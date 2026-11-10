# CENG413 Week 7: Configuration, health checks and limits

Last time you ran your first Pods, Deployments and Services. This week we add the pieces that make an app **runnable by someone else**: where its settings and secrets come from, how the cluster knows it is healthy, and how much it may use. You do the lab in an online cluster in your browser, so you install nothing.

## What is in this folder

| File | What it is |
|---|---|
| `LAB-GUIDE.md` | The lab, step by step (English) |
| `LAB-GUIDE.tr.md` | The same lab (Türkçe) |
| `manifests/app-config.yaml` | A ConfigMap and a Deployment that reads it (as variables and as a file) |
| `manifests/secret-pod.yaml` | A Pod that reads a Secret (the Secret itself is created with a command) |
| `manifests/probes.yaml` | A Deployment with readiness and liveness probes, and its Service |
| `manifests/liveness-exec.yaml` | A container that breaks on purpose, so a liveness probe restarts it |
| `manifests/memhog.yaml` | A container that uses more memory than its limit (OOMKilled) |
| `manifests/toobig.yaml` | A Pod that asks for more CPU than any node has (stays Pending) |
| `manifests/resources-deployment.yaml` | A Deployment with sensible requests and limits |

You do not need to download the manifests for the lab: the guide contains every file as a block you can paste. They are here so you can read them in your editor and reuse them later.

## The ideas in one page

1. **ConfigMap.** Settings live outside the image, as key-value pairs. A Pod reads them as environment variables or as files. Variables are read once at start (restart the Pods to change them). Files update by themselves after a short delay.
2. **Secret.** Like a ConfigMap, but for passwords and keys. The value is only base64 encoded, not encrypted, so who may read Secrets matters. Never commit a Secret to Git.
3. **Probes.** *Readiness*: may this Pod get traffic? A failing Pod stays alive but leaves the Service. *Liveness*: is the container alive? A failing container is restarted. Readiness is the one that protects your users during a slow start or a temporary problem.
4. **Resources.** `requests` are what the Pod needs (the scheduler uses them to pick a node). `limits` are the most it may use. Too much memory: the container is killed (OOMKilled). Too much CPU: it is slowed down. A request no node can satisfy: the Pod stays Pending.
5. **Storage (slides only).** A named volume in Compose becomes a PersistentVolumeClaim in Kubernetes: the Pod asks for storage, and the cluster provides it.

## From Compose to Kubernetes (updated map)

| In Compose | In Kubernetes | Where |
|---|---|---|
| service | Deployment | Week 6 |
| service name | Service | Week 6 |
| `environment:` | ConfigMap | **Week 7** |
| `.env`, secrets | Secret | **Week 7** |
| `healthcheck:` | readiness / liveness probe | **Week 7** |
| `deploy.resources` | requests and limits | **Week 7** |
| named volume | PersistentVolumeClaim | slides, Week 7 |
| `docker compose up` | `kubectl apply -f` | Week 6 |

## Commands you used this week

```bash
kubectl apply -f FILE.yaml
kubectl exec POD -- COMMAND
kubectl logs POD
kubectl get pods -w                                   # watch (Ctrl+C to stop)
kubectl describe pod POD                              # read the Events at the bottom
kubectl create configmap NAME --from-literal=KEY=VALUE
kubectl create secret generic NAME --from-literal=KEY=VALUE
kubectl get secret NAME -o jsonpath='{.data.KEY}' | base64 -d
kubectl rollout restart deployment/NAME
kubectl get endpointslices -l kubernetes.io/service-name=NAME
```

## Roadmap

| Step | Status |
|---|---|
| Docker (Weeks 4 and 5) | Done |
| Compose (Week 5) | Done |
| Kubernetes basics (Week 6) | Done |
| Configuration, secrets, health checks, limits (Week 7) | **Today** |
| Tests and security | Next (draft) |
| AI-assisted coding | Then (draft) |
| Your project on VibeHub | Goal |
