# Part III — Services & Networking

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
