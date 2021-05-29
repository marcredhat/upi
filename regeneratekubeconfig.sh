#!/bin/bash

AUTH_NAME="auth2kube"
NEW_KUBECONFIG="newkubeconfig"

echo "create a certificate request for system:admin user"
openssl req -new -newkey rsa:4096 -nodes -keyout $AUTH_NAME.key -out $AUTH_NAME.csr -subj "/CN=system:admin/O=system:masters"

echo "create signing request resource definition"

oc delete csr $AUTH_NAME-access # Delete old csr with the same name

cat << EOF >> $AUTH_NAME-csr.yaml
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: $AUTH_NAME-access
spec:
  groups:
  - system:authenticated
  request: $(cat $AUTH_NAME.csr | base64 | tr -d '\n')
  usages:
  - client auth
EOF

oc create -f $AUTH_NAME-csr.yaml

echo "approve csr and extract client cert"
oc get csr
oc adm certificate approve $AUTH_NAME-access
oc get csr $AUTH_NAME-access -o jsonpath='{.status.certificate}' | base64 -d > $AUTH_NAME-access.crt

echo "add system:admin credentials, context to the kubeconfig"
oc config set-credentials system:admin --client-certificate=$AUTH_NAME-access.crt \
--client-key=$AUTH_NAME.key --embed-certs --kubeconfig=/tmp/$NEW_KUBECONFIG

echo "create context for the system:admin"
oc config set-context system:admin --cluster=$(oc config view -o jsonpath='{.clusters[0].name}') \
--namespace=default --user=system:admin --kubeconfig=/tmp/$NEW_KUBECONFIG

echo "extract certificate authority"
oc -n openshift-authentication rsh `oc get pods -n openshift-authentication -o name | head -1` \
cat /run/secrets/kubernetes.io/serviceaccount/ca.crt > ingress-ca.crt

echo "set certificate authority data"
oc config set-cluster $(oc config view -o jsonpath='{.clusters[0].name}') \
--server=$(oc config view -o jsonpath='{.clusters[0].cluster.server}') --certificate-authority=ingress-ca.crt --kubeconfig=/tmp/$NEW_KUBECONFIG --embed-certs

echo "set current context to system:admin"
oc config use-context system:admin --kubeconfig=/tmp/$NEW_KUBECONFIG

echo "test client certificate authentication with system:admin"
export KUBECONFIG=/tmp/$NEW_KUBECONFIG
oc login -u system:admin
oc get pod -n openshift-console
