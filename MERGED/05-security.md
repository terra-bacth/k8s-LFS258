# Part V — Security

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

### 8a. The full user-certificate flow, end to end — `basic labs.txt`

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
