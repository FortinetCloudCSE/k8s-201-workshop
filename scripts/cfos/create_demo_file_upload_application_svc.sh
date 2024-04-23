kubectl create deployment goweb --image=interbeing/myfmg:fileuploadserverx86
kubectl expose  deployment goweb --target-port=80  --port=80
