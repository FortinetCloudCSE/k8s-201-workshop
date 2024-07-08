k create namespace cfostest
k apply -f cfos_license.yaml -n cfostest
k apply -f dockerinterbeing.yaml -n cfostest
k apply -f test_dns.yaml -n cfostest
k apply -f test_dns_svc.yaml -n cfostest
k apply -f 03_udp.yaml -n cfostest
#ingress protection
#curl http://k8strainingmaster1.westus.cloudapp.azure.com:8888/
#curl http://k8strainingmaster1.westus.cloudapp.azure.com:8889/

#east-west protection

#kubectl run curl-pod --image=curlimages/curl --restart=Never -- curl cfos7210250-service.default.svc.cluster.local:8888/ 
#kubectl logs curl-pod
#kubectl delete pod curl-pod
#
#dns
#dig @k8strainingmaster1.westus.cloudapp.azure.com -p 8886 www.google.com
