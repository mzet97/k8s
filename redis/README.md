# Redis Cluster (3 nós) para MicroK8s

Este projeto fornece manifests Kubernetes para implementar um **Redis Cluster** de alta disponibilidade com 3 nós mestres (sem réplicas) no MicroK8s, utilizando persistência local via `microk8s-hostpath`.

## Funcionalidade Principal

O Redis Cluster implementado oferece:
- **3 nós mestres** em modo cluster para distribuição automática de dados
- **Persistência de dados** com volumes persistentes de 10GB por nó
- **Anti-afinidade de pods** para distribuição em diferentes nós do cluster
- **Acesso externo** via NodePort para conectividade fora do cluster
- **Autenticação** com senha configurável
- **Health checks** com readiness e liveness probes
- **Bootstrap automatizado** do cluster via Job

## Requisitos do Sistema

### Pré-requisitos obrigatórios:
- **MicroK8s** instalado e configurado
- **Addons habilitados**: `storage`, `dns` (ingress opcional)
- **Mínimo 3 nós** no cluster Kubernetes para anti-afinidade
- **StorageClass** `microk8s-hostpath` como padrão
- **Recursos mínimos**: 1 CPU e 512MB RAM por pod Redis

### Dependências:
- **Redis 7 Alpine** (imagem oficial)
- **Kubernetes 1.20+**
- **Volumes persistentes** com suporte a ReadWriteOnce

> **⚠️ Aviso de Produção**: HostPath é *local ao nó*. Em caso de falha do nó, o PVC não migra automaticamente. Para produção/HA real, utilize storage distribuído (Rook/Ceph, NFS com RWX, etc.).

## Instalação e Configuração

### Passo 1: Configuração da Senha

Antes do deploy, configure a senha do Redis editando o arquivo `01-secret.yaml`:

```yaml
# redis/01-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-auth
  namespace: redis
type: Opaque
stringData:
  REDIS_PASSWORD: "SuaSenhaSegura123"
```

### Passo 2: Deploy dos Componentes

```bash
# 1) Criar namespace
kubectl apply -f redis/00-namespace.yaml

# 2) Aplicar configurações base
kubectl apply -f redis/01-secret.yaml
kubectl apply -f redis/10-configmap.yaml

# 3) Criar serviços
kubectl apply -f redis/11-headless-svc.yaml
kubectl apply -f redis/12-client-svc.yaml

# 4) Deploy do StatefulSet
kubectl apply -f redis/20-statefulset.yaml

# 5) Aguardar pods ficarem prontos
kubectl -n redis get pods -w
# Aguarde até ver: redis-cluster-0/1/2 1/1 Running
```

### Passo 3: Bootstrap do Cluster

```bash
# Executar job de inicialização do cluster
kubectl apply -f redis/30-bootstrap-job.yaml

# Acompanhar logs do bootstrap
kubectl -n redis logs job/redis-cluster-bootstrap -f

# Aplicar acesso externo (opcional)
kubectl apply -f redis/40-external-access.yaml
```

```
kubectl -n redis patch statefulset redis-cluster --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args","value":["\nORD=$(hostname | awk -F- \x27{print $NF}\x27)\nDATA_PORT=$((30079 + ORD))\nBUS_PORT=$((32079 + ORD))\nHOST_IP=$(awk -F= \x27/KUBERNETES_NODE_IP/ {print $2}\x27 /etc/environment 2>/dev/null || true)\n[ -z \x22$HOST_IP\x22 ] && HOST_IP=$(getent hosts $(hostname -f) | awk \x27{print $1}\x27)\nexec redis-server /usr/local/etc/redis/redis.conf \\\n  --requirepass \x22$REDIS_PASSWORD\x22 \\\n  --masterauth \x22$REDIS_PASSWORD\x22 \\\n  --cluster-announce-ip \x22$HOST_IP\x22 \\\n  --cluster-announce-port \x22$DATA_PORT\x22 \\\n  --cluster-announce-bus-port \x22$BUS_PORT\x22"] }
]'
kubectl -n redis delete pod redis-cluster-0 redis-cluster-1 redis-cluster-2
kubectl -n redis get pods -w
```

## Verificação e Exemplos de Uso

### Verificação do Status

```bash
# Verificar status dos recursos
kubectl -n redis get pods,svc,pvc

# Verificar logs dos pods
kubectl -n redis logs redis-cluster-0

# Verificar informações do cluster
POD=$(kubectl -n redis get pod -l app=redis-cluster -o jsonpath='{.items[0].metadata.name}')
kubectl -n redis exec -it $POD -- sh -lc 'redis-cli -a "$REDIS_PASSWORD" cluster info'

# Listar nós do cluster
kubectl -n redis exec -it $POD -- sh -lc 'redis-cli -a "$REDIS_PASSWORD" cluster nodes'
```

### Exemplos de Uso

#### Teste de Conectividade Interna

```bash
# Conectar via pod temporário
kubectl run redis-test --rm -it --restart=Never \
  --image=redis:7-alpine -- redis-cli \
  -h redis-cluster.redis.svc.cluster.local \
  -p 6379 -a "Admin@123"

# Testar operações básicas
127.0.0.1:6379> SET mykey "Hello Redis Cluster"
127.0.0.1:6379> GET mykey
127.0.0.1:6379> CLUSTER INFO
```

#### Acesso Externo via NodePort

```bash
# Descobrir IPs dos nós
kubectl get nodes -o wide

# Conectar externamente (substitua NODE_IP)
redis-cli -h <NODE_IP> -p 30079 -a "Admin@123"
redis-cli -h <NODE_IP> -p 30080 -a "Admin@123"
redis-cli -h <NODE_IP> -p 30081 -a "Admin@123"
```

#### Exemplo de Aplicação Cliente

```yaml
# exemplo-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-client-app
  namespace: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-client
  template:
    metadata:
      labels:
        app: redis-client
    spec:
      containers:
      - name: app
        image: redis:7-alpine
        command: ["sleep", "3600"]
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-auth
              key: REDIS_PASSWORD
        - name: REDIS_HOSTS
          value: "redis-cluster-0.redis-cluster-headless.redis.svc.cluster.local:6379,redis-cluster-1.redis-cluster-headless.redis.svc.cluster.local:6379,redis-cluster-2.redis-cluster-headless.redis.svc.cluster.local:6379"
```

## Como Conectar Aplicações

### Clientes Cluster-Aware (Recomendado)

Para aplicações que suportam Redis Cluster, configure múltiplos seed nodes:

```bash
# Endpoints dos nós individuais
redis-cluster-0.redis-cluster-headless.redis.svc.cluster.local:6379
redis-cluster-1.redis-cluster-headless.redis.svc.cluster.local:6379
redis-cluster-2.redis-cluster-headless.redis.svc.cluster.local:6379
```

**Configuração de exemplo (Node.js):**
```javascript
const Redis = require('ioredis');

const cluster = new Redis.Cluster([
  {
    host: 'redis-cluster-0.redis-cluster-headless.redis.svc.cluster.local',
    port: 6379
  },
  {
    host: 'redis-cluster-1.redis-cluster-headless.redis.svc.cluster.local', 
    port: 6379
  },
  {
    host: 'redis-cluster-2.redis-cluster-headless.redis.svc.cluster.local',
    port: 6379
  }
], {
  redisOptions: {
    password: 'Admin@123'
  }
});
```

### Single Endpoint (Limitado)

Para clientes que não suportam cluster, use o serviço principal:
```bash
redis-cluster.redis.svc.cluster.local:6379
```

> **⚠️ Limitação**: Este método não oferece descoberta automática de nós e pode ter limitações de performance.

### Acesso Externo

Para conectar de fora do cluster Kubernetes:
```bash
# NodePorts disponíveis
<NODE_IP>:30079  # redis-cluster-0
<NODE_IP>:30080  # redis-cluster-1  
<NODE_IP>:30081  # redis-cluster-2
```

## Escala / Réplicas

- Este bundle cria **3 mestres (sem réplicas)**.
- Para **mestres+réplicas** (ex.: 3 mestres + 3 réplicas), aumente `replicas: 6` no StatefulSet e altere o Job de bootstrap para `--cluster-replicas 1`.
- Para garantir 1 pod por nó, mantenha o **podAntiAffinity** configurado e 3 nós disponíveis.

## Arquitetura dos Componentes

### Estrutura dos Manifests

| Arquivo | Descrição | Função |
|---------|-----------|--------|
| `00-namespace.yaml` | Namespace Redis | Isolamento de recursos |
| `01-secret.yaml` | Credenciais | Armazena senha do Redis |
| `10-configmap.yaml` | Configuração Redis | Parâmetros do cluster |
| `11-headless-svc.yaml` | Serviço Headless | Descoberta de pods |
| `12-client-svc.yaml` | Serviço Cliente | Endpoint único |
| `20-statefulset.yaml` | StatefulSet | Pods Redis persistentes |
| `30-bootstrap-job.yaml` | Job Bootstrap | Inicialização do cluster |
| `40-external-access.yaml` | NodePort Services | Acesso externo |

### Configurações Importantes

```yaml
# Configuração do Redis (10-configmap.yaml)
port 6379
bind 0.0.0.0
protected-mode no
cluster-enabled yes
cluster-config-file /data/nodes.conf
cluster-node-timeout 5000
appendonly yes
dir /data
```

```yaml
# Anti-afinidade (20-statefulset.yaml)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: ["redis-cluster"]
        topologyKey: kubernetes.io/hostname
```

## Troubleshooting

### Problemas Comuns

**Pods não inicializam:**
```bash
# Verificar eventos
kubectl -n redis describe pods

# Verificar storage class
kubectl get storageclass
```

**Cluster não forma:**
```bash
# Verificar logs do bootstrap
kubectl -n redis logs job/redis-cluster-bootstrap

# Verificar conectividade DNS
kubectl -n redis exec redis-cluster-0 -- nslookup redis-cluster-1.redis-cluster-headless.redis.svc.cluster.local
```

**Performance issues:**
```bash
# Verificar distribuição de pods
kubectl -n redis get pods -o wide

# Verificar recursos
kubectl -n redis top pods
```

## Remoção Completa

```bash
# Remover em ordem reversa
kubectl delete -f redis/40-external-access.yaml --ignore-not-found
kubectl delete -f redis/30-bootstrap-job.yaml --ignore-not-found
kubectl delete -f redis/20-statefulset.yaml
kubectl delete -f redis/12-client-svc.yaml
kubectl delete -f redis/11-headless-svc.yaml
kubectl delete -f redis/10-configmap.yaml
kubectl delete -f redis/01-secret.yaml

# Remover PVCs (CUIDADO: apaga dados!)
kubectl -n redis delete pvc --all

# Remover namespace
kubectl delete -f redis/00-namespace.yaml
```

## Licenciamento

Este projeto está licenciado sob a **MIT License**. Consulte o arquivo [LICENSE](../LICENSE) na raiz do repositório para detalhes completos.

### Resumo da Licença MIT:
- ✅ Uso comercial permitido
- ✅ Modificação permitida  
- ✅ Distribuição permitida
- ✅ Uso privado permitido
- ❌ Sem garantias
- ❌ Sem responsabilidade do autor

**Copyright (c) 2025 Matheus Zeitune**

---

> 📝 **Contribuições**: Pull requests são bem-vindos! Para mudanças importantes, abra uma issue primeiro para discutir as alterações propostas.

