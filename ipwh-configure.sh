#!/bin/bash
sudo apt update
sudo apt install golang-cfssl

#create CSR to send to KubeAPI
sudo cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "image-bouncer-webhook",
    "image-bouncer-webhook.default.svc",
    "image-bouncer-webhook.default.svc.cluster.local",
    "192.168.56.10",
    "10.96.0.0"
  ],
  "CN": "system:node:image-bouncer-webhook.default.pod.cluster.local",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "O": "system:nodes"
    }
  ]
}
EOF

#create csr request
sudo cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: image-bouncer-webhook.default
spec:
  request: $(cat server.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

#approver cert
kubectl certificate approve image-bouncer-webhook.default

# download signed server.crt
kubectl get csr image-bouncer-webhook.default -o jsonpath='{.status.certificate}' | base64 --decode > server.crt
#sudo mkdir -p /etc/kubernetes/pki/ib-webhook/

#copy to /etc/kubernetes/pki/
sudo cp server.crt /etc/kubernetes/pki/

# create secret with signed server.crt
kubectl create secret tls tls-image-bouncer-webhook --key server-key.pem --cert server.crt

#create backend
sudo cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-bouncer-webhook
spec:
  selector:
    matchLabels:
      app: image-bouncer-webhook
  template:
    metadata:
      labels:
        app: image-bouncer-webhook
    spec:
      containers:
        - name: image-bouncer-webhook
          imagePullPolicy: Always
          image: "kainlite/kube-image-bouncer:latest"
          args:
            - "--cert=/etc/admission-controller/tls/tls.crt"
            - "--key=/etc/admission-controller/tls/tls.key"
            - "--debug"
            - "--registry-whitelist=docker.io,k8s.gcr.io"
          volumeMounts:
            - name: tls
              mountPath: /etc/admission-controller/tls
      volumes:
        - name: tls
          secret:
            secretName: tls-image-bouncer-webhook
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: image-bouncer-webhook
  name: image-bouncer-webhook
spec:
  type: NodePort
  ports:
    - name: https
      port: 443
      targetPort: 1323
      protocol: "TCP"
      nodePort: 30020
  selector:
    app: image-bouncer-webhook
EOF

#add dns to hosts file
sudo echo "127.0.0.1 image-bouncer-webhook" >> /etc/hosts
netstat -na | grep 30020
telnet image-bouncer-webhook 30020

# create kube config
sudo cat > /etc/kubernetes/pki/ib_kube_config.yaml  <<EOF 
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/server.crt
    server: https://image-bouncer-webhook:30020/image_policy
  name: bouncer_webhook
contexts:
- context:
    cluster: bouncer_webhook
    user: api-server
  name: bouncer_validator
current-context: bouncer_validator
preferences: {}
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/pki/apiserver.crt
    client-key:  /etc/kubernetes/pki/apiserver.key
EOF

#create admission config
cat > /etc/kubernetes/pki/admission_config.yaml  <<EOF 
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/pki/ib_kube_config.yaml
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
EOF

# - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
# - --admission-control-config-file=/etc/kubernetes/pki/admission_config.yaml

