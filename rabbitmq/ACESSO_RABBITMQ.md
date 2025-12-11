# Como Acessar o RabbitMQ Management UI

## ✅ RabbitMQ Instalado com Sucesso

O **RabbitMQ** com Management UI está disponível em:

**URL**: https://rabbitmq-mgmt.home.arpa/

## 🔐 Credenciais de Acesso

Para acessar a interface web:
- **Usuário**: `admin`
- **Senha**: `Admin@123`

## 📋 Informações da Instalação

| Item | Valor |
|------|-------|
| **Management UI** | https://rabbitmq-mgmt.home.arpa/ |
| **AMQP (sem TLS)** | rabbitmq.rabbitmq.svc.cluster.local:5672 |
| **AMQPS (com TLS)** | rabbitmq.rabbitmq.svc.cluster.local:5671 |
| **Ingress IP** | 192.168.1.51 |
| **Namespace** | rabbitmq |
| **StatefulSet** | rabbitmq |
| **Réplicas** | 1 |
| **TLS** | ✅ Sim (cert-manager local-ca) |
| **Persistência** | ✅ Dados: 10Gi, Logs: 2Gi |

## 🌐 Configuração DNS

### Se já configurou no roteador:
✅ Você já apontou `*.home.arpa` para `192.168.1.51` no roteador
✅ Pode acessar diretamente: https://rabbitmq-mgmt.home.arpa/

### Se ainda não configurou localmente:

**Linux/Mac**:
```bash
echo "192.168.1.51 rabbitmq-mgmt.home.arpa" | sudo tee -a /etc/hosts
```

**Windows** (como Administrador):
```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "192.168.1.51 rabbitmq-mgmt.home.arpa"
```

## 🧪 Testar Acesso

### Método 1: Browser
1. Abra o navegador
2. Acesse: https://rabbitmq-mgmt.home.arpa/
3. Aceite o certificado autoassinado (é esperado)
4. Login: `admin` / `Admin@123`

### Método 2: curl
```bash
# Testar se o endpoint responde
curl -k https://rabbitmq-mgmt.home.arpa/

# Testar API
curl -k -u admin:Admin@123 https://rabbitmq-mgmt.home.arpa/api/overview
```

### Método 3: Verificar DNS
```bash
# Verificar se o domínio resolve
nslookup rabbitmq-mgmt.home.arpa

# Ou
ping rabbitmq-mgmt.home.arpa
```

## 🎯 O que você pode fazer no RabbitMQ Management

✅ **Monitorar filas** e exchanges
✅ **Criar, editar e deletar** filas, exchanges e bindings
✅ **Ver mensagens** em filas
✅ **Publicar e consumir** mensagens
✅ **Monitorar conexões** e canais
✅ **Ver estatísticas** de performance
✅ **Gerenciar usuários** e permissões
✅ **Gerenciar virtual hosts**
✅ **Configurar políticas** e parâmetros
✅ **Importar/Exportar** configurações

## 📊 Recursos da Interface

### Overview
- Status geral do cluster
- Taxa de mensagens (publicação/entrega)
- Estatísticas de nós
- Gráficos de performance

### Connections
- Lista de todas as conexões ativas
- Protocolos utilizados (AMQP, AMQPS)
- Estatísticas por conexão

### Channels
- Canais abertos por conexão
- Taxa de mensagens por canal

### Queues
- Lista de todas as filas
- Número de mensagens em cada fila
- Taxa de consumo
- Criar/deletar filas
- Purge de mensagens

### Exchanges
- Lista de exchanges
- Tipo (direct, topic, fanout, headers)
- Criar/deletar exchanges
- Visualizar bindings

### Admin
- Gerenciar usuários
- Configurar virtual hosts
- Definir políticas
- Configurar parâmetros

## 🔌 Conexão de Aplicações

### URLs de Conexão

**Dentro do Kubernetes** (sem TLS):
```
amqp://admin:Admin@123@rabbitmq.rabbitmq.svc.cluster.local:5672/
```

**Dentro do Kubernetes** (com TLS):
```
amqps://admin:Admin@123@rabbitmq.rabbitmq.svc.cluster.local:5671/
```

**De fora do cluster** (via NodePort, se configurado):
```
amqp://admin:Admin@123@192.168.1.51:<nodeport>/
```

### Exemplos de Código

#### Python (pika)
```python
import pika

# Conexão sem TLS
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

#### Python com TLS
```python
import pika
import ssl

credentials = pika.PlainCredentials('admin', 'Admin@123')
context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE

parameters = pika.ConnectionParameters(
    host='rabbitmq.rabbitmq.svc.cluster.local',
    port=5671,
    credentials=credentials,
    ssl_options=pika.SSLOptions(context)
)
connection = pika.BlockingConnection(parameters)
```

#### Node.js (amqplib)
```javascript
const amqp = require('amqplib');

// Conexão sem TLS
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

#### Java (Spring Boot)
```yaml
# application.yml
spring:
  rabbitmq:
    host: rabbitmq.rabbitmq.svc.cluster.local
    port: 5672
    username: admin
    password: Admin@123
    virtual-host: /
```

#### .NET (RabbitMQ.Client)
```csharp
using RabbitMQ.Client;

var factory = new ConnectionFactory
{
    HostName = "rabbitmq.rabbitmq.svc.cluster.local",
    Port = 5672,
    UserName = "admin",
    Password = "Admin@123"
};

using var connection = factory.CreateConnection();
using var channel = connection.CreateModel();

channel.QueueDeclare(queue: "hello",
                     durable: false,
                     exclusive: false,
                     autoDelete: false,
                     arguments: null);

var body = Encoding.UTF8.GetBytes("Hello World!");
channel.BasicPublish(exchange: "",
                     routingKey: "hello",
                     basicProperties: null,
                     body: body);
```

## 📊 Monitoramento

### Prometheus Metrics
RabbitMQ expõe métricas Prometheus na porta 15692:

```bash
# Dentro do cluster
curl http://rabbitmq.rabbitmq.svc.cluster.local:15692/metrics
```

### Grafana Dashboard
Você pode importar dashboards RabbitMQ no Grafana:
- Dashboard ID: 10991 (RabbitMQ-Overview)
- Dashboard ID: 4279 (RabbitMQ Monitoring)

## 🔧 Status do Serviço

Verificar se o RabbitMQ está rodando:

```bash
# Como usuário k8s1
kubectl get pods -n rabbitmq
kubectl get svc -n rabbitmq
kubectl get ingress -n rabbitmq
```

Ver logs:
```bash
kubectl logs -n rabbitmq rabbitmq-0 -f
```

Entrar no pod (troubleshooting):
```bash
kubectl exec -it -n rabbitmq rabbitmq-0 -- bash

# Dentro do pod, usar rabbitmqctl
rabbitmqctl status
rabbitmqctl list_queues
rabbitmqctl list_users
rabbitmqctl cluster_status
```

Reiniciar (se necessário):
```bash
kubectl rollout restart statefulset/rabbitmq -n rabbitmq
```

## 🚨 Troubleshooting

### Erro: "Página não encontrada" (404)
**Causa**: DNS não configurado
**Solução**: Configure o /etc/hosts ou DNS do roteador

### Erro: "Connection refused"
**Verificar**:
```bash
# Status do pod
kubectl get pods -n rabbitmq

# Logs
kubectl logs -n rabbitmq rabbitmq-0 --tail=50

# Port forward (teste direto)
kubectl port-forward -n rabbitmq rabbitmq-0 15672:15672
# Depois acesse: http://localhost:15672
```

### Login não funciona
**Causa**: Senha incorreta
**Solução**: Verificar senha:
```bash
kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.password}' | base64 -d
```

### Mensagens não estão sendo consumidas
**Verificar**:
1. Consumidores conectados
2. Prefetch count
3. ACKs das mensagens
4. Dead letter queues

### Disco cheio
**Verificar PVC**:
```bash
kubectl get pvc -n rabbitmq
kubectl describe pvc rabbitmq-data-rabbitmq-0 -n rabbitmq
```

**Limpar mensagens**:
- Use a UI para fazer purge das filas
- Ou use `rabbitmqctl purge_queue <queue_name>`

## 🔒 Segurança

### Credenciais Adicionais

**Usuário de Aplicação**:
```bash
# Usuário: app
kubectl get secret rabbitmq-app -n rabbitmq -o jsonpath='{.data.password}' | base64 -d
```

**Usuário de Monitoramento**:
```bash
# Usuário: monitoring
kubectl get secret rabbitmq-monitoring -n rabbitmq -o jsonpath='{.data.password}' | base64 -d
```

### Criar Novos Usuários

Via Management UI:
1. Acesse Admin → Users
2. Clique em "Add a user"
3. Configure permissões

Via CLI:
```bash
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl add_user myuser mypassword
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl set_user_tags myuser administrator
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl set_permissions -p / myuser ".*" ".*" ".*"
```

### Virtual Hosts

Criar novo vhost:
```bash
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl add_vhost /myapp
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl set_permissions -p /myapp admin ".*" ".*" ".*"
```

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

### Backup de Dados
Os dados estão em PersistentVolumes:
```bash
# Listar PVCs
kubectl get pvc -n rabbitmq

# Dados em: /var/lib/rabbitmq
# Logs em: /var/log/rabbitmq
```

## 📱 Acesso de Outros Dispositivos

### Mesmo Computador
✅ Acesse: https://rabbitmq-mgmt.home.arpa/

### Outro Computador na Mesma Rede
✅ Com DNS do roteador configurado: https://rabbitmq-mgmt.home.arpa/

### Aplicações no Kubernetes
✅ Use: `rabbitmq.rabbitmq.svc.cluster.local:5672` (AMQP)
✅ Use: `rabbitmq.rabbitmq.svc.cluster.local:5671` (AMQPS)

## 📚 Referências

- **RabbitMQ Official**: https://www.rabbitmq.com/
- **Management Plugin**: https://www.rabbitmq.com/management.html
- **AMQP 0-9-1**: https://www.rabbitmq.com/tutorials/amqp-concepts.html
- **Clustering**: https://www.rabbitmq.com/clustering.html

## 🎉 Resumo

✅ RabbitMQ instalado com sucesso
✅ Management UI: https://rabbitmq-mgmt.home.arpa/
✅ Login: admin / Admin@123
✅ TLS configurado com cert-manager
✅ Persistência: Dados (10Gi) + Logs (2Gi)
✅ Pronto para receber conexões AMQP/AMQPS

**Aproveite sua fila de mensagens!** 🐰
