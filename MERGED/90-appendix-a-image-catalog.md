# Appendix A — `quay.io/pandeysp/*` Image Catalog

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
