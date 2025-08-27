# Redis Cluster (3 nós) para MicroK8s

Manifests Kubernetes para subir um **Redis Cluster** (modo cluster, 3 mestres / sem réplicas) no MicroK8s, usando `microk8s-hostpath` para persistência.

> **Pré‑requisitos (no cluster):**
> - MicroK8s com `ingress`, `storage` e DNS padrão habilitados.
> - 3 nós no cluster para espalhar os pods (anti‑affinity).
> - `microk8s-hostpath` como StorageClass default (ou ajuste nos manifests).
>
> **Aviso**: HostPath é *local ao nó*. Em caso de falha do nó, o PVC não move automaticamente. Para produção/HA real, use storage distribuído (ex.: Rook/Ceph, NFS com RWX, etc.).

## Deploy

```bash
# 1) Ajuste a senha em redis/01-secret.yaml (REDIS_PASSWORD)
# 2) Aplique tudo
kubectl apply -f redis/00-namespace.yaml
kubectl apply -f redis/01-secret.yaml
kubectl apply -f redis/10-configmap.yaml
kubectl apply -f redis/11-headless-svc.yaml
kubectl apply -f redis/12-client-svc.yaml
kubectl apply -f redis/20-statefulset.yaml

# 3) Aguarde os 3 pods ficarem Ready
kubectl -n redis get pods -w

# 4) Crie o cluster (Job de bootstrap)
kubectl apply -f redis/30-bootstrap-job.yaml
kubectl -n redis logs job/redis-cluster-bootstrap -f
kubectl apply -f redis/40-external-access.yaml
```

## Verificação

```bash
# Status dos pods e serviços
kubectl -n redis get pods,svc,pvc

# Ver info do cluster (exec em qualquer pod)
POD=$(kubectl -n redis get pod -l app=redis-cluster -o jsonpath='{.items[0].metadata.name}')
kubectl -n redis exec -it $POD -- sh -lc 'redis-cli -a "$REDIS_PASSWORD" cluster info'

# Lista de nós
kubectl -n redis exec -it $POD -- sh -lc 'redis-cli -a "$REDIS_PASSWORD" cluster nodes'
```

## Como conectar aplicações

- Para clientes que conhecem **Redis Cluster**, aponte para **qualquer pod** ou use a lista de A records do **headless**:
  - `redis-cluster-0.redis-cluster-headless.redis.svc.cluster.local:6379`
  - `redis-cluster-1.redis-cluster-headless.redis.svc.cluster.local:6379`
  - `redis-cluster-2.redis-cluster-headless.redis.svc.cluster.local:6379`
- Para um **single endpoint** inicial, pode usar `redis-cluster.redis.svc.cluster.local:6379`, mas clientes cluster-aware costumam preferir múltiplos seed nodes.

## Escala / Réplicas

- Este bundle cria **3 mestres (sem réplicas)**.
- Para **mestres+réplicas** (ex.: 3 mestres + 3 réplicas), aumente `replicas: 6` no StatefulSet e altere o Job de bootstrap para `--cluster-replicas 1`.
- Para garantir 1 pod por nó, mantenha o **podAntiAffinity** configurado e 3 nós disponíveis.

## Remoção

```bash
kubectl delete -f redis/30-bootstrap-job.yaml --ignore-not-found
kubectl delete -f redis/20-statefulset.yaml
kubectl delete -f redis/12-client-svc.yaml
kubectl delete -f redis/11-headless-svc.yaml
kubectl delete -f redis/10-configmap.yaml
kubectl delete -f redis/01-secret.yaml
kubectl delete -f redis/00-namespace.yaml
```

