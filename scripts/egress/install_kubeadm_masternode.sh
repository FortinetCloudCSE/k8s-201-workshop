#!/bin/bash -xe

dnsusername=$1
location=$2
EMAIL=$3

username=$(whoami)
nodename=$(hostname)

error_handler() {
    echo -e "\e[31mAn error occurred. Exiting...\e[0m" >&2
    tput bel
    tput bel
}

trap error_handler ERR

sudo apt-get update -y
sudo apt-get install socat conntrack -y
sudo apt-get install jq -y
sudo apt-get install apt-transport-https ca-certificates -y
sudo apt-get install hey -y
sudo apt-get install certbot -y

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

OS="xUbuntu_22.04"
VERSION="1.25"
echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | sudo tee  /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list


mkdir -p /usr/share/keyrings
sudo curl -L --retry 3 --retry-delay 5 https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg.tmp
sudo mv -f /usr/share/keyrings/libcontainers-archive-keyring.gpg.tmp /usr/share/keyrings/libcontainers-archive-keyring.gpg

sudo curl -L --retry 3 --retry-delay 5 https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg.tmp
sudo mv -f /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg.tmp /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

sudo apt-get update
sudo apt-get install cri-o cri-o-runc -y

sudo systemctl daemon-reload
sudo systemctl enable crio
sudo systemctl start crio

DOWNLOAD_DIR="/usr/local/bin"
sudo mkdir -p "$DOWNLOAD_DIR"
CRICTL_VERSION="v1.25.0"
ARCH="amd64"
curl  --insecure --retry 3 --retry-connrefused -fL "https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-$CRICTL_VERSION-linux-$ARCH.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz

function install_cni_binary() {
CNI_PLUGINS_VERSION="v1.1.1"
ARCH="amd64"
DEST="/opt/cni/bin"
sudo mkdir -p "$DEST"
curl  --insecure --retry 3 --retry-connrefused -fL "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGINS_VERSION/cni-plugins-linux-$ARCH-$CNI_PLUGINS_VERSION.tgz" | sudo tar -C "$DEST" -xz

}
#RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
RELEASE="v1.26.1"
ARCH="amd64"
DOWNLOAD_DIR="/usr/local/bin"
sudo mkdir -p "$DOWNLOAD_DIR"
cd $DOWNLOAD_DIR
sudo curl --insecure --retry 3 --retry-connrefused -fL --remote-name-all https://dl.k8s.io/release/$RELEASE/bin/linux/$ARCH/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

RELEASE_VERSION="v0.4.0"
curl --insecure --retry 3 --retry-connrefused -fL "https://raw.githubusercontent.com/kubernetes/release/$RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:$DOWNLOAD_DIR:g" | sudo tee /etc/systemd/system/kubelet.service

sudo mkdir -p /etc/systemd/system/kubelet.service.d

sudo curl --insecure --retry 3 --retry-connrefused -fL "https://raw.githubusercontent.com/kubernetes/release/$RELEASE_VERSION/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:$DOWNLOAD_DIR:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

sudo curl --insecure --retry 3 --retry-connrefused -fLO https://dl.k8s.io/release/v1.26.0/bin/linux/amd64/kubectl

sudo chmod +x /usr/local/bin/kubectl
alias k='kubectl'

sudo systemctl enable --now kubelet

sudo kubeadm config images pull --cri-socket unix:///var/run/crio/crio.sock --kubernetes-version=v1.26.1 --v=5

local_ip=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
CLUSTERDNSIP="10.96.0.10"
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS=--node-ip=$local_ip,--cluster-dns=$CLUSTERDNSIP
EOF

IPADDR=$local_ip
NODENAME=`hostname | tr -d '-'`
POD_CIDR="10.224.0.0/16"
SERVICE_CIDR="10.96.0.0/12"
FQDN="k8strainingmaster-$dnsusername-1.$location.cloudapp.azure.com"
echo $IPADDR $NODENAME  | sudo tee -a  /etc/hosts

sudo kubeadm reset -f
sudo kubeadm init --cri-socket=unix:///var/run/crio/crio.sock --apiserver-advertise-address=$IPADDR  --apiserver-cert-extra-sans=$IPADDR,$FQDN  --service-cidr=$SERVICE_CIDR --pod-network-cidr=$POD_CIDR --node-name $NODENAME  --token-ttl=0 -v=5

mkdir -p /home/${username}/.kube
sudo cp -f /etc/kubernetes/admin.conf /home/${username}/.kube/config
sudo chown ${username}:${username} /home/${username}/.kube/config
sudo mkdir -p /root/.kube
sudo cp -f /home/${username}/.kube/config /root/.kube/config 
kubectl --kubeconfig /home/${username}/.kube/config config set-cluster kubernetes --server "https://$local_ip:6443"

kubeadm token create --print-join-command > /home/${username}/workloadtojoin.sh
kubeadm config print join-defaults  > /home/${username}/kubeadm-join.default.yaml
echo '#sudo kubeadm join --config kubeadm-join.default.yaml' | sudo tee -a  /home/${username}/workloadtojoin.sh
sed -i 's/^kubeadm join/sudo kubeadm join/g' /home/${username}/workloadtojoin.sh
chmod +x /home/${username}/workloadtojoin.sh
cat /home/${username}/workloadtojoin.sh

cd $HOME
#sudo curl --insecure --retry 3 --retry-connrefused -fL https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl
sudo curl --insecure --retry 3 --retry-connrefused -fL https://github.com/projectcalico/calico/releases/download/v3.25.0/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl

sudo chmod +x /usr/local/bin/calicoctl
curl --insecure --retry 3 --retry-connrefused -fLO https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
kubectl --kubeconfig /home/${username}/.kube/config create -f tigera-operator.yaml
kubectl get namespace tigera-operator
kubectl rollout status deployment tigera-operator -n tigera-operator
curl --insecure --retry 3 --retry-connrefused -fLO https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
sed -i -e "s?blockSize: 26?blockSize: 24?g" custom-resources.yaml
sed -i -e "s?VXLANCrossSubnet?VXLAN?g" custom-resources.yaml
sed -i -e "s?192.168.0.0/16?10.224.0.0/16?g" custom-resources.yaml
sed -i '/calicoNetwork:/a\    containerIPForwarding: Enabled ' custom-resources.yaml
sed -i '/calicoNetwork:/a\    bgp: Disabled ' custom-resources.yaml
kubectl --kubeconfig /home/${username}/.kube/config create namespace calico-system
sleep 1
kubectl  get namespace calico-system
kubectl --kubeconfig /home/${username}/.kube/config apply  -f custom-resources.yaml
sleep 30 

kubectl rollout status deployment calico-kube-controllers -n calico-system
kubectl rollout status ds calico-node -n calico-system

kubectl get tigerastatus

kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system 

install_cni_binary

sudo certbot certonly --standalone -d $FQDN --preferred-challenges http --agree-tos -n -m $EMAIL --keep-until-expiring 
#sudo cp -R /etc/letsencrypt/live/$FQDN /home/${username} 
sudo cp /etc/letsencrypt/live/$FQDN/fullchain.pem /home/${username}
sudo cp /etc/letsencrypt/live/$FQDN/privkey.pem /home/${username}
sudo chmod 644 /home/${username}/privkey.pem

cat /home/${username}/workloadtojoin.sh
[ $? -eq 0 ] && echo "installation done on master node"
trap - ERR
