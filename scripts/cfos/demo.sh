#ingress protection
curl http://k8strainingmaster1.westus.cloudapp.azure.com:8888/

#east-west protection

kubectl run curl-pod --image=curlimages/curl --restart=Never -- curl cfos7210250-service.default.svc.cluster.local:8888/ 
kubectl logs curl-pod
kubectl delete pod curl-pod

#dns
dig @k8strainingmaster1.westus.cloudapp.azure.com -p 8888 www.google.com
