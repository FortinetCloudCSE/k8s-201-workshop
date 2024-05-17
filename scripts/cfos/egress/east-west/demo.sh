
kubectl create namespace app-1
kubectl apply -f nad_10_1_200_1_1_1_1.yaml -n app-1
kubectl apply -f demo_application_nad_200.yaml -n app-1

kubectl create namespace app-2
kubectl apply -f nad_10_1_100_1_1_1_1.yaml -n app-2
kubectl apply -f demo_application_nad_100.yaml -n app-2
kubectl create namespace cfostest

kubectl apply -f nad_10_1_200_252_cfos.yaml -n cfostest
kubectl apply -f nad_10_1_100_252_cfos.yaml -n cfostest
kubectl apply -f 01_create_cfos_account.yaml -n cfostest
kubectl apply -f ./../imagepullsecret.yaml -n cfostest
kubectl apply -f ./../cfos_license.yaml -n cfostest
kubectl apply -f 02_create_cfos_deployment.yaml -n cfostest

kubectl apply -f net1net2cmfirewallpolicy.yaml -n cfostest


