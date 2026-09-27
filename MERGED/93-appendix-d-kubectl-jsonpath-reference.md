# Appendix D — `kubectl` and JSONPath Quick Reference

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
