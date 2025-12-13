# RabbitMQ no Kubernetes (K3s Homelab)

Implantação simplificada do RabbitMQ em K3s para homelab.

## 🚀 Visão Rápida

- **Namespace**: `rabbitmq`
- **StatefulSet**: `rabbitmq` com 1 réplica
- **Acesso Web**: https://rabbitmq-mgmt.home.arpa/
- **Credenciais**: `admin` / `Admin@123`

## 📦 Componentes Instalados

### Services
- `rabbitmq` (ClusterIP): Portas 5672, 5671, 15672, 15671, 15692, 15691
- `rabbitmq-headless` (Headless): Para cluster interno
- `rabbitmq-management` (ClusterIP): Management UI (15672, 15671)
- `rabbitmq-lb` (LoadBalancer): Acesso externo via 192.168.1.51

### Volumes
- **Data**: 10Gi (persistência de mensagens)
- **Logs**: 2Gi (logs do RabbitMQ)

### Segurança
- TLS habilitado (cert-manager com local-ca)
- NetworkPolicy configurada
- Usuários: admin, app, monitoring

## 🛠️ Instalação

```bash
cd /home/k8s1/k8s/rabbitmq

# 1. Namespace e RBAC
kubectl apply -f 00-namespace.yaml
kubectl apply -f 03-rbac.yaml

# 2. Secrets
kubectl apply -f 01-secret.yaml

# 3. Certificados TLS
kubectl apply -f 02-tls-certificates.yaml

# 4. Configuração
kubectl apply -f 10-configmap.yaml

# 5. Services
kubectl apply -f 11-headless-svc.yaml
kubectl apply -f 12-client-svc.yaml
kubectl apply -f 13-management-svc.yaml
kubectl apply -f 31-rabbitmq-loadbalancer.yaml

# 6. StatefulSet
kubectl apply -f 20-statefulset.yaml

# 7. Ingress
kubectl apply -f 30-management-ingress.yaml

# 8. NetworkPolicy
kubectl apply -f 40-network-policy.yaml
```

## 🔌 Acesso

### Management UI
- **URL**: https://rabbitmq-mgmt.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123`

### Conexões AMQP

**Dentro do cluster Kubernetes** (sem TLS):
```
amqp://admin:Admin@123@rabbitmq.rabbitmq.svc.cluster.local:5672/
```

**Dentro do cluster Kubernetes** (com TLS):
```
amqps://admin:Admin@123@rabbitmq.rabbitmq.svc.cluster.local:5671/
```

**De fora do cluster** (via LoadBalancer):
```
amqp://admin:Admin@123@192.168.1.51:5672/
amqps://admin:Admin@123@192.168.1.51:5671/
```

## 💻 Exemplos de Código

### Python (pika)
```python
import pika

# Conexão sem TLS (interno)
credentials = pika.PlainCredentials('admin', 'Admin@123')
parameters = pika.ConnectionParameters(
    host='rabbitmq.rabbitmq.svc.cluster.local',
    port=5672,
    credentials=credentials
)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()

# Declarar fila
channel.queue_declare(queue='hello')

# Publicar mensagem
channel.basic_publish(exchange='', routing_key='hello', body='Hello World!')
print("Mensagem enviada!")

connection.close()
```

### Node.js (amqplib)
```javascript
const amqp = require('amqplib');

// Conexão
const connection = await amqp.connect('amqp://admin:Admin@123@rabbitmq.rabbitmq.svc.cluster.local:5672');
const channel = await connection.createChannel();

// Declarar fila
await channel.assertQueue('hello');

// Publicar mensagem
channel.sendToQueue('hello', Buffer.from('Hello World!'));
console.log("Mensagem enviada!");

await channel.close();
await connection.close();
```

## 🔧 Operações Comuns

### Verificar Status
```bash
# Status dos pods
kubectl get pods -n rabbitmq

# Status dos services
kubectl get svc -n rabbitmq

# Logs
kubectl logs -n rabbitmq rabbitmq-0 -f

# Entrar no pod
kubectl exec -it -n rabbitmq rabbitmq-0 -- bash
```

### Comandos RabbitMQ CLI
```bash
# Dentro do pod
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl status
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl cluster_status
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_queues
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_users
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_connections
```

### Gerenciar Usuários
```bash
# Criar usuário
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl add_user myuser mypassword

# Definir permissões
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl set_permissions -p / myuser ".*" ".*" ".*"

# Definir tags
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl set_user_tags myuser administrator

# Listar usuários
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_users
```

## 📊 Monitoramento

### Prometheus Metrics
```bash
# Dentro do cluster
curl http://rabbitmq.rabbitmq.svc.cluster.local:15692/metrics

# Via ingress
curl -k https://rabbitmq-mgmt.home.arpa/metrics
```

### Grafana Dashboard
Importar dashboards RabbitMQ no Grafana:
- Dashboard ID: 10991 (RabbitMQ-Overview)
- Dashboard ID: 4279 (RabbitMQ Monitoring)

## 💾 Backup e Recovery

### Backup de Definições
```bash
# Exportar definições (exchanges, queues, bindings, etc)
curl -k -u admin:Admin@123 https://rabbitmq-mgmt.home.arpa/api/definitions -o rabbitmq-definitions.json
```

### Restore de Definições
```bash
# Importar definições
curl -k -u admin:Admin@123 -H "Content-Type: application/json" \
  -X POST --data @rabbitmq-definitions.json \
  https://rabbitmq-mgmt.home.arpa/api/definitions
```

## 🚨 Troubleshooting

### Pod não inicia
```bash
# Ver logs
kubectl logs -n rabbitmq rabbitmq-0

# Descrever pod
kubectl describe pod -n rabbitmq rabbitmq-0

# Verificar eventos
kubectl get events -n rabbitmq --sort-by='.lastTimestamp'
```

### Login não funciona
```bash
# Verificar senha
kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.password}' | base64 -d
```

### Limpar mensagens
```bash
# Purge de fila via CLI
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl purge_queue <queue_name>

# Ou use a Management UI
```

### Reiniciar
```bash
# Reiniciar pod
kubectl delete pod rabbitmq-0 -n rabbitmq

# Ou rollout restart
kubectl rollout restart statefulset/rabbitmq -n rabbitmq
```

## 🔒 Segurança

### Credenciais Configuradas

| Usuário | Secret | Uso |
|---------|--------|-----|
| admin | rabbitmq-admin | Administração |
| appuser | rabbitmq-app | Aplicações |
| monitoring | rabbitmq-monitoring | Monitoramento |

### Verificar Senhas
```bash
# Admin
kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.password}' | base64 -d

# App
kubectl get secret rabbitmq-app -n rabbitmq -o jsonpath='{.data.password}' | base64 -d

# Monitoring
kubectl get secret rabbitmq-monitoring -n rabbitmq -o jsonpath='{.data.password}' | base64 -d
```

## 🧹 Remoção

```bash
# Remover tudo
kubectl delete -f 20-statefulset.yaml
kubectl delete -f 30-management-ingress.yaml
kubectl delete -f 31-rabbitmq-loadbalancer.yaml
kubectl delete -f 13-management-svc.yaml
kubectl delete -f 12-client-svc.yaml
kubectl delete -f 11-headless-svc.yaml
kubectl delete -f 10-configmap.yaml
kubectl delete -f 40-network-policy.yaml
kubectl delete -f 02-tls-certificates.yaml
kubectl delete -f 01-secret.yaml
kubectl delete -f 03-rbac.yaml
kubectl delete -f 00-namespace.yaml

# Ou deletar o namespace inteiro
kubectl delete namespace rabbitmq
```

## 📚 Referências

- [RabbitMQ Docs](https://www.rabbitmq.com/documentation.html)
- [Management Plugin](https://www.rabbitmq.com/management.html)
- [AMQP Concepts](https://www.rabbitmq.com/tutorials/amqp-concepts.html)
- [Prometheus Monitoring](https://www.rabbitmq.com/prometheus.html)

## 📄 Licença

MIT
