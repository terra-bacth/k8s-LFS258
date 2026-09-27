# Part VI — Troubleshooting

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
