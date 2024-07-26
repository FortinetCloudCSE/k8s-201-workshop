#!/bin/bash -x
cfosnamespace="cfos-ingress"

echo delete namespace cfos-ingress
kubectl delete namespace $cfosnamespace

echo delete target application and svc
kubectl delete svc goweb
kubectl delete svc nginx
kubectl delete deployment goweb
kubectl delete deployment nginx

echo create again


./create_cfos.sh
./create_app.sh
./create_cfos_svc.sh

echo sleep 60
sleep 60

# Get resource group name
arogroupname=$(az group list --query "[?contains(name, 'aro')].name" -o tsv)
echo $arogroupname

# Get FQDN name
fqdn=$(az network public-ip list -g "$arogroupname" --query "[].dnsSettings.fqdn" -o tsv)
echo $fqdn


curl -v http://${fqdn}:8080
curl -v http://${fqdn}:8000
curl -v http://${fqdn}:8005

wget -c https://secure.eicar.org/eicar_com.zip

cfosnamespace="cfos-ingress"
scriptDir="${HOME}/github"
curl -v --max-time 5 -F "file=@$scriptDir/k8s-201-workshop/scripts/cfos/ingress_demo/eicar_com.zip" http://${fqdn}:8000
podname=$(kubectl get pod -n $cfosnamespace -l app=cfos -o jsonpath='{.items[*].metadata.name}')
echo $podname

kubectl exec -it po/$podname -n $cfosnamespace  -- tail -f /var/log/log/virus.0

