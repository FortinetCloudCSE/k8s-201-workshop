#!/bin/bash -x

demoapp1="goweb"
demoapp1image="interbeing/myfmg:goweb"
demoapp1port="80"

demoapp2="nginx"
demoapp2image="nginx"
demoapp2port="80"

function deploy_application_deployment() {
kubectl create deployment $demoapp1 --image=$demoapp1image
kubectl rollout status deployment $demoapp1
kubectl create deployment $demoapp2 --image=$demoapp2image
kubectl rollout status deployment $demoapp2
}

function deploy_application_clusterIPSVC() {
kubectl expose deployment $demoapp1 --port=$demoapp1port
kubectl expose deployment $demoapp2 --port=$demoapp2port
}

#function getfortiweblbsvcip() {
#  if [ -z "$fortiwebsshhost" ]; then
#    fortiwebsshhost=$(kubectl get svc $fortiwebcontainerversion-service -o json | jq -r 'select(.spec.selector.app == "fortiweb") | .status.loadBalancer.ingress[0].ip')
#  fi
#echo $fortiwebsshhost
#}
#

function demo() {
ip=$(kubectl get cm ssh-config -o json | jq -r .data.SSH_HOST)
port="8888"
curl http://$ip:$port/v2
curl http://$ip:$port/index.html
}
deploy_application_deployment
deploy_application_clusterIPSVC
#demo
