#!/bin/bash 

azureslbdnslabel="k8strainingmaster1onarotest"

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
fortiweblabel="app: fortiweb"
fortiwebcontainerrepo="interbeing/myfmg"
fortiwebcontainerversion="fweb70577"
fortiwebcontainerimage="$fortiwebcontainerrepo:$fortiwebcontainerversion"
fortiwebexposedvipserviceport="8888"

fortiwebsshusername="admin"
fortiwebsshport="2222"
fortiwebsshpassword="Welcome.123"
fortiweblbsvcmetadataannotation=""

filename="deploy_fortiweb_deployment_lb_svc.yaml"
rm $filename

function getfortiweblbsvcip() {
  if [ -z "$fortiwebsshhost" ]; then
    fortiwebsshhost=$(kubectl get svc $fortiwebcontainerversion-service -o json | jq -r 'select(.spec.selector.app == "fortiweb") | .status.loadBalancer.ingress[0].ip')
  fi
echo $fortiwebsshhost
}

function configloadbalanceripifmetallbcontrollerinstalled() {
    cmd="kubectl get ipaddresspools -n metallb-system -o json"
    ip=$(eval $cmd | jq -r '.items[0].spec.addresses[0]')
    ip=$(echo "$ip" | cut -d'/' -f1)
    # Check if $ip is not empty
    if [ -n "$ip" ]; then
        fortiweblbsvcmetadataannotation="metallb.universe.tf/loadBalancerIPs: $ip"
        echo "Annotation to be applied: $fortiweblbsvcmetadataannotation"
    else
        echo "No IP address retrieved from MetalLB IP address pools."
    fi
}
configloadbalanceripifmetallbcontrollerinstalled
echo $fortiweblbsvcmetadataannotation 

function install_fortiweb_deployment() {
cat << EOF | tee  $filename
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $fortiwebcontainerversion-deployment
  labels:
    $fortiweblabel
spec:
  replicas: 1
  selector:
    matchLabels:
      $fortiweblabel
  template:
    metadata:
      labels:
        $fortiweblabel
    spec:
      containers:
      - name: $fortiwebcontainerversion-container
        image: $fortiwebcontainerimage
        securityContext:
          privileged: true
        ports:
        - containerPort: 8
        - containerPort: 9
        - containerPort: 43
        - containerPort: 22
        - containerPort: 80
        - containerPort: 443
EOF
}


function expose_fortiweb_loadbalancer_svc() {
cat << EOF | tee -a $filename
---
apiVersion: v1
kind: Service
metadata:
  name: $fortiwebcontainerversion-service
  annotations:
    $fortiweblbsvcmetadataannotation
    service.beta.kubernetes.io/azure-dns-label-name: $azureslbdnslabel
spec:
  sessionAffinity: ClientIP
  ports:
  - port: $fortiwebsshport 
    name: ssh
    targetPort: 22
  - port: 18443
    name: gui
    targetPort: 43
  - port: $fortiwebexposedvipserviceport
    name: $fortiwebcontainerversion-service-$fortiwebexposedvipserviceport
    targetPort: $fortiwebexposedvipserviceport
  selector:
    $fortiweblabel
  type: LoadBalancer
EOF
}


function create_configmap_for_initcontainer() {
#fortiwebsshhost=$(kubectl get pods -l app=fortiweb -o=jsonpath='{.items[*].status.podIP}')
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
kubectl apply -f $filename
}

install_fortiweb_deployment
expose_fortiweb_loadbalancer_svc
kubectl apply -f $filename
kubectl rollout status deployment $fortiwebcontainerversion-deployment

getfortiweblbsvcip
echo "${fortiwebsshhost}"
create_configmap_for_initcontainer
