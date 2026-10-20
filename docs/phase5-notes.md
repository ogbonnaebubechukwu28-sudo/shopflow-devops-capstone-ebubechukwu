# Phase 5 - Kubernetes with Minikube: Notes

## Cluster and image workflow
- Minikube (docker driver, 2 CPUs, 3 GB), kubectl v1.31, Kubernetes v1.35.
- Images are built inside Minikube's Docker engine ("eval $(minikube docker-env)")
  with the same 1.0.0 tags as Compose. imagePullPolicy is IfNotPresent so nothing is pulled from a registry.

## Resources (k8s/ folder, applied with kubectl apply -f k8s/)
- Namespace shopflow, labelled with app.kubernetes.io/name and part-of.
- ConfigMap shopflow-config: non-sensitive settings (DB name/user, REDIS_URL, PORT).
- Secret shopflow-secret: POSTGRES_PASSWORD and DATABASE_URL. Created with
  "kubectl create secret generic" using a random password (openssl rand -hex 12),
  so no credential is ever stored in Git.
- PostgreSQL: StatefulSet + headless Service + 1Gi PersistentVolumeClaim, PGDATA in a subfolder.
- Redis: Deployment + Service.
- Backend: Deployment (2 replicas) + Service "backend" (the name nginx proxies to).
- Frontend: Deployment (2 replicas) + NodePort Service, port 80 -> container port 8080.
- HorizontalPodAutoscaler for the backend (2-4 replicas, 70% CPU, needs metrics-server).
- PodDisruptionBudget for the backend (minAvailable 1).

## Health, resources and security
- Backend: readiness probe /ready (checks DB and Redis), liveness probe /health, timeoutSeconds 3.
- Frontend probes on /. Postgres and Redis use pg_isready and redis-cli ping.
- Every container has CPU/memory requests and limits.
- Backend and frontend run as non-root (uid 1000 and 101) with allowPrivilegeEscalation false.

## Problems and decisions
- One backend pod restarted once at first start. Both replicas run "flask init-db"
  at the same moment, and the Kubernetes default probe timeout (1s) was tight on a small machine.
  Fix: probe timeoutSeconds 3. Production fix would be a separate migration Job.
- SEED_DB is not set in Kubernetes (the entrypoint says it is for dev only).
  Sample data was inserted once with: kubectl exec deploy/backend -- flask --app app seed.
- The frontend is reached with: minikube service frontend -n shopflow --url
  (with the docker driver on Linux the terminal must stay open).

## Evidence
- Screenshots: kubectl get all,hpa,pdb,pvc -n shopflow; the app in the browser; kubectl top pods.
NAME                            READY   STATUS    RESTARTS   AGE
pod/backend-55d45cf984-rb29p    1/1     Running   0          11m
pod/backend-55d45cf984-sl8sr    1/1     Running   0          12m
pod/frontend-6844566f88-wdtm7   1/1     Running   0          26m
pod/frontend-6844566f88-x9pkc   1/1     Running   0          26m
pod/postgres-0                  1/1     Running   0          38m
pod/redis-5869899d84-gtcfd      1/1     Running   0          38m

NAME               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/backend    ClusterIP   10.101.1.249     <none>        5000/TCP       26m
service/frontend   NodePort    10.111.127.254   <none>        80:30431/TCP   26m
service/postgres   ClusterIP   None             <none>        5432/TCP       38m
service/redis      ClusterIP   10.104.242.98    <none>        6379/TCP       38m

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend    2/2     2            2           26m
deployment.apps/frontend   2/2     2            2           26m
deployment.apps/redis      1/1     1            1           38m

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/backend-55d45cf984    2         2         2       12m
replicaset.apps/backend-6d7d47ddd4    0         0         0       26m
replicaset.apps/frontend-6844566f88   2         2         2       26m
replicaset.apps/redis-5869899d84      1         1         1       38m

NAME                        READY   AGE
statefulset.apps/postgres   1/1     38m

NAME                                          REFERENCE            TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/backend   Deployment/backend   cpu: 2%/70%   2         4         2          12m

NAME                                 MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/backend   1               N/A               1                     12m

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/pgdata-postgres-0   Bound    pvc-3c7b6387-94aa-4d8a-b894-ef1b3cbe5b08   1Gi        RWO            standard       <unset>                 38m
