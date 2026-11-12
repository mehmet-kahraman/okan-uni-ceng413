# HW-3: Run your HW-2 app on Kubernetes (DRAFT, not announced)

**Due:** [date, to be confirmed with Emel hoca]
**Work:** [alone / in pairs, to be confirmed]
**Hand in:** one `.zip` file with the files below.

## Task
Take the app from HW-2 and describe it for Kubernetes. Test it in a Killercoda Kubernetes playground (sessions are deleted after about an hour, so keep your YAML files on your own computer).

## Checklist (draft points, total 100)
| Item | Points |
|---|---|
| Deployment and Service for the app, with a pinned image tag | 25 |
| Settings in a ConfigMap, password in a Secret (not in the image, not in Git) | 20 |
| Readiness probe and liveness probe | 20 |
| Requests and limits for CPU and memory | 15 |
| README: how to apply, how to check, what you saw | 10 |
| Screenshot of `kubectl get pods` and `kubectl describe` of one Pod | 5 |
| Written answers (3 short questions, see below) | 5 |

Bonus (up to +5): a note on what happens when you remove the readiness endpoint.

## Questions
1. What is the difference between a readiness and a liveness probe?
2. Why is a Secret not the same as encryption?
3. What happens when a container crosses its memory limit?

## Notes
- Do not put real passwords in the zip. Use a demo value.
- Use `kubectl apply --dry-run=client -f .` to catch typing mistakes.
- Not built or tested by the instructor: this text is a draft from Week 7 topics.
