# Redis - In-Memory Database (K3s Homelab)

Redis com replicação master-replica para K3s.

## 🚀 Visão Rápida

- **Namespace**: `redis`
- **Arquitetura**: 1 master + 3 replicas
- **Redis Commander**: https://redis-stats.home.arpa/
- **Senha**: `Admin@123`
- **Acesso externo**: 192.168.1.51:6379 (sem TLS) / :6380 (com TLS)

## 📦 Componentes Instalados

### StatefulSets
- `redis-master`: 1 réplica (read/write)
- `redis-replica`: 3 réplicas (read-only)

### Services
- `redis-master` (ClusterIP): Portas 6379, 6380
- `redis-master-lb` (LoadBalancer): Acesso externo via 192.168.1.51
- `redis-master-nodeport` (NodePort): Portas 30379, 30380
- `redis-cluster` (ClusterIP): Para replicas (6380)
- `redis-replica-headless` (Headless): Para replicas (6380)

### Redis Commander
- **Deployment**: Interface web para gerenciar Redis
- **Ingress**: https://redis-stats.home.arpa/
- **Service**: redis-commander:8081

## 🛠️ Instalação

```bash
cd /home/k8s1/k8s/redis

# Aplicar todas as configurações
kubectl apply -f .
```

## 🔌 Acesso

### Redis Commander (Web UI)
- **URL**: https://redis-stats.home.arpa/
- **Senha**: `Admin@123`

### Conexões Redis

**Dentro do cluster Kubernetes** (sem TLS):
```
redis://redis-master.redis.svc.cluster.local:6379
```

**Dentro do cluster Kubernetes** (com TLS):
```
rediss://redis-master.redis.svc.cluster.local:6380
```

**De fora do cluster** (via LoadBalancer):
```bash
# Sem TLS
redis-cli -h 192.168.1.51 -p 6379 -a Admin@123

# Com TLS
redis-cli -h 192.168.1.51 -p 6380 -a Admin@123 --tls --insecure
```

## 💻 Exemplos de Código

### Python (redis-py)
```python
import redis

# Conexão sem TLS (interno)
r = redis.Redis(
    host='redis-master.redis.svc.cluster.local',
    port=6379,
    password='Admin@123',
    decode_responses=True
)

# Set/Get
r.set('key', 'value')
print(r.get('key'))

# Hash
r.hset('user:1', mapping={'name': 'John', 'age': 30})
print(r.hgetall('user:1'))

# Lista
r.lpush('mylist', 'value1', 'value2')
print(r.lrange('mylist', 0, -1))

# Pub/Sub
p = r.pubsub()
p.subscribe('channel')
r.publish('channel', 'message')
```

### Node.js (ioredis)
```javascript
const Redis = require('ioredis');

// Conexão
const redis = new Redis({
    host: 'redis-master.redis.svc.cluster.local',
    port: 6379,
    password: 'Admin@123'
});

// Set/Get
await redis.set('key', 'value');
const value = await redis.get('key');
console.log(value);

// Hash
await redis.hmset('user:1', 'name', 'John', 'age', 30);
const user = await redis.hgetall('user:1');
console.log(user);

// Pub/Sub
const subscriber = new Redis({
    host: 'redis-master.redis.svc.cluster.local',
    port: 6379,
    password: 'Admin@123'
});

subscriber.subscribe('channel', (err, count) => {
    console.log(`Subscribed to ${count} channel(s)`);
});

subscriber.on('message', (channel, message) => {
    console.log(`Received ${message} from ${channel}`);
});

redis.publish('channel', 'Hello World!');
```

### Java (Jedis)
```java
import redis.clients.jedis.Jedis;

// Conexão
Jedis jedis = new Jedis("redis-master.redis.svc.cluster.local", 6379);
jedis.auth("Admin@123");

// Set/Get
jedis.set("key", "value");
String value = jedis.get("key");
System.out.println(value);

// Hash
jedis.hset("user:1", "name", "John");
jedis.hset("user:1", "age", "30");
Map<String, String> user = jedis.hgetAll("user:1");
System.out.println(user);

// Close
jedis.close();
```

### .NET (StackExchange.Redis)
```csharp
using StackExchange.Redis;

// Conexão
var redis = ConnectionMultiplexer.Connect(
    "redis-master.redis.svc.cluster.local:6379,password=Admin@123"
);
var db = redis.GetDatabase();

// Set/Get
db.StringSet("key", "value");
var value = db.StringGet("key");
Console.WriteLine(value);

// Hash
db.HashSet("user:1", new HashEntry[] {
    new HashEntry("name", "John"),
    new HashEntry("age", "30")
});
var user = db.HashGetAll("user:1");
foreach (var entry in user)
{
    Console.WriteLine($"{entry.Name}: {entry.Value}");
}
```

## 🔧 Operações Comuns

### Verificar Status
```bash
# Status dos pods
kubectl get pods -n redis

# Status dos services
kubectl get svc -n redis

# Logs do master
kubectl logs -n redis redis-master-0 -f

# Logs das replicas
kubectl logs -n redis redis-replica-0 -f
```

### Conectar via redis-cli
```bash
# No master
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123

# Na replica
kubectl exec -it -n redis redis-replica-0 -- redis-cli -a Admin@123

# Comandos úteis
INFO replication
INFO stats
KEYS *
DBSIZE
FLUSHALL
```

### Verificar Replicação
```bash
# No master
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 INFO replication

# Nas replicas
kubectl exec -n redis redis-replica-0 -- redis-cli -a Admin@123 INFO replication
kubectl exec -n redis redis-replica-1 -- redis-cli -a Admin@123 INFO replication
kubectl exec -n redis redis-replica-2 -- redis-cli -a Admin@123 INFO replication
```

### Alterar Senha
```bash
# Editar secret
kubectl edit secret redis-secret -n redis

# Ou recriar
kubectl delete secret redis-secret -n redis
kubectl create secret generic redis-secret \
  --from-literal=redis-password=newpassword \
  -n redis

# Reiniciar pods
kubectl delete pod redis-master-0 -n redis
kubectl delete pod redis-replica-0 redis-replica-1 redis-replica-2 -n redis
```

## 📊 Monitoramento

### Métricas via INFO
```bash
# Informações gerais
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 INFO

# Memória
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 INFO memory

# Estatísticas
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 INFO stats

# Clientes conectados
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 CLIENT LIST
```

### Redis Commander
Acesse https://redis-stats.home.arpa/ para:
- Ver keys e valores
- Monitorar memória
- Ver conexões
- Executar comandos
- Visualizar estatísticas

## 💾 Backup e Recovery

### Backup (RDB)
```bash
# Forçar save
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 SAVE

# Ou background save
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 BGSAVE

# Copiar arquivo RDB
kubectl cp redis/redis-master-0:/data/dump.rdb ./backup-dump.rdb
```

### Restore
```bash
# Copiar backup para pod
kubectl cp ./backup-dump.rdb redis/redis-master-0:/data/dump.rdb

# Reiniciar Redis
kubectl delete pod redis-master-0 -n redis
```

### Exportar/Importar Keys
```bash
# Exportar todas as keys
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 --scan > keys.txt

# Exportar com valores (usando DUMP/RESTORE)
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 --rdb dump.rdb
```

## 🚨 Troubleshooting

### Pod não inicia
```bash
# Ver logs
kubectl logs -n redis redis-master-0

# Descrever pod
kubectl describe pod -n redis redis-master-0

# Verificar PVC
kubectl get pvc -n redis
```

### Replica não sincroniza
```bash
# Ver status de replicação no master
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 INFO replication

# Ver logs da replica
kubectl logs -n redis redis-replica-0

# Forçar resync
kubectl delete pod redis-replica-0 -n redis
```

### Memória cheia
```bash
# Ver uso de memória
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 INFO memory

# Limpar cache
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 FLUSHALL

# Ou limpar database específico
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 FLUSHDB
```

### Conexão recusada
```bash
# Verificar senha
kubectl get secret redis-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d

# Testar conexão
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 PING
```

### Reiniciar
```bash
# Reiniciar master
kubectl delete pod redis-master-0 -n redis

# Reiniciar replicas
kubectl delete pod redis-replica-0 redis-replica-1 redis-replica-2 -n redis

# Ou rollout restart
kubectl rollout restart statefulset/redis-master -n redis
kubectl rollout restart statefulset/redis-replica -n redis
```

## 🔒 Segurança

### Senha Atual
```bash
# Ver senha
kubectl get secret redis-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d
```

### TLS
Redis está configurado para aceitar conexões TLS na porta 6380:
```bash
# Conectar com TLS
redis-cli -h redis-master.redis.svc.cluster.local -p 6380 -a Admin@123 --tls --insecure
```

### Network Policy
Configure políticas de rede para limitar acesso:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-network-policy
  namespace: redis
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: myapp
    ports:
    - protocol: TCP
      port: 6379
```

## 🔄 Alta Disponibilidade

### Arquitetura Atual
- 1 master (read/write)
- 3 replicas (read-only)
- Replicação assíncrona

### Read from Replicas
Para distribuir carga de leitura:

**Python**:
```python
import redis

# Master para writes
master = redis.Redis(host='redis-master.redis.svc.cluster.local', port=6379, password='Admin@123')

# Replica para reads
replica = redis.Redis(host='redis-replica-0.redis-replica-headless.redis.svc.cluster.local', port=6380, password='Admin@123')

# Write no master
master.set('key', 'value')

# Read da replica
value = replica.get('key')
```

## 🧹 Remoção

```bash
# Remover tudo
kubectl delete namespace redis

# Ou remover componentes individuais
kubectl delete statefulset redis-master redis-replica -n redis
kubectl delete deployment redis-commander -n redis
kubectl delete svc --all -n redis
kubectl delete ingress --all -n redis
kubectl delete pvc --all -n redis
```

## 📚 Referências

- [Redis Docs](https://redis.io/documentation)
- [Redis Commands](https://redis.io/commands)
- [Redis Replication](https://redis.io/topics/replication)
- [Redis Python Client](https://redis-py.readthedocs.io/)
- [Redis Node.js Client](https://github.com/luin/ioredis)

## 📄 Licença

MIT
