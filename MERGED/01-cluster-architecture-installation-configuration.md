# Part I — Cluster Architecture, Installation & Configuration

**CKA weight: ~25% — the largest single domain.**

This domain is where LFS258 and the CKA overlap the most, because LFS258 is itself a cluster-operations course. It covers
role-based access control of the control plane, the components' security posture, how the cluster is bootstrapped with
kubeadm, how the network plugin is installed, how the cluster is upgraded, how etcd is backed up and restored, and how
static pods and the scheduler are configured.

**Competencies covered in this part**

1. Manage role-based access control (RBAC)
2. Prepare underlying infrastructure for installing a Kubernetes cluster
3. Create and manage Kubernetes clusters using kubeadm
4. Manage the lifecycle of a Kubernetes cluster — upgrades, node joins/removals
5. Implement and configure a cluster network plugin
6. Configure a highly-available control plane
7. Provision underlying infrastructure to deploy a Kubernetes cluster
8. Perform a version upgrade on a Kubernetes cluster
9. Implement and configure an etcd cluster
10. Perform a backup and restore of an etcd cluster

> LFS258 maps its labs to this domain under the chapter names *Cluster Architecture*, *Installation and Configuration*,
> *API Access*, and *Security*. Your repo's labs `04.namespaces.sh`, `13-static-pod.sh`, `14-custom-scheduler.sh`,
> `15-metric-server.sh`, `21-etcd-backup-restore.*`, `21-etcd-multi-cluster.sh`, `22-certicates-dig.sh`,
> `acloudguru-etcd.sh`, `Networking/*` and `Security/t.yaml` all live here.

---

## 1.1 Control plane architecture — what each component actually does

| Component | Where it runs | Responsibility | Failure symptom |
|---|---|---|---|
| `kube-apiserver` | Control plane (static pod) | The *only* component that talks to etcd. Exposes the REST API; authenticates, authorises, admits | Every `kubectl` call hangs/fails; nothing else breaks immediately |
| `etcd` | Control plane (static pod) | The cluster's database — the *only* stateful component | Cluster reads work from cache briefly, then writes fail; all state lost on restore mistakes |
| `kube-scheduler` | Control plane (static pod) | Watches for unscheduled pods and assigns them to a node | New pods stay `Pending` forever |
| `kube-controller-manager` | Control plane (static pod) | Runs the control loops (node, replicaset, deployment, endpoint, serviceaccount…) | Deployments stop converging; deleted pods are not recreated |
| `cloud-controller-manager` | Control plane | Cloud-provider loops (node, route, service) | Cloud LB/route integration stops |
| `kubelet` | **Every** node | Node agent — turns pod specs into containers, reports status | Node goes `NotReady`, pods are evicted after toleration timeout |
| `kube-proxy` | Every node | Programs iptables/IPVS rules so `ClusterIP` services actually route | `ClusterIP` unreachable from other pods; DNS resolves but connections time out |

**Key mental model for the exam:** the control plane components are **static pods** — manifests dropped into
`/etc/kubernetes/manifests/`. Editing a file there makes the kubelet recreate the pod. This is *the* mechanism you use to
restore etcd (lab 21) and to change the scheduler (lab 14).

```bash
ls -la /etc/kubernetes/manifests/
# etcd.yaml            kube-controller-manager.yaml  kube-scheduler.yaml
# kube-apiserver.yaml  .kubelet-keep
```

**[Your note]** — `Labs/22-certicates-dig.sh` captured exactly this layout on a live controlplane node.

---

## 1.2 The API and `kubectl` — how a request flows

From `ApiAccess/commands.sh` and `Proxy/proxy-window2.sh` you explored the API directly:

```bash
cat $HOME/.kube/config
kubectl config view | grep server
kubectl proxy --api-prefix=/ &            # then curl http://127.0.0.1:8001/api/v1/pods
```

A `kubectl get pods` call does this:

1. Reads `~/.kube/config` → finds the current context → cluster server URL, CA data, user credentials.
2. Opens a TLS connection to `kube-apiserver` (port `6443`).
3. **Authentication** — the client certificate's CN (`kubernetes-admin`) becomes the *username*; the O (`system:masters`)
   becomes a *group*.
4. **Authorisation** — RBAC (or Node/ABAC/webhook) decides whether that user may `get` `pods`.
5. **Admission control** — mutating and validating webhooks run (e.g. the ingress admission controller you saw in
   `Labs/33-ingress-1.sh`: `ingress-nginx-admission-create`, `ingress-nginx-admission-patch`).
6. The object is read from / written to etcd and serialised back as JSON/YAML.

### Talking to the API with raw curl

```bash
export client=$(grep client-cert $HOME/.kube/config | cut -d" " -f 6)
export key=$(grep client-key-data $HOME/.kube/config | cut -d" " -f 6)
export auth=$(grep certificate-authority-data $HOME/.kube/config | cut -d" " -f 6)

echo $client | base64 -d - > ./client.pem
echo $key    | base64 -d - > ./client-key.pem
echo $auth   | base64 -d - > ./ca.pem

curl --cert ./client.pem --key ./client-key.pem --cacert ./ca.pem \
  https://k8scp:6443/api/v1/pods
```

**Create a pod straight over the API** (this is the `ApiAccess/my-json-nginx-pod.json` file in your repo):

```json
{
  "apiVersion": "v1",
  "kind": "Pod",
  "metadata": { "name": "nginx-pod" },
  "spec": {
    "containers": [
      { "name": "nginx-container", "image": "nginx" }
    ]
  }
}
```

```bash
curl --cert ./client.pem --key ./client-key.pem --cacert ./ca.pem \
  https://k8scp:6443/api/v1/namespaces/default/pods \
  -XPOST -H 'Content-Type: application/json' -d @my-json-nginx-pod.json
```

> **Exam note** — you are unlikely to be asked for raw curl, but you *will* be asked to explain the flow and to find the
> API server's advertise address, port and cert paths. Know `kubectl config view`, `kubectl cluster-info`, and
> `grep -i crt /etc/kubernetes/manifests/kube-apiserver.yaml`.

### Discover the API surface without a browser

```bash
kubectl api-resources
kubectl api-versions
kubectl get --raw /apis/networking.k8s.io/v1 | jq .
```

Your repo's `ApiAccess/serverresources.json` is a captured `kubectl get --raw /apis` dump, and
`ApiAccess/console.log` / `ApiAccess/pods.json` / `ApiAccess/pods.yaml` are captured API responses — useful as reference
when the cluster is unreachable and you need to remember a field name.

---

## 1.3 Namespaces — Lab `04.namespaces.sh`

Namespaces are the cluster's virtual-partitioning primitive. They scope *names*, RBAC, ResourceQuota, LimitRange and
NetworkPolicy — nothing else. Pods in different namespaces can still talk to each other by default.

```bash
kubectl get namespaces | wc
kubectl get pods -n research
kubectl run redis --image=redis -n finance
kubectl get pods --all-namespaces | grep -i blue
```

**Declarative form:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: research
  labels:
    name: research          # NetworkPolicy namespaceSelector matches this
```

```bash
kubectl create namespace research
kubectl config set-context --current --namespace=research   # stop typing -n
kubectl get pods -n research
kubectl delete namespace research    # deletes everything inside it
```

**ResourceQuota** — from `VolumesAndData/storage-quota.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storagequota
spec:
  hard:
    persistentvolumeclaims: "10"
    requests.storage: "500Mi"
```

> **Exam note** — if a pod creation fails with `forbidden: exceeded quota`, you need a ResourceQuota in that namespace,
> not a LimitRange. If it fails with `must specify cpu` / `memory`, you need a **LimitRange** with a default.

---

## 1.4 Bootstrapping a cluster with kubeadm

LFS258 devotes significant time to kubeadm because it is the CKA's *only* sanctioned way to build a cluster in the exam.
Your repo has `Security/t.yaml`, a complete kubeadm `InitConfiguration` + `ClusterConfiguration`:

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
  - groups:
      - system:bootstrappers:kubeadm:default-node-token
    token: abcdef.0123456789abcdef
    ttl: 24h0m0s
    usages:
      - signing
      - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 1.2.3.4
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: node
  taints: null
---
apiVersion: kubeadm.k8s.io/v1beta3
apiServer:
  timeoutForControlPlane: 4m0s
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: 1.28.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
scheduler: {}
```

### The canonical sequence

```bash
# 0. Prerequisites on every node
sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay && sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# 1. Container runtime (containerd) — required on every node
#    critical: SystemdCgroup = true in /etc/containerd/config.toml
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd && sudo systemctl enable containerd

# 2. kubeadm/kubelet/kubectl on every node
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# 3. Pull images first so the init is offline-safe
sudo kubeadm config images pull

# 4. Initialise the control plane
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=<CONTROL_PLANE_IP> \
  --upload-certs

# 5. Regular-user kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 6. Join the workers (token printed by kubeadm init)
sudo kubeadm join <CP_IP>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>

# 7. Network plugin (see 1.5)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### 4a. The `kubeadm init` flags your `basic-k8s` lab used

`basic-k8s/basic-labs.txt` builds its cluster with the `pandeysp1/ubuntu-k8s` installer script and then runs
`kubeadm init` by hand. The exact invocation, with every flag explained:

```bash
sudo -i
apt-get update
wget https://raw.githubusercontent.com/pandeysp1/ubuntu-k8s/refs/heads/main/install.sh
chmod +x install.sh

kubeadm init \
  --pod-network-cidr '10.244.0.0/16' \
  --service-cidr '10.96.0.0/16' \
  --ignore-preflight-errors=all \
  --skip-token-print

./install.sh

kubectl get nodes
```

| Flag | What it does | When you need it |
|---|---|---|
| `--pod-network-cidr` | The range pods get IPs from. flannel's default is `10.244.0.0/16`; calico's is `192.168.0.0/16`. | **Always** for flannel — the DaemonSet reads it from the config |
| `--service-cidr` | The range Services' virtual IPs come from. Default `10.96.0.0/12`. | Only if you want a non-default range |
| `--ignore-preflight-errors=all` | Skips **every** pre-flight check — swap, cgroups, ports, kernel modules. | When preflight fails for an environmental reason you cannot fix (common in a lab VM). It hides real problems, so use it knowingly |
| `--skip-token-print` | Does not print the `kubeadm join` command to stdout | When you plan to create the token later with `kubeadm token create --print-join-command` |

```bash
# If you skipped the join command, get it back
kubeadm token create --print-join-command
kubeadm token list
```

The installer script also sets up the `k` alias, which every command in your `basic-k8s` lab relies on:

```bash
alias k=kubectl
echo "alias k=kubectl" >> ~/.bashrc
```

> **Exam note** — `--pod-network-cidr` must match the CNI you are about to install. flannel wants `10.244.0.0/16`;
> calico wants `192.168.0.0/16`. Passing the wrong one means pods come up `NotReady` with
> `NetworkPluginNotReady` / `cni plugin not initialized`, and the symptom looks like a CNI bug rather than a flag
> mismatch. See Part I §1.5.

### 4b. `kubectl explain` — the in-terminal API reference

`basic-k8s` uses `k explain` throughout, and it is the single most under-used command on the exam. With no browser
available, it replaces the entire API documentation.

```bash
k explain pod
k explain pod.metadata
k explain pod.spec
k explain pod.spec.containers
k explain pod.spec.containers.env
k explain pod.spec.containers.env.valueFrom
k explain pod.spec.containers.resources
k explain pod.spec.containers.resources.limits
k explain pod.spec.containers.volumeMounts
k explain pod.spec.volumes
k explain pod.spec.volumes.emptyDir
k explain pod.spec.volumes.persistentVolumeClaim
k explain deployment
k explain deployment.spec.strategy
k explain deployment.spec.strategy.rollingUpdate
k explain deployment.spec.template.spec.containers
k explain service.spec.ports
k explain pvc.spec
k explain role.rules
k explain csr.spec
```

The output is a field reference with the type, whether it is required, and a description:

```bash
$ k explain pod.spec.containers.env.valueFrom
KIND:     Pod
VERSION:  v1

FIELD:    valueFrom <EnvVarSource>

DESCRIPTION:
     Source for the environment variable's value. Cannot be used if value is not
     empty.

FIELDS:
   configMapKeyRef  <ConfigMapKeySelector>
   fieldRef         <ObjectFieldSelector>
   resourceFieldRef <ResourceFieldSelector>
   secretKeyRef     <SecretKeySelector>
```

```bash
# --recursive prints the whole subtree — the fastest way to learn a schema
k explain deployment --recursive | less
k explain deployment --recursive | grep -A2 strategy
```

> **Exam note** — when a question asks for a field you are not sure exists (`lifecycle.preStop`? `readinessProbe`?
> `topologySpreadConstraints`?), run `k explain <resource> --recursive | grep <guess>` before writing the manifest.
> It costs five seconds and eliminates the "invalid field" rejection entirely.

### Stacked vs external etcd (this is a favourite CKA question)

| | Stacked etcd | External etcd |
|---|---|---|
| Where etcd runs | Static pod on the control plane, `dataDir: /var/lib/etcd` | Separate host(s) you manage with systemd |
| Backup/restore | Restore into a new dir, edit `/etc/kubernetes/manifests/etcd.yaml` | Restore into a new dir, edit `/etc/systemd/system/etcd.service`, `systemctl daemon-reload && systemctl restart etcd` |
| HA | 3 control planes, each with its own etcd | 3+ etcd hosts, N control planes |
| Certs | `/etc/kubernetes/pki/etcd/{ca,server,peer}.{crt,key}` | `/etc/etcd/pki/*.pem` (see `acloudguru-etcd.sh`) |

Your repo contains **both** patterns, which is why you should be comfortable with either:

* `Labs/21-etcd-backup-restore.sh` + `Labs/21-etcd-backup-restore.md` → **stacked**
* `Labs/21-etcd-multi-cluster.sh` + `acloudguru-etcd.sh` → **external** (systemd unit)

---

## 1.5 Installing and configuring a CNI plugin

Your repo has three CNI reference sets:

* `Networking/weave-spec.yaml` — a full Weave Net manifest (ServiceAccount, ClusterRole, ClusterRoleBinding, DaemonSet)
* `Networking/gce/plugins.sh` — the contents of `/opt/cni/bin` on a GCE-based cluster
* `Networking/kubeadmin/*` — Calico conflists and kubelet service/logs
* `Networking/kubeadmin/network-namespaces.sh`, `Networking/ubuntu-host-with-docker.sh` — raw `ip netns` experiments

### What lives in `/opt/cni/bin`

```
bandwidth   dhcp       firewall    host-device  ipvlan    macvlan   ptp
bridge      dummy      flannel     host-local   loopback  portmap   sbr
static      tap        tuning      vrf          vlan
```

The CNI contract is: **kubelet asks the CNI plugin to `ADD` a container to the network, and `DEL` it when the container
dies.** Kubernetes itself does not implement pod networking.

From `Networking/temp.md`:

> **Docker and CNI/CNM**
>
> Docker does not implement CNI. Docker has its own set of standards known as **CNM** (Container Network Model) which is
> another standard that aims at solving container networking challenges similar to CNI but with some differences.
>
> Due to the differences, these plugins don't natively integrate with Docker, meaning you can't run a Docker container and
> specify the network plugin to use a CNI and specify one of these plugins.
>
> **But that doesn't mean you can't use Docker with CNI at all.** You just have to work around it yourself.
> 1. create a Docker container without any network configuration — `docker network none`
> 2. manually invoke the bridge plugin yourself.
>
> That is pretty much how Kubernetes does it. When Kubernetes creates Docker containers, it creates them on the
> `none` network. It then invokes the configured CNI plugins who take care of the rest of the configuration.

### Pod-to-pod connectivity requirements

Every pod must be able to reach every other pod **without NAT**, and every node must be able to reach every pod. The CNI
plugin achieves this with a per-node bridge (`cni0`) plus an overlay or a routed network.

From `Labs/32-networking-explore-env.sh` — a live capture of exactly this:

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
2: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 ...
3: cni0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 ... inet 10.244.0.1/24
4: veth50e87d52@if2: ... master cni0 ... link-netns cni-b0ccf98c-...
5: veth01b630bb@if2: ... master cni0 ... link-netns cni-4ef6d342-...
```

Reading that output:

* `cni0` = the node's pod bridge, `10.244.0.1/24` = the node's pod subnet gateway.
* each `vethNNN@if2` = one end of a veth pair whose peer lives inside a pod's netns (`cni-<pod-uid>`).
* `flannel.1` = the overlay interface, `10.244.0.0/32` = this node's address in the cluster-wide overlay.

```bash
# Verify the whole chain
ip link show
ip -n <netns> addr            # inside a pod netns
ip route
kubectl get pods -o wide
bridge link show              # veths attached to cni0
```

### CNI and `br_netfilter` / IP forwarding

```bash
cat /proc/sys/net/ipv4/ip_forward       # must be 1
cat /proc/sys/net/bridge/bridge-nf-call-iptables   # must be 1 for kube-proxy
```

`Networking/ubuntu-host-with-docker.sh` captures a pre-CNI host: `docker0` exists with a `172.17.0.0/16` route,
`ip_forward` is already `1`, and `/etc/resolv.conf` has the systemd-resolved stub. Two notes worth keeping from that file:

> **About `/etc/hosts`**
> 1. it dominates the `/etc/resolv.conf`
> 2. `nslookup` and `dig` do not query it

That is why a DNS problem in the exam can look like "the pod resolves nothing" when the entry is in `/etc/hosts` but not in
DNS — `dig` will not show it.

### Weave Net manifest structure

`Networking/weave-spec.yaml` is the canonical shape of *any* CNI DaemonSet install:

1. `ServiceAccount weave-net` in `kube-system`
2. `ClusterRole weave-net` — `get/list/watch` on `pods`, `namespaces`, `nodes`
3. `ClusterRoleBinding` binding them
4. `Role` + `RoleBinding` for the CNI IPAM configmap in `kube-system`
5. `DaemonSet weave-net` — because exactly one agent must run per node

> **Exam note** — "install a CNI plugin" in the exam is almost always just `kubectl apply -f <url-or-provided-file>` then
> `kubectl get nodes` twice until the node conditions flip to Ready. Know how to read the DaemonSet's logs when it does not:
> `kubectl -n kube-system logs -l name=weave-net --tail=50`.

---

## 1.6 The kubelet and static pods — Lab `13-static-pod.sh`

A **static pod** is managed directly by the kubelet, not by the API server. The kubelet watches a directory
(`staticPodPath` in `/var/lib/kubelet/config.yaml`) and mirrors any manifest it finds there into the API server as a
**mirror pod** — with a name suffixed by the node name, and no controller owning it.

```bash
kubectl get pods --all-namespaces -o wide
kubectl describe pod kube-apiserver-controlplane -n kube-system | grep -i image
cd /etc/kubernetes/manifests/

kubectl run --restart=Never --image=busybox static-busybox \
  --dry-run=client -o yaml --command -- sleep 1000 \
  > /etc/kubernetes/manifests/static-busybox.yaml
```

**[Your note]** — this is one of the most valuable observations in the whole repo:

> *none of my edit tries of the file for new image worked until i overwrote the entire file as the following:*
> ```bash
> kubectl run --restart=Never --image=busybox:1.28.4 static-busybox \
>   --dry-run=client -o yaml --command -- sleep 1000 \
>   > /etc/kubernetes/manifests/static-busybox.yaml
> ```

The kubelet's file-watch only re-reads on a real content change; in-place edits that it does not observe will not take
effect. When a static pod "won't update", **regenerate the whole file**.

### Finding a static pod the hard way (exam scenario)

Your lab continues: *there is a static pod in the cluster, find it and delete it*.

```bash
ssh node01
ps -ef | grep /usr/bin/kubelet
#  root 12178 1 0 18:56 ?  /usr/bin/kubelet \
#    --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
#    --kubeconfig=/etc/kubernetes/kubelet.conf \
#    --config=/var/lib/kubelet/config.yaml \
#    --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \
#    --pod-infra-container-image=registry.k8s.io/pause:3.9

cat /var/lib/kubelet/config.yaml
```

**[Your note]** — and here is the trick the exam loves:

```yaml
# ...
staticPodPath: /etc/just-to-mess-with-you
# ...
```

The kubelet's `staticPodPath` is **not always `/etc/kubernetes/manifests`**. It is whatever
`/var/lib/kubelet/config.yaml` says. In this capture it points at `/etc/just-to-mess-withyou` — a directory deliberately
named to stop you assuming. **Always read the kubelet config before concluding a static pod does not exist.**

```bash
# Delete a static pod
rm /etc/just-to-mess-withyou/<pod>.yaml        # or /etc/kubernetes/manifests/<pod>.yaml
kubectl get pods -o wide                        # confirm the mirror pod disappears
```

> **Exam note** — you cannot `kubectl delete` a static pod; the kubelet recreates it. And you cannot edit a mirror pod's
> spec, because the kubelet overwrites it from the file.

---

## 1.7 A second scheduler — Lab `14-custom-scheduler.sh`

This lab is pure CKA. You deploy a *second* scheduler, give it its own profile name, and steer pods to it with
`schedulerName`.

### Discovery

```bash
kubectl get pods --all-namespaces
kubectl describe pod kube-scheduler-controlplane -n kube-system | grep -i image
kubectl get serviceaccounts -n kube-system | grep -i scheduler
kubectl get rolebinding -n kube-system | grep -i scheduler
kubectl get role -n kube-system | grep -i scheduler
```

### The three manifests

**1. The scheduler's config** — `Labs/scheduler/my-scheduler-config.yaml`:

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  - schedulerName: my-scheduler
leaderElection:
  leaderElect: false
```

`leaderElection.leaderElect: false` matters: two schedulers with leader election on would fight over the same lock, and
the second one would sit idle.

**2. A ConfigMap to hold it** — `Labs/scheduler/my-scheduler-configmap.yaml`:

```yaml
apiVersion: v1
data:
  my-scheduler-config.yaml: |
    apiVersion: kubescheduler.config.k8s.io/v1
    kind: KubeSchedulerConfiguration
    profiles:
      - schedulerName: my-scheduler
    leaderElection:
      leaderElect: false
kind: ConfigMap
metadata:
  name: my-scheduler-config
  namespace: kube-system
```

**3. The scheduler itself as a static pod** — `Labs/scheduler/my-scheduler.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: my-scheduler
  name: my-scheduler
  namespace: kube-system
spec:
  serviceAccountName: my-scheduler
  containers:
    - command:
        - /usr/local/bin/kube-scheduler
        - --config=/etc/kubernetes/my-scheduler/my-scheduler-config.yaml
      image: registry.k8s.io/kube-scheduler:v1.29.0
      livenessProbe:
        httpGet:
          path: /healthz
          port: 10259
          scheme: HTTPS
        initialDelaySeconds: 15
      name: kube-second-scheduler
      readinessProbe:
        httpGet:
          path: /healthz
          port: 10259
          scheme: HTTPS
      resources:
        requests:
          cpu: '0.1'
      securityContext:
        privileged: false
      volumeMounts:
        - name: config-volume
          mountPath: /etc/kubernetes/my-scheduler
  hostNetwork: false
  hostPID: false
  volumes:
    - name: config-volume
      configMap:
        name: my-scheduler-config
```

**Alternative image:** `# Alt image: quay.io/pandeysp/nginx-ambassador:latest` (only useful if you want a lightweight
stand-in for a "scheduler-like" control pod in a scratch lab — for a real second scheduler you need the actual
`kube-scheduler` binary, so prefer `registry.k8s.io/kube-scheduler`).

```bash
kubectl apply -f my-scheduler-configmap.yaml
kubectl apply -f my-scheduler-config.yaml
kubectl apply -f my-scheduler.yaml
kubectl get pods -n kube-system
kubectl delete pod my-scheduler -n kube-system        # force a re-read of the ConfigMap
```

### Steering a pod to the custom scheduler

`Labs/scheduler/nginx-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  schedulerName: my-scheduler          # <-- the whole point
  containers:
    - image: nginx
      # Alt image: quay.io/pandeysp/nginx:latest
      name: nginx
```

**[Your note]** from `Labs/14-custom-scheduler.sh`:

> ```
> kubectl describe kube-scheduler-controlplane -n kube-system | grep -i "image:"
> kubectl describe pod kube-scheduler-controlplane -n kube-system | grep -i "image:"
> ```

You need the **Pod** form; `kubectl describe` of a bare name resolves to nothing here because the object is a Pod, not a
Node-named resource. Also note `kubectl appy -f nginx-pod.yaml` — a typo you'll want to muscle-memory away:
`kubectl appy` → `kubectl apply`.

> **Exam note** — a pod with `schedulerName: my-scheduler` and no running scheduler sits in `Pending` with the event
> `no scheduler found for pod ... / no objects passed to scheduler`. That event message is the giveaway.

---

## 1.8 Metrics Server — Lab `15-metric-server.sh`

Required for `kubectl top` and for HPA/vpa to work.

```bash
kubectl get pods --all-namespaces
git clone https://github.com/kodekloudhub/kubernetes-metrics-server.git
cd kubernetes-metrics-server/
kubectl apply -f .
kubectl get all --all-namespaces

kubectl top nodes
kubectl top pod
kubectl top pod -n kube-system
```

The full manifest set in your repo (`Labs/metric-server/*`) is worth understanding because the **aggregation layer** is a
classic CKA topic:

| File | Purpose |
|---|---|
| `aggregated-metrics-reader.yaml` | ClusterRole letting the aggregator read `metrics.k8s.io` |
| `auth-delegator.yaml` | RoleBinding delegating auth decisions to the aggregator via `extension-apiserver-authentication` |
| `auth-reader.yaml` | RoleBinding letting the aggregator read the `extension-apiserver-authentication` ConfigMap in `kube-system` |
| `resource-reader.yaml` | ClusterRole for `nodes/metrics`, `pods`, `namespaces` stats |
| `metrics-apiservice.yaml` | The `APIService v1beta1.metrics.k8s.io` that points the API server at the aggregator |
| `metrics-server-deployment.yaml` | The aggregator Deployment |
| `metrics-server-service.yaml` | Its Service |

Key parts of `metrics-server-deployment.yaml`:

```yaml
spec:
  hostNetwork: true                    # so it can reach every kubelet on 10250
  serviceAccountName: metrics-server
  containers:
    - name: metrics-server
      image: k8s.gcr.io/metrics-server/metrics-server:v0.5.2
      args:
        - --cert-dir=/tmp
        - --metric-resolution=15s
        - --kubelet-preferred-address-types=InternalIP
        - --kubelet-insecure-tls       # <-- the flag that fixes self-signed kubelet certs
```

**Alternative images:** `# Alt image: quay.io/pandeysp/prom_metrics_expoter:latest` and
`# Alt image: quay.io/pandeysp/prometheus:latest` — your own metrics exporters, useful for the "instrument an app and
expose `/metrics`" style lab.

```bash
# Diagnose a broken metrics-server
kubectl -n kube-system logs deploy/metrics-server
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes | head
```

> **Exam note** — "metrics-server is deployed but `kubectl top nodes` returns an error" is almost always
> `--kubelet-insecure-tls` missing, or the `APIService` missing its CA bundle. Read the Deployment args first.

---

## 1.9 etcd: backup and restore — Labs `21-etcd-*`, `acloudguru-etcd.sh`

**etcd is the single most heavily tested item in Part I.** Two flavours, both present in your repo.

### 9a. Stacked etcd (kubeadm) — `Labs/21-etcd-backup-restore.sh`

```bash
# 1. Confirm where etcd lives and what certs it uses
kubectl get deployments | wc
kubectl get pods -o wide -n kube-system
kubectl describe pod etcd-controlplane -n kube-system | grep -i image
kubectl describe pod etcd-controlplane -n kube-system | grep -i crt
kubectl describe pod etcd-controlplane -n kube-system | grep -icrt
kubectl get services -n kube-system

# 2. Export the client certs for etcdctl
export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
etcdctl version

# 3. Take the snapshot
etcdctl --endpoints=https://127.0.0.1:2379 snapshot save /opt/snapshot-pre-boot.db

# 4. Restore it somewhere else
etcdctl --data-dir /var/lib/etcd-from-backup snapshot restore /opt/snapshot-pre-boot.db

# 5. Point the static pod at the new data dir
cd /etc/kubernetes/manifests/
vi etcd.yaml
```

The restore output, captured verbatim in `Labs/21-etcd-backup-restore.md`:

```
2022-03-25 09:19:27.175043 I | mvcc: restore compact to 2552
2022-03-25 09:19:27.266709 I | etcdserver/membership: added member 8e9e05c52164694d [http://localhost:2380] to cluster cdf818194e3a8c32
```

**[Your note]** from `Labs/21-etcd-backup-restore.md`:

> *In this case, we are restoring the snapshot to a different directory but in the same server where we took the backup
> (the controlplane node). As a result, the only required option for the restore command is the `--data-dir`.*

The only change needed in `/etc/kubernetes/manifests/etcd.yaml`:

```yaml
volumes:
  - hostPath:
      path: /var/lib/etcd-from-backup     # was /var/lib/etcd
      type: DirectoryOrCreate
    name: etcd-data
```

**[Your note]** — the two operational notes from the same file:

> **Note 1:** As the ETCD pod has changed it will automatically restart, and also kube-controller-manager and
> kube-scheduler. Wait 1-2 mins for these pods to restart. You can run the command:
> `watch "crictl ps | grep etcd"` to see when the ETCD pod is restarted.
>
> **Note 2:** If the etcd pod is not getting Ready 1/1, then restart it by
> `kubectl delete pod -n kube-system etcd-controlplane` and wait 1 minute.
>
> **Note 3:** This is the simplest way to make sure that ETCD uses the restored data after the ETCD pod is recreated.
> You don't have to change anything else.
>
> If you do change `--data-dir` to `/var/lib/etcd-from-backup` in the ETCD YAML file, make sure that the volumeMounts for
> etcd-data is updated as well, with the mountPath pointing to `/var/lib/etcd-from-backup`
> (THIS COMPLETE STEP IS OPTIONAL AND NEED NOT BE DONE FOR COMPLETING THE RESTORE)

### 9b. External etcd (systemd) — `Labs/21-etcd-multi-cluster.sh`, `acloudguru-etcd.sh`

```bash
kubectl cluster-info
kubectl get nodes
kubectl config view

# Switch between clusters in a multi-cluster setup
kubectl config use-context cluster1
kubectl config use-context cluster2

kubectl describe pod kube-apiserver-cluster2-controlplane -n kube-system | grep -i etcd
kubectl describe pod kube-apiserver-cluster1-controlplane -n kube-system | grep -i etcd
kubectl describe etcd-cluster1-controlplane -n kube-system | grep -i data

ssh etcd-server
ps -ef | grep etcd

ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/pki/ca.pem \
  --cert=/etc/etcd/pki/etcd.pem \
  --key=/etc/etcd/pki/etcd-key.pem member list
```

Snapshot from a *remote* cluster:

```bash
etcdctl --endpoints https://192.20.25.21:2379 snapshot save /opt/cluster2.db
```

Restore on a different machine, then edit the **systemd unit** (this is the only structural difference from 9a):

```bash
ETCDCTL_API=3
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/pki/ca.pem \
  --cert=/etc/etcd/pki/etcd.pem \
  --key=/etc/etcd/pki/etcd-key.pem \
  snapshot restore /root/cluster2.db --data-dir /var/lib/etcd-data-new

vi /etc/systemd/system/etcd.service        # add the new --data-dir
chown -R etcd:etcd /var/lib/etcd-data-new
ls -ld /var/lib/etcd-data-new/
systemctl daemon-reload
systemctl restart etcd

scp /opt/cluster2.db etcd-server:/root     # copy the snapshot to the target host
ssh etcd-server
kubectl get pods
sudo systemctl restart kube-scheduler
```

### 9c. The `acloudguru-etcd.sh` reference sheet

This file is a compact etcd cheat-sheet worth keeping:

```bash
# Listening / advertising
etcd --listen-client-urls=http://$PRIVATE_IP:2379 --advertise-client-urls=http://$PRIVATE_IP:2379
etcd --listen-client-urls=http://$IP1:2379,http://$IP2:2379,http://$IP3:2379 --advertise-client-urls=http://$IP1:2379,...

# Member list (remote, with certs)
ETCDCTL_API=3
etcdctl --endpoints 10.2.0.9:2379 \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt member list

# Snapshot + verify
ETCDCTL_API=3 etcdctl --endpoints $ENDPOINT snapshot save snapshot.db
ETCDCTL_API=3 etcdctl --write-out=table snapshot status snapshot.db

# Full restore with a new cluster identity (for an external etcd)
ETCDCTL_API=3 etcdctl snapshot restore /home/cloud_user/etcd_backup.db \
  --initial-cluster etcd-restore=https://10.0.1.101:2380 \
  --initial-advertise-peer-urls https://10.0.1.101:2380 \
  --name etcd-restore \
  --data-dir /var/lib/etcd

# The full stop/restore/start cycle
sudo systemctl stop etcd
sudo rm -rf /var/lib/etcd
sudo chown -R etcd:etcd /var/lib/etcd
sudo systemctl start etcd
```

**[Your note]** from that file:

> `#do not forget scaling controller manager`

That is the classic post-restore failure: kube-controller-manager (and kube-scheduler) were talking to the old etcd, so
after a restore they may need a restart, and they are static pods — `kubectl delete pod -n kube-system
kube-controller-manager-controlplane` or restart the systemd units on an external control plane.

### 9d. Growing an existing cluster

```bash
export ETCD_NAME="member4"
export ETCD_INITIAL_CLUSTER="member2=http://10.0.0.2:2380,member3=http://10.0.0.3:2380,member4=http://10.0.0.4:2380"
export ETCD_INITIAL_CLUSTER_STATE=existing
```

`ETCD_INITIAL_CLUSTER_STATE=existing` is the flag people forget: with `new`, etcd wipes the existing cluster identity.

> **Exam note** — memorize the difference between `snapshot save` (writes a `.db` file), `snapshot status` (inspects it)
> and `snapshot restore` (creates a *new* data dir). Restoring never modifies the snapshot. And remember:
> **stacked → edit `/etc/kubernetes/manifests/etcd.yaml`; external → edit `/etc/systemd/system/etcd.service`.**

### 9e. etcd as a **systemd service** — `my-steps-etcd-systemctl.sh`, `practice-on-paper/practice-on-paper.sh`

When etcd runs as a systemd unit rather than a static pod, there is no manifest to edit — you work with the unit, the data
directory and the certificate paths in the unit file. Your two files capture the whole flow, and they include three
operational gotchas that are not obvious from the docs.

**Step 1 — find the endpoint and the certificates.** Do not guess; read them out of the unit.

```bash
systemctl cat etcd.service
systemctl cat etcd.service | grep -i listen
#   ExecStart=/usr/local/bin/etcd \
#     --listen-client-urls https://10.0.1.101:2379 \
#     --trusted-ca-file=/home/cloud_user/etcd-certs/ca.crt \
#     --cert-file=/home/cloud_user/etcd-certs/server.crt \
#     --key-file=/home/cloud_user/etcd-certs/server.key

ls -l /home/cloud_user/etcd-certs
```

**[Your note]** — the ordering, verbatim:

> *#find the listen url*
> *#locate where the instructions tell you the keys*

**Step 2 — take the snapshot.**

```bash
mkdir -p /home/cloud_user/

etcdctl --endpoints=https://10.0.1.101:2379 \
  --cacert=/home/cloud_user/etcd-certs/ca.crt \
  --cert=/home/cloud_user/etcd-certs/server.crt \
  --key=/home/cloud_user/etcd-certs/server.key \
  snapshot save /home/cloud_user/etcd_backup.db

ls -lrt /home/cloud_user/etcd_backup.db
```

**Step 3 — stop etcd, clear the data dir, restore.**

```bash
systemctl stop etcd

sudo rm -rf /var/lib/etcd/

sudo etcdctl --data-dir /var/lib/etcd snapshot restore /home/cloud_user/etcd_backup.db

# this is very important
chown -R etcd:etcd /var/lib/etcd

systemctl restart etcd.service
systemctl status etcd
```

**[Your note]** — the three gotchas, verbatim:

> *you need to run it with sudo otherwise it does not allow you to mkdir /var/lib/etcd*
>
> *you need to stop `systemctl stop etcd` before removing `/var/lib/etcd`*

Each one corresponds to a real failure mode:

| Missing step | Symptom |
|---|---|
| No `sudo` on the restore | `mkdir /var/lib/etcd: permission denied` — the restore aborts partway and leaves a partial data dir |
| No `systemctl stop etcd` first | etcd keeps its file handles open; the restored data is either overwritten or etcd refuses to start with `member ID changed` / `walpb` errors |
| No `chown -R etcd:etcd` | etcd starts as user `etcd` but the restored files are owned by `root`, so it cannot read them: `permission denied` in `journalctl -u etcd` |

**Step 4 — restart whatever reads etcd.** On a systemd-etcd cluster the control plane usually runs as static pods, so the
kubelet restarts them automatically once etcd is healthy again. If they do not:

```bash
sudo systemctl restart kubelet
sudo crictl ps -a | grep -E 'etcd|apiserver|scheduler|controller'
```

**Step 5 — the network triage you appended to the same file.** The `my-steps-etcd-systemctl.sh` capture also contains a
generic network check that is useful on its own:

```bash
ip link show
ip addr show
ip route show
ip neigh show
cat /proc/sys/net/ipv4/ip_forward
systemctl status kubelet
systemctl status containerd
systemctl status etcd
```

> **Exam note** — when etcd is a systemd service, the `snapshot restore` command does **not** need `--cacert/--cert/--key`
> (it is a local file operation, no endpoint contacted), but it **does** need `--data-dir`. Passing the TLS flags anyway
> is harmless. Getting the `--data-dir` wrong is the failure that costs the question.

---

## 1.10 Inspecting the control plane's TLS — Lab `22-certicates-dig.sh`

```bash
ls /etc/kubernetes/manifests/

cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -i crt
#      - --client-ca-file=/etc/kubernetes/pki/ca.crt
#      - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
#      - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
#      - --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
#      - --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
#      - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
#      - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt

cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -i kubelet
#      - --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
#      - --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
#      - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname

cat /etc/kubernetes/manifests/etcd.yaml | grep -i crt
#      - --cert-file=/etc/kubernetes/pki/etcd/server.crt
#      - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
#      - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
#      - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

### The PKI layout on a kubeadm control plane

```
/etc/kubernetes/pki/
├── ca.crt / ca.key                          # the cluster CA — signs everything
├── apiserver.crt / apiserver.key            # the API server's serving cert (SANs: CP IP, LB IP, kubernetes.default...)
├── apiserver-etcd-client.crt/.key           # API server → etcd
├── apiserver-kubelet-client.crt/.key        # API server → kubelet
├── front-proxy-ca.crt/.key                  # front-proxy CA
├── front-proxy-client.crt/.key              # aggregation layer
├── sa.key / sa.pub                          # ServiceAccount token signing
└── etcd/
    ├── ca.crt                               # separate etcd CA
    ├── server.crt / server.key              # etcd serving
    ├── peer.crt / peer.key                  # etcd peer traffic (port 2380)
    └── healthcheck-client.crt/.key
```

```bash
# Read any cert
openssl x509 -in /etc/kubernetes/pki/etcd/ca.crt -text -noout

# The fields you need
openssl x509 -in apiserver.crt -noout -subject -issuer -dates
openssl x509 -in apiserver.crt -noout -ext subjectAltName
openssl x509 -in apiserver.crt -noout -purpose

# Verify a cert chains to the CA
openssl verify -CAfile ca.crt apiserver.crt
```

The `openssl x509 -text -noout` output captured in your lab:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 3712485603828999599 (0x338565fcb1faa5af)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = etcd-ca
        Validity
            Not Before: Apr  6 13:41:33 2024 GMT
            Not After : Apr  4 13:46:33 2034 GMT
        Subject: CN = etcd-ca
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus: 00:af:cb:10:de:61:85:03:...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
```

> **Exam note** — the two questions you must be able to answer from this data: *"is this cert expired?"* (Not After) and
> *"does this cert have the right SAN?"* (the IP/DNS entries). An expired or wrong-SAN API server cert produces exactly
> the `x509: certificate is valid for X, not Y` error you'd see in a kubelet log.

---

## 1.11 Cluster upgrades

```bash
# 1. Check what's available and what you're on
kubectl version --short
kubeadm version
kubectl get nodes
sudo apt-get update
apt-cache policy kubeadm | head

# 2. Upgrade the FIRST control plane node
sudo apt-mark unhold kubeadm && sudo apt-get update
sudo apt-get install -y kubeadm=1.31.0-1.1
sudo apt-mark hold kubeadm

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.31.0        # first CP only
sudo apt-mark unhold kubelet kubectl && sudo apt-get update
sudo apt-get install -y kubelet=1.31.0-1.1 kubectl=1.31.0-1.1
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# 3. Additional control plane nodes
sudo kubeadm upgrade node

# 4. Workers — one at a time
kubectl drain <node> --ignore-daemonsets
# ... install new kubeadm/kubelet, then:
sudo kubeadm upgrade node
sudo systemctl restart kubelet
kubectl uncordon <node>
```

> **Exam note** — the ordering rules that get graded: **kubeadm before kubelet**, **control plane before workers**,
> **one minor version at a time**, **drain before touching a worker**, and `kubeadm upgrade apply` only on the *first*
> control plane (subsequent ones use `kubeadm upgrade node`).

### 11a. The upgrade sequence you actually ran — `cluster-upgrade/history.sh`, `lighteningexam.sh`, `practice-on-paper.sh`

Your three upgrade captures agree on the shape, and each adds a detail the others omit. Merged:

```bash
# ── 1. Snapshot the state first ────────────────────────────────────────────
kubectl get nodes -o wide
kubectl version --short
sudo kubeadm upgrade plan

# ── 2. Drain the control plane node ────────────────────────────────────────
sudo kubectl drain controlplane --ignore-daemonsets
# your capture shows the fuller form:
kubectl drain <node> --force --delete-emptydir-data

# ── 3. Upgrade kubeadm on the FIRST control plane ──────────────────────────
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.3-1.1
sudo apt-mark hold kubeadm

sudo kubeadm upgrade apply v1.29.3

# ── 4. Upgrade kubelet + kubectl on the SAME control plane ─────────────────
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.29.3-1.1 kubectl=1.29.3-1.1
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

# ── 5. Bring the control plane back ────────────────────────────────────────
kubectl uncordon controlplane          # ← NO sudo. See the note below.

# ── 6. Additional control plane nodes ──────────────────────────────────────
sudo kubeadm upgrade node
sudo systemctl restart kubelet

# ── 7. Workers, ONE AT A TIME ──────────────────────────────────────────────
kubectl drain node01 --ignore-daemonsets

ssh node01
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.3-1.1
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node

sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.29.3-1.1 kubectl=1.29.3-1.1
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
exit

kubectl uncordon node01                # ← again, no sudo

# ── 8. Verify ──────────────────────────────────────────────────────────────
kubectl get nodes -o wide
kubectl version --short
```

**[Your note]** — from `cluster-upgrade/history.sh`, and it is a genuine trap:

> *`kubectl uncordon` must **not** be run with `sudo`*

Why: `uncordon` reads the kubeconfig from `$HOME/.kube/config`. Under `sudo`, `$HOME` is `/root`, which has no kubeconfig
— so the command fails with `The connection to the server localhost:8080 was refused`. Every `kubectl` command in an
upgrade is run **without** `sudo`; only the package installs, `systemctl` and `kubeadm upgrade apply/node` need it.

**[Your note]** — from the same file, the two drain flags that were needed:

> *`kubectl drain <node> --force --delete-emptydir-data`*

| Flag | Why it was needed |
|---|---|
| `--force` | A bare pod with no controller was running — `drain` refuses to evict it, because the pod would be lost forever |
| `--delete-emptydir-data` | A pod using an `emptyDir` volume was running — `drain` refuses, because the data would be lost |

**The deployment-inventory step** from `lighteningexam.sh`, which is a *separate* exam question in its own right:

```bash
# Write a deployment inventory (name + replicas) to a file
kubectl get deployments -A \
  -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas \
  > /opt/admin2406_data/deployments.txt

# Or with a label selector, if the question names one
kubectl get deployments -A -l tier=backend -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas
```

**The kubeconfig step** from the same file — a very common CKA sub-task:

```bash
kubectl config set-cluster cka \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --server=https://172.30.1.2:6443 \
  --kubeconfig=/root/CKA/admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/pki/admin.crt \
  --client-key=/etc/kubernetes/pki/admin.key \
  --embed-certs=true \
  --kubeconfig=/root/CKA/admin.kubeconfig

kubectl config set-context admin@cka \
  --cluster=cka --user=admin \
  --kubeconfig=/root/CKA/admin.kubeconfig

kubectl config use-context admin@cka --kubeconfig=/root/CKA/admin.kubeconfig
kubectl get nodes --kubeconfig=/root/CKA/admin.kubeconfig
```

Note the `--kubeconfig=` flag on **every** command — without it, `kubectl config set-*` writes to `~/.kube/config` and
your new file stays empty. That is the single most common mistake in this task.

**The `set image` step** from the same file — the same container-name gotcha as `mock-exam-2.sh`:

```bash
kubectl set image deployment/nginx-deploy nginx=nginx:1.17
#                                     ^^^^^ the CONTAINER name, not the deployment name
```

**The PVC debug step** — a troubleshooting pattern worth knowing:

```bash
kubectl get pvc alpha-mysql -n <ns>
kubectl describe pvc alpha-mysql -n <ns>
# Events: ... waiting for first consumer to be created before binding
# → the StorageClass is WaitForFirstConsumer; the pod must exist first
kubectl get sc slow -o yaml | grep volumeBindingMode
```

> **Exam note** — a PVC stuck `Pending` with the event `waiting for first consumer` is not broken. Create the pod that
> references it, and the binding happens immediately. This is covered in Part IV §4.5.

### 11b. `kubeadm token` and the CA hash for adding nodes

From `shells/cp-commands.sh` and `shells/worker-commands.sh`:

```bash
# On the control plane
kubeadm token list
kubeadm token create --print-join-command
kubeadm token create --ttl 24h --print-join-command

# Or build the join command by hand
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform der 2>/dev/null \
  | openssl dgst -sha256 -hex | sed 's/^.* //'
# 7d3f...c9e1

kubeadm join 172.30.1.2:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:7d3f...c9e1

# With --upload-certs (for additional control planes)
kubeadm init --control-plane-endpoint "172.30.1.2:6443" --upload-certs
kubeadm join ... --control-plane --certificate-key <key>
```

> **Exam note** — the CA hash one-liner is worth memorising verbatim. It is asked for directly, and there is no way to
> derive it from memory. The `2>/dev/null` matters: on newer OpenSSL, `openssl rsa -pubin` prints a deprecation warning
> to stderr that otherwise pollutes the output.

---

## 1.12 Node lifecycle — Lab `20-drain-uncordon-cordon.sh`

```bash
kubectl get pods -o wide

kubectl drain node01
kubectl drain node01 --ignore-daemonsets

kubectl get pods -o wide
kubectl get nodes

kubectl cordon node01
# When you use the drain command to temporarily evict pods for maintenance,
# Kubernetes has to ensure that the pods will not be lost forever.
# That's why it checks whether the pod is created as part of a replica set that maintains the desired state by asserting a number;
# otherwise, it knows that the pod will be lost forever and will not evict the pod unless you use the force flag.
# when you are done then:
kubectl uncordon node01
```

The full flag set for the exam:

```bash
kubectl drain node01 \
  --ignore-daemonsets \        # DaemonSet pods would block the drain forever
  --delete-emptydir-data \     # pods using emptyDir would block it
  --force \                    # bare pods / pods with no controller
  --grace-period=60 \
  --timeout=60s
```

| Command | Effect |
|---|---|
| `kubectl cordon node01` | Marks the node `Unschedulable`. Existing pods keep running. |
| `kubectl drain node01` | Cordons **and** evicts every evictable pod. |
| `kubectl uncordon node01` | Clears the `Unschedulable` taint. Does **not** bring evicted pods back — their controllers must reschedule them. |

> **Exam note** — `drain` failing with `error: cannot delete DaemonSet-managed Pods` is the single most common
> node-lifecycle failure. `--ignore-daemonsets` is the answer. `--delete-emptydir-data` is the second most common.

---

## 1.13 Part I self-check

1. What is the difference between a static pod and a mirror pod? How do you find the static pod's source directory?
2. Where does kubeadm stack etcd's data, and how do you change it after a restore?
3. Your `kubectl top nodes` returns `Metrics API not available`. Name three things you check.
4. A pod is `Pending` with event `no scheduler found`. What is missing and where do you look?
5. Write the exact commands to back up etcd and restore it on the same control plane node.
6. What is `ETCD_INITIAL_CLUSTER_STATE=existing` for?
7. Which kubeadm subcommand runs only on the first control plane during an upgrade?
8. `kubectl drain node01` refuses to evict a pod. Name the three flags that could fix it.
