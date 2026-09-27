# Appendix B — LFS258 → CKA Crosswalk

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
