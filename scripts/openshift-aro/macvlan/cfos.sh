#!/bin/bash -x
cfosnamespace="cfos-egress"
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
echo create multus nad for cfos
kubectl apply -f nad_10_1_200_252_cfos.yaml -n $cfosnamespace
echo create cfos
kubectl apply -f 03_cfos_deployment_with_scc_priviledge_multus_macvlan.yaml -n $cfosnamespace


cat << EOF | tee > net1net2cmtointernetfirewallpolicy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: net1net2
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall policy
        edit 100
            set utm-status enable
            set name "net1tointernet"
            set srcintf "net1"
            set dstintf "eth0"
            set srcaddr "all"
            set dstaddr "all"
            set service "ALL"
            set ssl-ssh-profile "deep-inspection"
            set av-profile "default"
            set ips-sensor "high_security"
            set application-list "default"
            set nat enable
            set logtraffic all
        next
    end
EOF
kubectl apply -f net1net2cmtointernetfirewallpolicy.yaml -n $cfosnamespace

