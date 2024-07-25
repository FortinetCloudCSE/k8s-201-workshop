#!/bin/bash -x
kubectl create deployment goweb --image=interbeing/myfmg:fileuploadserverx86 
kubectl expose  deployment goweb --target-port=80  --port=80 
kubectl create deployment nginx --image=nginx 
kubectl expose deployment nginx --target-port=80 --port=80 
