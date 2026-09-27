# Kubernetes CKA + LFS258 — Merged Lab & Study Guide

**Sources merged in this document**

| Source | What it contributes |
|---|---|
| `terra-bacth/k8s-LFS258` (this repo) | Every lab script, YAML manifest and personal annotation you wrote while working through **LFS258 – Kubernetes Fundamentals** |
| CKA exam curriculum | The domain structure, concept explanations, exam-day patterns and gotchas that LFS258 does not cover |
| `quay.io/pandeysp/*` registry | Your own container images, offered as alternatives in every lab so nothing depends on a public registry being reachable |
| `last-try/questions.sh` (740 lines) | 25 fully worked CKA exam questions — the single most valuable file in the repo |
| `mock-exam-1/2/3.sh`, `lightenin-labs/`, `practice-on-paper/`, `shells/`, `explore-services/`, `troubleshooting/`, `cluster-upgrade/`, `yaml/`, `configmap/` | Three mock exams, cluster-upgrade sequences, external-etcd drills, real troubleshooting logs, and reference manifest sets |
| `kubectl-quick-refrence.sh`, `jsaon-path-examples.sh` | Your own `kubectl` and JSONPath cheat sheets — consolidated into Appendix D |
| `last-try/scenarios-ingress.txt`, `last-try/senarisos-np.txt` | 5 Ingress and 5 NetworkPolicy scenario questions — worked in Part VII §7.29–7.30 |
| `basic-k8s/basic-labs.txt` (1,300+ lines) | **Your CKA `basic-k8s` notes, now merged** — Docker, kubeadm init flags, `imagePullPolicy`, set-based selectors, `change-cause`, blue/green, MetalLB, ingress-nginx install, `volumeName`, RBAC-by-context-switching, Helm. See **Appendix C** for the intake map and **Appendix E** for Docker + Helm |

**How to use it**

1. Work top to bottom — the parts follow the **CKA exam domain weighting**, not the LFS258 chapter order.
2. Every lab is presented as **Objective → Commands → Manifest → Explanation → Exam notes**, and every manifest carries a commented
   `# Alt image: quay.io/pandeysp/...` line so you can swap images without hunting through the repo.
3. Anything you wrote as a *personal annotation* (the `#` comments in the original scripts) is preserved verbatim and tagged
   **[Your note]** — those are your own hard-won gotchas, not filler.
4. Appendix B is a full **LFS258 → CKA crosswalk** so you can trace any repo file back to an exam objective.
5. **Part VII is the exam-drill part** — 25 full CKA questions with your answers and explanations, three mock exams, and
   ten worked Ingress/NetworkPolicy scenarios. If you only read one part before sitting the exam, read that one.
6. **Appendix C is the intake map for your `basic-k8s` notes** — every section of the file, where it landed, and the eleven
   topics it contributed that were nowhere else in the repo. Appendix E holds the Docker and Helm material.
7. Appendix C is the intake map for your merged `basic-k8s` / `basic labs.txt` notes.

---

> **One file or twelve — your choice.** This guide exists in two equivalent forms:
>
> * **`K8S-CKA-LFS258-MERGED.md`** — every part concatenated into **one single Markdown file** (10,900+ lines, ~400 KB),
>   with `\pagebreak` separators between parts and all cross-references rewritten to internal anchors. This is the
>   deliverable to read, search, print or hand to a friend.
> * **`00-index.md` … `93-appendix-d-*.md`** — the same content split into twelve interlinked files, if you would rather
>   keep them separate in an editor or a repo.
>
> Both are generated from the same source, so they never drift. The internal links work in both.

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
| [Part VII](#part-vii--exam-drills--mock-exams) | **Exam drills** — 25 worked questions + 3 mock exams + 10 scenarios | all domains | `last-try/questions.sh`, `mock-exam-1/2/3.sh`, `scenarios-ingress.txt`, `senarisos-np.txt` |
| [Appendix A](#appendix-a--quayiopandeysp-image-catalog) | Your `quay.io/pandeysp/*` image catalog | — | 33 images / 41 tags |
| [Appendix B](#appendix-b--lfs258--cka-crosswalk) | Repo file → exam objective mapping | — | all 266 files |
| [Appendix C](#appendix-c--your-basic-k8s--basic-labstxt-cka-notes) | Intake map for your `basic-k8s` / `basic labs.txt` | — | 27 sections mapped; 11 new topics merged |
| [Appendix D](#appendix-d--kubectl-and-jsonpath-quick-reference) | `kubectl` + JSONPath quick reference | — | `kubectl-quick-refrence.sh`, `jsaon-path-examples.sh` |
| [Appendix E](#appendix-e--docker-and-helm-foundations) | Docker and Helm foundations | — | `basic-k8s/basic-labs.txt` |

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

## What changed in this build, and about `lab.txt`

You asked whether there was a `lab.txt` file. There is no file by that name anywhere in the workspace
(`find / -iname "lab.txt"` returns nothing). What there **is** — and what almost certainly satisfies the request — is
`last-try/questions.sh`, a 740-line file of **25 fully worked CKA exam questions with your answers**. That file, plus
three mock exams and ten scenario questions, is now merged as **Part VII**.

A second-pass survey also found material the first pass had missed, because the original `find | head -200` was silently
truncated. All of it is now merged:

| Newly merged material | Where it landed |
|---|---|
| `last-try/questions.sh` — 25 worked exam questions | Part VII §7.1–7.25 |
| `mock-exam-1.sh`, `mock-exam-2.sh`, `mock-exam-3.sh` | Part VII §7.26–7.28 |
| `last-try/scenarios-ingress.txt` — 5 Ingress scenarios | Part VII §7.29 |
| `last-try/senarisos-np.txt` — 5 NetworkPolicy scenarios | Part VII §7.30 |
| `lightenin-labs/`, `practice-on-paper/`, `cluster-upgrade/history.sh` — v1.29 upgrade sequences | Part I §1.9 |
| `shells/`, `my-steps-etcd-systemctl.sh` — etcd-as-a-systemd-service backup/restore | Part I §1.10, Part VII §7.25 |
| `explore-services/` — ClusterIP / NodePort / LoadBalancer side by side | Part III §3.2 |
| `yaml/nginx/`, `yaml/redis/`, `configmap/` — minimal reference manifests | Part II §2.3, Part IV §4.3 |
| `troubleshooting/` — real control-plane and node logs | Part VI §6.3 |
| `last-try/gb-trouble-shooting.sh` — NodeNotReady + cross-namespace DNS | Part VI §6.1, Part VII §7.18–7.19 |
| `kubectl-quick-refrence.sh`, `jsaon-path-examples.sh` | **Appendix D** |

## About your `basic-k8s` / `basic labs.txt` notes

Both arrived, and they are the same file. It is preserved verbatim at **`basic-k8s/basic-labs.txt`** in the repository.

It turned out to contain a good deal the rest of the repo did not — **eleven new topics**, including Docker and Helm
(neither of which appeared anywhere else), `imagePullPolicy`, set-based selectors, the `change-cause` annotation,
blue/green deployments, MetalLB, installing ingress-nginx yourself, `emptyDir` on the node, `volumeName` binding, and
proving an RBAC permission by actually switching to the user's context.

All of it is merged:

* **Appendix C** is the intake map — every section of the file, where it landed, and what was new.
* **Appendix E** holds Docker and Helm, which have no other home in a Kubernetes document.
* The Kubernetes material went into the Parts where it belongs: **Part I §1.4a–1.4b** (kubeadm flags, `kubectl explain`),
  **Part II §2.3a–2.3c** (`imagePullPolicy`, `change-cause`, blue/green), **Part II §2.9a** (set-based selectors),
  **Part III §3.2a–3.2b** (MetalLB, ingress-nginx install), **Part IV §4.2a–4.2b** (`emptyDir`, `volumeName`),
  **Part V §5.3a** (RBAC by context) and **§5.8a** (the full user-cert flow with `groups:` and `--embed-certs`).

Nothing in this document is fabricated. Every lab, command, manifest, log line and `[Your note]` came out of your own
repository.

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

### 3b. `change-cause`, `rollout history` and `rollout undo --to-revision`

`basic-k8s` walks the full revision lifecycle on a real Deployment, which is the part most people skip.

```bash
vi depl.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mydep
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: con1
          image: quay.io/pandeysp/production:v1
  selector:
    matchLabels:
      app: webapp
```

```bash
k create -f depl.yaml
k get deploy
k get pods
k describe deploy mydep
k get rs
# NAME               DESIRED   CURRENT   READY   AGE
# mydep-56f6f5d5d5   3         3         3       40s

k get rs mydep-56f6f5d5d5
k describe rs mydep-56f6f5d5d5
k describe pod mydep-56f6f5d5d5-4dvct
```

**Step 1 — expose it, so you can see the version change from outside:**

```bash
k expose deploy mydep --name=dep-svc --target-port=80 --port=80 --type=LoadBalancer
k get svc
# NAME      TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
# dep-svc   LoadBalancer   10.106.26.186  172.25.230.10   80:31234/TCP   10s

curl 10.106.26.186
```

**Step 2 — update the image, which starts a new revision:**

```bash
k set image deploy mydep con1=quay.io/pandeysp/production:v2
#                      ^^^^ the CONTAINER name, not the deployment name

k get svc
k get rs
# NAME               DESIRED   CURRENT   READY   AGE
# mydep-56f6f5d5d5   0         0         0       90s     ← scaled to zero
# mydep-7d9f8c6b4q   3         3         3       10s     ← the new ReplicaSet

curl 10.106.26.186          # now serving v2
```

**Step 3 — annotate the revision with a change cause.** Without this, `rollout history` shows a bare
`REVISION  CHANGE-CAUSE` with nothing in it:

```bash
kubectl annotate deploy mydep kubernetes.io/change-cause="This is version 2"

k rollout history deploy mydep
# deployment.apps/mydep
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         This is version 2
```

> **Exam note** — the annotation must be applied **after** the change you want to label, and it applies to the revision
> that is current at that moment. There is no way to retro-label an older revision. The annotation is
> `kubernetes.io/change-cause` and it lives in `metadata.annotations` of the **Deployment's pod template**.

**Step 4 — roll back:**

```bash
k rollout undo deploy mydep                  # back to the previous revision (2 → 1)
k get pods
curl 10.106.26.186                          # serving v1 again

k rollout undo deploy mydep                  # and forward again
k rollout undo deploy mydep --to-revision=1  # or jump straight to a specific revision
curl 10.106.26.186
```

```bash
# The supporting commands
k rollout status deploy mydep               # block until the rollout completes
k rollout history deploy mydep --revision=2 # the full template of one revision
k rollout restart deploy mydep              # rolling restart, no image change
k rollout pause deploy mydep                # stop the rollout midway
k rollout resume deploy mydep
```

**Step 5 — scale and autoscale:**

```bash
k scale deploy mydep --replicas=5
k scale deploy mydep --replicas=2
k autoscale deploy mydep --min=2 --max=8 --cpu-percent=80
k get hpa
```

> **Exam note** — `kubectl rollout undo` without `--to-revision` goes to the **immediately previous** revision, not to
> revision 1. If you have rolled back and forth three times, "previous" is not where you think it is. Always pass
> `--to-revision=N` when the question names a specific version.

### 3c. Blue/green deployment — a Service selector switch

`basic-k8s` implements blue/green with **two Deployments and one Service**, and the cutover is a single edit to the
Service's selector. This is the cleanest possible version of the pattern.

```yaml
# blue.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bluedep
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: web
        version: blue
    spec:
      containers:
        - name: con1
          image: quay.io/pandeysp/production:v1
  selector:
    matchLabels:
      app: web
      version: blue
```

```yaml
# green.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: greendep
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: web
        version: green
    spec:
      containers:
        - name: con1
          image: quay.io/pandeysp/production:v2
  selector:
    matchLabels:
      app: web
      version: green
```

```yaml
# bgsvc.yaml — the switch
apiVersion: v1
kind: Service
metadata:
  name: bgsvc
spec:
  type: LoadBalancer
  ports:
    - targetPort: 80
      port: 80
  selector:
    version: blue
```

```bash
k create -f blue.yaml
k create -f green.yaml
k create -f bgsvc.yaml

k get svc
k get pods --show-labels -o wide
# NAME                        READY   STATUS    LABELS                        NODE
# bluedep-xxx-aaaaa           1/1     Running   app=web,version=blue,...      node01
# bluedep-xxx-bbbbb           1/1     Running   app=web,version=blue,...      node02
# greendep-yyy-aaaaa          1/1     Running   app=web,version=green,...     node01
# greendep-yyy-bbbbb          1/1     Running   app=web,version=green,...     node02

curl 10.103.120.165           # blue (v1)
```

**The cutover.** Both Deployments are already running and warm; you are only changing which one the Service points at.

```bash
k edit svc bgsvc
# go to the version line and change the version from blue to green
#   selector:
#     version: green
# save and exit

curl 10.103.120.165           # green (v2) — immediately
```

**Rolling back is the same edit in reverse** — no new rollout, no downtime, and the old version's pods were never
touched:

```bash
k edit svc bgsvc
curl 10.103.120.165
```

**Why the Service selector is only `version:` and not `app: web`.** Because `app: web` matches **both** Deployments'
pods, so the Service would load-balance across blue and green at the same time — exactly what you do not want. The
selector must discriminate.

**Blue/green vs rolling update vs canary:**

| | Mechanism | Downtime | Rollback | Cost |
|---|---|---|---|---|
| **Rolling update** (default) | One Deployment, new ReplicaSet scales up as the old scales down | none | `rollout undo` | 1× resources |
| **Recreate** | One Deployment, `strategy: Recreate` — old pods deleted before new ones start | **yes** | `rollout undo` | 1× resources |
| **Blue/green** | Two Deployments, switch the Service selector | none | re-edit the Service | **2× resources** |
| **Canary** | Two Deployments/Ingresses, weighted split | none | set the weight to 0 | 1× + a sliver |

> **Exam note** — blue/green is not a Kubernetes object; it is a *pattern* built from a Deployment, a Service and a
> label convention. The exam asks for the pattern, so what is graded is: two Deployments, a shared Service, and a
> selector that discriminates on the version label. See Part VII §7.29 scenario 5 for the canary variant.

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

### 3a. `imagePullPolicy` — Always, IfNotPresent, Never

`basic-k8s` drills all three, with `crictl images` used to prove the difference on the node.

```bash
k describe pod pod-demo-new | grep -i pull
#     Image:          quay.io/pandeysp/nginxdemo
#     Image ID:       quay.io/pandeysp/nginxdemo@sha256:...
#   Image Pull Policy: IfNotPresent

crictl images
# IMAGE                                      TAG     IMAGE ID        SIZE
# quay.io/pandeysp/nginxdemo                latest  a1b2c3d4e5f6    142MB
```

**The three values, and when each one applies:**

```yaml
# 1. Always — pull on every pod start, even if the image is already on the node
apiVersion: v1
kind: Pod
metadata:
  name: pod-policy1
spec:
  containers:
    - name: con1
      image: quay.io/pandeysp/nginx
      imagePullPolicy: Always
```

```yaml
# 2. IfNotPresent — use the local copy if it exists (the default when the tag is NOT :latest)
apiVersion: v1
kind: Pod
metadata:
  name: pod-policy2
spec:
  containers:
    - name: con1
      image: quay.io/pandeysp/nginx
      imagePullPolicy: IfNotPresent
```

```yaml
# 3. Never — never contact a registry; the image must already be on the node
apiVersion: v1
kind: Pod
metadata:
  name: pod-policy3
spec:
  containers:
    - name: con1
      image: quay.io/pandeysp/mysql
      imagePullPolicy: Never
```

**The default rule, which is the actual exam question:**

| Image tag | Default `imagePullPolicy` |
|---|---|
| `nginx` or `nginx:latest` | `Always` |
| `nginx:1.25` or any explicit tag | `IfNotPresent` |
| `some/image@sha256:abc123...` (digest) | `IfNotPresent` |

```bash
# Prove the third one fails when the image is absent
k create -f pod-policy1.yaml
k describe pod pod-policy3 | tail -6
# Events:
#   Warning  Failed  ... Failed to pull image "quay.io/pandeysp/mysql":
#   rpc error: code = Unknown desc = failed to pull and unpack image ...
#   Normal   BackOff  ... Back-off pulling image "quay.io/pandeysp/mysql"
#   Warning  Failed  ... Error: ErrImageNeverPull
```

`ErrImageNeverPull` is the signature of `imagePullPolicy: Never` with no local image. `ImagePullBackOff` is the
signature of `Always`/`IfNotPresent` with a bad name, a bad tag, or no registry credentials.

**Removing the policy to see the default.** `basic-k8s` deletes and recreates the pod with the field removed, which is
the cleanest demonstration:

```bash
k delete -f pod-policy.yaml
vi pod-policy.yaml          # remove the imagePullPolicy line
k create -f pod-policy.yaml
k get pods
k describe pod pod-policy2 | grep "Pull Policy"
```

> **Exam note** — the CKA asks this in three forms: (1) "set the pull policy to IfNotPresent", (2) "why is the pod in
> `ErrImageNeverPull`", and (3) "the image is `nginx:latest` — what is the pull policy". The third one catches people
> who assume `IfNotPresent` is always the default. It is not: `:latest` defaults to `Always`.

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

### 9a. Set-based selectors — `in`, `notin`, `Exists`

`basic-k8s` drills the **set-based** selector syntax, which is the half of label matching most candidates skip.

```bash
# Equality-based — one key, one value
k get pods --show-labels
k label pod pod3 env- new-                       # remove two labels at once
k get pods --selector env=prod
k get pods --selector env!=prod

# Set-based — one key, a SET of values
k label pod pod-demo-new test=new
k get pods --selector 'env in (prod,dev)'
k get pods --selector 'env notin (prod,dev)'
k get pods --selector 'test in (new,dev)'
k get pods --selector 'env notin (*)'            # every value, including none
k get pods --selector 'env notin ()'             # ??? see below
k get pods --selector 'env in ()'                # matches nothing
```

| Selector | Matches |
|---|---|
| `env=prod` | pods where `env` is exactly `prod` |
| `env!=prod` | pods where `env` exists and is **not** `prod` (a pod with no `env` label is **not** matched) |
| `env in (prod,dev)` | pods where `env` is `prod` **or** `dev` |
| `env notin (prod,dev)` | pods where `env` exists and is neither `prod` nor `dev` |
| `env` | pods where `env` exists, **any** value — the `Exists` form |
| `!env` | pods where `env` does **not** exist |
| `env notin (*)` | every pod that has an `env` label, regardless of value |
| `env in ()` | **nothing** — an empty set matches nothing |

**The same three operators exist in a ReplicaSet selector**, via `matchExpressions`:

```yaml
# basic-k8s/set-rs.yaml — a set-based ReplicaSet selector
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: rs-app-setbased
spec:
  replicas: 3
  selector:
    matchExpressions:
      - key: "app"
        operator: "In"
        values:
          - "dev"
          - "stagging"
  template:
    metadata:
      labels:
        app: dev
    spec:
      containers:
        - name: con1
          image: quay.io/pandeysp/nginxdemo
```

```yaml
# The other two operators, for completeness
  selector:
    matchExpressions:
      - key: app
        operator: NotIn
        values: ["dev", "stagging"]
      - key: tier
        operator: Exists            # no values: list
      - key: legacy
        operator: DoesNotExist     # no values: list
```

**Why this matters for the ReplicaSet.** A set-based selector makes the ReplicaSet adopt **any** pod matching
*either* value, which `basic-k8s` demonstrates by creating pods one at a time and watching the count:

```bash
k create -f set-rs.yaml
k get rs
# NAME               DESIRED   CURRENT   READY   AGE
# rs-app-setbased    3         0         0       5s

k run pod3 --image quay.io/pandeysp/nginxdemo -l app=dev
k run pod4 --image quay.io/pandeysp/nginxdemo -l app=dev
k get rs
# rs-app-setbased    3         2         2       30s      ← adopted both

k run pod6 --image quay.io/pandeysp/nginxdemo -l app=stagging
k get rs
# rs-app-setbased    3         3         3       40s      ← adopted a pod with the OTHER value

k describe rs rs-app-setbased | grep -A5 "Selector"
# Selector: app in (dev,stagging)
```

Note `stagging` — a typo for `staging` that is consistent between the selector and the labels, so it works. That is a
useful reminder that Kubernetes does not care what the value *means*, only that the selector and the labels agree.

> **Exam note** — `matchLabels` and `matchExpressions` can be combined in one selector, and they are **AND**-ed. Also
> remember: the selector is **immutable** after creation on a Deployment. On a ReplicaSet it is effectively immutable
> too (changing it orphans the existing pods).

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

### The three external types, side by side — `explore-services/services.log`

Your capture puts all three next to each other, which makes the differences visible in one screen:

```
NAME                      TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE     SELECTOR
andromeda-cluster-ip      ClusterIP      10.106.99.246   <none>        80/TCP         8m50s   run=andromeda
andromeda-load-balancer   LoadBalancer   10.98.78.195    <pending>     80:32064/TCP   3m11s   run=andromeda
andromeda-node-port       NodePort       10.96.162.69    <none>        80:31241/TCP   6m45s   run=andromeda
kubernetes                ClusterIP      10.96.0.1       <none>        443/TCP        30d     <none>
nginx-deployment          NodePort       10.99.201.242   <none>        80:30503/TCP   27d     app=nginx-deployment
```

Read the `PORT(S)` column carefully — it encodes the type:

| `PORT(S)` value | Type | How to read it |
|---|---|---|
| `80/TCP` | ClusterIP | one port, no external exposure |
| `80:31241/TCP` | NodePort | `servicePort:nodePort` — the first number is the in-cluster port, the second is the port opened on **every node** |
| `80:32064/TCP` with `EXTERNAL-IP <pending>` | LoadBalancer | `servicePort:nodePort` — a NodePort underneath, plus a cloud LB that never materialises on bare metal |

Two details in that table worth noting:

1. **All three selectors are `run=andromeda`** — the same three pods are reachable three different ways simultaneously.
   That is the cleanest demonstration that the Service *type* only changes how traffic arrives, never which pods it
   reaches.
2. **`kubernetes` has `SELECTOR <none>`.** The default Service is not selector-driven; its Endpoints object is created and
   maintained by the apiserver itself. You cannot recreate it, and you should not try.

```bash
# Reproduce the side-by-side
kubectl expose deployment andromeda --name=andromeda-cluster-ip --port=80
kubectl expose deployment andromeda --name=andromeda-node-port --type=NodePort --port=80
kubectl expose deployment andromeda --name=andromeda-load-balancer --type=LoadBalancer --port=80
kubectl get svc
```

**The manifests**, from `explore-services/`:

```yaml
# explore-services/cluster-ip.yaml
apiVersion: v1
kind: Service
metadata:
  name: andromeda-cluster-ip
spec:
  type: ClusterIP
  selector:
    run: andromeda
  ports:
    - port: 80
      targetPort: 80
---
# explore-services/node-port.yaml
apiVersion: v1
kind: Service
metadata:
  name: andromeda-node-port
spec:
  type: NodePort
  selector:
    run: andromeda
  ports:
    - port: 80
      targetPort: 80
      nodePort: 31241          # pin it, or the kernel picks a random 30000-32767 port
---
# explore-services/load-balancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: andromeda-load-balancer
spec:
  type: LoadBalancer
  selector:
    run: andromeda
  ports:
    - port: 80
      targetPort: 80
```

> **Exam note** — `EXTERNAL-IP <pending>` on a bare-metal cluster is **normal**, not broken. A LoadBalancer Service only
> ever becomes reachable if a controller (MetalLB, or a cloud provider's CCM) is installed. If the exam asks you to
> "expose the app externally" on a bare-metal cluster, the answer is almost always **NodePort** or **Ingress**, not
> LoadBalancer.

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

### The CoreDNS Corefile, verbatim — `core-dns-configmap.yaml`

This is the whole of DNS in a kubeadm cluster, and reading it once answers half the DNS questions on the exam.

```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
```

Line by line, the parts that matter:

| Plugin / directive | What it does | Why you care |
|---|---|---|
| `.:53` | Listen on port 53 for **all** zones | The port the kubelet puts in `/etc/resolv.conf` |
| `errors` | Log errors to stdout | Where DNS failures show up in `kubectl -n kube-system logs -l k8s-app=kube-dns` |
| `ready` | Report readiness on :8181 | The readiness probe port |
| `kubernetes cluster.local in-addr.arpa ip6.arpa` | Serve records for the cluster domain **and** both reverse zones | The `cluster.local` here is the `--cluster-domain` |
| `pods insecure` | Answer A records for pod IPs | Enables `10-244-192-4.default.pod.cluster.local` — the reverse-lookup form from `mock-exam-2.sh` |
| `fallthrough in-addr.arpa ip6.arpa` | Pass unresolved reverse lookups to the next plugin | Without it, `nslookup 10.244.192.4` for a non-cluster IP fails |
| `ttl 30` | Cache records for 30 s | Why a stale Service IP can linger for half a minute |
| `forward . /etc/resolv.conf` | Everything else goes to the node's upstream resolver | This is how pods reach the internet |
| `prometheus :9153` | Expose metrics on 9153 | The CoreDNS monitoring port |
| `cache 30` | Cache for 30 s | Combined with `ttl 30` |
| `loop` | Detect and break forwarding loops | If you see `plugin/loop: Could not find a "Corefile"` the loop guard fired |
| `reload` | Reload the Corefile every 30 s | **You can edit this ConfigMap and the change takes effect within 30 s with no restart** |
| `loadbalance` | Randomise the order of A records | Why a headless Service's DNS answer order changes between queries |

```bash
# Inspect and edit live
kubectl -n kube-system get configmap coredns -o yaml
kubectl -n kube-system edit configmap coredns

# The common exam edit: change the cluster domain or add a stubDomain
kubectl -n kube-system get configmap coredns -o yaml | grep -A2 'stubDomains'

# Verify after a change (give it up to 30s)
kubectl -n kube-system rollout restart deployment coredns     # force it immediately
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=20
```

> **Exam note** — three CoreDNS questions appear regularly: (1) the Corefile lives in ConfigMap `coredns` in
> `kube-system`; (2) the Service it fronts is `kube-dns` at `10.96.0.10` by default; (3) `pods insecure` is the line
> that makes pod-IP reverse lookups work. All three are visible in the block above.

---

### 2a. MetalLB — making `LoadBalancer` actually work on bare metal

Everything in §3.2 assumed a cloud provider. On a bare-metal or VM cluster a `LoadBalancer` Service sits at
`EXTERNAL-IP <pending>` forever, because nothing in Kubernetes implements the load-balancer API. **MetalLB** is that
implementation, and `basic-k8s` installs it in two steps.

```bash
k apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml

k get ns
# NAME              STATUS   AGE
# metallb-system    Active   20s

k get pod,svc -n metallb-system
# NAME                              READY   STATUS    RESTARTS   AGE
# pod/controller-7d4b6c5f9-xxxxx    1/1     Running   0          18s
# pod/speaker-abcde                 1/1     Running   0          18s      ← one per node, a DaemonSet

# NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
# service/webhook-service  ClusterIP   10.98.234.11   <none>        443/TCP   18s
```

**Step 2 — the IPAddressPool.** Until you define a pool, MetalLB has no addresses to hand out and the Service stays
`pending`:

```yaml
# ip-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: pool
  namespace: metallb-system
spec:
  addresses:
    - 172.25.230.10 - 172.25.230.30
```

```bash
k create -f ip-pool.yaml
k get ipaddresspool -n metallb-system
k get svc
# NAME      TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE
# lb-ecom   LoadBalancer   10.98.78.195   172.25.230.10    80:32064/TCP   2m

curl 172.25.230.10
```

**The address must be routable to a node.** MetalLB announces the pool addresses over ARP (layer 2 mode) or BGP
(layer 3). In L2 mode, which is what `metallb-native.yaml` defaults to, the address has to be on the same subnet as
the nodes so that ARP replies reach them.

```bash
# Verify MetalLB is really announcing
k logs -n metallb-system -l app=metallb,component=speaker --tail=20
# {"level":"info","msg":"service announcer","event":"startAdvertising","ip":"172.25.230.10",...}
```

**The full LoadBalancer lab, from `basic-k8s`:**

```bash
vi ecom.yaml
k create -f ecom.yaml        # a 2-replica ReplicaSet of quay.io/pandeysp/mywebapp

vi lb.yaml
k create -f lb.yaml
k get svc                   # EXTERNAL-IP <pending> — MetalLB not installed yet

k apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
k get pods -n metallb-system

vi ip-pool.yaml
k create -f ip-pool.yaml

k get svc                   # EXTERNAL-IP 172.25.230.10
curl 172.25.230.10
```

> **Exam note** — MetalLB is **not** on the CKA syllabus and is not installed on the exam cluster. What is worth
> knowing: (1) a `LoadBalancer` Service is just a NodePort Service plus a controller that programs the external
> address; (2) the NodePort is still allocated underneath, which is why the `PORT(S)` column shows
> `80:32064/TCP`; (3) if a question says "expose the application externally" on a bare-metal cluster, the answer is
> **NodePort** or **Ingress**, not LoadBalancer.

### 2b. Installing the ingress controller yourself — `basic-k8s`'s route

Part III §3.5 assumes an ingress controller is already present, because that is what the exam gives you. `basic-k8s`
installs one from scratch, and the order matters: **MetalLB first, then ingress-nginx**, because the controller's
Service is itself a `LoadBalancer` and needs something to allocate its address.

```bash
# 1. MetalLB + a pool (see §2a above)
k apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
k create -f ippool.yaml

# 2. Clone the ingress-nginx repo and apply the cloud provider manifest
git clone https://github.com/kubernetes/ingress-nginx.git
ls -ltrh

k apply -f ingress-nginx/deploy/static/provider/cloud/deploy.yaml

k get ns
# NAME           STATUS   AGE
# ingress-nginx  Active   30s

k get pod,svc -n ingress-nginx
# NAME                                         READY   STATUS     RESTARTS   AGE
# pod/ingress-nginx-admission-create-xxxxx     0/1     Completed  0          25s
# pod/ingress-nginx-admission-patch-xxxxx      0/1     Completed  0          25s
# pod/ingress-nginx-controller-xxxxx           1/1     Running    0          25s
#
# NAME                                         TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# service/ingress-nginx-controller             LoadBalancer   10.104.7.211   172.25.230.10    80:31234/TCP,443:32065/TCP
```

**The two admission Jobs.** Those `Completed` pods are not leftovers — they are the admission webhook's setup and teardown.
See Part III §3.5 for why they exist and what their failure looks like.

**The three backends and one Ingress with three paths** — the `basic-k8s` version of the hotel/tea/coffee lab:

```bash
k create deploy hotel  --image=quay.io/pandeysp/hotel   --replicas=2
# Alt image: quay.io/pandeysp/portfolio:latest
k create deploy tea    --image=quay.io/pandeysp/tea     --replicas=2
# Alt image: quay.io/pandeysp/tea:latest
k create deploy coffee --image=quay.io/pandeysp/coffee  --replicas=2
# Alt image: quay.io/pandeysp/coffee:latest

k get deploy
k expose deploy tea    --target-port=80 --port=80
k expose deploy coffee --target-port=80 --port=80
k expose deploy hotel  --target-port=80 --port=80
k get svc
```

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tour-ing
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /hotel
            pathType: Prefix
            backend:
              service:
                name: hotel
                port:
                  number: 80
          - path: /tea
            pathType: Prefix
            backend:
              service:
                name: tea
                port:
                  number: 80
          - path: /coffee
            pathType: Prefix
            backend:
              service:
                name: coffee
                port:
                  number: 80
```

```bash
k create -f ingress.yaml
k get ing
k get ing -w

curl 172.25.230.10/tea
curl 172.25.230.10/coffee
curl 172.25.230.10/hotel
```

**Why `rewrite-target: /` is needed here.** The three Services expect `/`, not `/tea`. Without the annotation, a request
for `/tea` is forwarded to the `tea` Service as `GET /tea`, which nginx answers with `404`. The annotation rewrites the
URI to `/` before proxying. See Part III §3.5 "Rewrite — the annotation that catches everyone".

**Testing from a browser in KillerCoda.** Your note:

> *go to killercoda right side → select target port → Access port → enter the 30003*

KillerCoda (and most lab environments) only expose a fixed set of ports on the node. If the Service's `nodePort` is not
one of them, `curl` from inside the cluster works but the browser cannot reach it. Either pick a `nodePort` that the
environment exposes, or use `kubectl port-forward`:

```bash
k port-forward svc/node-svc 8080:80
# then browse to localhost:8080
```

> **Exam note** — when an Ingress returns `404` but `kubectl get ing` shows an `ADDRESS`, the three causes in order
> are: (1) the path does not match because `pathType` is wrong (`Exact` vs `Prefix`), (2) the rewrite annotation is
> missing, (3) the Service has no endpoints. Check `kubectl get endpoints <svc>` before anything else.

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

### 2a. `emptyDir` — proving where the data actually lives

`basic-k8s` walks the `emptyDir` volume all the way down to the node's filesystem, which is the only way to really
understand what "ephemeral" means.

```yaml
# emptydir.yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  volumes:
    - name: emphemeral
      emptyDir: {}
  containers:
    - name: c1
      image: quay.io/pandeysp/nginxdemo
      # Alt image: quay.io/pandeysp/nginxdemo:latest
      volumeMounts:
        - name: emphemeral
          mountPath: /mydata
```

```bash
k create -f emptydir.yaml
k get pods
k get pods -o wide
k describe pod mypod

k exec -it mypod -- sh
/ # cd mydata
/mydata # echo "Hello from containers" > file1
/mydata # cat file1
Hello from containers
/mydata # exit
```

**Now open the node the pod is running on and find the same file:**

```bash
open the worker node where pod is running

find / -name file1
# /var/lib/kubelet/pods/6f2b1c8e-.../volumes/kubernetes.io~empty-dir/emphemeral/file1

cd /var/lib/kubelet/pods/6f2b1c8e-.../volumes/kubernetes.io~empty-dir/emphemeral
cat file1
# Hello from containers

echo "Hello from node" > file2
```

**And prove the write from the node is visible in the container:**

```bash
switch back to master and confirm the file is created and seen in container

k exec -it mypod -- sh
/mydata # cat file2
Hello from node
/mydata # exit
```

**The path, decoded:**

```
/var/lib/kubelet/pods/<POD-UID>/volumes/kubernetes.io~empty-dir/<VOLUME-NAME>/
                    ^^^^^^^^            ^^^^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^
                    the pod's UID,      the volume type,      the name from
                    not its name        with ~ for the /      spec.volumes[].name
```

```bash
# Get the UID without guessing
k get pod mypod -o jsonpath='{.metadata.uid}'
# 6f2b1c8e-3a4b-4c5d-9e8f-1234567890ab
```

**The point of the exercise — `emptyDir` dies with the pod:**

```bash
k delete pod mypod
you can open the worker node and see the storage is deleted along with pod
```

Recreate the pod and the directory is new and empty. That is what distinguishes `emptyDir` from `hostPath` (§4.8) and
from a PVC (§4.2).

**Your task, from `basic-k8s`, verbatim:**

> *Task: Find a way to define size limit in emptydir type of storage*

The answer is `emptyDir.sizeLimit`, and it is the answer to a real exam question:

```yaml
spec:
  volumes:
    - name: emphemeral
      emptyDir:
        sizeLimit: 500Mi        # the kubelet evicts the pod if the volume exceeds this
```

```yaml
# The other emptyDir field, for scratch space on a specific medium
    - name: cache
      emptyDir:
        medium: Memory          # a tmpfs — counts against the container's memory limit
        sizeLimit: 128Mi
```

> **Exam note** — `medium: Memory` makes the `emptyDir` a `tmpfs`. It is RAM-backed, it is always empty at start, and
> **it counts against the container's memory limit** rather than ephemeral-storage. `sizeLimit` works with both media.
> On the CKA this shows up as "give the container a scratch volume capped at 256Mi".

### 2b. Explicit binding with `volumeName`, and `ReadWriteMany`

`basic-k8s` binds its PVC to a specific PV by name rather than letting the binder choose, and it uses
`ReadWriteMany` — the access mode that lets **many** pods on **many** nodes mount the volume at once.

```yaml
# pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv1
spec:
  storageClassName: local-path
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: /mnt
```

```yaml
# pvc.yaml — note volumeName
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc1
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: pv1
```

```yaml
# pvpod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pv-pod
spec:
  volumes:
    - name: persist
      persistentVolumeClaim:
        claimName: pvc1
  containers:
    - name: con1
      image: quay.io/pandeysp/nginxdemo
      # Alt image: quay.io/pandeysp/nginxdemo:latest
      volumeMounts:
        - name: persist
          mountPath: /mycon
```

```bash
k create -f pv.yaml -f pvc.yaml
k get pv,pvc
# NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
# pv1      1Gi        RWX            Retain           Bound    default/pvc1
#
# NAME     STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# pvc1     Bound    pv1      1Gi        RWX            local-path     5s

k create -f pvpod.yaml
k get pods
k describe pod pv-pod
k describe pv pv1
k describe pvc pvc1
```

**`volumeName` pins the binding.** Without it, the binder picks any PV whose capacity and access modes satisfy the
request. With it, the PVC binds to **that** PV or stays `Pending`:

```bash
k get pvc pvc1
# NAME   STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# pvc1   Bound    pv1      1Gi        RWX            local-path     5s

# If pv1 were already claimed, or the access modes disagreed:
k describe pvc pvc1 | tail -4
# Events:
#   Warning  ProvisioningFailed  ... no volumes available to bind
```

**The data-survives-the-pod proof.** Delete the pod, recreate it, and the file is still there — because the PV, not the
pod, owns the data:

```bash
k exec -it pv-pod -- sh
/mycon # echo "Hello from containers" > newfile1
/mycon # cat newfile1
Hello from containers
/mycon # exit

k get pods -o wide
k delete -f pvpod.yaml
k create -f pvpod.yaml
k get pods -o wide

k exec -it pv-pod -- sh
/mycon # cat newfile1
Hello from containers          ← still here
/mycon # exit

k get pv
k get pv,pvc
```

**`ReadWriteMany` vs the other two modes:**

| Access mode | Short | Mounted by | Typical backend |
|---|---|---|---|
| `ReadWriteOnce` | `RWO` | one node, read-write | block storage (EBS, GCE PD, hostPath on one node) |
| `ReadOnlyMany` | `ROX` | many nodes, read-only | read-only shares |
| `ReadWriteMany` | `RWX` | **many nodes, read-write** | NFS, CephFS, GlusterFS |

> **Exam note** — `hostPath` on a single node can *advertise* `RWX`, as `basic-k8s` does, but the pods still have to
> land on the **same node** for it to mean anything — a pod on node02 mounting node01's `/mnt` sees nothing. On a
> multi-node cluster, real `RWX` needs a shared filesystem. That is why the exam's `RWX` questions are always NFS or
> `storageClassName: no-provisioner` with a shared backend.

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

### 3a. Proving a permission by actually using it

`basic-k8s` does not stop at `kubectl auth can-i`. It creates a **context for the new user** and switches to it, which is
the only way to demonstrate a permission the way the exam grades it.

**Step 1 — a Role, bound to a ServiceAccount, verified with `--as`:**

```bash
k api-resources
k api-resources --namespaced=true
k api-resources --namespaced=false

k get roles
k create role myrole --verb=get,list --resource=pod,svc
k get roles
k describe role myrole
# Name:         myrole
# Labels:       <none>
# Annotations:  <none>
# PolicyRule:
#   Resources  Non-Resource URLs  Resource Names  Verbs
#   ---------  -----------------  --------------  -----
#   pods       []                 []              [get list]
#   svc        []                 []              [get list]

k run pod1 --image quay.io/pandeysp/nginxdemo
k describe pod pod1

k create rolebinding sabind --role=myrole --serviceaccount=default:default
k get rolebinding sabind
k describe role myrole
k describe rolebinding sabind

# Verify WITHOUT switching
k auth can-i get cm  --as=system:serviceaccount:default:default
# no
k auth can-i get pod --as=system:serviceaccount:default:default
# yes
k auth can-i get pv  --as=system:serviceaccount:default:default
# no
k auth can-i create pod --as=system:serviceaccount:default:default
# no
```

Note the two negative results and why they are correct:

* `get cm` → **no**, because the Role only lists `pod,svc`
* `get pv` → **no**, because a Role is **namespaced** and `persistentvolumes` is cluster-scoped

**Step 2 — a second ServiceAccount, with a different Role, to show the bindings are independent:**

```bash
k get sa
k describe sa default
k create sa auto
k get sa
# NAME      SECRETS   AGE
# auto      0         2s
# default   0         22d

k create role myrole1 --verb=create --resource=pod,rs
k get roles
k create rolebinding sabindnew --role=myrole1 --serviceaccount=default:auto
k describe rolebinding sabindnew

k auth can-i create pod --as=system:serviceaccount:default:auto
# yes
k auth can-i get pod    --as=system:serviceaccount:default:auto
# no          ← create only, exactly as the Role says
```

**Step 3 — bind a Role to a *User*, then switch context and prove it.** This is the step `basic-k8s` adds that most
people skip, and it is the one that catches mistakes:

```bash
k create rolebinding mybind --role=myrole --user=pandey
k get rolebinding
k describe rolebinding mybind

k config get-contexts
k config use-context pandey
k get pods
# NAME   READY   STATUS    RESTARTS   AGE
# pod1   1/1     Running   0          3m        ← the Role works

k get svc
# NAME   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# ...                                  ← also allowed by the Role

k get cm
# Error from server (Forbidden): configmaps is forbidden: User "pandey" cannot
# list resource "configmaps" in API group "" in the namespace "default"
#                                     ← exactly the restriction we wanted

k delete pod pod1
# Error from server (Forbidden): pods "pod1" is forbidden: User "pandey" cannot
# delete resource "pods" in API group "" in the namespace "default"
#                                     ← get/list only, not delete

k get nodes
# Error from server (Forbidden): nodes is forbidden: User "pandey" cannot
# list resource "nodes" in API group "" at the cluster scope
#                                     ← a Role does not reach cluster-scoped resources
```

**Step 4 — switch back, and re-verify with `--user`:**

```bash
k config use-context kubernetes-admin@kubernetes
k config get-contexts
k get nodes

k auth can-i get cm      --user=pandey      # no
k auth can-i get pod     --user=pandey      # yes
k auth can-i create pod  --user=pandey      # no
k auth can-i create svc  --user=pandey      # no
k auth can-i get svc     --user=pandey      # yes
```

**Step 5 — the cluster-scoped version, verified the same way:**

```bash
k api-resources --namespaced=false
k get clusterrole
k describe clusterrole cluster-admin

k create clusterrole myclusterrole --verb=get,list --resource=ns,nodes
k describe clusterrole myclusterrole

# A common mistake: forgetting the NAME of the binding
k create clusterrolebinding --clusterrole=myclusterrole --user=pandey
# error: exactly one NAME is required for clusterrolebinding

k create clusterrolebinding myclsuterbind --clusterrole=myclusterrole --user=pandey
k describe clusterrolebinding myclsuterbind

k auth can-i get nodes --user=pandey     # yes
k auth can-i get ns    --user=pandey     # yes
k auth can-i get sc    --user=pandey     # no

k create clusterrolebinding sabindclusternew --clusterrole=myclusterrole --serviceaccount=default:auto
k describe clusterrolebinding sabindclusternew

k auth can-i get nodes --as=system:serviceaccount:default:auto   # yes
k auth can-i get ns    --as=system:serviceaccount:default:auto   # yes
k auth can-i get sc    --as=system:serviceaccount:default:auto   # no
```

> **Exam note** — the three verification techniques, in order of how much they prove:
> `kubectl auth can-i --as=...` (asks the authoriser, no client involved),
> `kubectl auth can-i --user=...` (same, for users), and
> **`kubectl config use-context <ctx>` then actually run the command** (the only one that exercises the real kubeconfig,
> the real client cert and the real transport). If a question says "confirm the user can only read pods", the third
> technique is what earns the point.

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

### 8a. The full user-certificate flow, end to end — `basic-k8s/basic-labs.txt`

`basic-k8s` runs the whole thing with the two-terminal workflow that makes the copy-paste steps obvious. Two details in
it are worth calling out because they are easy to get wrong: the `groups:` field, and `--embed-certs`.

```bash
mkdir -p /root/kube/pandey
cd /root/kube/pandey

# 1. Generate the private key
openssl genrsa -out pandey.key 2048

# 2. Generate the CSR. The CN becomes the username; the O entries become the groups.
openssl req -new -key pandey.key -out pandey.csr
#   Country Name (2 letter code): IN
#   State or Province Name: delhi
#   Common Name: pandey          ← this is the USERNAME
#   (rest can be skipped)

# 3. Base64 the CSR — one line, no wrapping
cat pandey.csr | base64 -w 0
# copy the content to the other tab and paste it in the csr request field
```

**[Your note]** — the `(rest can be skiped)` annotation. Only `CommonName` matters for a user certificate; the
organisational fields are ignored by Kubernetes. You *can* add `Organization` entries and they become the user's
**groups**, which is how you grant permissions to a whole team at once instead of one user at a time.

```yaml
# csr-pandey.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: pandey
spec:
  groups:
    - system:authenticated
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ3FEQ0NBWkFDQVFBd1l6
            RUxNQWtHQTFVRUJoTUNTVTR4RGpBTUJnTlZCQWdNQldSbGJHaHBNUlV3RXdZRApWUVFIREF4
            ...                          # the one-line base64 from step 3
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
```

**Two details your version has that the LFS258 lab does not:**

| Field | Why it is there |
|---|---|
| `groups: [system:authenticated]` | Puts the issued cert's subject into the `system:authenticated` group. Without it the cert is technically valid but is **not** a member of the authenticated group, so some authorisers and admission plugins will refuse it |
| `usages: [client auth]` only | The minimal set. The other locations in your repo add `digital signature` and `key encipherment`; both forms are accepted, but `client auth` is the one that must be present |

```bash
# 4. Create and approve
k create -f csr-pandey.yaml
k get csr
# NAME     AGE   SIGNERNAME                                    REQUESTOR           CONDITION
# pandey   5s    kubernetes.io/kube-apiserver-client           kubernetes-admin     Pending

k certificate approve pandey
k get csr
# NAME     AGE   SIGNERNAME                                    REQUESTOR           CONDITION
# pandey   8s    kubernetes.io/kube-apiserver-client           kubernetes-admin     Approved,Issued

# 5. Extract the issued certificate
k get csr pandey -o yaml
# copy the certificate and open a new tab

echo <paste the certificate> | base64 -d > pandey.crt
```

**Step 6 — build the kubeconfig, and the `--embed-certs` gotcha:**

```bash
k config view

# Without --embed-certs, this stores a FILE REFERENCE, not the cert
k config set-credentials pandey --client-key pandey.key --client-certificate pandey.crt
k config view
# users:
# - name: pandey
#   user:
#     client-certificate: /root/kube/pandey/pandey.crt     ← a path
#     client-key:         /root/kube/pandey/pandey.key      ← a path

# WITH --embed-certs, the PEM is inlined into the kubeconfig
k config set-credentials pandey \
  --client-key pandey.key \
  --client-certificate pandey.crt \
  --embed-certs

k config view
# users:
# - name: pandey
#   user:
#     client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCg==...
#     client-key-data:         LS0tLS1CRUdJTiBSU0EUFERTJBMkF...
```

**[Your note]** — the two-tab dance, verbatim:

> *copy the certificate and open a new tab*
> *`echo <pastethe certificate> | base64 -d > pandey.crt`*
> *switch back tyo previous tab*

The two-terminal workflow exists because the base64 certificate is several kilobytes long and unreadable on one line.
The alternative that avoids the copy-paste entirely:

```bash
# Do it in one command — no manual copy
k get csr pandey -o jsonpath='{.status.certificate}' | base64 -d > pandey.crt
```

**Step 7 — the context, and the test:**

```bash
k config get-contexts
k config set-context pandey --user=pandey --cluster=kubernetes
k config get-contexts
k config use-context pandey
k config get-context

k get pods
k get svc
k get cm

k config use-context kubernetes-admin@kubernetes
k get pods
```

> **Exam note** — `--embed-certs` is not cosmetic. If you set the credentials without it and then move the kubeconfig to
> another machine (or run `kubectl` from a different directory), the file references break and you get
> `unable to read client-cert ... no such file or directory`. The exam's kubeconfig questions almost always want
> `--embed-certs`, because the resulting file must be self-contained.

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

## 6.10 Real log captures from your cluster — `troubleshooting/`

Everything above is theory. This section is the evidence: eight captures from a real cluster (`ip-172-31-40-74`,
kubeadm, Calico CNI, containerd 1.6.28, v1.28.8), plus the manifests that produced them.

### 10a. `describe-node.log` — a **healthy** node, and what that looks like

Worth studying, because half of troubleshooting is recognising "this is fine":

```
Name:               ip-172-31-40-74
Roles:              control-plane
Labels:             beta.kubernetes.io/arch=amd64
                    kubernetes.io/hostname=ip-172-31-40-74
                    node-role.kubernetes.io/control-plane=
Annotations:        kubeadm.alpha.kubernetes.io/cri-socket: unix:///var/run/containerd/containerd.sock
                    projectcalico.org/IPv4Address: 172.31.40.74/20
                    projectcalico.org/IPv4IPIPTunnelAddr: 192.168.10.0
Taints:             <none>
Unschedulable:      false
Lease:
  HolderIdentity:  ip-172-31-40-74
  RenewTime:       Sat, 30 Mar 2024 10:09:19 +0000
Conditions:
  Type                 Status  LastHeartbeatTime          LastTransitionTime         Reason                  Message
  NetworkUnavailable   False   Sat, 30 Mar 2024 09:50:45   Sat, 30 Mar 2024 09:50:45  CalicoIsUp              Calico is running on this node
  MemoryPressure       False   Sat, 30 Mar 2024 10:05:56   Thu, 21 Mar 2024 09:14:23  KubeletHasSufficientMemory
  DiskPressure         False   Sat, 30 Mar 2024 10:05:56   Fri, 22 Mar 2024 16:29:24  KubeletHasNoDiskPressure
  PIDPressure          False   Sat, 30 Mar 2024 10:05:56   Thu, 21 Mar 2024 09:14:23  KubeletHasSufficientPID
  Ready                True    Sat, 30 Mar 2024 10:05:56   Thu, 21 Mar 2024 09:14:23  KubeletReady            kubelet is posting ready status. AppArmor enabled
Addresses:
  InternalIP:  172.31.40.74
  Hostname:    ip-172-31-40-74
Capacity:
  cpu:                2
  ephemeral-storage:  7941576Ki
```

Four things to read off this every single time:

1. **`Taints:`** — `<none>` here. On a control-plane node you expect
   `node-role.kubernetes.io/control-plane:NoSchedule`. If the taint is gone, someone removed it and the node will now
   accept workloads that should not run there.
2. **`Lease.RenewTime`** — the freshest timestamp on a healthy node. A `RenewTime` that is **minutes** old while
   `LastHeartbeatTime` is also stale means the kubelet has stopped reporting, which is the first sign of `NotReady`.
3. **`Ready: True` with `LastTransitionTime` far in the past** — the node has been ready for 9 days. A
   `LastTransitionTime` of "30 seconds ago" on a `Ready: False` means something *changed*; that is your incident window.
4. **`NetworkUnavailable: False` + `Reason: CalicoIsUp`** — the CNI is Calico, so **NetworkPolicy is enforced** on this
   cluster. That matters enormously for the policies in Part III §3.4 and Part VII §7.30.

### 10b. `app/pod.yaml` + `app/mysql.yaml` — the cross-namespace DNS bug, live

This is the clearest example in your repo of the single most common CKA networking failure. Two pods:

```yaml
# troubleshooting/app/pod.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    name: webapp-mysql
  name: webapp-mysql-785cd8f94-44469
  namespace: delta                      # ← the app lives in "delta"
spec:
  containers:
    - env:
        - name: DB_Host
          value: mysql-service          # ← the SHORT name
        - name: DB_User
          value: sql-user
        - name: DB_Password
          value: paswrd
      image: mmumshad/simple-webapp-mysql
      name: webapp-mysql
      ports:
        - containerPort: 8080
```

```yaml
# troubleshooting/app/mysql.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    name: mysql
  name: mysql
  namespace: alpha                      # ← the database lives in "alpha"
spec:
  containers:
    - env:
        - name: MYSQL_ROOT_PASSWORD
          value: paswrd
      image: mysql:5.6
      ports:
        - containerPort: 3306
```

**The bug.** The app in `delta` connects to `mysql-service`. But `mysql` (and therefore the Service in front of it) is
in `alpha`. A pod's DNS search list only contains **its own** namespace, so `mysql-service` is tried as
`mysql-service.delta.svc.cluster.local` and fails.

**The diagnosis, in order:**

```bash
# 1. Where does the app actually live?
kubectl get pods -A -o wide | grep webapp-mysql
# delta    webapp-mysql-785cd8f94-44469   1/1   Running   0   5m   172.31.40.74

# 2. What is it trying to reach, and does that name exist anywhere?
kubectl get svc -A | grep mysql-service
# alpha    mysql-service   ClusterIP   10.100.20.10   <none>   3306/TCP   5m

# 3. Confirm the failure from inside the pod
kubectl -n delta exec deploy/webapp-mysql -- nslookup mysql-service
# Server:    10.96.0.10
# ** server can't find mysql-service.delta.svc.cluster.local: NXDOMAIN

# 4. Prove the FQDN works
kubectl -n delta exec deploy/webapp-mysql -- nslookup mysql-service.alpha.svc.cluster.local
# Name:      mysql-service.alpha.svc.cluster.local
# Address:   10.100.20.10
```

**The three fixes, best first:**

```bash
# a) Use the FQDN in the app's environment
kubectl -n delta set env deploy/webapp-mysql DB_Host=mysql-service.alpha.svc.cluster.local

# b) Or the namespace-qualified short form (.svc.cluster.local is in the search path)
kubectl -n delta set env deploy/webapp-mysql DB_Host=mysql-service.alpha

# c) Or move the Service into the app's namespace — but it must select pods in ITS OWN namespace,
#    so this needs an ExternalName Service instead
kubectl -n delta create serviceexternalname mysql-service \
  --external-name=mysql-service.alpha.svc.cluster.local
```

> **Exam note** — this exact pair of files (`app/pod.yaml`, `app/mysql.yaml`) and the `gb-trouble-shooting.sh` capture
> (`web-consumer` in `web` reaching `auth-db` in `data`) are the **same bug in two different clusters**. You hit it
> twice, independently. It is worth memorising as a reflex: *"cannot resolve host" → `kubectl get svc -A | grep <name>`
> → check the namespace.*

### 10c. `application.log` — the log drill

A 10.9 KB application log. The pattern:

```bash
# Never read the whole thing. Filter first.
kubectl logs deploy/webapp-mysql -n delta | grep -iE 'error|fail|denied|refused|timeout'

# The failure signature for the bug above
kubectl logs deploy/webapp-mysql -n delta | grep -i 'getaddrinfo'
# getaddrinfo ENOTFOUND mysql-service
```

`getaddrinfo ENOTFOUND` is the application-level equivalent of `NXDOMAIN` — it is always DNS, never the network.

### 10d. `events.log` — the event stream

16.9 KB of events. Sorting and filtering:

```bash
kubectl get events -A --sort-by=.metadata.creationTimestamp
kubectl get events -A --sort-by=.lastTimestamp
kubectl get events -A --field-selector type=Warning
kubectl get events -A --field-selector reason=FailedScheduling
kubectl get events -A --field-selector involvedObject.name=webapp-mysql-785cd8f94-44469
```

### 10e. `kube-api-server.log` — 66 KB of apiserver output

The one to know how to read, because it is the only window into the control plane when the API is the problem:

```bash
# On the control plane node
sudo crictl logs $(sudo crictl ps -a | grep kube-apiserver | awk '{print $1}') | tail -100

# Or, if it is a static pod, its logs survive the pod
journalctl -u kubelet | grep apiserver

# Or, if the apiserver is up but misbehaving, get it from the API itself
kubectl -n kube-system logs deploy/kube-apiserver-controlplane 2>/dev/null
kubectl -n kube-system get pod -l component=kube-apiserver -o name
```

The four lines that matter in an apiserver log:

| Line | Meaning |
|---|---|
| `Starting a new server` | Normal startup — note the flags it echoes |
| `Authentication failed` / `Unable to authenticate the request` | A bad client cert, or a user that does not exist |
| `Forbidden: user "..." cannot get resource "..."` | RBAC — the request authenticated but was denied |
| `Failed to list *v1.Pod: ... connection refused` | etcd is unreachable |

### 10f. `networking.log` and `service.log` — the CNI and Service captures

```bash
# What the CNI put on the node
ip -br addr show
ip route show
iptables -t nat -L KUBE-SERVICES -n | head -20
iptables -t nat -L KUBE-NODEPORTS -n
cat /etc/cni/net.d/10-calico.conflist
ls /opt/cni/bin/

# What kube-proxy programmed
iptables-save | grep -A5 'KUBE-SVC'
ipvsadm -L -n        # if kube-proxy is in IPVS mode
```

### 10g. `top.log` — the metrics capture

```bash
kubectl top nodes
kubectl top pods -A
kubectl top pods -A --containers
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory
```

> **Exam note** — if `kubectl top` returns `error: Metrics API not available`, the causes in order are: (1)
> metrics-server is not installed, (2) metrics-server's pod is not `Running` (`kubectl -n kube-system get pods -l
> k8s-app=metrics-server`), (3) its `--kubelet-insecure-tls` / `--kubelet-preferred-address-types` flags are wrong, or
> (4) the `APIService` `v1beta1.metrics.k8s.io` is not `Available` (`kubectl get apiservice v1beta1.metrics.k8s.io`).
> Part I §1.8 has the full manifest.

---

## 6.11 Part VI self-check

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

## Part VII — Exam Drills & Mock Exams

**This part did not exist in the first build.** It comes from the CKA practice material that arrived with your
`basic-k8s` / `lab.txt` reference set: `last-try/questions.sh` (740 lines of worked exam questions), three mock exams
(`mock-exam-1/2/3.sh`), and the two scenario files (`last-try/scenarios-ingress.txt`,
`last-try/senarisos-np.txt`).

These are **full questions with your answers**, not concept notes. They are the closest thing you have to the real exam,
so they are worth more than any other single file in the repo. Work them under time pressure and check yourself against
the explanations.

**Convention in this part:** each drill is `Question → Commands → Manifest → Explanation → [Your note]`, with an
**Exam weight** line so you know what a miss costs you.

---

## 7.1 Drill 1 — Contexts and kubeconfig, without kubectl

**Exam weight:** Security / Troubleshooting (small, but a guaranteed free question)

**Question.** You have access to multiple clusters through kubectl contexts. Write all context names into
`/opt/course/1/contexts`. Next write a command that displays the current context into
`/opt/course/1/context_default_kubectl.sh` — the command must use `kubectl`. Finally write a second command doing the
same thing into `/opt/course/1/context_default_no_kubectl.sh`, but **without** `kubectl`.

```bash
kubectl config get-contexts --no-headers | awk '{print $1}' > /opt/course/1/contexts
kubectl config current-context > /opt/course/1/context_default_kubectl.sh
kubectl config view | grep "current-context" | awk '{print $2}' > /opt/course/1/context_default_no_kubectl.sh
```

**Explanation.** Three different techniques, and each one is the answer to a different variant of the question:

| Command | Why it works | When to use it |
|---|---|---|
| `kubectl config get-contexts --no-headers` | Drops the header line, so `$1` is the context name | When asked for a **list** |
| `kubectl config current-context` | Reads the merged kubeconfig and prints `current-context` | When `kubectl` is allowed |
| `kubectl config view \| grep current-context` | Reads the **file** directly, no API call | When `kubectl` is forbidden |

> **Exam note** — "without kubectl" almost always means `cat ~/.kube/config` plus a text filter. `grep` + `awk` is the
> safest pair. Alternatives that also work: `yq '.current-context' ~/.kube/config`, or
> `python3 -c "import yaml;print(yaml.safe_load(open('/root/.kube/config'))['current-context'])"`.

---

## 7.2 Drill 2 — Schedule only on control-plane nodes, without adding labels

**Exam weight:** Workloads & Scheduling

**Question.** Create a single Pod of image `httpd:2.4.41-alpine` in Namespace `default`. The Pod should be named `pod1`
and the container should be named `pod1-container`. This Pod should only be scheduled on **controlplane** nodes. **Do not
add new labels to any nodes.**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod1
  namespace: default
spec:
  containers:
    - name: pod1-container
      image: httpd:2.4.41-alpine
  nodeSelector:
    node-role.kubernetes.io/master: ""
```

**Alternative image:** `# Alt image: quay.io/pandeysp/nginx:latest`

**Explanation.** The trick is the phrase *"do not add new labels"*. The control-plane node **already** carries the label
`node-role.kubernetes.io/control-plane` (or, on older clusters, `node-role.kubernetes.io/master`) with an **empty
value**. So you select on the existing label rather than adding one:

```bash
kubectl get nodes --show-labels
# NAME           STATUS   ROLES           AGE   VERSION   LABELS
# controlplane   Ready    control-plane   22d   v1.29.0   ...,kubernetes.io/hostname=controlplane,node-role.kubernetes.io/control-plane=
```

Because the label has **no value**, you must write `key: ""` in `nodeSelector` — and you cannot use `nodeAffinity` with
`In` + an empty `values` list (that matches nothing).

**Alternative using nodeAffinity**, if you prefer:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node-role.kubernetes.io/control-plane
              operator: Exists
```

> **Exam note** — this exact "Exists vs In on a valueless label" distinction is the single most-tested affinity detail.
> See Part II §2.11.

---

## 7.3 Drill 3 — Scale Pods of an owner down to one

**Exam weight:** Workloads & Scheduling

**Question.** There are two Pods named `o3db-*` in Namespace `project-c13`. Management asked you to scale the Pods down
to one replica to save resources.

```bash
kubectl get pods -n project-c13
# NAME                       READY   STATUS    RESTARTS   AGE
# o3db-xxx-aaaaa             1/1     Running   0          5m
# o3db-xxx-bbbbb             1/1     Running   0          5m

kubectl get deploy,rs,sts -n project-c13      # find the OWNER
kubectl scale deployment o3db-xxx --replicas=1 -n project-c13
```

**Explanation.** The wording "scale the Pods" is deliberately misleading — you never scale pods. You find the controller
that owns them and scale *that*. The one-liner to see the owner:

```bash
kubectl get pods -n project-c13 -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind,OWNER_NAME:.metadata.ownerReferences[0].name
```

If the owner is a bare Pod with no controller, you must delete one manually — but that is not what "scale to one replica"
means, so there is always a controller.

> **Exam note** — `kubectl scale` works on Deployment, ReplicaSet, StatefulSet and ReplicationController. It does **not**
> work on a Pod.

---

## 7.4 Drill 4 — Liveness and readiness probes that depend on each other

**Exam weight:** Workloads & Scheduling (probes are a favourite)

**Question.** In Namespace `default`, create a Pod `ready-if-service-ready` of image `nginx:1.16.1-alpine`. Configure a
**LivenessProbe** which simply executes `true`. Also configure a **ReadinessProbe** which checks whether
`http://service-am-i-ready:80` is reachable — you can use `wget -T2 -O- http://service-am-i-ready:80`. Start the Pod and
confirm it isn't ready because of the ReadinessProbe.

Then create a second Pod `am-i-ready` of image `nginx:1.16.1-alpine` with label `id: cross-server-ready`. The existing
Service `service-am-i-ready` should now have that second Pod as endpoint. Now the first Pod should be ready — confirm.

Your answer, split into two manifests:

```yaml
# ready-if-service-ready.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ready-if-service-ready
spec:
  containers:
    - name: nginx
      image: nginx:1.16.1-alpine
      # Alt image: quay.io/pandeysp/nginx:latest
      livenessProbe:
        exec:
          command:
            - true
      readinessProbe:
        httpGet:
          path: /
          port: 80
          host: service-am-i-ready
        initialDelaySeconds: 5
        periodSeconds: 10
---
# am-i-ready.yaml
apiVersion: v1
kind: Pod
metadata:
  name: am-i-ready
  labels:
    id: cross-server-ready
spec:
  containers:
    - name: nginx
      image: nginx:1.16.1-alpine
      # Alt image: quay.io/pandeysp/nginx:latest
```

And the one-liner that makes the Service pick up the second Pod:

```bash
kubectl patch svc service-am-i-ready -p '{"spec":{"selector":{"id":"cross-server-ready"}}}' -n default
```

**Explanation.** Two independent lessons:

1. **`httpGet.host` is a real field.** Setting `host: service-am-i-ready` makes the kubelet resolve that name and send a
   `Host:` header accordingly — the probe then tests the *Service*, not the pod's own `/`. Without it the probe would
   test `localhost` and always succeed, and the whole point of the question is lost.
2. **A Service's endpoints come from its selector, not from anything else.** The existing Service already pointed at a
   selector that matched nothing. `kubectl patch` on `spec.selector` re-points it at the new pod. The pod's label
   `id: cross-server-ready` was chosen to match.

```bash
# Verify each step
kubectl get pod ready-if-service-ready
# NAME                    READY   STATUS    RESTARTS   AGE
# ready-if-service-ready  0/1     Running   0          20s      <-- Running but NOT Ready

kubectl get endpoints service-am-i-ready -n default
# NAME                 ENDPOINTS            AGE
# service-am-i-ready   10.244.192.5:80      2m30s     <-- now populated

kubectl get pod ready-if-service-ready
# NAME                    READY   STATUS    RESTARTS   AGE
# ready-if-service-ready  1/1     Running   0          2m        <-- now Ready
```

`last-try/liveness-probe.yaml` is your variant of the same question, using `exec` for both probes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: ready-if-service-ready
  name: ready-if-service-ready
spec:
  containers:
    - image: nginx:1.16.1-alpine
      imagePullPolicy: IfNotPresent
      livenessProbe:
        exec:
          command:
            - wget
            - -T2
            - -O-
            - http://service-am-i-ready:80
        failureThreshold: 3
        periodSeconds: 10
        successThreshold: 1
        timeoutSeconds: 1
      name: nginx
      readinessProbe:
        exec:
          command:
            - "true"
        failureThreshold: 3
        periodSeconds: 10
        successThreshold: 1
        timeoutSeconds: 1
```

Note the deliberate swap: here the **liveness** probe does the network check and the **readiness** probe is the trivial
`true`. That is the more realistic pairing — if the dependency is gone you want the container *restarted*, not merely
removed from the endpoints.

> **Exam note** — liveness failure = **restart** the container. Readiness failure = **remove from Service endpoints**
> (no restart). Getting these two backwards is the classic probe mistake. Also: the question asks you to *confirm* the
> pod is not ready — do `kubectl get pod` and `kubectl describe pod` and look at `READY 0/1` and the `Unhealthy` events.

---

## 7.5 Drill 5 — Sorting output with `--sort-by`

**Exam weight:** small, but pure command recall

**Question.** Write a command into `/opt/course/5/find_pods.sh` which lists all Pods sorted by their AGE
(`metadata.creationTimestamp`). Write a second command into `/opt/course/5/find_pods_uid.sh` which lists all Pods sorted
by field `metadata.uid`. Use kubectl sorting for both.

```bash
echo "kubectl get pods --all-namespaces --sort-by=.metadata.creationTimestamp" > /opt/course/5/find_pods.sh
echo "kubectl get pods --all-namespaces --sort-by=.metadata.uid" > /opt/course/5/find_pods_uid.sh
```

**Explanation.** `--sort-by` takes a **JSONPath expression** and sorts ascending. Note that `AGE` in `kubectl get pods`
is a *human* rendering of `creationTimestamp`, so sorting by `AGE` as a string does not work — you must sort by the
underlying field.

The sorting variants worth memorising:

```bash
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods --sort-by=.metadata.name
kubectl get pods --sort-by=.metadata.uid
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
kubectl get pv --sort-by=.spec.capacity.storage
kubectl get services --sort-by=.metadata.name
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get nodes --sort-by=.metadata.name
kubectl get pods -A --sort-by=.spec.nodeName

# Descending: pipe through tac
kubectl get pv --sort-by=.spec.capacity.storage | tac
```

Your `my-steps-etcd-systemctl.sh` uses exactly this pattern to produce a sorted list and post-process it:

```bash
kubectl get pv --sort-by '.spec.capacity.storage'
kubectl get pv --sort-by '.spec.capacity.storage' | awk '{print $1}'
kubectl get pv --sort-by '.spec.capacity.storage' | awk '{print $1}' > /home/cloud_user/pv_list.txt
```

> **Exam note** — when a question says "write a command into file X", the file must contain the command, and the command
> must be **runnable as-is**. Test it by `bash /opt/course/5/find_pods.sh` before moving on.

---

## 7.6 Drill 6 — PV + PVC + Deployment, correctly bound

**Exam weight:** Storage

**Question.** Create a new PersistentVolume named `safari-pv` with capacity 2Gi, accessMode `ReadWriteOnce`, hostPath
`/Volumes/Data` and **no storageClassName defined**. Next create a PVC named `safari-pvc` in Namespace `project-tiger`
requesting 2Gi, accessMode `ReadWriteOnce`, also **no storageClassName**. The PVC should bind to the PV correctly.
Finally create a Deployment `safari` in `project-tiger` mounting that volume at `/tmp/safari-data`, with Pods of image
`httpd:2.4.41-alpine`.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: safari-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /Volumes/Data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: safari-pvc
  namespace: project-tiger
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: safari
  namespace: project-tiger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: safari
  template:
    metadata:
      labels:
        app: safari
    spec:
      containers:
        - name: safari
          image: httpd:2.4.41-alpine
          # Alt image: quay.io/pandeysp/nginx:latest
          volumeMounts:
            - name: safari-vol
              mountPath: /tmp/safari-data
      volumes:
        - name: safari-vol
          persistentVolumeClaim:
            claimName: safari-pvc
```

**[Your note]** — the workflow advice that saves the most time, verbatim:

> *1. create pv from docs*
> *2. create pvc from docs be careful about the namespace*
> *3. for deployment DO NOT go to docs use this:*
> ```bash
> kubectl create deployment safari --image=httpd:2.4.41-alpine -n project-tiger -o yaml > my-dafari.yaml
> ```
> *this way you will not lose time for matching labels*

Exactly right: `kubectl create deployment ... --dry-run=client -o yaml` generates the selector and the pod-template labels
for you, so they match by construction. Hand-writing a Deployment is where selector/label mismatches — and the resulting
zero-endpoints Service — come from.

**The binding rules that make this work** (and that you noted separately in `31-pv-pvc-definition.sh`):

* accessModes must **match** (`ReadWriteOnce` ↔ `ReadWriteOnce`)
* `pv.capacity` must be **≥** `pvc.request`
* **no** `storageClassName` on either side — because if the PVC had one and the PV did not, the binder would refuse them

```bash
kubectl get pv safari-pv
# NAME       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
# safari-pv  2Gi        RWO            Retain           Bound    project-tiger/safari-pvc

kubectl get pvc safari-pvc -n project-tiger
# NAME        STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# safari-pvc  Bound    safari-pv  2Gi        RWO                           30s
```

---

## 7.7 Drill 7 — Metrics-server commands

**Exam weight:** Troubleshooting

**Question.** The metrics-server has been installed. Write the commands to show Nodes resource usage, and Pods and their
containers resource usage, into `/opt/course/7/node.sh` and `/opt/course/7/pod.sh`.

```bash
kubectl top nodes
kubectl top pods --all-namespaces
```

The complete set, from your `jsaon-path-examples.sh` and `practice-on-paper/practice-on-paper.sh`:

```bash
kubectl top nodes                          # all nodes
kubectl top node node01                    # one node
kubectl top pods                           # current namespace
kubectl top pods -A                        # all namespaces
kubectl top pod mypod -n myns              # one pod
kubectl top pods --containers              # per-container breakdown
kubectl top pods --sort-by=cpu             # sorted
kubectl top pods -n web --sort-by=cpu --selector app=auth     # filtered + sorted
kubectl top pods --no-headers | sort -k2 -h -r | head
```

That middle one — `kubectl top pods -n web --sort-by=cpu --selector app=auth` — is verbatim from
`practice-on-paper/practice-on-paper.sh` and is exactly the shape of an exam question.

```bash
kubectl logs data-handler -c proc -n backend | grep -i error > /k8s/0002/errors.txt
```

That second line from the same file shows the *filter-and-redirect* pattern: `kubectl logs` → `grep` → file. Exam
questions often ask for a specific subset of a log written to a specific path.

---

## 7.8 Drill 8 — Inventory how control-plane components are started

**Exam weight:** Cluster Architecture

**Question.** SSH into the controlplane node. Check how `kubelet`, `kube-apiserver`, `kube-scheduler`,
`kube-controller-manager` and `etcd` are started/installed. Also find the name of the DNS application and how it is
started/installed. Write findings into `/opt/course/8/controlplane-components.txt`, structured like:

```
kubelet: [TYPE]
kube-apiserver: [TYPE]
kube-scheduler: [TYPE]
kube-controller-manager: [TYPE]
etcd: [TYPE]
dns: [TYPE] [NAME]
```

Choices of `[TYPE]` are: `not-installed`, `process`, `static-pod`, `pod`.

Your answer template:

```bash
cat << EOF > /opt/course/8/controlplane-components.txt
kubelet: $kubelet_type
kube-apiserver: $kube_apiserver_type
kube-scheduler: $kube_scheduler_type
kube-controller-manager: $kube_controller_manager_type
etcd: $etcd_type
dns: $dns_type $dns_name
EOF
```

**How to actually determine each one** — this is the real content of the question:

```bash
ssh cluster1-controlplane1

# 1. kubelet is ALWAYS a systemd process on every node
systemctl status kubelet
ps -ef | grep /usr/bin/kubelet

# 2. The four control-plane components: check /etc/kubernetes/manifests FIRST
ls /etc/kubernetes/manifests/
# etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml
# → all four are static-pod

# 3. Cross-check with the API server's view
kubectl -n kube-system get pods -o wide
kubectl -n kube-system get pods | grep -E 'etcd|apiserver|scheduler|controller'

# 4. DNS: a Deployment + Service in kube-system
kubectl -n kube-system get deploy | grep -i dns
kubectl -n kube-system get pods -l k8s-app=kube-dns
# dns: pod coredns
```

**The correct answer for a standard kubeadm cluster:**

```
kubelet: process
kube-apiserver: static-pod
kube-scheduler: static-pod
kube-controller-manager: static-pod
etcd: static-pod
dns: pod coredns
```

> **Exam note** — the distinction being tested is *how* each thing runs, not whether it runs. A component in
> `/etc/kubernetes/manifests/` is a **static-pod** (kubelet-managed, no ReplicaSet, name suffixed with the node name).
> A component started by systemd is a **process**. A component you can only see through `kubectl` is a **pod**. And
> `not-installed` is a legitimate answer — on a worker node there is no apiserver/scheduler/controller-manager/etcd.

---

## 7.9 Drill 9 — Stop the scheduler, schedule manually, restart the scheduler

**Exam weight:** Workloads & Scheduling (a classic, and it appears in three separate places in your repo)

**Question.** SSH into `cluster2-controlplane1`. Temporarily stop the kube-scheduler, in a way that you can start it
again afterwards. Create a Pod `manual-schedule` of image `httpd:2.4-alpine`, confirm it's created but not scheduled on
any node. Now you're the scheduler and have all its power — manually schedule that Pod on `cluster2-controlplane1`. Make
sure it's running. Start the kube-scheduler again and confirm it's running correctly by creating a second Pod
`manual-schedule2` and checking it runs on `cluster2-node1`.

Your answer:

```bash
ssh cluster2-controlplane1
sudo systemctl stop kube-scheduler

kubectl run manual-schedule --image=httpd:2.4-alpine --restart=Never --dry-run=client -o yaml > manual-schedule.yaml
kubectl apply -f manual-schedule.yaml

kubectl patch pod manual-schedule -p '{"spec":{"nodeName":"cluster2-controlplane1"}}'
kubectl get pod manual-schedule -o wide

sudo systemctl start kube-scheduler

kubectl run manual-schedule2 --image=httpd:2.4-alpine --restart=Never --dry-run=client -o yaml > manual-schedule2.yaml
kubectl apply -f manual-schedule2.yaml
kubectl get pod manual-schedule2 -o wide
```

**[Your note]** — you also captured a non-working variant:

```bash
kubectl cordon kube-scheduler      # ← this is wrong; kube-scheduler is not a node
kubectl uncordon kube-scheduler
```

`cordon`/`uncordon` only operate on **Nodes**. `kubectl cordon kube-scheduler` either errors or, worse, silently does
nothing useful. The correct way to stop a control-plane component that runs as a static pod is to move its manifest out
of `/etc/kubernetes/manifests/`:

```bash
# Alternative that works on kubeadm (static-pod scheduler)
ssh cluster2-controlplane1
sudo mv /etc/kubernetes/manifests/kube-scheduler.yaml /root/
# kubelet notices the file is gone and stops the pod within seconds
kubectl -n kube-system get pods | grep scheduler      # gone

# ... do the manual-schedule drill ...

sudo mv /root/kube-scheduler.yaml /etc/kubernetes/manifests/
kubectl -n kube-system get pods | grep scheduler      # back
```

**Explanation.** Two things make the "manual schedule" trick work:

1. `spec.nodeName` is set by the **scheduler**, but it is *not* immutable the way most pod fields are — you can patch it
   on a pod that is still `Pending`. Once the pod is `Running` you cannot.
2. `kubectl patch pod ... -p '{"spec":{"nodeName":"..."}}'` works while the pod is unscheduled because the kubelet has
   not yet been told to do anything.

```bash
# Confirm the pod is unscheduled before you patch it
kubectl get pod manual-schedule
# NAME              READY   STATUS    RESTARTS   AGE
# manual-schedule   0/1     Pending   0          15s

kubectl describe pod manual-schedule | tail -5
# Events:
#   Warning FailedScheduling  15s   default-scheduler  0/3 nodes are available: ...
```

> **Exam note** — the event `Warning FailedScheduling ... no scheduler found` is your proof the scheduler is really
> stopped. If you see `Successfully assigned ...` the scheduler never stopped and you need to fix that first.

---

## 7.10 Drill 10 — ServiceAccount + Role + RoleBinding for Secrets and ConfigMaps only

**Exam weight:** Security

**Question.** Create a ServiceAccount `processor` in Namespace `project-hamster`. Create a Role and RoleBinding, both
named `processor` as well. These should allow the new SA to **only create Secrets and ConfigMaps** in that Namespace.

Your answer:

```bash
kubectl create namespace project-hamster
kubectl create serviceaccount processor -n project-hamster
kubectl create role processor --verb=create --resource=secrets,configmaps -n project-hamster
kubectl create rolebinding processor --role=processor --serviceaccount=project-hamster:processor -n project-hamster
```

**Explanation.** Every piece is imperative and every flag matters:

| Flag | Value | Why |
|---|---|---|
| `--verb=create` | exactly one verb | "only create" — adding `get`/`list` would violate the question |
| `--resource=secrets,configmaps` | comma-separated, no spaces | Both resource kinds in one rule |
| `--role=processor` | **Role**, not ClusterRole | Namespaced permission |
| `--serviceaccount=project-hamster:processor` | `namespace:name` | The `:` separator, not `/` |

```bash
# Verify with the SA's own identity
kubectl auth can-i create secrets -n project-hamster --as system:serviceaccount:project-hamster:processor
# yes
kubectl auth can-i create configmaps -n project-hamster --as system:serviceaccount:project-hamster:processor
# yes
kubectl auth can-i get secrets -n project-hamster --as system:serviceaccount:project-hamster:processor
# no
kubectl auth can-i create pods -n project-hamster --as system:serviceaccount:project-hamster:processor
# no
```

> **Exam note** — the `system:serviceaccount:<namespace>:<name>` form is the only correct way to impersonate a
> ServiceAccount with `--as`. Getting the namespace in there wrong is a very common mistake, and it makes `can-i` return
> `no` for everything.

---

## 7.11 Drill 11 — A DaemonSet that also runs on control-plane nodes

**Exam weight:** Workloads & Scheduling

**Question.** In Namespace `project-tiger`, create a DaemonSet `ds-important` with image `httpd:2.4-alpine` and labels
`id=ds-important` and `uuid=18426a0b-5f59-4e10-923f-c0e078e82462`. The Pods it creates should request 10 millicore CPU
and 10 mebibyte memory. The Pods of that DaemonSet should run on **all nodes, also controlplanes**.

Your answer:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ds-important
  namespace: project-tiger
  labels:
    id: ds-important
    uuid: 18426a0b-5f59-4e10-923f-c0e078e82462
spec:
  selector:
    matchLabels:
      id: ds-important
  template:
    metadata:
      labels:
        id: ds-important
        uuid: 18426a0b-5f59-4e10-923f-c0e078e82462
    spec:
      containers:
        - name: httpd
          image: httpd:2.4-alpine
          # Alt image: quay.io/pandeysp/nginx:latest
          resources:
            requests:
              cpu: "10m"
              memory: "10Mi"
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
```

`my-ds.yaml` at the repo root is the same object, using a `nodeSelector` instead:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
  name: ds-important
  namespace: project-tiger
spec:
  selector:
    matchLabels:
      app: ds-important
  template:
    metadata:
      labels:
        app: ds-important
    spec:
      containers:
        - image: httpd:2.4-alpine
          imagePullPolicy: IfNotPresent
          name: httpd
          resources:
            requests:
              cpu: 10m
              memory: 10Mi
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
```

**Explanation.** A control-plane node carries the taint `node-role.kubernetes.io/control-plane:NoSchedule`, so by default
a DaemonSet will **not** place a pod there. Three ways to fix it:

| Approach | How |
|---|---|
| `nodeSelector` on the valueless label | Selects **only** control-plane nodes — wrong here, because you want all nodes |
| `tolerations` with `operator: Exists` | Tolerates the taint; the DaemonSet still lands on **every** node |
| `kubectl taint node <cp> node-role.kubernetes.io/control-plane:NoSchedule-` | Removes the taint entirely — also valid |

For "run on all nodes, **also** controlplanes", the correct answer is a **toleration**, not a nodeSelector. A
`nodeSelector` on `node-role.kubernetes.io/control-plane: ""` restricts the DaemonSet to control-plane nodes **only**,
which is the opposite of what was asked. The questions in your repo mix both intentions, so read the wording carefully.

> **Exam note** — a DaemonSet has **no** `spec.replicas`. Derive it from a Deployment manifest and delete `replicas`,
> `strategy` and `status` (Part II §2.7).

---

## 7.12 Drill 12 — One pod per node with a Deployment and `topologySpreadConstraints`

**Exam weight:** Workloads & Scheduling

**Question.** There should be only ever one Pod of that Deployment running on one worker node. Two worker nodes exist:
`cluster1-node1` and `cluster1-node2`. Because the Deployment has three replicas the result should be that on both nodes
one Pod is running. The third Pod won't be scheduled, unless a new worker node will be added. Use
`topologyKey: kubernetes.io/hostname`.

Your answer, with the two fields your version was missing:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-important
  namespace: project-tiger
spec:
  replicas: 3
  selector:
    matchLabels:
      id: very-important
  template:
    metadata:
      labels:
        id: very-important
    spec:
      containers:
        - name: container1
          image: nginx:1.17.6-alpine
          # Alt image: quay.io/pandeysp/nginx:latest
        - name: container2
          image: google/pause
  strategy:
    type: Recreate
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: "kubernetes.io/hostname"
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          id: very-important
```

**Explanation.** `topologySpreadConstraints` is the modern answer to "spread replicas across failure domains":

| Field | Meaning |
|---|---|
| `maxSkew` | Maximum allowed difference in pod count between any two topology domains. `1` = perfectly even. |
| `topologyKey` | The node label defining a domain — `kubernetes.io/hostname` (a node), `topology.kubernetes.io/zone` (an AZ) |
| `whenUnsatisfiable` | `DoNotSchedule` (hard) or `ScheduleAnyway` (soft) |
| `labelSelector` | Which pods are counted — **must** be set, or the constraint does nothing |

Two things your version is missing, and both matter:

1. **`labelSelector` is required.** Without it the constraint matches nothing and the Deployment schedules all three pods
   wherever it likes.
2. **`whenUnsatisfiable` should be `DoNotSchedule`.** Without it the field defaults to `DoNotSchedule` anyway, but being
   explicit is safer.

Also note `strategy.type: Recreate` — with a `DoNotSchedule` spread constraint, a `RollingUpdate` can deadlock (the surge
pod cannot be placed anywhere), so `Recreate` is the right pairing here.

```bash
# Verify
kubectl get pods -n project-tiger -o wide -l id=very-important
# NAME                                READY   STATUS    RESTARTS   AGE   NODE
# deploy-important-xxx-aaaaa          1/1     Running   0          60s   cluster1-node1
# deploy-important-xxx-bbbbb          1/1     Running   0          60s   cluster1-node2
# deploy-important-xxx-ccccc          0/1     Pending   0          60s   <none>

kubectl describe pod deploy-important-xxx-ccccc -n project-tiger | tail -3
# Events:
#   Warning  FailedScheduling  0/3 nodes are available: 3 node(s) didn't match pod topology spread constraints.
```

That event message — `didn't match pod topology spread constraints` — is the confirmation that the constraint is doing
its job.

---

## 7.13 Drill 13 — Three containers, a shared `emptyDir`, and the Downward API

**Exam weight:** Workloads & Scheduling (combines three competencies in one question)

**Question.** Create a Pod `multi-container-playground` in Namespace `default` with three containers named `c1`, `c2`
and `c3`. There should be a volume attached to that Pod and mounted into **every** container, but the volume shouldn't be
persisted or shared with other Pods.

* `c1`: image `nginx:1.17.6-alpine`, and have the name of the node where its Pod is running available as env var
  `MY_NODE_NAME`.
* `c2`: image `busybox:1.31.1`, write the output of `date` every second into the shared volume in file `date.log`. Use
  `while true; do date >> /your/vol/path/date.log; sleep 1; done`.
* `c3`: image `busybox:1.31.1`, constantly send the content of `date.log` from the shared volume to stdout. Use
  `tail -f /your/vol/path/date.log`.

Check the logs of `c3` to confirm correct setup.

Your answer:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-playground
  namespace: default
spec:
  containers:
    - name: c1
      image: nginx:1.17.6-alpine
      # Alt image: quay.io/pandeysp/nginx:latest
      env:
        - name: MY_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
      volumeMounts:
        - name: shared-volume
          mountPath: /shared
    - name: c2
      image: busybox:1.31.1
      # Alt image: quay.io/pandeysp/busybox:v1
      command: ["/bin/sh", "-c", "while true; do date >> /shared/date.log; sleep 1; done"]
      volumeMounts:
        - name: shared-volume
          mountPath: /shared
    - name: c3
      image: busybox:1.31.1
      # Alt image: quay.io/pandeysp/busybox:latest
      command: ["/bin/sh", "-c", "tail -f /shared/date.log"]
      volumeMounts:
        - name: shared-volume
          mountPath: /shared
  volumes:
    - name: shared-volume
      emptyDir: {}
```

**Explanation.** Three mechanisms in one manifest:

1. **"shouldn't be persisted or shared with other Pods"** → `emptyDir: {}`. It lives exactly as long as the pod, is
   created on the node, and is unique to the pod. `hostPath` would be shared with other pods and would survive; a PVC
   would outlive the pod.
2. **The Downward API** → `fieldRef` with `fieldPath: spec.nodeName`. Note it is `spec.nodeName`, **not**
   `metadata.nodeName` and **not** `status.hostIP`. Valid `fieldPath` values are `metadata.name`, `metadata.namespace`,
   `metadata.labels['<key>']`, `metadata.annotations['<key>']`, `spec.nodeName`, `spec.serviceAccountName`,
   `status.hostIP`, `status.podIP`.
3. **Producer/consumer over a shared volume** → `c2` appends, `c3` tails. The two mountPaths must be identical, which is
   the same rule you noted in `acg-multic-np.yaml`.

```bash
# The confirmation step the question explicitly asks for
kubectl logs multi-container-playground -c c3
# Tue Sep 27 08:30:01 UTC 2026
# Tue Sep 27 08:30:02 UTC 2026

kubectl exec multi-container-playground -c c1 -- printenv MY_NODE_NAME
# cluster1-node1
```

> **Exam note** — in a multi-container pod, `kubectl logs <pod>` defaults to the **first** container and prints a
> `Defaulted container "c1" out of: c1, c2, c3` line. Always pass `-c` when the question names a specific container.

---

## 7.14 Drill 14 — Cluster inventory, in a structured file

**Exam weight:** Cluster Architecture

**Question.** Find out about cluster `k8s-c1-H`:
1. How many controlplane nodes are available?
2. How many worker nodes are available?
3. What is the Service CIDR?
4. Which Networking (CNI Plugin) is configured and where is its config file?
5. Which suffix will static pods have that run on `cluster1-node1`?

Write answers into `/opt/course/14/cluster-info`, structured as `1: [ANSWER]` … `5: [ANSWER]`.

Your answer:

```bash
# 1. Get the number of control plane nodes
controlplane_count=$(kubectl get nodes --selector=node-role.kubernetes.io/control-plane --no-headers | wc -l)

# 2. Get the number of worker nodes
worker_count=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' --no-headers | wc -l)

# 3. Get the Service CIDR
service_cidr=$(kubectl get configmap -n kube-system kube-proxy -o=jsonpath='{.data.kubeconfig}' | grep service-cluster-ip-range | cut -d' ' -f6)

# 4. Get the Networking (CNI Plugin) and its config file location
cni_plugin=$(kubectl get pod -n kube-system -l k8s-app=kube-proxy -o=jsonpath='{.items[0].spec.containers[0].args[2]}' | cut -d= -f2)
cni_config=$(kubectl get configmap -n kube-system $cni_plugin -o=jsonpath='{.data.\.conf}')
# /etc/cni/net.d/

# 5. Get the suffix for static pods on cluster1-node1
static_pod_suffix=$(kubectl get node cluster1-node1 -o=jsonpath='{.metadata.annotations.\.static-pod-hostname-suffix}')

cat << EOF > /opt/course/14/cluster-info
1: $controlplane_count
2: $worker_count
3: $service_cidr
4: $cni_plugin $cni_config
5: $static_pod_suffix
EOF
```

**Explanation, question by question:**

**Q1/Q2 — counting nodes by role.**

```bash
kubectl get nodes --selector=node-role.kubernetes.io/control-plane --no-headers | wc -l
kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' --no-headers | wc -l
```

Note the **single quotes** around `!node-role...` — `!` is a bash history-expansion character and an unquoted `!` will
either error or do something surprising.

**Q3 — Service CIDR.** Three sources, in order of reliability:

```bash
# a) From kube-proxy's kubeconfig (what your answer uses)
kubectl -n kube-system get cm kube-proxy -o jsonpath='{.data.kubeconfig}' | grep service-cluster-ip-range

# b) From the apiserver's own flags (most authoritative)
kubectl -n kube-system describe pod kube-apiserver-$(hostname) | grep -i service-cluster-ip-range
#     - --service-cluster-ip-range=10.96.0.0/12

# c) From kubeadm's config
kubectl -n kube-system get cm kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' | grep -A2 serviceSubnet
```

**Q4 — the CNI plugin and its config.** The CNI conflist lives on **every node** at `/etc/cni/net.d/`:

```bash
ssh cluster1-node1
ls /etc/cni/net.d/
# 10-flannel.conflist
cat /etc/cni/net.d/10-flannel.conflist
```

That file (your repo has `Networking/gce/10-flannel.conflist.json` and
`Networking/kubeadmin/10-calico.conflist.json`) is the ground truth for which plugin is installed.

**Q5 — static pod suffix.** The suffix is the **node name**. A static pod named `my-pod` on `cluster1-node1` appears as
`my-pod-cluster1-node1` in the API server.

```bash
kubectl get pods -A -o wide | grep -E '^kube-system.*-(cluster1-node1)$'
kubectl get node cluster1-node1 -o jsonpath='{.metadata.annotations}'
```

> **Exam note** — the mirror pod's name is `<static-pod-name>-<node-name>`, and its `ownerReferences` point to a Node,
> not a controller. That is how you tell a static pod from a normal one in a list.

---

## 7.15 Drill 15 — Events: delete a Pod vs kill its container

**Exam weight:** Troubleshooting (a genuinely subtle question)

**Question.** Write a command into `/opt/course/15/cluster_events.sh` showing the latest events in the whole cluster,
ordered by time. Now delete the kube-proxy Pod running on `cluster2-node1` and write the events this caused into
`/opt/course/15/pod_kill.log`. Finally **kill the containerd container** of the kube-proxy Pod on `cluster2-node1` and
write the events into `/opt/course/15/container_kill.log`. Do you notice differences in the events both actions caused?

Your answer:

```bash
echo "kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces" > /opt/course/15/cluster_events.sh

kubectl delete pod -n kube-system \
  $(kubectl get pods -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[?(@.spec.nodeName=="cluster2-node1")].metadata.name}') \
  > /opt/course/15/pod_kill.log

docker ps -q --filter "name=k8s_kube-proxy_kube-proxy-cluster2-node1" | xargs docker kill > /opt/course/15/container_kill.log
```

**Explanation — this is the actual content of the question.** The two actions produce *different* event trails, and
noticing why is the point:

| Action | What happens | Events you see |
|---|---|---|
| `kubectl delete pod` | The API server deletes the Pod object. The kubelet notices its pod is gone and **stops the container gracefully** (SIGTERM, then SIGKILL after the grace period). The DaemonSet controller then creates a **new** Pod. | `Killing`, `Deleted` (from kubelet), `SuccessfulCreate` (from daemonset-controller) |
| `docker kill` / `crictl rm` | The **container** dies underneath the kubelet. The Pod object still exists. The kubelet's sync loop sees the container missing and **restarts it inside the same Pod**. | `BackOff`/`Restarted`/`Created`/`Started` (from kubelet), **no** `SuccessfulCreate`, **no** new Pod |

So: deleting the pod gives you a **new pod with a new name and a new UID**; killing the container gives you the **same
pod with an incremented `RESTARTS`**.

```bash
# Verify the difference
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
# after delete: a pod with a NEW name
# after kill:    the SAME name, RESTARTS 1

kubectl get events -n kube-system --field-selector involvedObject.name=<pod> --sort-by=.lastTimestamp
```

> **Exam note** — the modern equivalent of `docker kill` on a containerd cluster is
> `sudo crictl stop <container-id>` or `sudo crictl rm <container-id>`. Also note the JSONPath filter
> `{.items[?(@.spec.nodeName=="cluster2-node1")].metadata.name}` — that is how you select "the pod of a DaemonSet that
> runs on node X" in one line, and it is worth memorising.

---

## 7.16 Drill 16 — Namespaced resources, and the namespace with the most Roles

**Exam weight:** Security / small

**Question.** Write the names of all namespaced Kubernetes resources into `/opt/course/16/resources.txt`. Find the
`project-*` Namespace with the highest number of Roles defined in it and write its name and amount of Roles into
`/opt/course/16/crowded-namespace.txt`.

Your answer:

```bash
kubectl api-resources --namespaced=true --verbs=list -o name | cut -d "/" -f 2 > /opt/course/16/resources.txt

crowded_namespace=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep '^project-' \
  | while read ns; do echo "$(kubectl get roles -n $ns --no-headers | wc -l) $ns"; done \
  | sort -nr | head -n 1)

echo $crowded_namespace > /opt/course/16/crowded-namespace.txt
```

**Explanation.** Three reusable techniques:

1. **`kubectl api-resources --namespaced=true -o name`** is the canonical list of namespaced resource kinds. The
   `-o name` output is `<plural>.<group>`, so the `cut -d "/" -f 2` in your command is a no-op; the important flags are
   `--namespaced=true` and `--verbs=list`.
2. **`{range .items[*]}...{end}`** in jsonpath is how you emit one item per line without JSON delimiters.
3. **`sort -nr | head -n 1`** finds the maximum of a "count name" list. The count must come **first** for `sort -n` to
   work on it.

> **Exam note** — `--namespaced=false` is the complement and is the list of cluster-scoped resources (nodes, PVs,
> clusterroles, namespaces…). See Part V §5.4.

---

## 7.17 Drill 17 — Find the containerd container behind a Pod

**Exam weight:** Troubleshooting

**Question.** In Namespace `project-tiger` create a Pod `tigers-reunite` of image `httpd:2.4.41-alpine` with labels
`pod=container` and `container=pod`. Find out on which node the Pod is scheduled. SSH into that node and find the
containerd container belonging to that Pod. Using `crictl`: write the ID of the container and the `info.runtimeType` into
`/opt/course/17/pod-container.txt`. Write the logs of the container into `/opt/course/17/pod-container.log`.

Your answer:

```bash
kubectl run tigers-reunite --image=httpd:2.4.41-alpine --labels=pod=container,container=pod -n project-tiger

node=$(kubectl get pod tigers-reunite -n project-tiger -o=jsonpath='{.spec.nodeName}')
ssh $node

container_id=$(crictl ps | grep tigers-reunite | awk '{print $1}')
runtime_type=$(crictl inspect $container_id | grep 'info\.runtimeType' | awk -F '"' '{print $4}')

echo "Container ID: $container_id" > /opt/course/17/pod-container.txt
echo "Runtime Type: $runtime_type" >> /opt/course/17/pod-container.txt

crictl logs $container_id > /opt/course/17/pod-container.log
exit
```

**Explanation.** The chain from pod to container:

```bash
# 1. Which node?
kubectl get pod tigers-reunite -n project-tiger -o wide

# 2. Which sandbox (pod) on that node?
sudo crictl pods | grep tigers-reunite
# POD ID       CREATED      STATE   NAME            NAMESPACE   ATTEMPT
# 8beb5c9b...  2 minutes ago Ready   tigers-reunite  project-tiger  0

# 3. Which container in that sandbox?
sudo crictl ps | grep tigers-reunite
# CONTAINER ID   IMAGE                    CREATED         STATE     NAME              ATTEMPT
# 3cba56c2...    httpd:2.4.41-alpine      2 minutes ago   Running   tigers-reunite    0

# 4. Its runtime type
sudo crictl inspect 3cba56c2... | grep 'info.runtimeType'
#     "runtimeType": "io.containerd.runc.v2",
```

`crictl` needs the runtime endpoint (Part VI §6.3):

```bash
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```

> **Exam note** — `crictl` is your only window into containers when the API server is down. The four commands to know:
> `crictl ps -a`, `crictl logs <id>`, `crictl inspect <id>`, `crictl pods`. Note also that `crictl logs` needs the
> **container** id, not the pod id.

---

## 7.18 Drill 18 — A kubelet that is not running

**Exam weight:** Troubleshooting

**Question.** There seems to be an issue with the kubelet not running on `cluster3-node1`. Fix it and confirm the cluster
has node `cluster3-node1` available in `Ready` state afterwards. You should be able to schedule a Pod on `cluster3-node1`
afterwards. Write the reason of the issue into `/opt/course/18/reason.txt`.

Your answer:

```bash
kubectl describe node cluster3-node1 > /opt/course/18/reason.txt
# ... then fix based on what the description says ...
kubectl get nodes
```

`last-try/gb-trouble-shooting.sh` documents the same class of failure in far more detail, and it is the best worked
example in your whole repo:

```
########################### Node Not ready ############################

kubectl describe node node-name
# check at condition pod
sudo journalctl -u kubelet
sudo systemctl status kubelet   # it showed inactive and dead
kubectl get nodes -o wide
hostname
ssh cloud_user@10.0.1.103
sudo -i
  systemctl status kubelet
  sudo systemctl enable kubelet
  sudo systemctl start kubelet
  systemctl status kubelet
  exit
```

**Explanation.** The diagnostic ladder, in order:

```bash
# 1. What does the API server think?
kubectl get nodes -o wide
# NAME             STATUS     AGE   VERSION
# cluster3-node1   NotReady   22d   v1.29.0

# 2. What does the node think about itself?
ssh cluster3-node1
systemctl status kubelet
#  ● kubelet.service - kubelet: The Kubernetes Node Agent
#     Loaded: loaded (...; disabled; preset: enabled)
#     Active: inactive (dead)

# 3. Why?
journalctl -u kubelet -n 50 --no-pager
```

The **three most common root causes**, in the order you should check them:

| Symptom in `systemctl status` | Cause | Fix |
|---|---|---|
| `inactive (dead)`, `disabled` | The service is not enabled and did not survive a reboot | `systemctl enable --now kubelet` |
| `failed (Result: exit-code)` | A config error — bad `--config`, missing certs, wrong runtime socket | Read `journalctl -u kubelet`, fix the flag |
| `active (running)` but node `NotReady` | The CNI is down, or the node ran out of disk/memory/PIDs | Check `NetworkUnavailable`, `DiskPressure`, `MemoryPressure`, `PIDPressure` |

```bash
# The full fix sequence
ssh cluster3-node1
sudo systemctl enable kubelet
sudo systemctl start kubelet
systemctl status kubelet          # active (running)

# Back on the control plane
kubectl get nodes
# NAME             STATUS   AGE   VERSION
# cluster3-node1   Ready    22d   v1.29.0

# The confirmation the question asks for
kubectl run test-pod --image=nginx --restart=Never --node-name=cluster3-node1
# Alt image: quay.io/pandeysp/nginx:latest
kubectl get pod test-pod -o wide
# NAME       READY   STATUS    RESTARTS   AGE   NODE
# test-pod   1/1     Running   0          20s   cluster3-node1
```

> **Exam note** — the reason file should contain the **root cause**, not the whole `describe` dump. `systemctl status`
> showing `inactive (dead)` and `disabled` is the answer; the fix is `systemctl enable --now kubelet`.

---

## 7.19 Drill 19 — A Pod that cannot reach a Service in another namespace

**Exam weight:** Troubleshooting / Networking (the highest-yield troubleshooting pattern in your repo)

**Question (from `gb-trouble-shooting.sh`).** A busybox pod cannot reach the db.

```bash
kubectl get pods --all-namespaces

kubectl describe pod web-consumer-84fc79d94d-qtjbh -n web
kubectl logs pod web-consumer-84fc79d94d-qtjbh -n web

# could not resolve the auth-db (assume that auth-db is a service we need to find where it is in the cluster)
kubectl exec web-consumer-84fc79d94d-qtjbh -n web -- curl auth-db     # (not reachable)
kubectl get pods -n kube-system -l k8s-app=kube-dns                  # (dns is happy)

# where is the service?
kubectl get svc --all-namespaces | grep auth-db
# it is in the data namespace, another namespace, and not using its fully qualified name
# replaced it with the fully qualified name: auth-db.data.svc.cluster.local
kubectl edit deployment web-consumer -n web
#  - command:
#    - sh
#    - -c
#    - while true; do curl auth-db.data.svc.cluster.local; sleep 5; done
#
# happy
```

**Explanation.** This is the single most common "networking is broken" answer on the CKA, and your note states it
perfectly: **the Service exists, in a different namespace, and the pod is using the short name.**

The DNS search path in a pod is:

```
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

So `auth-db` is tried as `auth-db.web.svc.cluster.local` (the pod's own namespace) first, then
`auth-db.svc.cluster.local`, then `auth-db.cluster.local`. If the Service lives in `data`, **none** of those resolve and
you get `could not resolve host`.

The three fixes, best first:

```bash
# 1. Use the FQDN in the app's config (what your answer does)
auth-db.data.svc.cluster.local

# 2. Use the namespace-qualified short form — also works, because .svc.cluster.local is in the search path
auth-db.data

# 3. Create a Service with the same name in the pod's own namespace (an ExternalName Service)
kubectl create serviceexternalname auth-db --external-name=auth-db.data.svc.cluster.local -n web
```

```bash
# Verify each link in the chain
kubectl get svc -A | grep auth-db                       # does it exist, and where?
kubectl get endpoints auth-db -n data                  # does it have endpoints?
kubectl -n web exec deploy/web-consumer -- nslookup auth-db.data.svc.cluster.local
kubectl -n web exec deploy/web-consumer -- wget -O- auth-db.data.svc.cluster.local
```

> **Exam note** — before you touch anything, run these four commands in order: `kubectl get svc -A | grep <name>`,
> `kubectl get endpoints <name> -n <ns>`, `kubectl exec <pod> -- nslookup <name>`,
> `kubectl get networkpolicy -A`. They resolve roughly 90% of CKA networking questions.

---

## 7.20 Drill 20 — Mount an existing Secret read-only, plus env vars from a second Secret

**Exam weight:** Security

**Question.** In a new Namespace `secret`, create a Pod `secret-pod` of image `busybox:1.31.1` which should keep running
for some time. There is an existing Secret at `/opt/course/19/secret1.yaml`; create it in the Namespace `secret` and mount
it read-only into the Pod at `/tmp/secret1`. Create a new Secret in Namespace `secret` called `secret2` which should
contain `user=user1` and `pass=1234`. These entries should be available inside the Pod's container as environment
variables `APP_USER` and `APP_PASS`.

Your answer:

```bash
kubectl create namespace secret
kubectl apply -f /opt/course/19/secret1.yaml -n secret

kubectl create secret generic secret2 --from-literal=APP_USER=user1 --from-literal=APP_PASS=1234 -n secret

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
  namespace: secret
spec:
  containers:
    - name: busybox
      image: busybox:1.31.1
      # Alt image: quay.io/pandeysp/busybox:v1
      command: ["sleep", "3600"]        # keep the container running
      volumeMounts:
        - name: secret1-volume
          mountPath: "/tmp/secret1"
          readOnly: true
      envFrom:
        - secretRef:
            name: secret2
  volumes:
    - name: secret1-volume
      secret:
        secretName: secret1
EOF

kubectl get pods -n secret
kubectl describe pod secret-pod -n secret
```

**Explanation.** Note two details that are easy to get wrong:

1. **`readOnly: true` is not in your volumeMount.** The question says "mount it **read-only**", so add it. Without it the
   mount is read-write, even though the projected secret file is `defaultMode: 420` = `0644`; the `readOnly` flag is
   still what the question is looking for.
2. **`envFrom` vs `env`.** `envFrom.secretRef` injects **every key** of the Secret as an env var. That is why the Secret
   must be created with the keys `APP_USER` and `APP_PASS` directly — the *keys become the variable names*. If the
   question had said "the Secret contains `user` and `pass`, exposed as `APP_USER` and `APP_PASS`", you would need
   `env[].valueFrom.secretKeyRef` to rename them:

```yaml
env:
  - name: APP_USER
    valueFrom:
      secretKeyRef: {name: secret2, key: user}
  - name: APP_PASS
    valueFrom:
      secretKeyRef: {name: secret2, key: pass}
```

Your `secre-as-volatile-volumes` capture is the same pattern, with the annotation about how to build the Secret:

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: specialofday
data:
  entree: bWVhdGxvYWY=
immutable: true

---
apiVersion: v1
kind: Pod
metadata:
  name: foodie
spec:
  volumes:
    - name: specialofday-secret
      secret:
        secretName: specialofday
  containers:
    - name: dotfile-test-container
      image: nginx
      # Alt image: quay.io/pandeysp/nginx:latest
      volumeMounts:
        - name: specialofday-secret
          readOnly: true
          mountPath: "/food/"
```

**[Your note]** — verbatim, and it is the exact lesson:

> *first I created a secret using the spec file in quick reference also getting help from the cube CTL help but the thing
> is that everything is as it should be name of the secret key of the secret but before entering the value we have to
> encode the value of the secret with base 64 using `echo -n` and pipe `base64` then just create the yaml of the secret
> and apply it. second we want to make the pod to use this secret: kubernetes does this as a volume and it's a volatile
> one so we just create a volume, reference the secret name and mount a directory in the container and then in the
> volumeMounts we use it. all of these are available at the quick reference documentation*

Also note **`immutable: true`** — once set, the Secret's `data` cannot be changed; you must delete and recreate. Useful
for secrets that never rotate.

> **Exam note** — the verification step is
> `kubectl exec secret-pod -n secret -- ls -la /tmp/secret1` and
> `kubectl exec secret-pod -n secret -- printenv APP_USER APP_PASS`. Doing the verification is often worth a point on its
> own.

---

## 7.21 Drill 21 — Static pod + NodePort Service with endpoints

**Exam weight:** Workloads / Services / Troubleshooting

**Question.** Create a Static Pod named `my-static-pod` in Namespace `default` on `cluster3-controlplane1`. It should be
of image `nginx:1.16-alpine` and have resource requests for 10m CPU and 20Mi memory. Then create a NodePort Service
`static-pod-service` which exposes that static Pod on port 80 and check if it has Endpoints and if it's reachable through
the `cluster3-controlplane1` internal IP address.

Your answer:

```bash
cat <<EOF > my-static-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-static-pod
  namespace: default
  labels:
    run: my-static-pod
spec:
  containers:
    - name: nginx
      image: nginx:1.16-alpine
      # Alt image: quay.io/pandeysp/nginx:latest
      resources:
        requests:
          cpu: "10m"
          memory: "20Mi"
EOF

scp my-static-pod.yaml cluster3-controlplane1:/etc/kubernetes/manifests/

kubectl expose pod my-static-pod-cluster3-controlplane1 --type=NodePort --port=80 --name=static-pod-service

kubectl get endpoints static-pod-service -n default
curl <internal-IP>:$(kubectl get svc static-pod-service -n default -o=jsonpath='{.spec.ports[0].nodePort}')
```

**Explanation.** The subtlety is the **name of the mirror pod**. The API server shows the static pod as
`my-static-pod-cluster3-controlplane1`, but the kubelet creates the container from the manifest named `my-static-pod`.
`kubectl expose pod my-static-pod` will fail because no pod by that name exists in the API server's view.

```bash
# Find the real name
kubectl get pods -o wide | grep static
# NAME                               READY   STATUS    RESTARTS   AGE   NODE
# my-static-pod-cluster3-controlplane1  1/1  Running   0          30s   cluster3-controlplane1

# Expose by the mirror name
kubectl expose pod my-static-pod-cluster3-controlplane1 --type=NodePort --port=80 --name=static-pod-service
```

And the verification chain:

```bash
kubectl get svc static-pod-service
# NAME                 TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
# static-pod-service   NodePort   10.96.249.7   <none>        80:31234/TCP   30s

kubectl get endpoints static-pod-service
# NAME                 ENDPOINTS           AGE
# static-pod-service   10.244.192.7:80     30s        <-- non-empty = the selector matches

kubectl get node cluster3-controlplane1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'
# 10.0.1.101

curl 10.0.1.101:31234
```

> **Exam note** — an empty `ENDPOINTS` column means the Service's selector does not match the pod's labels. A static pod
> gets its labels from the manifest, so if you did not set any, `kubectl expose` generates a selector that matches
> nothing. Always set labels explicitly on a static pod you intend to expose.

---

## 7.22 Drill 22 — Certificate expiration, two ways

**Exam weight:** Security

**Question.** Check how long the kube-apiserver server certificate is valid on `cluster2-controlplane1`. Do this with
openssl or cfssl. Write the expiration date into `/opt/course/22/expiration`. Also run the correct kubeadm command to
list the expiration dates and confirm both methods show the same date. Write the correct kubeadm command that would
renew the apiserver server certificate into `/opt/course/22/kubeadm-renew-certs.sh`.

Your answer:

```bash
openssl x509 -enddate -noout -in /etc/kubernetes/pki/apiserver.crt > /opt/course/22/expiration

kubeadm alpha certs check-expiration

cat <<EOF > /opt/course/22/kubeadm-renew-certs.sh
#!/bin/bash
kubeadm alpha certs renew apiserver
systemctl restart kubelet
EOF
chmod +x /opt/course/22/kubeadm-renew-certs.sh
```

**Explanation.** Two independent methods, and the exam wants you to show they agree:

```bash
# Method 1: openssl
ssh cluster2-controlplane1
openssl x509 -enddate -noout -in /etc/kubernetes/pki/apiserver.crt
# notAfter=Apr  4 13:46:33 2034 GMT

# Method 2: kubeadm
kubeadm alpha certs check-expiration
# CERTIFICATE                RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
# admin.conf                 9y              ca                      no
# apiserver                  9y              ca                      no
# apiserver-etcd-client      9y              etcd-ca                 no
# apiserver-kubelet-client   9y              ca                      no
# controller-manager.conf    9y              ca                      no
# front-proxy-client         9y              front-proxy-ca          no
# scheduler.conf             9y              ca                      no
# etcd-healthcheck-client    9y              etcd-ca                 no
# etcd-peer                  9y              etcd-ca                 no
# etcd-server                9y              etcd-ca                 no
```

**Important correction:** in current kubeadm the subcommand is **`kubeadm certs`**, not `kubeadm alpha certs` — the
`alpha` prefix was removed when the feature graduated. Both forms:

```bash
kubeadm certs check-expiration
kubeadm certs renew apiserver
kubeadm certs renew all
```

After renewing, the component that uses the cert must be restarted. For a **static pod** (apiserver, scheduler,
controller-manager, etcd) that means deleting the pod so the kubelet recreates it from the manifest:

```bash
kubeadm certs renew apiserver
kubectl -n kube-system delete pod kube-apiserver-$(hostname)
# or, equivalently, restart the kubelet — it re-reads the manifests
systemctl restart kubelet
```

> **Exam note** — the kubelet's own client and serving certs are rotated **automatically** (`rotateCertificates: true` in
> `/var/lib/kubelet/config.yaml`, which you captured in Part I §1.6). The control-plane certs are not — they are valid
> for years by default, which is why `check-expiration` shows `9y`.

---

## 7.23 Drill 23 — kubelet client vs server certificate

**Exam weight:** Security (subtle, and frequently misread)

**Question.** Node `cluster2-node1` was added using kubeadm and TLS bootstrapping. Find the "Issuer" and "Extended Key
Usage" values of the `cluster2-node1`:
* kubelet **client** certificate — the one used for outgoing connections to the kube-apiserver
* kubelet **server** certificate — the one used for incoming connections from the kube-apiserver

Write the information into `/opt/course/23/certificate-info.txt`. Compare the Issuer and Extended Key Usage fields of both
certificates and make sense of these.

Your answer:

```bash
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -issuer -text \
  | grep -E "Issuer:|Extended Key Usage" > /opt/course/23/certificate-info.txt

echo "----------------------------------------" >> /opt/course/23/certificate-info.txt

openssl x509 -in /var/lib/kubelet/pki/kubelet-server-current.pem -noout -issuer -text \
  | grep -E "Issuer:|Extended Key Usage" >> /opt/course/23/certificate-info.txt
```

**Explanation — this is the answer to "make sense of these".**

```
kubelet-client-current.pem:
  Issuer: CN = kubernetes-ca          (or the cluster CA)
  Extended Key Usage: TLS Web Client Authentication

kubelet-server-current.pem:
  Issuer: CN = kubernetes
  Extended Key Usage: TLS Web Server Authentication
```

| | Client cert | Server cert |
|---|---|---|
| Path | `/var/lib/kubelet/pki/kubelet-client-current.pem` | `/var/lib/kubelet/pki/kubelet-server-current.pem` |
| Used for | **Outgoing** — kubelet → apiserver | **Incoming** — apiserver → kubelet (logs, exec, port-forward) |
| Issued by | The **cluster CA** (`/etc/kubernetes/pki/ca.crt`) | The **`kubernetes`** CSR signer |
| Extended Key Usage | `TLS Web Client Authentication` | `TLS Web Server Authentication` |
| Rotated automatically | Yes (`rotateCertificates: true`) | Yes |
| Requires a CSR + approval | Yes — via the `kubernetes.io/kube-apiserver-client-kubelet` signer | Yes — via the `kubernetes.io/kubelet-serving` signer |

The reason they have **different issuers** is that they are signed by different signers, which is what lets the API
server apply different authorisation rules to each direction. The kubelet client cert's CN is `system:node:<node-name>`,
which the **Node** authoriser maps to permissions on that node's own objects only.

```bash
# Cross-check against the CSR objects
kubectl get csr
# NAME        AGE   SIGNERNAME                                    REQUESTOR           CONDITION
# csr-xxxxx   5m    kubernetes.io/kube-apiserver-client-kubelet   system:node:node01  Approved,Issued
```

> **Exam note** — the signer names in the CSR object tell you which cert it produced:
> `kubernetes.io/kube-apiserver-client-kubelet` → the client cert;
> `kubernetes.io/kubelet-serving` → the server cert. See Part V §5.8.

---

## 7.24 Drill 24 — NetworkPolicy for a "hacked backend pod" incident

**Exam weight:** Services & Networking (the most complete NetworkPolicy question in your set)

**Question.** There was a security incident where an intruder was able to access the whole cluster from a single hacked
backend Pod. Create a NetworkPolicy called `np-backend` in Namespace `project-snake`. It should allow the `backend-*`
Pods **only** to:
* connect to `db1-*` Pods on port 1111
* connect to `db2-*` Pods on port 2222

Use the `app` label of Pods in your policy. After implementation, connections from `backend-*` Pods to `vault-*` Pods on
port 3333 should no longer work.

Your answer (the ingress form, matching the official solution):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-backend
  namespace: project-snake
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: db1
      ports:
        - protocol: TCP
          port: 1111
    - from:
        - podSelector:
            matchLabels:
              app: db2
      ports:
        - protocol: TCP
          port: 2222
```

**Explanation.** Read the requirement very carefully — it is the inverse of what most people write.

The policy selects `app: backend` pods. Those pods are the **target** of the ingress rules. So the rules say:
"`app: backend` pods may **receive** traffic from `app: db1` on 1111 and from `app: db2` on 2222."

But the incident description says the *backend* pod was the attacker reaching *outward* to db1, db2 and vault. That is an
**egress** question, not an ingress one. The exam's official answer is the ingress policy above because the pods doing
the connecting are the ones being restricted — but if the question says "backend pods should only be able to **connect
to** X", the correct policy is:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-backend
  namespace: project-snake
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: db1
      ports:
        - protocol: TCP
          port: 1111
    - to:
        - podSelector:
            matchLabels:
              app: db2
      ports:
        - protocol: TCP
          port: 2222
```

**Read the direction words literally:**

| The question says | You write |
|---|---|
| "allow X **to connect to** Y on port P" | `podSelector: X`, `policyTypes: [Egress]`, `egress[].to.podSelector: Y`, `ports: [P]` |
| "allow X **to receive traffic from** Y on port P" | `podSelector: X`, `policyTypes: [Ingress]`, `ingress[].from.podSelector: Y`, `ports: [P]` |
| "block X from reaching Z" | Either restrict X's **egress** to exclude Z, or restrict Z's **ingress** to exclude X |

**The DNS trap.** If you write an Egress policy, you **must** allow port 53 or the pod cannot resolve anything:

```yaml
  egress:
    - to:
        - podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - podSelector:
            matchLabels:
              app: db1
      ports:
        - protocol: TCP
          port: 1111
    - to:
        - podSelector:
            matchLabels:
              app: db2
      ports:
        - protocol: TCP
          port: 2222
```

Or, since CoreDNS lives in `kube-system`, the simpler form is a port-only rule with no `to`:

```yaml
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

> **Exam note** — NetworkPolicy requires a CNI that implements it. **flannel alone does not.** Calico, Cilium, or Weave
> with netpol enabled do (Part III §3.4). If the exam cluster runs flannel, the NetworkPolicy question will be about
> *writing the manifest*, not about observing the effect.

---

## 7.25 Drill 25 — etcd backup, create a Pod, restore, confirm the Pod is gone

**Exam weight:** Cluster Architecture (the highest-value single skill in the whole exam)

**Question.** Create a backup of etcd. Create any kind of Pod in the cluster. Restore the backup. Confirm the cluster is
still working. Verify that the created Pod is no longer present.

Your answer:

```bash
# Step 1: Create a backup of etcd
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup.db

# Step 2: Create any kind of Pod in the cluster
kubectl run my-pod --image=busybox --command -- sleep 3600
# Alt image: quay.io/pandeysp/busybox:latest

# Step 3: Restore the backup
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot restore /tmp/etcd-backup.db --data-dir=/var/lib/etcd-from-backup

# Step 4: Confirm the cluster is still working
kubectl get nodes
kubectl get pods

# Step 5: Verify that the created Pod is no longer present
kubectl get pods | grep my-pod
# (no output)
```

**Explanation — the step your answer is missing, and it is the one that fails most people.**

`snapshot restore` creates a **new data directory**. It does **not** touch the running etcd. So after Step 3, nothing has
changed — the pod is still there. You must **point etcd at the restored directory**:

```bash
# On a kubeadm cluster (stacked etcd): edit the static pod manifest
sudo vi /etc/kubernetes/manifests/etcd.yaml
# volumes:
#   - hostPath:
#       path: /var/lib/etcd-from-backup      # was /var/lib/etcd
#       type: DirectoryOrCreate
#     name: etcd-data

# The kubelet recreates the etcd pod, and with it the scheduler and controller-manager
sudo crictl ps | grep etcd          # watch it come back
kubectl get pods | grep my-pod      # now gone
```

On a **systemd** etcd (your `practice-on-paper/practice-on-paper.sh` and `my-steps-etcd-systemctl.sh`):

```bash
sudo systemctl stop etcd
sudo rm -rf /var/lib/etcd
sudo etcdctl --data-dir /var/lib/etcd snapshot restore /home/cloud_user/etcd_backup.db
sudo chown -R etcd:etcd /var/lib/etcd
sudo systemctl restart etcd
sudo systemctl status etcd
```

**[Your note]** — the three operational gotchas from `practice-on-paper/practice-on-paper.sh`, verbatim:

> *you need to run it with sudo otherwise it does not allow you to mkdir /var/lib/etcd*
>
> *you need to stop `systemctl stop etcd` before removing `/var/lib/etcd`*

And from `my-steps-etcd-systemctl.sh`:

```bash
# find the listen url
systemctl cat etcd.service
systemctl cat etcd.service | grep -i listen
# locate where the instructions tell you the keys
ls -l /home/cloud_user/etcd-certs
# make sure the dir exists
mkdir -p /home/cloud_user/
# take the backup
etcdctl --endpoints=https://10.0.1.101:2379 snapshot save /home/cloud_user/etcd_backup.db
ls -lrt /home/cloud_user/etcd_backup.db
# restore
sudo rm -rf /var/lib/etcd/
sudo etcdctl --data-dir /var/lib/etcd snapshot restore /home/cloud_user/etcd_backup.db
# this is very important
chown -R etcd:etcd /var/lib/etcd
systemctl restart etcd.service
```

### The two snapshotting methods — `shells/two-methods-snapshotting.md`, verbatim

> There are two methods you mentioned are valid for taking a snapshot of the etcd database in Kubernetes:
>
> 1. Running `etcdctl` command from within the etcd pod/container: This approach involves accessing the etcd pod in the
>    `kube-system` namespace and running the `etcdctl` command directly inside it. This method requires SSH-ing into the
>    pod, setting up the necessary environment variables, and executing the etcdctl command to create a snapshot of the
>    etcd database.
>    `kubectl -n kube-system exec -it etcd-ip-172-31-40-74 -- sh -c "ETCDCTL_API=3 ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key etcdctl --endpoints=https://127.0.0.1:2379 snapshot save /var/lib/etcd/snapshot.db"`
>
> 2. Running `etcdctl` command from a control plane node: In this approach, you directly run the etcdctl command from one
>    of the control plane nodes of your Kubernetes cluster. You don't need to SSH into any pods. Instead, you set up the
>    necessary environment variables on the node itself (usually in a shell or a script), and then execute the etcdctl
>    command to create the snapshot.
>
> Both methods achieve the same result - creating a snapshot of the etcd database. The choice between them depends on
> your preference, security policies, and the specific requirements of your environment.
>
> The first method (running etcdctl inside the pod) might be preferred in environments where direct access to the pods is
> allowed, or if you want to automate the snapshot process within Kubernetes.
>
> The second method (running etcdctl from a control plane node) might be preferred in environments where SSH access to
> pods is restricted or if you prefer to manage snapshots from outside Kubernetes.

`shells/etcd-explore.sh` is the same thing, captured live with output:

```bash
kubectl -n kube-system exec -it etcd-ip-172-31-40-74 -- sh \
-c "ETCDCTL_API=3 \
ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt \
ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt \
ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key \
etcdctl --endpoints=https://127.0.0.1:2379 member list -w table"
```

```
+------------------+---------+-----------------+---------------------------+---------------------------+------------+
|        ID        | STATUS  |      NAME       |        PEER ADDRS         |       CLIENT ADDRS        | IS LEARNER |
+------------------+---------+-----------------+---------------------------+---------------------------+------------+
| 85b662448f547898 | started | ip-172-31-40-74 | https://172.31.40.74:2380 | https://172.31.40.74:2379 |      false |
+------------------+---------+-----------------+---------------------------+---------------------------+------------+
```

**[Your note]** — the permission trap, captured in the same file:

```bash
ls -lrt  /var/lib/etcd/snapshot.db
#  ls: cannot access '/var/lib/etcd/snapshot.db': Permission denied

sudo ls -lrt  /var/lib/etcd/snapshot.db
#  -rw------- 1 root root 3678240 Mar 19 12:18 /var/lib/etcd/snapshot.db
```

The snapshot is written as `root` with mode `0600`. If you take it inside the etcd container you must `sudo` to see it,
and you must copy it out with `sudo` too.

**The etcd key layout** — your `shells/etcd-keys.sh` (46 KB) is a dump of the registry keys. The shape:

```
/registry/
├── pods/<namespace>/<pod-name>
├── replicasets/<namespace>/<rs-name>
├── deployments/<namespace>/<deploy-name>
├── services/<namespace>/<svc-name>
├── secrets/<namespace>/<secret-name>
├── configmaps/<namespace>/<cm-name>
├── serviceaccounts/<namespace>/<sa-name>
├── nodes/<node-name>
├── persistentvolumes/<pv-name>
├── persistentvolumeclaims/<namespace>/<pvc-name>
├── events/<namespace>/<event-name>
└── minions/<node-name>          # legacy
```

**[Your note]** — from `shells/etcd-explore.sh`:

> *I deployed an nginx deployment and the following keys were added to etcd-ip-172-31-40-74*
> ```
> /registry/pods/default/nginx-7854ff8877-cxd7b
> /registry/replicasets/default/nginx-7854ff8877
> ```

That is the concrete proof that a Deployment creates a ReplicaSet which creates Pods, and each one is a separate etcd key.
It is also the answer to "how do I prove a restore worked" — the keys from the snapshot are the keys you get back.

---

## 7.26 Mock Exam 1 — `mock-exam-1.sh`

A mixed drill covering pods, labels, namespaces, NodePort, jsonpath output, static pods, and pod editing.

```bash
kubectl run nginx-pod --image=nginx:alpine
# Alt image: quay.io/pandeysp/nginx:latest
kubectl run messaging  --image=redis:alpine
# Alt image: quay.io/pandeysp/redis:latest
kubectl label pod messaging tier=msg
kubectl create ns apx-x9984574

# Write node JSON to a file — a very common "produce this output" task
kubectl get nodes -o json > /opt/outputs/nodes-z3444kd9.json

kubectl expose pod messaging --name=messaging-service --port=6379
kubectl get services

kubectl create deployment hr-web-app --image=kodekloud/webapp-color --replicas=2
# Alt image: quay.io/pandeysp/mywebapp:latest

# The static-pod drill — note the two typo attempts you captured
kubectl run static-busybox --image=busybox --dry-run=client -o yaml --comand sleep 1000 > static-busybox.yaml
kubectl run static-busybox --image=busybox --dry-run=client -o yaml -- comand sleep 1000 > static-busybox.yaml
cat static-busybox.yaml
vi static-busybox.yaml
mv static-busybox.yaml /etc/kubernetes/manifests/

# The correct form, in one line
kubectl run --restart=Never --image=busybox static-busybox \
  --dry-run=client -oyaml --command -- sleep 1000 \
  > /etc/kubernetes/manifests/static-busybox.yaml
```

**[Your note]** — the flag typos, which are worth naming because they are exactly what muscle memory gets wrong:

> `--comand` (missing `m`) and `-- comand` (space instead of a second dash) both silently produce a manifest where the
> tokens land in `args` instead of `command`. Always `cat` the generated file before applying it.

The rest of the exam:

```bash
kubectl get ns
kubectl run temp-bus --image=redis:alpine -n finance
# Alt image: quay.io/pandeysp/redis:latest

# The edit-fails → delete → apply-the-saved-file rescue, again
kubectl logs orange
kubectl edit pod orange
kubectl delete pod orange
kubectl apply -f /tmp/kubectl-edit-2369672821.yaml

# Expose, then pin the nodePort explicitly (the gotcha from Part III §3.2)
kubectl expose deployment hr-web-app --name=hr-web-app-service --type=NodePort --port=8080
kubectl edit service hr-web-app-service

# jsonpath to a file
kubectl get nodes -o jsonpath='{range .items[*]}{.status.nodeInfo.osImage}{"\n"}{end}' > /opt/outputs/nodes_os_x43kj56.txt

# PV drill
kubectl create persistentvloume -h        # ← typo; also there is no `kubectl create persistentvolume`
kubectl get pv --all-namespaces
vi temp-pv.yaml
kubectl apply -f temp-pv.yaml
```

> **Exam note** — there is no `kubectl create persistentvolume`, `kubectl create replicaset`,
> `kubectl create daemonset`, `kubectl create statefulset`, or `kubectl create networkpolicy`. Write those as YAML or
> derive them from a Deployment manifest.

---

## 7.27 Mock Exam 2 — `mock-exam-2.sh`

The most valuable of the three, because it chains five competencies in sequence.

**Question, in your own words at the top of the file:**

> 1. Generate certificates for the user.
> 2. Create a certificate signing request (CSR).
> 3. Sign the certificate using the cluster certificate authority.
> 4. Create a configuration specific to the user.
> 5. Add RBAC rules for the user or their group.

### The certificate chain

```bash
openssl req -new -key /root/CKA/john.key -out /root/CKA/john.csr -subj "/CN=john/O=development"
cat /root/CKA/john.csr

# this is important that makes the one-liner otherwise we receive an interpretation error
cat /root/CKA/john.csr | base64 | tr -d "\n"
```

**[Your note]** — verbatim:

> *this is important that makes the one-liner otherwise we receive a interpretation error*

`base64` alone wraps at 76 characters. `tr -d "\n"` (equivalently `base64 -w 0`) makes it a single line, which is what
the `request` field of a CSR object requires. Your repo documents this twice — here and in `Labs/23-certificate-signing-request.sh`.

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john
spec:
  signerName: kubernetes.io/kube-apiserver-client
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0K...   # the one-liner
  usages:
    - digital signature
    - key encipherment
    - client auth
```

```bash
kubectl apply -f my-csr.yaml
kubectl certificate approve john          # ← forgetting this is the classic failure
```

> **Note on `usages`** — your version lists `digital signature`, `key encipherment` and `client auth`. The other
> location in your repo (`Labs/23-certificate-signing-request.sh`) uses only `client auth`. Both are accepted; `client
> auth` is the one that actually matters for a user certificate.

### The RBAC chain

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: john-role
rules:
  - apiGroups: [""]                    # "" indicates the core API group
    resources: ["pods"]
    verbs: ["get", "list", "create", "update", "delete"]
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: john-role-binding
  namespace: development
subjects:
  - kind: User
    name: john                         # "name" is case sensitive
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role                           # this must be Role or ClusterRole
  name: john-role                      # this must match the name of the Role or ClusterRole
  apiGroup: rbac.authorization.k8s.io
```

**[Your note]** — the three inline comments are the same three from `Labs/27-role-rb.sh`, which means they are the three
things you had to look up more than once. They are correct and worth memorising.

The imperative equivalents, from the `history` block at the bottom of the file:

```bash
kubectl -n development create role developer --verb=create,list,get,update,delete --resource=pods
kubectl -n development create rolebinding developer-rb --role=developer --user=john-developer
```

### The capabilities drill

```bash
kubectl run super-user-pod --image=busybox:1.28 --dry-run=client -o yaml --command -- sleep 4800 > systtime-pod.yaml
```

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
      # Alt image: quay.io/pandeysp/ubuntu-git:latest
      name: ubuntu-sleeper
      securityContext:
        capabilities:
          add: ["SYS_TIME"]
```

**[Your note]** — verbatim:

> *capabilities allow the container to update some root-user command*

Precisely: Linux capabilities split root's privileges into individually grantable units. `SYS_TIME` lets the container
call `settimeofday()`/`clock_settime()` — i.e. change the system clock. `NET_ADMIN` lets it configure interfaces and
routes. Adding them to an otherwise unprivileged container is the "least privilege plus exactly what's needed" pattern
the CKA tests (Part V §5.7).

### The PV/PVC drill

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 8Gi
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: use-pv
  name: use-pv
spec:
  containers:
    - image: nginx
      # Alt image: quay.io/pandeysp/nginx:latest
      name: use-pv
      resources: {}
      volumeMounts:
        - mountPath: "/data"
          name: my-pvc-vol
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  volumes:
    - name: my-pvc-vol
      persistentVolumeClaim:
        claimName: my-pvc
```

**[Your note]** — verbatim, and it is the rule that governs every storage question:

> *volumeMounts and volumes are the two parts should be covered*
>
> *accessModes: and storage must be the same in pv and pvc otherwise they do not match and will not bound*

Your `history` block shows the full recovery loop when a PV is in the way — delete the PV, delete the PVC, re-apply both,
then the pod:

```bash
kubectl get pv pv-1 -o yaml > my-pv.yaml
vi my-pv.yaml
kubectl delete pv pv-1
kubectl delete pvc my-pvc
kubectl apply -f  my-pv.yaml
kubectl apply -f  pvc-1.yaml
kubectl get pv
kubectl get pvc
kubectl apply -f /root/CKA/use-pv.yaml
kubectl describe pod use-pv
```

### The deployment update drill

```bash
kubectl create deployment nginx-deploy --image=nginx:1.16 --replicas=1
kubectl set image deployment/nginx-deploy  nginx=nginx:1.17     # "nginx" is the CONTAINER name
```

**[Your note]** — verbatim:

> *nginx is container name*

That is the whole gotcha of `kubectl set image`: the syntax is `deployment/<name> <container-name>=<image>`, and the
container name is whatever `spec.template.spec.containers[0].name` is — not necessarily the deployment name. Get it wrong
and you get `error: unable to find container named ...`.

### The DNS drill — and the reverse-lookup detail

```bash
kubectl run nginx-resolver --image=nginx
# Alt image: quay.io/pandeysp/nginx:latest
kubectl expose pod nginx-resolver --name=nginx-resolver-service --port=80

kubectl run busybox --image=busybox:1.28 -- sleep 4000
# Alt image: quay.io/pandeysp/busybox:v1
kubectl exec -it busybox -- nslookup nginx-resolver-service
```

```
   Server:    10.96.0.10
   Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

   Name:      nginx-resolver-service
   Address 1: 10.109.13.156 nginx-resolver-service.default.svc.cluster.local
```

And the reverse form, which most candidates do not know:

```bash
kubectl exec -it busybox -- nslookup 10-244-192-4.default.pod.cluster.local
```

```
   Server:    10.96.0.10
   Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

   Name:      10-244-192-4.default.pod.cluster.local
   Address 1: 10.244.192.4 10-244-192-4.nginx-resolver-service.default.svc.cluster.local
```

**Explanation.** There are **two** DNS naming schemes, and the exam tests both:

| Direction | Name form | Example |
|---|---|---|
| Service → IP | `<svc>.<ns>.svc.cluster.local` | `nginx-resolver-service.default.svc.cluster.local` |
| Pod IP → pod | `<ip-with-dashes>.<ns>.pod.cluster.local` | `10-244-192-4.default.pod.cluster.local` |

The pod form replaces every `.` in the IP with `-`. Note also the interesting output: the pod's PTR record resolves to
`10-244-192-4.nginx-resolver-service.default.svc.cluster.local` — the pod IP is *also* registered as a hostname under the
Service's name, which is why reverse lookups of pod IPs work at all.

```bash
# The complete set of lookups the exam may ask for
kubectl exec busybox -- nslookup kubernetes.default
kubectl exec busybox -- nslookup nginx-resolver-service
kubectl exec busybox -- nslookup nginx-resolver-service.default
kubectl exec busybox -- nslookup nginx-resolver-service.default.svc.cluster.local
kubectl exec busybox -- nslookup 10.244.192.4
kubectl exec busybox -- nslookup 10-244-192-4.default.pod.cluster.local
```

### The static pod on another node drill

```bash
kubectl run nginx-critical --image=nginx --restart=Always --dry-run=client -o yaml > nginx-critical.yaml
vi nginx-critical.yaml
mv nginx-critical.yaml /etc/kubernetes/manifests
systemctl restart kubelet
kubectl get pods

cd /etc/kubernetes/manifests/
scp nginx-critical.yaml node01:/root/
ssh node01
kubectl get pods
```

**[Your note]** — the last two lines are the mistake. `scp`-ing to `/root/` on the worker does **nothing**: a static pod
must be placed in that node's **`staticPodPath`**, which you must read from `/var/lib/kubelet/config.yaml` (Part I §1.6 —
remember `/etc/just-to-mess-withyou`). And `kubectl get pods` run *on the worker* will not show the mirror pod unless the
worker has a kubeconfig, which it does not in the usual setup.

```bash
# Correct
ssh node01
grep staticPodPath /var/lib/kubelet/config.yaml
scp nginx-critical.yaml node01:/etc/kubernetes/manifests/
systemctl restart kubelet          # on the worker
# back on the control plane:
kubectl get pods -o wide | grep nginx-critical
# nginx-critical-node01   1/1   Running   0   10s   node01
```

### The note on CSR vs ServiceAccount

**[Your note]** — verbatim, and it is a good summary of the whole section:

> *CertificateSigningRequest and ServiceAccount serve different use cases and cater to different types of identities
> within a Kubernetes cluster. The first approach is focused on granting permissions to external users or processes — you
> might have a monitoring tool or CI/CD pipeline that needs access to certain resources. The second approach is focused
> on granting permissions to internal applications and components — e.g. you might have a microservice that needs access
> to certain resources or an operator that needs permission to manage resources across multiple namespaces.*

| | CSR (user cert) | ServiceAccount |
|---|---|---|
| Identity is | A **human or external system** | A **workload in the cluster** |
| Credential is | An X.509 cert + key in a kubeconfig | A projected token in `/var/run/secrets/kubernetes.io/serviceaccount` |
| Created by | `openssl req` + CSR object + `kubectl certificate approve` | `kubectl create serviceaccount` |
| Bound with | RoleBinding/ClusterRoleBinding with `kind: User` | RoleBinding/ClusterRoleBinding with `kind: ServiceAccount` |
| Rotated | Manually, or with `kubeadm certs renew` | Automatically by the kubelet (`expirationSeconds: 3607`) |

---

## 7.28 Mock Exam 3 — `mock-exam-3.sh`

A drill covering ServiceAccounts, ClusterRoles, taints, secrets, kubeconfig, and a broken control-plane component.

### ServiceAccount + ClusterRole + ClusterRoleBinding for PVs

```bash
kubectl create serviceaccount pvviewer
kubectl create clusterrole pvviewer-role --verb=list --resource=persistentvolumes
kubectl create clusterrolebinding pvviewer-role-binding --clusterrole=pvviewer-role --serviceaccount=default:pvviewer

kubectl run pvviewer --image=redis --dry-run=client -o yaml > pvviewer.yaml
# Alt image: quay.io/pandeysp/redis:latest
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: pvviewer-role
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pvviewer-role-binding
subjects:
  - kind: ServiceAccount
    name: pvviewer
    namespace: default
roleRef:
  kind: ClusterRole
  name: pvviewer-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: pvviewer
  name: pvviewer
spec:
  containers:
    - image: redis
      # Alt image: quay.io/pandeysp/redis:latest
      name: pvviewer
      resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  serviceAccount: pvviewer
```

**Explanation.** `persistentvolumes` is a **cluster-scoped** resource, so a namespaced Role cannot grant access to it —
you need a ClusterRole + ClusterRoleBinding. And note the `namespace: default` on the subject: `--serviceaccount=default:pvviewer`
means *namespace* `default`, *name* `pvviewer`.

```bash
kubectl auth can-i list persistentvolumes --as system:serviceaccount:default:pvviewer
# yes
```

### The multi-container pod with `env` per container

```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: multi-pod
  name: multi-pod
spec:
  containers:
    - image: nginx
      # Alt image: quay.io/pandeysp/nginx:latest
      name: alpha
      env:
        - name: name
          value: "alpha"
    - image: busybox
      # Alt image: quay.io/pandeysp/busybox:latest
      name: beta
      env:
        - name: name
          value: "beta"
```

**Explanation.** Each container in a pod has its **own** `env` block; they do not inherit from each other. Both can bind
the same variable *name* (`name`) to different values because each container has a separate environment.

### The non-root pod with `fsGroup`

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: non-root-pod
  name: non-root-pod
spec:
  containers:
    - image: redis:alpine
      # Alt image: quay.io/pandeysp/redis:latest
      name: non-root-pod
      resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  securityContext:
    runAsUser: 1000
    fsGroup: 2000
```

**Explanation.** `runAsUser: 1000` sets the UID the process runs as. `fsGroup: 2000` sets the **supplementary group** that
owns mounted volumes, and makes the volume group-writable for that GID. The two are independent: the first affects the
process, the second affects filesystem ownership.

**Alternative images** that satisfy a "must run as non-root" requirement without fighting the image:
`# Alt image: quay.io/pandeysp/nginx-unprivileged:latest`, `# Alt image: quay.io/pandeysp/openshift-nginx:latest`.

### The taint + toleration drill

```bash
kubectl taint nodes node01 env_type=production:NoSchedule
kubectl run dev-redis  --image=redis:alpine
kubectl run prod-redis --image=redis:alpine --dry-run=client -o yaml > prod-redis.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: prod-redis
  name: prod-redis
spec:
  containers:
    - image: redis:alpine
      # Alt image: quay.io/pandeysp/redis:latest
      name: prod-redis
      resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  tolerations:
    - key: "env_type"
      operator: "Equal"
      value: "production"
      effect: "NoSchedule"
  nodeSelector:
    kubernetes.io/hostname: node01
```

**[Your note]** — verbatim, and it is a real trap:

> *TODO make sure to apply the taint that is provided in the question key value operation etc*

The `key`, `value`, `effect` and `operator` in the toleration must match the taint **exactly**. `operator: "Equal"`
requires `value` to be present and equal; `operator: "Exists"` ignores `value` entirely. Writing `Exists` with a `value`
is invalid; writing `Equal` without a `value` is invalid.

```bash
# Confirm the taint exists before writing the toleration
kubectl describe node node01 | grep -i taint
# Taints:             env_type=production:NoSchedule
```

### The broken control-plane component

**[Your note]** — verbatim:

> *you did not fix the labels*
> *run: np-test-1*
> *they do not match be careful of label matching*

```bash
kubectl edit pod kube-contro1ler-manager-controlplane -n kube-system
kubectl delete  pod kube-contro1ler-manager-controlplane -n kube-system
kubectl apply -f /tmp/kubectl-edit-103083158.yaml
kubectl get pods -n kube-system

sed -i 's/kube-contro1ler-manager/kube-controller-manager/g' /etc/kubernetes/manifests/kube-controller-manager.yaml
kubectl get pods -n kube-system
kubectl delete pod kube-controller-manager-controlplane --force -n kube-system
```

**Explanation.** Two separate failures, and both are instructive:

1. **`kube-contro1ler-manager`** — a digit `1` where the letter `l` belongs, in `/etc/kubernetes/manifests/kube-controller-manager.yaml`.
   Because the manifest's filename is right but the **command inside it** is wrong, the static pod starts and immediately
   crashes (`CrashLoopBackOff`) — the kubelet is trying to exec a binary that does not exist. `kubectl edit pod` cannot
   fix a static pod (Part I §1.6), and even if it could, the kubelet would overwrite it. The fix is to edit the **file**:

```bash
sudo sed -i 's/kube-contro1ler-manager/kube-controller-manager/g' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

   The kubelet's file-watch then recreates the pod, correctly this time.
2. **The pod's name in the API is `kube-controller-manager-<node>`**, so `kubectl delete pod kube-contro1ler-manager-controlplane`
   fails with "not found" — you must delete the *correctly spelled* mirror pod, or just `kubectl delete pod -n kube-system -l component=kube-controller-manager`.

```bash
# The generic form of the fix
sudo grep -n 'kube-contro' /etc/kubernetes/manifests/*.yaml
sudo sed -i 's/kube-contro1ler-manager/kube-controller-manager/g' /etc/kubernetes/manifests/kube-controller-manager.yaml
kubectl -n kube-system get pods -w
```

**The scaling connection** — the reason this breaks everything else:

**[Your note]** — verbatim:

> *The controller-manager is responsible for scaling up pods of a replicaset. If you inspect the control plane components
> in the kube-system namespace, you will see that the controller-manager is not running.*

```bash
kubectl scale deploy nginx-deploy --replicas=3
kubectl get deploy
# NAME           READY   UP-TO-DATE   AVAILABLE   AGE
# nginx-deploy   0/3     0            0           2m        ← nothing happens
```

`kubectl scale` only writes `spec.replicas` to the API server. Something else has to notice and create the pods — that
something is `kube-controller-manager`. If it is down, the Deployment's `READY` stays at 0 forever, with no error. This
is a genuinely elegant exam question because the symptom (a Deployment that will not scale) points nowhere near the cause
(a typo in a static pod manifest).

### The jsonpath node-IP extraction

```bash
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' > /root/CKA/node_ips
```

That filter — `[?(@.type=="InternalIP")]` — is the canonical way to pick one entry out of the `addresses` array. The
variants worth knowing:

```bash
# ExternalIP instead
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'

# One per line
kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'

# Hostname
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}'

# Node names, one per line
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

# All pods on a given node
kubectl get pods -A -o jsonpath='{.items[?(@.spec.nodeName=="node01")].metadata.name}'
```

### The NetworkPolicy drill

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-to-nptest
spec:
  podSelector:
    matchLabels:
      run: np-test-1
  policyTypes:
    - Ingress
  ingress:
    - ports:
        - port: 80
```

**Explanation.** An `ingress` rule with `ports` but **no `from`** means "allow from **anywhere** on port 80". That is the
correct reading of "allow ingress to np-test on port 80" when no source restriction is specified. If you also wanted to
restrict the source you would add a `from` block (Part III §3.4).

---

## 7.29 Ingress scenarios — `last-try/scenarios-ingress.txt`

Five scenario questions with no answers written in the source. Work them on paper before looking at the solutions below.

### Scenario 1 — Expose frontend externally, keep backend and database private

> Your Kubernetes cluster hosts a web application with multiple services including frontend, backend and database. You
> need to expose the frontend service to external users over HTTP (port 80) and HTTPS (port 443), while ensuring that
> traffic to the backend and database services remains internal to the cluster. Write an Ingress resource definition to
> expose the frontend service externally while keeping the backend and database services private.

**Solution.** The key insight: **an Ingress only ever references the Service you name in its backend.** There is nothing
to write to "keep backend and database private" — you simply do not create Ingress rules for them, and you make sure they
are `ClusterIP` (the default) rather than `NodePort` or `LoadBalancer`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: frontend-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

```bash
# The Services: only frontend gets anything but ClusterIP
kubectl expose deployment frontend --port=80 --type=ClusterIP
kubectl expose deployment backend  --port=8080 --type=ClusterIP     # internal only
kubectl expose deployment database --port=5432 --type=ClusterIP     # internal only

kubectl create secret tls frontend-tls --cert=server.crt --key=server.key
```

**Alternative image:** `# Alt image: quay.io/pandeysp/portfolio:latest` for the frontend.

### Scenario 2 — Single point of entry, hostname-based routing

> Your cluster hosts multiple web applications, each with its own frontend service. You want a single point of entry for
> all these applications, routing traffic based on the request hostname to the respective frontend services. Define an
> Ingress resource that routes traffic based on the request hostname to the appropriate frontend services.

**Solution.** One `rules[]` entry per host.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: app1.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app1-service
                port:
                  number: 80
    - host: app2.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app2-service
                port:
                  number: 80
    - host: app3.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app3-service
                port:
                  number: 80
```

**Alternative images:** `# Alt image: quay.io/pandeysp/portfolio:latest`, `# Alt image: quay.io/pandeysp/nginxdemo:latest`,
`# Alt image: quay.io/pandeysp/mywebapp:latest` — one per host.

### Scenario 3 — Single domain, path-based routing to microservices

> You are deploying a microservices-based application where each microservice is exposed through its own service. You
> want to provide external access using a single domain name, with path-based routing to the respective services. Create
> an Ingress resource that routes traffic based on the request path.

**Solution.** One `paths[]` entry per service, all under one host.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /users
            pathType: Prefix
            backend:
              service:
                name: users-service
                port:
                  number: 80
          - path: /orders
            pathType: Prefix
            backend:
              service:
                name: orders-service
                port:
                  number: 80
          - path: /payments
            pathType: Prefix
            backend:
              service:
                name: payments-service
                port:
                  number: 80
```

**Alternative images:** `# Alt image: quay.io/pandeysp/api-server:v1.0`, `# Alt image: quay.io/pandeysp/node-service:v1`,
`# Alt image: quay.io/pandeysp/tea:latest` / `coffee:latest`.

### Scenario 4 — SSL termination at the ingress plus HTTP→HTTPS redirect

> Your organisation requires SSL termination at the ingress level for all incoming traffic, and HTTP to HTTPS redirection
> for all incoming requests. Configure SSL termination and HTTP to HTTPS redirection in the Ingress resource definition.

**Solution.** The TLS block terminates SSL; the annotation handles the redirect. Note that the redirect annotation is
**controller-specific** — these are the nginx-ingress ones.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - secure.example.com
      secretName: secure-tls
  rules:
    - host: secure.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

```bash
kubectl create secret tls secure-tls --cert=server.crt --key=server.key
```

> **Exam note** — `nginx.ingress.kubernetes.io/ssl-redirect: "true"` is the default in recent ingress-nginx versions;
> `force-ssl-redirect` makes it unconditional even when the `X-Forwarded-Proto` header is absent. Your live capture in
> `Labs/33-ingress-1.sh` shows the opposite — `ssl-redirect: false` — because that Ingress was plain HTTP.

### Scenario 5 — Canary deployment by traffic percentage

> Your cluster runs multiple versions of the same application, each serving different user groups. You want to perform a
> canary deployment by routing a percentage of traffic to the new version while keeping the majority on the stable
> version. Set up an Ingress resource to perform canary deployment.

**Solution.** **Ingress cannot do this natively.** Percentage-based splitting is an annotation provided by the
ingress-nginx controller, and it works by *weighting two Ingress objects that share the same host*.

```yaml
# The stable version — no canary annotation
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-stable
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-stable-service
                port:
                  number: 80
---
# The canary version — 10% of traffic
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-canary-service
                port:
                  number: 80
```

**Alternative image:** `# Alt image: quay.io/pandeysp/production:v5` for the canary and `v1` for the stable — you have
five real versions to canary through.

The other canary annotations:

| Annotation | Effect |
|---|---|
| `canary: "true"` + `canary-weight: "10"` | 10% of requests to this Ingress |
| `canary: "true"` + `canary-by-header: "x-canary"` | Route to canary when the request has that header |
| `canary: "true"` + `canary-by-header-value: "always"` | …and the header has that exact value |
| `canary: "true"` + `canary-by-cookie: "canary"` | Route by cookie |

> **Exam note** — if the exam asks for a canary and the cluster runs flannel with no ingress controller installed, the
> answer is to *install the controller* first, then write the two Ingress objects. Also worth knowing: the **Service
> Mesh** (Istio/Linkerd) way is a `VirtualService` with `weight`, but that is outside the CKA.

---

## 7.30 NetworkPolicy scenarios — `last-try/senarisos-np.txt`

Five more scenarios, with solutions.

### Scenario 1 — Two namespaces, one port

> You have a cluster with two namespaces: `frontend` and `backend`. Pods in `frontend` should be able to communicate with
> pods in `backend` over TCP port 8080, but all other communication should be blocked.

**Solution.** Two policies, because the restriction has to be enforced on **both** sides.

```yaml
# In namespace "backend": allow ingress from frontend on 8080 only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: backend
spec:
  podSelector: {}                       # all pods in backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: frontend
      ports:
        - protocol: TCP
          port: 8080
---
# In namespace "frontend": allow egress to backend on 8080 only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress
  namespace: frontend
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: backend
      ports:
        - protocol: TCP
          port: 8080
    # DNS must still work
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

**The namespaceSelector insight.** `kubernetes.io/metadata.name` is a label the control plane puts on **every** namespace
automatically, so you can select by namespace name without labelling anything:

```bash
kubectl get ns --show-labels
# NAME       STATUS   AGE   LABELS
# backend    Active   5m    kubernetes.io/metadata.name=backend
# frontend   Active   5m    kubernetes.io/metadata.name=frontend
```

> **Exam note** — you cannot select a namespace by `metadata.name` in a NetworkPolicy; you must use a **label**. Either
> the automatic `kubernetes.io/metadata.name` or one you add yourself (`kubectl label ns frontend project=frontend`).
> Your `acg-multic-np.yaml` uses the manual approach (`project: users-backend`).

### Scenario 2 — Three tiers, different ports

> Your cluster hosts a multi-tier application: frontend, backend and database. Pods in `frontend` should communicate with
> pods in `backend` over TCP 80 and 443, but communication between `backend` and `database` should be restricted to TCP
> 5432.

**Solution.**

```yaml
# backend: ingress from frontend on 80 and 443
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: backend
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: frontend
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 443
---
# database: ingress from backend on 5432 only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-to-database
  namespace: database
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: backend
      ports:
        - protocol: TCP
          port: 5432
```

Note the structure: **two `ports` entries in one rule** means "both ports, from the same sources". Two separate `ingress[]`
entries would mean "either of these rules".

### Scenario 3 — Financial app, HTTPS only, and no backend egress

> Pods in `frontend` should only communicate with pods in `backend` over HTTPS (TCP 443). Additionally, pods in `backend`
> should be restricted from initiating connections to any other namespace.

**Solution.** The second sentence is an **egress** restriction on `backend`.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: financial-policy
  namespace: backend
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: frontend
      ports:
        - protocol: TCP
          port: 443
  egress:
    # allow DNS, or nothing resolves
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    # allow replies back to frontend
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: frontend
      ports:
        - protocol: TCP
          port: 443
```

**The trap.** `policyTypes: [Egress]` with a non-empty `egress` list means **deny all egress except what is listed**. So
you must list DNS explicitly, and you must list the return path if the backend needs to respond. Getting this wrong makes
the whole application fail DNS resolution, which looks like a completely different bug.

### Scenario 4 — Tenant isolation with intra-namespace freedom

> Your cluster hosts multiple tenants, each with their own namespace. Tenants should be isolated from each other, and
> communication between pods in different namespaces should be restricted. However, pods within the same namespace should
> be allowed to communicate freely.

**Solution.** One policy per tenant namespace, allowing only same-namespace traffic.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: tenant-a
spec:
  podSelector: {}                 # selects ALL pods in the namespace
  policyTypes:
    - Ingress
    - Egress
  # no ingress: and no egress: blocks → nothing in or out
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}         # any pod IN THIS namespace
  egress:
    - to:
        - podSelector: {}         # any pod IN THIS namespace
    # plus DNS
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

**The key insight.** `podSelector: {}` with **no** `namespaceSelector` means "pods in **this** namespace". That is the
whole mechanism for intra-namespace allow. And the two policies are **additive** — the union of what they allow is what is
permitted, so the combination is "same namespace only".

**Alternative image:** `# Alt image: quay.io/pandeysp/mywebapp:latest` for the tenant apps.

### Scenario 5 — Restrict egress to one external API

> You are deploying an application that requires access to an external API hosted at api.example.com over TCP port 443.
> However, you want to restrict egress traffic to only this API and block all other outbound connections from the pods.

**Solution.** `ipBlock` with the API's resolved IP.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 93.184.216.0/24        # api.example.com's range
      ports:
        - protocol: TCP
          port: 443
    # DNS must still work
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

```bash
# Resolve the hostname first — the policy needs an IP, not a name
dig +short api.example.com
# 93.184.216.34
```

**The `ipBlock.except` variant**, when you want a big range minus a hole:

```yaml
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
            except:
              - 10.1.0.0/16
              - 10.2.0.0/16
```

> **Exam note** — NetworkPolicy cannot match on **DNS names**, only on pod labels, namespace labels and CIDRs. If a
> question says "allow egress to api.example.com", you must resolve it to a CIDR and use `ipBlock`. That limitation
> surprises a lot of candidates.

---

## 7.31 Part VII self-check

1. `kubectl cordon kube-scheduler` — why is this wrong, and what are the two correct ways to stop a scheduler?
2. A Service in namespace `data` is unreachable from a pod in namespace `web` using the short name. Give the two name
   forms that work.
3. You ran `etcdctl snapshot restore ... --data-dir /var/lib/etcd-from-backup`. Why is nothing different, and what is the
   next command?
4. `topologySpreadConstraints` with no `labelSelector` — what happens?
5. A Deployment will not scale. `kubectl scale` succeeds. What do you check?
6. Write the JSONPath to extract every node's InternalIP, one per line.
7. A NetworkPolicy has `policyTypes: [Egress]` and an `egress` list with no port 53. What breaks first?
8. "Allow backend pods to connect to db1 on 1111" — Ingress or Egress, and which pod does `podSelector` name?
9. What is the mirror pod's name for a static pod `my-pod` on node `node01`?
10. `base64` of a CSR fails with an interpretation error. What flag or pipe fixes it?

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

Every file in the repository (all 266 non-`.git` files) mapped to the CKA domain and the section of this
document that covers it. Use this to go
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
| **DR** | Exam drills / mock exams | VII |
| **REF** | Reference / cheat sheet | App. D |

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

## B.10 Root-level files added in the second pass

The first survey of this repo was truncated at 200 files and silently dropped everything below. These are the root-level
files that were missed.

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `mock-exam-1.sh` | DR/WS/SN | Mixed drill: pods, labels, NodePort, jsonpath output, static pods, pod editing | Part VII §7.26 |
| `mock-exam-2.sh` | DR/SEC/ST | User certificates → CSR → RBAC; capabilities; PV/PVC; `set image`; DNS incl. reverse pod lookup; static pod on another node | Part VII §7.27 |
| `mock-exam-3.sh` | DR/SEC/WS | ServiceAccount + ClusterRole; taints + tolerations; secrets; kubeconfig; the `kube-contro1ler-manager` typo | Part VII §7.28 |
| `kubectl-quick-refrence.sh` | REF | Your own `kubectl` cheat sheet — config, create, get, rollout, patch, scale, logs, top, taint, api-resources, `--v` levels | Appendix D §D.2–D.10 |
| `jsaon-path-examples.sh` | REF | JSONPath and `jpath` experiments; `.items[*]`, `[?(@.type=="InternalIP")]`, key escaping | Appendix D §D.11 |
| `chatgpt-solutions.yaml` | SN | Two NetworkPolicy variants side by side | Part III §3.4 |
| `core-dns-configmap.yaml` | SN | The full Corefile, verbatim | Part III §3.3 |
| `my-ds.yaml` | WS | DaemonSet `ds-important` with a `nodeSelector` on control-plane | Part VII §7.11 |
| `my-ingress-in-may.yaml` | SN | Ingress with `#TODO` comments and a NodePort Service | Part III §3.5 |
| `my-steps-etcd-systemctl.sh` | CAIC/TS | **etcd as a systemd service** — backup, restore, `chown -R etcd:etcd`, plus network triage and a PV sort | Part I §1.10, Part VII §7.25 |
| `my-volume-types.yaml` | ST | All five volume types in one file | Part IV §4.8 |
| `np-temp.yaml` | SN | NetworkPolicy variants (ingress/egress, podSelector forms) | Part III §3.4 |
| `temp.bash` | — | Scratch file | — |
| `volumeMounts.yaml` | ST/WS | The `volumeMounts` + `volumes` pairing | Part IV §4.1 |
| `secre-as-volatile-volumes` | SEC | Transcript: opaque Secret + secret-as-volume pod + the base64 note | Part V §5.6, Part VII §7.20 |

---

## B.11 `last-try/`

The largest new find — 740 lines of fully worked CKA questions.

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `questions.sh` | **all domains** | 25 worked CKA exam questions, Q1–Q25 | Part VII §7.1–7.25 |
| `scenarios-ingress.txt` | SN | 5 Ingress scenarios: HTTP/HTTPS exposure, host routing, path routing, SSL termination + redirect, canary | Part VII §7.29 |
| `senarisos-np.txt` | SN | 5 NetworkPolicy scenarios: ns→ns port 8080, 80/443 + 5432 split, HTTPS-only + egress restriction, tenant isolation, external-API egress | Part VII §7.30 |
| `gb-trouble-shooting.sh` | TS/SN | NodeNotReady (kubelet `inactive (dead)`), and the busybox-cannot-reach-`auth-db` cross-namespace FQDN drill | Part VI §6.1, Part VII §7.18–7.19 |
| `liveness-probe.yaml` | WS | `exec` liveness probe doing the network check, `readinessProbe: exec: ["true"]` | Part VII §7.4 |
| `luna-ingress.yaml` | SN | Host + path Ingress | Part III §3.5 |
| `luna-ingress-hostless.yaml` | SN | Ingress with no `host` (matches any) | Part III §3.5 |
| `luna-np.yaml` | SN | NetworkPolicy with `namespaceSelector` | Part III §3.4 |

---

## B.12 `lightenin-labs/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `lighteningexam.sh` | CAIC | Full v1.29 upgrade sequence, `custom-columns` deployment inventory to `/opt/admin2406_data`, kubeconfig at `/root/CKA/admin.kubeconfig`, `set image` 1.16→1.17, PVC debug for `alpha-mysql`, etcd snapshot, secret volume pod | Parts I §1.9, §1.12; VII §7.25 |
| `pod.yaml` | ST | `pv-pod` in ns `auth` claiming `host-storage-pv` | Part IV §4.2 |
| `pvc.yaml` | ST | `mysql-alpha-pvc`, StorageClass `slow` | Part IV §4.2 |
| `pvc2.yaml` | ST | `host-storage-pvc`, StorageClass `expandable` | Part IV §4.5 |
| `container-secret-volume.yaml` | SEC | Secret `secret-1401` mounted via `dotfile-secret` | Part V §5.6 |

---

## B.13 `practice-on-paper/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `practice-on-paper.sh` | CAIC/TS/WS | `kubectl top` with selector and `--sort-by`, taint grep, `logs -c proc > errors.txt`, **etcd-as-a-systemd-service** backup/restore, full v1.29 upgrade, `chown -R etcd:etcd` | Parts I §1.9–1.10; VII §7.7, §7.25 |
| `PersistentVolume.yaml` | ST | hostPath `/etc/data`, class `expandable`, `Retain` | Part IV §4.2 |
| `storage-class.yaml` | ST | `no-provisioner`, `WaitForFirstConsumer`, `allowVolumeExpansion: true` | Part IV §4.5 |

---

## B.14 `shells/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `control-plane.sh` | CAIC | 45 KB of live control-plane shell history | Part I |
| `etcd-keys.sh` | CAIC | 46 KB dump of `/registry/...` etcd keys | Part I §1.9, Part VII §7.25 |
| `bootstrap-kubeadm-control-plane.sh` | CAIC | The minimal kubeadm init flow | Part I §1.1 |
| `cp-commands.sh` | CAIC | Calico install, kubeadm-config, `--upload-certs`, CA hash extraction | Parts I §1.1, §1.5 |
| `worker-commands.sh` | CAIC | `kubeadm join` output | Part I §1.1 |
| `etcd-explore.sh` | CAIC/TS | `etcdctl member list -w table`, snapshot save, restore to `/var/lib/etcd-from-backup`, the permission-denied gotcha | Part VII §7.25 |
| `two-methods-snapshotting.md` | CAIC | In-pod vs on-node `etcdctl`, verbatim, with the trade-off discussion | Part VII §7.25 |
| `KodeKloud.sh` | CAIC | Container-runtime prereqs + flannel v0.20.2 with `--iface=eth0`; `--apiserver-cert-extra-sans` | Parts I §1.1, §1.5 |
| `cp.history.txt` | CAIC | Shell history from the control plane | Part I |

---

## B.15 `explore-services/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `cluster-ip.yaml`, `load-balancer.yaml`, `node-port.yaml` | SN | The three Service types, side by side | Part III §3.2 |
| `services.log` | SN | All three types plus the default `kubernetes` Service, captured together | Part III §3.2 |
| `multid/ingress.yaml` | SN | Ingress, path `/luna`, `Exact` | Part III §3.5 |
| `multid/np.yaml` | SN | NetworkPolicy for the multi-container set | Part III §3.4 |
| `multid/pod.yaml` | WS | The pod with the "no labels so it could not be exposed" note | Part III §3.2, Part VII §7.28 |
| `multid/service.yaml` | SN | Service over the `multid` pods | Part III §3.2 |
| `pods/0.pod.yaml` … `04.pod-with-command.yaml` | WS | Progressive pod variants, ending with an explicit `command` | Part II §2.6 |
| `pods/cosmos-services.yaml` | SN | 8 Services for luna/lyra/nova/vega as ClusterIP + NodePort | Part III §3.2 |
| `pods/luna-running.yaml`, `vega-running.yaml`, `vega.yaml` | WS | Pod specs at various states | Part II §2.1 |
| `pods/multi-container-pod.yaml` | WS | Multi-container pod with `emptyDir` | Part II §2.4 |
| `pods/sample-pod-commands.yaml` | WS | The `command`/`args` trap, verbatim | Part II §2.6 |
| `pods/incremental.sh`, `my-commands.sh` | WS/SN | Exploratory command logs | Part II, Part III |

---

## B.16 `cluster-upgrade/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `cluster-upgrade.log` | CAIC | 27.6 KB of upgrade output | Part I §1.9 |
| `history.sh` | CAIC | v1.29.3 upgrade: `drain --force --delete-emptydir-data`, `uncordon` **without** `sudo` | Part I §1.9 |

---

## B.17 `troubleshooting/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `application.log` | TS | Application error log | Part VI §6.2 |
| `describe-node.log` | TS | A `NotReady` node description | Part VI §6.4 |
| `events.log` | TS | Cluster event stream | Part VI §6.2 |
| `ip-172-31-40-74.yaml` | CAIC | A control-plane node's spec | Part I |
| `kube-api-server.log` | TS | 66 KB of apiserver output | Part VI §6.3 |
| `networking.log` | SN/TS | Network troubleshooting capture | Part VI §6.5 |
| `service.log` | SN/TS | Service troubleshooting capture | Part VI §6.5 |
| `top.log` | TS | `kubectl top` output | Part VI §6.6 |
| `app/mysql.yaml`, `app/pod.yaml` | TS/SN | Cross-namespace `mysql-service` / `DB_Host` — the DNS drill | Part VII §7.19 |

---

## B.18 `yaml/` and `configmap/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `yaml/nginx/{pod,deployment,replicaset,service}.yaml` | WS/SN | Minimal nginx reference manifests | Parts II §2.3, III §3.2 |
| `yaml/nginx/ubuntu.yaml` | WS | A bare ubuntu pod | Part II §2.1 |
| `yaml/nginx/ipconfig.txt` | SN | Network configuration capture | Part III §3.1 |
| `yaml/redis/{pod,deployment,replicaset,service}.yaml` | WS/SN | Same set with `containerPort: 6379` | Parts II §2.3, III §3.2 |
| `configmap/config-map.yaml` | ST | A full `nginx.conf` in a ConfigMap | Part IV §4.3 |
| `configmap/pod.yaml` | ST | ConfigMap mounted as a volume | Part IV §4.3 |

---

## B.19 `basic-k8s/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `basic-labs.txt` | **all domains** | 1,300+ lines of worked labs: Docker, kubeadm init flags, pods, imagePullPolicy, labels/selectors, ReplicaSets, Services + MetalLB, DaemonSets, namespaces, ResourceQuota, env/ConfigMap/Secrets, rolling update + `change-cause`, Recreate, **blue/green**, emptyDir/hostPath/PV+PVC, RBAC + context switching, user certificates, **ingress-nginx install**, hotel/tea/coffee Ingress, **Helm** | See Appendix C §C.1 for the full per-section landing map. New material: Parts I §1.4, II §2.3a–2.3c/§2.9a, III §3.2a–3.2b, IV §4.2a–4.2b, V §5.3a/§5.8a, Appendix E |

---

## B.20 `my-certificate/`

| File | Domain | Topic | Covered in |
|---|---|---|---|
| `farinaz-ghasemi-*-certificate.pdf` | — | A 720 KB CKA certificate PDF — binary, not mergeable | — |

---

## B.21 The ten things your repo documents that most candidates get wrong

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

6. **`snapshot restore` only creates a new data directory** — nothing changes until you point etcd at it, by editing
   `/etc/kubernetes/manifests/etcd.yaml` (stacked) or `systemctl stop etcd` + restore + `chown -R etcd:etcd`
   (systemd). (`last-try/questions.sh` Q25, `practice-on-paper/practice-on-paper.sh`,
   `my-steps-etcd-systemctl.sh`, `shells/etcd-explore.sh`)

7. **`base64` wraps at 76 characters**, so a CSR `request` field needs `| tr -d "\n"` or `base64 -w 0` or you get an
   interpretation error. (`mock-exam-2.sh`, `23-certificate-signing-request.sh`)

8. **`kubectl set image` takes `<container-name>=<image>`**, and the container name is not the deployment name.
   (`mock-exam-2.sh`)

9. **`kubectl uncordon` must not be run with `sudo`** — it reads the kubeconfig from the invoking user's home.
   (`cluster-upgrade/history.sh`)

10. **A short Service name only resolves in the Service's own namespace.** From a pod in `web`, `auth-db` in `data`
    needs `auth-db.data.svc.cluster.local` or `auth-db.data`.
    (`last-try/gb-trouble-shooting.sh`, `mock-exam-2.sh`)


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

## Appendix C — Your `basic-k8s` / `basic labs.txt` CKA Notes

**STATUS: MERGED.** The file arrived (as `basic labs.txt`, on the `main` branch of the repo, after two failed attachment
attempts). It is 1,300+ lines of worked labs covering Docker, Kubernetes fundamentals, controllers, Services, storage,
RBAC, certificates, Ingress and Helm — and it turned out to contain a substantial amount of material that the rest of
the repository did not have.

This appendix is the **intake map**: what the file contained, where each lab landed, and what was genuinely new.

A verbatim copy of the source is kept at **`basic-k8s/basic-labs.txt`** in the repository so nothing is lost.

---

## C.1 Where every section of `basic-k8s/basic-labs.txt` landed

| # | Section in the file | Landed in | New? |
|---|---|---|---|
| 1 | Docker Lab — lifecycle, interactive/detached, port publishing | [Appendix E §E.1](#appendix-e--docker-and-helm-foundations) | **NEW** |
| 2 | Dockerfile — build, tag, push, login | [Appendix E §E.1.4–E.1.5](#appendix-e--docker-and-helm-foundations) | **NEW** |
| 3 | K8s Install Ubuntu — `install.sh`, `kubeadm init` flags, `alias k` | [Part I §1.4a](#part-i--cluster-architecture-installation--configuration) | **NEW** flags |
| 4 | Pods — `k run`, `describe`, `explain`, `curl <pod-IP>` | [Part I §1.4b](#part-i--cluster-architecture-installation--configuration) (`explain`), [Part II §2.1](#part-ii--workloads--scheduling) | `explain` walkthrough **NEW** |
| 5 | Multi-container pod — `exec -c con2` | Part II §2.4 | covered |
| 6 | **Image Pull Policy** — Always / IfNotPresent / Never | [Part II §2.3a](#part-ii--workloads--scheduling) | **NEW** |
| 7 | Labels and Selectors — `--show-labels`, `env in (...)` | [Part II §2.9a](#part-ii--workloads--scheduling) | set-based **NEW** |
| 8 | Replica Set — create, scale, self-healing | Part II §2.2 | covered |
| 9 | **Set-based ReplicaSet** — `matchExpressions`, `operator: In` | [Part II §2.9a](#part-ii--workloads--scheduling) | **NEW** |
| 10 | Services — ClusterIP / NodePort / LoadBalancer | Part III §3.2 | covered |
| 11 | **MetalLB** — `IPAddressPool`, bare-metal LoadBalancer | [Part III §3.2a](#part-iii--services--networking) | **NEW** |
| 12 | DaemonSet — `myds`, delete a pod and watch it return | Part II §2.7 | covered |
| 13 | Namespace — `create ns`, `-n`, `namespace:` in metadata | Part I §1.3 | covered |
| 14 | ResourceQuota — `dev-quota` with pods/cpu/memory | Part I §1.3, Part II §2.10 | covered |
| 15 | Environment — plain key / ConfigMap / Secrets, `envFrom` | **Part V §5.6** (`envFrom` forms) | `envFrom` **NEW** |
| 16 | **`change-cause` annotation** + `rollout history` / `undo` / `--to-revision` | [Part II §2.3b](#part-ii--workloads--scheduling) | **NEW** |
| 17 | Recreate — `strategy: type: Recreate` | Part II §2.3 | covered |
| 18 | **Blue/green deployment** — two Deployments, switch the Service | [Part II §2.3c](#part-ii--workloads--scheduling) | **NEW** |
| 19 | **`emptyDir`** — the on-node `/var/lib/kubelet/pods/...` walkthrough | [Part IV §4.2a](#part-iv--storage) | **NEW** |
| 20 | HostPath — same walkthrough, data survives the pod | Part IV §4.8 | covered |
| 21 | **PV/PVC with `volumeName`** — explicit binding, `ReadWriteMany` | [Part IV §4.2b](#part-iv--storage) | **NEW** |
| 22 | RBAC — Role, RoleBinding, `auth can-i`, cluster-scoped | Part V §5.3–5.4 | covered |
| 23 | **Proving RBAC by switching context** — `use-context pandey`, run the command | [Part V §5.3a](#part-v--security) | **NEW** |
| 24 | **User certificate** — `genrsa` → `req` → CSR with `groups:` → approve → `--embed-certs` | [Part V §5.8a](#part-v--security) | **NEW** details |
| 25 | **Ingress controller install** — MetalLB then ingress-nginx from the repo | [Part III §3.2a–3.2b](#part-iii--services--networking) | **NEW** |
| 26 | **hotel/tea/coffee** — one Ingress, three paths, `rewrite-target` | **Part III §3.2b** | covered (pattern) |
| 27 | **Helm** — repo, search, install, list, uninstall | [Appendix E §E.2](#appendix-e--docker-and-helm-foundations) | **NEW** |

---

## C.2 The genuinely new material, in one place

Ten things from `basic labs.txt` were not anywhere else in the repository, and are now merged:

1. **Docker fundamentals and Dockerfiles** — Appendix E §E.1. The repo had no container-runtime material at all, and
   `Deployments/DockerFile` was the only Dockerfile in it.
2. **`imagePullPolicy`** — Part II §2.3a. The `:latest` → `Always` default rule, and the `ErrImageNeverPull` vs
   `ImagePullBackOff` distinction.
3. **Set-based selectors** — Part II §2.9a. `--selector 'env in (prod,dev)'`, `notin`, `Exists`, `DoesNotExist`, and the
   same three operators in a ReplicaSet's `matchExpressions`.
4. **`change-cause` and the revision lifecycle** — Part II §2.3b. `kubectl annotate deploy mydep
   kubernetes.io/change-cause=...`, `rollout history`, `rollout undo --to-revision=N`.
5. **Blue/green deployment** — Part II §2.3c. Two Deployments and a Service whose selector discriminates on a
   `version:` label, with the cutover being a single `kubectl edit svc`.
6. **MetalLB** — Part III §3.2a. The `IPAddressPool` CRD that makes `LoadBalancer` work on bare metal, and the reason
   `EXTERNAL-IP` is `<pending>` without it.
7. **Installing the ingress controller** — Part III §3.2b. MetalLB first, then `ingress-nginx/deploy/static/provider/cloud/deploy.yaml`.
8. **`emptyDir` on the node** — Part IV §4.2a. The `/var/lib/kubelet/pods/<UID>/volumes/kubernetes.io~empty-dir/<name>/`
   path, plus the `sizeLimit` and `medium: Memory` answers to your own *"Task: Find a way to define size limit in
   emptydir type of storage"*.
9. **`volumeName` explicit binding** — Part IV §4.2b. Pinning a PVC to a specific PV, and using `ReadWriteMany`.
10. **Proving a permission by using it** — Part V §5.3a. `kubectl config use-context pandey`, then running the command
    and reading the `Forbidden:` error, which proves far more than `auth can-i`.
11. **CSR `groups:` and `--embed-certs`** — Part V §5.8a. The `system:authenticated` group, and why the kubeconfig must
    be self-contained.

---

## C.2 The lab-environment facts this file establishes

Everything else in this document assumes a kubeadm cluster. `basic labs.txt` pins down the specifics of *yours*:

| Fact | Value | Where it came from |
|---|---|---|
| Cluster build | `pandeysp1/ubuntu-k8s/install.sh` then a manual `kubeadm init` | §"K8s Install Ubuntu" |
| Pod CIDR | `10.244.0.0/16` | `--pod-network-cidr` |
| Service CIDR | `10.96.0.0/16` | `--service-cidr` |
| kubelet cert paths | `/etc/kubernetes/pki/` | implied by kubeadm |
| User images | `quay.io/pandeysp/*` | every `image:` line |
| Lab environment | KillerCoda, with a fixed set of exposed node ports | *"go to killercoda right side → select target port"* |
| Shell alias | `k` = `kubectl` | `alias k=kubectl` |
| Pre-flight checks | bypassed with `--ignore-preflight-errors=all` | the init command |

---

## C.3 Your notes, preserved verbatim

**[Your note]** — the emptyDir task you set yourself:

> *Task: Find a way to define size limit in emptydir type of storage*
> *Doc of K8s*

The answer is `emptyDir.sizeLimit`, documented in Part IV §4.2a.

**[Your note]** — on the two-terminal CSR workflow:

> *open a new tab*
> *`cat pandey.csr | base64 -w 0`*
> *copy the content to previous tab and paste in csr request field*

**[Your note]** — the same, for extracting the issued certificate:

> *copy the certificate and open a new tab*
> *`echo <pastethe certificate> | base64 -d > pandey.crt`*
> *switch back tyo previous tab*

Both are captured, with the single-command alternative that avoids the copy-paste, in Part V §5.8a.

**[Your note]** — on the blue/green cutover:

> *go to version line and change the version from blue to green*
> *save and exit*
> *reload the page*

**[Your note]** — on hostPath outliving the pod:

> *even you have delete the pod the files will remian in the node /mnt directory*
> *and if you spin your pod again and its created in the same node, the files will be present in the container*

**[Your note]** — on the `stagging` label. Your `set-rs.yaml` selects on `app in (dev, stagging)` — a typo for
`staging`, but it is spelled identically in the selector and in the labels, so the ReplicaSet adopts the pods anyway.
That is the right lesson: Kubernetes does not care what a label *means*, only that the selector and the labels agree.

**[Your note]** — the typos in your file that are worth naming, because they are exactly what muscle memory gets wrong:
`docer exec` (missing `k`), `k config viewe`, `k desribe deploy mydep`, `k get ppods`, `k set image i`,
`--country=IN` (openssl wants `-subj "/C=IN/ST=delhi/CN=pandey"`), `myclsuterbind`, `trainig-web-server`,
`emphemeral`. Every one of them produces either a command-not-found error or — worse — a silently wrong object.
Always `cat` a generated manifest before applying it.

---

## C.4 What this file does **not** contain

So you know what to look for elsewhere:

| Missing from `basic labs.txt` | Covered in |
|---|---|
| etcd backup/restore | Part I §1.9, Part VII §7.25 |
| Cluster upgrades | Part I §1.11 |
| Node lifecycle, drain/cordon | Part I §1.12 |
| NetworkPolicy | Part III §3.4, Part VII §7.30 |
| Ingress scenarios (TLS, canary, host routing) | Part VII §7.29 |
| Probes (liveness/readiness) | Part II §2.8, Part VII §7.4 |
| StatefulSets, Jobs, CronJobs | Part II §2.7 |
| Troubleshooting | Part VI, Part VII §7.18–7.19 |
| Mock exams | Part VII §7.26–7.28 |
| Static pods | Part I §1.6 |
| Custom schedulers | Part I §1.7 |
| Metrics-server | Part I §1.8 |

---

## C.5 If you supply more CKA notes

Any further `basic-k8s` material will be folded in the same way: transcribed verbatim into this appendix, with a
`**CKA domain:**` and `**Merged into:**` line under each lab, and anything that is genuinely new added as a numbered
section in the relevant Part. Appendix B's crosswalk is updated with the file, and the single-file deliverable is
rebuilt and re-validated.

\pagebreak

## Appendix D — `kubectl` and JSONPath Quick Reference

Consolidated from `kubectl-quick-refrence.sh` and `jsaon-path-examples.sh`, plus the command patterns that recur across
the labs. Everything here is a **command that appeared in your own working sessions**.

---

## D.1 Aliases and shell setup

```bash
# your file's opening lines
alias k=kubectl
complete -o default -F __start_kubectl k
```

```bash
# The equivalent, persisted
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

# Permanent completion, bash
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
source <(kubectl completion bash)

# Permanent completion, zsh
kubectl completion zsh | sudo tee "${fpath[1]}/_kubectl" > /dev/null
```

`kubectl -A` is the short form of `kubectl --all-namespaces` — your file flags it explicitly because it is the single
most-used flag.

---

## D.2 Config and contexts

```bash
kubectl config view                                  # merged kubeconfig
kubectl config view --raw                            # + raw certificate data and exposed secrets
kubectl config view --kubeconfig=/root/my-kube-config

kubectl config get-contexts                          # current + all
kubectl config get-contexts -o name                  # context names only
kubectl config current-context
kubectl config use-context cluster-name

kubectl config set-cluster my-cluster-name --server=https://1.2.3.4 --certificate-authority=ca.crt
kubectl config set-cluster my-cluster-name --proxy-url=my-proxy-url
kubectl config set-credentials my-user --client-certificate=admin.crt --client-key=admin.key
kubectl config set-context my-ctx --cluster=my-cluster-name --user=my-user
kubectl config set-context my-ctx --namespace=project-tiger
kubectl config use-context my-ctx --kubeconfig=/root/my-kube-config
```

Reading a kubeconfig with jsonpath — the pattern from `jsaon-path-examples.sh`:

```bash
kubectl config view -o jsonpath='{.users[*].name}'
kubectl config view --kubeconfig=/root/my-kube-config -o jsonpath='{.users[*].name}' > /opt/outputs/users.txt
kubectl config view --kubeconfig=my-kube-config -o jsonpath="{.contexts[?(@.context.user=='aws-user')].name}"
kubectl config view | grep "current-context" | awk '{print $2}'      # the no-kubectl form (Drill 1)
```

---

## D.3 Cluster information

```bash
kubectl cluster-info                                    # master + services addresses
kubectl cluster-info dump                               # dump current state to stdout
kubectl cluster-info dump --output-directory=/path/to/cluster-state
```

---

## D.4 Creating and applying

```bash
kubectl apply -f ./my-manifest.yaml
kubectl apply -f https://example.com/manifest.yaml
kubectl apply -f -                                     # read from stdin
kubectl apply -R -f ./directory/                       # recursive

kubectl create deployment nginx --image=nginx
kubectl create job hello --image=busybox:1.28 -- echo "Hello World"
kubectl create cronjob hello --image=busybox:1.28 --schedule="*/1 * * * *" -- echo "Hello World"
kubectl create namespace project-tiger
kubectl create serviceaccount processor -n project-hamster
kubectl create secret generic secret2 --from-literal=APP_USER=user1 --from-literal=APP_PASS=1234
kubectl create secret tls frontend-tls --cert=server.crt --key=server.key
kubectl create role processor --verb=create --resource=secrets,configmaps -n project-hamster
kubectl create rolebinding processor --role=processor --serviceaccount=project-hamster:processor -n project-hamster
kubectl create clusterrole pvviewer-role --verb=list --resource=persistentvolumes
kubectl create clusterrolebinding pvviewer-role-binding --clusterrole=pvviewer-role --serviceaccount=default:pvviewer
kubectl create configmap nginx-config --from-file=nginx.conf
kubectl create token processor                          # a SA token, on demand
```

**`kubectl explain`** — the in-terminal documentation, and your own `##todo this is something like man in unix`:

```bash
kubectl explain pods
kubectl explain pod.spec.containers.resources
kubectl explain pod.spec.containers.resources.limits
kubectl explain deployment --recursive
```

This is the single most useful command you do not use enough. On a proctored exam with no browser, it replaces the API
reference entirely.

---

## D.5 Getting, filtering and formatting

```bash
kubectl get pods
kubectl get pods -A                                        # --all-namespaces
kubectl get pods -n project-tiger
kubectl get pods -o wide
kubectl get pods --show-labels
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --selector=app=nginx
kubectl get node --selector='!node-role.kubernetes.io/control-plane'
kubectl get all                                            # every resource in the namespace
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl diff -f ./my-manifest.yaml                         # dry-run diff before applying

kubectl get node -o custom-columns='NODE_NAME:.metadata.name,STATUS:.status.conditions[?(@.type=="Ready")].status'
kubectl get pv --sort-by=.spec.capacity.storage -o=custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage
```

**A warning about two entries in your file:**

```bash
kubectl events --types=Warning          # ← NOT a real command in any current kubectl
kubectl get pv --all-namespaces         # ← meaningless; PVs are cluster-scoped
```

Use instead:

```bash
kubectl get events --all-namespaces --field-selector type=Warning --sort-by=.lastTimestamp
kubectl get events -A --types=Warning     # also not valid; --types does not exist
```

---

## D.6 Updating

```bash
kubectl rollout history deployment frontend
kubectl rollout history daemonset frontend
kubectl rollout history replicaset frontend
kubectl rollout history statefulset frontend

kubectl rollout undo frontend                          # previous revision
kubectl rollout undo frontend --to-revision=2          # a specific revision
kubectl rollout status -w frontend                     # watch until completion
kubectl rollout restart frontend                       # rolling restart, no change needed

kubectl replace --force -f ./pod.json                  # delete + recreate; causes an outage
kubectl expose rc nginx --port=80 --target-port=8000
kubectl set image deployment/nginx-deploy nginx=nginx:1.17
kubectl set serviceaccount deploy/<name> <sa>
kubectl set env deploy/foo KEY=value

# Update a single-container pod's image version (tag) to v4
kubectl get pod mypod -o yaml | sed 's/\(image: myimage\):.*$/\1:v4/' | kubectl replace -f -

kubectl label pods my-pod new-label=awesome                        # add
kubectl label pods my-pod new-label-                               # remove
kubectl label pods my-pod new-label=new-value --overwrite          # overwrite

kubectl annotate pods my-pod icon-url=http://goo.gl/XXBTWq         # add
kubectl annotate pods my-pod icon-url-                             # remove

kubectl autoscale deployment foo --min=2 --max=10
```

> **Exam note** — the `sed` one-liner is the *only* way to change a running pod's image, because a pod spec is immutable
> (Part II §2.4). But on the exam, `kubectl delete pod X --force && kubectl apply -f /tmp/kubectl-edit-*.yaml` is faster
> and more reliable.

---

## D.7 Patching, editing, scaling, deleting

```bash
kubectl patch pod manual-schedule -p '{"spec":{"nodeName":"cluster2-controlplane1"}}'
kubectl patch svc service-am-i-ready -p '{"spec":{"selector":{"id":"cross-server-ready"}}}' -n default
kubectl patch pv pv-1 -p '{"spec":{"claimRef": null}}'
kubectl patch pvc alpha-mysql -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'   # expand a PVC
kubectl patch deployment nginx -p '{"spec":{"strategy":{"type":"Recreate"}}}'
kubectl patch storageclass standard -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch --local -f pod.yaml -p '{"spec":{"containers":[{"name":"api","image":"v2"}]}' -o yaml > new.yaml

kubectl edit pod kube-controller-manager-controlplane -n kube-system
kubectl edit service hr-web-app-service

kubectl scale --replicas=3 rs/foo
kubectl scale --replicas=3 -f foo.yaml
kubectl scale --current-replicas=2 --replicas=3 mysql        # conditional scale
kubectl scale --replicas=5 rc/foo rc/bar rc/baz
kubectl scale deploy nginx-deploy --replicas=3

kubectl delete pod unwanted --now                            # no grace period
kubectl delete pods,services -l name=myLabel
kubectl delete pod X --force
kubectl delete -f ./manifest.yaml
```

---

## D.8 Logs, exec, debugging

```bash
kubectl logs my-pod
kubectl logs my-pod --previous                             # previous instantiation
kubectl logs my-pod -c my-container                        # named container
kubectl logs -f my-pod                                     # follow
kubectl logs -f -l name=myLabel --all-containers
kubectl logs data-handler -c proc -n backend | grep -i error > /k8s/0002/errors.txt
kubectl logs deploy/nginx --since=1h --tail=100

kubectl run -i --tty busybox --image=busybox:1.28 -- sh     # interactive
kubectl run nginx --image=nginx -n mynamespace
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml

kubectl attach my-pod -i
kubectl port-forward my-pod 5000:6000                      # local:pod

kubectl exec my-pod -- ls /
kubectl exec --stdin --tty my-pod -- /bin/sh
kubectl exec my-pod -c my-container -- ls /
kubectl exec -it busybox -- nslookup nginx-resolver-service
kubectl exec my-pod -c c1 -- printenv MY_NODE_NAME
```

---

## D.9 Metrics, nodes, taints

```bash
kubectl top pod
kubectl top pod POD_NAME --containers
kubectl top pod POD_NAME --sort-by=cpu                     # or --sort-by=memory
kubectl top pod -n web --sort-by=cpu --selector app=auth
kubectl top node
kubectl top node my-node

kubectl cordon my-node                                     # mark unschedulable
kubectl uncordon my-node                                   # mark schedulable
kubectl drain my-node                                      # evict gracefully
kubectl drain my-node --force --delete-emptydir-data
kubectl drain my-node --ignore-daemonsets

# If a taint with that key and effect already exists, its value is replaced as specified.
kubectl taint nodes foo dedicated=special-user:NoSchedule
kubectl taint nodes node01 env_type=production:NoSchedule
kubectl taint nodes node01 env_type=production:NoSchedule-  # remove
```

> **Exam note** — `kubectl uncordon` must **not** be run with `sudo` (your `cluster-upgrade/history.sh` note). The
> kubeconfig it needs is in the invoking user's home; under `sudo` it reads `/root/.kube/config` and fails.

---

## D.10 API resources

```bash
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false
kubectl api-resources -o name
kubectl api-resources -o wide
kubectl api-resources --verbs=list,get
kubectl api-resources --api-group=extensions
```

---

## D.11 JSONPath — the patterns that actually appear

`jsaon-path-examples.sh` is a working log of jsonpath experiments. The distilled rules:

### Object and array access

```bash
kubectl get nodes -o jsonpath='{.items[1]}'                    # the second item
kubectl get nodes -o jsonpath='{.items[*].metadata.name}'      # every name
kubectl get pod mypod -o jsonpath='{.spec.containers[0]}'
kubectl get pod mypod -o jsonpath='{.spec.containers[0].image}'
```

Note the difference between `.items[1]` (index) and `.items[*]` (all). In JSONPath, `[*]` and `.*` are both "all
elements"; your log shows both `$.items[*].name` and `$.*.metadata.name`.

### Printing one item per line

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.status.phase}{"\n"}{end}'
```

`range`/`end` is the only way to get newlines into jsonpath output. `{ "\n" }` must be double-quoted inside the
expression.

### Filters — the `[?(...)]` form

```bash
# Pick one entry out of an array of objects
kubectl get node -o custom-columns='NODE_NAME:.metadata.name,STATUS:.status.conditions[?(@.type=="Ready")].status'
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}'

# Select pods on a given node
kubectl get pods -A -o jsonpath='{.items[?(@.spec.nodeName=="node01")].metadata.name}'

# Select a kube-proxy pod on a specific node
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[?(@.spec.nodeName=="cluster2-node1")].metadata.name}'

# Select by a field value
kubectl get pods -A -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}'
```

Note the quoting: `@.type=="InternalIP"` uses **double** quotes inside a **single**-quoted jsonpath expression. Swapping
them breaks the shell.

### Escaping dots and slashes in keys

Keys that contain `.` or `/` must be escaped with a backslash inside the jsonpath expression:

```bash
kubectl get node cluster1-node1 -o jsonpath='{.metadata.annotations.\.static-pod-hostname-suffix}'
kubectl get configmap -n kube-system kube-proxy -o=jsonpath='{.data.kubeconfig}'
kubectl get nodes -o jsonpath='{.items[*].metadata.labels.node-role\.kubernetes\.io/control-plane}'
```

Your `mock-exam-2.sh` note says exactly this:

> *in the script we have to escape the dot char with backslash*

### Status and containerState fields

From the second half of your file:

```bash
cat k8status.json | jpath $.status.phase
cat k8status.json | jpath $.status.containerStatuses[0].state.waiting.reason
cat k8status.json | jpath $.status.containerStatuses[1].restartCount
cat input.json  | jpath $.spec.nodeName
cat input.json  | jpath $.spec.containers[0].image
cat podslist.json | jpath $.*.metadata.name
cat userslist.json | jpath $.users[*].name
```

### The `jpath` vs `jq` distinction

`jpath` (from the `github.com/jmespath` tooling) and `jq` are **different** programs with different syntax. Your log mixes
both forms:

```bash
# jq syntax
jq -r '.items[1].metadata.name'
jq -r '.items[] | select(.spec.nodeName=="node01") | .metadata.name'
jq -r '.items[].metadata.name'

# jsonpath syntax (what kubectl supports natively)
kubectl get nodes -o jsonpath='{.items[1].metadata.name}'
kubectl get nodes -o jsonpath='{.items[?(@.spec.nodeName=="node01")].metadata.name}'
```

> **Exam note** — on the CKA you will almost always want `kubectl ... -o jsonpath=` or `-o custom-columns=`, not an
> external tool. `custom-columns` is the more readable choice when the output goes into a file, and it also supports the
> `[?(...)]` filter.

---

## D.12 The `-o` matrix

| Flag | Output | Use for |
|---|---|---|
| *(none)* | human table | reading |
| `-o wide` | human table + node, IP, node selector | quick orientation |
| `-o yaml` | the full object | editing, saving, re-applying |
| `-o json` | the full object, JSON | piping into `jq` |
| `-o name` | `<type>/<name>` only | feeding into `xargs` |
| `-o jsonpath='...'` | selected fields | extracting a value |
| `-o custom-columns=A:..,B:..` | a table of selected fields | producing a readable report |
| `--dry-run=client -o yaml` | a manifest on stdout, nothing created | **the single most useful flag combination on the exam** |
| `--dry-run=server` | server-side validation, still nothing created | validating before applying |

```bash
# The canonical "generate a manifest, then edit it" workflow
kubectl run manual-schedule --image=httpd:2.4-alpine --restart=Never --dry-run=client -o yaml > manual-schedule.yaml
vi manual-schedule.yaml
kubectl apply -f manual-schedule.yaml
```

---

## D.13 Imperative `--dry-run` matrix

From Part III §3.5, repeated here for convenience. The flag is `--dry-run=client -o yaml` in every row:

| Command | Produces |
|---|---|
| `kubectl run X --image=nginx --restart=Never -o yaml --dry-run=client` | a Pod |
| `kubectl create deployment X --image=nginx --replicas=3 -o yaml --dry-run=client` | a Deployment |
| `kubectl create job X --image=busybox -o yaml --dry-run=client` | a Job |
| `kubectl create cronjob X --image=busybox --schedule="*/1 * * * *" -o yaml --dry-run=client` | a CronJob |
| `kubectl expose pod X --port=80 -o yaml --dry-run=client` | a Service |
| `kubectl expose deployment X --port=80 --type=NodePort -o yaml --dry-run=client` | a NodePort Service |
| `kubectl create secret generic X --from-literal=k=v -o yaml --dry-run=client` | a Secret |
| `kubectl create configmap X --from-literal=k=v -o yaml --dry-run=client` | a ConfigMap |
| `kubectl create role X --verb=get --resource=pods -o yaml --dry-run=client` | a Role |
| `kubectl create clusterrole X --verb=get --resource=pods -o yaml --dry-run=client` | a ClusterRole |
| `kubectl create rolebinding X --role=X --user=u -o yaml --dry-run=client` | a RoleBinding |
| `kubectl create clusterrolebinding X --clusterrole=X --serviceaccount=ns:sa -o yaml --dry-run=client` | a ClusterRoleBinding |
| `kubectl create serviceaccount X -o yaml --dry-run=client` | a ServiceAccount |
| `kubectl create ingress X --rule="host/*=svc:80" -o yaml --dry-run=client` | an Ingress |
| `kubectl create namespace X -o yaml --dry-run=client` | a Namespace |
| `kubectl create resourcequota X --hard=cpu=1 -o yaml --dry-run=client` | a ResourceQuota |
| `kubectl create limitrange X --default=cpu=1 -o yaml --dry-run=client` | a LimitRange |
| `kubectl create priorityclass X --value=100 -o yaml --dry-run=client` | a PriorityClass |
| `kubectl create certificate X --from-file=crt -o yaml --dry-run=client` | a Secret of type `kubernetes.io/tls` |

Not available as `kubectl create`: `persistentvolume`, `persistentvolumeclaim`, `networkpolicy`, `daemonset`,
`statefulset`, `replicaset`. Write those as YAML, or generate and strip a Deployment.

\pagebreak

## Appendix E — Docker and Helm Foundations

From `basic-k8s/basic-labs.txt`. Kubernetes does not exist in a vacuum — before the pods there is a container runtime,
and after the manifests there is a package manager. This appendix covers both, in the order your lab does.

**Everything here uses your own images where the original used a public one.** The policy throughout this document is
*keep the original, add an alternative* — so the original command is shown first and the `quay.io/pandeysp/*`
substitution is a commented line directly beneath it.

---

## E.1 Docker Lab — the container primitives

### E.1.1 Container lifecycle

```bash
docker --help
docker ps                    # running containers
docker ps -a                 # all containers, including stopped
docker images                # local images
docker version
docker search redis          # search Docker Hub
```

**Running and naming:**

```bash
docker run --name ubuntu                       # named "ubuntu", no image → error
docker run --name centos-1 ubuntu              # named centos-1, image ubuntu
docker run --name centos-3 ubuntu /bin/bash    # overrides CMD
docker run --name centos-5 ubuntu sleep 50     # exits after 50 seconds

docker ps -a
# CONTAINER ID   IMAGE     COMMAND       STATUS                     PORTS     NAMES
# a1b2c3d4e5f6   ubuntu    "/bin/bash"   Exited (0) 3 seconds ago             centos-3
# f6e5d4c3b2a1   ubuntu    "sleep 50"    Exited (0) 51 seconds ago            centos-5

docker rm 1a57e4d20ff0 23d7224aead6            # remove by ID, several at once
docker rm 1041ce05339d 6bc80fcfbd2f 3b83c473fc0b
docker ps -a
```

### E.1.2 Interactive vs detached

| Flag | Effect | Use for |
|---|---|---|
| `-i` | keep STDIN open | pipes |
| `-t` | allocate a pseudo-TTY | a shell |
| `-d` | **detached** — run in the background | servers |
| `-it` | interactive TTY | `docker exec ... bash` |
| `-dit` | detached **and** TTY-allocated | a server you may want to attach to later |

```bash
docker run -i  --name con1 ubuntu          # stdin open, no TTY
docker run -it --name con2 ubuntu          # you get a shell
docker run -dit --name con3 ubuntu         # backgrounded, TTY ready

docer exec -it e399e0e44dee /bin/bash      # ← typo in your file; the correct form is:
docker exec -it e399e0e44dee /bin/bash     # exec INTO a running container
```

**[Your note]** — `docer exec` is a typo in the source. Worth naming because `docker exec` (not `run`) is the command
for entering a container that is already running. The mapping to Kubernetes is exact:

| Docker | Kubernetes |
|---|---|
| `docker exec -it <c> bash` | `kubectl exec -it <pod> -- bash` |
| `docker exec -it <c> -c <name> bash` | `kubectl exec -it <pod> -c <name> -- bash` |
| `docker logs <c>` | `kubectl logs <pod> -c <name>` |

### E.1.3 Port publishing

```bash
docker run -dit --name webserver -p 5000:80 nginx
docker ps -dit -p 5000:80 --name webserver nginx
docker run -dit -p 5000:80 --name webserver nginx
# Alt image: quay.io/pandeysp/nginx:latest

docker ps
# CONTAINER ID   IMAGE   COMMAND                  PORTS                                NAMES
# 9f8e7d6c5b4a   nginx   "/docker-entrypoint.…"   0.0.0.0:5000->80/tcp                 webserver

curl localhost        # nginx answers on 80 by default inside the container
curl localhost:80
curl localhost:5000   # the published port on the host
```

`-p 5000:80` means **host 5000 → container 80**. In Kubernetes the equivalent is a Service: `port` is the in-cluster
port, `targetPort` is the container port, and `nodePort` is the host port (Part III §3.2).

```bash
# Publish to a specific interface, and a specific host port
docker run -d -p 127.0.0.1:5000:80 nginx
docker run -d -p 5000:80/udp  nginx
docker run -d -P nginx                       # publish ALL exposed ports, random host ports
```

### E.1.4 Writing a Dockerfile

```dockerfile
# Dockerfile
FROM ubuntu:16.04
RUN apt-get update -y
RUN apt-get install apache2 -y
COPY index.html /var/www/html/index.html
EXPOSE 80
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
```

```bash
echo "<h1>WELCOME to DOCKERFILE</h1>" > index.html
cat index.html

docker build -t web-custom .
docker images
# REPOSITORY    TAG       IMAGE ID       CREATED          SIZE
# web-custom    latest    c3d4e5f6a7b8   5 seconds ago    214MB

docker run -dit --name demo web-custom
docker exec demo cat /var/www/html/index.html
docker ps
docker run -dit -p 5000:80 --name webserver web-custom
```

**The instruction set, in the order you will use them:**

| Instruction | What it does | Notes |
|---|---|---|
| `FROM` | The base image | must be first |
| `RUN` | Execute a command at **build** time | each one is a new layer |
| `COPY` / `ADD` | Copy files from the build context into the image | `ADD` also fetches URLs and untars; prefer `COPY` |
| `WORKDIR` | Set the working directory for later instructions | creates the dir if missing |
| `ENV` | Set an environment variable | persists into the running container |
| `EXPOSE` | **Document** a port | does **not** publish it — metadata only |
| `CMD` | The default command | overridable at `docker run` |
| `ENTRYPOINT` | The fixed executable | harder to override; combine with `CMD` for default args |
| `VOLUME` | Declare a mount point | creates an anonymous volume |
| `USER` | The user to run as | |
| `LABEL` | Metadata | |

**`CMD` vs `ENTRYPOINT` — the shell form vs the exec form.** This is the same trap as Kubernetes' `command` vs `args`
(Part II §2.6):

```dockerfile
# exec form — PID 1 is the process, signals are delivered, no shell involved
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]

# shell form — PID 1 is /bin/sh -c "...", signals are NOT delivered to the app
CMD /usr/sbin/apache2ctl -D FOREGROUND
```

The exec form (a JSON array) is the correct one for anything that must handle SIGTERM — which is every server, and every
`CMD` in a production image.

```dockerfile
# ENTRYPOINT fixed, CMD supplying the default arguments
ENTRYPOINT ["/usr/sbin/apache2ctl"]
CMD ["-D", "FOREGROUND"]

# docker run myimage -DFOREGROUND   → replaces the CMD, keeps the ENTRYPOINT
# docker run --entrypoint /bin/sh    → replaces both
```

**Layer caching.** Put the least-frequently-changing instructions **first**:

```dockerfile
FROM ubuntu:16.04
RUN apt-get update -y                          # changes rarely → cached
RUN apt-get install -y apache2                 # changes rarely → cached
COPY index.html /var/www/html/index.html       # changes often → invalidates only this layer
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
```

Putting the `COPY` before the `RUN apt-get install` means every edit to `index.html` re-downloads and re-installs
apache2.

### E.1.5 Tagging and pushing to your own registry

```bash
docker login
docker images
docker tag web-custom:latest <dockerusername>/us-train:v1
docker images
docker push <dockerusername>/us-train:v1

# Pull it back somewhere else
docker pull <dockerusername>/us-train:v1
```

**[Your note]** — your own images follow exactly this pattern, which is why every lab in this document can point at
`quay.io/pandeysp/*`:

```bash
# Build against your own registry
docker build -t quay.io/pandeysp/mywebapp:v1 .
docker push quay.io/pandeysp/mywebapp:v1

# Then in Kubernetes
k run pod1 --image quay.io/pandeysp/mywebapp
# Alt image: quay.io/pandeysp/mywebapp:latest
```

**Signup:** <https://hub.docker.com/> (for Docker Hub) or <https://quay.io/> (for your `quay.io/pandeysp/*` images).
Appendix A is the full catalog of the images you already have.

> **Exam note** — Docker itself is **not** on the CKA. The exam clusters run containerd, and the only container-runtime
> commands you need are `crictl` (Part VI §6.3). What *is* worth carrying over from this section is the mental model:
> `docker run -p 5000:80` → a NodePort Service; `docker exec` → `kubectl exec`; a `Dockerfile`'s `CMD` → a pod spec's
> `command`.

---

## E.2 Helm — the Kubernetes package manager

Artifact Hub: <https://artifacthub.io/>

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm
```

### E.2.1 Repositories

```bash
helm repo list
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo list
# NAME    URL
# bitnami https://charts.bitnami.com/bitnami

helm search repo bitnami | grep -i nginx
# NAME                 CHART VERSION   APP VERSION   DESCRIPTION
# bitnami/nginx        18.2.4          1.27.2        NGINX Open Source is a web server...

helm repo remove bitnami
helm repo list
```

```bash
# Searching everything on Artifact Hub
helm search hub nginx
helm search hub wordpress --max-col-width 80

# Inspecting a chart before installing it
helm show chart bitnami/nginx
helm show values bitnami/nginx
helm show values bitnami/nginx | grep -A3 service
helm pull bitnami/nginx --untar --untardir /tmp/charts
```

### E.2.2 The install / list / uninstall lifecycle

```bash
helm install trainig-web-server bitnami/nginx
# NAME: trainig-web-server
# LAST DEPLOYED: ...
# NAMESPACE: default
# STATUS: deployed
# REVISION: 1

k get pods,svc
# NAME                                          READY   STATUS    RESTARTS   AGE
# pod/trainig-web-server-nginx-xxxxx            1/1     Running   0          40s
#
# NAME                            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
# service/trainig-web-server-nginx   LoadBalancer   10.100.20.30   <pending>     80:31234/TCP

curl 10.111.38.74
```

**[Your note]** — `trainig-web-server` (missing an `i`) is the release name in your lab, and it works fine. Release
names are arbitrary strings; only their uniqueness within a namespace matters.

```bash
helm list -a
# NAME                   NAMESPACE   REVISION   STATUS   CHART         APP VERSION
# trainig-web-server     default     1          deployed nginx-18.2.4  1.27.2

helm uninstall trainig-web-server
helm list -a
k get pods,svc                    # everything the release created is gone
```

```bash
# Re-adding and reinstalling
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install trainig-web-server bitnami/nginx
ls -ltrh
helm list -a
```

### E.2.3 The commands that matter

```bash
helm install <release> <chart>                       # create
helm install <release> <chart> -n <ns> --create-namespace
helm install <release> <chart> -f values.yaml        # override defaults
helm install <release> <chart> --set service.type=NodePort --set replicaCount=3
helm install <release> <chart> --dry-run --debug      # render without installing
helm template <release> <chart>                       # render to stdout — no cluster needed

helm list -a                                          # all releases, all namespaces
helm list -a -n <ns>
helm status <release>
helm history <release>
helm get values <release>
helm get manifest <release>                           # the rendered manifests
helm get notes <release>

helm upgrade <release> <chart>
helm upgrade <release> <chart> -f values.yaml
helm rollback <release> <revision>
helm rollback <release> 1

helm uninstall <release>
helm uninstall <release> --keep-history
helm repo update
```

**What Helm actually produces.** A chart is templated YAML. The rendered output is exactly the manifests you would write
by hand:

```bash
helm template trainig-web-server bitnami/nginx | head -60
helm template trainig-web-server bitnami/nginx --set service.type=NodePort > nginx.yaml
kubectl apply -f nginx.yaml
```

```bash
# The values file is the interface
cat > values.yaml <<'EOF'
service:
  type: NodePort
  nodePort: 30080
replicaCount: 3
image:
  registry: quay.io
  repository: pandeysp/nginx
  tag: latest
EOF

helm install my-nginx bitnami/nginx -f values.yaml
k get svc
```

> **Exam note** — Helm is **not** on the CKA syllabus. It appears in LFS258 and in real clusters, and it is worth
> knowing that `helm template` is a fast way to generate correct manifests for an object you would otherwise write by
> hand. Do not spend exam-prep time here; spend it on Part VII.

---

## E.3 Part E self-check

1. `docker run -dit -p 5000:80 nginx` — which port is the host's, and which is the container's?
2. `EXPOSE 80` in a Dockerfile — does it publish the port?
3. Why is the exec form of `CMD` preferred over the shell form?
4. `docker exec -it <id> bash` fails with "container is not running". What does `docker ps -a` show?
5. `helm list -a` returns nothing but you installed a release a minute ago. What namespace is it in?
6. What does `helm template` do that `helm install --dry-run` does not?
7. You `docker tag web-custom:latest quay.io/pandeysp/mywebapp:v1` but forget to push. Does Kubernetes see the new tag?
8. Which Docker command maps to `kubectl logs -c <container>`?
