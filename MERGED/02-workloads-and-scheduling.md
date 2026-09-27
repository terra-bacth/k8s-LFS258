# Part II — Workloads & Scheduling

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
