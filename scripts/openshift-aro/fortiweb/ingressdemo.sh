./deploy_fortiweb_expose_slb.sh 
./deploy_fortiwebingresscontroller.sh 
./deploy_demo_application.sh 
kubectl apply -f ingress.yaml
ip=$(kubectl get cm ssh-config -o json | jq -r .data.SSH_HOST)
echo $ip
port="8888"
curl http://$ip:$port/v2
curl http://$ip:$port/index.html
