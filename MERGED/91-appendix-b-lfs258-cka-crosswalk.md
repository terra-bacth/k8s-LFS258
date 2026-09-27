# Appendix B — LFS258 → CKA Crosswalk

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
