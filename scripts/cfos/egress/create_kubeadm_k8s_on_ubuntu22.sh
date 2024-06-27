#!/bin/bash -x
# Configuration
echo $(date)
nsg_name="myNSG"
srcaddressprefix="'*'"
master_prefix="k8strainingmaster-$(whoami)-"
worker_prefix="k8strainingworker-$(whoami)-"
vm_image="Ubuntu2204"
EMAIL=$(az account show --query user.name)
rg=$(az group list --query "[?contains(name, '$(whoami)') && contains(name, 'workshop')].name" -o tsv)
if [ -z $rg ] ; then 
echo no rg exist, will create it
fi

if [ -z $location ] ; then
location="eastus"
fi

#vm_size="Standard_B2s"
#vm_size="Standard_D4s_v4"
vm_size="Standard_D2s_v4"

admin_username="ubuntu"
#rsakeyname="id_rsa_tecworkshop"
rsakeyname="id_rsa"
[ ! -f ~/.ssh/$rsakeyname ] && ssh-keygen -t rsa -b 4096 -q -N "" -f ~/.ssh/$rsakeyname
os_disk_size_gb="100"
public_ip_sku="Standard"
vnet_name="myVNet"
subnet_name="mySubnet"
address_prefix="10.0.0.0/16"
subnet_prefix="10.0.0.0/24"
domain="$location.cloudapp.azure.com"
number_of_masters=1
number_of_workers=1

master_vm_names=()
worker_vm_names=()
cluster_join_script_name="./workloadtojoin.sh"

create_rg() {
currentUser=$(az account show --query user.name -o tsv)
echo $currentUser
rg=$(az group list --query "[?contains(name, '$(whoami)') && contains(name, 'workshop')].name" -o tsv)

if [ -z $rg ] ; then 
owner="tecworkshop"
rg=$owner-$(whoami)-"cfos-"$location-$(date -I)
az group create --location $location --resource-group $rg
fi
echo $rg 
echo $location
}

create_vnet() {
  az network vnet create \
    --resource-group $rg \
    --name $vnet_name \
    --address-prefix $address_prefix \
    --subnet-name $subnet_name \
    --subnet-prefix $subnet_prefix \
    --location $location
}

create_nsg() {
  echo "Creating NSG: $nsg_name in Resource Group: $rg"
  az network nsg create \
    --resource-group $rg \
    --name $nsg_name \
    --location $location
}

create_nsg_rule() {
  az network nsg rule create \
    --resource-group $rg \
    --nsg-name $nsg_name \
    --name AllowSpecificIP \
    --priority 1000 \
    --source-address-prefixes $srcaddressprefix \
    --destination-port-ranges '*' \
    --direction Inbound \
    --access Allow \
    --protocol '*' \
    --description "Allow traffic to TCP port any"
}

update_vnet_subnet_nsg() {
  az network vnet subnet update \
    --vnet-name $vnet_name \
    --name $subnet_name \
    --resource-group $rg \
    --network-security-group $nsg_name
}

create_vm() {
  local vm_name_prefix=$1
  local vm_count=$2
  local vm_role=$3 # master or worker

  for ((i=1; i<=vm_count; i++)); do
    local vm_name="${vm_name_prefix}${i}"
    local dns_name="${vm_name_prefix}${i}"
    echo "Creating VM: $vm_name with role: $vm_role and DNS name: $dns_name.$domain"

    az vm create \
      --resource-group $rg \
      --name $vm_name \
      --image $vm_image \
      --size $vm_size \
      --admin-username $admin_username \
      --ssh-key-values @~/.ssh/${rsakeyname}.pub \
      --os-disk-size-gb $os_disk_size_gb \
      --location $location \
      --public-ip-sku $public_ip_sku \
      --public-ip-address-dns-name $dns_name \
      --vnet-name $vnet_name \
      --subnet $subnet_name --verbose

    # Store VM names for later use
    if [[ "$vm_role" == "master" ]]; then
      master_vm_names+=("$vm_name")
    else
      worker_vm_names+=("$vm_name")
    fi
  done
}

update_nics_with_nsg() {
  local vm_names=("$@") # Accept an array of VM names

  for vm_name in "${vm_names[@]}"; do
    echo "Updating NIC for VM: $vm_name"

    local vnic=$(az vm show --resource-group $rg --name $vm_name --query "networkProfile.networkInterfaces[0].id" -o tsv)
    az network nic update --ids $vnic --network-security-group $nsg_name
  done
}

copy_script_from_master() {
    # Directly use the first master VM name assuming it's the primary one
    local master_vm_name=$1
    local master_dns="${master_vm_name}.${domain}"

    # More secure approach to handle known_hosts entries
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${master_dns}"

    # Copy the script from the master node to the local directory
    scp -o "StrictHostKeyChecking=no" "ubuntu@${master_dns}:${cluster_join_script_name}" .
}


run_script_on_master() {
    local script_path=$1  # Path to the script you want to execute on the master node

    # Assuming only one master node for simplicity
    local master_vm_name="${master_vm_names[0]}"
    local master_dns="${master_vm_name}.${domain}"

    
    echo "Executing script on master node: $master_dns"
    scp -o "StrictHostKeyChecking=no" "$script_path" "ubuntu@${master_dns}:~/"
    ssh -o "StrictHostKeyChecking=no" "ubuntu@${master_dns}" "bash ~/$(basename $script_path) $(whoami) $location $EMAIL"
}

run_script_on_workers() {
    local script_path=$1  # Path to the script you want to execute on the worker nodes

    for worker_vm_name in "${worker_vm_names[@]}"; do
        local worker_dns="${worker_vm_name}.${domain}"

        echo "Executing script on worker node: $worker_dns"
        ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${worker_dns}"
        scp -o "StrictHostKeyChecking=no" "$script_path" "ubuntu@${worker_dns}:~/"
        ssh -o "StrictHostKeyChecking=no" "ubuntu@${worker_dns}" "bash ~/$(basename $script_path)"
    done
}

copy_and_modify_kubeconfig() {
    local master_vm_name="${master_vm_names[0]}" # Assuming first master node
    local master_dns="${master_vm_name}.${domain}"
    local local_kubeconfig_path="./config" # Temporary local path for kubeconfig
    local new_kubeconfig_path="$HOME/.kube/config" # Final path for kubeconfig

    # Copy kubeconfig from master node
    echo "Copying kubeconfig from master node: $master_dns"
    scp -o "StrictHostKeyChecking=no" "ubuntu@${master_dns}:/home/ubuntu/.kube/config" $local_kubeconfig_path

    # Modify kubeconfig to use DNS name instead of IP for the server
    echo "Modifying kubeconfig to use DNS name for the server"

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    sed -i '' "s/server: https:\/\/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:6443/server: https:\/\/${master_dns}:6443/g" $local_kubeconfig_path
else
    # Linux (and potentially other UNIX-like systems)
    sed -i "s/server: https:\/\/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:6443/server: https:\/\/${master_dns}:6443/g" $local_kubeconfig_path
fi

    #sed -i "s/server: https:\/\/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:6443/server: https:\/\/${master_dns}:6443/g" $local_kubeconfig_path

    # Ensure the .kube directory exists
    mkdir -p "$HOME/.kube"

    # Move modified kubeconfig to the final directory
    echo "Placing modified kubeconfig in $new_kubeconfig_path"
    cp $local_kubeconfig_path $new_kubeconfig_path
}

replace_fqdn_with_master_dns() {

    local file_path=$1  # The file in which to replace the FQDN value
    local master_vm_name="${master_vm_names[0]}" # Assuming the first master node
    local master_dns="${master_vm_name}.${domain}"

    # Check if the file exists
    if [[ ! -f "$file_path" ]]; then
        echo "File $file_path does not exist."
        return 1
    fi

    # Use sed to replace 'FQDN="localhost"' with the master node's DNS name in the file
    sed -i "s/FQDN=\"localhost\"/FQDN=\"${master_dns}\"/g" "$file_path"

    echo "Replaced 'localhost' with '${master_dns}' in $file_path"
}

untaint_master_node() {
    #local master_vm_name="k8strainingmaster1"
    local master_vm_name="${master_vm_names[0]}"
    echo "Master VM Name: $master_vm_name"

    if [[ $number_of_workers -eq 0 ]]; then
        echo "Untainting master node because there are no worker nodes..."

        # Dynamically get the key of the taint to remove
        local taint_keys=$(kubectl get node "$master_vm_name" -o jsonpath='{.spec.taints[*].key}')
        
        for taint_key in $taint_keys; do
            if [[ $taint_key == "node-role.kubernetes.io/master" || $taint_key == "node-role.kubernetes.io/control-plane" ]]; then
                echo "Removing taint $taint_key:NoSchedule from the master node..."
                kubectl taint nodes "$master_vm_name" "$taint_key:NoSchedule-"
            fi
        done
    else
        echo "There are worker nodes present. No need to untaint the master node."
    fi
}

copy_cert_from_master() {
    # Directly use the first master VM name assuming it's the primary one
    local master_vm_name=$1
    local master_dns="${master_vm_name}.${domain}"

    # More secure approach to handle known_hosts entries
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${master_dns}"

    # Copy the script from the master node to the local directory
    scp -o "StrictHostKeyChecking=no"  "ubuntu@${master_dns}:/home/ubuntu/fullchain.pem" .
    scp -o "StrictHostKeyChecking=no"  "ubuntu@${master_dns}:/home/ubuntu/privkey.pem" .
}

install_local_storage_class() {
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

kubectl rollout status deployment local-path-provisioner -n local-path-storage

kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
}

delete_resource() {

rg=$(az group list --query "[?contains(name, '$(whoami)') && contains(name, 'workshop')].name" -o tsv) 
vmNames=$(az vm list -g $rg --query "[].name" -o tsv)
for vmName in $vmNames; do 
   az vm delete --name $vmName -g $rg --yes
done

diskNames=$(az disk list --resource-group "$rg" --query "[].name" -o tsv)
  for diskName in $diskNames; do
    az disk delete --name "$diskName" --resource-group $rg --yes
  done

nics=$(az network nic list -g $rg -o tsv)
for nic in $nics; do
    az network nic delete --name $nic -g $rg 
done

publicIps=$(az network public-ip list -g $rg -o tsv)
for publicIp in $publicIps; do 
    az network public-ip delete --name $publicIp -g $rg 
done

vnets=$(az network vnet list -g $rg -o tsv)
for vnet in $vnets; do
   az network vnet delete --name $vnet -g $rg
done


nsgs=$(az network nsg list -g $rg -o tsv)
for nsg in $nsgs; do
    az network nsg delete --name $nsg -g $rg 
done
}

installmetallb() {

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
kubectl rollout status deployment controller -n metallb-system

}

createmetallbpool() {
local_ip=$(kubectl get node -o wide | grep 'control-plane' | awk '{print $6}')
cat <<EOF | tee metallbippool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - $local_ip/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
EOF
kubectl apply -f metallbippool.yaml
}

restart_allpod_allnamespace () {
kubectl get deployments --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' | tail -n +2 | while read namespace name; do kubectl rollout restart deployment $name -n $namespace; done

kubectl get deployments --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' | tail -n +2 | while read namespace name; do kubectl rollout status deployment $name -n $namespace; done

kubectl get daemonsets --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' | tail -n +2 | while read namespace name; do kubectl rollout restart daemonset $name -n $namespace; done

kubectl get daemonsets --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name' | tail -n +2 | while read namespace name; do kubectl rollout status daemonset $name -n $namespace; done

}
# Initial setup calls
create_rg
create_vnet
create_nsg
create_nsg_rule
update_vnet_subnet_nsg
create_vm $master_prefix $number_of_masters "master"
create_vm $worker_prefix $number_of_workers "worker"
update_nics_with_nsg "${master_vm_names[@]}"
update_nics_with_nsg "${worker_vm_names[@]}"
replace_fqdn_with_master_dns "./install_kubeadm_masternode.sh"
run_script_on_master "./install_kubeadm_masternode.sh"
run_script_on_workers "./install_kubeadm_workernode.sh"
copy_script_from_master "${master_vm_names[0]}"
run_script_on_workers "${cluster_join_script_name}" 
copy_and_modify_kubeconfig
untaint_master_node
copy_cert_from_master "${master_vm_names[0]}"
restart_allpod_allnamespace 
install_local_storage_class
installmetallb
createmetallbpool
#delete_resource 
echo $(date)
