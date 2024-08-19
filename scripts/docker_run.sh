#!/bin/bash

myarray=( "build" "server" "shell" "" )

[[ "$#" > "1" ]] || [[ ! " ${myarray[*]} " =~ " $1 " ]] && echo "Usage: ./scripts/docker_run.sh [ build | server | shell ]" && exit 1

cmd="docker run --rm -it 
  -v /Users/srijareddyallam/Documents/TECworkshop/k8s-201-workshop/content:/home/CentralRepo/content
  -v /Users/srijareddyallam/Documents/TECworkshop/k8s-201-workshop/docs:/home/CentralRepo/public
  --mount type=bind,source=/Users/srijareddyallam/Documents/TECworkshop/k8s-201-workshop/config.toml,target=/home/CentralRepo/config.toml
  -p 1313:1313 fortinet-hugo:latest $1"
echo $cmd
$cmd