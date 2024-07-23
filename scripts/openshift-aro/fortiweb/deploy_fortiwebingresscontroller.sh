#!/bin/bash 

function setfortiwebsshhostipifusemetallb() {

if kubectl get ipaddresspools -n metallb-system > /dev/null 2>&1; then
    echo "metallb ippool exist,use cluster master node external ip by default for fortiweb"
#fortiwebsshhost="" && fortiwebsshhost=$(kubectl run curl-ipinfo --image=appropriate/curl --quiet --restart=Never  -it -- curl -s icanhazip.com) && echo $fortiwebsshhost && sleep 2 && kubectl delete pod curl-ipinfo
fortiwebsshhost=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
fortiwebsshhost=$(echo $fortiwebsshhost | awk -F'[/:]' '{print $4}')
else
    fortiwebsshhost=""
fi

echo "fortiwebsshhost is set to: $fortiwebsshhost"

}

setfortiwebsshhostipifusemetallb
fortiwebingresscontrollerclassname="fortiwebingresscontroller"

fortiwebingresscontrollername="fortiwebingresscontroller"
fortiwebingresscontrollerimage="interbeing/myfmg:fortiwebingresscontrollerx86"
fortiwebingresscontrollernamespace="default"

filename="deploy_fortiwebingresscontroller.yaml"
rm $filename

fortiwebexposedvipserviceport="8888"
fortiwebsshusername="admin"
fortiwebsshport="2222"
fortiwebsshpassword="Welcome.123"

fortiwebcontainerversion="fweb70577"

function getfortiweblbsvcip() {
  if [ -z "$fortiwebsshhost" ]; then
    fortiwebsshhost=$(kubectl get svc $fortiwebcontainerversion-service -o json | jq -r 'select(.spec.selector.app == "fortiweb") | .status.loadBalancer.ingress[0].ip')
  fi
echo $fortiwebsshhost
}

getfortiweblbsvcip



function install_ingressclass() {
cat << EOF | tee -a $filename
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: $fortiwebingresscontrollername
spec:
  controller: yagosys.com/ingresscontroller
EOF
}

function install_fortiweb_ingresscontroller() {
cat << EOF | tee -a $filename
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-$fortiwebingresscontrollername
  namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $fortiwebingresscontrollername
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $fortiwebingresscontrollername
  template:
    metadata:
      labels:
        app: $fortiwebingresscontrollername
    spec:
      serviceAccountName: sa-$fortiwebingresscontrollername
      initContainers:
      - name: ssh-setup
        image: interbeing/myfmg:my-ssh-setup-image
        imagePullPolicy: Always
        envFrom:
        - configMapRef:
            name: ssh-config
      containers:
      - name: $fortiwebingresscontrollername
        image: $fortiwebingresscontrollerimage
        imagePullPolicy: Always
        envFrom:
        - configMapRef:
            name: ssh-config
        ports:
        - containerPort: 80
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: $fortiwebingresscontrollername-role
rules:
- apiGroups: ["", "extensions", "networking.k8s.io"]
  resources: ["ingresses", "services", "endpoints", "pods", "nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses/status"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $fortiwebingresscontrollername-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: $fortiwebingresscontrollername-role
subjects:
- kind: ServiceAccount
  name: sa-$fortiwebingresscontrollername
  namespace: $fortiwebingresscontrollernamespace
EOF
}

function create_configmap_for_initcontainer() {
cat << EOF | tee -a $filename
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssh-config
data:
  SSH_HOST: "${fortiwebsshhost}"
  SSH_PORT: "${fortiwebsshport}"
  SSH_USERNAME: "${fortiwebsshusername}"
  SSH_NEW_PASSWORD: "${fortiwebsshpassword}"
  FORTIWEBIMAGENAME: "${fortiwebcontainerversion}"
  FORTIWEBSVCPORT:   "${fortiwebexposedvipserviceport}"
EOF
}


install_ingressclass
install_fortiweb_ingresscontroller
create_configmap_for_initcontainer
kubectl apply -f $filename
kubectl rollout status deployment $fortiwebingresscontrollername
