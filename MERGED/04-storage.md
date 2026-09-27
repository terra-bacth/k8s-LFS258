# Part IV — Storage

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
