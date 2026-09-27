# Part VII — Exam Drills & Mock Exams

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
