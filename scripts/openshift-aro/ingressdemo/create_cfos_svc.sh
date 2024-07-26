#!/bin/bash -xe
cfosnamespace="cfos-ingress"

function create_cfos_headless_asvip() {
cat << EOF | tee headlessservice.yaml
apiVersion: v1
kind: Service
metadata:
  name: cfostest-headless
spec:
  clusterIP: None
  selector:
    app: cfos
  ports:
    - protocol: TCP
      port: 443
      targetPort: 443
EOF
kubectl apply -f headlessservice.yaml -n $cfosnamespace
}

function create_cfos_rest() {
cat << EOF | tee rest8080.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: restapi
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |- 
     config system global
       set admin-port 8080
       set admin-server-cert "Device"
     end
EOF
kubectl apply -f rest8080.yaml -n $cfosnamespace
}

function create_cfosvip_forbackendapp() {
nginxclusterip=$(kubectl get svc -l app=nginx  -o jsonpath='{.items[*].spec.clusterIP}')
echo $nginxclusterip
gowebclusterip=$(kubectl get svc -l app=goweb  -o jsonpath='{.items[*].spec.clusterIP}')
echo $gowebclusterip

cat << EOF | tee cfosconfigmapfirewallvip.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cfosconfigvip
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall vip
           edit "nginx"
            set extip "cfostest-headless.$cfosnamespace.svc.cluster.local"
            set mappedip $nginxclusterip
            set extintf "eth0"
            set portforward enable
            set extport "8005"
            set mappedport "80"
           next
           edit "goweb"
            set extip "cfostest-headless.$cfosnamespace.svc.cluster.local"
            set mappedip $gowebclusterip
            set extintf "eth0"
            set portforward enable
            set extport "8000"
            set mappedport "80"
           next
       end
EOF
kubectl apply -f cfosconfigmapfirewallvip.yaml -n $cfosnamespace
}


function create_firewall_policy() {
cat << EOF | tee cfosconfigmapfirewallpolicy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cfosconfigpolicy
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall policy
           edit 1
            set name "nginx"
            set srcintf "eth0"
            set dstintf "eth0"
            set srcaddr "all"
            set dstaddr "nginx"
            set nat enable
           next
           edit 2
            set name "goweb"
            set srcintf "eth0"
            set dstintf "eth0"
            set srcaddr "all"
            set dstaddr "goweb"
            set utm-status enable
            set av-profile default
            set nat enable
           next
       end
EOF
kubectl apply -f cfosconfigmapfirewallpolicy.yaml -n $cfosnamespace
}

function create_lb_svc() {
svcname=$(kubectl config view -o json | jq .clusters[0].cluster.server | cut -d "." -f 2 | cut -d "/" -f 3)-$(date -I)
echo $svcname
echo $svcname.eastus.cloudapp.azure.com
echo use pool ipaddress $metallbip for svc 

cat << EOF | tee > 03_single.yaml 
apiVersion: v1
kind: Service
metadata:
  name: cfos7210250-service
  annotations:
    $metallbannotation
    service.beta.kubernetes.io/azure-dns-label-name: $svcname
spec:
  sessionAffinity: ClientIP
  ports:
  - port: 8080
    name: cfos-restapi
    targetPort: 8080
  - port: 8000
    name: cfos-goweb-default-1
    targetPort: 8000
    protocol: TCP
  - port: 8005
    name: cfos-nginx-default-1
    targetPort: 8005
    protocol: TCP
  selector:
    app: cfos
  type: LoadBalancer

EOF
kubectl apply -f 03_single.yaml  -n $cfosnamespace
sleep 5
kubectl get svc cfos7210250-service  -n $cfosnamespace
}


create_cfos_headless_asvip
create_cfos_rest
create_cfosvip_forbackendapp
echo sleep 60
sleep 60
create_firewall_policy
create_lb_svc
