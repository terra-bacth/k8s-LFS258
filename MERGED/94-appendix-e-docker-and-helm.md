# Appendix E — Docker and Helm Foundations

From `basic-k8s/basic-labs.txt`. Kubernetes does not exist in a vacuum — before the pods there is a container runtime,
and after the manifests there is a package manager. This appendix covers both, in the order your lab does.

**Everything here uses your own images where the original used a public one.** The policy throughout this document is
*keep the original, add an alternative* — so the original command is shown first and the `quay.io/pandeysp/*`
substitution is a commented line directly beneath it.

---

## E.1 Docker Lab — the container primitives

### E.1.1 Container lifecycle

```bash
docker --help
docker ps                    # running containers
docker ps -a                 # all containers, including stopped
docker images                # local images
docker version
docker search redis          # search Docker Hub
```

**Running and naming:**

```bash
docker run --name ubuntu                       # named "ubuntu", no image → error
docker run --name centos-1 ubuntu              # named centos-1, image ubuntu
docker run --name centos-3 ubuntu /bin/bash    # overrides CMD
docker run --name centos-5 ubuntu sleep 50     # exits after 50 seconds

docker ps -a
# CONTAINER ID   IMAGE     COMMAND       STATUS                     PORTS     NAMES
# a1b2c3d4e5f6   ubuntu    "/bin/bash"   Exited (0) 3 seconds ago             centos-3
# f6e5d4c3b2a1   ubuntu    "sleep 50"    Exited (0) 51 seconds ago            centos-5

docker rm 1a57e4d20ff0 23d7224aead6            # remove by ID, several at once
docker rm 1041ce05339d 6bc80fcfbd2f 3b83c473fc0b
docker ps -a
```

### E.1.2 Interactive vs detached

| Flag | Effect | Use for |
|---|---|---|
| `-i` | keep STDIN open | pipes |
| `-t` | allocate a pseudo-TTY | a shell |
| `-d` | **detached** — run in the background | servers |
| `-it` | interactive TTY | `docker exec ... bash` |
| `-dit` | detached **and** TTY-allocated | a server you may want to attach to later |

```bash
docker run -i  --name con1 ubuntu          # stdin open, no TTY
docker run -it --name con2 ubuntu          # you get a shell
docker run -dit --name con3 ubuntu         # backgrounded, TTY ready

docer exec -it e399e0e44dee /bin/bash      # ← typo in your file; the correct form is:
docker exec -it e399e0e44dee /bin/bash     # exec INTO a running container
```

**[Your note]** — `docer exec` is a typo in the source. Worth naming because `docker exec` (not `run`) is the command
for entering a container that is already running. The mapping to Kubernetes is exact:

| Docker | Kubernetes |
|---|---|
| `docker exec -it <c> bash` | `kubectl exec -it <pod> -- bash` |
| `docker exec -it <c> -c <name> bash` | `kubectl exec -it <pod> -c <name> -- bash` |
| `docker logs <c>` | `kubectl logs <pod> -c <name>` |

### E.1.3 Port publishing

```bash
docker run -dit --name webserver -p 5000:80 nginx
docker ps -dit -p 5000:80 --name webserver nginx
docker run -dit -p 5000:80 --name webserver nginx
# Alt image: quay.io/pandeysp/nginx:latest

docker ps
# CONTAINER ID   IMAGE   COMMAND                  PORTS                                NAMES
# 9f8e7d6c5b4a   nginx   "/docker-entrypoint.…"   0.0.0.0:5000->80/tcp                 webserver

curl localhost        # nginx answers on 80 by default inside the container
curl localhost:80
curl localhost:5000   # the published port on the host
```

`-p 5000:80` means **host 5000 → container 80**. In Kubernetes the equivalent is a Service: `port` is the in-cluster
port, `targetPort` is the container port, and `nodePort` is the host port (Part III §3.2).

```bash
# Publish to a specific interface, and a specific host port
docker run -d -p 127.0.0.1:5000:80 nginx
docker run -d -p 5000:80/udp  nginx
docker run -d -P nginx                       # publish ALL exposed ports, random host ports
```

### E.1.4 Writing a Dockerfile

```dockerfile
# Dockerfile
FROM ubuntu:16.04
RUN apt-get update -y
RUN apt-get install apache2 -y
COPY index.html /var/www/html/index.html
EXPOSE 80
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
```

```bash
echo "<h1>WELCOME to DOCKERFILE</h1>" > index.html
cat index.html

docker build -t web-custom .
docker images
# REPOSITORY    TAG       IMAGE ID       CREATED          SIZE
# web-custom    latest    c3d4e5f6a7b8   5 seconds ago    214MB

docker run -dit --name demo web-custom
docker exec demo cat /var/www/html/index.html
docker ps
docker run -dit -p 5000:80 --name webserver web-custom
```

**The instruction set, in the order you will use them:**

| Instruction | What it does | Notes |
|---|---|---|
| `FROM` | The base image | must be first |
| `RUN` | Execute a command at **build** time | each one is a new layer |
| `COPY` / `ADD` | Copy files from the build context into the image | `ADD` also fetches URLs and untars; prefer `COPY` |
| `WORKDIR` | Set the working directory for later instructions | creates the dir if missing |
| `ENV` | Set an environment variable | persists into the running container |
| `EXPOSE` | **Document** a port | does **not** publish it — metadata only |
| `CMD` | The default command | overridable at `docker run` |
| `ENTRYPOINT` | The fixed executable | harder to override; combine with `CMD` for default args |
| `VOLUME` | Declare a mount point | creates an anonymous volume |
| `USER` | The user to run as | |
| `LABEL` | Metadata | |

**`CMD` vs `ENTRYPOINT` — the shell form vs the exec form.** This is the same trap as Kubernetes' `command` vs `args`
(Part II §2.6):

```dockerfile
# exec form — PID 1 is the process, signals are delivered, no shell involved
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]

# shell form — PID 1 is /bin/sh -c "...", signals are NOT delivered to the app
CMD /usr/sbin/apache2ctl -D FOREGROUND
```

The exec form (a JSON array) is the correct one for anything that must handle SIGTERM — which is every server, and every
`CMD` in a production image.

```dockerfile
# ENTRYPOINT fixed, CMD supplying the default arguments
ENTRYPOINT ["/usr/sbin/apache2ctl"]
CMD ["-D", "FOREGROUND"]

# docker run myimage -DFOREGROUND   → replaces the CMD, keeps the ENTRYPOINT
# docker run --entrypoint /bin/sh    → replaces both
```

**Layer caching.** Put the least-frequently-changing instructions **first**:

```dockerfile
FROM ubuntu:16.04
RUN apt-get update -y                          # changes rarely → cached
RUN apt-get install -y apache2                 # changes rarely → cached
COPY index.html /var/www/html/index.html       # changes often → invalidates only this layer
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
```

Putting the `COPY` before the `RUN apt-get install` means every edit to `index.html` re-downloads and re-installs
apache2.

### E.1.5 Tagging and pushing to your own registry

```bash
docker login
docker images
docker tag web-custom:latest <dockerusername>/us-train:v1
docker images
docker push <dockerusername>/us-train:v1

# Pull it back somewhere else
docker pull <dockerusername>/us-train:v1
```

**[Your note]** — your own images follow exactly this pattern, which is why every lab in this document can point at
`quay.io/pandeysp/*`:

```bash
# Build against your own registry
docker build -t quay.io/pandeysp/mywebapp:v1 .
docker push quay.io/pandeysp/mywebapp:v1

# Then in Kubernetes
k run pod1 --image quay.io/pandeysp/mywebapp
# Alt image: quay.io/pandeysp/mywebapp:latest
```

**Signup:** <https://hub.docker.com/> (for Docker Hub) or <https://quay.io/> (for your `quay.io/pandeysp/*` images).
Appendix A is the full catalog of the images you already have.

> **Exam note** — Docker itself is **not** on the CKA. The exam clusters run containerd, and the only container-runtime
> commands you need are `crictl` (Part VI §6.3). What *is* worth carrying over from this section is the mental model:
> `docker run -p 5000:80` → a NodePort Service; `docker exec` → `kubectl exec`; a `Dockerfile`'s `CMD` → a pod spec's
> `command`.

---

## E.2 Helm — the Kubernetes package manager

Artifact Hub: <https://artifacthub.io/>

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm
```

### E.2.1 Repositories

```bash
helm repo list
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo list
# NAME    URL
# bitnami https://charts.bitnami.com/bitnami

helm search repo bitnami | grep -i nginx
# NAME                 CHART VERSION   APP VERSION   DESCRIPTION
# bitnami/nginx        18.2.4          1.27.2        NGINX Open Source is a web server...

helm repo remove bitnami
helm repo list
```

```bash
# Searching everything on Artifact Hub
helm search hub nginx
helm search hub wordpress --max-col-width 80

# Inspecting a chart before installing it
helm show chart bitnami/nginx
helm show values bitnami/nginx
helm show values bitnami/nginx | grep -A3 service
helm pull bitnami/nginx --untar --untardir /tmp/charts
```

### E.2.2 The install / list / uninstall lifecycle

```bash
helm install trainig-web-server bitnami/nginx
# NAME: trainig-web-server
# LAST DEPLOYED: ...
# NAMESPACE: default
# STATUS: deployed
# REVISION: 1

k get pods,svc
# NAME                                          READY   STATUS    RESTARTS   AGE
# pod/trainig-web-server-nginx-xxxxx            1/1     Running   0          40s
#
# NAME                            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
# service/trainig-web-server-nginx   LoadBalancer   10.100.20.30   <pending>     80:31234/TCP

curl 10.111.38.74
```

**[Your note]** — `trainig-web-server` (missing an `i`) is the release name in your lab, and it works fine. Release
names are arbitrary strings; only their uniqueness within a namespace matters.

```bash
helm list -a
# NAME                   NAMESPACE   REVISION   STATUS   CHART         APP VERSION
# trainig-web-server     default     1          deployed nginx-18.2.4  1.27.2

helm uninstall trainig-web-server
helm list -a
k get pods,svc                    # everything the release created is gone
```

```bash
# Re-adding and reinstalling
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install trainig-web-server bitnami/nginx
ls -ltrh
helm list -a
```

### E.2.3 The commands that matter

```bash
helm install <release> <chart>                       # create
helm install <release> <chart> -n <ns> --create-namespace
helm install <release> <chart> -f values.yaml        # override defaults
helm install <release> <chart> --set service.type=NodePort --set replicaCount=3
helm install <release> <chart> --dry-run --debug      # render without installing
helm template <release> <chart>                       # render to stdout — no cluster needed

helm list -a                                          # all releases, all namespaces
helm list -a -n <ns>
helm status <release>
helm history <release>
helm get values <release>
helm get manifest <release>                           # the rendered manifests
helm get notes <release>

helm upgrade <release> <chart>
helm upgrade <release> <chart> -f values.yaml
helm rollback <release> <revision>
helm rollback <release> 1

helm uninstall <release>
helm uninstall <release> --keep-history
helm repo update
```

**What Helm actually produces.** A chart is templated YAML. The rendered output is exactly the manifests you would write
by hand:

```bash
helm template trainig-web-server bitnami/nginx | head -60
helm template trainig-web-server bitnami/nginx --set service.type=NodePort > nginx.yaml
kubectl apply -f nginx.yaml
```

```bash
# The values file is the interface
cat > values.yaml <<'EOF'
service:
  type: NodePort
  nodePort: 30080
replicaCount: 3
image:
  registry: quay.io
  repository: pandeysp/nginx
  tag: latest
EOF

helm install my-nginx bitnami/nginx -f values.yaml
k get svc
```

> **Exam note** — Helm is **not** on the CKA syllabus. It appears in LFS258 and in real clusters, and it is worth
> knowing that `helm template` is a fast way to generate correct manifests for an object you would otherwise write by
> hand. Do not spend exam-prep time here; spend it on Part VII.

---

## E.3 Part E self-check

1. `docker run -dit -p 5000:80 nginx` — which port is the host's, and which is the container's?
2. `EXPOSE 80` in a Dockerfile — does it publish the port?
3. Why is the exec form of `CMD` preferred over the shell form?
4. `docker exec -it <id> bash` fails with "container is not running". What does `docker ps -a` show?
5. `helm list -a` returns nothing but you installed a release a minute ago. What namespace is it in?
6. What does `helm template` do that `helm install --dry-run` does not?
7. You `docker tag web-custom:latest quay.io/pandeysp/mywebapp:v1` but forget to push. Does Kubernetes see the new tag?
8. Which Docker command maps to `kubectl logs -c <container>`?
