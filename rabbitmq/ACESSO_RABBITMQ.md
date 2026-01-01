# Como Acessar o RabbitMQ

## 🚀 RabbitMQ Instalado e Funcionando

### Management UI (Interface Web)
- **URL**: https://rabbitmq-mgmt.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123`

## 2. Acesso ao Broker (AMQP)

O RabbitMQ está exposto diretamente na porta **5672** do nó (HostPort).

- **Host:** `rabbitmq.home.arpa` (ou IP `192.168.1.51`)
- **Porta:** `5672`
- **Usuário:** `admin`
- **Senha:** `Admin@123`

### ⚠️ Connection String (Importante)
Como a senha contém `@`, você **DEVE** codificá-la como `%40` na URL de conexão.

**Correto:**
```
amqp://admin:Admin%40123@rabbitmq.home.arpa:5672/
```

**Incorreto (Vai falhar):**
```
amqp://admin:Admin@123@rabbitmq.home.arpa:5672/
```

## 🌐 Configuração DNS

Configure os seguintes domínios para apontar para `192.168.1.51`:

### No Roteador (Recomendado)
Configure wildcard DNS ou adicione entradas específicas:
```
rabbitmq-mgmt.home.arpa  → 192.168.1.51
rabbitmq.home.arpa       → 192.168.1.51
```

### No /etc/hosts (Linux/Mac)
```bash
sudo tee -a /etc/hosts <<EOF
192.168.1.51 rabbitmq-mgmt.home.arpa
192.168.1.51 rabbitmq.home.arpa
EOF
```

### No Windows
Edite `C:\Windows\System32\drivers\etc\hosts` como Administrador:
```
192.168.1.51 rabbitmq-mgmt.home.arpa
192.168.1.51 rabbitmq.home.arpa
```

## 📋 Informações da Instalação

| Item | Valor |
|------|-------|
| **Management UI** | https://rabbitmq-mgmt.home.arpa/ |
| **AMQP** | rabbitmq.home.arpa:5672 |
| **AMQPS** | rabbitmq.home.arpa:5671 |
| **Traefik IP** | 192.168.1.51 |
| **Namespace** | rabbitmq |
| **StatefulSet** | rabbitmq (1 réplica) |
| **TLS** | ✅ Sim (cert-manager local-ca) |
| **Persistência** | ✅ Dados: 10Gi, Logs: 2Gi |

## 💻 Exemplos de Código

### Python (pika)
```python
import pika

# Usando domínio
credentials = pika.PlainCredentials('admin', 'Admin@123')
parameters = pika.ConnectionParameters(
    host='rabbitmq.home.arpa',
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

// Usando domínio
const connection = await amqp.connect('amqp://admin:Admin@123@rabbitmq.home.arpa:5672');
const channel = await connection.createChannel();

// Declarar fila
await channel.assertQueue('hello');

// Publicar mensagem
channel.sendToQueue('hello', Buffer.from('Hello World!'));
console.log("Mensagem enviada!");

await channel.close();
await connection.close();
```

### Java (Spring Boot)
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

### .NET (RabbitMQ.Client)
```csharp
using RabbitMQ.Client;

var factory = new ConnectionFactory
{
    HostName = "rabbitmq.home.arpa",
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

## 🧪 Testar Acesso

### Via Browser
1. Abra: https://rabbitmq-mgmt.home.arpa/
2. Aceite o certificado self-signed
3. Login: `admin` / `Admin@123`
4. Você deve ver o dashboard do RabbitMQ

### Via curl
```bash
# Testar API
curl -k -u admin:Admin@123 https://rabbitmq-mgmt.home.arpa/api/overview

# Testar se o domínio resolve
nslookup rabbitmq-mgmt.home.arpa

# Ou
ping rabbitmq.home.arpa
```

### Via rabbitmq-diagnostics
```bash
# Dentro do pod
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl status
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl cluster_status
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_users
```

## 🔧 Status do Serviço

```bash
# Ver pods
kubectl get pods -n rabbitmq

# Ver services
kubectl get svc -n rabbitmq

# Ver ingress
kubectl get ingress -n rabbitmq

# Ver logs
kubectl logs -n rabbitmq rabbitmq-0 -f

# Entrar no pod
kubectl exec -it -n rabbitmq rabbitmq-0 -- bash
```

## 🚨 Troubleshooting

### "No available server" na UI
**Causa**: O JavaScript não consegue conectar à API do RabbitMQ

**Soluções**:
1. Limpe o cache do browser (Ctrl+Shift+Del)
2. Verifique se o domínio está configurado no /etc/hosts ou DNS
3. Teste em modo anônimo/privado
4. Verifique se o RabbitMQ está rodando:
```bash
kubectl get pods -n rabbitmq
kubectl logs -n rabbitmq rabbitmq-0 --tail=50
```

### Conexão AMQP recusada
```bash
# Verificar se a porta está aberta
telnet rabbitmq.home.arpa 5672

# Ou usar nc
nc -zv rabbitmq.home.arpa 5672

# Verificar LoadBalancer
kubectl get svc rabbitmq-lb -n rabbitmq
```

### Login não funciona
```bash
# Verificar credenciais
kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.username}' | base64 -d
kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.password}' | base64 -d

# Listar usuários no RabbitMQ
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_users
```

### Certificado inválido
É esperado pois usamos certificados self-signed:
```bash
# Verificar certificado
kubectl get certificate -n rabbitmq

# Ver detalhes
kubectl describe certificate rabbitmq-management-tls -n rabbitmq
```

## 🔒 Segurança

### Credenciais Configuradas

| Usuário | Secret | Uso |
|---------|--------|-----|
| admin | rabbitmq-admin | Administração e aplicações |

### Alterar Senha
```bash
# Via kubectl
kubectl edit secret rabbitmq-admin -n rabbitmq

# Ou via rabbitmqctl
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl change_password admin 'NovaSenha@123'

# Reiniciar para aplicar mudanças do secret
kubectl delete pod rabbitmq-0 -n rabbitmq
```

### Criar Novos Usuários
```bash
# Via kubectl exec
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl add_user myuser mypassword
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl set_permissions -p / myuser ".*" ".*" ".*"
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl set_user_tags myuser administrator

# Via Management UI
1. Acesse Admin → Users
2. Clique em "Add a user"
3. Configure permissões
```

## 📊 Monitoramento

### Prometheus Metrics
```bash
# Interno
curl http://rabbitmq.rabbitmq.svc.cluster.local:15692/metrics

# Externo (via ingress se configurado)
curl -k https://rabbitmq-mgmt.home.arpa/metrics
```

### Grafana Dashboard
Importar dashboards no Grafana:
- Dashboard ID: 10991 (RabbitMQ-Overview)
- Dashboard ID: 4279 (RabbitMQ Monitoring)

## 💾 Backup e Recovery

### Backup de Definições
```bash
# Exportar
curl -k -u admin:Admin@123 https://rabbitmq-mgmt.home.arpa/api/definitions -o rabbitmq-definitions.json
```

### Restore de Definições
```bash
# Importar
curl -k -u admin:Admin@123 -H "Content-Type: application/json" \
  -X POST --data @rabbitmq-definitions.json \
  https://rabbitmq-mgmt.home.arpa/api/definitions
```

## 📚 Referências

- [RabbitMQ Docs](https://www.rabbitmq.com/documentation.html)
- [Management Plugin](https://www.rabbitmq.com/management.html)
- [AMQP Concepts](https://www.rabbitmq.com/tutorials/amqp-concepts.html)
- [Prometheus Monitoring](https://www.rabbitmq.com/prometheus.html)

## 🎉 Resumo

✅ RabbitMQ instalado e funcionando
✅ Management UI: https://rabbitmq-mgmt.home.arpa/
✅ AMQP: rabbitmq.home.arpa:5672
✅ Login: admin / Admin@123
✅ TLS configurado com cert-manager
✅ Persistência: Dados (10Gi) + Logs (2Gi)
✅ Pronto para receber conexões!

**Aproveite sua fila de mensagens!** 🐰
