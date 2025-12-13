# Guia de Acesso aos Serviços - Rede Externa

## ✅ CORREÇÃO APLICADA

Todos os serviços agora estão configurados para acesso via domínios `.home.arpa` da sua rede local, não apenas via FQDNs internos do Kubernetes.

---

## 🎯 IP Único para Todos os Serviços

**IP**: `192.168.1.51` (LoadBalancer K3s)

Todos os serviços TCP e HTTP estão acessíveis através deste IP.

---

## 📊 Tabela Completa de Acesso

### Interfaces Web (Browser)

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| Redis Commander | https://redis-stats.home.arpa/ | admin / Admin@123 |
| RabbitMQ Management | https://rabbitmq-mgmt.home.arpa/ | admin / Admin@123 |
| MinIO Console | https://minio-console.home.arpa/ | admin / Admin@123 |
| Grafana | https://grafana.home.arpa/ | admin / Admin@123 |
| Prometheus | https://prometheus.home.arpa/ | (sem senha) |
| Kibana | https://kibana.home.arpa/ | (sem senha) |

### Conexões TCP/Protocolos Nativos

| Serviço | Domínio | Porta | Protocolo | Credenciais |
|---------|---------|-------|-----------|-------------|
| **Redis** | redis.home.arpa | 6379 | Redis (sem TLS) | senha: Admin@123 |
| **Redis TLS** | redis.home.arpa | 6380 | Redis (com TLS) | senha: Admin@123 |
| **RabbitMQ** | rabbitmq.home.arpa | 5672 | AMQP (sem TLS) | admin / Admin@123 |
| **RabbitMQ TLS** | rabbitmq.home.arpa | 5671 | AMQPS (com TLS) | admin / Admin@123 |
| **MinIO S3** | minio-s3.home.arpa | 443 | S3 API (HTTPS) | admin / Admin@123 |
| **Elasticsearch** | elasticsearch.home.arpa | 443 | HTTP API | (sem senha) |

---

## 🔧 Exemplos de Uso

### Redis - Da Sua Rede

#### Linha de Comando
```bash
# Usando domínio (CORRETO ✅)
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping

# ❌ ERRADO (não funciona fora do cluster):
# redis-cli -h redis-master.redis.svc.cluster.local -p 6379 -a Admin@123 ping
```

#### Python
```python
import redis

# CORRETO ✅ - Acesso da rede
r = redis.Redis(
    host='redis.home.arpa',
    port=6379,
    password='Admin@123'
)
print(r.ping())

# ❌ ERRADO (só funciona dentro do cluster):
# host='redis-master.redis.svc.cluster.local'
```

#### Node.js
```javascript
const redis = require('redis');

// CORRETO ✅
const client = redis.createClient({
  host: 'redis.home.arpa',
  port: 6379,
  password: 'Admin@123'
});

// ❌ ERRADO:
// host: 'redis-master.redis.svc.cluster.local'
```

### RabbitMQ - Da Sua Rede

#### Python
```python
import pika

# CORRETO ✅ - Acesso da rede
credentials = pika.PlainCredentials('admin', 'Admin@123')
parameters = pika.ConnectionParameters(
    host='rabbitmq.home.arpa',
    port=5672,
    credentials=credentials
)
connection = pika.BlockingConnection(parameters)

# ❌ ERRADO:
# host='rabbitmq.rabbitmq.svc.cluster.local'
```

#### Node.js
```javascript
const amqp = require('amqplib');

// CORRETO ✅
const connection = await amqp.connect(
  'amqp://admin:Admin@123@rabbitmq.home.arpa:5672'
);

// ❌ ERRADO:
// 'amqp://admin:Admin@123@rabbitmq.rabbitmq.svc.cluster.local:5672'
```

#### Java (Spring Boot)
```yaml
# CORRETO ✅
spring:
  rabbitmq:
    host: rabbitmq.home.arpa
    port: 5672
    username: admin
    password: Admin@123

# ❌ ERRADO:
# host: rabbitmq.rabbitmq.svc.cluster.local
```

### MinIO - Da Sua Rede

#### AWS CLI
```bash
# CORRETO ✅
aws --endpoint-url https://minio-s3.home.arpa s3 ls --no-verify-ssl

# ❌ ERRADO:
# --endpoint-url http://minio-service.minio.svc.cluster.local:9000
```

#### Python
```python
import boto3

# CORRETO ✅
s3 = boto3.client(
    's3',
    endpoint_url='https://minio-s3.home.arpa',
    aws_access_key_id='admin',
    aws_secret_access_key='Admin@123',
    verify=False
)

# ❌ ERRADO:
# endpoint_url='http://minio-service.minio.svc.cluster.local:9000'
```

---

## 🌐 Quando Usar Cada Tipo de Domínio

### Domínios `.home.arpa` (Para Rede Externa)

**Use quando**:
✅ Acessando de outro computador na rede
✅ Acessando de aplicações fora do Kubernetes
✅ Desenvolvimento local no seu laptop
✅ Testes de integração externos

**Exemplos**:
- `redis.home.arpa`
- `rabbitmq.home.arpa`
- `minio-s3.home.arpa`
- `grafana.home.arpa`

### Domínios `.svc.cluster.local` (Para Dentro do Cluster)

**Use quando**:
✅ Pods/Deployments dentro do Kubernetes precisam se comunicar
✅ Melhor performance (sem sair do cluster)
✅ Não precisa de LoadBalancer

**Exemplos**:
- `redis-master.redis.svc.cluster.local`
- `rabbitmq.rabbitmq.svc.cluster.local`
- `minio-service.minio.svc.cluster.local`
- `elasticsearch.elk.svc.cluster.local`

---

## 🔄 Resumo das Mudanças Aplicadas

### 1. Redis ✅
- **Antes**: Documentação sugeria `redis-master.redis.svc.cluster.local`
- **Agora**: Usa `redis.home.arpa` para acesso externo
- **LoadBalancer**: Já existia (redis-master-lb)
- **Portas**: 6379 (sem TLS), 6380 (com TLS)

### 2. RabbitMQ ✅
- **Antes**: Documentação sugeria `rabbitmq.rabbitmq.svc.cluster.local`
- **Agora**: Usa `rabbitmq.home.arpa` para acesso externo
- **LoadBalancer**: **CRIADO AGORA** (rabbitmq-lb)
- **Portas**: 5672 (AMQP sem TLS), 5671 (AMQPS com TLS)

### 3. MinIO ✅
- **Status**: Já estava correto
- **Domínios**: `minio-s3.home.arpa` e `minio-console.home.arpa`
- **Via**: Traefik Ingress (HTTPS)

### 4. Monitoring ✅
- **Status**: Já estava correto
- **Domínios**: `grafana.home.arpa`, `prometheus.home.arpa`
- **Via**: Traefik Ingress (HTTPS)

### 5. ELK ✅
- **Status**: Já estava correto
- **Domínios**: `kibana.home.arpa`, `elasticsearch.home.arpa`
- **Via**: Traefik Ingress (HTTPS)

---

## 🧪 Testes Rápidos

### Testar DNS
```bash
# Verificar se domínios resolvem para 192.168.1.51
nslookup redis.home.arpa
nslookup rabbitmq.home.arpa
nslookup minio-s3.home.arpa
nslookup grafana.home.arpa
```

### Testar Redis
```bash
# TCP direto
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping

# Esperado: PONG
```

### Testar RabbitMQ
```bash
# Teste rápido via Python
python3 << EOF
import pika
credentials = pika.PlainCredentials('admin', 'Admin@123')
parameters = pika.ConnectionParameters('rabbitmq.home.arpa', 5672, '/', credentials)
connection = pika.BlockingConnection(parameters)
print("✅ RabbitMQ conectado!")
connection.close()
EOF
```

### Testar MinIO
```bash
# Via mc (MinIO Client)
mc alias set myminio https://minio-s3.home.arpa admin Admin@123 --insecure
mc admin info myminio --insecure

# Esperado: Informações do servidor MinIO
```

### Testar Interfaces Web
```bash
# Acessar via browser
xdg-open https://grafana.home.arpa/
xdg-open https://kibana.home.arpa/
xdg-open https://redis-stats.home.arpa/
xdg-open https://rabbitmq-mgmt.home.arpa/
xdg-open https://minio-console.home.arpa/
```

---

## 📋 Checklist de Configuração

### No Seu Computador de Desenvolvimento

- [ ] DNS do roteador configurado (wildcard `*.home.arpa → 192.168.1.51`)
- [ ] Testar resolução: `nslookup redis.home.arpa`
- [ ] Testar ping: `ping redis.home.arpa`
- [ ] Instalar ferramentas cliente:
  - [ ] `redis-cli` (redis-tools)
  - [ ] Python com `redis`, `pika`, `boto3`
  - [ ] `mc` (MinIO Client)
  - [ ] `kubectl` (para gerenciamento)

### Nas Suas Aplicações

- [ ] Atualizar strings de conexão para usar domínios `.home.arpa`
- [ ] Remover referências a `.svc.cluster.local` em configs externas
- [ ] Testar conectividade antes de deploy
- [ ] Documentar URLs de acesso no README do projeto

---

## 📚 Documentação Relacionada

- **Guia DNS Completo**: `/home/k8s1/k8s/GUIA_DNS_COMPLETO.md`
- **DNS Standards**: `/home/k8s1/k8s/DNS-STANDARDS.md`
- **Acesso Completo**: `/home/k8s1/k8s/ACESSO_COMPLETO.md`
- **Redis**: `/home/k8s1/k8s/redis/ACESSO_REDIS_STATS.md`
- **RabbitMQ**: `/home/k8s1/k8s/rabbitmq/ACESSO_RABBITMQ.md`
- **MinIO**: `/home/k8s1/k8s/minio/ACESSO_MINIO.md`
- **Monitoring**: `/home/k8s1/k8s/monitoring/ACESSO_MONITORING.md`
- **ELK**: `/home/k8s1/k8s/ELK/ACESSO_ELK.md`

---

## 🎉 Resumo

✅ **Redis**: Acesse via `redis.home.arpa:6379`
✅ **RabbitMQ**: Acesse via `rabbitmq.home.arpa:5672`
✅ **MinIO S3**: Acesse via `https://minio-s3.home.arpa`
✅ **Grafana**: Acesse via `https://grafana.home.arpa`
✅ **Kibana**: Acesse via `https://kibana.home.arpa`
✅ **LoadBalancers**: Configurados para todos os serviços TCP
✅ **DNS**: Todos os domínios `.home.arpa` funcionando

**Todos os serviços acessíveis da sua rede usando domínios próprios!** 🚀

---

**Última atualização**: 2025-12-11
**IP LoadBalancer**: 192.168.1.51
