
```bash
yum -y install docker-distribution httpd-tools
```

Let's create the cert, I'll provide marcregistry.local as CN.

```bash
openssl req -newkey rsa:2048 -nodes -sha256 -x509 -days 365  -keyout /etc/pki/tls/private/registry.key -out /etc/pki/tls/registry.crt
```

```bash
cp /etc/pki/tls/registry.crt /etc/pki/ca-trust/source/anchors/cp

update-ca-trust
                    
htpasswd -c -B /etc/docker-distribution/dockerpasswd marc 
```

```bash
cat /etc/docker-distribution/registry/config.yml
version: 0.1
log:
  fields:
    service: registry
storage:
    cache:
        layerinfo: inmemory
    filesystem:
        rootdirectory: /var/lib/registry
http:
    addr: 192.168.122.1:5000
    tls:
        certificate: /etc/pki/tls/registry.crt
        key: /etc/pki/tls/private/registry.key
auth:
    htpasswd:
        realm: example.com
        path: /etc/docker-distribution/dockerpasswd
```

```bash
systemctl start docker-distribution

systemctl enable docker-distribution
```

```bash
ss -tulpn | grep 5000
tcp    LISTEN     0      128    192.168.122.1:5000                  *:*                   users:(("registry",pid=288509,fd=3))
```


```text
When creating the certificate, I provided provide marcregistry.local as CN.

So I also modified my /etc/hosts to point marcregistry.local to the address my registry listens to 192.168.122.1.
```


```bash
systemctl restart docker
```bash


```bash
docker  login marcregistry.local:5000
Username: marc
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```


```text
Enable external access: 
[root@vb0632 ~]# firewall-cmd --permanent --add-port=5000/tcp
success
[root@vb0632 ~]# systemctl restart firewalld
```

## External access

Get certificate:

```bash
[root@vb0632 marc]# openssl s_client -showcerts -connect marcregistry.local:5000  < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > test.crt
```


```bash
[marc@base-centos-7-0 ~]$ sudo cp test.crt /etc/pki/ca-trust/source/anchors/cp
```

```bash
[marc@base-centos-7-0 ~]$ sudo update-ca-trust
```

```bash
[marc@base-centos-7-0 ~]$ openssl s_client -showcerts -connect marcregistry.local:5000 | more
depth=0 C = FR, ST = FR, L = FR, O = FR, OU = FR, CN = marcregistry.local, emailAddress = m@m.m
verify return:1
CONNECTED(00000003)
---
Certificate chain
 0 s:/C=FR/ST=FR/L=FR/O=FR/OU=FR/CN=marcregistry.local/emailAddress=m@m.m
   i:/C=FR/ST=FR/L=FR/O=FR/OU=FR/CN=marcregistry.local/emailAddress=m@m.m
```
