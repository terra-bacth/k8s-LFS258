---
title: "Kubernetes CKA + LFS258 — Merged Lab & Study Guide"
date: 2026-09-27
sources:
  - terra-bacth/k8s-LFS258 (LFS258 lab set)
  - CKA exam curriculum
  - quay.io/pandeysp container image registry
status: "Appendix C reserved for the user's basic-k8s CKA notes"
---

> **One file, nine sections.** This is the complete merged document. The same content is also available as nine
> separate files in this `MERGED/` directory (`00-index.md` … `92-appendix-c-cka-notes.md`) if you prefer to read or
> edit it in pieces.

## Kubernetes CKA + LFS258 — Merged Lab & Study Guide

**Sources merged in this document**

| Source | What it contributes |
|---|---|
| `terra-bacth/k8s-LFS258` (this repo) | Every lab script, YAML manifest and personal annotation you wrote while working through **LFS258 – Kubernetes Fundamentals** |
| CKA exam curriculum | The domain structure, concept explanations, exam-day patterns and gotchas that LFS258 does not cover |
| `quay.io/pandeysp/*` registry | Your own container images, offered as alternatives in every lab so nothing depends on a public registry being reachable |

**How to use it**

1. Work top to bottom — the parts follow the **CKA exam domain weighting**, not the LFS258 chapter order.
2. Every lab is presented as **Objective → Commands → Manifest → Explanation → Exam notes**, and every manifest carries a commented
   `# Alt image: quay.io/pandeysp/...` line so you can swap images without hunting through the repo.
3. Anything you wrote as a *personal annotation* (the `#` comments in the original scripts) is preserved verbatim and tagged
   **[Your note]** — those are your own hard-won gotchas, not filler.
4. Appendix B is a full **LFS258 → CKA crosswalk** so you can trace any repo file back to an exam objective.
5. Appendix C is a reserved slot for your `basic-k8s` CKA notes (see the note at the end of this index).

---

## Table of Contents

| Part | CKA Domain | Weight | Labs covered |
|---|---|---|---|
| [Part I](#part-i--cluster-architecture-installation--configuration) | Cluster Architecture, Installation & Configuration | ~25% | 04, 13, 14, 15, 21 (etcd), kubeadm, CNI, kubelet |
| [Part II](#part-ii--workloads--scheduling) | Workloads & Scheduling | ~15% | 01, 02, 03, 06, 07, 08, 09, 10, 11, 12, 18, 19, Deployments/* |
| [Part III](#part-iii--services--networking) | Services & Networking | ~20% | 05, 30, 32, 33, Networking/*, Ingress/*, Services/* |
| [Part IV](#part-iv--storage) | Storage | ~10% | 16, 31, VolumesAndData/* |
| [Part V](#part-v--security) | Security | ~20% | 17, 22, 23, 24, 25, 26, 27, 28, 29, Security/* |
| [Part VI](#part-vi--troubleshooting) | Troubleshooting | ~10% | 15, 20, ApiAccess/*, Proxy/*, metric-server |
| [Appendix A](#appendix-a--quayiopandeysp-image-catalog) | Your `quay.io/pandeysp/*` image catalog | — | 33 images / 41 tags |
| [Appendix B](#appendix-b--lfs258--cka-crosswalk) | Repo file → exam objective mapping | — | 255 files |
| [Appendix C](#appendix-c--your-basic-k8s-cka-notes) | Your `basic-k8s` CKA notes (reserved) | — | — |

---

## Lab environment assumptions

Everything below assumes a **kubeadm cluster** with a `controlplane` node and at least one `node01`, containerd as the
runtime, and flannel as the CNI — matching the environment your lab transcripts were captured in
(`Services/docker-desktop-node-spec.log`, `Labs/32-networking-explore-env.sh`).

```bash
# Sanity check before you start any lab
kubectl get nodes -o wide
kubectl cluster-info
kubectl version --short
kubectl config current-context
```

### Namespace shorthand used throughout

| Namespace | Purpose in these labs |
|---|---|
| `default` | Most labs |
| `kube-system` | Control plane, metrics-server, custom scheduler |
| `blue`, `research`, `finance`, `development`, `production` | RBAC labs |
| `elastic-stack` | Elasticsearch + Kibana + sidecar labs |
| `app-space`, `critical-space`, `users-backend`, `baz`, `accounting`, `andromeda` | Networking / Ingress labs |

---

## The `kubectl` patterns you will use in every single lab

These are worth memorising before Part I — roughly a third of the exam is "produce the YAML, then edit it".

```bash
# 1. Generate YAML instead of writing it (the single biggest time-saver in the exam)
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create deployment web --image=nginx --dry-run=client -o yaml > deploy.yaml
kubectl create job hi --image=busybox --dry-run=client -o yaml > job.yaml
kubectl create cronjob hi --image=busybox --schedule="* * * * *" --dry-run=client -o yaml > cj.yaml
kubectl expose deployment web --port=80 --dry-run=client -o yaml > svc.yaml
kubectl create configmap cm --from-literal=k=v --dry-run=client -o yaml > cm.yaml
kubectl create secret generic s --from-literal=k=v --dry-run=client -o yaml > s.yaml
kubectl create serviceaccount sa --dry-run=client -o yaml > sa.yaml
kubectl create clusterrole cr --verb=get,list --resource=pods --dry-run=client -o yaml > cr.yaml
kubectl create role r --verb=get,list --resource=pods -n dev --dry-run=client -o yaml > role.yaml
kubectl create rolebinding rb --role=r --user=dev -n dev --dry-run=client -o yaml > rb.yaml
kubectl create ingress ing --rule="host/path=svc:80" --dry-run=client -o yaml > ing.yaml

# 2. Explain — read the schema instead of guessing a field name
kubectl explain pod.spec.containers.securityContext
kubectl explain deployment.spec.strategy.rollingUpdate
kubectl explain pvc.spec.resources

# 3. Quickly patch / scale / label / annotate without an editor
kubectl scale deploy web --replicas=5
kubectl patch deploy web -p '{"spec":{"replicas":5}}'
kubectl label node node01 disk=ssd
kubectl annotate pod p1 description="my pod"
kubectl set image deploy web nginx=nginx:1.25

# 4. Inspect fast
kubectl get pod -o wide
kubectl get pod -o jsonpath='{.status.podIP}'
kubectl get pod -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
kubectl get events --sort-by=.lastTimestamp
kubectl get all --show-labels
```

> **Exam note** — `--dry-run=client -o yaml` is *client-side only*: it does not create the object, so it is safe to run even
> when you are unsure whether the object already exists. It costs you nothing and it guarantees correct apiVersion/kind.

---

## A note on your `basic-k8s` notes file

You mentioned an attached `basic-k8s` text file containing your CKA labs. The attachment did **not** arrive in this
workspace — only the LFS258 repo is present here. To keep you unblocked, this document was built from:

* the complete contents of this repository (all 255 non-`.git` files), and
* the current CKA curriculum structure.

**Appendix C is deliberately left as a reserved, pre-formatted slot.** Re-share the `basic-k8s` file (paste its text, or drop
the file into the repo) and it will be folded in verbatim, with each lab cross-linked into the matching Part above.


\pagebreak

## Part I — Cluster Architecture, Installation & Configuration

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


\pagebreak

## Part II — Workloads & Scheduling

**CKA weight: ~15%**

This is where your repo is richest — labs `01` through `12`, `18`, `19`, plus the whole `Deployments/` folder. It covers
application deployments, the controllers that keep them running, and every mechanism that decides *which* node a pod
lands on and *whether* it is allowed to stay there.

**Competencies covered in this part**

1. Understand deployments and how to perform rolling updates and rollbacks
2. Use ConfigMaps and Secrets to configure applications
3. Know how to scale applications
4. Understand the primitives used to create robust, self-healing application deployments
5. Understand how resource limits can affect pod scheduling
6. Be aware of manifest management and common tooling
7. Configure Pod Admission and Security Context
8. Use labels, selectors and annotations effectively
9. Configure a pod's readiness, liveness and startup probes
10. Use the Downward API
11. Work with multi-container pods and init containers
12. Perform a rolling update / rollback on a Deployment

---

## 2.1 Pods — Lab `01-pods.sh`

The smallest deployable unit. One pod = one or more containers that share a network namespace, a PID namespace (opt-in)
and volumes.

```bash
kubectl get pods
kubectl run nginx --image=nginx
kubectl describe pod newpods-vpc8l | grep -i image
kubectl get pods -o wide
kubectl describe pod webapp | grep -i "container id"
kubectl describe pod webapp | grep -i "image"
kubectl describe pod webapp
kubectl events pod webapp
```

### The ImagePullBackOff drill — the most instructive part of your lab

```bash
kubectl run redis --image=redis123          # deliberately wrong image
kubectl replace pod redis --image=redis      # does NOT work
kubectl get pod redis -o yaml
kubectl delete pod redis
kubectl run redis --image=redis              # correct
```

**[Your note]** — you discovered that `kubectl replace` cannot fix a pod's image. Two reasons:

1. `kubectl replace` requires the full object and re-`PUT`s it, but **most pod fields are immutable after creation**
   (`spec.containers[*].image` is *not* in the immutable set for `kubectl replace`, but the running pod's container is
   never recreated by it — kubelet keeps the old container).
2. Even if the API accepted the update, the kubelet does not restart the container.

The reliable fix is **delete and recreate**:

```bash
kubectl delete pod redis
kubectl run redis --image=redis
# or, in one step for a controller-managed workload:
kubectl set image deploy/redis redis=redis
```

**[Your note]** — the explanation of the `1/1` you saw:

> ```text
> NAME                    READY   STATUS        RESTARTS   AGE
> # new-replica-set-lff4m   1/1     Running       0          101s
> # 1/1 means there is one container in the pod and 1 is running so it is about :"containers" inside pod
> ```

`READY` is `readyContainers / totalContainers`, not pods. A sidecar pod shows `2/2`.

### Pod lifecycle phases

| Phase | Meaning |
|---|---|
| `Pending` | Accepted by the API server, not yet scheduled or still pulling images |
| `Running` | At least one container is running or restarting |
| `Succeeded` | All containers exited 0 and will not restart |
| `Failed` | All containers exited, at least one non-zero |
| `Unknown` | The node is unreachable, kubelet cannot report |

`ContainerStatuses` reasons you will see in `kubectl describe`: `CrashLoopBackOff`, `ImagePullBackOff`,
`ErrImagePull`, `CreateContainerConfigError`, `Init:Error`, `Init:0/2`, `PodInitializing`.

### Pod spec skeleton to memorise

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
  namespace: default
  labels:
    app: myapp
  annotations:
    description: "my pod"
spec:
  restartPolicy: Always            # Always | OnFailure | Never
  nodeName: node01                # bypasses the scheduler entirely
  schedulerName: default-scheduler
  serviceAccountName: default
  securityContext: {}             # pod-level
  initContainers: []              # run to completion before containers[]
  containers:
    - name: app
      image: nginx
      # Alt image: quay.io/pandeysp/nginx:latest
      imagePullPolicy: IfNotPresent   # Always | IfNotPresent | Never
      command: []                 # overrides ENTRYPOINT
      args: []                    # overrides CMD
      ports:
        - containerPort: 80
      env: []
      envFrom: []
      resources:
        requests: {cpu: 100m, memory: 128Mi}
        limits:   {cpu: 250m, memory: 256Mi}
      volumeMounts: []
      livenessProbe: {}
      readinessProbe: {}
      startupProbe: {}
      lifecycle: {}
      securityContext: {}         # container-level
  volumes: []
  tolerations: []
  affinity: {}
```

> **Exam note** — `kubectl run` changed semantics across versions. In ≥1.25 `kubectl run foo --image=nginx` creates a
> **Pod** by default (older versions created a Deployment). Always add `--restart=Never` to be explicit about a Pod, and
> `--dry-run=client -o yaml` to get a manifest instead of the object.

---

## 2.2 ReplicaSets — Lab `02-replicasets.sh`

A ReplicaSet guarantees N identical pods at all times. In practice you almost always create it through a Deployment.

```bash
kubectl get rs
kubectl describe pod new-replica-set | grep -i image
kubectl get rs -o wide
kubectl get pods -o wide
kubectl delete pod new-replica-set-g67sm
```

### The self-healing demonstration

```bash
kubectl edit rs new-replica-set
kubectl get rs new-replica-set -o yaml
kubectl get pods
kubectl delete pod new-replica-set-m5clc
kubectl delete pod new-replica-set-t6fjf
kubectl delete pod new-replica-set-rbgr8
kubectl delete pod new-replica-set-6wknp
kubectl get pods
```

**[Your note]** — this is the single most important insight in the lab, verbatim:

> *after i edited replicaset the pods were not affected automatically until i deleted the pods and replicaset created new
> ones and those were healthy.*

The ReplicaSet controller only reconciles **count**, not **content**. Editing `.spec.template` of a live ReplicaSet
changes nothing about existing pods — only the next pod it creates will use the new template. A **Deployment** fixes this
by creating a *new* ReplicaSet on every template change.

### Scaling

```bash
kubectl scale rs new-replica-set --replicas=5
kubectl get pods
kubectl scale rs new-replica-set --replicas=2
kubectl get pods
```

### ReplicaSet manifest — `Deployments/my-rs.yaml`

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
          # Alt image: quay.io/pandeysp/nginx:latest
```

> **Exam note** — `.spec.selector` is **immutable** on a live ReplicaSet/Deployment. If the exam asks you to change it,
> you must recreate the object. Changing `.spec.template` is allowed and is what rollouts are built on.

### `--cascade=orphan` — from `Deployments/replicaset-commands.sh`

```bash
kubectl delete replicaset nginx --cascade=orphan
# replicaset.apps "nginx" deleted
kubectl get pods
# NAME          READY   STATUS    RESTARTS   AGE
# nginx-4q2wr   1/1     Running   0          98s
```

The ReplicaSet is gone; the pod survives, now **orphaned** (its `ownerReferences` no longer resolve). Worth knowing for
the "rescue the pod" style question.

**[Your note]** — the two commands that do not exist, captured in the same file:

```bash
kubectl get replicaset nginx --image=nginx --dry-run=client -o yaml
# error: unknown flag: --image

kubectl create replicaset nginx --image=nginx --dry-run=client -o yaml
# error: unknown flag: --image
```

There is no `kubectl create replicaset`. You must either write the YAML or derive it from a Deployment manifest
(`kind: Deployment` → `kind: ReplicaSet`, drop `strategy`, `revisionHistoryLimit` and `status`).

---

## 2.3 Deployments — Lab `03.deployments.sh`

A Deployment owns ReplicaSets, and owns *history*. This is the object the exam asks you to roll.

```bash
kubectl get pods
kubectl get rs
kubectl get deployments
kubectl describe deployment frontend-deployment | grep -i image
kubectl events deployment frontend-deployment
kubectl create deployment httpd-frontend --image=httpd:2.4-alpine --replicas=3
```

> **Note** — `kubectl events` is not a real command in current kubectl. Use
> `kubectl get events --sort-by=.lastTimestamp` or `kubectl describe deployment <name>`.

### Rolling update, in the words of `Deployments/replicaset.txt`

> In this lab:
> 1. we will first explore the API objects used to manage groups of containers. The objects available have changed as
>    Kubernetes has matured, so the Kubernetes version in use will determine which are available.
> 2. Our first object will be a **ReplicaSet**, which does not include newer management features found with Deployments.
> 3. A **Deployment** operator manages ReplicaSet operators for you.
> 4. We will also work with another object and watch loop called a **DaemonSet** which ensures a container is running on
>    newly added node.
> 5. Then we will update the software in a container, view the revision history, and roll-back to a previous version.

### The rolling update drill — `Deployments/rolling-update.sh`

```bash
kubectl get all
#  NAME                           READY   STATUS    RESTARTS   AGE
#  pod/frontend-685dfcc44-brxjb   1/1     Running   0          70s
#  ...
#  service/kubernetes       ClusterIP    10.43.0.1      <none>        443/TCP
#  service/webapp-service   NodePort     10.43.98.112   <none>        8080:30080/TCP
#  deployment.apps/frontend   4/4     4            4            70s
#  replicaset.apps/frontend-685dfcc44   4         4        4        70s
```

A load generator that proves the rollout never dropped a request:

```bash
cat curl-test.sh
for i in {1..35}; do
  kubectl exec --namespace=kube-public curl -- sh -c \
    'test=`wget -qO- -T 2 http://webapp-service.default.svc.cluster.local:8080/info 2>&1` && echo "$test OK" || echo "Failed"';
  echo ""
done
```

Note the DNS name used: `webapp-service.default.svc.cluster.local:8080`. That is the full four-part form, and it works
from *any* namespace.

```bash
kubectl describe pod frontend-685dfcc44-mtzxh
#  Labels:           name=webapp
#                    pod-template-hash=685dfcc44
#  Image:          kodekloud/webapp-color:v1
```

`pod-template-hash=685dfcc44` is the Deployment's fingerprint of the pod template. Two ReplicaSets of the same
Deployment differ only in this label — that is how the Deployment knows which pods belong to which revision.

### Rollout commands to memorise

```bash
kubectl rollout status deployment/frontend
kubectl rollout history deployment/frontend
kubectl rollout history deployment/frontend --revision=2
kubectl rollout undo deployment/frontend
kubectl rollout undo deployment/frontend --to-revision=1
kubectl rollout restart deployment/frontend        # forces a new ReplicaSet without changing the image
kubectl rollout pause deployment/frontend
kubectl rollout resume deployment/frontend
```

### Strategy block

```yaml
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%            # or an absolute number, e.g. 1
      maxUnavailable: 25%      # or an absolute number, e.g. 0
  minReadySeconds: 0
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600   # after this, the rollout is declared failed
```

`Deployment` + `Recreate` strategy: `strategy.type: Recreate` kills all old pods before creating new ones — a downtime
window, but required when two versions cannot coexist (e.g. a schema migration or a `ReadWriteOnce` volume).

> **Exam note** — `maxUnavailable: 0` + `maxSurge: 1` gives a true zero-downtime rollout. `maxUnavailable: 1` +
> `maxSurge: 0` gives a pure in-place replacement that never exceeds the replica count.

---

## 2.4 Multi-container pods — `Deployments/multi-container-pod.yaml`, `Labs/18-side-car.yaml`, `Deployments/sloution.yaml`

Containers in a pod share the network namespace (same IP, `localhost` works) and can share volumes. They are scheduled
together and scaled together — you cannot scale them independently.

### The sidecar pattern — `Labs/18-side-car.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: elastic-stack
  labels:
    name: app
spec:
  containers:
    - name: app
      image: kodekloud/event-simulator
      # Alt image: quay.io/pandeysp/hotel:latest
      volumeMounts:
        - mountPath: /log
          name: log-volume

    - name: sidecar
      image: kodekloud/filebeat-configured
      # Alt image: quay.io/pandeysp/zabbix-agent2:alpine-6.4.13
      volumeMounts:
        - mountPath: /var/log/event-simulator/
          name: log-volume

  volumes:
    - name: log-volume
      hostPath:
        # directory location on host
        path: /var/log/webapp
        # this field is optional
        type: DirectoryOrCreate
```

The app writes to `/log`; the sidecar tails `/var/log/event-simulator/`. Both resolve to the same `hostPath` volume. That
is the whole pattern: **one producer, one consumer of the same volume, no network hop.**

`Deployments/sloution.yaml` is the identical manifest as your cleaned-up "solution" copy.

### The ambassador / adapter / logger variants

From `acg-multic-np.yaml` — a **logger sidecar** using `emptyDir`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: logging-sidecar
  name: logging-sidecar
  namespace: baz
spec:
  containers:
    - image: busybox
      # Alt image: quay.io/pandeysp/busybox:latest
      name: busybox
      command: ['sh', '-c', 'while true; do echo Logging data > /output/output.log; sleep 5; done']
      volumeMounts:
        - name: shared-data
          mountPath: /output

    - image: busybox
      name: sidecar
      command: ['sh', '-c', 'tail -n+1 -f  /output/output.log']
      volumeMounts:
        - name: shared-data
          mountPath: /output
  volumes:
    - name: shared-data
      emptyDir: {}
  restartPolicy: Always
```

**[Your note]** — verbatim, and it is exactly the kind of detail that decides an exam question:

> *the folder in the command part is not important, the only important value is the mountpath that should be the same as
> the one in the command*
>
> `kubectl -n baz logs logging-sidecar -c sidecar`

So: the app's `echo ... > /output/output.log` writes to the **mountPath** `/output`. Whatever filename it writes there is
irrelevant to Kubernetes. The two mountPaths must agree.

### A pod that would crash-loop without a postStart hack — `Deployments/multi-container-pod.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: yellow
spec:
  containers:
    - name: lemon
      image: busybox
      # Alt image: quay.io/pandeysp/busybox:latest
      command: ["sh", "-c", "while true; do echo 'Lemon Container is running...'; sleep 10; done"]
      # If the pod goes into the crashloopbackoff, add the command sleep 1000 in the lemon container
      lifecycle:
        postStart:
          exec:
            command: ["/bin/sh", "-c", "if [ ! -f /tmp/initialized ]; then sleep 1000; touch /tmp/initialized; fi"]
      volumeMounts:
        - name: shared-data
          mountPath: /tmp
    - name: gold
      image: redis
      # Alt image: quay.io/pandeysp/redis:latest
      command: ["redis-server"]
  volumes:
    - name: shared-data
      emptyDir: {}
```

Two things to take from this:

1. `emptyDir` is the only volume type shared by both containers here — it lives as long as the pod does.
2. The `postStart` hook runs **concurrently** with the container's `command`, not before it. If the hook sleeps, the
   entrypoint is still running. That is why the `/tmp/initialized` guard file exists: without it the hook would block on
   every restart.

### Lifecycle hooks

```yaml
lifecycle:
  postStart:
    exec:
      command: ["/bin/sh", "-c", "echo started > /tmp/started"]
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 10"]
    # or: httpGet: {path: /shutdown, port: 8080}
```

`preStop` fires before the container is sent SIGTERM — use it for graceful drains. Combined with
`terminationGracePeriodSeconds` it is how you get a zero-drop connection rollout.

---

## 2.5 Init containers — Labs `19-init-containers.sh`, `init-cotainer.sh`, `init-container-readme.md`

From `Labs/init-container-readme.md`, verbatim:

> ### Init Containers
>
> An init container is a concept used to run utility or setup tasks before the main application container starts within a
> pod. Pods in Kubernetes can have one or more containers, and init containers provide a way to perform initialization
> tasks such as pre-fetching data, preparing configurations, or setting up required resources before the application
> container(s) start running.
>
> Here are some key points about init containers:
>
> **Initialization:** Init containers run to completion before any of the application containers in the same pod start.
> They are executed sequentially, one after the other.
>
> **Separate Containers:** Init containers are separate containers from the application containers but share the same pod
> namespace and resources. This means they can communicate with each other through local network communication or shared
> volumes.
>
> **Purpose:** Init containers are often used for tasks like setting up configuration files, initializing databases,
> running migrations, or waiting for external resources to become available.
>
> **Error Handling:** If an init container fails (i.e., exits with a non-zero status), Kubernetes restarts it until it
> succeeds. Once all init containers have successfully completed, the main application container(s) start.
>
> **Image and Configuration:** Init containers are defined in the pod specification (spec) alongside the main containers.
> Each init container specifies its own image, command, and volume mounts.
>
> **Lifecycle Hooks:** Init containers support lifecycle hooks such as preStop and postStart similar to regular
> containers. These hooks can be used for executing commands before the container starts or after it completes.
>
> **Overall**, init containers provide a way to perform initialization tasks in a controlled and orchestrated manner,
> ensuring that the main application container(s) have the required environment and resources ready before they start
> processing requests. This enhances the reliability and flexibility of applications deployed in Kubernetes.

### One init container — `Labs/init-container-pod.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: blue
  namespace: default
spec:
  containers:
    - command:
        - sh
        - -c
        - echo The app is running! && sleep 3600
      image: busybox:1.28
      # Alt image: quay.io/pandeysp/busybox:v1
      name: green-container-1
      volumeMounts:
        - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          name: kube-api-access-zhrtn
          readOnly: true
  initContainers:
    - command:
        - sh
        - -c
        - sleep 5
      image: busybox
      name: init-myservice
      volumeMounts:
        - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          name: kube-api-access-zhrtn
          readOnly: true
```

### Two sequential init containers — `Labs/init-container-pod-2.yaml`

```yaml
spec:
  containers:
    - command: ["sh", "-c", "echo The app is running! && sleep 3600"]
      image: busybox:1.28
      name: purple-container
  initContainers:
    - command: ["sh", "-c", "sleep 600"]
      image: busybox:1.28
      name: warm-up-1
    - command: ["sh", "-c", "sleep 1200"]
      image: busybox:1.28
      name: warm-up-2
```

`warm-up-1` must exit before `warm-up-2` starts. `kubectl get pods` shows `Init:0/2`, then `Init:1/2`, then the pod
becomes `Running`.

### Reading init-container state — from `Labs/init-cotainer.sh`

```bash
kubectl get pods
kubectl get pods --watch
# NAME     READY   STATUS     RESTARTS   AGE
# purple   0/1     Init:0/2   0          89s

kubectl describe pod red | grep -i init
kubectl get pod blue -o yaml
kubectl get pod purple -o yaml
```

### The Init:Error drill

```bash
kubectl get pods
# NAME     READY   STATUS       RESTARTS      AGE
# green    2/2     Running      0             12m
# blue     1/1     Running      0             12m
# purple   0/1     Init:0/2     0             6m11s
# red      0/1     Init:0/1     0             21s
# orange   0/1     Init:Error   1 (13s ago)   15s

kubectl describe pod orange
kubectl logs orange
# Defaulted container "orange-container" out of: orange-container, init-myservice (init)
# Error from server (BadRequest): container "orange-container" in pod "orange" is waiting to start: PodInitializing

kubectl events pod orange
# LAST SEEN           TYPE      REASON                           OBJECT              MESSAGE
# 39s (x4 over 87s)   Normal    Created                          Pod/orange          Created container init-myservice
# 39s (x4 over 86s)   Normal    Started                          Pod/orange          Started container init-myservice
# 0s (x7 over 82s)   Warning   BackOff                          Pod/orange          Back-off restarting failed container init-myservice in pod orange_default(...)
```

**[Your note]** — the critical gotcha, captured verbatim:

```bash
kubectl edit pod red
# error: pods "red" is invalid
# A copy of your changes has been stored to "/tmp/kubectl-edit-1267393329.yaml"
# error: Edit cancelled, no valid changes were saved.

kubectl delete pod red --force
# Warning: Immediate deletion does not wait for confirmation that the running resource has been terminated. The resource may continue to run on the cluster indefinitely.
# pod "red" force deleted

kubectl apply -f /tmp/kubectl-edit-1267393329.yaml
# pod/red created
```

**You cannot edit a pod's spec.** `kubectl edit` on a Pod rejects most spec changes with `pods "<name>" is invalid`,
saves your edit to a `/tmp/kubectl-edit-<timestamp>.yaml`, and cancels. The workflow that works — and that you should
muscle-memory — is:

```bash
kubectl edit pod <name>                 # fails, but writes /tmp/kubectl-edit-*.yaml
kubectl delete pod <name> --force       # or just kubectl delete pod <name>
kubectl apply -f /tmp/kubectl-edit-*.yaml
```

This pattern appears **four times** in your repo (`16-config-map.sh`, `17-secretlab.sh`, `init-cotainer.sh`,
`31-pv-pvc-definition.sh`) — it is clearly the thing you had to learn the hard way, so it is almost certainly what the
exam will test.

> **Exam note** — the immutable pod fields are: `spec.containers[*].image` after the container has started (via edit),
> `spec.nodeName`, `spec.serviceAccountName` (older clusters), and the volume/claim pairing. To change any of them:
> `kubectl get pod X -o yaml > x.yaml`, edit, `kubectl delete pod X --force`, `kubectl apply -f x.yaml`. Or use
> `kubectl replace --force -f x.yaml`.

---

## 2.6 Container commands and arguments — Lab `19-container-commands.sh`

Docker's `ENTRYPOINT` maps to Kubernetes `command`; Docker's `CMD` maps to `args`. If both `command` and `args` are set,
the `command` **replaces** ENTRYPOINT and `args` replaces CMD.

From your lab, the Dockerfiles:

```dockerfile
FROM python:3.6-alpine
RUN pip install flask
COPY . /opt/
EXPOSE 8080
WORKDIR /opt
ENTRYPOINT ["python", "app.py"]
# at entry point command python app.py is run
```

```dockerfile
FROM python:3.6-alpine
RUN pip install flask
COPY . /opt/
EXPOSE 8080
WORKDIR /opt
ENTRYPOINT ["python", "app.py"]
CMD ["--color", "red"]
# at entry point command python app.py --color red is running
```

### The three ways to pass a flag

```yaml
# 1. command only — replaces ENTRYPOINT entirely
spec:
  containers:
    - name: simple-webapp
      image: kodekloud/webapp-color
      # Alt image: quay.io/pandeysp/mywebapp:latest
      command: ["python", "app.py"]
      args: ["--color", "pink"]

# 2. bare YAML list form
    - name: ubuntu
      image: ubuntu
      command: ["sleep", "4000"]

# 3. block form
    - name: ubuntu
      image: ubuntu
      command:
        - sleep
        - "4800"
```

### The trap you hit

```bash
kubectl run webapp-green --image=kodekloud/webapp-color --dry-run=client -o yaml -- command --color=green > ttt.yaml
```

produces:

```yaml
spec:
  containers:
  - args:
    - command
    - --color=green
    image: kodekloud/webapp-color
    name: webapp-green
```

**[Your note]** — `-- command --color=green` put `command` and `--color=green` into **`args`**, not into `command`. That
is because `kubectl run ... -- <tokens>` appends to the container's `args`. To get them into `command` you must use
`--command`:

```bash
kubectl run webapp-green --image=kodekloud/webapp-color --dry-run=client -o yaml \
  --command -- sleep 5000
```

and then hand-edit the YAML.

> **Exam note** — the rule of thumb: `command` overrides ENTRYPOINT, `args` overrides CMD, and if you supply `command`
> without `args`, the image's `CMD` is **ignored**. If the image has no ENTRYPOINT and you only supply `args`, nothing
> runs and you get `Error: no command specified`.

### The projected service-account volume

Your `kubectl get pod ubuntu-sleeper -o yaml` capture is worth studying, because it shows the token volume that appears on
*every* pod:

```yaml
spec:
  containers:
  - command:
    - sleep
    - "4800"
    image: ubuntu
    name: ubuntu
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-7w6qp
      readOnly: true
  volumes:
  - name: kube-api-access-7w6qp
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          expirationSeconds: 3607
          path: token
      - configMap:
          items:
          - key: ca.crt
            path: ca.crt
          name: kube-root-ca.crt
      - downwardAPI:
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
            path: namespace
```

That `downwardAPI` source is the Downward API in action — the pod's own namespace is injected as a *file*. The
equivalent as environment variables:

```yaml
env:
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
  - name: CPU_REQUEST
    valueFrom:
      resourceFieldRef:
        containerName: app
        resource: requests.cpu
```

Valid `fieldPath` values: `metadata.name`, `metadata.namespace`, `metadata.labels['<key>']`, `metadata.annotations['<key>']`,
`spec.nodeName`, `spec.serviceAccountName`, `status.hostIP`, `status.podIP`. **No `metadata.creationTimestamp`-style
mutable fields, and no arbitrary JSONPath.**

---

## 2.7 DaemonSets — Lab `12-ds.sh`

A DaemonSet runs **exactly one pod per node**, including nodes added later. Use it for log collectors, node exporters,
CNI plugins, and storage daemons.

```bash
kubectl get ds --all-namespaces
kubectl describe ds flannel-ds -n kube-flannel | grep -i image
kubectl get ds -o wide --all-namespaces
kubectl describe ds kube-flannel-ds -n kube-flannel | grep -i image
```

**[Your note]** — the DS name is **not** always the deployment name you'd guess. In your cluster the DaemonSet is
`kube-flannel-ds` in `kube-flannel`, not `flannel-ds`. Always `kubectl get ds -A` first.

### Creating a DaemonSet the exam way

There is no `kubectl create daemonset`. Derive it from a Deployment manifest:

```bash
kubectl create deployment elasticsearch \
  --image=registry.k8s.io/fluentd-elasticsearch:1.20 \
  -n kube-system --dry-run=client -o yaml > my-ds.yaml
```

Then edit:

```yaml
kind: DaemonSet                       # was Deployment
metadata:
  labels:
    app: elasticsearch
  name: elasticsearch
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
        - image: registry.k8s.io/fluentd-elasticsearch:1.20
          name: fluentd-elasticsearch
```

**[Your note]** — verbatim:

> *after creating the yaml file using deployment command i removed the replicas, creation time, strategy, etc also i
> replaced the Deployment kind with DaemonSet*

Exactly right. Remove `spec.replicas`, `spec.strategy`, `spec.revisionHistoryLimit`, `metadata.creationTimestamp`, and
`status`. A DaemonSet has no `replicas` field at all.

**Alternative image:** `# Alt image: quay.io/pandeysp/zabbix-proxy-sqlite3:alpine-6.4.13` or
`# Alt image: quay.io/pandeysp/prom_metrics_expoter:latest` — both are natural node-level DaemonSet workloads.

> **Exam note** — DaemonSet update strategies are `RollingUpdate` (default, `maxUnavailable` + `maxSurge`) and
> `OnDelete`. With `OnDelete` the pod is only replaced when you delete it manually.

---

## 2.8 StatefulSets and Jobs — not in your labs, but examinable

Your repo has no StatefulSet, but the CKA does test them. Keep this reference.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web            # the headless service that backs it
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx
          # Alt image: quay.io/pandeysp/nginx:latest
          volumeMounts:
            - name: www
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:       # creates web-0, web-1, web-2 PVCs automatically
    - metadata:
        name: www
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

| | Deployment | StatefulSet |
|---|---|---|
| Pod names | `web-7d9f8b6c4-x2k` (random) | `web-0`, `web-1`, `web-2` (stable, ordered) |
| Storage | Shared PVC or nothing | One `volumeClaimTemplate` per replica |
| Startup order | All at once | Strictly sequential (`web-0` before `web-1`) |
| Scaling down | Random | Reverse order (`web-2` first) |
| Network | Any Service | Requires a **headless** Service (`clusterIP: None`) |

```yaml
# Job
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  completions: 5          # run 5 successful pods total
  parallelism: 2          # 2 at a time
  backoffLimit: 4
  template:
    spec:
      restartPolicy: Never    # Job requires Never or OnFailure, not Always
      containers:
        - name: pi
          image: perl:5.34
          command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]

---
# CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: hello
              image: busybox
              # Alt image: quay.io/pandeysp/busybox:latest
              command: ["sh", "-c", "date; echo Hello"]
```

---

## 2.9 Labels, selectors and annotations — Lab `08-working-with-labels.sh`

```bash
kubectl get pods --all-namespaces -o wide
kubectl get pods --show-labels            # the usage is similar to --all-namespaces
kubectl get pods --show-labels | grep -i "=dev"
kubectl get pods --show-labels | grep -i "=dev" | wc
kubectl get pods --show-labels | grep -i "=finance"
kubectl get all --show-labels | grep -i "=prod"
kubectl apply -f replicaset-definition-1.yaml
```

**[Your note]** — verbatim:

> *i just matched the labels of replicaset and pod*

Which is the whole point: `.spec.selector.matchLabels` of the controller must be a **subset** of the pod template's
labels. If they don't overlap, the controller creates pods it does not recognise (and with a Deployment, the ReplicaSet
never reports Ready).

### Label selectors in practice

```bash
# Equality-based
kubectl get pods -l app=nginx
kubectl get pods -l app=nginx,tier=frontend
kubectl get pods -l 'env in (prod,dev)'
kubectl get pods -l 'env notin (prod)'
kubectl get pods -l app                  # key exists
kubectl get pods -l '!app'               # key does not exist

# Set-based in YAML
selector:
  matchExpressions:
    - key: tier
      operator: In
      values: [frontend, backend]
    - key: environment
      operator: DoesNotExist
```

Valid operators: `In`, `NotIn`, `Exists`, `DoesNotExist`. **`matchLabels` and `matchExpressions` are ANDed together.**

### Labels vs annotations

| | Labels | Annotations |
|---|---|---|
| Purpose | Identity, grouping, selection | Non-identifying metadata |
| Queryable | Yes (`-l`, selectors) | No |
| Size limit | 63 chars per key/value, 31611 total | 256 KB total |
| Example | `app: nginx`, `tier: frontend` | `kubectl.kubernetes.io/last-applied-configuration`, `nginx.ingress.kubernetes.io/rewrite-target` |

```bash
kubectl label pod nginx tier=frontend
kubectl label pod nginx tier=backend --overwrite
kubectl label pod nginx tier-                       # remove
kubectl annotate pod nginx description="hello"
kubectl annotate pod nginx description-             # remove
```

> **Exam note** — without `--overwrite`, `kubectl label` fails if the key exists. This trips people up in timed exams.

---

## 2.10 Resource requests, limits and QoS — Lab `11-resource-limits.sh`

```bash
kubectl events pod elephant
kubectl describe pod rabbit
```

**[Your note]** — verbatim:

> *nothing special: create the yaml file from the running pod -> increase the cpu limit*

Which is the exam pattern: `kubectl get pod rabbit -o yaml > rabbit.yaml`, edit `resources.limits.cpu`,
`kubectl delete pod rabbit --force`, `kubectl apply -f rabbit.yaml`.

### Requests vs limits

```yaml
resources:
  requests:                  # used by the SCHEDULER to pick a node; reserved
    cpu: 100m                # 100 millicores = 0.1 core
    memory: 128Mi
  limits:                    # enforced by the kubelet/CFS at runtime
    cpu: 250m
    memory: 256Mi
```

| | CPU | Memory |
|---|---|---|
| Unit | `m` (millicores) or fractional cores (`0.1`) | `Ki`, `Mi`, `Gi`, `Ti` |
| Request is | Compressible — throttled, never killed | Incompressible — the scheduler's hard constraint |
| Exceeding the limit | Throttling (latency, no crash) | **OOMKilled** — the container is killed |

### QoS classes (derived, never set directly)

| QoS | Condition | Eviction priority |
|---|---|---|
| **Guaranteed** | Every container has requests == limits for **both** cpu and memory | Last to be evicted |
| **Burstable** | At least one container has a request or limit that differs | Middle |
| **BestEffort** | No requests or limits anywhere | **First** to be evicted |

You can read it off a live pod: `kubectl get pod -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass`.

### LimitRange and ResourceQuota

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
    - type: Container
      default:                 # applied as limits when none specified
        cpu: 500m
        memory: 512Mi
      defaultRequest:          # applied as requests when none specified
        cpu: 100m
        memory: 128Mi
      max: {cpu: "2", memory: 2Gi}
      min: {cpu: "50m", memory: 64Mi}
```

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    persistentvolumeclaims: "10"
    requests.storage: "500Mi"
```

> **Exam note** — `kubectl describe quota` is the fastest way to see *used* vs *hard*. A pod that is rejected with
> `exceeded quota: compute-quota, requested: requests.cpu=1, used: requests.cpu=3, limited: requests.cpu=4` tells you
> exactly which quota object to raise.

---

## 2.11 Scheduling — Taints, Tolerations, Node Affinity, nodeSelector

### Lab `07.scheduler01.sh` and `09-taint-tolerations.sh`

```bash
kubectl describe node controlplane
kubectl describe node controlplane | grep -i taint
kubectl get pods
kubectl apply -f nginx.yaml

kubectl get nodes -o='custom-columns=NodeName:.metadata.name,TaintKey:.spec.taints[*].key,TaintValue:.spec.taints[*].value,TaintEffect:.spec.taints[*].effect'
```

That custom-columns command is the fastest taint dump you can produce. Memorise it.

```bash
# taint a node: key=value:effect
kubectl taint nodes node01 spray=mortein:NoSchedule
kubectl taint nodes node01 env_type=production:NoSchedul      # typo: NoSchedul
kubectl taint nodes node01 env=prod:NoSchedule

kubectl run mosquito --image=nginx        # will NOT land on node01

kubectl run bee --image=nginx --dry-run=client -o yaml > my-pod.yaml
```

```yaml
# apiVersion: v1
# kind: Pod
# metadata:
#   labels:
#     run: bee
#   name: bee
# spec:
#   containers:
#   - image: nginx
#     name: bee
#   tolerations:
#   - key: spray
#     value: mortein
#     effect: NoSchedule
#     operator: Equal
```

```bash
kubectl apply -f my-pod.yaml
kubectl describe node controlplane | grep -i taint
```

**[Your note]** — the removal typo you hit, and it is a genuine trap:

```bash
kubectl taint node controlplane key=node-role.kubernetes.io/control-plane:NoSchedule-
# this was wrong key=was not required
kubectl taint node controlplane node-role.kubernetes.io/control-plane:NoSchedule-
```

**Removing** a taint takes only `<key>:<effect>-`. Including the value or writing `key=` makes kubectl treat it as a new
key name and the removal silently does nothing.

### Taint effects

| Effect | Behaviour |
|---|---|
| `NoSchedule` | Pods without a matching toleration are not scheduled there. Existing pods stay. |
| `PreferNoSchedule` | Soft version — the scheduler tries to avoid the node but will use it if there is no alternative. |
| `NoExecute` | Evicts running pods that don't tolerate it, **and** blocks new scheduling. |

Default taints on a kubeadm cluster:

```
node.kubernetes.io/not-ready:NoExecute       for 300s
node.kubernetes.io/unreachable:NoExecute     for 300s
node.kubernetes.io/memory-pressure:NoSchedule
node.kubernetes.io/disk-pressure:NoSchedule
node.kubernetes.io/pid-pressure:NoSchedule
node.kubernetes.io/unschedulable:NoSchedule   (added by cordon)
node-role.kubernetes.io/control-plane:NoSchedule
```

### The `tolerationSeconds` knob

```yaml
tolerations:
  - key: node.kubernetes.io/unreachable
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 600        # tolerate for 10 minutes, then evict
```

`operator: Exists` with no `value` matches **any** value of that key. That is what the default tolerations use, and it is
why the DaemonSet tolerations block in your captured manifests looks like:

```yaml
tolerations:
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
```

### nodeSelector vs nodeAffinity

**nodeSelector** — exact key=value match, the simplest tool:

```yaml
spec:
  nodeSelector:
    disktype: ssd
```

`Services/nginx-one.yaml` uses it:

```yaml
spec:
  template:
    spec:
      containers:
        - image: nginx:1.20.1
          name: nginx
          ports:
            - containerPort: 8080
      nodeSelector:
        system: secondOne
```

**nodeAffinity** — full set-based expressions. From `Labs/10-node-affinity.sh`:

```bash
kubectl get nodes --show-labels
kubectl label node node01 color=blue
kubectl create deployment blue --image=nginx --replicas=3
kubectl get pods -o wide
kubectl create deployment red --image=nginx --replicas=2 --dry-run=client -o yaml > red.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: red
spec:
  replicas: 2
  selector:
    matchLabels:
      app: red
  template:
    metadata:
      labels:
        app: red
    spec:
      containers:
        - image: nginx
          # Alt image: quay.io/pandeysp/nginx:latest
          name: nginx
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/control-plane
                    operator: Exists
```

**[Your note]** — verbatim, and this is the subtlety that decides the question:

> *the `node-role.kubernetes.io/control-plane` label does not have any value and just exists as a label so we use `Exists`
> instead of `In`*

A key with **no value** requires `operator: Exists`. Using `In` with an empty `values` list matches nothing and the pod
stays `Pending`.

### The four affinity flavours

| Type | Field | Meaning |
|---|---|---|
| `requiredDuringSchedulingIgnoredDuringExecution` | `nodeAffinity` | Hard. Pod won't schedule unless the rule matches. |
| `preferredDuringSchedulingIgnoredDuringExecution` | `nodeAffinity` | Soft. The scheduler prefers, but will schedule elsewhere. |
| `requiredDuringSchedulingIgnoredDuringExecution` | `podAffinity` | Hard. Co-locate with pods matching a selector. |
| `preferredDuringScheduling...` | `podAntiAffinity` | Soft. Spread away from pods matching a selector. |

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values: [web]
        topologyKey: kubernetes.io/hostname     # spread across nodes, not AZs
```

`topologyKey` is mandatory and defines the failure domain: `kubernetes.io/hostname` (a node),
`topology.kubernetes.io/zone` (an AZ), `topology.kubernetes.io/region`.

> **Exam note** — the long names are confusingly symmetrical. Rule of thumb: **"Required" = hard, "Preferred" = soft;
> "DuringScheduling" = evaluated at schedule time; "IgnoredDuringExecution" = not re-evaluated later** (there is no
> "RequiredDuringExecution" — it does not exist).

---

## 2.12 Scheduling a pod manually, and the scheduler decision chain

```
Pod created (Pending)
      │
      ▼
┌─────────────────────┐
│ Filtering (Predicates)│   ← removes nodes that cannot host the pod
│  • taints/tolerations │
│  • resource fit       │
│  • nodeSelector       │
│  • nodeAffinity       │
│  • port conflicts     │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│ Scoring (Priorities) │   ← ranks the remaining nodes
│  • spread of replicas│
│  • image locality    │
│  • resource balance  │
└──────────┬──────────┘
           ▼
   Highest-scoring node
           │
           ▼
  kubelet on that node is told to start the pod
```

You can watch it happen:

```bash
kubectl get pod -w
kubectl describe pod <name> | tail -20        # the Events section names the scheduler
# Normal  Scheduled  5s   default-scheduler  Successfully assigned default/web to node01
```

Bypass the scheduler entirely:

```yaml
spec:
  nodeName: node01        # kubelet still validates it can run there
```

---

## 2.13 Probes — not in your labs, but high-yield

```yaml
containers:
  - name: app
    image: nginx
    livenessProbe:                 # restart the container if this fails
      httpGet: {path: /healthz, port: 8080}
      initialDelaySeconds: 15
      periodSeconds: 10
      timeoutSeconds: 1
      failureThreshold: 3
      successThreshold: 1
    readinessProbe:                # remove from Service endpoints if this fails
      httpGet: {path: /ready, port: 8080}
      initialDelaySeconds: 5
      periodSeconds: 5
    startupProbe:                  # gives a slow app time to boot
      httpGet: {path: /, port: 8080}
      failureThreshold: 30
      periodSeconds: 10
```

Three handler types: `httpGet`, `tcpSocket`, `exec`.

> **Exam note** — the classic question is "your app takes 90 seconds to start and the liveness probe keeps killing it."
> The answer is a **startupProbe** with a generous `failureThreshold`, not a longer `initialDelaySeconds` on liveness —
> because `initialDelaySeconds` is a fixed guess while `startupProbe` scales with actual boot time (and while the
> startup probe is failing, liveness and readiness are disabled).

---

## 2.14 Part II self-check

1. You edited a ReplicaSet's pod template. Why did nothing happen, and what would have happened with a Deployment?
2. `kubectl edit pod red` failed and saved a file. What are the exact next two commands?
3. `kubectl run x --image=nginx -- command --flag=1` — where did `--flag=1` land, and how do you move it?
4. `kubectl taint node node01 key=value:NoSchedule-` fails to remove the taint. Why?
5. What are the only valid values of `restartPolicy` for a Job's pod template?
6. A Deployment with `maxUnavailable: 0` and `maxSurge: 25%` and 4 replicas — how many pods can exist at peak?
7. A pod's `READY` shows `1/2`. What does the `2` count?
8. Name the three QoS classes and the eviction order.
9. `kubectl get pods -l '!app'` — what does it return?
10. What does `topologyKey: kubernetes.io/hostname` mean in a podAntiAffinity rule?


\pagebreak

## Part III — Services & Networking

**CKA weight: ~20%**

This is the domain where the LFS258 course and your lab set overlap most productively: you have real captures of every
Service type, real Ingress objects, real NetworkPolicies, and a live `ip`/`ifconfig` walkthrough of the pod network.

**Competencies covered in this part**

1. Demonstrate basic understanding of NetworkPolicies
2. Demonstrate basic understanding of the Cluster Network Operator / CNI plugin
3. Understand the networking configuration on the cluster nodes
4. Understand connectivity between pods
5. Define and enforce Network Policies
6. Know how to use and configure the main elements of the Kubernetes networking model: pod network, service network, ClusterIP, NodePort, LoadBalancer, Ingress
7. Know how to use Ingress rules and Ingress controllers
8. Use the DNS service for name resolution
9. Understand the service networking model and the role of kube-proxy

---

## 3.1 The Kubernetes networking model — the four problems

From `Networking/temp.md`:

> *we know that we have one to n pods inside a single node and every single of this pods should be able to connect to
> other pods inside that node also to pods in other nodes in the cluster. Kubernetes does not implement this way of
> networking and we have to implement it ourselves.*

| Problem | Solution | Who implements it |
|---|---|---|
| Container ↔ container in the **same** pod | Shared network namespace (the `pause` container holds it) | kubelet / CRI |
| Pod ↔ pod on the **same** node | A Linux bridge (`cni0`) + veth pairs | CNI plugin |
| Pod ↔ pod on a **different** node | Overlay (VXLAN), routing, or BGP | CNI plugin |
| Pod ↔ Service (`ClusterIP`) | iptables / IPVS rules + `kube-proxy` | kube-proxy |

**The rules, and they are absolute:**

* Every pod gets its **own IP**. No NAT between pods.
* Pods on the same node reach each other via the bridge; pods on different nodes via the CNI plugin.
* A pod's IP is routable from every node without NAT.
* Services get a **virtual IP** from the service CIDR that is not bound to any interface.

### IP ranges on a kubeadm cluster (from `Security/t.yaml`)

```yaml
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
```

and the pod CIDR is whatever you passed to `kubeadm init --pod-network-cidr=10.244.0.0/16`.

Your captures show both a Docker-Desktop cluster (`10.1.0.11` pod IPs — `VolumesAndData/new-pod.yaml`) and a kubeadm
cluster (`10.42.0.12`, `10.244.0.4`). The pod CIDR differs per cluster; the *model* does not.

### Reading the node's networking — `Labs/32-networking-explore-env.sh`

```bash
kubectl get nodes -o wide
ip link show
ifconfig -a
ip a
```

```
1: lo:       <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
2: flannel.1:<BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 ... inet 10.244.0.0/32
3: cni0:     <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 ... inet 10.244.0.1/24
4: veth50e87d52@if2: ... master cni0 ... link-netns cni-b0ccf98c-85f3-5a2c-20d7-eafa47c6fc7a
5: veth01b630bb@if2: ... master cni0 ... link-netns cni-4ef6d342-4a47-7e35-6e61-66f640da6254
10056: eth0@if10057: ... inet 192.32.98.9/24
10058: eth1@if10059: ... inet 172.25.0.91/24
```

Mapping that to the model:

| Interface | Role |
|---|---|
| `lo` | Loopback. Every netns has one. |
| `cni0` | The node's **pod bridge**. `10.244.0.1/24` = the node's pod-subnet gateway. |
| `vethNNN@if2` | One end of a veth pair; the `@if2` peer is inside a pod netns. `master cni0` = plugged into the bridge. |
| `flannel.1` | The **overlay** endpoint. `10.244.0.0/32` = this node's address inside the cluster-wide overlay. |
| `eth0` | The node's real NIC. |
| `eth1` | A second NIC (host-network pods, or the CNI's own interface). |

```bash
# Find which netns a pod is in and look inside it
ip link show | grep veth
ip -n <netns> addr
ip netns list
ip netns exec blue ip route

# Which node is a pod on, and what is its IP?
kubectl get pods -o wide
# NAME    STATUS   IP          NODE
# blue    Running  10.244.0.5  node01

# Cross-check against the node's interfaces
kubectl describe node node01
#  NetworkUnavailable   False   ...   FlannelIsUp   Flannel is running on this node
```

That `NetworkUnavailable / FlannelIsUp` line is the node condition you check when a newly joined node stays `NotReady`
— it means the CNI plugin never came up.

### The veth/bridge plumbing, by hand

`Networking/kubeadmin/networking.sh` is a raw `ip netns` drill that shows exactly what a CNI plugin does:

```bash
ip netns list
ip netns exec blue ip link
ip route
ip netns exec red ip route

ip link add veth-red type veth peer name veth-blue
ip link show
ip link set veth-red netns red
ip link set veth-blue netns blue
ip link show

ip netns exec red ip addr add 192.168.15.1/24 dev veth-red
ip netns exec blue ip addr add 192.168.15.2/24 dev veth-blue
ip link set veth-red up
ip netns exec red ip link set dev veth-red up
ip netns exec blue ip link set dev veth-blue up

ip netns exec red ifconfig
ip netns exec blue ifconfig
ip netns exec red ping 192.168.15.2      # pod-to-pod on one host, with no NAT
```

And the extension to a **third** namespace via a bridge (the multi-node story in miniature):

```bash
ip link add veth-red type veth peer name veth-red-br
ip link set veth-red-br master cni0
```

> **Exam note** — "pod-to-pod connectivity is broken" almost always means one of: the CNI DaemonSet is not running on the
> new node, `net.ipv4.ip_forward` is `0`, `br_netfilter` is not loaded, or the pod CIDR the node advertised is wrong.
> Check `kubectl get pods -n kube-system -o wide`, then `ip a` on the node, then `ip route`.

---

## 3.2 Services — Lab `05.services.sh`

A Service is a **stable virtual IP + DNS name + port mapping** in front of a changing set of pods, selected by labels.

```bash
kubectl get services
kubectl get services -o wide
kubectl describe service kubernetes
kubectl get endpoints
kubectl get endpoints -o wide
kubectl get endpoints -o wide --all-namespaces
kubectl get deployments
kubectl describe deployment simple-webapp-deployment | grep -i image
```

`kubectl get endpoints` is the single best debugging command in this domain: **an empty Endpoints list means the
Service's selector matches no pods.** The selector is the whole mechanism — it is `spec.selector` of the Service
intersected with pod labels.

```bash
cat service-definition-1.yaml
vi service-definition-1.yaml
kubectl apply -f service-definition-1.yaml
kubectl describe service webapp-service
kubectl get services
curl 10.43.102.177
curl 10.43.102.177:8080
kubectl delete service webapp-service
kubectl expose deployment simple-webapp-deployment --port=8080 --type=NodePort
kubectl get service simple-webapp-deployment -o yaml
```

**[Your note]** — verbatim:

> *my first try node port exposed port was missing when i fixed it the service was accessible from external*

That is the NodePort gotcha: `kubectl expose --type=NodePort` with **no** `--node-port` leaves `spec.ports[].nodePort`
unset, and the API server allocates one from the range `30000-32767` — but the Service is *not* reachable until that
field exists. Pinning it explicitly is the fix:

```yaml
ports:
  - port: 8080          # the Service's own port
    targetPort: 8080    # the container's port
    nodePort: 30080     # the port on every node  ← this one
```

Your `Labs/services/service1.yaml` shows a fully-realised NodePort:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: simple-webapp-deployment
  namespace: default
spec:
  clusterIP: 10.43.216.1
  clusterIPs:
    - 10.43.216.1
  externalTrafficPolicy: Cluster
  internalTrafficPolicy: Cluster
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  ports:
    - nodePort: 32302
      port: 8080
      protocol: TCP
      targetPort: 8080
  selector:
    name: simple-webapp
  sessionAffinity: None
  type: NodePort
```

And `Labs/services/service2.yaml` is the minimal form:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: default
spec:
  ports:
    - nodePort:
      port: 8080
      targetPort: 8080
  selector:
    name: simple-webapp
  type: NodePort
```

### The four Service types

| Type | Reachable from | ClusterIP? | Use it for |
|---|---|---|---|
| `ClusterIP` (default) | Inside the cluster only | Yes | Pod-to-pod, the default |
| `NodePort` | `<anyNodeIP>:<nodePort>` from outside | Yes | Dev/test, bare metal, ingress controllers |
| `LoadBalancer` | A cloud LB's external IP | Yes | Production on a cloud |
| `ExternalName` | N/A — a CNAME in DNS | **No** | Pointing at an external service |

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
  type: NodePort
```

`Networking/nginx-service.yaml`, with the DNS annotations you wrote on it:

```yaml
# access from inside cluster same namespace:    http://nginx-service
#                                               http://nginx-service.default
# access from inside cluster another namespace: http://nginx-service.default.svc.cluster.local
```

### The DNS names, precisely

```
<service>                                    same namespace
<service>.<namespace>                        another namespace
<service>.<namespace>.svc                    (svc is optional but conventional)
<service>.<namespace>.svc.cluster.local      fully qualified
```

Headless services (`clusterIP: None`) return the **pod IPs** in their A records instead of a single virtual IP — that is
what a StatefulSet needs for `web-0.web`, `web-1.web`.

### `externalTrafficPolicy`

| Value | Behaviour |
|---|---|
| `Cluster` (default) | Every node accepts traffic and forwards it to a pod anywhere. **Source IP is lost** (SNAT). Extra network hop. |
| `Local` | Only nodes running a pod accept traffic; the real client IP is preserved. Requires at least one ready endpoint on every node or you get blackholes. |

### `sessionAffinity`

`None` (default) or `ClientIP`. Set it when your app is stateful and has no shared session store:

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
```

> **Exam note** — "Service has no endpoints" is the #1 networking failure. Diagnose with
> `kubectl get endpoints <svc>`, `kubectl describe svc <svc>` (compare `Selector`), and
> `kubectl get pods --show-labels` (compare the pod's labels). A typo in either label is the answer 90% of the time.

---

## 3.3 kube-proxy — how the virtual IP actually works

`ClusterIP` is not bound to any interface. It exists only as iptables/IPVS rules in the node's netfilter.

```bash
# On a node
sudo iptables -t nat -L KUBE-SERVICES -n | head
sudo iptables-save | grep -c KUBE
sudo ipvsadm -L -n                 # if kube-proxy is in IPVS mode
```

kube-proxy watches the API server for Service and Endpoints changes and rewrites these rules. Each `ClusterIP:port` gets
a chain; each endpoint gets a rule in that chain; `statistic mode random` does the load balancing.

```bash
# kube-proxy modes
kubectl -n kube-system describe pod kube-proxy-xxxxx | grep -i proxy-mode
# --proxy-mode=iptables   (default)   or   --proxy-mode=ipvs
```

| Mode | Load balancing | Scale | Notes |
|---|---|---|---|
| `iptables` | `statistic mode random` | Linear rule scan; ~5000 services degrades | Default |
| `ipvs` | Real algorithms (`rr`, `lc`, `wlc`, `sh`, `dh`) | Hash-based, scales to 100k+ | Needs `ipvsadm` on the node |
| `kernelspace` | Legacy | — | Removed in 1.29+ |
| `userspace` | Legacy | — | Deprecated, removed |

> **Exam note** — if you change `--proxy-mode` you must restart kube-proxy (it is a DaemonSet: `kubectl rollout restart
> ds/kube-proxy -n kube-system`).

---

## 3.4 NetworkPolicy — Lab `30-network-policy.sh`

Once a NetworkPolicy selects a pod, that pod is **isolated** for the declared directions and everything not explicitly
allowed is denied. Default is allow-all; a single policy flips it to deny-by-default for the pods it selects.

```bash
kubectl get networkpolicy
kubectl get networkpolicy payroll-policy -o yaml
kubectl get networkpolicy payroll-policy -o yaml > mynp.yaml
vi mynp.yaml
kubectl apply -f mynp.yaml
```

### Ingress — the payroll policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payroll-policy
  namespace: default
spec:
  ingress:
    - from:
        - podSelector:
            matchLabels:
              name: internal
      ports:
        - port: 8080
          protocol: TCP
  podSelector:
    matchLabels:
      name: payroll
  policyTypes:
    - Ingress
```

Reading it: *pods labelled `name=payroll` accept ingress **only** from pods labelled `name=internal`, and **only** on
TCP 8080.*

`Security/role-rolebinding/network-policy/policy.yaml` is the same object captured live from the cluster, and
`pod.yaml` is the `payroll` pod it protects:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    name: payroll
  name: payroll
  namespace: default
spec:
  containers:
    - env:
        - name: APP_NAME
          value: Payroll Application
        - name: BG_COLOR
          value: blue
      image: kodekloud/webapp-conntest
      # Alt image: quay.io/pandeysp/mywebapp:latest
      name: payroll
      ports:
        - containerPort: 8080
```

### Egress — the internal policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: internal-policy
spec:
  egress:
    - to:
        - podSelector:
            matchLabels:
              name: mysql
      ports:
        - port: 3306
          protocol: TCP
    - to:
        - podSelector:
            matchLabels:
              name: payroll
      ports:
        - port: 8080
          protocol: TCP
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
  podSelector:
    matchLabels:
      name: internal
  policyTypes:
    - Ingress
    - Egress
```

Note the third egress rule: it has **`ports` but no `to`** — that means "allow egress to anywhere on port 53". DNS must
be allowed explicitly or the pod cannot resolve any name.

### The namespace-based policy — `acg-multic-np.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-np
  namespace: users-backend
spec:
  podSelector: {}                      # selects ALL pods in this namespace
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              project: users-backend
      ports:
        - protocol: TCP
          port: 80
```

```bash
# label namespace
kubectl label namespace users-backend project=users-backend
# podSelector{} is required
```

**[Your note]** — verbatim: *`podSelector{}` is required.* An empty `podSelector: {}` is how you say "every pod in this
namespace" — and you must write the `{}`, not omit the key. Omitting `podSelector` entirely is a validation error.

### The three selectors and how they combine

| Selector | Matches | Typical use |
|---|---|---|
| `podSelector` (inside `spec.podSelector`) | Which pods **this policy applies to** | The policy's target |
| `podSelector` (inside `ingress[].from[]`) | Pods in the **same namespace** as the policy | "allow traffic from the app tier" |
| `namespaceSelector` | Pods in a **labelled namespace** | "allow traffic from the monitoring namespace" |
| `ipBlock.cidr` / `ipBlock.except` | External CIDRs | "allow traffic from the office IP" |

`podSelector` + `namespaceSelector` in the **same** `from` element are **ANDed** — "pods with this label *in* that
namespace". Listing them as **separate** elements of `from[]` is **OR** — "either of these".

```yaml
# AND: only pods labelled role=db inside namespaces labelled env=prod
ingress:
  - from:
      - podSelector:
          matchLabels: {role: db}
        namespaceSelector:
          matchLabels: {env: prod}

# OR: pods labelled role=db in this namespace, OR any pod in a namespace labelled env=prod
ingress:
  - from:
      - podSelector:
          matchLabels: {role: db}
      - namespaceSelector:
          matchLabels: {env: prod}
```

> **Exam note** — NetworkPolicy is **additive across policies** (a pod is allowed traffic if *any* policy allows it) but
> **restrictive within a policy** (each `ingress[]` entry is a complete allow rule; a pod selected by *no* policy at all
> is unrestricted). Also: NetworkPolicy requires a CNI that implements it — **flannel alone does not**. You need Calico,
> Cilium, Weave with the netpol flag, etc.

---

## 3.5 Ingress — Lab `33-ingress-1.sh`, `Ingress/*`, `Networking/*`

An Ingress is **L7 routing** (host + path → Service) in front of an Ingress controller. It is not a load balancer
itself — it is a *configuration object* the controller reads.

```bash
kubectl get ingress --all-namespaces
# NAMESPACE   NAME                 CLASS    HOSTS   ADDRESS         PORTS   AGE
# app-space   ingress-wear-watch   <none>   *       10.110.34.207   80      3m29s

kubectl get all --all-namespaces | grep -i ingress
# ingress-nginx   pod/ingress-nginx-admission-create-xdhxb        0/1     Completed   0          4m26s
# ingress-nginx   pod/ingress-nginx-admission-patch-zqsw8         0/1     Completed   0          4m26s
# ingress-nginx   pod/ingress-nginx-controller-7689699d9b-jk99z   1/1     Running     0          4m26s
# ingress-nginx   service/ingress-nginx-controller             NodePort    10.110.34.207    <none>        80:30080/TCP,443:32103/TCP   4m27s
# ingress-nginx   service/ingress-nginx-controller-admission   ClusterIP    10.98.59.3       <none>        443/TCP                      4m26s
# ingress-nginx   deployment.apps/ingress-nginx-controller   1/1     1            1            1            4m26s
# ingress-nginx   replicaset.apps/ingress-nginx-controller-7689699d9b   1         1        1        4m26s
# ingress-nginx   job.batch/ingress-nginx-admission-create   1/1     1            12s          4m26s
# ingress-nginx   job.batch/ingress-nginx-admission-patch    1/1     1            1            12s          4m26s
```

Note the **two Jobs** (`admission-create`, `admission-patch`). They generate and patch the TLS secret and the validating
webhook that guards the Ingress API. They are `Completed`, not `Running` — that is normal and not a failure.

### Examining and exporting an Ingress

```bash
kubectl get ingress ingress-wear-watch -o yaml -n app-space > temp.yaml
kubectl describe ingress ingress-wear-watch -n app-space
```

```
Name:             ingress-wear-watch
Namespace:        app-space
Address:          10.110.34.207
Ingress Class:    <none>
Default backend:  <default>
Rules:
  Host        Path  Backends
  ----        ----  --------
  *
              /wear    wear-service:8080 (10.244.0.4:8080)
              /watch   video-service:8080 (10.244.0.5:8080)
Annotations:  nginx.ingress.kubernetes.io/rewrite-target: /
              nginx.ingress.kubernetes.io/ssl-redirect: false
Events:
  Type    Reason     Age                    From                      Message
  ----    ------     ----                   -------                   -------
  Normal  Sync        8m22s (x2 over 8m23s)  nginx-ingress-controller  Scheduled for sync
```

The `Sync` event from `nginx-ingress-controller` is the controller telling you it accepted the object. **No `Sync` event =
the controller is not watching this Ingress class or namespace.**

```bash
kubectl describe ingress ingress-wear-watch -n app-space | grep -i default
# Default backend:  <default>
```

`Default backend: <default>` means there is no catch-all backend — requests matching no rule get a 404 from the
controller's own default service. Setting `spec.defaultBackend` gives you a custom 404 page.

### Host-based routing — `Networking/nginx-ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /welcome
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```

**Alternative image:** `# Alt image: quay.io/pandeysp/nginx-ambassador:latest` — your own nginx build, suitable for
standing in as the ingress backend.

### Multi-path routing — `Networking/student-ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: students-ingress
spec:
  rules:
    - host: www.students.com
      http:
        paths:
          - path: /teachers
            pathType: Prefix
            backend:
              service:
                name: teachers-service
                port:
                  number: 80
          - path: /courses
            pathType: Prefix
            backend:
              service:
                name: courses-service
                port:
                  number: 80
```

### Namespace-scoped with a specific host — `Ingress/my-ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: andromeda
spec:
  rules:
    - host: awsprolearner.link
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```

### `pathType` — three values, different matching

| `pathType` | Matching rule |
|---|---|
| `Prefix` | Longest-prefix match on URL path segments. `/` matches everything. |
| `Exact` | Exact string match, case-sensitive. |
| `ImplementationSpecific` | Whatever the controller decides (nginx treats it like `Prefix` with some regex support). |

**Omitting `pathType` is allowed** in `networking.k8s.io/v1` (it defaults to `ImplementationSpecific`) but it is bad
practice and older controllers reject it. Always set it.

### `ingressClassName`

```yaml
spec:
  ingressClassName: nginx        # which controller should handle this
  rules: [...]
```

Or the legacy annotation `kubernetes.io/ingress.class: nginx`. If you have more than one controller (nginx + traefik),
this field is how you avoid the wrong one picking it up.

### Rewrite — the annotation that catches everyone

Your live Ingress has `nginx.ingress.kubernetes.io/rewrite-target: /`. Without it, a request to `/wear` is proxied to the
backend as `/wear`, and an app that only serves `/` returns 404.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
    - http:
        paths:
          - path: /wear(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: wear-service
                port:
                  number: 80
```

`$2` is the capture group after the prefix. For a simple strip, `rewrite-target: /` is enough.

### TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
    - hosts: [secure.example.com]
      secretName: secure-tls        # a kubernetes.io/tls Secret
  rules:
    - host: secure.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 443
```

```bash
kubectl create secret tls secure-tls --cert=server.crt --key=server.key
```

### The full request path

```
Client
  │  http://www.students.com/courses
  ▼
DNS → ingress-controller NodeIP : NodePort(30080)
  ▼
ingress-nginx-controller pod
  │  matches Ingress rule host=www.students.com path=/courses
  ▼
Service courses-service : 80        (ClusterIP)
  ▼
Endpoints → pod 10.244.0.x : 80
  ▼
nginx container in that pod
```

> **Exam note** — three separate things people conflate. An **Ingress** is a config object. An **Ingress controller**
> is a Deployment + Service that reads those objects. A **Service of type LoadBalancer** is L4 and has nothing to do with
> Ingress. The exam's "expose this app on a host and path" question wants the Ingress object, and you must check that a
> controller is actually installed.

---

## 3.6 Lab `06.imperative-commands.sh` — everything you can do without a YAML file

```bash
kubectl create deployment nginx-pod --image=nginx:alpine
kubectl describe deployment nginx-pod

# two steps to be applied on deployment
kubectl create deployment redis --image=redis:alpine
kubectl label deployment redis tier=db

# for a pod we can label in one go
kubectl run redis --image=redis:alpine --labels=tier=db
kubectl expose pod redis --name=redis-service --port=6379

kubectl create deployment webapp --image=kodekloud/webapp-color --replicas=3
# Alt image: quay.io/pandeysp/mywebapp:latest

kubectl run custom-nginx --image=nginx --port=8080

kubectl create namespace dev-ns
kubectl create deployment redis-deploy --image=redis --replicas=2 -n dev-ns

kubectl run httpd --image=httpd:alpine
kubectl expose pod httpd --port=80
```

**[Your note]** — verbatim, and the asymmetry is worth memorising:

> *two steps to be applied on deployment* — `kubectl create deployment` has no `--labels` flag, so you label afterwards.
>
> *for a pod we can label in one go* — `kubectl run` **does** have `--labels`.

**Alternative images for this lab:**

```bash
kubectl run webapp --image=quay.io/pandeysp/mywebapp:latest --replicas=3
kubectl run tea   --image=quay.io/pandeysp/tea:latest
kubectl run coffee --image=quay.io/pandeysp/coffee:latest
```

The `tea` / `coffee` pair is ideal for a two-tier service demo: deploy both, expose both, and show that `tea` can reach
`coffee` by ClusterIP DNS but nothing outside can.

### `--dry-run` matrix

| Object | Command |
|---|---|
| Pod | `kubectl run nginx --image=nginx --dry-run=client -o yaml` |
| Deployment | `kubectl create deploy nginx --image=nginx --dry-run=client -o yaml` |
| Service (ClusterIP) | `kubectl expose deploy nginx --port=80 --dry-run=client -o yaml` |
| Service (NodePort) | `kubectl expose deploy nginx --port=80 --type=NodePort --dry-run=client -o yaml` |
| ConfigMap | `kubectl create configmap cm --from-literal=k=v --dry-run=client -o yaml` |
| Secret | `kubectl create secret generic s --from-literal=k=v --dry-run=client -o yaml` |
| ServiceAccount | `kubectl create sa sa --dry-run=client -o yaml` |
| Job | `kubectl create job j --image=busybox --dry-run=client -o yaml` |
| CronJob | `kubectl create cj c --image=busybox --schedule="* * * * *" --dry-run=client -o yaml` |
| Namespace | `kubectl create ns ns --dry-run=client -o yaml` |
| ResourceQuota | `kubectl create quota q --hard=pods=10 --dry-run=client -o yaml` |

> **Exam note** — there is **no** `kubectl create replicaset`, `kubectl create daemonset`, `kubectl create statefulset`,
> or `kubectl create networkpolicy`. Derive those from a Deployment manifest and edit. (There *is*
> `kubectl create ingress` and `kubectl create role`/`clusterrole`/`rolebinding`/`clusterrolebinding`.)

---

## 3.7 The namespaces your networking labs live in

```bash
kubectl get ns
# NAME              STATUS   AGE
# app-space         Active   22m
# critical-space    Active   14s
# default           Active   23m
# ingress-nginx     Active   22m
# kube-flannel      Active   23m
# kube-node-lease   Active   23m
# kube-public       Active   23m
# kube-system       Active   23m

kubectl get all -n critical-space
# NAME                              READY   STATUS    RESTARTS   AGE
# pod/webapp-pay-657d677c99-gmxjc   1/1     Running   0          39s
#
# NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
# service/pay-service   ClusterIP   10.96.249.7    <none>        8282/TCP   39s
#
# NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/webapp-pay   1/1     1            1            39s
#
# NAME                                    DESIRED   CURRENT   READY   AGE
# replicaset.apps/webapp-pay-657d677c99   1         1        1        39s
```

`Services/fast.yaml` is a deployment in the `accounting` namespace:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: accounting
  labels:
    app: webserver
  name: webserver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webserver
  template:
    metadata:
      labels:
        app: webserver
    spec:
      containers:
        - image: nginx
          # Alt image: quay.io/pandeysp/nginx:latest
          name: nginx
```

---

## 3.8 IPv6 / dual-stack — the `langflow` images

Your registry has `quay.io/pandeysp/langflow:ipv6-dev` and `quay.io/pandeysp/langflow:ipv6-v1`, which points at
dual-stack work. The relevant Service fields:

```yaml
spec:
  ipFamilies:
    - IPv6
    - IPv4
  ipFamilyPolicy: PreferDualStack      # or RequireDualStack / SingleStack
```

```bash
# Check what the cluster supports
kubectl get nodes -o jsonpath='{.items[*].status.addresses}' ; echo
kubectl cluster-info dump | grep -i service-cluster-ip-range
kubectl -n kube-system describe pod kube-apiserver-controlplane | grep -i cluster-ip-range
# --service-cluster-ip-range=10.96.0.0/12,fd00::/108   (dual-stack)
```

---

## 3.9 Part III self-check

1. `kubectl get endpoints mysvc` is empty. Name the three commands that find the cause.
2. A pod labelled `name=payroll` is selected by a policy allowing ingress from `name=internal` on 8080 only. Can it
   receive traffic on 9090? Can it receive from a pod labelled `name=external`?
3. You write a NetworkPolicy with `podSelector` omitted. What happens?
4. Two CNI plugins: one implements NetworkPolicy, one does not. Which one do you pick, and why does flannel alone fail
   here?
5. What is the difference between an Ingress and an Ingress controller?
6. `externalTrafficPolicy: Local` — what breaks if no pod is scheduled on the node receiving the traffic?
7. `pathType: Prefix` with `path: /` — what does it match?
8. Why does the third egress rule in the `internal-policy` have `ports` but no `to`?
9. A pod on `node01` cannot reach a pod on `node02`. Give four things to check, in order.
10. `kubectl expose pod redis --name=redis-service --port=6379` — what Service type do you get?


\pagebreak

## Part IV — Storage

**CKA weight: ~10%**

The smallest domain, but the one with the most unforgiving details — a wrong access mode or a missing `storageClassName`
means a PVC that stays `Pending` forever and a pod stuck in `ContainerCreating`.

**Competencies covered in this part**

1. Understand storage classes, persistent volumes and persistent volume claims
2. Understand the container storage interface (CSI)
3. Know how to configure applications with persistent storage
4. Understand volume modes, access modes and reclaim policies
5. Understand persistent volume claims and how they bind

---

## 4.1 The three objects

```
Pod ──claims──▶ PersistentVolumeClaim ──binds──▶ PersistentVolume ◀──provisioned by── StorageClass
                  (what the app wants)              (the actual disk)                (dynamic provisioning)
```

| Object | Who creates it | Scope | Purpose |
|---|---|---|---|
| **PersistentVolume (PV)** | Cluster admin (or the provisioner) | Cluster-wide | A piece of storage, independent of any pod |
| **PersistentVolumeClaim (PVC)** | The app developer | Namespaced | A *request* for storage: size + access mode |
| **StorageClass** | Cluster admin | Cluster-wide | A recipe for **dynamically** provisioning PVs |

The lifecycle: PVC is created → the control loop looks for a matching PV → **Binding** → the pod mounts it → the pod
dies → the PVC and PV survive → the PVC is deleted → the PV is **Released** → per the reclaim policy it becomes
`Available` again, or is **Deleted**, or is **Retained**.

### Static provisioning vs dynamic provisioning

| | Static | Dynamic |
|---|---|---|
| PV created by | Admin, by hand | StorageClass provisioner, automatically |
| PVC must specify | Nothing (or `volumeName`) | `storageClassName` |
| StorageClass needed | No | **Yes** |
| Failure mode | PVC stays `Pending` if no PV matches | PVC stays `Pending` if the provisioner is missing/broken |

---

## 4.2 PV and PVC definitions — Lab `31-pv-pvc-definition.sh`

**[Your note]** — verbatim, and this is the single most useful sentence in the whole storage domain:

> *for pv and pvc to be automatically bound access mode must match. if one of them is readwriteonce and the other one is
> readwriteany they dont match and wont bound*

That is correct and it is the #1 cause of a `Pending` PVC.

```yaml
###############
#  PV definition
###############

apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-log
spec:
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /pv/log
```

```yaml
###############
#  PVC definition
###############

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-log-1
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Mi
```

Note the PVC requests **50Mi** from a **100Mi** PV. That is legal and correct — the binding controller needs
`pv.capacity >= pvc.request`, not equality.

### NFS-backed PV — `VolumesAndData/PVol.yaml`

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pvvol-1
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /opt/sfw
    server: ip-172-31-40-74
    readOnly: false
```

### Matching PVC — `VolumesAndData/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-one
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 200Mi
```

### Using it in a workload — `VolumesAndData/nfs-pod.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-nfs
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      run: nginx
  template:
    metadata:
      labels:
        run: nginx
    spec:
      containers:
        - image: nginx
          # Alt image: quay.io/pandeysp/nginx:latest
          name: nginx
          volumeMounts:               # <--  Add these three lines
            - name: nfs-vol
              mountPath: /opt
          ports:
            - containerPort: 80
      volumes:                           # <-- Add these four lines
        - name: nfs-vol
          persistentVolumeClaim:
            claimName: pvc-one
```

The three-step pattern that repeats for every PV lab:

```yaml
# 1. the volume in the POD spec
volumes:
  - name: nfs-vol
    persistentVolumeClaim:
      claimName: pvc-one

# 2. the mount in the CONTAINER spec
volumeMounts:
  - name: nfs-vol          # must match the volume name exactly
    mountPath: /opt

# 3. (optional) restrict the volume
    readOnly: true
```

### The three "volume sources" you will see

```yaml
volumes:
  - name: a
    hostPath:                        # a directory on the node
      path: /var/log/webapp
      type: DirectoryOrCreate
  - name: b
    emptyDir: {}                     # lives as long as the pod; shared between containers
  - name: c
    persistentVolumeClaim:
      claimName: pvc-one             # a bound PVC
```

| Volume | Lifetime | Shared between containers? | Survives pod restart? |
|---|---|---|---|
| `emptyDir` | The pod | Yes | No (new emptyDir per pod) |
| `hostPath` | The node | Yes | **Yes** — but ties the pod to that node |
| `persistentVolumeClaim` | The PVC | Yes | Yes |

---

## 4.3 Access modes

| Mode | Abbrev | Meaning | Typical backend |
|---|---|---|---|
| `ReadWriteOnce` | **RWO** | One **node** can mount read-write | Block storage: EBS, GCE PD, Azure Disk, local disk |
| `ReadOnlyMany` | **ROX** | Many nodes, read-only | NFS, object stores |
| `ReadWriteMany` | **RWX** | Many nodes, read-write | NFS, GlusterFS, CephFS, Filestore |
| `ReadWriteOncePod` | **RWOP** | Exactly one **pod** (not node) in the whole cluster | CSI with that capability |

```yaml
accessModes:
  - ReadWriteOnce
  # - ReadOnlyMany
  # - ReadWriteMany
  # - ReadWriteOncePod
```

**Matching rules for binding:**

* The PVC's `accessModes` must be a **subset** of the PV's.
* The PVC's `storage` request must be **≤** the PV's `capacity`.
* If `volumeBindingMode: Immediate` and `storageClassName` is set, the provisioner must exist.
* A PVC with `storageClassName: ""` explicitly binds **only** to a PV that also has `storageClassName: ""`.
* A PVC with **no** `storageClassName` field and a cluster with a **default** StorageClass uses that default.

---

## 4.4 Reclaim policies

Set on the **PV** (and inherited from the StorageClass), not the PVC.

| Policy | On PVC deletion |
|---|---|
| `Retain` | The PV and its **data survive**; the PV goes to `Released` and is **not** reusable until an admin manually clears the claimRef and resets it to `Available`. |
| `Delete` | The PV **and the underlying storage** are deleted. This is the dynamic-provisioning default for most cloud provisioners. |
| `Recycle` | **Deprecated and removed.** Ignore it if you see it in old material. |

```bash
# Manually resurrect a Retained PV
kubectl get pv
# NAME   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM
# pv-log 100Mi      RWX            Retain           Released   default/claim-log-1

kubectl patch pv pv-log -p '{"spec":{"claimRef": null}}'
kubectl get pv
# ...  STATUS   Available
```

**[Your note]** from `Labs/31-storage-class.yaml` — the lifecycle you observed:

> *after deleting the pvc the pvc hangs in terminating*
> *deleting the pod the pvc is deleted the pv is released but not available*

Exactly right:

1. `kubectl delete pvc` with a pod still mounting it → the PVC hangs in `Terminating` because the finalizer
   `kubernetes.io/pvc-protection` blocks it while it is in use.
2. Delete the pod first → the PVC is removed → the PV moves to `Released` (with `Retain`) or is deleted (with `Delete`).
3. `Released` ≠ `Available` — a `Retain` PV is **not** automatically reusable. You must clear `spec.claimRef`.

---

## 4.5 StorageClasses — Lab `31-storage-class.sh`

From `VolumesAndData/readme.md`, verbatim:

> **StorageClasses** enables dynamic provisioning of storage resources.
>
> **Provisioners** are responsible for dynamically provisioning storage volumes. Without StorageClasses, administrators
> have to manually create PersistentVolumes (PVs) for each PersistentVolumeClaim (PVC) made by users. With
> StorageClasses, this process is automated. When a user creates a PVC and specifies a StorageClass, the system
> automatically creates a corresponding PV that meets the requirements.
>
> so we have storage class as an automation wrapper to create PV (persistent Volume)
>
> while StorageClasses alone don't handle the provisioning of storage volumes (which requires provisioners), they provide
> a layer of abstraction that streamlines the process of requesting and managing storage in Kubernetes. By leveraging
> StorageClasses, users can benefit from automated, on-demand provisioning of storage resources while abstracting away
> the complexities of the underlying storage infrastructure.

```bash
kubectl get storageclass
kubectl get storageclass -o wide
kubectl describe storageclass local-storage
kubectl describe storageclass portworx-io-priority-high
kubectl get pvc -o wide
kubectl get pv
kubectl get pv local-pv -o yaml
kubectl describe pv local-pv
kubectl apply -f my-pvc.yaml
kubectl get pvc
kubectl describe pvc local-pvc
kubectl events pvc local-pvc
kubectl get pvc
kubectl get pvc local-pvc -o yaml
kubectl run nginx --image=nginx:alpine --dry-run=client -o yaml > pod.yaml
```

### The StorageClass manifest — `Labs/31-storage-class.yaml`

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: delayed-volume-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

The three fields that matter:

| Field | Values | Effect |
|---|---|---|
| `provisioner` | e.g. `ebs.csi.aws.com`, `kubernetes.io/no-provisioner`, `cluster.local/nfs-subdir-external-provisioner` | Which plugin creates the volume |
| `volumeBindingMode` | `Immediate` (default) / `WaitForFirstConsumer` | **When** the PV is created |
| `reclaimPolicy` | `Delete` (default) / `Retain` | What happens to the PV when the PVC goes |
| `allowVolumeExpansion` | `true` / `false` | Whether a PVC can be resized |

### `WaitForFirstConsumer` — the local-storage trick

`kubernetes.io/no-provisioner` means "no dynamic provisioning; PVs are pre-created by an admin". Combined with
`WaitForFirstConsumer`, the scheduler delays binding until it has picked a node, so a `local` PV only binds to a pod
that actually landed on the node holding the disk. Without it, you get pods `Pending` forever because the PV is on the
wrong node.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

```yaml
# The matching PV, pinned to a node
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 500Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disk
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values: [node01]
```

### A PVC that uses it, and a pod that mounts it

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 500Mi
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
  name: nginx
spec:
  containers:
    - image: nginx:alpine
      # Alt image: quay.io/pandeysp/alpine:latest
      name: nginx
      volumeMounts:
        - name: local-persistent-storage
          mountPath: /var/www/html
  dnsPolicy: ClusterFirst
  volumes:
    - name: local-persistent-storage
      persistentVolumeClaim:
        claimName: local-pvc
  restartPolicy: Always
```

### A PVC with a placeholder class name — `VolumesAndData/pvc-storage-class.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: <storage-class-name>     # replace with `kubectl get sc` output
  resources:
    requests:
      storage: 1Gi
```

and `VolumesAndData/pod-with-storage-class.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
    - name: nginx
      image: nginx:latest
      # Alt image: quay.io/pandeysp/nginx:latest
      volumeMounts:
        - name: nginx-storage
          mountPath: /usr/share/nginx/html
  volumes:
    - name: nginx-storage
      persistentVolumeClaim:
        claimName: nginx-pvc
```

### The provisioners list — `VolumesAndData/readme.md`

> In addition to NFS provisioners, there are various other types of provisioners used in Kubernetes for dynamic
> provisioning of storage. Here are a few examples:
>
> **AWS Elastic Block Store (EBS) Provisioner:** An AWS EBS provisioner dynamically creates EBS volumes in AWS cloud
> environments to fulfill PersistentVolumeClaims (PVCs). It interacts with the AWS API to create, attach, and mount EBS
> volumes as needed by Kubernetes applications.
>
> **Google Compute Engine (GCE) Persistent Disk Provisioner:** Similar to AWS EBS provisioner, the GCE Persistent Disk
> provisioner dynamically creates and manages GCE persistent disks in Google Cloud Platform (GCP) environments.
>
> **Azure Disk Provisioner:** In Azure Kubernetes Service (AKS) or other Azure environments, the Azure Disk provisioner
> dynamically provisions Azure managed disks to fulfill storage requirements of Kubernetes applications.
>
> **Local Persistent Volume Provisioner:** The local persistent volume provisioner allows Kubernetes applications to use
> local storage resources on cluster nodes. It dynamically creates PersistentVolumes backed by local disks on the nodes,
> enabling applications to access and utilize local storage efficiently.
>
> **GlusterFS Provisioner:** GlusterFS provisioner dynamically provisions storage volumes using GlusterFS, a distributed
> file system. It creates and manages GlusterFS volumes to fulfill PVCs requested by applications running in the cluster.
>
> **Ceph RBD Provisioner:** Ceph RBD (Rados Block Device) provisioner dynamically provisions block storage volumes using
> Ceph, a distributed storage system. It creates and manages RBD volumes to fulfill PVCs requested by applications
> running in the cluster.

### A real external provisioner — `VolumesAndData/provisioner-pod.yaml`

```yaml
spec:
  containers:
    - env:
        - name: PROVISIONER_NAME
          value: cluster.local/nfs-subdir-external-provisioner
        - name: NFS_SERVER
          value: k8scp
        - name: NFS_PATH
          value: /opt/sfw/
      image: registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
      name: nfs-subdir-external-provisioner
      volumeMounts:
        - mountPath: /persistentvolumes
          name: nfs-subdir-external-provisioner-root
  serviceAccountName: nfs-subdir-external-provisioner
  volumes:
    - name: nfs-subdir-external-provisioner-root
      nfs:
        path: /opt/sfw/
        server: k8scp
```

The `PROVISIONER_NAME` env var is the string that goes into `StorageClass.provisioner` — that is the whole contract
between a StorageClass and its provisioner. Your repo also has `provisioner-deployment.yaml` and
`provisioner-rs.yaml`, the same thing wrapped in a controller.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs
provisioner: cluster.local/nfs-subdir-external-provisioner   # must match PROVISIONER_NAME
parameters:
  archiveOnDelete: "false"
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

### Mark a StorageClass as the default

```bash
kubectl patch storageclass local-storage \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Only one class may be default. A PVC with no `storageClassName` picks it up automatically.

---

## 4.6 Volume modes, and expanding a PVC

```yaml
spec:
  volumeMode: Filesystem     # default; the only other value is Block
  # volumeMode: Block        # a raw block device; the pod gets a device path, not a mountPath
```

```yaml
# Resize an existing PVC (needs allowVolumeExpansion: true on the class)
kubectl patch pvc local-pvc -p '{"spec":{"resources":{"requests":{"storage":"1Gi"}}}}'
kubectl get pvc local-pvc
# CAPACITY may lag until the pod is restarted — FileSystemResizePending
```

---

## 4.7 CSI in one paragraph

The **Container Storage Interface** lets storage vendors ship an out-of-tree plugin: a DaemonSet (`node-driver-registrar`
+ `node`) and a Deployment (`controller`). Kubernetes calls `NodeStageVolume`, `NodePublishVolume`, `NodeUnpublishVolume`,
`NodeUnstageVolume` on the node side, and `CreateVolume`/`DeleteVolume`/`ControllerPublishVolume` on the controller side.

```bash
# Inspect the CSI plumbing on a node
ls /var/lib/kubelet/plugins/<driver>/        # the CSI socket directory
ls /var/lib/kubelet/plugins_registry/
kubectl get csidrivers
kubectl get csinodes
```

> **Exam note** — you will not be asked to write a CSI driver. You will be asked to find why a dynamically provisioned
> volume is not appearing: `kubectl get sc`, `kubectl describe pvc` (look for `waiting for first consumer` or
> `provisioning failed`), then `kubectl get events --sort-by=.lastTimestamp`, then the provisioner's own logs.

---

## 4.8 Lab `31-host-volume-mount.yaml` — the webapp with a hostPath log volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  namespace: default
spec:
  containers:
    - env:
        - name: LOG_HANDLERS
          value: file
      image: kodekloud/event-simulator
      # Alt image: quay.io/pandeysp/hotel:latest
      imagePullPolicy: Always
      name: event-simulator
      volumeMounts:
        - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          name: kube-api-access-dknlc
        - mountPath: /log
          name: log-volume
          readOnly: true
  volumes:
    - name: log-volume
      hostPath:
        path: /var/log/webapp
        type: directory
    - name: kube-api-access-dknlc
      projected:
        defaultMode: 420
        sources:
          - serviceAccountToken:
              expirationSeconds: 3607
              path: token
          - configMap:
              items:
                - key: ca.crt
                  path: ca.crt
              name: kube-root-ca.crt
          - downwardAPI:
              items:
                - fieldRef:
                    apiVersion: v1
                    fieldPath: metadata.namespace
                  path: namespace
```

Note `type: directory` — the pod will not start if `/var/log/webapp` does not exist as a directory. The alternatives are:

| `hostPath.type` | Requirement |
|---|---|
| `""` (empty) | No check at all |
| `DirectoryOrCreate` | Create it if missing |
| `Directory` | Must exist as a directory, else the pod stays `ContainerCreating` |
| `FileOrCreate` | Create an empty file if missing |
| `File` | Must exist as a file |
| `Socket` | Must exist as a unix socket |
| `CharDevice` / `BlockDevice` | Must exist as a device node |

```bash
# Verify the mount landed
kubectl get pods
kubectl exec webapp -- cat /log/app.log
kubectl get pv -o wide
kubectl get pvc -o wide
kubectl edit pod webapp
kubectl delete pod webapp --force
kubectl apply -f /tmp/kubectl-edit-1157805548.yaml
```

`kubectl exec webapp -- cat /log/app.log` is the fastest proof that a volume mounted correctly — if the file is there, the
volume, the mountPath and the app's write path are all correct.

---

## 4.9 Part IV self-check

1. A PVC requests `ReadWriteOnce`; the only PV offers `ReadWriteMany`. Does it bind? Why?
2. A PVC with `Retain` was deleted. The PV shows `Released`. How do you make it `Available` again?
3. You want a PV to be created only after the scheduler picks a node. Which two fields do you set?
4. What is the difference between `emptyDir` and `hostPath` for a sidecar log shipper?
5. `kubectl delete pvc` hangs in `Terminating`. What is holding it, and what do you delete first?
6. Where is `reclaimPolicy` set — the PV, the PVC, or the StorageClass?
7. What does `PROVISIONER_NAME` in the NFS provisioner's env correspond to?
8. A pod is `ContainerCreating` and `kubectl describe` says `MountVolume.SetUp failed ... hostPath type check failed`. Fix?
9. `storageClassName: ""` — what does that mean?
10. `volumeMode: Block` — what does the container see?


\pagebreak

## Part V — Security

**CKA weight: ~20%**

Your repo is unusually strong here — ten labs plus the whole `Security/` folder covering RBAC from three angles,
ServiceAccounts, image pull secrets, security contexts, certificates, CSRs and kubeconfigs.

**Competencies covered in this part**

1. Know how to configure authentication and authorization
2. Understand Kubernetes security primitives
3. Know how to configure network policies (covered in Part III)
4. Understand and configure the Kubernetes certificate system
5. Know how to configure `kubectl` contexts and switch between them
6. Create and manage TLS certificates for cluster components
7. Know how to configure a SecurityContext for a pod or container
8. Define the permissions a ServiceAccount has
9. Know how to create and use ServiceAccounts
10. Know how to pull images from a private registry

---

## 5.1 The four security gates

```
Request
  │
  ├─ 1. AUTHENTICATION   Who are you?      → certs, tokens, OIDC, webhook
  ├─ 2. AUTHORISATION    May you do this?  → RBAC (the only mode you need for the CKA)
  ├─ 3. ADMISSION        Should this object exist? → validating/mutating webhooks, PodSecurity
  └─ 4. RUNTIME          What may the process do? → SecurityContext, seccomp, AppArmor, capabilities, NetworkPolicy
```

Kubernetes has **no user objects**. Users come from the credentials in their kubeconfig — the certificate's `CN` becomes
the username, the `O` becomes the group.

```bash
# Which user am I?
kubectl config view --minify -o jsonpath='{..user}'; echo
kubectl auth whoami          # 1.28+
```

---

## 5.2 RBAC — the model

Four objects:

| Object | Scope | Grants permissions to... |
|---|---|---|
| **Role** | Namespaced | subjects, **within one namespace** |
| **ClusterRole** | Cluster-wide | subjects, **across all namespaces** |
| **RoleBinding** | Namespaced | binds a Role or ClusterRole to subjects **in one namespace** |
| **ClusterRoleBinding** | Cluster-wide | binds a ClusterRole to subjects **cluster-wide** |

A **RoleBinding can reference a ClusterRole** — that is the standard way to grant a cluster-wide set of verbs to a user
in a single namespace (e.g. bind the built-in `edit` ClusterRole to a team in their namespace).

### The three parts of a rule

```yaml
rules:
  - apiGroups: ["", "apps", "extensions"]   # "" is the core group
    resources: ["pods", "deployments"]
    resourceNames: ["blue-app"]              # OPTIONAL: restrict to named objects
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

| `apiGroups` value | Meaning |
|---|---|
| `""` | The core group — pods, services, secrets, configmaps, namespaces, nodes, PVs, PVCs, serviceaccounts |
| `apps` | deployments, replicasets, statefulsets, daemonsets |
| `batch` | jobs, cronjobs |
| `networking.k8s.io` | ingresses, networkpolicies |
| `rbac.authorization.k8s.io` | roles, rolebindings, clusterroles, clusterrolebindings |
| `storage.k8s.io` | storageclasses, csidrivers |
| `extensions` | **Legacy**, pre-1.16. `kubectl` still accepts it for backward compatibility. |

```bash
kubectl api-resources --api-group=apps
kubectl api-resources --namespaced=false        # cluster-scoped resources
```

Valid `verbs`: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`, `use`,
`bind`, `escalate`, `impersonate`, `approve`, `sign`. Plus the wildcard `*`.

> **Exam note** — `kubectl get pods` needs **both** `get` and `list`. `kubectl delete pod` needs `delete`. A common exam
> trap is a Role with only `get` and a task that says "list the pods" — it will fail.

### Checking what you can do

```bash
kubectl auth can-i list pods
kubectl auth can-i create deployments -n dev
kubectl auth can-i delete nodes                    # cluster-scoped
kubectl auth can-i '*' '*'                          # am I cluster-admin?
kubectl auth can-i list pods --as dev-user
kubectl auth can-i list pods --as system:serviceaccount:default:default
kubectl auth can-i list secrets -n kube-system --as dev-user
```

---

## 5.3 Lab `25-role-based-access-control.sh`

```bash
ls /etc/kubernetes/manifests/
cat kube-apiserver.yaml | grep -i authorization
#   - --authorization-mode=Node,RBAC

kubectl get roles
kubectl get roles --all-namespaces
kubectl get roles --all-namespaces | wc

kubectl get role kube-proxy -n kube-system -o yaml
kubectl get rolebindings -n kube-system
kubectl get rolebindings -n kube-system | grep -i proxy
kubectl describe rolebinding kube-proxy -n kube-system
```

**[Your note]** — the `--authorization-mode=Node,RBAC` line is the one to remember. `Node` authorises the kubelet's own
requests; `RBAC` handles everything else. If RBAC is not in that list, no Role or RoleBinding has any effect and the
exam's RBAC question is unsolvable until you add it.

```bash
cat .kube/config
kubectl get all -n blue
kubectl get rolebindings
kubectl get rolebindings --all-namespaces

kubectl get rolebindings -n blue
kubectl get rolebinding dev-user-binding -o yaml -n blue
kubectl get role developer -o yaml -n blue

kubectl get pods --as dev-user
kubectl edit role developer -n blue
kubectl get pods --as dev-user
vi my-role.yaml
kubectl apply -f my-role.yaml
kubectl get rolebindings -n blue
kubectl get rolebindings -n blue -o yaml > my-rb.yaml
vi my-rb.yaml
kubectl apply -f my-role.yaml
kubectl apply -f my-rb.yaml
```

### The `developer` role in namespace `blue` — `Labs/rb.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: blue
rules:
  - apiGroups:
      - apps
    resourceNames:
      - blue-app
      - dark-blue-app
    resources:
      - pods
      - deployments
    verbs:
      - get
      - watch
      - create
      - delete
      - list
```

`resourceNames` is the field people forget. It narrows the rule to **only** objects named `blue-app` and
`dark-blue-app` — so `dev-user` can `get` those two pods but nothing else.

### The broader `developer` role — `Security/role-dev.yaml`

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: development
  name: developer
rules:
  - apiGroups: ["", "extensions", "apps"]
    resources: ["deployments", "replicasets", "pods"]
    verbs: ["list", "get", "watch", "create", "update", "patch", "delete"]
# You can use ["*"] for all verbs
```

### RoleBinding — `Security/rolebind.yaml`

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: developer-role-binding
  namespace: development
subjects:
  - kind: User
    name: polaris
    apiGroup: ""
roleRef:
  kind: Role
  name: developer
  apiGroup: ""
```

### `Security/rolebindprod.yaml` — the "reuse in another namespace" pattern

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: production-role-binding  # <-- Edit to production
  namespace: production          # <-- Also here
subjects:
  - kind: User
    name: polaris
    apiGroup: ""
roleRef:
  kind: Role
  name: dev-prod                 # <-- Also this
  apiGroup: ""
```

**[Your note]** — the three inline comments are exactly the edits needed: **metadata.name**, **metadata.namespace**, and
**roleRef.name** must all be changed, because `roleRef` is **immutable** on a live RoleBinding.

> **Exam note** — `roleRef` and `subjects` are both **immutable** after creation on RoleBinding/ClusterRoleBinding. If
> you get one wrong, delete and recreate. This is a very common exam time-sink.

### Sample role + binding — `Security/role-rolebinding/role.yaml` and `role-binding.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sample-role
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sample-role-binding
subjects:
  - kind: User
    name: alice
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: sample-role
  apiGroup: rbac.authorization.k8s.io
```

> Note the inconsistency between the two files: `rolebind.yaml` uses `apiGroup: ""` for both subject and roleRef, while
> `role-binding.yaml` uses `apiGroup: rbac.authorization.k8s.io`. For `roleRef` the correct value is
> **`rbac.authorization.k8s.io`**; for a `User` subject it is **`""`** (the core group). The `""` in `rolebind.yaml` is
> tolerated by the API server for backward compatibility but is technically wrong.

### Building RBAC imperatively — from `Security/role-rolebinding/history.sh`

```bash
kubectl get role developer -n blue -o yaml > new-role.yaml
vi new-role.yaml
kubectl apply -f new-role.yaml

kubectl create rolebinding developer-edit-rb --dry-run=client -o yaml
kubectl create rolebinding developer-edit-rb --dry-run=client

kubectl get rolebindings -n blue
kubectl get rolebinding dev-user-binding -o yaml -n blue > new-role-b.yaml
vi new-role-b.yaml
kubectl apply -f new-role-b.yaml
```

The full imperative forms:

```bash
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n default
kubectl create rolebinding read-pods --role=pod-reader --user=dev-user -n default
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding read-nodes --clusterrole=node-reader --user=dev-user
kubectl create rolebinding read-pods --clusterrole=view --serviceaccount=default:dashboard-sa -n default
```

> **Exam note** — `kubectl create rolebinding X --role=Y` binds a **Role**; `--clusterrole=Y` binds a **ClusterRole**.
> Using the wrong flag produces a binding whose `roleRef.kind` doesn't match and the permissions silently don't apply.

---

## 5.4 ClusterRoles and ClusterRoleBindings — Lab `26-cluster-roles.sh`

```bash
kubectl get clusterroles
kubectl get clusterrolebindings
kubectl get clusterroles | wc
kubectl get clusterrolebindings | wc
kubectl get clusterroles --all-namespaces
kubectl get clusterroles | grep -i "cluster-admin"
kubectl describe clusterrole cluster-admin
kubectl get clusterrole cluster-admin -o yaml
kubectl describe clusterrolebinding cluster-admin
```

### `cluster-admin` — `Labs/cluster-any-action-any-resource.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
rules:
  - apiGroups:
      - '*'
    resources:
      - '*'
    verbs:
      - '*'
  - nonResourceURLs:
      - '*'
    verbs:
      - '*'
```

Note the **second rule**: `nonResourceURLs`. That is what lets `cluster-admin` hit `/healthz`, `/version`, `/metrics` —
the non-resource endpoints. A ClusterRole with only the first rule cannot.

The `describe` output you captured:

```
kubectl describe clusterrole cluster-admin
Name:         cluster-admin
Labels:       kubernetes.io/bootstrapping=rbac-defaults
Annotations:  rbac.authorization.kubernetes.io/autoupdate: true
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  *.*        []                 []              [*]
             [*]                []              [*]

kubectl describe clusterrolebinding cluster-admin
Name:         cluster-admin
Labels:       kubernetes.io/bootstrapping=rbac-defaults
Annotations:  rbac.authorization.kubernetes.io/autoupdate: true
Role:
  Kind:  ClusterRole
  Name:  cluster-admin
Subjects:
  Kind   Name            Namespace
  ----   ----            ---------
  Group  system:masters
```

`system:masters` is the group your `kubernetes-admin` certificate's `O` field is set to — that is why the default admin
kubeconfig can do everything.

### The `michelle` ClusterRole + binding — from `Labs/26-cluster-roles.sh`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: michelle
rules:
  - apiGroups:
      - ""
    resources:
      - nodes
      - persistentvolumes
      - storageclasses
    verbs:
      - get
      - create
      - list
      - watch
      - delete
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: michelle
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: michelle
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: michelle
```

```bash
kubectl apply -f my-cluster-role.yaml
kubectl apply -f my-cluster-role-binding.yaml
kubectl auth can-i list nodes --as michelle
```

Note the subject's `apiGroup: rbac.authorization.k8s.io` — again, for a `User` subject the correct value is `""`. It
works either way in practice, but `""` is correct.

### Which resources are cluster-scoped?

```bash
kubectl api-resources --namespaced=false
```

Typical output:

```
NAME                     SHORTNAMES   APIVERSION   NAMESPACED
clusterrolebindings                rbac.authorization.k8s.io/v1   false
clusterroles                       rbac.authorization.k8s.io/v1   false
componentstatuses        cs         v1                           false
csidrivers                         storage.k8s.io/v1             false
csinodes                           storage.k8s.io/v1             false
namespaces              ns         v1                           false
nodes                   no         v1                           false
persistentvolumes       pv         v1                           false
storageclasses          sc         storage.k8s.io/v1             false
mutatingwebhookconfigurations       admissionregistration.k8s.io/v1  false
validatingwebhookconfigurations     admissionregistration.k8s.io/v1  false
apiservices                        apiregistration.k8s.io/v1     false
certificatesigningrequests  csr    certificates.k8s.io/v1       false
clusterissuers                      cert-manager.io/v1           false
ingressclasses                     networking.k8s.io/v1          false
priorityclasses         pc         scheduling.k8s.io/v1         false
runtimeclasses                     node.k8s.io/v1               false
volumeattachments                  storage.k8s.io/v1             false
```

**[Your note]** from `Security/role-rolebinding/commnds.sh` — you discovered this the hard way:

```bash
kubectl get clusterroles --all-namespaces | grep -i admin
# this did not work because cluster roles are global and not limited or do not have namespaces
kubectl get clusterroles --all-namespaces -o wide | grep -i admin
# this did not work because cluster roles are global and not limited or do not have namespaces
```

`--all-namespaces` is meaningless for cluster-scoped resources. `kubectl describe role cluster-admin` also fails — it is
a **Cluster**Role, so you need `kubectl describe clusterrole cluster-admin`.

> **Exam note** — a ClusterRole alone grants nothing. It must be bound by a **ClusterRoleBinding** (cluster-wide) or a
> **RoleBinding** (one namespace). Conversely a ClusterRoleBinding referencing a namespaced Role is invalid.

---

## 5.5 ServiceAccounts — Lab `27-role-rb.sh`

A ServiceAccount is the identity a **pod** uses. Every namespace gets a `default` one automatically.

```bash
kubectl get serviceaccounts --all-namespaces | wc
kubectl get serviceaccount default -o yaml
#  apiVersion: v1
#  kind: ServiceAccount
#  metadata:
#    name: default
#    namespace: default

kubectl describe serviceaccount default
#  Name:                default
#  Namespace:           default
#  Labels:              <none>
#  Annotations:         <none>
#  Image pull secrets:  <none>
#  Mountable secrets:   <none>
#  Tokens:              <none>
#  Events:              <none>
```

### Creating and wiring one

```bash
kubectl get deployments
kubectl get deployments -o wide
kubectl get pods
kubectl describe deployment web-dashboard
kubectl get pod web-dashboard-74cbcd9494-wjxcd -o yaml
kubectl describe pod web-dashboard-74cbcd9494-wjxcd
kubectl get serviceaccounts
kubectl create serviceaccount dashboard-sa
kubectl get serviceaccount dashboard-sa -o yaml
kubectl create token dashboard-sa
kubectl set serviceaccount deploy/web-dashboard dashboard-sa
```

```bash
# Attach it to a pod
kubectl patch deploy web-dashboard -p '{"spec":{"template":{"spec":{"serviceAccountName":"dashboard-sa"}}}}'
# or in YAML:
spec:
  serviceAccountName: dashboard-sa     # use this
  # serviceAccount: dashboard-sa       # deprecated alias, avoid
```

`kubectl create token dashboard-sa` produces a short-lived JWT you can use directly against the API:

```bash
TOKEN=$(kubectl create token dashboard-sa)
kubectl --token=$TOKEN get pods
curl -H "Authorization: Bearer $TOKEN" --cacert ca.crt https://<cp>:6443/api/v1/namespaces/default/pods
```

### The full RBAC trio — `Labs/27-role-rb.sh`

```yaml
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: default
subjects:
  - kind: ServiceAccount
    name: dashboard-sa          # Name is case sensitive
    namespace: default
roleRef:
  kind: Role                    # this must be Role or ClusterRole
  name: pod-reader              # this must match the name of the Role or ClusterRole you wish to bind to
    apiGroup: rbac.authorization.k8s.io
```

```yaml
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: pod-reader
rules:
  - apiGroups:
      - ''
    resources:
      - pods
    verbs:
      - get
      - watch
      - list
```

**[Your note]** — the three inline comments are worth repeating because they are the exact mistakes the exam sets:

> *Name is case sensitive*
> *this must be Role or ClusterRole*
> *this must match the name of the Role or ClusterRole you wish to bind to*

### A pod's identity in a `kubectl describe`

```
kubectl describe pod web-dashboard-74cbcd9494-wjxcd
#  Name:             web-dashboard-74cbcd9494-wjxcd
#  Namespace:        default
#  Service Account:  default
#  Node:             controlplane/192.13.128.9
#  ...
#  Mounts:
#    /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-glgk8 (ro)
```

`Service Account: default` means the pod has **no** permissions beyond the namespace default. Changing it to
`dashboard-sa` and binding the Role is the whole fix.

> **Exam note** — a pod talking to the API server with a `403 Forbidden` is almost always a ServiceAccount problem, not
> a network problem. Check: `kubectl get pod X -o jsonpath='{.spec.serviceAccountName}'`, then
> `kubectl auth can-i <verb> <resource> --as system:serviceaccount:<ns>:<sa>`, then look for the RoleBinding whose
> `subjects[].name` matches.

---

## 5.6 Image pull secrets — Lab `28-imagesecret-pull.sh`

```bash
kubectl create secret --help
kubectl get deployments -o wide
kubectl edit deployment web
kubectl get pods
kubectl get secrets
kubectl get secrets --all-namespaces
```

### The imperative way (always works)

```bash
kubectl create secret docker-registry private-reg-cred \
  --docker-username=dock_user \
  --docker-password=dock_password \
  --docker-server=myprivateregistry.com:5000 \
  --docker-email=dock_user@myprivateregistry.com
```

Or from a `docker/config.json`:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=quay.io \
  --docker-username=pandeysp \
  --docker-password='<token>' \
  --docker-email=you@example.com
```

```bash
# Attach it to a ServiceAccount (applies to every pod using that SA)
kubectl patch serviceaccount default -p '{"imagePullSecrets":[{"name":"private-reg-cred"}]}'

# Or attach it directly to a pod/deployment
kubectl edit deployment web      # add:
# spec:
#   template:
#     spec:
#       imagePullSecrets:
#         - name: private-reg-cred
```

### The declarative trap — your note is the most valuable thing in this repo

> *I tried to create a secret in a declarative way but eventually I failed because it seems if when you write it
> imperatively behind the scene it is encoded so somehow what I entered as plain text was not acceptable by kubernetes
> engine*
>
> ```bash
> kubectl get secret bootstrap-token-c0m8s1 -n kube-system -o yaml > temp.secret.yaml
> #  did not work!^^
> ```

What you tried, and it was rejected:

```yaml
#  WRONG — plain text values, wrong type, wrong keys
apiVersion: v1
data:
  Username: dock_user
  Password: dock_password
  Server: myprivateregistry.com:5000
  Email: dock_user@myprivateregistry.com
kind: Secret
metadata:
  name: private-reg-cred
type: docker-registry
```

What Kubernetes actually requires:

```yaml
#  CORRECT — base64-encoded .dockerconfigjson, right type
apiVersion: v1
data:
  .dockerconfigjson: eyJhdXRocyI6eyJteXByaXZhdGVyZWdpc3RyeS5jb206NTAwMCI6eyJ1c2VybmFtZSI6ImRvY2tfdXNlciIsInBhc3N3b3JkIjoiZG9ja19wYXNzd29yZCIsImVtYWlsIjoiZG9ja191c2VyQG15cHJpdmF0ZXJlZ2lzdHJ5LmNvbSIsImF1dGgiOiJaRzlqYTE5MWMyVnlPbVJ2WTJ0ZmNHRnpjM2R2Y21RPSJ9fX0=
kind: Secret
metadata:
  name: private-reg-cred
  namespace: default
type: kubernetes.io/dockerconfigjson
```

Three separate mistakes, and all three matter:

1. **`type`** — `docker-registry` is not a valid Secret type. It must be `kubernetes.io/dockerconfigjson`.
2. **The key** — it must be a single key named `.dockerconfigjson`, not `Username`/`Password`/`Server`/`Email`.
3. **The value** — it must be **base64 of a JSON document**, not base64 of the individual fields.

Build it yourself when you must:

```bash
# Step 1: the JSON
kubectl create secret docker-registry regcred \
  --docker-server=quay.io --docker-username=pandeysp \
  --docker-password='TOKEN' --docker-email=a@b.c \
  --dry-run=client -o yaml > regcred.yaml

# Step 2: decode it to see the structure
kubectl get secret regcred -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
# {"auths":{"quay.io":{"username":"pandeysp","password":"TOKEN","email":"a@b.c","auth":"cGFuZGV5c3A6VE9LRU4="}}}

# Step 3: verify
kubectl get secret regcred -o yaml
```

> **Exam note** — always use the imperative form with `--dry-run=client -o yaml`. It is faster and it is correct. If the
> exam gives you a `.dockerconfigjson` file, use `--from-file=.dockerconfigjson=./config.json`.

### Opaque secrets — Lab `17-secretlab.sh`

```bash
kubectl get secrets
kubectl get secret dashboard-token -o yaml

kubectl create secret generic db-secret
kubectl get secret db-secret -o yaml > temp.yaml
vi temp.yaml

# better way in one go
kubectl create secret generic db-secret \
  --from-literal=DB_Host=sql01 \
  --from-literal=DB_User=root \
  --from-literal=DB_Password=password123

kubectl edit pod webapp-pod
kubectl get pods
kubectl delete pod webapp-pod --force
kubectl apply -f /tmp/kubectl-edit-634543789.yaml
```

`Labs/configmap/secret-imperative.yaml` shows what the imperative command actually produces:

```yaml
apiVersion: v1
data:
  DB_Host: c3FsMDE=
  DB_Password: cGFzc3dvcmQxMjM=
  DB_User: cm9vdA==
kind: Secret
metadata:
  name: db-secret
  namespace: default
type: Opaque
```

And `Labs/configmap/secret.yaml` is the **plain-text** version that does **not** work:

```yaml
apiVersion: v1
data:
  DB_Host: sql01
  DB_User: root
  DB_Password: password123
kind: Secret
metadata:
  name: db-secret
  namespace: default
type: Opaque
```

> **Exam note** — Secret `data` values must always be base64. If you want to write plain text, use the `stringData`
> field, which the API server encodes for you on write:
> ```yaml
> stringData:
>   DB_Host: sql01
>   DB_User: root
>   DB_Password: password123
> ```
> This is the correct declarative workaround to the problem you documented.

### Consuming a secret — `Labs/configmap/pod-read-from-secret.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    name: webapp-pod
  name: webapp-pod
  namespace: default
spec:
  containers:
    - image: kodekloud/simple-webapp-mysql
      # Alt image: quay.io/pandeysp/mysql:latest
      imagePullPolicy: Always
      name: webapp
      envFrom:
        - secretRef:
            name: db-secret
```

Three ways to consume:

```yaml
# 1. One key as one env var
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: DB_Password

# 2. All keys as env vars
envFrom:
  - secretRef:
      name: db-secret

# 3. As files
volumeMounts:
  - name: secret-vol
    mountPath: /etc/secrets
    readOnly: true
volumes:
  - name: secret-vol
    secret:
      secretName: db-secret
```

---

## 5.7 SecurityContext — Lab `29-security-context.sh`

```bash
kubectl exec -it ubuntu-sleeper -- whoami
kubectl get securitycontext
kubectl describe pod ubuntu-sleeper | grep security
kubectl get pod ubuntu-sleeper -o yaml | grep security
kubectl get pod ubuntu-sleeper -o yaml > ubuntu-spec.yaml
cat ubuntu-spec.yaml
kubectl delete pod ubuntu-sleeper --force
vi ubuntu-spec.yaml
kubectl apply -f ubuntu-spec.yaml

kubectl run ubuntu-sleeper --image=ubuntu --dry-run=client -o yaml > fromscratch.yaml
vi fromscratch.yaml
kubectl apply -f fromscratch.yaml
```

### Pod-level securityContext — `Security/role-rolebinding/ubuntu-sleeper.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-sleeper
  namespace: default
spec:
  securityContext:
    runAsUser: 1010
  containers:
    - command:
        - sleep
        - "4800"
      image: ubuntu
      # Alt image: quay.io/pandeysp/ubuntu-git:latest
      name: ubuntu-sleeper
```

**[Your note]** — verbatim:

> To delete the existing ubuntu-sleeper pod:
> `kubectl delete po ubuntu-sleeper`
> After that apply solution manifest file to run as user 1010 as follows:
> ...
> **NOTE:** TO delete the pod faster, you can run `kubectl delete pod ubuntu-sleeper --force`. This can be done for any
> pod in the lab or the actual exam. It is not recommended to run this in Production, so keep a note of that.

### Container-level securityContext — `Security/role-rolebinding/sys-time.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-sleeper
  namespace: default
spec:
  containers:
    - command:
        - sleep
        - "4800"
      image: ubuntu
      name: ubuntu-sleeper
      securityContext:
        capabilities:
          add: ["SYS_TIME", "NET_ADMIN"]
```

### The full reference

| Field | Level | Meaning |
|---|---|---|
| `runAsUser` | Pod **or** container | UID the process runs as |
| `runAsGroup` | Pod **or** container | Primary GID |
| `runAsNonRoot` | Pod **or** container | **`true`** = refuse to start if the image would run as root |
| `fsGroup` | Pod | GID that owns mounted volumes; also set as the supplementary group |
| `fsGroupChangePolicy` | Pod | `Always` (default) or `OnRootMismatch` |
| `supplementalGroups` | Pod | Extra GIDs |
| `seccompProfile.type` | Pod **or** container | `RuntimeDefault`, `Unconfined`, `Localhost` |
| `seLinuxOptions` | Pod **or** container | SELinux user/role/type/level |
| `appArmorProfile.type` | container | `RuntimeDefault`, `Unconfined`, `Localhost` |
| `capabilities.add` | **Container only** | Add Linux capabilities |
| `capabilities.drop` | **Container only** | Drop capabilities (default `NET_RAW` on hardened clusters) |
| `privileged` | **Container only** | `true` = effectively root on the host |
| `readOnlyRootFilesystem` | **Container only** | Make `/` immutable |
| `allowPrivilegeEscalation` | **Container only** | `false` blocks `setuid` binaries |
| `procMount` | **Container only** | `Default` or `Unmasked` |

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:                    # POD level
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    fsGroupChangePolicy: OnRootMismatch
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: nginx
      securityContext:                # CONTAINER level
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        privileged: false
        runAsNonRoot: true
        capabilities:
          drop: ["ALL"]
          add: ["NET_BIND_SERVICE"]
```

**Alternative images** that pair naturally with the unprivileged-nginx labs:

```yaml
# Alt image: quay.io/pandeysp/nginx-unprivileged:latest
# Alt image: quay.io/pandeysp/openshift-nginx:latest
```

Both are built to run as a non-root UID (8080 or similar), which makes them the correct choice when a question says
"the pod must run as a non-root user and listen on 8080" — plain `nginx` would fail.

```bash
# Verify
kubectl exec -it ubuntu-sleeper -- whoami     # prints the UID if no passwd entry
kubectl exec -it ubuntu-sleeper -- id
kubectl get pod ubuntu-sleeper -o jsonpath='{.spec.securityContext}'
```

> **Exam note** — `runAsNonRoot: true` + an image whose `USER` is root (or unset, defaulting to 0) produces
> `CreateContainerConfigError: container has runAsNonRoot and image has non-numeric user (root), cannot verify user is
> non-root`. That is the signal to switch to an unprivileged image.

---

## 5.8 TLS certificates — Labs `22-certicates-dig.sh` and `23-certificate-signing-request.sh`

### The PKI tree (recap, with the paths you'll need)

```
/etc/kubernetes/pki/
├── ca.crt / ca.key                              cluster CA
├── apiserver.crt / apiserver.key                API server serving cert
├── apiserver-etcd-client.crt / .key             API server → etcd
├── apiserver-kubelet-client.crt / .key          API server → kubelet
├── front-proxy-ca.crt / .key                    front-proxy CA
├── front-proxy-client.crt / .key                aggregation layer
├── sa.key / sa.pub                              ServiceAccount token signing
└── etcd/{ca,server,peer,healthcheck-client}.{crt,key}
```

```bash
openssl x509 -in /etc/kubernetes/pki/etcd/ca.crt -text -noout
openssl x509 -in apiserver.crt -noout -subject -issuer -dates -ext subjectAltName
openssl verify -CAfile ca.crt apiserver.crt
```

### Generating a certificate by hand

```bash
# 1. Private key
openssl genrsa -out akshay.key 2048

# 2. CSR
openssl req -new -key akshay.key -subj "/CN=akshay/O=developers" -out akshay.csr

# 3. Inspect it
openssl req -in akshay.csr -noout -text
```

The `O=` field is what becomes the RBAC group. `CN=` is the username.

### The Kubernetes CSR object — `Labs/23-certificate-signing-request.sh`

```bash
kubectl get csr --all-namespaces
kubectl get csr csr-dp45d -o yaml > temp-csr.yaml

# the certificate must be base64 one liner
cat akshay.csr | base64 -w 0
```

**[Your note]** — verbatim, and it is the gotcha that fails everyone:

> *the certificate must be base64 one liner*

`base64 -w 0` is essential. Without it you get a multi-line base64 blob which YAML will fold, and the API server rejects
it or signs the wrong bytes.

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: akshay
spec:
  groups:
    - system:nodes
    - system:authenticated
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0K...   # base64 -w 0 of the .csr
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
```

```bash
vi temp-csr.yaml
kubectl apply -f temp-csr.yaml
kubectl get csr

# approve/deny
kubectl certificate approve akshay
kubectl certificate deny agent-smith

kubectl get csr agent-smith -o yaml
kubectl delete csr agent-mith
```

**Signer names** (this changed in 1.19+ — the old `kubernetes.io/legacy-unknown` is gone):

| `signerName` | Signed by | Typical use |
|---|---|---|
| `kubernetes.io/kube-apiserver-client` | `ca.crt` / `ca.key` | **User** client certs |
| `kubernetes.io/kube-apiserver-client-kubelet` | `ca.crt` / `ca.key` | Kubelet client certs |
| `kubernetes.io/kubelet-serving` | `ca.crt` / `ca.key` | Kubelet **serving** certs |
| `kubernetes.io/legacy-unknown` | `ca.crt` / `ca.key` | Deprecated |

**Valid `usages`:** `client auth`, `server auth`, `digital signature`, `key encipherment`, `content commitment`,
`cert sign`, `crl sign`, `signing`, `key agreement`, `data encipherment`, `any`, `ocsp signing`.

> **Exam note** — the whole flow is: generate key → generate CSR → base64 it → create the CSR object → **approve it** →
> `kubectl get csr akshay -o jsonpath='{.status.certificate}' | base64 -d > akshay.crt` → put the cert and key into a
> kubeconfig. Forgetting `kubectl certificate approve` is the classic failure.

### Signing it yourself (no CSR object)

```bash
openssl x509 -req -in akshay.csr -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial \
  -out akshay.crt -days 365
```

---

## 5.9 kubeconfig — Lab `24-kube-config.sh`

```bash
cat .kube/config
cat my-kube-config | grep -i current

# config use-context
kubectl config --kubeconfig=/root/my-kube-config use-context research
# config current-context
kubectl config --kubeconfig=/root/my-kube-config current-context

cp my-kube-config ~/.kube/config
kubectl get pods
ls /etc/kubernetes/pki/users/
```

### The structure — `Security/config-2.yaml`

```yaml
apiVersion: v1
clusters:
  - cluster:
      certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...   # base64 of ca.crt
      server: https://k8scp:6443
    name: kubernetes
contexts:
  - context:
      cluster: kubernetes
      user: kubernetes-admin
    name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
  - name: kubernetes-admin
    user:
      client-certificate-data: #######
      client-key-data: #######
  - name: polaris
    user:
      client-certificate: /home/ubuntu/polaris.crt
      client-key: /home/ubuntu/polaris.key
```

**Alternative images** (a container that gives you a shell and openssl to build certs):
`# Alt image: quay.io/pandeysp/ubuntu-git:latest`, `# Alt image: quay.io/pandeysp/centos:latest`,
`# Alt image: quay.io/pandeysp/alpine:latest`

### The kubelet's kubeconfig — `Security/kubelet.yaml`

```yaml
apiVersion: v1
clusters:
  - cluster:
      certificate-authority-data: #####
      server: https://k8scp:6443
    name: kubernetes
contexts:
  - context:
      cluster: kubernetes
      user: system:node:ip-172-31-40-74
    name: system:node:ip-172-31-40-74@kubernetes
current-context: system:node:ip-172-31-40-74@kubernetes
kind: Config
users:
  - name: system:node:ip-172-31-40-74
    user:
      client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
      client-key: /var/lib/kubelet/pki/kubelet-client-current.pem
```

Note the naming convention: `system:node:<node-name>` must match the node's name exactly, because the **Node**
authoriser grants a kubelet permission based on that prefix.

### Managing kubeconfigs without a text editor

```bash
# Build one from scratch
kubectl config set-cluster kubernetes \
  --server=https://k8scp:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --kubeconfig=/root/my-kube-config

kubectl config set-credentials polaris \
  --client-certificate=/home/ubuntu/polaris.crt \
  --client-key=/home/ubuntu/polaris.key \
  --embed-certs=true \
  --kubeconfig=/root/my-kube-config

kubectl config set-context polaris-context \
  --cluster=kubernetes --user=polaris \
  --kubeconfig=/root/my-kube-config

kubectl config use-context polaris-context --kubeconfig=/root/my-kube-config

# Inspect
kubectl config view --kubeconfig=/root/my-kube-config
kubectl config view --minify --kubeconfig=/root/my-kube-config
kubectl config current-context --kubeconfig=/root/my-kube-config
kubectl config get-contexts
kubectl config get-users
kubectl config get-clusters
```

> **Exam note** — `--kubeconfig` must come **after** the subcommand but the flag applies to the whole command; the common
> mistake is putting it at the end of a `set-cluster` invocation, which still works, versus forgetting it entirely and
> silently modifying `~/.kube/config` instead of the file the question asked about.

### The ServiceAccount token path

```bash
ls /etc/kubernetes/pki/users/          # from your lab
kubectl -n kube-system get secret <sa-token-secret> -o jsonpath='{.data.token}' | base64 -d
kubectl create token dashboard-sa      # 1.24+, preferred
```

---

## 5.10 Part V self-check

1. A RoleBinding has `roleRef.kind: Role` and you need it to reference a ClusterRole. Can you edit it in place?
2. `kubectl auth can-i list pods --as dev-user` returns `no`. Name the four things you check.
3. A declarative `docker-registry` Secret with plain-text `Username:` keys is rejected. What are the three things wrong?
4. `kubectl create rolebinding X --role=edit --user=bob -n dev` — what is `roleRef.kind`?
5. Write the exact commands to create a CSR object for a user cert and get it signed.
6. What is `stringData` and when do you use it instead of `data`?
7. `runAsNonRoot: true` with `image: nginx` fails. Which of your images fixes it?
8. Where does a pod's RBAC identity come from — the pod name, the ServiceAccount, or the node?
9. `kubectl get clusterroles --all-namespaces` returns nothing useful. Why?
10. What are the three fields of a kubeconfig's `contexts[]` entry?


\pagebreak

## Part VI — Troubleshooting

**CKA weight: ~10%**

The CKA troubleshooting section is deliberately open-ended: "an application is failing, fix it." Your repo has good raw
material — API access debugging, a proxy walkthrough, a metrics-server investigation, and node lifecycle.

**Competencies covered in this part**

1. Troubleshoot cluster component failure
2. Troubleshoot application failure
3. Troubleshoot networking issues
4. Troubleshoot storage issues
5. Evaluate cluster and node logging
6. Understand how to monitor applications
7. Manage container stdout and stderr logs
8. Troubleshoot control plane failure and worker node failure

---

## 6.1 The triage sequence — use this every time

```bash
# 1. What is wrong, in one glance?
kubectl get pods -o wide --all-namespaces | grep -v Running
kubectl get nodes
kubectl get events --sort-by=.lastTimestamp | tail -40

# 2. Is it the app or the cluster?
kubectl get pods -o wide                  # Pending/CrashLoop = scheduling or app
kubectl top nodes                         # needs metrics-server

# 3. Zoom in on the failing object
kubectl describe pod <name>
kubectl logs <name> [-c <container>] [--previous] [--tail=50]
kubectl get pod <name> -o yaml

# 4. Is the control plane healthy?
kubectl -n kube-system get pods
sudo crictl ps -a | grep -E 'etcd|kube-apiserver|kube-scheduler|kube-controller'
sudo journalctl -u kubelet -n 50 --no-pager

# 5. Is the node healthy?
systemctl status kubelet --no-pager
systemctl status containerd --no-pager
```

### The pod status → cause table

| Status | Almost always means | First command |
|---|---|---|
| `Pending` | Unschedulable: taint, affinity, insufficient resources, no PV | `kubectl describe pod` → Events |
| `ContainerCreating` | Volume/secret/configmap not ready, or image pull in progress | `kubectl describe pod` |
| `ImagePullBackOff` / `ErrImagePull` | Wrong image name/tag, or no pull secret | `kubectl describe pod`, `kubectl get events` |
| `CrashLoopBackOff` | The process exits non-zero | `kubectl logs <pod> --previous` |
| `Init:0/N` / `Init:Error` | An init container is still running or failing | `kubectl logs <pod> -c <init-container>` |
| `CreateContainerConfigError` | A referenced Secret/ConfigMap doesn't exist | `kubectl describe pod` |
| `OOMKilled` | The container exceeded its memory limit | `kubectl describe pod`, `kubectl top pod` |
| `Terminating` (stuck) | A finalizer or a mounted volume is blocking it | `kubectl describe pod`, `kubectl get pvc` |
| `Error` | The container ran and exited non-zero, `restartPolicy` not Always | `kubectl logs <pod>` |
| `Evicted` | Node resource pressure | `kubectl describe node` |
| `Completed` | A Job or a one-shot pod that succeeded | Nothing — this is healthy |

---

## 6.2 Application failure — the log drill

```bash
# Current logs
kubectl logs <pod>
kubectl logs <pod> -c <container>              # multi-container pods REQUIRE -c
kubectl logs <pod> --tail=100
kubectl logs <pod> --since=10m
kubectl logs <pod> -f                          # follow

# Logs of the container that CRASHED (the single most useful flag)
kubectl logs <pod> --previous
kubectl logs <pod> -c app --previous

# All containers at once
kubectl logs <pod> --all-containers=true

# A previous ReplicaSet's pod, after a bad rollout
kubectl logs deploy/<name> --all-containers=true
kubectl rollout history deploy/<name>
kubectl rollout undo deploy/<name>

# Logs straight from the container runtime, bypassing the API server
sudo crictl ps -a
sudo crictl logs <container-id>
sudo crictl inspect <container-id> | head -40
```

### Multi-container pods — the `Defaulted container` message

From `Labs/init-cotainer.sh`:

```bash
kubectl logs orange
# Defaulted container "orange-container" out of: orange-container, init-myservice (init)
# Error from server (BadRequest): container "orange-container" in pod "orange" is waiting to start: PodInitializing
```

Two lessons in one output:

1. kubectl **tells you** which containers exist and which one it defaulted to — read that line.
2. `PodInitializing` means the **init** containers haven't finished, so the app container has no logs at all. To see the
   real error you must target the init container:
   ```bash
   kubectl logs orange -c init-myservice
   ```

### Events are the ground truth

```bash
kubectl get events --sort-by=.lastTimestamp
kubectl get events --sort-by=.lastTimestamp | tail -30
kubectl get events --field-selector involvedObject.name=<pod> --sort-by=.lastTimestamp
kubectl get events --field-selector type=Warning
```

From your capture:

```
LAST SEEN           TYPE      REASON                           OBJECT              MESSAGE
39s (x4 over 87s)   Normal    Created                          Pod/orange          Created container init-myservice
39s (x4 over 86s)   Normal    Started                          Pod/orange          Started container init-myservice
0s (x7 over 82s)    Warning   BackOff                          Pod/orange          Back-off restarting failed container init-myservice in pod orange_default(8beb5c9b-...)
```

`Back-off restarting failed container` + `x7 over 82s` = the container is failing repeatedly. That is a `CrashLoopBackOff`
in its init phase, and the fix is whatever makes `init-myservice` exit 0.

> **Note** — `kubectl events` (as used in `Labs/01-pods.sh` and `Labs/03.deployments.sh`) is **not** a kubectl
> subcommand. Use `kubectl get events ...` or `kubectl describe ...` and read the `Events:` section at the bottom.

---

## 6.3 Control plane failure — the static-pod toolkit

The control plane runs as static pods, so you have two layers of visibility.

```bash
# Layer 1: the API server's view
kubectl -n kube-system get pods -o wide
kubectl -n kube-system describe pod kube-apiserver-controlplane
kubectl -n kube-system logs kube-apiserver-controlplane

# Layer 2: the node's view (works even when the API server is down)
sudo crictl ps -a
sudo crictl logs <container-id>
sudo crictl inspect <container-id>

# Layer 3: systemd / the kubelet
systemctl status kubelet --no-pager
sudo journalctl -u kubelet --since "10 minutes ago" --no-pager
```

### Which component is broken?

| Symptom | Broken component |
|---|---|
| `kubectl` hangs or `connection refused` on 6443 | `kube-apiserver` |
| `kubectl get pods` works, but new pods stay `Pending` | `kube-scheduler` |
| Deleted pods are never recreated; ReplicaSets don't converge | `kube-controller-manager` |
| `kubectl get nodes` shows the node `NotReady` | `kubelet` (or the CNI on that node) |
| `ClusterIP` unreachable, DNS resolves fine | `kube-proxy` (or iptables) |
| Pod-to-pod across nodes fails | CNI plugin / routing / `ip_forward` |
| `kubectl get` returns stale data, writes fail | `etcd` |

### The `crictl` commands to memorise

```bash
sudo crictl ps                       # running containers
sudo crictl ps -a                    # including exited — find the crashed one
sudo crictl logs <id>
sudo crictl logs <id> --tail 100
sudo crictl inspect <id>
sudo crictl images
sudo crictl pull <image>
sudo crictl rmi <image>
sudo crictl rmp <pod-id>             # remove a stuck pod
sudo crictl pods                     # sandbox (pod) list
```

`crictl` needs to point at the same runtime endpoint kubelet uses:

```bash
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```

Or just `sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps`.

### Reading kubelet logs

From `Networking/kubeadmin/kubelet.process.log` and `kublet.status.log` in your repo — the shape of a kubelet process
listing:

```bash
ps -ef | grep /usr/bin/kubelet
# root 12178 1 0 18:56 ?  /usr/bin/kubelet \
#   --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
#   --kubeconfig=/etc/kubernetes/kubelet.conf \
#   --config=/var/lib/kubelet/config.yaml \
#   --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \
#   --pod-infra-container-image=registry.k8s.io/pause:3.9

systemctl status kubelet
#  ● kubelet.service - kubelet: The Kubernetes Node Agent
#     Loaded: loaded (/lib/systemd/system/kubelet.service; enabled; preset: enabled)
#     Active: active (running) since ...
#   Main PID: 12178 (kubelet)

journalctl -u kubelet -n 100 --no-pager
```

### kubelet service file — `Networking/kubeadmin/kubelet.service`

The relevant bits of a kubeadm kubelet unit:

```ini
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/default/kubelet
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
Restart=always
RestartSec=10
```

`Restart=always` means the kubelet is self-healing — if it is down, `systemctl` will show repeated restarts. Check
`/var/lib/kubelet/kubeadm-flags.env` for the effective flags:

```bash
cat /var/lib/kubelet/kubeadm-flags.env
# KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.10"
```

> **Exam note** — if you must change a kubelet flag, edit
> `Environment="KUBELET_EXTRA_ARGS="` in the unit **or** `/var/lib/kubelet/kubeadm-flags.env`, then
> `systemctl daemon-reload && systemctl restart kubelet`. Editing only `/var/lib/kubelet/config.yaml` works for
> `KubeletConfiguration` fields but not for flags that only exist on the command line.

---

## 6.4 Node failure and eviction

```bash
kubectl get nodes
kubectl describe node node01
```

```
Conditions:
  Type                 Status   LastHeartbeatTime                 LastTransitionTime                Reason                       Message
  ----                 ------   -----------------                 -----------------                 ------                       -------
  NetworkUnavailable   False    Mon, 08 Apr 2024 16:42:34 +0000    Mon, 08 Apr 2024 16:42:34 +0000    FlannelIsUp                 Flannel is running on this node
  MemoryPressure       False    Mon, 08 Apr 2024 16:53:12 +0000    Mon, 08 Apr 2024 16:42:28 +0000    KubeletHasSufficientMemory   kubelet has sufficient memory available
  DiskPressure         False    Mon, 08 Apr 2024 16:53:12 +0000    Mon, 08 Apr 2024 16:42:28 +0000    KubeletHasNoDiskPressure     kubelet has no disk pressure
  PIDPressure          False    Mon, 08 Apr 2024 16:53:12 +0000    Mon, 08 Apr 2024 16:42:28 +0000    KubeletHasSufficientPID      kubelet has sufficient PID available
  Ready                True     ...
```

| Condition | If `True` (i.e. bad) | Meaning | Fix |
|---|---|---|---|
| `Ready` | `False` | kubelet is not reporting | Check kubelet, containerd, CNI |
| `MemoryPressure` | `True` | Node is out of memory | Evict pods / raise limits |
| `DiskPressure` | `True` | Node disk is nearly full | Clean images, raise `imagefs` |
| `PIDPressure` | `True` | Too many processes | Raise `--pod-max-pids` or kill processes |
| `NetworkUnavailable` | `True` | CNI never configured the pod network | Fix the CNI DaemonSet |

The default `NoExecute` taints and the 300s tolerance you saw in every captured pod:

```yaml
tolerations:
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300      # pods survive 5 minutes of node unreadiness
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
```

```bash
# A node is wedged
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data --force
# fix the node
kubectl uncordon node01

# A node is gone for good
kubectl delete node node01
# then on the node itself:
sudo kubeadm reset
```

### Eviction and QoS ordering

When the node hits pressure, kubelet evicts in this order:

1. **BestEffort** pods that exceed their requests
2. **Burstable** pods that exceed their requests
3. **Guaranteed** pods (only if still under pressure)

---

## 6.5 Networking troubleshooting — a decision tree

```
Pod A cannot reach Pod B
├── Is Pod B Running? ─────────────────── no ──▶ fix Pod B first
├── Same node?
│   ├── yes ──▶ kubectl exec A -- ip a           # is A's IP in the pod CIDR?
│   │           kubectl exec A -- ping <B-ip>    # veth / bridge / iptables
│   └── no ───▶ ip route (on each node)          # does each node route the other's pod CIDR?
│               ip link show                     # flannel.1 up? MTU match?
├── By name?
│   └── kubectl exec A -- nslookup b-svc         # CoreDNS
│       kubectl -n kube-system get pods -l k8s-app=kube-dns
├── By Service?
│   └── kubectl get endpoints b-svc              # empty = selector mismatch
└── Blocked by policy?
    └── kubectl get networkpolicy -A
        # a policy selecting B flips it to deny-by-default
```

### DNS troubleshooting

```bash
kubectl get pods -n kube-system | grep dns
kubectl -n kube-system logs -l k8s-app=kube-dns

# Test from inside a pod
kubectl exec -it <pod> -- nslookup kubernetes.default
kubectl exec -it <pod> -- cat /etc/resolv.conf
# nameserver 10.96.0.10
# search default.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5

# Does the pod's resolv.conf point at the right CoreDNS ClusterIP?
kubectl -n kube-system get svc kube-dns
```

`ndots:5` means any name with fewer than 5 dots gets the search domains appended first. That is why
`kubernetes` is tried as `kubernetes.default.svc.cluster.local` and works, and why an external name like
`example.com` (1 dot) is tried as `example.com.default.svc.cluster.local` first — a source of slow lookups and
occasional NXDOMAIN surprises.

From `Networking/ubuntu-host-with-docker.sh`:

> **Some info about `/etc/hosts`**
> 1. it dominates the `/etc/resolv.conf`
> 2. `nslookup` and `dig` do not query it

### Service troubleshooting

```bash
kubectl get svc
kubectl describe svc <name>
kubectl get endpoints <name>
kubectl get endpointslices -l kubernetes.io/service-name=<name>

# Are the pods the Service should select actually labelled right?
kubectl get pods --show-labels -l app=<selector>

# Does kube-proxy have the rules?
sudo iptables -t nat -L KUBE-SERVICES -n | grep <clusterIP>
sudo iptables-save | grep <clusterIP>
```

### Ingress troubleshooting

```bash
kubectl get ingress --all-namespaces
kubectl describe ingress <name>
kubectl get pods -n ingress-nginx
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=100
kubectl -n ingress-nginx get svc ingress-nginx-controller

# Test the controller directly
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80
curl -H "Host: www.students.com" http://localhost:8080/courses

# Is the Ingress class right?
kubectl get ingressclass
kubectl get ingress <name> -o jsonpath='{.spec.ingressClassName}'
```

**The three Ingress failure modes:**

1. **No controller installed** — the Ingress object exists but `ADDRESS` is empty and nothing listens.
2. **Wrong/missing `ingressClassName`** — the controller ignores it, no `Sync` event appears.
3. **Backend Service has no endpoints** — the controller returns `503 Service Temporarily Unavailable`.

---

## 6.6 Metrics and monitoring — Lab `15-metric-server.sh` revisited

```bash
kubectl top nodes
kubectl top pod
kubectl top pod -n kube-system
kubectl top pod --containers
kubectl top pod --sort-by=cpu
kubectl top pod --no-headers | sort -k2 -h -r | head
```

Your repo has `Labs/metric-server.log` — a captured metrics-server log. Common lines and their meaning:

```
E0408 ... unable to fetch metrics ... x509: certificate signed by unknown authority
    → missing --kubelet-insecure-tls
E0408 ... unable to fully collect metrics: [unable to fully scrape metrics from source kubelet_summary:node01: ...
    → kubelet's 10250 not reachable from the aggregator; hostNetwork / preferred address types
I0408 ... Generating self-signed cert (...)
    → normal startup
```

```bash
# Fix the most common failure
kubectl -n kube-system edit deploy metrics-server
# args: add --kubelet-insecure-tls
kubectl -n kube-system rollout status deploy metrics-server
```

**Your own monitoring images:**

```bash
# Alt image: quay.io/pandeysp/prometheus:latest
# Alt image: quay.io/pandeysp/prom_metrics_expoter:latest
# Alt image: quay.io/pandeysp/zabbix-proxy-sqlite3:alpine-6.4.13
# Alt image: quay.io/pandeysp/zabbix-agent2:alpine-6.4.13
```

A DaemonSet of `zabbix-agent2` is the textbook "monitor every node" workload, and a Deployment of
`prom_metrics_expoter` is the textbook "instrument an app" workload. Both fit Part II and Part VI.

---

## 6.7 API access troubleshooting — `ApiAccess/` and `Proxy/`

```bash
# Is the API server reachable at all?
kubectl cluster-info
kubectl cluster-info dump | head -50
curl -k https://<cp>:6443/healthz
curl -k https://<cp>:6443/livez
curl -k https://<cp>:6443/readyz?verbose

# Is my credential valid?
kubectl config view --minify
kubectl auth whoami
kubectl get --raw /api

# Is the aggregator layer OK?
kubectl get apiservices
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

# Raw API, with the extracted certs
curl --cert ./client.pem --key ./client-key.pem --cacert ./ca.pem https://k8scp:6443/api/v1/pods

# Through the proxy
kubectl proxy --port=8001 &
curl http://127.0.0.1:8001/api/
curl http://127.0.0.1:8001/api/v1/namespaces/default/pods
curl http://127.0.0.1:8001/apis/apps/v1/namespaces/default/deployments
```

From `Proxy/proxy-window2.sh`:

```
curl http://127.0.0.1:8001/api/
{
  "kind": "APIVersions",
  "versions": ["v1"],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "172.31.40.74:6443"
    }
  ]
}
```

`kubectl proxy` is the safest way to reach the API from inside a pod because it handles auth for you. Your other note in
the same file:

```bash
curl http://127.0.0.1:8001/api/v1/namespacess        # note the typo — "namespacess"
```

which returned a **200 with a NamespaceList** instead of a 404, because `/api/v1/namespaces` (correctly spelled) matched
and the trailing `s` was ignored by the router. A useful reminder: **a 200 from the API does not prove you hit the
endpoint you meant.**

### What `kubectl` actually does — `ApiAccess/commands.sh`

```bash
sudo apt-get install -y strace
kubectl get endpoints
strace kubectl get endpoints
strace kubectl get pods
```

Strace shows kubectl reading `~/.kube/config`, opening the TLS socket to `6443`, and writing the request. It is the
definitive answer to "is this a kubectl problem or a cluster problem" — if strace shows the request leaving, the problem
is server-side.

Your captured `ApiAccess/serverresources.json` is a `/apis` dump; `ApiAccess/pods.json` / `pods.yaml` / `console.log`
are full API responses. Keep them handy for remembering field names when the cluster is unreachable.

---

## 6.8 The rescue commands

```bash
# Pod won't delete
kubectl delete pod <name> --force --grace-period=0

# Pod stuck Terminating with a finalizer
kubectl patch pod <name> -p '{"metadata":{"finalizers":null}}'
kubectl delete pod <name> --force --grace-period=0

# PVC stuck Terminating (a pod still has it mounted)
kubectl delete pod <pod-using-it>
kubectl patch pvc <name> -p '{"metadata":{"finalizers":null}}'

# PV stuck Released after a Retain PVC was deleted
kubectl patch pv <name> -p '{"spec":{"claimRef":null}}'

# Deployment won't converge
kubectl rollout restart deploy/<name>
kubectl rollout undo deploy/<name>
kubectl rollout status deploy/<name>

# Node wedged
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force
kubectl uncordon <node>

# Clear the kubelet's pod cache after manual surgery
sudo rm -rf /var/lib/kubelet/pods/<pod-uid>

# Namespace stuck Terminating
kubectl get namespace <ns> -o json > ns.json
# remove spec.finalizers, then:
kubectl replace --raw "/api/v1/namespaces/<ns>/finalize" -f ns.json
```

---

## 6.9 A worked example, end to end

**Symptom:** `kubectl get pods` shows `orange  0/1  Init:Error  1 (13s ago)  15s`.

```bash
# 1. What does the API server know?
kubectl describe pod orange
# → Init container init-myservice is failing, BackOff, 7 restarts

# 2. What did it say before it died?
kubectl logs orange
# → Defaulted container "orange-container" out of: orange-container, init-myservice (init)
# → Error from server (BadRequest): container "orange-container" ... is waiting to start: PodInitializing
# (the app container has no logs — target the init container)

kubectl logs orange -c init-myservice --previous
# → sh: can't open 'wait-for-db.sh': No such file or directory

# 3. So the init container's script is missing. Can I edit the pod in place?
kubectl edit pod orange
# → error: pods "orange" is invalid
# → A copy of your changes has been stored to "/tmp/kubectl-edit-3406230358.yaml"
# → error: Edit cancelled, no valid changes were saved.

# 4. The documented workaround
kubectl delete pod orange
kubectl apply -f /tmp/kubectl-edit-3406230358.yaml
# pod/orange created

kubectl get pods
# orange   1/1   Running   0   8s
```

That sequence — **describe → logs (right container, `--previous`) → edit fails → delete → apply the saved file** — is the
exact workflow your repo documents four separate times. It is the highest-value thing to memorise in this whole document.

---

## 6.10 Part VI self-check

1. `kubectl logs pod` says `Defaulted container "app" out of: app, init-db (init)` and then `PodInitializing`. Which
   container do you log, and with which extra flag?
2. A pod is `OOMKilled`. Which field do you raise, and where does the QoS class come from?
3. `kubectl delete pod x` hangs. Give the two commands that force it.
4. `kubectl get nodes` shows a node `NotReady`. List the four conditions you check in `kubectl describe node`.
5. The API server is unreachable. Which command still works, and where do you run it?
6. A Service has an empty Endpoints list. What is the single most likely cause?
7. `kubectl top nodes` fails. Name two causes.
8. You changed a kubelet flag. What are the two files you might edit, and the command after editing?
9. A PV is `Released` with `Retain`. How do you make it `Available`?
10. An Ingress has an `ADDRESS` but returns 503. What do you check?


\pagebreak

## Appendix A — `quay.io/pandeysp/*` Image Catalog

All 33 repositories and 41 tags from your registry, mapped to where they are used in this document.

**Registry:** `quay.io`  ·  **Namespace:** `pandeysp`

```bash
# Log in once per environment
podman login quay.io -u pandeysp
# or
docker login quay.io -u pandeysp

# Pull
podman pull quay.io/pandeysp/nginx:latest

# Inspect what an image will run as (useful for runAsNonRoot questions)
podman inspect quay.io/pandeysp/nginx-unprivileged:latest \
  --format 'User={{.Config.User}} Exposed={{.Config.ExposedPorts}} Entrypoint={{.Config.Entrypoint}}'

# Skopeo without pulling
skopeo inspect docker://quay.io/pandeysp/mysql:latest
```

---

## A.1 Web servers and frontends

| Image | Tags | Use it for | Referenced in |
|---|---|---|---|
| `nginx` | `latest` | The default pod/deployment/service in every lab | Parts II, III, IV |
| `nginx-unprivileged` | `latest` | Any "must run as non-root user" question; listens on 8080 | Part V §5.7 |
| `openshift-nginx` | `latest` | OpenShift-flavoured nginx; non-root by default | Part V §5.7 |
| `nginx-ambassador` | `latest` | The **ambassador** multi-container pattern — one nginx fronting several backends | Part II §2.4, Part III §3.5 |
| `nginxdemo` | `latest` | A generic nginx demo app for Service/Ingress labs | Part III |
| `mywebapp` | `latest` | Stand-in for `kodekloud/webapp-color`; a colour-changing web app | Part II §2.6, Part III §3.4 |
| `hotel` | `latest` | A multi-service app — good for sidecar / multi-container labs | Part II §2.4, Part IV §4.8 |
| `portfolio` | `latest` | A static site — ideal for host-based Ingress routing | Part III §3.5 |
| `production` | `v1` `v2` `v3` `v4` `v5` | **Rolling updates and rollbacks** — five real versions to roll through | Part II §2.3 |
| `api-server` | `v1.0` | A versioned backend for Services/Ingress labs | Part III |
| `swarm-frontend` | `v1.0` | A Docker-Swarm-style frontend; useful when contrasting Swarm and Kubernetes | Part II |
| `node-service` | `v1` | A Node.js service for the two-tier Services lab | Part III §3.6 |
| `langflow` | `ipv6-dev` `ipv6-v1` | **IPv6 / dual-stack** networking experiments | Part III §3.8 |

```bash
# The production:v1..v5 rollout drill
kubectl create deployment prod --image=quay.io/pandeysp/production:v1 --replicas=4
kubectl set image deploy/prod prod=quay.io/pandeysp/production:v2
kubectl rollout status deploy/prod
kubectl rollout history deploy/prod
kubectl set image deploy/prod prod=quay.io/pandeysp/production:v3
kubectl rollout undo deploy/prod --to-revision=1
```

```bash
# The tea/coffee two-tier service drill
kubectl create deployment tea    --image=quay.io/pandeysp/tea:latest
kubectl create deployment coffee --image=quay.io/pandeysp/coffee:latest
kubectl expose deployment tea    --port=8080
kubectl expose deployment coffee --port=8080
kubectl exec deploy/tea -- curl -s http://coffee:8080
kubectl exec deploy/tea -- nslookup coffee
```

---

## A.2 Base images and utilities

| Image | Tags | Use it for | Referenced in |
|---|---|---|---|
| `busybox` | `latest` `v1` | Init containers, `sleep`, `wget`, `nslookup`, one-shot jobs | Parts II, III, VI |
| `alpine` | `latest` | Minimal pod for command/args and probe labs | Part II §2.6 |
| `ubuntu-git` | `latest` | Anything needing `openssl`, `git`, `curl`, `strace` — certificate labs | Part V §5.9 |
| `centos` | `latest` | `yum`-based variant for cert and kubeconfig labs | Part V §5.9 |

```bash
# Init container that waits for a dependency, using busybox
kubectl run app --image=quay.io/pandeysp/mywebapp:latest --dry-run=client -o yaml > app.yaml
# then add:
#   initContainers:
#     - name: wait
#       image: quay.io/pandeysp/busybox:latest
#       command: ['sh','-c','until nslookup db; do echo waiting; sleep 2; done']

# Certificate generation pod
kubectl run certkit --image=quay.io/pandeysp/ubuntu-git:latest --restart=Never -it -- bash
```

---

## A.3 Databases

| Image | Tags | Use it for | Referenced in |
|---|---|---|---|
| `mysql` | `latest` | Secret consumption (`envFrom.secretRef`), a StatefulSet, a `ReadWriteOnce` PVC | Parts IV, V |
| `mysql-84-c9s` | `latest` | MySQL 8.4 on a C9S base — for "deploy a stateful database" labs | Part IV |

```bash
# Secret consumed by a MySQL pod
kubectl create secret generic db-secret \
  --from-literal=DB_Host=sql01 \
  --from-literal=DB_User=root \
  --from-literal=DB_Password=password123

kubectl run webapp --image=quay.io/pandeysp/mywebapp:latest \
  --dry-run=client -o yaml > webapp.yaml
# add:
#   envFrom:
#     - secretRef:
#         name: db-secret
```

```bash
# A MySQL StatefulSet with a real PVC per replica
kubectl run mysql --image=quay.io/pandeysp/mysql-84-c9s:latest --dry-run=client -o yaml > mysql.yaml
# change kind to StatefulSet, add serviceName, volumeClaimTemplates with storageClassName
```

---

## A.4 Datastores and observability

| Image | Tags | Use it for | Referenced in |
|---|---|---|---|
| `redis` | `latest` | A second container in a pod, a cache Service, a `ReadWriteOnce` PVC | Parts II, IV |
| `elasticsearch` | `8.15.0` | The `elastic-stack` namespace lab | Part II §2.4 |
| `kibana` | `8.15.0` | Paired with Elasticsearch in the `elastic-stack` lab | Part II §2.4 |
| `prometheus` | `latest` | Metrics collection, a monitoring Deployment | Part VI §6.6 |
| `prom_metrics_expoter` | `latest` | A custom `/metrics` exporter for an application | Part VI §6.6 |
| `zabbix-agent2` | `alpine-6.4.13` | A **DaemonSet** — one agent per node | Parts II §2.7, VI §6.6 |
| `zabbix-proxy-sqlite3` | `alpine-6.4.13` | The Zabbix proxy with the SQLite3 backend | Part VI §6.6 |
| `jenkins` | `latest` | A CI Deployment with a persistent volume and a `ReadWriteOnce` PVC | Part IV |

```bash
# The elastic-stack lab with your images
kubectl create namespace elastic-stack
kubectl run elastic-search --image=quay.io/pandeysp/elasticsearch:8.15.0 -n elastic-stack \
  --port=9200 --env=discovery.type=single-node
kubectl run kibana --image=quay.io/pandeysp/kibana:8.15.0 -n elastic-stack \
  --port=5601 --env=ELASTICSEARCH_URL=http://elasticsearch:9200
```

```bash
# A DaemonSet of agents on every node
kubectl create deployment zabbix --image=quay.io/pandeysp/zabbix-agent2:alpine-6.4.13 \
  -n kube-system --dry-run=client -o yaml > zabbix-ds.yaml
# change kind: DaemonSet, delete spec.replicas and spec.strategy
```

---

## A.5 Load balancers

| Image | Tags | Use it for | Referenced in |
|---|---|---|---|
| `haproxy` | `latest` | L4/L7 load balancing, a front proxy for several backends | Part III |

```bash
# haproxy in front of the production:v1..v5 deployment
kubectl create deployment lb --image=quay.io/pandeysp/haproxy:latest
kubectl expose deployment lb --port=80 --type=LoadBalancer
```

---

## A.6 Quick substitution table

Drop these into any manifest in Parts II–VI by replacing the `image:` value:

| Original in your LFS258 material | Replace with |
|---|---|
| `nginx` | `quay.io/pandeysp/nginx:latest` |
| `nginx:alpine` | `quay.io/pandeysp/alpine:latest` |
| `busybox` | `quay.io/pandeysp/busybox:latest` |
| `busybox:1.28` / `busybox:1.28.4` | `quay.io/pandeysp/busybox:v1` |
| `redis` / `redis:alpine` | `quay.io/pandeysp/redis:latest` |
| `mysql` / `kodekloud/simple-webapp-mysql` | `quay.io/pandeysp/mysql:latest` |
| `kodekloud/webapp-color` | `quay.io/pandeysp/mywebapp:latest` |
| `kodekloud/event-simulator` | `quay.io/pandeysp/hotel:latest` |
| `kodekloud/filebeat-configured` | `quay.io/pandeysp/zabbix-agent2:alpine-6.4.13` |
| `docker.elastic.co/elasticsearch/elasticsearch:6.4.2` | `quay.io/pandeysp/elasticsearch:8.15.0` |
| `kibana:6.4.2` | `quay.io/pandeysp/kibana:8.15.0` |
| `httpd:2.4-alpine` / `httpd:alpine` | `quay.io/pandeysp/nginx:latest` |
| `ubuntu` | `quay.io/pandeysp/ubuntu-git:latest` |
| `registry.k8s.io/fluentd-elasticsearch:1.20` | `quay.io/pandeysp/zabbix-agent2:alpine-6.4.13` |
| `registry.k8s.io/pause:3.9` | *(leave alone — infrastructure image)* |
| `k8s.gcr.io/metrics-server/metrics-server:v0.5.2` | `quay.io/pandeysp/prom_metrics_expoter:latest` |
| `registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2` | *(leave alone — infrastructure image)* |
| `registry.k8s.io/kube-scheduler:v1.29.0` | *(leave alone — infrastructure image)* |

> **Keep the infrastructure images alone.** `pause`, `kube-scheduler`, `kube-apiserver`, `kube-controller-manager`,
> `kube-proxy`, `coredns`, `etcd`, the CNI plugin and the CSI drivers are matched to your cluster version by tag and by
> contract. Substituting them will break the cluster, and the CKA does not ask you to.


\pagebreak

## Appendix B — LFS258 → CKA Crosswalk

Every file in the repository mapped to the CKA domain and the section of this document that covers it. Use this to go
from "I have a question about X in the repo" straight to "the merged document explains it here."

## B.1 Legend

| Code | CKA domain | Part |
|---|---|---|
| **CAIC** | Cluster Architecture, Installation & Configuration | I |
| **WS** | Workloads & Scheduling | II |
| **SN** | Services & Networking | III |
| **ST** | Storage | IV |
| **SEC** | Security | V |
| **TS** | Troubleshooting | VI |

---

## B.2 `Labs/` — the numbered lab sequence

| Repo file | Domain | Topic | Covered in |
|---|---|---|---|
| `01-pods.sh` | WS | Pod lifecycle, `1/1` READY, ImagePullBackOff, `kubectl replace` vs delete/recreate | Part II §2.1 |
| `02-replicasets.sh` | WS | ReplicaSet self-healing, template edits, scaling | Part II §2.2 |
| `03.deployments.sh` | WS | Deployment objects, `kubectl create deployment` | Part II §2.3 |
| `04.namespaces.sh` | CAIC | Namespaces, `-n`, `--all-namespaces` | Part I §1.3 |
| `05.services.sh` | SN | Service types, endpoints, NodePort port pinning | Part III §3.2 |
| `06.imperative-commands.sh` | WS/SN | Everything doable without YAML; `--labels` on run vs create | Part III §3.6 |
| `07.scheduler01.sh` | WS | Node taints, `custom-columns` taint dump | Part II §2.11 |
| `08-working-with-labels.sh` | WS | Labels, `--show-labels`, selector matching | Part II §2.9 |
| `09-taint-tolerations.sh` | WS | Taints, tolerations, removal syntax `key:effect-` | Part II §2.11 |
| `10-node-affinity.sh` | WS | `nodeSelector` vs `nodeAffinity`, `Exists` vs `In` | Part II §2.11 |
| `11-resource-limits.sh` | WS | Requests/limits, QoS, editing from a live pod | Part II §2.10 |
| `12-ds.sh` | WS | DaemonSets, deriving one from a Deployment | Part II §2.7 |
| `13-static-pod.sh` | CAIC/WS | Static pods, `staticPodPath`, kubelet config | Part I §1.6 |
| `14-custom-scheduler.sh` | CAIC/WS | Second scheduler, `schedulerName`, KubeSchedulerConfiguration | Part I §1.7 |
| `15-metric-server.sh` | TS | Metrics Server, `kubectl top`, aggregation layer | Parts I §1.8, VI §6.6 |
| `16-config-map.sh` | ST | ConfigMap edit → pod recreate cycle | Parts II §2.5, IV |
| `17-secretlab.sh` | SEC | Secret creation, imperative vs declarative | Part V §5.6 |
| `18-side-car.yaml` | WS | Sidecar pattern, shared hostPath volume | Part II §2.4 |
| `19-container-commands.sh` | WS | `command` vs `args`, ENTRYPOINT/CMD mapping, Downward API | Part II §2.6 |
| `19-init-containers.sh` | WS | Init container inspection, `Init:0/2` | Part II §2.5 |
| `20-drain-uncordon-cordon.sh` | CAIC/TS | Node drain, cordon, uncordon, `--ignore-daemonsets` | Parts I §1.12, VI §6.4 |
| `21-etcd-backup-restore.md` | CAIC | Stacked etcd restore, the three operational notes | Part I §1.9a |
| `21-etcd-backup-restore.sh` | CAIC | etcdctl env vars, `snapshot save`/`restore` | Part I §1.9a |
| `21-etcd-multi-cluster.sh` | CAIC | Multi-cluster contexts, external etcd, systemd restore | Part I §1.9b |
| `22-certicates-dig.sh` | SEC/CAIC | kube-apiserver/etcd cert flags, `openssl x509` | Parts I §1.10, V §5.8 |
| `23-certificate-signing-request.sh` | SEC | CSR objects, `base64 -w 0`, approve/deny | Part V §5.8 |
| `24-kube-config.sh` | SEC | kubeconfig, `--kubeconfig`, `use-context` | Part V §5.9 |
| `25-role-based-access-control.sh` | SEC | `--authorization-mode=Node,RBAC`, Roles in `blue` | Part V §5.3 |
| `26-cluster-roles.sh` | SEC | ClusterRole/ClusterRoleBinding, `cluster-admin`, `nonResourceURLs` | Part V §5.4 |
| `27-role-rb.sh` | SEC | ServiceAccounts, RoleBinding to an SA, the three comments | Part V §5.5 |
| `28-imagesecret-pull.sh` | SEC | docker-registry secret, the plain-text failure | Part V §5.6 |
| `29-security-context.sh` | SEC | `runAsUser`, capabilities, pod vs container level | Part V §5.7 |
| `30-network-policy.sh` | SN | Ingress and egress policies, payroll/internal | Part III §3.4 |
| `31-host-volume-mount.yaml` | ST | hostPath volume, `type: directory` | Part IV §4.8 |
| `31-pv-pvc-definition.sh` | ST | PV/PVC, access-mode matching | Part IV §4.2 |
| `31-storage-class.sh` | ST | StorageClasses, `local-storage`, provisioners | Part IV §4.5 |
| `31-storage-class.yaml` | ST | `WaitForFirstConsumer`, PVC+pod, Released lifecycle | Part IV §4.5 |
| `32-networking-explore-env.sh` | SN | `ip link`, `cni0`, veth, flannel.1, node conditions | Parts I §1.5, III §3.1 |
| `33-ingress-1.sh` | SN | Ingress objects, controller Jobs, describe, rewrite-target | Part III §3.5 |
| `cluster-any-action-any-resource.yaml` | SEC | The `cluster-admin` ClusterRole verbatim | Part V §5.4 |
| `init-container-pod.yaml` | WS | One init container (`blue`) | Part II §2.5 |
| `init-container-pod-2.yaml` | WS | Two sequential init containers (`purple`) | Part II §2.5 |
| `init-container-readme.md` | WS | Init container concept, verbatim | Part II §2.5 |
| `init-cotainer.sh` | WS | `Init:Error`, the edit→delete→apply rescue | Parts II §2.5, VI §6.9 |
| `metric-server.log` | TS | Captured metrics-server log | Part VI §6.6 |
| `rb.yaml` | SEC | `developer` Role with `resourceNames` | Part V §5.3 |

---

## B.3 `Labs/configmap/`

| File | Domain | Covered in |
|---|---|---|
| `config-map.yaml` | ST | Part II §2.5, Part IV |
| `pod.yaml` | ST | Part II §2.5 |
| `pod-read-from-secret.yaml` | SEC | Part V §5.6 |
| `secret.yaml` | SEC | Part V §5.6 — the **plain-text** (failing) form |
| `secret-imperative.yaml` | SEC | Part V §5.6 — the **base64** (working) form |

## B.4 `Labs/scheduler/`

| File | Domain | Covered in |
|---|---|---|
| `my-scheduler-config.yaml` | CAIC | Part I §1.7 |
| `my-scheduler-configmap.yaml` | CAIC | Part I §1.7 |
| `my-scheduler.yaml` | CAIC | Part I §1.7 — the scheduler static pod |
| `nginx-pod.yaml` | CAIC | Part I §1.7 — `schedulerName: my-scheduler` |
| `on-control-plane.yaml`, `on-node01.yaml` | CAIC | Part I §1.7 (node-placement variants) |

## B.5 `Labs/services/`

| File | Domain | Covered in |
|---|---|---|
| `service1.yaml` | SN | Part III §3.2 — full NodePort |
| `service2.yaml` | SN | Part III §3.2 — minimal NodePort |

## B.6 `Labs/metric-server/`

| File | Domain | Covered in |
|---|---|---|
| `aggregated-metrics-reader.yaml` | CAIC | Part I §1.8 |
| `auth-delegator.yaml` | CAIC | Part I §1.8 |
| `auth-reader.yaml` | CAIC | Part I §1.8 |
| `metrics-apiservice.yaml` | CAIC | Part I §1.8 — the `APIService` |
| `metrics-server-deployment.yaml` | CAIC | Part I §1.8 |
| `metrics-server-service.yaml` | CAIC | Part I §1.8 |
| `resource-reader.yaml` | CAIC | Part I §1.8 |

---

## B.7 `ApiAccess/`

| File | Domain | Covered in |
|---|---|---|
| `commands.sh` | TS/SEC | Parts I §1.2, V §5.9, VI §6.7 |
| `console.log` | TS | Part VI §6.7 — captured API output |
| `my-json-nginx-pod.json` | CAIC | Part I §1.2 — pod JSON for `curl -XPOST` |
| `pods.json`, `pods.yaml` | TS | Part VI §6.7 — full API responses |
| `serverresources.json` | CAIC | Part I §1.2 — `/apis` dump |

## B.8 `Deployments/`

| File | Domain | Covered in |
|---|---|---|
| `DockerFile` | WS | Part II §2.6 — ENTRYPOINT vs CMD |
| `app.yaml` | ST | Part IV §4.8 |
| `elastic-search.yaml` | WS | Part II §2.4 — Elasticsearch pod |
| `kibana.yaml` | WS | Part II §2.4 — Kibana pod |
| `multi-container-pod.yaml` | WS | Part II §2.4 — `postStart` + `emptyDir` |
| `my-rs.yaml` | WS | Part II §2.2 |
| `replicaset-commands.sh` | WS | Part II §2.2 — `--cascade=orphan`, no `create replicaset` |
| `replicaset.txt` | WS | Part II §2.3 — the lab's own objectives |
| `rolling-update.sh` | WS | Part II §2.3 — rollout with a load test |
| `sloution.yaml` | WS | Part II §2.4 — the sidecar solution |

## B.9 `Ingress/`, `Networking/`, `Proxy/`, `Security/`, `Services/`, `VolumesAndData/`, root

| File | Domain | Covered in |
|---|---|---|
| `Ingress/my-ingress.yaml` | SN | Part III §3.5 — namespaced, host-based |
| `Networking/gce/10-flannel.conflist.json` | CAIC | Part I §1.5 — CNI conflist |
| `Networking/gce/kubelet.service` | TS | Part VI §6.3 |
| `Networking/gce/plugins.sh` | CAIC | Part I §1.5 — `/opt/cni/bin` contents |
| `Networking/gce/ps-aux.log` | TS | Part VI §6.3 |
| `Networking/kubeadmin/10-calico.conflist.json` | SN | Parts I §1.5, III §3.4 — Calico (implements NetworkPolicy) |
| `Networking/kubeadmin/control-plane.sh` | CAIC | Part I |
| `Networking/kubeadmin/kubelet.process.log` | TS | Part VI §6.3 |
| `Networking/kubeadmin/kubelet.service` | TS | Part VI §6.3 |
| `Networking/kubeadmin/kublet.status.log` | TS | Part VI §6.3 |
| `Networking/kubeadmin/network-namespaces.sh` | SN | Part III §3.1 — raw `ip netns` |
| `Networking/kubeadmin/networking.sh` | SN | Part III §3.1 — veth/bridge by hand |
| `Networking/kubeadmin/plugins.sh` | CAIC | Part I §1.5 |
| `Networking/nginx-deployment.yaml` | SN | Part III §3.5 |
| `Networking/nginx-ingress.yaml` | SN | Part III §3.5 — host + path |
| `Networking/nginx-service.yaml` | SN | Part III §3.2 — NodePort with DNS notes |
| `Networking/student-ingress.yaml` | SN | Part III §3.5 — multi-path |
| `Networking/temp.md` | CAIC/SN | Parts I §1.5, III §3.1 — CNI vs CNM, verbatim |
| `Networking/ubuntu-host-with-docker.sh` | SN | Part III §3.1 — `ip_forward`, `/etc/hosts` notes |
| `Networking/weave-spec.yaml` | CAIC | Part I §1.5 — full CNI DaemonSet install |
| `Proxy/proxy-window2.sh` | TS | Part VI §6.7 — `kubectl proxy` |
| `Security/config-2.yaml` | SEC | Part V §5.9 — kubeconfig with two users |
| `Security/config.yaml` | SEC | Part V §5.9 — single-user kubeconfig |
| `Security/gce/*` | CAIC/SEC | Parts I, V §5.8 — control plane specs and exploration |
| `Security/kubelet.yaml` | SEC | Part V §5.9 — `system:node:` kubeconfig |
| `Security/role-dev.yaml` | SEC | Part V §5.3 |
| `Security/role-rolebinding/cluster-role.log` | SEC | Part V §5.4 |
| `Security/role-rolebinding/commnds.sh` | SEC | Part V §5.4 — `--all-namespaces` is meaningless for ClusterRoles |
| `Security/role-rolebinding/history.sh` | SEC | Part V §5.3 — imperative rolebinding |
| `Security/role-rolebinding/image-registry.sh` | SEC | Part V §5.6 |
| `Security/role-rolebinding/network-policy/*.yaml` | SN | Part III §3.4 |
| `Security/role-rolebinding/role.yaml`, `role-binding.yaml` | SEC | Part V §5.3 |
| `Security/role-rolebinding/service-account-commands.sh` | SEC | Part V §5.5 — `kubectl create token`, `set serviceaccount` |
| `Security/role-rolebinding/sys-time.yaml` | SEC | Part V §5.7 |
| `Security/role-rolebinding/ubuntu-sleeper.yaml` | SEC | Part V §5.7 |
| `Security/rolebind.yaml`, `rolebindprod.yaml` | SEC | Part V §5.3 — immutable `roleRef` |
| `Security/t.yaml` | CAIC | Part I §1.4 — kubeadm config |
| `Services/dig.ubuntu.log`, `logs.log`, `logs2.log`, `docker-desktop-node-spec.log` | SN/TS | Parts III, VI |
| `Services/fast.yaml` | WS | Part III §3.7 — deployment in `accounting` |
| `Services/my-nginx.yaml` | WS | Part III §3.7 — `nodeSelector` |
| `Services/nginx-one.yaml` | WS | Part III §3.7 — fully commented deployment |
| `VolumesAndData/PVol.yaml` | ST | Part IV §4.2 — NFS PV |
| `VolumesAndData/car-map.yaml`, `colors.yaml`, `config-map.sh` | ST | Part IV / Part II §2.5 |
| `VolumesAndData/describe.pod.log`, `log.log`, `simple-pod-des.log` | TS | Part VI |
| `VolumesAndData/favorite`, `primary/*` | ST | Part IV — volume contents |
| `VolumesAndData/new-pod.yaml` | ST | Part IV — a live pod spec |
| `VolumesAndData/nfs-pod.yaml` | ST | Part IV §4.2 |
| `VolumesAndData/pod-with-storage-class.yaml` | ST | Part IV §4.5 |
| `VolumesAndData/provisioner-deployment.yaml`, `provisioner-pod.yaml`, `provisioner-rs.yaml` | ST | Part IV §4.5 — NFS provisioner |
| `VolumesAndData/pv-pvc-output.sh` | ST | Part IV |
| `VolumesAndData/pvc-storage-class.yaml`, `pvc.yaml` | ST | Parts IV §4.2, §4.5 |
| `VolumesAndData/readme.md` | ST | Part IV §4.5 — StorageClasses/provisioners, verbatim |
| `VolumesAndData/simple-pod.yaml`, `simple-po2.yaml`, `simpleshell.yaml`, `simpleshell-2.yaml` | ST | Part IV / Part II §2.5 |
| `VolumesAndData/storage-quota.yaml` | ST | Part IV / Part II §2.10 — ResourceQuota |
| `acg-multic-np.yaml` | SN/WS | Parts III §3.4, II §2.4 — namespaceSelector NP + logger sidecar |
| `acloudguru-etcd.sh` | CAIC | Part I §1.9c — etcd cheat sheet |
| `README.md` | — | (Unrelated poem — not course material) |

---

## B.10 The five things your repo documents that most candidates get wrong

These all appear as explicit **[Your note]** comments in your own lab files. They are worth more than any checklist.

1. **`kubectl edit pod` fails on spec changes** and writes `/tmp/kubectl-edit-*.yaml`. The fix is
   `kubectl delete pod X --force` then `kubectl apply -f /tmp/kubectl-edit-*.yaml`.
   (`16-config-map.sh`, `17-secretlab.sh`, `init-cotainer.sh`, `31-pv-pvc-definition.sh`)

2. **A ReplicaSet's template edit does nothing to existing pods.** Only the count is reconciled.
   (`02-replicasets.sh`)

3. **Removing a taint does not take `key=` or the value.** `kubectl taint node X key:effect-`.
   (`09-taint-tolerations.sh`)

4. **A docker-registry Secret must be `type: kubernetes.io/dockerconfigjson` with a single base64
   `.dockerconfigjson` key** — plain-text `Username`/`Password` keys are rejected.
   (`28-imagesecret-pull.sh`, `17-secretlab.sh`)

5. **PV and PVC access modes must match exactly** for automatic binding, and a `Retain` PV goes to `Released`, not
   `Available`. (`31-pv-pvc-definition.sh`, `31-storage-class.yaml`)


\pagebreak

## Appendix C — Your `basic-k8s` CKA Notes

**STATUS: RESERVED — awaiting the `basic-k8s` file.**

The `basic-k8s` text file containing your CKA labs was referenced but did not arrive in this workspace. Only the
LFS258 repository was delivered. Rather than guess at its contents, this appendix is pre-formatted and ready.

---

## C.1 How to supply it

Any one of these works:

1. **Paste the text directly** into the chat. I will transcribe it into this appendix verbatim, preserving your code
   blocks and comments.
2. **Drop the file into the repository** — e.g. `MERGED/basic-k8s.txt` or `Labs/basic-k8s.md` — and tell me the path.
3. **Attach it to a follow-up message** so it lands in the workspace alongside the repo.

Once it is here I will:

* transcribe it into this appendix under a `## C.N <original heading>` structure, unchanged;
* add a `**CKA domain:**` and `**Merged into:**` line under each lab so it cross-links to Parts I–VI;
* add any labs it contains that Parts I–VI do not already cover, as new numbered sections in the relevant Part;
* update the [index](#kubernetes-cka--lfs258--merged-lab--study-guide) row for this appendix;
* update [Appendix B](#appendix-b--lfs258--cka-crosswalk) with the new file.

---

## C.2 The structure each of your labs will be given

So you can see exactly what arrives, here is the template every lab in this document follows — your notes will be folded
into the same shape so the whole thing reads consistently:

```
### Lab <N>. <title>

**CKA domain:** <CAIC | Workloads & Scheduling | Services & Networking | Storage | Security | Troubleshooting>
**Merged into:** Part <X> §<Y>
**Repo file:** <path, if it also exists in the LFS258 repo>
**Alternative image:** quay.io/pandeysp/<image>:<tag>

#### Objective
<one or two sentences on what the task asks for>

#### Commands
<the exact commands you ran, in order>

#### Manifest
<the YAML, with the alt-image comment>

#### Explanation
<why it works, the concept behind it, and the fields that matter>

#### [Your note]
<your own annotation from the original file, verbatim>

#### Exam notes
<the gotchas, the traps, the time-savers>
```

---

## C.3 CKA domains your `basic-k8s` notes most likely cover

Mapping so nothing gets lost when the file arrives. If your notes touch any of these, it lands in the Part shown:

| Topic in your CKA notes | Lands in |
|---|---|
| Cluster components, `kubeadm init/join/upgrade`, HA control plane, etcd | Part I §1.1–1.4, §1.9, §1.11 |
| CNI plugin install, pod CIDR, `ip`/`iptables`, DNS (CoreDNS) | Part I §1.5, Part III §3.1, §3.8 |
| Static pods, second scheduler, kubelet config, `staticPodPath` | Part I §1.6, §1.7 |
| Metrics Server / aggregation layer, `kubectl top` | Part I §1.8 |
| RBAC — Roles, ClusterRoles, bindings, ServiceAccounts, `auth can-i` | Part V §5.2–5.5 |
| Certificates, CSR objects, kubeconfig, TLS for components | Part V §5.8, §5.9 |
| SecurityContext, capabilities, `runAsNonRoot`, Pod Security | Part V §5.7 |
| Private registries, image pull secrets | Part V §5.6 |
| NetworkPolicy — ingress, egress, `podSelector`/`namespaceSelector` | Part III §3.4 |
| Services — ClusterIP, NodePort, LoadBalancer, headless, endpoints | Part III §3.2, §3.3 |
| Ingress — controller install, host/path routing, TLS, rewrite | Part III §3.5 |
| PV / PVC / StorageClass / access modes / reclaim policy / CSI | Part IV §4.1–4.7 |
| Pods, ReplicaSets, Deployments, rollouts, rollbacks, `rollout undo` | Part II §2.1–2.3 |
| Multi-container pods, sidecar, ambassador, adapter, init containers | Part II §2.4, §2.5 |
| `command` / `args` / ENTRYPOINT / CMD, Downward API | Part II §2.6 |
| DaemonSets, StatefulSets, Jobs, CronJobs | Part II §2.7, §2.8 |
| Labels, selectors, annotations, `--show-labels` | Part II §2.9 |
| Requests, limits, QoS, LimitRange, ResourceQuota, HPA | Part II §2.10 |
| Taints, tolerations, node affinity, pod affinity, topologyKey | Part II §2.11 |
| Probes — liveness, readiness, startup | Part II §2.13 |
| Node drain/cordon/uncordon, upgrades, cluster maintenance | Part I §1.12, §1.11 |
| Troubleshooting — pod status, logs, `crictl`, control plane, network | Part VI §6.1–6.9 |

---

## C.4 What is already fully covered without your notes file

If your `basic-k8s` notes largely repeat LFS258 ground, you may find this document already covers them. For reference,
the complete competency list of the current CKA curriculum and where each one is addressed:

| # | CKA competency | Covered in |
|---|---|---|
| 1 | Manage RBAC | Part V §5.2–5.5 |
| 2 | Prepare underlying infrastructure for a cluster install | Part I §1.4 |
| 3 | Create and manage clusters with kubeadm | Part I §1.4 |
| 4 | Manage the lifecycle of a cluster | Part I §1.11, §1.12 |
| 5 | Implement and configure a CNI plugin | Part I §1.5 |
| 6 | Configure a highly-available control plane | Part I §1.4, §1.9 |
| 7 | Provision underlying infrastructure | Part I §1.4 |
| 8 | Perform a version upgrade | Part I §1.11 |
| 9 | Implement and configure an etcd cluster | Part I §1.9 |
| 10 | Perform an etcd backup and restore | Part I §1.9 |
| 11 | Understand deployments and rolling updates / rollbacks | Part II §2.3 |
| 12 | Use ConfigMaps and Secrets | Part II §2.5, Part V §5.6 |
| 13 | Scale applications | Part II §2.2, §2.10 |
| 14 | Primitives for robust, self-healing deployments | Part II §2.2, §2.3, §2.7, §2.8 |
| 15 | Resource limits and their effect on scheduling | Part II §2.10 |
| 16 | Manifest management and common tooling | Index §"kubectl patterns", Part III §3.6 |
| 17 | Configure Pod Admission and Security Context | Part V §5.7 |
| 18 | Use labels, selectors and annotations | Part II §2.9 |
| 19 | Configure liveness, readiness, startup probes | Part II §2.13 |
| 20 | Use the Downward API | Part II §2.6 |
| 21 | Multi-container pods and init containers | Part II §2.4, §2.5 |
| 22 | Rolling update / rollback on a Deployment | Part II §2.3 |
| 23 | Understand NetworkPolicies | Part III §3.4 |
| 24 | Cluster network / CNI plugin basics | Part I §1.5 |
| 25 | Networking configuration on cluster nodes | Part III §3.1 |
| 26 | Connectivity between pods | Part III §3.1 |
| 27 | Define and enforce Network Policies | Part III §3.4 |
| 28 | Kubernetes networking model — pod/service network, ClusterIP, NodePort, LoadBalancer, Ingress | Part III §3.1–3.5 |
| 29 | Ingress rules and controllers | Part III §3.5 |
| 30 | DNS service for name resolution | Part III §3.1, §3.2, Part VI §6.5 |
| 31 | Service networking model and kube-proxy | Part III §3.3 |
| 32 | Storage classes, PVs, PVCs | Part IV §4.1–4.5 |
| 33 | Container Storage Interface | Part IV §4.7 |
| 34 | Configure applications with persistent storage | Part IV §4.2, §4.8 |
| 35 | Volume modes, access modes, reclaim policies | Part IV §4.3, §4.4, §4.6 |
| 36 | PVCs and how they bind | Part IV §4.1–4.4 |
| 37 | Authentication and authorisation | Part V §5.1–5.5 |
| 38 | Kubernetes security primitives | Part V §5.7 |
| 39 | Network policies (see #23) | Part III §3.4 |
| 40 | The Kubernetes certificate system | Part V §5.8 |
| 41 | Configure `kubectl` contexts and switch between them | Part V §5.9 |
| 42 | Create and manage TLS certificates for cluster components | Part V §5.8 |
| 43 | Configure a SecurityContext for a pod or container | Part V §5.7 |
| 44 | Define ServiceAccount permissions | Part V §5.5 |
| 45 | Create and use ServiceAccounts | Part V §5.5 |
| 46 | Pull images from a private registry | Part V §5.6 |
| 47 | Troubleshoot cluster component failure | Part VI §6.3 |
| 48 | Troubleshoot application failure | Part VI §6.1, §6.2, §6.9 |
| 49 | Troubleshoot networking issues | Part VI §6.5 |
| 50 | Troubleshoot storage issues | Part IV §4.5, §4.8, Part VI §6.8 |
| 51 | Evaluate cluster and node logging | Part VI §6.3, §6.7 |
| 52 | Monitor applications | Part VI §6.6 |
| 53 | Manage container stdout and stderr logs | Part VI §6.2 |
| 54 | Troubleshoot control plane and worker node failure | Part VI §6.3, §6.4 |

**All 54 competencies are addressed in Parts I–VI.** Your `basic-k8s` notes will add *your* wording, *your* commands and
*your* personal annotations on top of that, which is exactly the value they add over any textbook.

---

*Send the `basic-k8s` file and this appendix fills in.*
