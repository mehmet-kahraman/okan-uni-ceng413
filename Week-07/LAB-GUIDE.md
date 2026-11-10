# Week 7 Lab: Configuration, health checks and limits (in the browser)

**Time:** 45 minutes, work with a partner. **Turkish version:** `LAB-GUIDE.tr.md`.

Same setup as last time: a small Kubernetes cluster in a browser tab, nothing to install. Every command can be pasted, so if your one-hour session ends you can start again quickly.

**Working rule:** *predict first, then run.* Tell your partner what you think will happen before each experiment.

**What we add today to the Compose map:** settings and secrets (ConfigMap, Secret), `healthcheck` (probes), and `deploy.resources` (requests and limits).

## Part 0: Get a cluster (5 minutes)

Use the Killercoda Kubernetes playground from last time (<https://killercoda.com/playgrounds>). Free sessions last about one hour and are deleted when you close the tab. Other options: KodeKloud playground, iximiuz Labs, Docker Desktop with Kubernetes switched on, or `kind`.

```bash
kubectl get nodes
```

You need at least one node with `STATUS` **Ready**. The manifests below are written with `cat <<'EOF'`, so you paste a whole block and the file is created. Check the file with `ls` if unsure.

## Part 1: ConfigMap, settings outside the image (10 minutes)

A ConfigMap holds settings as key-value pairs. Your Pod can read it as **environment variables** and as **files**. The image does not change, only the ConfigMap does.

```bash
cat <<'EOF' > app-config.yaml
# ConfigMap + Deployment: the app reads its settings from outside the image.
# The same ConfigMap is used twice: as environment variables and as a file.
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  GREETING: "Hello from the ConfigMap"
  LOG_LEVEL: "info"
  index.html: |
    <h1>Hello from the ConfigMap</h1>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cfgweb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cfgweb
  template:
    metadata:
      labels:
        app: cfgweb
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          env:
            - name: GREETING            # one key as one variable
              valueFrom:
                configMapKeyRef:
                  name: web-config
                  key: GREETING
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: web-config
                  key: LOG_LEVEL
          volumeMounts:
            - name: site
              mountPath: /usr/share/nginx/html   # the page nginx serves
      volumes:
        - name: site
          configMap:
            name: web-config
            items:
              - key: index.html                  # only this key becomes a file
                path: index.html
EOF
```

```bash
kubectl apply -f app-config.yaml
kubectl get pods
```

Wait for `Running`. Read the settings from inside the Pod:

```bash
kubectl exec deploy/cfgweb -- printenv GREETING LOG_LEVEL
kubectl exec deploy/cfgweb -- cat /usr/share/nginx/html/index.html
```

- **Predict:** you now change the ConfigMap. Which will change first, the environment variable or the file?

```bash
kubectl patch configmap web-config --type merge -p '{"data":{"GREETING":"Hello again","index.html":"<h1>Hello again</h1>\n"}}'
kubectl exec deploy/cfgweb -- printenv GREETING
kubectl exec deploy/cfgweb -- cat /usr/share/nginx/html/index.html
```

The variable is still the old value. The file may take up to about a minute to change. Repeat the `cat` command every 15 seconds until it shows "Hello again". Environment variables are read **once, when the container starts**. To pick up the new value, restart the Pods:

```bash
kubectl rollout restart deployment/cfgweb
kubectl rollout status deployment/cfgweb
kubectl exec deploy/cfgweb -- printenv GREETING
```

**Think:** you changed one line of configuration and did not rebuild an image. Where would that be a problem in your Week 5 Compose project?

## Part 2: Secret, passwords outside the image and Git (8 minutes)

A Secret looks like a ConfigMap, but it is meant for passwords and keys. We create it with a command, so the value never sits in a file that you might commit.

```bash
kubectl create secret generic db-secret --from-literal=password=demo-not-a-real-password
kubectl get secret db-secret -o yaml
```

Look at the `data:` part. It does not show the password in plain text, but look closer:

```bash
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

- **Important:** the value is only **base64 encoded**. That is an encoding, not encryption. Anyone who may read the Secret can decode it. Real protection comes from limiting who can read Secrets (RBAC) and from encryption of the cluster's storage, which the cluster administrators set up.

Now use it in a Pod:

```bash
cat <<'EOF' > secret-pod.yaml
# A Pod that reads a Secret as an environment variable and as a file.
# Create the Secret first:
#   kubectl create secret generic db-secret --from-literal=password=demo-not-a-real-password
apiVersion: v1
kind: Pod
metadata:
  name: secretpod
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sh", "-c", "echo password-from-env is $DB_PASSWORD; ls /etc/creds; sleep 3600"]
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
      volumeMounts:
        - name: creds
          mountPath: /etc/creds
          readOnly: true
  volumes:
    - name: creds
      secret:
        secretName: db-secret
EOF
```

```bash
kubectl apply -f secret-pod.yaml
kubectl logs secretpod
```

You see the password from the environment variable and the list of files in `/etc/creds`.

**Think:** the Secret is not inside the image and not in Git. What did we gain? What is still exposed to someone who can run `kubectl exec` in this Pod?

## Part 3: Probes, how Kubernetes knows an app is healthy (14 minutes)

Two questions: **may this Pod receive traffic?** (readiness probe) and **is this container still alive?** (liveness probe).

```bash
cat <<'EOF' > probes.yaml
# Two copies of nginx behind a Service, with a readiness and a liveness probe.
# Readiness: "may this Pod receive traffic?"  -> asks for the home page every 5 s.
# Liveness:  "is the container alive?"        -> only checks that port 80 accepts connections.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probeweb
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probeweb
  template:
    metadata:
      labels:
        app: probeweb
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            periodSeconds: 5
            failureThreshold: 2
          livenessProbe:
            tcpSocket:
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: probeweb
spec:
  selector:
    app: probeweb
  ports:
    - port: 80
      targetPort: 80
EOF
```

```bash
kubectl apply -f probes.yaml
kubectl get pods
kubectl get endpointslices -l kubernetes.io/service-name=probeweb
```

The `ENDPOINTS` column shows two Pod IP addresses. Those are the Pods that receive traffic from the Service.

### 3a: Break the readiness probe

Pick one Pod and delete the home page inside it:

```bash
POD=$(kubectl get pods -l app=probeweb -o name | head -1)
echo $POD
kubectl exec $POD -- rm /usr/share/nginx/html/index.html
```

- **Predict:** will Kubernetes restart this Pod? Will it still receive traffic?

Wait about 15 seconds, then look:

```bash
kubectl get pods
kubectl get endpointslices -l kubernetes.io/service-name=probeweb
kubectl describe $POD | tail -n 8
```

You should see: `READY 0/1` for that Pod, `RESTARTS` still 0, and only **one** IP address left in `ENDPOINTS`. In the events: "Readiness probe failed". The Pod is alive, it just receives no traffic. Repair it:

```bash
kubectl exec $POD -- sh -c 'echo ok > /usr/share/nginx/html/index.html'
kubectl get pods
kubectl get endpointslices -l kubernetes.io/service-name=probeweb
```

After a few seconds it is `1/1` again and has two IP addresses.

### 3b: A liveness probe restarts a broken container

```bash
cat <<'EOF' > liveness-exec.yaml
# A container that is healthy for 30 seconds, then "breaks" (the file disappears).
# The liveness probe notices and Kubernetes restarts the container.
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sh", "-c", "touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600"]
      livenessProbe:
        exec:
          command: ["cat", "/tmp/healthy"]
        initialDelaySeconds: 5
        periodSeconds: 5
        failureThreshold: 2
EOF
```

```bash
kubectl apply -f liveness-exec.yaml
kubectl get pod liveness-demo -w
```

Watch for about a minute. Press `Ctrl+C` when `RESTARTS` becomes 1. Then:

```bash
kubectl describe pod liveness-demo | tail -n 12
```

You should see "Liveness probe failed" and "will be restarted". The container breaks 30 seconds after each start, so it keeps repeating.

**Think:** which of the two probes would you give to an app that needs 2 minutes to warm up? What could go wrong if the liveness probe is too strict?

## Part 4: Resources, requests and limits (8 minutes)

`requests` = what the Pod needs (the scheduler uses it to pick a node). `limits` = the most it may use.

### 4a: Memory over the limit

```bash
cat <<'EOF' > memhog.yaml
# A container that tries to use 250 MB but is only allowed 100 MiB.
# Memory over the limit -> the container is killed (OOMKilled).
# Note: polinux/stress is the image used in the official Kubernetes memory tutorial.
# It is a demo-only image, so we do not pin a tag here.
apiVersion: v1
kind: Pod
metadata:
  name: memhog
spec:
  containers:
    - name: stress
      image: polinux/stress
      command: ["stress"]
      args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "1"]
      resources:
        requests:
          memory: "50Mi"
        limits:
          memory: "100Mi"
EOF
```

```bash
kubectl apply -f memhog.yaml
kubectl get pod memhog -w
```

The first run pulls an image, so wait. Press `Ctrl+C` when you see `OOMKilled` or `CrashLoopBackOff`. Then:

```bash
kubectl get pod memhog -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'; echo
```

`OOMKilled` means the container used more memory than its limit and was killed. (CPU is different: a container over its CPU limit is slowed down, not killed.)

### 4b: A request that no node can satisfy

```bash
cat <<'EOF' > toobig.yaml
# A Pod that asks for far more CPU than any node has.
# The scheduler cannot place it, so it stays Pending.
apiVersion: v1
kind: Pod
metadata:
  name: toobig
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:
          cpu: "100"
          memory: "64Mi"
EOF
```

```bash
kubectl apply -f toobig.yaml
kubectl get pod toobig
kubectl describe pod toobig | tail -n 6
```

The Pod stays `Pending`. The event says the scheduler found no node with enough CPU ("Insufficient cpu").

### 4c: The good habit

```bash
cat <<'EOF' > resources-deployment.yaml
# The "good habit": every container declares what it needs (requests) and what it may use (limits).
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sizedweb
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sizedweb
  template:
    metadata:
      labels:
        app: sizedweb
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "50m"
              memory: "32Mi"
            limits:
              cpu: "200m"
              memory: "64Mi"
EOF
```

```bash
kubectl apply -f resources-deployment.yaml
kubectl get pod -l app=sizedweb -o jsonpath='{.items[0].status.qosClass}'; echo
```

It prints `Burstable` (requests are lower than limits). If requests equal limits, the class is `Guaranteed`. With no requests or limits it is `BestEffort`, the first kind to be removed when a node is short of memory.

## Part 5: Clean up

```bash
kubectl delete deployment cfgweb probeweb sizedweb
kubectl delete service probeweb
kubectl delete configmap web-config
kubectl delete secret db-secret
kubectl delete pod secretpod liveness-demo memhog toobig
```

Closing the Killercoda tab deletes everything anyway.

## The Compose to Kubernetes map, now with today's pieces

| In Compose | In Kubernetes | Today |
|---|---|---|
| `environment:` | ConfigMap (env or file) | Part 1 |
| `.env`, secrets | Secret | Part 2 |
| `healthcheck:` | readiness / liveness probe | Part 3 |
| `deploy.resources` | `resources` (requests, limits) | Part 4 |
| named volume | PersistentVolumeClaim | slides only |

## Command summary

```bash
kubectl apply -f FILE                         # create or update from a file
kubectl exec POD -- COMMAND                   # run a command inside a Pod
kubectl get pods -w                           # watch Pods change (Ctrl+C to stop)
kubectl describe pod POD                      # details and events (read the bottom!)
kubectl create configmap NAME --from-literal=KEY=VALUE
kubectl create secret generic NAME --from-literal=KEY=VALUE
kubectl rollout restart deployment/NAME       # replace the Pods one by one
kubectl get endpointslices -l kubernetes.io/service-name=NAME
```

## If something goes wrong

- **`ImagePullBackOff` on `polinux/stress` or `busybox`:** wait a minute and run `kubectl get pods` again; if it stays, read `kubectl describe pod NAME` (Events) and tell us.
- **The file did not change after a minute:** check that you patched the right ConfigMap (`kubectl get configmap web-config -o yaml`) and wait one more minute.
- **`AlreadyExists`:** you ran the command twice. That is fine.
- **Session ended:** open a new Killercoda session and paste the blocks again.

## Reflection questions (write 2 to 3 sentences each, you can answer in your own words)

1. Why is it better to keep settings in a ConfigMap than inside the image? Name one thing that gets easier.
2. A Secret is only base64 encoded. Why is it still better than writing the password in the Deployment file?
3. A readiness probe failed but the Pod was not restarted. Why is that the right behavior?
4. What happens to a container that uses more memory than its limit? What happens if it uses more CPU than its limit?
5. Which of today's four pieces (ConfigMap, Secret, probes, resources) will your own project need first, and why?
