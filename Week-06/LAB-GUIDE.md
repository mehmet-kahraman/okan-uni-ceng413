# Week 6 Lab: Your first Kubernetes cluster (in the browser)

**Time:** 35 minutes, work with a partner. **Turkish version:** `LAB-GUIDE.tr.md`.

You do not install anything for this lab. You use a small Kubernetes cluster that runs in a browser tab. Every command here can be pasted, so if your session ends you can start again quickly.

**Working rule:** *predict first, then run.* Before each experiment, tell your partner what you think will happen. Wrong guesses cost nothing.

## Part 0: Get a cluster (5 minutes, do it in the break)

**Option A (recommended): Killercoda.**

1. Go to <https://killercoda.com> and create a free account.
2. Open the Kubernetes playground. The page <https://killercoda.com/kubernetes> lists it, and the Playgrounds page has more.
3. A terminal opens in your browser. `kubectl` is the command you use for everything.

Things to know: a free session lasts **one hour**, and the environment is **deleted when you close the tab**. Nothing you do there touches your own computer.

**Option B (if A does not work for you):**

- KodeKloud Kubernetes playground (free sign-in, 60-minute sessions): <https://kodekloud.com/playgrounds/playground-kubernetes-single-node-latest>
- iximiuz Labs, "Kubernetes Cluster" playground (free account): <https://labs.iximiuz.com/>

**Option C (on your own laptop):** Docker Desktop has a Kubernetes switch (Settings, Kubernetes, enable it). Or install [kind](https://kind.sigs.k8s.io/) and run `kind create cluster`. You also need `kubectl`.

Check that it works:

```bash
kubectl get nodes
```

You should see at least one node with `STATUS` **Ready**. If yes, you are done with part 0.

## Part 1: Look around (3 minutes)

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
```

- `-A` means "all namespaces". The cluster already runs its own system Pods. These are the parts of the "brain" from the slides.

**Think:** which of these Pods do you recognize from the slide about cluster parts?

## Part 2: Deploy an app (8 minutes)

Create a Deployment with three copies of nginx, then look at the Pods.

```bash
kubectl create deployment web --image=nginx:1.27 --replicas=3
kubectl get deployments
kubectl get pods -o wide
```

Wait until all three Pods are `Running` (the first time, the image must be pulled, so `ContainerCreating` for a while is normal).

- **Predict:** how many different IP addresses will you see in the `IP` column?

Now give the Pods a stable name with a Service:

```bash
kubectl expose deployment web --port=80
kubectl get service web
```

Call the Service **by name**, from a temporary Pod inside the cluster (this is Week 5 again: names, not IP addresses):

```bash
kubectl run tmp --rm -it --image=busybox:1.37 --restart=Never -- wget -qO- http://web
```

You should see the HTML of the nginx welcome page. The temporary Pod is removed when the command ends.

**Think:** why does `http://web` work? Which Week 5 idea does this remind you of?

## Part 3: Break it, scale it, update it (12 minutes)

### 3.1 Delete a Pod

- **Predict:** you delete one of the three Pods. Does it come back? With the same name?

Open a second terminal tab (or use `--watch` later) and look at the Pod names. Then:

```bash
kubectl get pods
kubectl delete pod POD-NAME        # copy one real name from the list
kubectl get pods
```

(Replace `POD-NAME` with a real name. Names look like `web-5d8c7f9b4-x2k9p`.)

Look at the `AGE` column. Which Pod is new?

### 3.2 Scale

```bash
kubectl scale deployment web --replicas=5
kubectl get pods
kubectl scale deployment web --replicas=3
```

### 3.3 Update to a new version, without stopping

```bash
kubectl set image deployment/web nginx=nginx:1.28
kubectl rollout status deployment/web
kubectl get pods
```

The first `nginx` in `nginx=nginx:1.28` is the **container name**, the second part is the image.

### 3.4 Make a mistake on purpose, then undo it

- **Predict:** you update to an image tag that does not exist. Does the whole service stop?

```bash
kubectl set image deployment/web nginx=nginx:no-such-tag
kubectl get pods
```

Wait 10 to 20 seconds and run `kubectl get pods` again. Some new Pods show `ErrImagePull` or `ImagePullBackOff`. How many old Pods are still `Running`?

Read why it fails:

```bash
kubectl describe pod POD-NAME      # use one of the failing Pods, read the Events at the bottom
```

Go back:

```bash
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
kubectl get pods
```

**Think:** which habit from Week 4 (the `FROM` line in your Dockerfile) makes rollback easy?

## Part 4: Safe Pods, the PHP lesson (8 minutes)

This week's PHP problem showed: an attacker who gets in can do what the app can do. Here we compare two Pods that run the same program.

Create the files (copy the whole block at once):

```bash
cat <<'EOF' > rootpod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: rootpod
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sleep", "3600"]
EOF

cat <<'EOF' > safepod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: safepod
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sleep", "3600"]
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
        seccompProfile:
          type: RuntimeDefault
EOF

kubectl apply -f rootpod.yaml -f safepod.yaml
kubectl get pods
```

Both files are also in the `manifests/` folder of the course repository.

**Predict** (talk with your partner), for each command: does it work on `safepod`?

```bash
kubectl exec rootpod -- id
kubectl exec safepod -- id
kubectl exec safepod -- touch /hello
kubectl exec rootpod -- touch /hello
kubectl exec safepod -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

Write down what you saw. The last command is the surprise: the hardened Pod can still read a file called `token`. This is the key the Pod gets by default to talk to the cluster's brain. Most apps do not need it. Now make a third Pod without it:

```bash
cat <<'EOF' > safepod-nosa.yaml
apiVersion: v1
kind: Pod
metadata:
  name: safepod-nosa
spec:
  automountServiceAccountToken: false
  containers:
    - name: app
      image: busybox:1.37
      command: ["sleep", "3600"]
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
        seccompProfile:
          type: RuntimeDefault
EOF

kubectl apply -f safepod-nosa.yaml
kubectl exec safepod-nosa -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

Now the last command should fail with "No such file or directory".

**Think (and answer in your notes):** from the five questions in class (user, files, other services, tools, host), which did the settings on `safepod` improve? Which did they **not** change? Does this make `safepod` "safe"?

## Part 5 (stretch): The same thing as a YAML file

If you finish early, do the same as part 2 with files, the way Compose used `compose.yaml`. Similar files are in `manifests/` (they use the name `web`; here we use `web2`):

```bash
cat <<'EOF' > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web2
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web2
  template:
    metadata:
      labels:
        app: web2
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
EOF

kubectl apply -f deployment.yaml
kubectl get pods
```

Now change `replicas: 3` to `replicas: 4` in the file (`nano deployment.yaml`), save, and run `kubectl apply -f deployment.yaml` again. What changed? Compare with the `docker compose up` you know from Week 5.

(Why `web2`? So it does not collide with the `web` Deployment from part 2.)

## Clean up

```bash
kubectl delete deployment web web2
kubectl delete service web
kubectl delete pod rootpod safepod safepod-nosa
```

If a name does not exist, you get an error and that is fine. If you used Killercoda, you can also just close the tab: the whole environment is deleted.

## Command summary

| Command | What it does |
|---|---|
| `kubectl get nodes` / `pods` / `deployments` / `service` | List things. Add `-o wide` for more columns, `-A` for all namespaces |
| `kubectl create deployment NAME --image=IMG --replicas=N` | Create a Deployment |
| `kubectl expose deployment NAME --port=80` | Create a Service in front of it |
| `kubectl scale deployment NAME --replicas=N` | Change the number of copies |
| `kubectl set image deployment/NAME CONTAINER=IMG` | Roll out a new image |
| `kubectl rollout status` / `undo` / `history` | Follow, reverse or list updates |
| `kubectl describe pod NAME` | Details and **Events** (read these when something fails) |
| `kubectl logs NAME` | The container's output |
| `kubectl exec NAME -- COMMAND` | Run a command inside a Pod |
| `kubectl apply -f FILE` / `delete -f FILE` | Create or update from a YAML file / remove it |

## Troubleshooting

| What you see | Try this |
|---|---|
| Session ended | Start a new one, paste the commands again |
| Pod is `Pending` or `ContainerCreating` | Wait 30 seconds, then `kubectl describe pod NAME` and read the Events |
| `ImagePullBackOff` | Check the image name and tag for typos |
| Paste does not work in the terminal | Try Ctrl+Shift+V, or right-click and paste |
| `command not found: kubectl` | You are in your own terminal. Use the playground terminal |
| `The connection to the server ... was refused` | The cluster is not ready yet (wait a minute), or you are in the wrong terminal |
| Names already exist (`AlreadyExists`) | You ran the command twice. That is fine, or delete first and run again |

## Reflection questions (write 2 or 3 sentences each)

1. Why did the Pod come back after you deleted it? Use the words *desired state* and *actual state*.
2. A Pod gets a new name and a new IP when it is replaced. How can other services still find it?
3. During the bad update, why did the application keep working?
4. Name two things the settings on `safepod` limit, and one thing they do **not** limit.
5. Which Compose idea from Week 5 matches a Service? Which matches a Deployment?
