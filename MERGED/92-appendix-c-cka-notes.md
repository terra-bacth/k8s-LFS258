# Appendix C — Your `basic-k8s` CKA Notes

**STATUS: RESERVED — awaiting the `basic-k8s` file.**

The `basic-k8s` text file containing your CKA labs was referenced but did not arrive in this workspace. Only the
LFS258 repository was delivered. Rather than guess at its contents, this appendix is pre-formatted and ready.

> **Good news, though.** While looking for a `lab.txt` file you asked about (there is none anywhere in the workspace),
> a second, complete survey of the repository turned up **266 non-`.git` files instead of 255** — the first survey had
> been silently truncated at 200 lines. The files it missed contained a great deal of CKA lab material, and all of it is
> now merged:
>
> * `last-try/questions.sh` — **740 lines, 25 fully worked CKA exam questions** (now [Part VII](07-exam-drills-and-mock-exams.md))
> * `mock-exam-1.sh`, `mock-exam-2.sh`, `mock-exam-3.sh` — three mock exams (Part VII §7.26–7.28)
> * `last-try/scenarios-ingress.txt` and `last-try/senarisos-np.txt` — 10 scenario questions, worked (Part VII §7.29–7.30)
> * `lightenin-labs/`, `practice-on-paper/`, `cluster-upgrade/`, `shells/`, `explore-services/`, `troubleshooting/`,
>   `yaml/`, `configmap/` — upgrade sequences, external-etcd drills, real log captures and reference manifests
> * `kubectl-quick-refrence.sh` and `jsaon-path-examples.sh` — consolidated as
>   [Appendix D](93-appendix-d-kubectl-jsonpath-reference.md)
>
> So most of what `basic-k8s` would have contributed is already covered. If the file adds anything beyond that, this
> appendix is where it goes.

---

## C.1 How to supply it

Any one of these works:

1. **Paste the text directly** into the chat. I will transcribe it into this appendix verbatim, preserving your code
   blocks and comments.
2. **Drop the file into the repository** — e.g. `MERGED/basic-k8s.txt` or `Labs/basic-k8s.md` — and tell me the path.
3. **Attach it to a follow-up message** so it lands in the workspace alongside the repo.

Once it is here I will:

* transcribe it into this appendix under a `## C.N <original heading>` structure, unchanged;
* add a `**CKA domain:**` and `**Merged into:**` line under each lab so it cross-links to Parts I–VII;
* add any labs it contains that Parts I–VI do not already cover, as new numbered sections in the relevant Part;
* update the [index](00-index.md) row for this appendix;
* update [Appendix B](91-appendix-b-lfs258-cka-crosswalk.md) with the new file.

---

## C.2 The structure each of your labs will be given

So you can see exactly what arrives, here is the template every lab in this document follows — your notes will be folded
into the same shape so the whole thing reads consistently:

```
### Lab <N>. <title>

**CKA domain:** <CAIC | Workloads & Scheduling | Services & Networking | Storage | Security | Troubleshooting>
**Merged into:** Part <X> §<Y>
**Repo file:** <path, if it also exists in the LFS258 repo>
**Alternative image:** quay.io/pandeysp/<image>:<tag>

#### Objective
<one or two sentences on what the task asks for>

#### Commands
<the exact commands you ran, in order>

#### Manifest
<the YAML, with the alt-image comment>

#### Explanation
<why it works, the concept behind it, and the fields that matter>

#### [Your note]
<your own annotation from the original file, verbatim>

#### Exam notes
<the gotchas, the traps, the time-savers>
```

---

## C.3 CKA domains your `basic-k8s` notes most likely cover

Mapping so nothing gets lost when the file arrives. If your notes touch any of these, it lands in the Part shown:

| Topic in your CKA notes | Lands in |
|---|---|
| Cluster components, `kubeadm init/join/upgrade`, HA control plane, etcd | Part I §1.1–1.4, §1.9, §1.11 |
| CNI plugin install, pod CIDR, `ip`/`iptables`, DNS (CoreDNS) | Part I §1.5, Part III §3.1, §3.8 |
| Static pods, second scheduler, kubelet config, `staticPodPath` | Part I §1.6, §1.7 |
| Metrics Server / aggregation layer, `kubectl top` | Part I §1.8 |
| RBAC — Roles, ClusterRoles, bindings, ServiceAccounts, `auth can-i` | Part V §5.2–5.5 |
| Certificates, CSR objects, kubeconfig, TLS for components | Part V §5.8, §5.9 |
| SecurityContext, capabilities, `runAsNonRoot`, Pod Security | Part V §5.7 |
| Private registries, image pull secrets | Part V §5.6 |
| NetworkPolicy — ingress, egress, `podSelector`/`namespaceSelector` | Part III §3.4 |
| Services — ClusterIP, NodePort, LoadBalancer, headless, endpoints | Part III §3.2, §3.3 |
| Ingress — controller install, host/path routing, TLS, rewrite | Part III §3.5 |
| PV / PVC / StorageClass / access modes / reclaim policy / CSI | Part IV §4.1–4.7 |
| Pods, ReplicaSets, Deployments, rollouts, rollbacks, `rollout undo` | Part II §2.1–2.3 |
| Multi-container pods, sidecar, ambassador, adapter, init containers | Part II §2.4, §2.5 |
| `command` / `args` / ENTRYPOINT / CMD, Downward API | Part II §2.6 |
| DaemonSets, StatefulSets, Jobs, CronJobs | Part II §2.7, §2.8 |
| Labels, selectors, annotations, `--show-labels` | Part II §2.9 |
| Requests, limits, QoS, LimitRange, ResourceQuota, HPA | Part II §2.10 |
| Taints, tolerations, node affinity, pod affinity, topologyKey | Part II §2.11 |
| Probes — liveness, readiness, startup | Part II §2.13 |
| Node drain/cordon/uncordon, upgrades, cluster maintenance | Part I §1.12, §1.11 |
| Troubleshooting — pod status, logs, `crictl`, control plane, network | Part VI §6.1–6.11 |
| **Full worked exam questions, mock exams, Ingress/NetworkPolicy scenarios** | **Part VII §7.1–7.31** |
| `kubectl` command reference, JSONPath | Appendix D |

---

## C.4 What is already fully covered without your notes file

If your `basic-k8s` notes largely repeat LFS258 ground, you may find this document already covers them. For reference,
the complete competency list of the current CKA curriculum and where each one is addressed:

| # | CKA competency | Covered in |
|---|---|---|
| 1 | Manage RBAC | Part V §5.2–5.5 |
| 2 | Prepare underlying infrastructure for a cluster install | Part I §1.4 |
| 3 | Create and manage clusters with kubeadm | Part I §1.4 |
| 4 | Manage the lifecycle of a cluster | Part I §1.11, §1.12 |
| 5 | Implement and configure a CNI plugin | Part I §1.5 |
| 6 | Configure a highly-available control plane | Part I §1.4, §1.9 |
| 7 | Provision underlying infrastructure | Part I §1.4 |
| 8 | Perform a version upgrade | Part I §1.11 |
| 9 | Implement and configure an etcd cluster | Part I §1.9 |
| 10 | Perform an etcd backup and restore | Part I §1.9 |
| 11 | Understand deployments and rolling updates / rollbacks | Part II §2.3 |
| 12 | Use ConfigMaps and Secrets | Part II §2.5, Part V §5.6 |
| 13 | Scale applications | Part II §2.2, §2.10 |
| 14 | Primitives for robust, self-healing deployments | Part II §2.2, §2.3, §2.7, §2.8 |
| 15 | Resource limits and their effect on scheduling | Part II §2.10 |
| 16 | Manifest management and common tooling | Index §"kubectl patterns", Part III §3.6 |
| 17 | Configure Pod Admission and Security Context | Part V §5.7 |
| 18 | Use labels, selectors and annotations | Part II §2.9 |
| 19 | Configure liveness, readiness, startup probes | Part II §2.13 |
| 20 | Use the Downward API | Part II §2.6 |
| 21 | Multi-container pods and init containers | Part II §2.4, §2.5 |
| 22 | Rolling update / rollback on a Deployment | Part II §2.3 |
| 23 | Understand NetworkPolicies | Part III §3.4 |
| 24 | Cluster network / CNI plugin basics | Part I §1.5 |
| 25 | Networking configuration on cluster nodes | Part III §3.1 |
| 26 | Connectivity between pods | Part III §3.1 |
| 27 | Define and enforce Network Policies | Part III §3.4 |
| 28 | Kubernetes networking model — pod/service network, ClusterIP, NodePort, LoadBalancer, Ingress | Part III §3.1–3.5 |
| 29 | Ingress rules and controllers | Part III §3.5 |
| 30 | DNS service for name resolution | Part III §3.1, §3.2, Part VI §6.5 |
| 31 | Service networking model and kube-proxy | Part III §3.3 |
| 32 | Storage classes, PVs, PVCs | Part IV §4.1–4.5 |
| 33 | Container Storage Interface | Part IV §4.7 |
| 34 | Configure applications with persistent storage | Part IV §4.2, §4.8 |
| 35 | Volume modes, access modes, reclaim policies | Part IV §4.3, §4.4, §4.6 |
| 36 | PVCs and how they bind | Part IV §4.1–4.4 |
| 37 | Authentication and authorisation | Part V §5.1–5.5 |
| 38 | Kubernetes security primitives | Part V §5.7 |
| 39 | Network policies (see #23) | Part III §3.4 |
| 40 | The Kubernetes certificate system | Part V §5.8 |
| 41 | Configure `kubectl` contexts and switch between them | Part V §5.9 |
| 42 | Create and manage TLS certificates for cluster components | Part V §5.8 |
| 43 | Configure a SecurityContext for a pod or container | Part V §5.7 |
| 44 | Define ServiceAccount permissions | Part V §5.5 |
| 45 | Create and use ServiceAccounts | Part V §5.5 |
| 46 | Pull images from a private registry | Part V §5.6 |
| 47 | Troubleshoot cluster component failure | Part VI §6.3 |
| 48 | Troubleshoot application failure | Part VI §6.1, §6.2, §6.9 |
| 49 | Troubleshoot networking issues | Part VI §6.5 |
| 50 | Troubleshoot storage issues | Part IV §4.5, §4.8, Part VI §6.8 |
| 51 | Evaluate cluster and node logging | Part VI §6.3, §6.7 |
| 52 | Monitor applications | Part VI §6.6 |
| 53 | Manage container stdout and stderr logs | Part VI §6.2 |
| 54 | Troubleshoot control plane and worker node failure | Part VI §6.3, §6.4 |

**All 54 competencies are addressed in Parts I–VI.** Your `basic-k8s` notes will add *your* wording, *your* commands and
*your* personal annotations on top of that, which is exactly the value they add over any textbook.

---

*Send the `basic-k8s` file and this appendix fills in.*
