# Kubernetes CKA + LFS258 — Merged Lab & Study Guide

**Sources merged in this document**

| Source | What it contributes |
|---|---|
| `terra-bacth/k8s-LFS258` (this repo) | Every lab script, YAML manifest and personal annotation you wrote while working through **LFS258 – Kubernetes Fundamentals** |
| CKA exam curriculum | The domain structure, concept explanations, exam-day patterns and gotchas that LFS258 does not cover |
| `quay.io/pandeysp/*` registry | Your own container images, offered as alternatives in every lab so nothing depends on a public registry being reachable |

**How to use it**

1. Work top to bottom — the parts follow the **CKA exam domain weighting**, not the LFS258 chapter order.
2. Every lab is presented as **Objective → Commands → Manifest → Explanation → Exam notes**, and every manifest carries a commented
   `# Alt image: quay.io/pandeysp/...` line so you can swap images without hunting through the repo.
3. Anything you wrote as a *personal annotation* (the `#` comments in the original scripts) is preserved verbatim and tagged
   **[Your note]** — those are your own hard-won gotchas, not filler.
4. Appendix B is a full **LFS258 → CKA crosswalk** so you can trace any repo file back to an exam objective.
5. Appendix C is a reserved slot for your `basic-k8s` CKA notes (see the note at the end of this index).

---

## Table of Contents

| Part | CKA Domain | Weight | Labs covered |
|---|---|---|---|
| [Part I](01-cluster-architecture-installation-configuration.md) | Cluster Architecture, Installation & Configuration | ~25% | 04, 13, 14, 15, 21 (etcd), kubeadm, CNI, kubelet |
| [Part II](02-workloads-and-scheduling.md) | Workloads & Scheduling | ~15% | 01, 02, 03, 06, 07, 08, 09, 10, 11, 12, 18, 19, Deployments/* |
| [Part III](03-services-and-networking.md) | Services & Networking | ~20% | 05, 30, 32, 33, Networking/*, Ingress/*, Services/* |
| [Part IV](04-storage.md) | Storage | ~10% | 16, 31, VolumesAndData/* |
| [Part V](05-security.md) | Security | ~20% | 17, 22, 23, 24, 25, 26, 27, 28, 29, Security/* |
| [Part VI](06-troubleshooting.md) | Troubleshooting | ~10% | 15, 20, ApiAccess/*, Proxy/*, metric-server |
| [Appendix A](90-appendix-a-image-catalog.md) | Your `quay.io/pandeysp/*` image catalog | — | 33 images / 41 tags |
| [Appendix B](91-appendix-b-lfs258-cka-crosswalk.md) | Repo file → exam objective mapping | — | 255 files |
| [Appendix C](92-appendix-c-cka-notes.md) | Your `basic-k8s` CKA notes (reserved) | — | — |

---

## Lab environment assumptions

Everything below assumes a **kubeadm cluster** with a `controlplane` node and at least one `node01`, containerd as the
runtime, and flannel as the CNI — matching the environment your lab transcripts were captured in
(`Services/docker-desktop-node-spec.log`, `Labs/32-networking-explore-env.sh`).

```bash
# Sanity check before you start any lab
kubectl get nodes -o wide
kubectl cluster-info
kubectl version --short
kubectl config current-context
```

### Namespace shorthand used throughout

| Namespace | Purpose in these labs |
|---|---|
| `default` | Most labs |
| `kube-system` | Control plane, metrics-server, custom scheduler |
| `blue`, `research`, `finance`, `development`, `production` | RBAC labs |
| `elastic-stack` | Elasticsearch + Kibana + sidecar labs |
| `app-space`, `critical-space`, `users-backend`, `baz`, `accounting`, `andromeda` | Networking / Ingress labs |

---

## The `kubectl` patterns you will use in every single lab

These are worth memorising before Part I — roughly a third of the exam is "produce the YAML, then edit it".

```bash
# 1. Generate YAML instead of writing it (the single biggest time-saver in the exam)
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create deployment web --image=nginx --dry-run=client -o yaml > deploy.yaml
kubectl create job hi --image=busybox --dry-run=client -o yaml > job.yaml
kubectl create cronjob hi --image=busybox --schedule="* * * * *" --dry-run=client -o yaml > cj.yaml
kubectl expose deployment web --port=80 --dry-run=client -o yaml > svc.yaml
kubectl create configmap cm --from-literal=k=v --dry-run=client -o yaml > cm.yaml
kubectl create secret generic s --from-literal=k=v --dry-run=client -o yaml > s.yaml
kubectl create serviceaccount sa --dry-run=client -o yaml > sa.yaml
kubectl create clusterrole cr --verb=get,list --resource=pods --dry-run=client -o yaml > cr.yaml
kubectl create role r --verb=get,list --resource=pods -n dev --dry-run=client -o yaml > role.yaml
kubectl create rolebinding rb --role=r --user=dev -n dev --dry-run=client -o yaml > rb.yaml
kubectl create ingress ing --rule="host/path=svc:80" --dry-run=client -o yaml > ing.yaml

# 2. Explain — read the schema instead of guessing a field name
kubectl explain pod.spec.containers.securityContext
kubectl explain deployment.spec.strategy.rollingUpdate
kubectl explain pvc.spec.resources

# 3. Quickly patch / scale / label / annotate without an editor
kubectl scale deploy web --replicas=5
kubectl patch deploy web -p '{"spec":{"replicas":5}}'
kubectl label node node01 disk=ssd
kubectl annotate pod p1 description="my pod"
kubectl set image deploy web nginx=nginx:1.25

# 4. Inspect fast
kubectl get pod -o wide
kubectl get pod -o jsonpath='{.status.podIP}'
kubectl get pod -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
kubectl get events --sort-by=.lastTimestamp
kubectl get all --show-labels
```

> **Exam note** — `--dry-run=client -o yaml` is *client-side only*: it does not create the object, so it is safe to run even
> when you are unsure whether the object already exists. It costs you nothing and it guarantees correct apiVersion/kind.

---

## A note on your `basic-k8s` notes file

You mentioned an attached `basic-k8s` text file containing your CKA labs. The attachment did **not** arrive in this
workspace — only the LFS258 repo is present here. To keep you unblocked, this document was built from:

* the complete contents of this repository (all 255 non-`.git` files), and
* the current CKA curriculum structure.

**Appendix C is deliberately left as a reserved, pre-formatted slot.** Re-share the `basic-k8s` file (paste its text, or drop
the file into the repo) and it will be folded in verbatim, with each lab cross-linked into the matching Part above.
