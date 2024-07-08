#ssh ubuntu@k8strainingmaster1.westus.cloudapp.azure.com
function installcni() {
    CNI_PLUGINS_VERSION="v1.1.1"
    ARCH="amd64"
    DEST="/opt/cni/bin"
    sudo mkdir -p "$DEST"
    curl  --insecure --retry 3 --retry-connrefused -fL "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGINS_VERSION/cni-plugins-linux-$ARCH-$CNI_PLUGINS_VERSION.tgz" | sudo tar -C "$DEST" -xz
}
function install_multus_3_9_3() {
   cd /home/ubuntu
   git clone -b v3.9.3  https://github.com/intel/multus-cni.git
#   sed -i 's/multus-conf-file=auto/multus-conf-file=\/tmp\/multus-conf\/70-multus.conf/g' /home/ubuntu/multus-cni/deployments/multus-daemonset.yml
   sed -i 's/stable/v3.9.3/g' /home/ubuntu/multus-cni/deployments/multus-daemonset.yml
   cat /home/ubuntu/multus-cni/deployments/multus-daemonset.yml | kubectl --kubeconfig /home/ubuntu/.kube/config apply -f -
}

installcni
install_multus_3_9_3

