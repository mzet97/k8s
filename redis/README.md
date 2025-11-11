# Redis Kubernetes (Master/Replica) com TLS e NodePort

Este diretório provisiona um cluster Redis com um pod mestre e três réplicas, com suporte a TLS em `6380`, acesso interno via `ClusterIP`, e acesso externo via `NodePort` (`30379` sem TLS e `30380` com TLS). As NetworkPolicies foram ajustadas para permitir acesso da rede interna e controlar tráfego entre master e réplicas.

## Arquitetura
- `StatefulSet` mestre: `21-master-statefulset.yaml` (labels `app=redis-cluster`, `role=master`)
- `StatefulSet` réplicas: `22-replica-statefulset.yaml` (labels `app=redis-cluster`, `role=replica`, 3 réplicas)
- `ConfigMap` de configuração: `10-configmap.yaml` (habilita `port 6379` e `tls-port 6380`, certificados em `/tls`)
- `Secrets`:
  - `01-secret.yaml`: senha Redis (`REDIS_PASSWORD`)
  - `02-tls-certificates.yaml`: cert-manager gera `redis-tls-secret` com certs para master e réplicas
- `Services`:
  - `12-client-svc.yaml`: `ClusterIP` para `redis-tls:6380`
  - `11-headless-svc.yaml`: headless para descobrir réplicas
  - `13-master-svc.yaml`: `NodePort` para `6379:30379` e `6380:30380`, selector `app=redis-cluster, role=master`
- `NetworkPolicies`: `70-high-availability.yaml`
  - `redis-network-policy`: permite ingress entre pods Redis e acesso de faixas LAN privadas
  - `redis-replica-network-policy`: restringe réplicas e permite egress para master

Observação: o antigo `20-statefulset.yaml` foi removido por conflito com a arquitetura master/replica e falta de TLS consistente.

## Instalação
```bash
# Namespace e básicos
kubectl apply -f redis/00-namespace.yaml
kubectl apply -f redis/01-secret.yaml
kubectl apply -f redis/03-rbac.yaml

# TLS (cert-manager precisa estar instalado no cluster)
kubectl apply -f redis/02-tls-certificates.yaml
# Aguarde o secret ser criado: redis-tls-secret no namespace redis

# Configuração e serviços
kubectl apply -f redis/10-configmap.yaml
kubectl apply -f redis/11-headless-svc.yaml
kubectl apply -f redis/12-client-svc.yaml
kubectl apply -f redis/13-master-svc.yaml

# StatefulSets
kubectl apply -f redis/21-master-statefulset.yaml
kubectl apply -f redis/22-replica-statefulset.yaml

# Políticas de rede
kubectl apply -f redis/70-high-availability.yaml
```

## Execução Rápida
- UI/Stats (opcional via Ingress): `http://redis-stats.home.arpa` se aplicado
- Cliente interno: `redis-master.redis.svc.cluster.local:6379` (sem TLS) e `6380` (TLS)
- NodePort externo: `30379` (sem TLS) e `30380` (TLS)

```bash
# Descobrir IP do nó
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Teste rápido sem TLS
redis-cli -h "$NODE_IP" -p 30379 -a Admin@123 ping

# Mapear DNS e testar TLS
echo "$NODE_IP redis.home.arpa" | sudo tee -a /etc/hosts
redis-cli --tls --insecure -h redis.home.arpa -p 30380 -a Admin@123 ping
```

## Verificação
- `kubectl -n redis get pods`
- `kubectl -n redis get svc redis-master -o wide`
- `kubectl -n redis get endpoints redis-master -o wide`
- `kubectl -n redis get netpol`

## Testes Internos (Cluster)
```bash
# Sem TLS
kubectl -n redis run -it redis-tester --image=redis:7-alpine --restart=Never -- sh -lc 'redis-cli -h redis-master -p 6379 -a Admin@123 ping'

# Com TLS (certs montados nos pods Redis; para tester usar "--insecure")
kubectl -n redis run -it redis-tester-tls --image=redis:7-alpine --restart=Never -- sh -lc 'redis-cli --tls --insecure -h redis-master -p 6380 -a Admin@123 ping'
```

## Testes Externos (NodePort)
```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Sem TLS
redis-cli -h "$NODE_IP" -p 30379 -a Admin@123 ping

# Com TLS (usar seu DNS apontando para o IP do nó)
echo "$NODE_IP redis.home.arpa" | sudo tee -a /etc/hosts
redis-cli --tls --insecure -h redis.home.arpa -p 30380 -a Admin@123 ping
```

## Troubleshooting
- NodePort retorna "Connection refused":
  - Verifique endpoints: `kubectl -n redis get endpoints redis-master`
  - Confirme iptables NodePort: `sudo iptables -t nat -L KUBE-NODEPORTS -n | grep -E '30379|30380'`
  - CNI/NetworkPolicy: aplique `70-high-availability.yaml` e confirme labels do namespace: `kubectl get ns redis -o jsonpath='{.metadata.labels}'`
- TLS falha: valide que `redis-tls-secret` existe e que `tls-port 6380` está no `10-configmap.yaml`.

## Senha Padrão
- `Admin@123` (armazenada em `redis/01-secret.yaml`). Altere conforme necessidade.

## Remoção
```bash
kubectl delete -f redis/22-replica-statefulset.yaml || true
kubectl delete -f redis/21-master-statefulset.yaml || true
kubectl delete -f redis/13-master-svc.yaml -f redis/12-client-svc.yaml -f redis/11-headless-svc.yaml || true
kubectl delete -f redis/10-configmap.yaml -f redis/03-rbac.yaml -f redis/01-secret.yaml || true
kubectl delete -f redis/02-tls-certificates.yaml || true
kubectl delete -f redis/70-high-availability.yaml || true
kubectl delete namespace redis
```

## Licença
MIT License