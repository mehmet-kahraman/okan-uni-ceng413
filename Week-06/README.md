# CENG413 Week 6: Kubernetes first steps

This week: a real security case (PHP2Shell), then our first steps with Kubernetes. You do the lab in an online cluster in your browser, so you install nothing.

## What is in this folder

| File | What it is |
|---|---|
| `LAB-GUIDE.md` | The lab, step by step (English) |
| `LAB-GUIDE.tr.md` | The same lab (Türkçe) |
| `manifests/deployment.yaml` | A Deployment: three copies of nginx 1.27 |
| `manifests/service.yaml` | A Service: one stable name (`web`) in front of the Pods |
| `manifests/rootpod.yaml` | A Pod with default settings (root) |
| `manifests/safepod.yaml` | The same Pod, hardened (non-root, read-only files, no extra capabilities) |
| `manifests/safepod-nosa.yaml` | Hardened, and without the default cluster access token |

You do not need to download the manifests for the lab: the guide contains every file as a block you can paste. They are here so you can read them in your editor and reuse them later.

## The ideas in one page

1. **PHP2Shell (CVE-2026-109618 and CVE-2026-109619).** Two critical PHP bugs, no login needed, any PHP page is on the path. The fix is to patch (PHP 8.5.12, 8.4.27, 8.3.36 or 8.2.35). In a container, patching means: new base image, rebuild, redeploy. Layers such as a non-root user, no secrets in the image, own networks and resource limits do not close the hole, but they limit how far it spreads.
2. **Desired state.** In Kubernetes you declare the result (for example, three copies of `web`), and the cluster keeps it true, all the time.
3. **Three building blocks.** Pod (disposable unit), Deployment (keeps the copies, updates and rolls back), Service (stable name for changing Pods).
4. **From Compose to Kubernetes.** Compose service becomes Deployment. The service name becomes a Service. `.env` becomes ConfigMap and Secret. A volume becomes a PersistentVolumeClaim. `healthcheck` becomes probes. `docker compose up` becomes `kubectl apply -f`.
5. **Hardened does not mean safe.** `safepod` limits who runs the code and what it can change. It does not remove what the app can read, such as the default service account token. `safepod-nosa` removes that token.

## Commands you used this week

```bash
kubectl get nodes | pods | deployments | service      # add -o wide, or -A
kubectl create deployment web --image=nginx:1.27 --replicas=3
kubectl expose deployment web --port=80
kubectl scale deployment web --replicas=5
kubectl set image deployment/web nginx=nginx:1.28
kubectl rollout status deployment/web
kubectl rollout undo deployment/web
kubectl describe pod POD-NAME                         # read the Events
kubectl exec POD-NAME -- id
kubectl apply -f FILE.yaml
kubectl delete deployment web
```

## Roadmap

| Step | Status |
|---|---|
| Docker (Weeks 4 and 5): images, Dockerfile, non-root, pinned versions | Done |
| Compose (Week 5): services, names, volumes, state | Done |
| Kubernetes basics (Week 6): Pod, Deployment, Service, safe Pods | **Today** |
| More Kubernetes: configuration, secrets, health checks, storage | Next |
| Tests and security | Then |
| AI-assisted coding | Then |
| Your project on VibeHub | Goal |

The exact week-by-week plan after this week is still a draft.

## Homework

HW-2 (Compose) is handed in as agreed in class. There is no new homework file this week. If your instructors give a take-home task, it will be announced in class.
