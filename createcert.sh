#!/bin/bash
set -euxo pipefail

# Set up local registry with long-lived certs with SAN
# if in gcp instance
#HOSTNAME=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/hostname" -H "Metadata-Flavor: Google")
HOSTNAME=marcregistry.local
GOPATH="/root/go/"

date --set="10 MAR 2021 18:00:00"

sudo dnf -y install podman httpd httpd-tools make
sudo yum module -y install go-toolset
rpm -qi go-toolset
set +e

sudo cp -pR /root/go/bin/* /usr/bin

if ! cfssl version || ! cfssljson --help; then
  set -e
  go get github.com/cloudflare/cfssl/cmd/...
  ls ~/go/bin/
  #pushd "${GOPATH}"/src/github.com/cloudflare/cfssl
  #make
  #popd
  #sudo cp "${GOPATH}"/src/github.com/cloudflare/cfssl/bin/cfssl /usr/local/bin
  #sudo cp "${GOPATH}"/src/github.com/cloudflare/cfssl/bin/cfssljson /usr/local/bin
fi
set -e

mkdir create-registry-certs
pushd create-registry-certs
cat > ca-config.json << EOF
{
    "signing": {
        "default": {
            "expiry": "87600h"
        },
        "profiles": {
            "server": {
                "expiry": "87600h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "87600h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            }
        }
    }
}
EOF

cat > ca-csr.json << EOF
{
    "CN": "Test Registry Self Signed CA",
    "hosts": [
        "${HOSTNAME}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "San Francisco"
        }
    ]
}
EOF

cat > server.json << EOF
{
    "CN": "Test Registry Self Signed CA",
    "hosts": [
        "${HOSTNAME}"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "San Francisco"
        }
    ]
}
EOF

# generate ca-key.pem, ca.csr, ca.pem
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

# generate server-key.pem, server.csr, server.pem
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server server.json | cfssljson -bare server

# enable schema version 1 images
cat > registry-config.yml << EOF
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
compatibility:
  schema1:
    enabled: true
EOF

sudo mkdir -p /opt/registry/{auth,certs,data}
sudo firewall-cmd --add-port=5000/tcp --zone=internal --permanent
sudo firewall-cmd --add-port=5000/tcp --zone=public   --permanent
sudo firewall-cmd --add-service=http  --permanent
sudo firewall-cmd --reload

CA=$(sudo tail -n +2 ca.pem | head -n-1 | tr -d '\r\n')
sudo htpasswd -bBc /opt/registry/auth/htpasswd test test
sudo cp registry-config.yml /opt/registry/.
sudo cp server-key.pem /opt/registry/certs/.
sudo cp server.pem /opt/registry/certs/.
sudo cp /opt/registry/certs/server.pem /etc/pki/ca-trust/source/anchors/
sudo cp ca.pem /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract

# Now that certs are in place, run the local image registry
sudo podman run --name test-registry -p 5000:5000 \
-v /opt/registry/data:/var/lib/registry:z \
-v /opt/registry/auth:/auth:z \
-e "REGISTRY_AUTH=htpasswd" \
-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" \
-e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" \
-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
-v /opt/registry/certs:/certs:z \
-v /opt/registry/registry-config.yml:/etc/docker/registry/config.yml:z \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server.pem \
-e REGISTRY_HTTP_TLS_KEY=/certs/server-key.pem \
-d docker.io/library/registry:2

popd
#rm -rf create-registry-certs
sleep 5
curl -u test:test https://"${HOSTNAME}":5000/v2/_catalog
