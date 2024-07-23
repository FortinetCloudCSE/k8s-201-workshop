echo curl without ips attack
appnamespace="app-1"
cfosnamespace="cfos-egress"

kubectl exec -it po/diag200 -n $appnamespace -- curl  http://ipinfo.io

echo curl with ips attack 
kubectl exec -it po/diag200 -n $appnamespace -- curl --max-time 5 -H "User-Agent: () { :; }; /bin/ls" http://ipinfo.io

echo display cfos log

podname=$(kubectl get pod -n $cfosnamespace -o jsonpath='{.items[].metadata.name}')
kubectl exec -it po/$podname -n cfos-egress -- tail -f /var/log/log/ips.0

