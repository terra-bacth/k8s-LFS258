apt-get update && apt-get upgrade -y
apt-get install -y vim curl git wget gpg lsb-release ca-certificates
swapoff -a
modprobe overlay
modprobe br_netfilter
cat << EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
cat << EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y containerd.io
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null
sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g'     -i /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubeadm kubelet kubectl
apt-mark hold kubelet kubeadm kubectl
wget https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/calico.yaml
hostname -I
ip addr show
vim /etc/hosts
uname -a
vim /etc/hosts
cat /etc/hosts
vim kubeadm-config.yaml
kubeadm-config.yaml
kubeadm config validate --config=kubeadm-config.yaml
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.out
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
kubectl apply -f calico.yaml
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
