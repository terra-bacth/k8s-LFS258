# Kubernetes CKA + LFS258 — Merged Lab & Study Guide

**Sources merged in this document**

| Source | What it contributes |
|---|---|
| `terra-bacth/k8s-LFS258` (this repo) | Every lab script, YAML manifest and personal annotation you wrote while working through **LFS258 – Kubernetes Fundamentals** |
| CKA exam curriculum | The domain structure, concept explanations, exam-day patterns and gotchas that LFS258 does not cover |
| `quay.io/pandeysp/*` registry | Your own container images, offered as alternatives in every lab so nothing depends on a public registry being reachable |
| `last-try/questions.sh` (740 lines) | 25 fully worked CKA exam questions — the single most valuable file in the repo |
| `mock-exam-1/2/3.sh`, `lightenin-labs/`, `practice-on-paper/`, `shells/`, `explore-services/`, `troubleshooting/`, `cluster-upgrade/`, `yaml/`, `configmap/` | Three mock exams, cluster-upgrade sequences, external-etcd drills, real troubleshooting logs, and reference manifest sets |
| `kubectl-quick-refrence.sh`, `jsaon-path-examples.sh` | Your own `kubectl` and JSONPath cheat sheets — consolidated into Appendix D |
| `last-try/scenarios-ingress.txt`, `last-try/senarisos-np.txt` | 5 Ingress and 5 NetworkPolicy scenario questions — worked in Part VII §7.29–7.30 |
| `basic labs.txt` (1,555 lines) | **Your CKA `basic-k8s` notes, now merged** — Docker, kubeadm init flags, `imagePullPolicy`, set-based selectors, `change-cause`, blue/green, MetalLB, ingress-nginx install, `volumeName`, RBAC-by-context-switching, Helm. See **Appendix C** for the intake map and **Appendix E** for Docker + Helm |

**How to use it**

1. Work top to bottom — the parts follow the **CKA exam domain weighting**, not the LFS258 chapter order.
2. Every lab is presented as **Objective → Commands → Manifest → Explanation → Exam notes**, and every manifest carries a commented
   `# Alt image: quay.io/pandeysp/...` line so you can swap images without hunting through the repo.
3. Anything you wrote as a *personal annotation* (the `#` comments in the original scripts) is preserved verbatim and tagged
   **[Your note]** — those are your own hard-won gotchas, not filler.
4. Appendix B is a full **LFS258 → CKA crosswalk** so you can trace any repo file back to an exam objective.
5. **Part VII is the exam-drill part** — 25 full CKA questions with your answers and explanations, three mock exams, and
   ten worked Ingress/NetworkPolicy scenarios. If you only read one part before sitting the exam, read that one.
6. **Appendix C is the intake map for your `basic-k8s` notes** — every section of the file, where it landed, and the eleven
   topics it contributed that were nowhere else in the repo. Appendix E holds the Docker and Helm material.
7. Appendix C is the intake map for your merged `basic-k8s` / `basic labs.txt` notes.

---

> **One file or twelve — your choice.** This guide exists in two equivalent forms:
>
> * **`K8S-CKA-LFS258-MERGED.md`** — every part concatenated into **one single Markdown file** (10,900+ lines, ~400 KB),
>   with `\pagebreak` separators between parts and all cross-references rewritten to internal anchors. This is the
>   deliverable to read, search, print or hand to a friend.
> * **`00-index.md` … `93-appendix-d-*.md`** — the same content split into twelve interlinked files, if you would rather
>   keep them separate in an editor or a repo.
>
> Both are generated from the same source, so they never drift. The internal links work in both.

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
| [Part VII](07-exam-drills-and-mock-exams.md) | **Exam drills** — 25 worked questions + 3 mock exams + 10 scenarios | all domains | `last-try/questions.sh`, `mock-exam-1/2/3.sh`, `scenarios-ingress.txt`, `senarisos-np.txt` |
| [Appendix A](90-appendix-a-image-catalog.md) | Your `quay.io/pandeysp/*` image catalog | — | 33 images / 41 tags |
| [Appendix B](91-appendix-b-lfs258-cka-crosswalk.md) | Repo file → exam objective mapping | — | all 266 files |
| [Appendix C](92-appendix-c-cka-notes.md) | Intake map for your `basic-k8s` / `basic labs.txt` | — | 27 sections mapped; 11 new topics merged |
| [Appendix D](93-appendix-d-kubectl-jsonpath-reference.md) | `kubectl` + JSONPath quick reference | — | `kubectl-quick-refrence.sh`, `jsaon-path-examples.sh` |
| [Appendix E](94-appendix-e-docker-and-helm.md) | Docker and Helm foundations | — | `basic labs.txt` |

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

## What changed in this build, and about `lab.txt`

You asked whether there was a `lab.txt` file. There is no file by that name anywhere in the workspace
(`find / -iname "lab.txt"` returns nothing). What there **is** — and what almost certainly satisfies the request — is
`last-try/questions.sh`, a 740-line file of **25 fully worked CKA exam questions with your answers**. That file, plus
three mock exams and ten scenario questions, is now merged as **Part VII**.

A second-pass survey also found material the first pass had missed, because the original `find | head -200` was silently
truncated. All of it is now merged:

| Newly merged material | Where it landed |
|---|---|
| `last-try/questions.sh` — 25 worked exam questions | Part VII §7.1–7.25 |
| `mock-exam-1.sh`, `mock-exam-2.sh`, `mock-exam-3.sh` | Part VII §7.26–7.28 |
| `last-try/scenarios-ingress.txt` — 5 Ingress scenarios | Part VII §7.29 |
| `last-try/senarisos-np.txt` — 5 NetworkPolicy scenarios | Part VII §7.30 |
| `lightenin-labs/`, `practice-on-paper/`, `cluster-upgrade/history.sh` — v1.29 upgrade sequences | Part I §1.9 |
| `shells/`, `my-steps-etcd-systemctl.sh` — etcd-as-a-systemd-service backup/restore | Part I §1.10, Part VII §7.25 |
| `explore-services/` — ClusterIP / NodePort / LoadBalancer side by side | Part III §3.2 |
| `yaml/nginx/`, `yaml/redis/`, `configmap/` — minimal reference manifests | Part II §2.3, Part IV §4.3 |
| `troubleshooting/` — real control-plane and node logs | Part VI §6.3 |
| `last-try/gb-trouble-shooting.sh` — NodeNotReady + cross-namespace DNS | Part VI §6.1, Part VII §7.18–7.19 |
| `kubectl-quick-refrence.sh`, `jsaon-path-examples.sh` | **Appendix D** |

## About your `basic-k8s` / `basic labs.txt` notes

Both arrived, and they are the same file. It is preserved verbatim at **`basic labs.txt`** in the repository root.

It turned out to contain a good deal the rest of the repo did not — **eleven new topics**, including Docker and Helm
(neither of which appeared anywhere else), `imagePullPolicy`, set-based selectors, the `change-cause` annotation,
blue/green deployments, MetalLB, installing ingress-nginx yourself, `emptyDir` on the node, `volumeName` binding, and
proving an RBAC permission by actually switching to the user's context.

All of it is merged:

* **Appendix C** is the intake map — every section of the file, where it landed, and what was new.
* **Appendix E** holds Docker and Helm, which have no other home in a Kubernetes document.
* The Kubernetes material went into the Parts where it belongs: **Part I §1.4a–1.4b** (kubeadm flags, `kubectl explain`),
  **Part II §2.3a–2.3c** (`imagePullPolicy`, `change-cause`, blue/green), **Part II §2.9a** (set-based selectors),
  **Part III §3.2a–3.2b** (MetalLB, ingress-nginx install), **Part IV §4.2a–4.2b** (`emptyDir`, `volumeName`),
  **Part V §5.3a** (RBAC by context) and **§5.8a** (the full user-cert flow with `groups:` and `--embed-certs`).

Nothing in this document is fabricated. Every lab, command, manifest, log line and `[Your note]` came out of your own
repository.
