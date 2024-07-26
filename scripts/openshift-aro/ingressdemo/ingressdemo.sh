#!/bin/bash -x
cfosnamespace="cfos-ingress"


./create_cfos.sh
./create_app.sh
./create_cfos_svc.sh

echo sleep 60
sleep 60
echo get rg name
arogroupname=$(az group list -o table | grep aro | cut -d ' ' -f 1)
echo $arogroupname
echo get fqdn name
fqdn=$(az network public-ip list -g $arogroupname | grep fqdn | cut -d ":" -f 2 | tr -d '"')
echo $fqdn

curl -v http://${fqdn}:8080
curl -v http://${fqdn}:8000
curl -v http://${fqdn}:8005

wget -c https://secure.eicar.org/eicar_com.zip

cfosnamespace="cfos-ingress"
curl -v --max-time 5 -F "file=@$scriptDir/k8s-201-workshop/scripts/cfos/ingress_demo/eicar_com.zip" http://${fqdn}:8000
podname=$(kubectl get pod -n $cfosnamespace -l app=cfos -o jsonpath='{.items[*].metadata.name}')
echo $podname

kubectl exec -it po/$podname -n $cfosnamespace  -- tail -f /var/log/log/virus.0

