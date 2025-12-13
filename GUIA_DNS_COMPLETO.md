# Guia Completo de DNS - Acesso Externo aos Serviços

## 🎯 IP do LoadBalancer

**IP**: `192.168.1.51`

Todos os serviços estão acessíveis através deste IP usando domínios `.home.arpa`.

---

## 📋 Tabela Completa de Domínios e Portas

### Serviços HTTP/HTTPS (via Traefik Ingress)

| Serviço | Domínio | Porta HTTPS | Porta HTTP | Tipo |
|---------|---------|-------------|------------|------|
| **Redis Stats** | redis-stats.home.arpa | 443 | 80 | Web UI |
| **RabbitMQ Management** | rabbitmq-mgmt.home.arpa | 443 | 80 | Web UI |
| **MinIO Console** | minio-console.home.arpa | 443 | 80 | Web UI |
| **MinIO S3 API** | minio-s3.home.arpa | 443 | 80 | API |
| **Grafana** | grafana.home.arpa | 443 | 80 | Web UI |
| **Prometheus** | prometheus.home.arpa | 443 | 80 | Web UI |
| **Kibana** | kibana.home.arpa | 443 | 80 | Web UI |
| **Elasticsearch** | elasticsearch.home.arpa | 443 | 80 | API |

### Serviços TCP/UDP (via LoadBalancer)

| Serviço | Domínio | Portas | Protocolo | Uso |
|---------|---------|--------|-----------|-----|
| **Redis** | redis.home.arpa | 6379, 6380 | TCP | Redis Protocol (6379: sem TLS, 6380: com TLS) |
| **RabbitMQ** | rabbitmq.home.arpa | 5672, 5671 | TCP | AMQP (5672: sem TLS, 5671: com TLS) |

---

## 🌐 Configuração de DNS

### Opção 1: DNS no Roteador (Recomendado) ✅

Você JÁ configurou wildcard DNS no roteador:
```
*.home.arpa → 192.168.1.51
```

✅ **Todos os domínios já funcionam em qualquer dispositivo da rede!**

### Opção 2: Arquivo /etc/hosts (Alternativa)

Se necessário em algum dispositivo específico:

**Linux/Mac**:
```bash
cat <<EOF | sudo tee -a /etc/hosts
# K3s Homelab Services - HTTP/HTTPS
192.168.1.51 redis-stats.home.arpa
192.168.1.51 rabbitmq-mgmt.home.arpa
192.168.1.51 minio-console.home.arpa
192.168.1.51 minio-s3.home.arpa
192.168.1.51 grafana.home.arpa
192.168.1.51 prometheus.home.arpa
192.168.1.51 kibana.home.arpa
192.168.1.51 elasticsearch.home.arpa

# K3s Homelab Services - TCP/UDP
192.168.1.51 redis.home.arpa
192.168.1.51 rabbitmq.home.arpa
EOF
```

**Windows** (PowerShell como Administrador):
```powershell
$entries = @"
# K3s Homelab Services - HTTP/HTTPS
192.168.1.51 redis-stats.home.arpa
192.168.1.51 rabbitmq-mgmt.home.arpa
192.168.1.51 minio-console.home.arpa
192.168.1.51 minio-s3.home.arpa
192.168.1.51 grafana.home.arpa
192.168.1.51 prometheus.home.arpa
192.168.1.51 kibana.home.arpa
192.168.1.51 elasticsearch.home.arpa

# K3s Homelab Services - TCP/UDP
192.168.1.51 redis.home.arpa
192.168.1.51 rabbitmq.home.arpa
"@
Add-Content C:\Windows\System32\drivers\etc\hosts $entries
```

---

## 🔌 Exemplos de Uso - Acesso Externo

### 1. Redis - Acesso TCP da Rede

#### Via redis-cli
```bash
# Sem TLS (porta 6379)
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping

# Com TLS (porta 6380)
redis-cli --tls \
  --cert /path/to/tls.crt \
  --key /path/to/tls.key \
  --cacert /path/to/ca.crt \
  -h redis.home.arpa \
  -p 6380 \
  -a Admin@123 \
  ping
```

#### Via Python
```python
import redis

# Sem TLS
r = redis.Redis(
    host='redis.home.arpa',
    port=6379,
    password='Admin@123',
    decode_responses=True
)
print(r.ping())  # True

# Com TLS
r_tls = redis.Redis(
    host='redis.home.arpa',
    port=6380,
    password='Admin@123',
    ssl=True,
    ssl_cert_reqs='required',
    ssl_ca_certs='/path/to/ca.crt',
    ssl_certfile='/path/to/tls.crt',
    ssl_keyfile='/path/to/tls.key',
    decode_responses=True
)
print(r_tls.ping())  # True
```

#### Via Node.js
```javascript
const redis = require('redis');

// Sem TLS
const client = redis.createClient({
  host: 'redis.home.arpa',
  port: 6379,
  password: 'Admin@123'
});

client.ping((err, reply) => {
  console.log(reply); // PONG
});

// Com TLS
const clientTLS = redis.createClient({
  host: 'redis.home.arpa',
  port: 6380,
  password: 'Admin@123',
  tls: {
    ca: fs.readFileSync('/path/to/ca.crt'),
    cert: fs.readFileSync('/path/to/tls.crt'),
    key: fs.readFileSync('/path/to/tls.key')
  }
});
```

### 2. RabbitMQ - Acesso AMQP da Rede

#### Via Python (pika)
```python
import pika

# Sem TLS (porta 5672)
credentials = pika.PlainCredentials('admin', 'Admin@123')
parameters = pika.ConnectionParameters(
    host='rabbitmq.home.arpa',
    port=5672,
    credentials=credentials
)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()

# Declarar fila e publicar mensagem
channel.queue_declare(queue='test')
channel.basic_publish(exchange='', routing_key='test', body='Hello from network!')
print("Mensagem enviada!")
connection.close()

# Com TLS (porta 5671)
import ssl

context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE

ssl_options = pika.SSLOptions(context)
parameters_tls = pika.ConnectionParameters(
    host='rabbitmq.home.arpa',
    port=5671,
    credentials=credentials,
    ssl_options=ssl_options
)
connection_tls = pika.BlockingConnection(parameters_tls)
```

#### Via Node.js (amqplib)
```javascript
const amqp = require('amqplib');

// Sem TLS
async function sendMessage() {
  const connection = await amqp.connect('amqp://admin:Admin@123@rabbitmq.home.arpa:5672');
  const channel = await connection.createChannel();

  await channel.assertQueue('test');
  channel.sendToQueue('test', Buffer.from('Hello from network!'));

  console.log('Mensagem enviada!');

  await channel.close();
  await connection.close();
}

// Com TLS
async function sendMessageTLS() {
  const connection = await amqp.connect('amqps://admin:Admin@123@rabbitmq.home.arpa:5671');
  // ... resto do código
}
```

#### Via Java (Spring Boot)
```yaml
# application.yml
spring:
  rabbitmq:
    host: rabbitmq.home.arpa
    port: 5672
    username: admin
    password: Admin@123
    virtual-host: /
```

### 3. MinIO - Acesso S3 API da Rede

#### Via AWS CLI
```bash
# Configurar
aws configure set aws_access_key_id admin
aws configure set aws_secret_access_key Admin@123
aws configure set region us-east-1

# Usar
aws --endpoint-url https://minio-s3.home.arpa s3 ls --no-verify-ssl
aws --endpoint-url https://minio-s3.home.arpa s3 mb s3://mybucket --no-verify-ssl
aws --endpoint-url https://minio-s3.home.arpa s3 cp file.txt s3://mybucket/ --no-verify-ssl
```

#### Via Python (boto3)
```python
import boto3
from botocore.client import Config

s3 = boto3.client(
    's3',
    endpoint_url='https://minio-s3.home.arpa',
    aws_access_key_id='admin',
    aws_secret_access_key='Admin@123',
    config=Config(signature_version='s3v4'),
    verify=False
)

# Listar buckets
buckets = s3.list_buckets()
print(buckets['Buckets'])

# Upload
s3.upload_file('local_file.txt', 'mybucket', 'remote_file.txt')
```

#### Via MinIO Client (mc)
```bash
# Configurar
mc alias set myminio https://minio-s3.home.arpa admin Admin@123 --insecure

# Usar
mc ls myminio/ --insecure
mc mb myminio/mybucket --insecure
mc cp file.txt myminio/mybucket/ --insecure
```

---

## 🧪 Testes de Conectividade

### Testar Resolução DNS
```bash
# Verificar se domínios resolvem
nslookup redis.home.arpa
nslookup rabbitmq.home.arpa
nslookup minio-s3.home.arpa

# Ou
ping -c 2 redis.home.arpa
ping -c 2 rabbitmq.home.arpa
```

### Testar Conectividade TCP
```bash
# Redis
telnet redis.home.arpa 6379
nc -zv redis.home.arpa 6379

# RabbitMQ
telnet rabbitmq.home.arpa 5672
nc -zv rabbitmq.home.arpa 5672
```

### Testar Conectividade HTTP/HTTPS
```bash
# Grafana
curl -k https://grafana.home.arpa/api/health

# Kibana
curl -k https://kibana.home.arpa/api/status

# MinIO
curl -k https://minio-s3.home.arpa/minio/health/live
```

---

## 🔒 Portas e Protocolos - Referência Completa

### Redis (redis.home.arpa)

| Porta | TLS | Protocolo | Uso |
|-------|-----|-----------|-----|
| 6379 | ❌ | Redis Protocol | Conexões Redis sem TLS |
| 6380 | ✅ | Redis Protocol + TLS | Conexões Redis com TLS |

**URL de Conexão**:
- Sem TLS: `redis://redis.home.arpa:6379`
- Com TLS: `rediss://redis.home.arpa:6380`

### RabbitMQ (rabbitmq.home.arpa)

| Porta | TLS | Protocolo | Uso |
|-------|-----|-----------|-----|
| 5672 | ❌ | AMQP 0-9-1 | Conexões AMQP sem TLS |
| 5671 | ✅ | AMQP 0-9-1 + TLS | Conexões AMQP com TLS |
| 15672 | ❌ | HTTP | Management API sem TLS |
| 15671 | ✅ | HTTPS | Management API com TLS |

**URL de Conexão**:
- AMQP sem TLS: `amqp://admin:Admin@123@rabbitmq.home.arpa:5672`
- AMQP com TLS: `amqps://admin:Admin@123@rabbitmq.home.arpa:5671`
- Management: `https://rabbitmq-mgmt.home.arpa/`

### MinIO (minio-s3.home.arpa)

| Porta | TLS | Protocolo | Uso |
|-------|-----|-----------|-----|
| 443 | ✅ | HTTPS/S3 API | API S3 com TLS (via Ingress) |

**URL de Conexão**:
- S3 API: `https://minio-s3.home.arpa`
- Console: `https://minio-console.home.arpa`

---

## 📱 Acesso de Diferentes Dispositivos

### Computador na Mesma Rede
✅ **Acesso direto** - DNS do roteador já configurado
```bash
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping
```

### Smartphone/Tablet (Wi-Fi)
✅ **Acesso direto** - Conectado ao Wi-Fi da rede
- Browsers: `https://grafana.home.arpa/`
- Apps: Usar domínios `.home.arpa`

### Docker Containers (Host na Rede)
```bash
docker run -it --rm redis:latest redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping
```

### Kubernetes Pods (Dentro do Cluster)
⚠️ **Use FQDNs internos** para melhor performance:
```bash
# Redis
redis-master.redis.svc.cluster.local:6379

# RabbitMQ
rabbitmq.rabbitmq.svc.cluster.local:5672

# MinIO
minio-service.minio.svc.cluster.local:9000
```

---

## 🚨 Troubleshooting

### Problema: Domínio não resolve

**Verificar DNS**:
```bash
nslookup redis.home.arpa
```

**Solução**:
1. Verificar DNS no roteador
2. Adicionar entrada em /etc/hosts
3. Testar com IP diretamente: `192.168.1.51`

### Problema: Conexão recusada

**Verificar se serviço está rodando**:
```bash
kubectl get svc -A | grep LoadBalancer
kubectl get pods -n redis
kubectl get pods -n rabbitmq
```

**Verificar portas**:
```bash
telnet redis.home.arpa 6379
telnet rabbitmq.home.arpa 5672
```

### Problema: TLS/SSL errors

**Para testes**, use opções de ignorar SSL:
```bash
# Redis
redis-cli --tls --insecure -h redis.home.arpa -p 6380 -a Admin@123 ping

# curl
curl -k https://grafana.home.arpa/
```

---

## 📚 Resumo de URLs

### Interfaces Web (HTTPS)
```
https://redis-stats.home.arpa/          - Redis Commander
https://rabbitmq-mgmt.home.arpa/        - RabbitMQ Management
https://minio-console.home.arpa/        - MinIO Console
https://grafana.home.arpa/              - Grafana
https://prometheus.home.arpa/           - Prometheus
https://kibana.home.arpa/               - Kibana
```

### Conexões TCP
```
redis.home.arpa:6379                    - Redis (sem TLS)
redis.home.arpa:6380                    - Redis (com TLS)
rabbitmq.home.arpa:5672                 - RabbitMQ AMQP (sem TLS)
rabbitmq.home.arpa:5671                 - RabbitMQ AMQP (com TLS)
```

### APIs
```
https://minio-s3.home.arpa              - MinIO S3 API
https://elasticsearch.home.arpa         - Elasticsearch API
```

---

**✅ Todos os serviços acessíveis via domínios `.home.arpa` da sua rede!**

**Última atualização**: 2025-12-11
