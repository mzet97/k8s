# Redis Master-Replica para K3s

Configuração Redis Master-Replica otimizada para K3s com Traefik e ServiceLB.

## Arquitetura

### Componentes

```
┌─────────────────────────────────────────────────────────────┐
│                    K3s Cluster                               │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐                    │
│  │ Redis Master │◄─────┤ Redis        │                    │
│  │  (Pod 1)     │      │ Replica 0    │                    │
│  │              │      │              │                    │
│  │ Port: 6379   │      │ Port: 6379   │                    │
│  │ TLS:  6380   │◄─────┤ TLS:  6380   │                    │
│  └──────┬───────┘      └──────────────┘                    │
│         │                                                    │
│         │              ┌──────────────┐                    │
│         └──────────────┤ Redis        │                    │
│                        │ Replica 1    │                    │
│                        │              │                    │
│                        │ Port: 6379   │                    │
│                ┌───────┤ TLS:  6380   │                    │
│                │       └──────────────┘                    │
│                │                                            │
│                │       ┌──────────────┐                    │
│                └───────┤ Redis        │                    │
│                        │ Replica 2    │                    │
│                        │              │                    │
│                        │ Port: 6379   │                    │
│                        │ TLS:  6380   │                    │
│                        └──────────────┘                    │
│                                                              │
│  Services:                                                  │
│  ├─ redis-master (ClusterIP)      - Acesso interno         │
│  ├─ redis-master-lb (LoadBalancer) - Acesso externo (ServiceLB) │
│  ├─ redis-master-nodeport          - Fallback NodePort     │
│  └─ redis-replica-headless         - Service discovery     │
│                                                              │
│  Storage: local-path (K3s)                                  │
│  TLS: cert-manager + local-ca                              │
└─────────────────────────────────────────────────────────────┘

External Access via ServiceLB:
  <NODE_IP>:6379 (non-TLS)
  <NODE_IP>:6380 (TLS)
```

### Características

- **1 Master**: Redis em modo master (leitura/escrita)
- **3 Replicas**: Redis em modo replica (somente leitura)
- **TLS**: Habilitado na porta 6380 com certificados cert-manager
- **Non-TLS**: Porta 6379 para compatibilidade
- **High Availability**: Anti-affinity para distribuição de pods
- **Persistence**: PVC de 20Gi por pod usando local-path
- **ServiceLB**: Acesso externo via LoadBalancer do K3s (Klipper)

## Diferenças para MicroK8s

Esta configuração foi adaptada de MicroK8s para K3s com as seguintes mudanças:

### 1. StorageClass
```yaml
# Antes (MicroK8s)
storageClassName: microk8s-hostpath

# Depois (K3s)
storageClassName: local-path
```

### 2. Acesso Externo
```yaml
# Antes: Apenas NodePort
type: NodePort

# Depois: ServiceLB + NodePort (fallback)
type: LoadBalancer  # ServiceLB do K3s
```

### 3. Certificados TLS
```yaml
# Antes: CA própria do Redis
issuerRef:
  name: redis-ca-issuer
  kind: Issuer

# Depois: ClusterIssuer global do K3s
issuerRef:
  name: local-ca
  kind: ClusterIssuer
```

## Instalação Rápida

### Pré-requisitos

1. **K3s instalado e rodando**
   ```bash
   kubectl get nodes
   ```

2. **cert-manager instalado**
   ```bash
   kubectl get clusterissuer local-ca
   ```

   Se não estiver instalado:
   ```bash
   cd ~/k8s/certs
   ./install-cert-manager.sh
   ```

### Instalação Automática

```bash
cd ~/k8s/redis
./install-redis-k3s.sh
```

### Instalação Manual

```bash
# 1. Namespace e secrets
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-secret.yaml
kubectl apply -f 03-rbac.yaml

# 2. TLS Certificates (cert-manager)
kubectl apply -f 02-tls-certificates-k3s.yaml

# Aguardar certificado estar pronto
kubectl wait --for=condition=ready certificate -n redis redis-server-cert --timeout=120s

# 3. ConfigMap e Services
kubectl apply -f 10-configmap.yaml
kubectl apply -f 11-headless-svc.yaml
kubectl apply -f 12-client-svc.yaml
kubectl apply -f 13-master-svc-k3s.yaml

# 4. StatefulSets
kubectl apply -f 21-master-statefulset-k3s.yaml
kubectl apply -f 22-replica-statefulset-k3s.yaml

# Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod -l role=master -n redis --timeout=120s
kubectl wait --for=condition=ready pod -l role=replica -n redis --timeout=180s
```

## Verificação

### Status dos Pods

```bash
kubectl get pods -n redis -o wide
```

Saída esperada:
```
NAME              READY   STATUS    RESTARTS   AGE
redis-master-0    1/1     Running   0          5m
redis-replica-0   1/1     Running   0          4m
redis-replica-1   1/1     Running   0          4m
redis-replica-2   1/1     Running   0          4m
```

### Status dos Services

```bash
kubectl get svc -n redis
```

Saída esperada:
```
NAME                    TYPE           EXTERNAL-IP    PORT(S)
redis-cluster           ClusterIP      10.43.x.x      6380/TCP
redis-master            ClusterIP      10.43.x.x      6379/TCP,6380/TCP
redis-master-lb         LoadBalancer   192.168.1.51   6379:xxxxx/TCP,6380:xxxxx/TCP
redis-master-nodeport   NodePort       10.43.x.x      6379:30379/TCP,6380:30380/TCP
redis-replica-headless  ClusterIP      None           6379/TCP,6380/TCP
```

### Certificado TLS

```bash
kubectl get certificate -n redis
kubectl describe certificate -n redis redis-server-cert
```

### PVCs

```bash
kubectl get pvc -n redis
```

## Acesso ao Redis

### 1. Acesso Interno (ClusterIP)

```bash
# Non-TLS
kubectl run -it redis-cli --image=redis:7-alpine --rm \
  -- redis-cli -h redis-master.redis.svc.cluster.local -p 6379 -a Admin@123 ping

# TLS
kubectl run -it redis-cli-tls --image=redis:7-alpine --rm \
  -- redis-cli --tls --insecure -h redis-master.redis.svc.cluster.local -p 6380 -a Admin@123 ping
```

### 2. Acesso Externo (LoadBalancer - ServiceLB)

```bash
# Obter EXTERNAL-IP
EXTERNAL_IP=$(kubectl get svc -n redis redis-master-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $EXTERNAL_IP

# Non-TLS
redis-cli -h $EXTERNAL_IP -p 6379 -a Admin@123 ping

# TLS (requer certificado confiável ou --insecure)
redis-cli --tls --insecure -h $EXTERNAL_IP -p 6380 -a Admin@123 ping
```

### 3. Acesso Externo (NodePort - Fallback)

```bash
# Obter IP do Node
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo $NODE_IP

# Non-TLS
redis-cli -h $NODE_IP -p 30379 -a Admin@123 ping

# TLS
redis-cli --tls --insecure -h $NODE_IP -p 30380 -a Admin@123 ping
```

## Testes

### Testar Replicação

```bash
# Conectar ao Master e escrever dados
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 SET test "Hello from K3s"

# Ler do Master
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 GET test

# Ler de uma Replica
kubectl exec -it -n redis redis-replica-0 -- redis-cli -a Admin@123 GET test

# Ver info de replicação
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 INFO replication
```

Saída esperada no master:
```
# Replication
role:master
connected_slaves:3
slave0:ip=10.42.0.x,port=6380,state=online,offset=xxx,lag=0
slave1:ip=10.42.0.x,port=6380,state=online,offset=xxx,lag=0
slave2:ip=10.42.0.x,port=6380,state=online,offset=xxx,lag=0
```

### Testar TLS

```bash
# Extrair CA certificate
kubectl get secret -n redis redis-tls-secret -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/redis-ca.crt

# Conectar com TLS validando certificado
redis-cli --tls \
  --cacert /tmp/redis-ca.crt \
  -h $EXTERNAL_IP -p 6380 \
  -a Admin@123 \
  ping
```

## Monitoramento

### Logs

```bash
# Master logs
kubectl logs -n redis redis-master-0 -f

# Replica logs
kubectl logs -n redis redis-replica-0 -f

# Todos os pods
kubectl logs -n redis -l app=redis-cluster -f
```

### Métricas

```bash
# Stats do Redis
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 INFO stats

# Memory usage
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 INFO memory

# Clients conectados
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 CLIENT LIST
```

## Configuração Avançada

### Alterar Senha

1. Editar secret:
   ```bash
   kubectl edit secret -n redis redis-auth
   ```

2. Alterar o valor de `REDIS_PASSWORD` (base64 encoded)
   ```bash
   echo -n "NovaSenha123" | base64
   ```

3. Reiniciar pods:
   ```bash
   kubectl rollout restart statefulset -n redis redis-master
   kubectl rollout restart statefulset -n redis redis-replica
   ```

### Escalar Replicas

```bash
# Aumentar para 5 replicas
kubectl scale statefulset -n redis redis-replica --replicas=5

# Aguardar novos pods
kubectl wait --for=condition=ready pod -l role=replica -n redis --timeout=180s
```

### Ajustar Recursos

Editar StatefulSets:
```bash
kubectl edit statefulset -n redis redis-master
```

Alterar:
```yaml
resources:
  requests:
    memory: "1Gi"    # Era 512Mi
    cpu: "500m"      # Era 250m
  limits:
    memory: "4Gi"    # Era 2Gi
    cpu: "2000m"     # Era 1000m
```

### Alterar Tamanho do Volume

```bash
# Verificar se StorageClass suporta expansion
kubectl get sc local-path -o yaml | grep allowVolumeExpansion

# Se sim, editar PVC
kubectl patch pvc -n redis data-redis-master-0 -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

## Backup e Restore

### Backup Manual

```bash
# RDB snapshot
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 SAVE

# Copiar arquivo RDB
kubectl cp redis/redis-master-0:/data/dump.rdb ./backup-$(date +%Y%m%d).rdb

# Backup AOF
kubectl cp redis/redis-master-0:/data/appendonly.aof ./backup-aof-$(date +%Y%m%d).aof
```

### Restore

```bash
# Parar Redis
kubectl scale statefulset -n redis redis-master --replicas=0

# Copiar backup
kubectl cp ./backup-20251211.rdb redis/redis-master-0:/data/dump.rdb

# Reiniciar Redis
kubectl scale statefulset -n redis redis-master --replicas=1
```

## Troubleshooting

### Pods não ficam prontos

```bash
# Ver eventos
kubectl describe pod -n redis redis-master-0

# Ver logs
kubectl logs -n redis redis-master-0

# Verificar certificado
kubectl get certificate -n redis
kubectl describe certificate -n redis redis-server-cert
```

### Replicas não conectam ao Master

```bash
# Verificar logs da replica
kubectl logs -n redis redis-replica-0 | grep -i "master"

# Testar conectividade
kubectl exec -n redis redis-replica-0 -- redis-cli -h redis-master.redis.svc.cluster.local -p 6380 -a Admin@123 ping

# Verificar configuração
kubectl exec -n redis redis-replica-0 -- cat /usr/local/etc/redis/redis-replica.conf | grep replicaof
```

### LoadBalancer EXTERNAL-IP fica \<pending\>

```bash
# Verificar ServiceLB pods
kubectl get pods -n kube-system | grep svclb

# Verificar eventos do service
kubectl describe svc -n redis redis-master-lb

# Usar NodePort como fallback
kubectl get svc -n redis redis-master-nodeport
```

### TLS não funciona

```bash
# Verificar secret
kubectl get secret -n redis redis-tls-secret
kubectl describe secret -n redis redis-tls-secret

# Ver dados do certificado
kubectl get secret -n redis redis-tls-secret -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Testar TLS localmente no pod
kubectl exec -n redis redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -p 6380 -a Admin@123 ping
```

## Desinstalação

```bash
# Deletar StatefulSets
kubectl delete statefulset -n redis redis-master redis-replica

# Deletar Services
kubectl delete svc -n redis --all

# Deletar ConfigMap e Secrets
kubectl delete configmap -n redis redis-config
kubectl delete secret -n redis redis-auth redis-tls-secret

# Deletar Certificate
kubectl delete certificate -n redis redis-server-cert

# Deletar PVCs (CUIDADO: deleta dados!)
kubectl delete pvc -n redis --all

# Deletar Namespace
kubectl delete namespace redis
```

## Arquivos da Configuração K3s

| Arquivo | Descrição |
|---------|-----------|
| `21-master-statefulset-k3s.yaml` | Master StatefulSet (storageClass: local-path) |
| `22-replica-statefulset-k3s.yaml` | Replica StatefulSet (storageClass: local-path) |
| `13-master-svc-k3s.yaml` | Services com LoadBalancer (ServiceLB) |
| `02-tls-certificates-k3s.yaml` | Certificados TLS usando local-ca |
| `install-redis-k3s.sh` | Script de instalação automática |
| `README-K3S.md` | Este arquivo |

**Arquivos compartilhados** (sem mudanças):
- `00-namespace.yaml`
- `01-secret.yaml`
- `03-rbac.yaml`
- `10-configmap.yaml`
- `11-headless-svc.yaml`
- `12-client-svc.yaml`

## Comparação: MicroK8s vs K3s

| Aspecto | MicroK8s | K3s |
|---------|----------|-----|
| **StorageClass** | microk8s-hostpath | local-path |
| **Acesso Externo** | NodePort | ServiceLB + NodePort |
| **TLS Issuer** | Redis próprio CA | local-ca (cluster-wide) |
| **Ingress** | NGINX (addon) | Traefik (built-in) |
| **Peso** | ~500MB RAM | ~150MB RAM |
| **Instalação** | snap | Script simples |

## Recursos Adicionais

- [K3s Documentation](https://docs.k3s.io/)
- [Redis Documentation](https://redis.io/docs/)
- [ServiceLB Guide](../k3s-setup/SERVICELB_GUIDE.md)
- [cert-manager Guide](../certs/README.md)
- [Redis Original README](./README.md)

## Licença

MIT License
