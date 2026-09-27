# Appendix C — Your `basic-k8s` / `basic labs.txt` CKA Notes

**STATUS: MERGED.** The file arrived (as `basic labs.txt`, on the `main` branch of the repo, after two failed attachment
attempts). It is 1,300+ lines of worked labs covering Docker, Kubernetes fundamentals, controllers, Services, storage,
RBAC, certificates, Ingress and Helm — and it turned out to contain a substantial amount of material that the rest of
the repository did not have.

This appendix is the **intake map**: what the file contained, where each lab landed, and what was genuinely new.

A verbatim copy of the source is kept at **`basic-k8s/basic-labs.txt`** in the repository so nothing is lost.

---

## C.1 Where every section of `basic-k8s/basic-labs.txt` landed

| # | Section in the file | Landed in | New? |
|---|---|---|---|
| 1 | Docker Lab — lifecycle, interactive/detached, port publishing | [Appendix E §E.1](94-appendix-e-docker-and-helm.md) | **NEW** |
| 2 | Dockerfile — build, tag, push, login | [Appendix E §E.1.4–E.1.5](94-appendix-e-docker-and-helm.md) | **NEW** |
| 3 | K8s Install Ubuntu — `install.sh`, `kubeadm init` flags, `alias k` | [Part I §1.4a](01-cluster-architecture-installation-configuration.md) | **NEW** flags |
| 4 | Pods — `k run`, `describe`, `explain`, `curl <pod-IP>` | [Part I §1.4b](01-cluster-architecture-installation-configuration.md) (`explain`), [Part II §2.1](02-workloads-and-scheduling.md) | `explain` walkthrough **NEW** |
| 5 | Multi-container pod — `exec -c con2` | Part II §2.4 | covered |
| 6 | **Image Pull Policy** — Always / IfNotPresent / Never | [Part II §2.3a](02-workloads-and-scheduling.md) | **NEW** |
| 7 | Labels and Selectors — `--show-labels`, `env in (...)` | [Part II §2.9a](02-workloads-and-scheduling.md) | set-based **NEW** |
| 8 | Replica Set — create, scale, self-healing | Part II §2.2 | covered |
| 9 | **Set-based ReplicaSet** — `matchExpressions`, `operator: In` | [Part II §2.9a](02-workloads-and-scheduling.md) | **NEW** |
| 10 | Services — ClusterIP / NodePort / LoadBalancer | Part III §3.2 | covered |
| 11 | **MetalLB** — `IPAddressPool`, bare-metal LoadBalancer | [Part III §3.2a](03-services-and-networking.md) | **NEW** |
| 12 | DaemonSet — `myds`, delete a pod and watch it return | Part II §2.7 | covered |
| 13 | Namespace — `create ns`, `-n`, `namespace:` in metadata | Part I §1.3 | covered |
| 14 | ResourceQuota — `dev-quota` with pods/cpu/memory | Part I §1.3, Part II §2.10 | covered |
| 15 | Environment — plain key / ConfigMap / Secrets, `envFrom` | **Part V §5.6** (`envFrom` forms) | `envFrom` **NEW** |
| 16 | **`change-cause` annotation** + `rollout history` / `undo` / `--to-revision` | [Part II §2.3b](02-workloads-and-scheduling.md) | **NEW** |
| 17 | Recreate — `strategy: type: Recreate` | Part II §2.3 | covered |
| 18 | **Blue/green deployment** — two Deployments, switch the Service | [Part II §2.3c](02-workloads-and-scheduling.md) | **NEW** |
| 19 | **`emptyDir`** — the on-node `/var/lib/kubelet/pods/...` walkthrough | [Part IV §4.2a](04-storage.md) | **NEW** |
| 20 | HostPath — same walkthrough, data survives the pod | Part IV §4.8 | covered |
| 21 | **PV/PVC with `volumeName`** — explicit binding, `ReadWriteMany` | [Part IV §4.2b](04-storage.md) | **NEW** |
| 22 | RBAC — Role, RoleBinding, `auth can-i`, cluster-scoped | Part V §5.3–5.4 | covered |
| 23 | **Proving RBAC by switching context** — `use-context pandey`, run the command | [Part V §5.3a](05-security.md) | **NEW** |
| 24 | **User certificate** — `genrsa` → `req` → CSR with `groups:` → approve → `--embed-certs` | [Part V §5.8a](05-security.md) | **NEW** details |
| 25 | **Ingress controller install** — MetalLB then ingress-nginx from the repo | [Part III §3.2a–3.2b](03-services-and-networking.md) | **NEW** |
| 26 | **hotel/tea/coffee** — one Ingress, three paths, `rewrite-target` | **Part III §3.2b** | covered (pattern) |
| 27 | **Helm** — repo, search, install, list, uninstall | [Appendix E §E.2](94-appendix-e-docker-and-helm.md) | **NEW** |

---

## C.2 The genuinely new material, in one place

Ten things from `basic labs.txt` were not anywhere else in the repository, and are now merged:

1. **Docker fundamentals and Dockerfiles** — Appendix E §E.1. The repo had no container-runtime material at all, and
   `Deployments/DockerFile` was the only Dockerfile in it.
2. **`imagePullPolicy`** — Part II §2.3a. The `:latest` → `Always` default rule, and the `ErrImageNeverPull` vs
   `ImagePullBackOff` distinction.
3. **Set-based selectors** — Part II §2.9a. `--selector 'env in (prod,dev)'`, `notin`, `Exists`, `DoesNotExist`, and the
   same three operators in a ReplicaSet's `matchExpressions`.
4. **`change-cause` and the revision lifecycle** — Part II §2.3b. `kubectl annotate deploy mydep
   kubernetes.io/change-cause=...`, `rollout history`, `rollout undo --to-revision=N`.
5. **Blue/green deployment** — Part II §2.3c. Two Deployments and a Service whose selector discriminates on a
   `version:` label, with the cutover being a single `kubectl edit svc`.
6. **MetalLB** — Part III §3.2a. The `IPAddressPool` CRD that makes `LoadBalancer` work on bare metal, and the reason
   `EXTERNAL-IP` is `<pending>` without it.
7. **Installing the ingress controller** — Part III §3.2b. MetalLB first, then `ingress-nginx/deploy/static/provider/cloud/deploy.yaml`.
8. **`emptyDir` on the node** — Part IV §4.2a. The `/var/lib/kubelet/pods/<UID>/volumes/kubernetes.io~empty-dir/<name>/`
   path, plus the `sizeLimit` and `medium: Memory` answers to your own *"Task: Find a way to define size limit in
   emptydir type of storage"*.
9. **`volumeName` explicit binding** — Part IV §4.2b. Pinning a PVC to a specific PV, and using `ReadWriteMany`.
10. **Proving a permission by using it** — Part V §5.3a. `kubectl config use-context pandey`, then running the command
    and reading the `Forbidden:` error, which proves far more than `auth can-i`.
11. **CSR `groups:` and `--embed-certs`** — Part V §5.8a. The `system:authenticated` group, and why the kubeconfig must
    be self-contained.

---

## C.2 The lab-environment facts this file establishes

Everything else in this document assumes a kubeadm cluster. `basic labs.txt` pins down the specifics of *yours*:

| Fact | Value | Where it came from |
|---|---|---|
| Cluster build | `pandeysp1/ubuntu-k8s/install.sh` then a manual `kubeadm init` | §"K8s Install Ubuntu" |
| Pod CIDR | `10.244.0.0/16` | `--pod-network-cidr` |
| Service CIDR | `10.96.0.0/16` | `--service-cidr` |
| kubelet cert paths | `/etc/kubernetes/pki/` | implied by kubeadm |
| User images | `quay.io/pandeysp/*` | every `image:` line |
| Lab environment | KillerCoda, with a fixed set of exposed node ports | *"go to killercoda right side → select target port"* |
| Shell alias | `k` = `kubectl` | `alias k=kubectl` |
| Pre-flight checks | bypassed with `--ignore-preflight-errors=all` | the init command |

---

## C.3 Your notes, preserved verbatim

**[Your note]** — the emptyDir task you set yourself:

> *Task: Find a way to define size limit in emptydir type of storage*
> *Doc of K8s*

The answer is `emptyDir.sizeLimit`, documented in Part IV §4.2a.

**[Your note]** — on the two-terminal CSR workflow:

> *open a new tab*
> *`cat pandey.csr | base64 -w 0`*
> *copy the content to previous tab and paste in csr request field*

**[Your note]** — the same, for extracting the issued certificate:

> *copy the certificate and open a new tab*
> *`echo <pastethe certificate> | base64 -d > pandey.crt`*
> *switch back tyo previous tab*

Both are captured, with the single-command alternative that avoids the copy-paste, in Part V §5.8a.

**[Your note]** — on the blue/green cutover:

> *go to version line and change the version from blue to green*
> *save and exit*
> *reload the page*

**[Your note]** — on hostPath outliving the pod:

> *even you have delete the pod the files will remian in the node /mnt directory*
> *and if you spin your pod again and its created in the same node, the files will be present in the container*

**[Your note]** — on the `stagging` label. Your `set-rs.yaml` selects on `app in (dev, stagging)` — a typo for
`staging`, but it is spelled identically in the selector and in the labels, so the ReplicaSet adopts the pods anyway.
That is the right lesson: Kubernetes does not care what a label *means*, only that the selector and the labels agree.

**[Your note]** — the typos in your file that are worth naming, because they are exactly what muscle memory gets wrong:
`docer exec` (missing `k`), `k config viewe`, `k desribe deploy mydep`, `k get ppods`, `k set image i`,
`--country=IN` (openssl wants `-subj "/C=IN/ST=delhi/CN=pandey"`), `myclsuterbind`, `trainig-web-server`,
`emphemeral`. Every one of them produces either a command-not-found error or — worse — a silently wrong object.
Always `cat` a generated manifest before applying it.

---

## C.4 What this file does **not** contain

So you know what to look for elsewhere:

| Missing from `basic labs.txt` | Covered in |
|---|---|
| etcd backup/restore | Part I §1.9, Part VII §7.25 |
| Cluster upgrades | Part I §1.11 |
| Node lifecycle, drain/cordon | Part I §1.12 |
| NetworkPolicy | Part III §3.4, Part VII §7.30 |
| Ingress scenarios (TLS, canary, host routing) | Part VII §7.29 |
| Probes (liveness/readiness) | Part II §2.8, Part VII §7.4 |
| StatefulSets, Jobs, CronJobs | Part II §2.7 |
| Troubleshooting | Part VI, Part VII §7.18–7.19 |
| Mock exams | Part VII §7.26–7.28 |
| Static pods | Part I §1.6 |
| Custom schedulers | Part I §1.7 |
| Metrics-server | Part I §1.8 |

---

## C.5 If you supply more CKA notes

Any further `basic-k8s` material will be folded in the same way: transcribed verbatim into this appendix, with a
`**CKA domain:**` and `**Merged into:**` line under each lab, and anything that is genuinely new added as a numbered
section in the relevant Part. Appendix B's crosswalk is updated with the file, and the single-file deliverable is
rebuilt and re-validated.
