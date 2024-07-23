#!/bin/bash -x
appnamespace="app-1"
kubectl create namespace $appnamespace
kubectl apply -f nad_10_1_200_1_1_1_1.yaml -n $appnamespace
kubectl apply -f demo_application_nad_200_3.yaml -n $appnamespace

