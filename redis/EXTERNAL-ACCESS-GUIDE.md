# Guia de Acesso Externo ao Redis

Este guia explica como acessar o Redis Master-Replica externamente usando diferentes métodos, incluindo o novo proxy HAProxy com terminação TLS.

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Métodos de Acesso](#métodos-de-acesso)
3. [Proxy HAProxy (Recomendado)](#proxy-haproxy-recomendado)
4. [Acesso Direto via NodePort](#acesso-direto-via-nodeport)
5. [Port-Forward](#port-forward)
6. [Configuração de DNS](#configuração-de-dns)
7. [Exemplos de Conexão](#exemplos-de-conexão)
8. [Troubleshooting](#troubleshooting)

## 🔍 Visão Geral

O Redis está configurado com:
- **TLS obrigatório** na porta 6380
- **Porta 6379 desabilitada** por segurança
- **Senha**: `Admin@123` (configurável em `01-secret.yaml`)
- **Arquitetura**: 1 Master + 3 Réplicas

## 🚀 Métodos de Acesso

### 1. Proxy HAProxy (Recomendado) ⭐

O proxy HAProxy oferece a melhor experiência para acesso externo:

#### Vantagens:
- ✅ **Sem necessidade de certificados no cliente**
- ✅ **Terminação TLS no proxy**
- ✅ **Load balancing automático**
- ✅ **Health checks integrados**
- ✅ **Monitoramento via stats**
- ✅ **Alta disponibilidade**

#### Portas Expostas:
- **30379**: Redis sem TLS (proxy faz terminação)
- **30380**: Redis com TLS opcional
- **30404**: HAProxy Stats Dashboard

### 2. Acesso Direto via NodePort

Acesso direto aos pods Redis (requer certificados TLS):
- **30380**: Redis Master com TLS
- **30381**: Redis Réplicas com TLS (opcional)

### 3. Port-Forward

Para desenvolvimento local:
```bash
kubectl port-forward -n redis svc/redis-master 6380:6380
```

## 🔧 Proxy HAProxy (Recomendado)

### Instalação

1. **Aplicar a configuração do proxy:**
```bash
kubectl apply -f 42-redis-proxy-tls.yaml
```

2. **Verificar o status:**
```bash
# Verificar pods do proxy
kubectl get pods -n redis -l app=redis-proxy

# Verificar serviços
kubectl get svc -n redis redis-proxy-service

# Verificar certificados
kubectl get secret -n redis redis-proxy-tls
```

3. **Monitorar logs:**
```bash
kubectl logs -n redis -l app=redis-proxy -f
```

### Conexão via Proxy

#### Opção 1: Sem TLS (Recomendado)
```bash
# Obter IP do nó
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Conectar via redis-cli
redis-cli -h $NODE_IP -p 30379 -a Admin@123
```

#### Opção 2: Com TLS
```bash
# Conectar com TLS (certificado auto-assinado)
redis-cli -h $NODE_IP -p 30380 -a Admin@123 --tls --insecure
```

### HAProxy Stats Dashboard

Acesse o dashboard de monitoramento:
```bash
# Via navegador
http://<NODE_IP>:30404/stats

# Via curl
curl http://<NODE_IP>:30404/stats
```

## 🌐 Acesso Direto via NodePort

### Aplicar Configuração
```bash
kubectl apply -f 41-external-access-master-replica.yaml
```

### Conexão Direta
```bash
# Obter IP do nó
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Extrair certificados (necessário para TLS)
kubectl get secret -n redis redis-tls-certs -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
kubectl get secret -n redis redis-tls-certs -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret -n redis redis-tls-certs -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key

# Conectar com certificados
redis-cli -h $NODE_IP -p 30380 -a Admin@123 \
  --tls \
  --cert tls.crt \
  --key tls.key \
  --cacert ca.crt

# Ou conectar ignorando certificados (apenas para teste)
redis-cli -h $NODE_IP -p 30380 -a Admin@123 --tls --insecure
```

## 🔄 Port-Forward

### Para o Master
```bash
# Criar port-forward
kubectl port-forward -n redis svc/redis-master 6380:6380

# Em outro terminal, conectar
redis-cli -h localhost -p 6380 -a Admin@123 --tls --insecure
```

### Para Réplicas (Leitura)
```bash
# Port-forward para réplica
kubectl port-forward -n redis svc/redis-replica 6380:6380

# Conectar para leitura
redis-cli -h localhost -p 6380 -a Admin@123 --tls --insecure
```

## 🌍 Configuração de DNS

### Opção 1: Hosts File

Adicione ao `/etc/hosts` (Linux/Mac) ou `C:\Windows\System32\drivers\etc\hosts` (Windows):
```
<NODE_IP> redis.local
<NODE_IP> redis-proxy.local
```

### Opção 2: DNS Interno

Configure seu DNS interno para apontar:
```
redis.empresa.com -> <NODE_IP>
redis-proxy.empresa.com -> <NODE_IP>
```

### Conexão via DNS
```bash
# Via proxy (sem TLS)
redis-cli -h redis-proxy.local -p 30379 -a Admin@123

# Via proxy (com TLS)
redis-cli -h redis-proxy.local -p 30380 -a Admin@123 --tls --insecure

# Direto ao master
redis-cli -h redis.local -p 30380 -a Admin@123 --tls --insecure
```

## 💻 Exemplos de Conexão

### Python
```python
import redis

# Via proxy (sem TLS) - Recomendado
r = redis.Redis(
    host='<NODE_IP>',
    port=30379,
    password='Admin@123',
    decode_responses=True
)

# Via proxy (com TLS)
r = redis.Redis(
    host='<NODE_IP>',
    port=30380,
    password='Admin@123',
    ssl=True,
    ssl_check_hostname=False,
    ssl_cert_reqs=None,
    decode_responses=True
)

# Testar conexão
print(r.ping())  # True
r.set('test', 'hello')
print(r.get('test'))  # 'hello'
```

### Node.js
```javascript
const redis = require('redis');

// Via proxy (sem TLS) - Recomendado
const client = redis.createClient({
    host: '<NODE_IP>',
    port: 30379,
    password: 'Admin@123'
});

// Via proxy (com TLS)
const clientTLS = redis.createClient({
    host: '<NODE_IP>',
    port: 30380,
    password: 'Admin@123',
    tls: {
        rejectUnauthorized: false
    }
});

// Testar conexão
client.on('connect', () => {
    console.log('Conectado ao Redis');
    client.set('test', 'hello');
    client.get('test', (err, result) => {
        console.log(result); // 'hello'
    });
});
```

### Java
```java
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

// Via proxy (sem TLS) - Recomendado
JedisPoolConfig config = new JedisPoolConfig();
JedisPool pool = new JedisPool(config, "<NODE_IP>", 30379, 2000, "Admin@123");

try (Jedis jedis = pool.getResource()) {
    System.out.println(jedis.ping()); // PONG
    jedis.set("test", "hello");
    System.out.println(jedis.get("test")); // hello
}
```

### GUIs Recomendadas

#### RedisInsight (Recomendado)
```
Host: <NODE_IP>
Port: 30379 (proxy sem TLS) ou 30380 (proxy com TLS)
Password: Admin@123
TLS: Apenas se usar porta 30380
```

#### Redis Desktop Manager
```
Host: <NODE_IP>
Port: 30379
Auth: Admin@123
SSL: Desabilitado (proxy faz terminação)
```

#### Another Redis Desktop Manager
```
Name: Redis Kubernetes
Host: <NODE_IP>
Port: 30379
Password: Admin@123
```

## 🔧 Troubleshooting

### Problemas Comuns

#### 1. Erro "Connection refused"
```bash
# Verificar se os pods estão rodando
kubectl get pods -n redis

# Verificar serviços
kubectl get svc -n redis

# Verificar logs do proxy
kubectl logs -n redis -l app=redis-proxy
```

#### 2. Erro "I/O error" ou "Server closed connection"
```bash
# Verificar se está usando a porta correta
# Porta 30379: sem TLS (via proxy)
# Porta 30380: com TLS

# Testar conectividade
telnet <NODE_IP> 30379
telnet <NODE_IP> 30380
```

#### 3. Erro de autenticação
```bash
# Verificar senha no secret
kubectl get secret -n redis redis-password -o jsonpath='{.data.password}' | base64 -d

# Testar sem senha primeiro
redis-cli -h <NODE_IP> -p 30379 ping
```

#### 4. Problemas de TLS
```bash
# Verificar certificados do proxy
kubectl get secret -n redis redis-proxy-tls

# Regenerar certificados se necessário
kubectl delete job -n redis redis-proxy-cert-generator
kubectl apply -f 42-redis-proxy-tls.yaml
```

### Comandos de Diagnóstico

```bash
# Status geral do Redis
kubectl get all -n redis

# Logs detalhados
kubectl logs -n redis -l app=redis-master --tail=100
kubectl logs -n redis -l app=redis-replica --tail=100
kubectl logs -n redis -l app=redis-proxy --tail=100

# Testar conectividade interna
kubectl exec -n redis redis-master-0 -- redis-cli --tls --insecure -a Admin@123 ping

# Verificar configuração do HAProxy
kubectl exec -n redis deployment/redis-proxy -- cat /usr/local/etc/haproxy/haproxy.cfg

# Stats do HAProxy
kubectl exec -n redis deployment/redis-proxy -- wget -qO- http://localhost:8404/stats
```

### Monitoramento

```bash
# Métricas do proxy
curl http://<NODE_IP>:30404/stats

# Status dos backends
curl http://<NODE_IP>:30404/stats | grep redis

# Logs em tempo real
kubectl logs -n redis -l app=redis-proxy -f
```

## 📊 Resumo de Portas

| Serviço | Porta | Tipo | TLS | Descrição |
|---------|-------|------|-----|-----------|
| Redis Proxy | 30379 | NodePort | ❌ | Acesso sem TLS (recomendado) |
| Redis Proxy | 30380 | NodePort | ✅ | Acesso com TLS opcional |
| HAProxy Stats | 30404 | NodePort | ❌ | Dashboard de monitoramento |
| Redis Master | 30380 | NodePort | ✅ | Acesso direto (requer certs) |
| Redis Réplicas | 30381 | NodePort | ✅ | Acesso direto (requer certs) |

## 🎯 Recomendações

1. **Use o proxy HAProxy** na porta 30379 para a melhor experiência
2. **Configure DNS** para usar nomes ao invés de IPs
3. **Monitore via HAProxy Stats** na porta 30404
4. **Use TLS apenas quando necessário** (proxy já oferece segurança)
5. **Implemente load balancing** no lado da aplicação para réplicas
6. **Configure alertas** baseados nas métricas do HAProxy

## 🔐 Segurança

- ✅ TLS obrigatório para conexões diretas
- ✅ Proxy com terminação TLS segura
- ✅ Senha forte configurável
- ✅ Porta 6379 desabilitada
- ✅ Certificados auto-renováveis
- ✅ Health checks automáticos

---

**Última atualização**: $(date)
**Versão**: 2.0
**Autor**: Sistema de Deploy Kubernetes