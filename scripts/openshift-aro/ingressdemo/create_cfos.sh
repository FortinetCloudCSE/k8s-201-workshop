#!/bin/bash -xe
cfosnamespace="cfos-ingress"
kubectl create namespace $cfosnamespace
kubectl apply -f cfos_license.yaml -n $cfosnamespace
kubectl apply -f cfosimagepullsecret.yaml -n $cfosnamespace

scriptDir=$HOME/github && echo $scriptDir
echo $scriptDir
echo Create serviceaccount for cfos
kubectl apply -f $scriptDir/k8s-201-workshop/scripts/cfos/Task1_1_create_cfos_serviceaccount.yaml  -n $cfosnamespace

echo set cfos image

cfosimage="fortinetwandy.azurecr.io/cfos:255"

echo get dns ip 

k8sdnsip=$(kubectl get svc dns-default -n openshift-dns -o jsonpath='{.spec.clusterIP}')
echo $k8sdnsip

echo create scc
kubectl apply -f 02_custom-scc-role.yaml
echo create scc role binding 
kubectl apply -f 02_custom-scc-rolebinding.yaml -n $cfosnamespace
echo associated scc with serviceaccount 
kubectl apply -f 02_custom-scc-sa-root.yaml -n $cfosnamespace
echo create cfos
kubectl apply -f 03_cfos_deployment_with_scc_priviledge.yaml -n $cfosnamespace


