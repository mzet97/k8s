# 🚀 Guia de Acesso Rápido - K3s Homelab

Documentação consolidada de acesso a todos os serviços do cluster K3s.

## 📊 Resumo dos Serviços

| Serviço | URL/Domínio | Usuário | Senha | Porta Externa |
|---------|-----|---------|-------|---------------|
| **Grafana** | https://grafana.home.arpa | admin | Admin@123 | - |
| **Prometheus** | https://prometheus.home.arpa | - | - | - |
| **Kibana** | https://kibana.home.arpa | - | - | - |
| **RabbitMQ** | https://rabbitmq-mgmt.home.arpa | admin | Admin@123 | rabbitmq.home.arpa:5672 |
| **MinIO Console** | https://minio-console.home.arpa | admin | Admin@123 | - |
| **MinIO S3 API** | https://minio-s3.home.arpa | admin | Admin@123 | - |
| **Redis Commander** | https://redis-stats.home.arpa | admin | (mesma do Redis) | - |
| **Redis (TCP)** | redis.home.arpa | - | Admin@123 | 192.168.1.51:6379, 192.168.1.51:6380 |
| **Mongo Express** | https://mongodb-console.home.arpa | admin | Admin@123 | - |
| **MongoDB (TCP)** | mongodb.home.arpa | admin | Admin@123 | 192.168.1.51:27017 |
| **NATS (TCP)** | nats://nats.home.arpa:4222 | admin | Admin@123 | 192.168.1.51:4222 |
| **NATS Monitor** | https://nats-monitor.home.arpa | - | - | - |
| **n8n** | https://n8n.home.arpa | - | (definida no primeiro acesso) | - |
| **Kong Admin API** | https://kong-admin.home.arpa | admin | Admin@123 | - |
| **Kong Manager** | https://kong-manager.home.arpa | admin | Admin@123 | - |
| **Authentik** | https://authentik.home.arpa | akadmin | (definida no primeiro acesso) | - |

## 🌐 Configuração DNS

Todos os domínios `*.home.arpa` apontam para o IP do Traefik LoadBalancer:

**IP do Traefik**: `192.168.1.51`

### Configurar no Roteador (Recomendado)
Configure wildcard DNS `*.home.arpa` → `192.168.1.51` no seu roteador/DNS local.

### Configurar no /etc/hosts (Alternativa)
```bash
# Linux/Mac
sudo tee -a /etc/hosts <<EOF
192.168.1.51 grafana.home.arpa
192.168.1.51 prometheus.home.arpa
192.168.1.51 kibana.home.arpa
192.168.1.51 elasticsearch.home.arpa
192.168.1.51 rabbitmq-mgmt.home.arpa
192.168.1.51 rabbitmq.home.arpa
192.168.1.51 minio-console.home.arpa
192.168.1.51 minio-s3.home.arpa
192.168.1.51 redis-stats.home.arpa
192.168.1.51 redis.home.arpa
192.168.1.51 mongodb-console.home.arpa
192.168.1.51 mongodb.home.arpa
192.168.1.51 nats.home.arpa
192.168.1.51 nats-monitor.home.arpa
192.168.1.51 n8n.home.arpa
192.168.1.51 kong-admin.home.arpa
192.168.1.51 kong-manager.home.arpa
192.168.1.51 authentik.home.arpa
EOF
```

## 📦 Detalhes por Serviço

### Monitoring Stack (Grafana + Prometheus)

**Grafana**:
- **URL**: https://grafana.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123`
- **Namespace**: `monitoring`
- **Recursos**: Dashboards, alertas, visualizações

**Prometheus**:
- **URL**: https://prometheus.home.arpa/
- **Namespace**: `monitoring`
- **Recursos**: Métricas, queries, targets

**Acesso interno** (aplicações no cluster):
```
http://prometheus.monitoring.svc.cluster.local:9090
http://grafana.monitoring.svc.cluster.local:3000
```

### ELK Stack (Elasticsearch + Kibana)

**Kibana**:
- **URL**: https://kibana.home.arpa/
- **Autenticação**: por padrão, sem login (quando `xpack.security.enabled: false`)
- **Se habilitar segurança no Elasticsearch**: use as credenciais do Secret `elastic-credentials` (usuário/senha)
- **Namespace**: `elk`

**Elasticsearch**:
- **Interno**: `http://elasticsearch.elk.svc.cluster.local:9200`
- **Autenticação**: por padrão, sem login (quando `xpack.security.enabled: false`)

**Filebeat**: Coleta logs automaticamente de todos os pods

### RabbitMQ

**Management UI**:
- **URL**: https://rabbitmq-mgmt.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123`
- **Namespace**: `rabbitmq`

**Conexões AMQP**:
```bash
# Interno (cluster)
amqp://admin:Admin@123@rabbitmq.rabbitmq.svc.cluster.local:5672/

# Externo (via domínio - recomendado)
amqp://admin:Admin@123@rabbitmq.home.arpa:5672/

# Externo (via IP - alternativa)
amqp://admin:Admin@123@192.168.1.51:5672/
```

### MinIO (Object Storage)

**Console**:
- **URL**: https://minio-console.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123`
- **Namespace**: `minio`

**S3 API**:
```bash
# Interno
http://minio-service.minio.svc.cluster.local:9000

# Externo
https://minio-s3.home.arpa

# Exemplo AWS CLI
aws --endpoint-url https://minio-s3.home.arpa s3 ls
```

### Redis

**Redis Commander**:
- **URL**: https://redis-stats.home.arpa/
- **Senha**: `Admin@123`
- **Namespace**: `redis`

**Conexões Redis**:
```bash
# Interno (cluster)
redis://redis-master.redis.svc.cluster.local:6379

# Externo (LoadBalancer)
redis-cli -h 192.168.1.51 -p 6379 -a Admin@123
```

**Arquitetura**: 1 master + 3 replicas

### MongoDB

**Mongo Express**:
- **URL**: https://mongodb-console.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123`
- **Namespace**: `mongodb`

**MongoDB (TCP)**:
- **Host**: `mongodb.home.arpa`
- **Porta**: `27017`
- **Connection string**: `mongodb://admin:Admin%40123@mongodb.home.arpa:27017/?authSource=admin`

### NATS

- **Servidor (TCP)**: `nats.home.arpa:4222`
- **Monitor (HTTPS)**: https://nats-monitor.home.arpa/
- **Usuário/Senha**: `admin` / `Admin@123`
- **Namespace**: `nats`

### n8n

- **URL**: https://n8n.home.arpa/
- **Primeiro acesso**: criar a conta de administrador
- **Namespace**: `n8n`

### Kong Gateway

- **Kong Admin API**: https://kong-admin.home.arpa/ (Basic Auth)
- **Kong Manager**: https://kong-manager.home.arpa/
- **Proxy (LoadBalancer)**: `http://192.168.1.51` / `https://192.168.1.51`
- **Usuário/Senha**: `admin` / `Admin@123`
- **Namespace**: `kong`

### Authentik

- **URL**: https://authentik.home.arpa/
- **Admin**: usuário `akadmin` (senha definida no primeiro acesso)
- **Namespace**: `authentik`

## 🔧 Comandos Úteis

### Verificar Status Geral
```bash
# Ver todos os namespaces
kubectl get namespaces

# Ver pods em todos os namespaces
kubectl get pods --all-namespaces

# Ver services com IPs externos
kubectl get svc --all-namespaces | grep LoadBalancer

# Ver todos os ingress
kubectl get ingress --all-namespaces
```

### Verificar Serviços Específicos
```bash
# Monitoring
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# ELK
kubectl get pods -n elk
kubectl get svc -n elk

# RabbitMQ
kubectl get pods -n rabbitmq
kubectl get svc -n rabbitmq

# NATS
kubectl get pods -n nats
kubectl get svc -n nats

# MongoDB
kubectl get pods -n mongodb
kubectl get svc -n mongodb

# MinIO
kubectl get pods -n minio
kubectl get svc -n minio

# n8n
kubectl get pods -n n8n
kubectl get svc -n n8n

# Kong
kubectl get pods -n kong
kubectl get svc -n kong

# Authentik
kubectl get pods -n authentik
kubectl get svc -n authentik

# Redis
kubectl get pods -n redis
kubectl get svc -n redis
```

### Ver Logs
```bash
# Grafana
kubectl logs -n monitoring -l app=grafana -f

# Prometheus
kubectl logs -n monitoring -l app=prometheus -f

# Kibana
kubectl logs -n elk -l app.kubernetes.io/name=kibana -f

# RabbitMQ
kubectl logs -n rabbitmq rabbitmq-0 -f

# NATS
kubectl logs -n nats nats-0 -f

# MongoDB
kubectl logs -n mongodb mongodb-0 -f

# MinIO
kubectl logs -n minio minio-0 -f

# n8n
kubectl logs -n n8n -l app.kubernetes.io/name=n8n -f

# Kong
kubectl logs -n kong -l app=kong -f

# Authentik
kubectl logs -n authentik -l app.kubernetes.io/name=authentik-server -f

# Redis
kubectl logs -n redis redis-master-0 -f
```

### Reiniciar Serviços
```bash
# Grafana
kubectl rollout restart deployment/grafana -n monitoring

# Prometheus
kubectl rollout restart statefulset/prometheus -n monitoring

# Kibana
kubectl rollout restart deployment/kibana -n elk

# RabbitMQ
kubectl delete pod rabbitmq-0 -n rabbitmq

# MinIO
kubectl delete pod minio-0 -n minio

# Redis
kubectl delete pod redis-master-0 -n redis
```

## 🔐 Credenciais Resumidas

**Senha padrão** para a maioria dos serviços: `Admin@123`

| Serviço | Usuário | Secret |
|---------|---------|--------|
| Grafana | admin | grafana-admin |
| Kibana/Elasticsearch | (depende do xpack security) | elastic-credentials |
| RabbitMQ | admin | rabbitmq-admin |
| NATS | admin | nats-auth |
| MongoDB | admin | mongodb-creds |
| MinIO | admin | minio-creds |
| Kong | admin | kong-auth |
| Authentik | akadmin | (senha definida no primeiro acesso) |
| Redis | - | redis-auth |

### Ver Senhas via kubectl
```bash
# Grafana
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d

# Elasticsearch/Kibana
kubectl get secret elastic-credentials -n elk -o jsonpath='{.data.password}' | base64 -d

# RabbitMQ
kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.password}' | base64 -d

# NATS
kubectl get secret nats-auth -n nats -o jsonpath='{.data.password}' | base64 -d

# MongoDB
kubectl get secret mongodb-creds -n mongodb -o jsonpath='{.data.mongo-root-password}' | base64 -d

# MinIO
kubectl get secret minio-creds -n minio -o jsonpath='{.data.rootPassword}' | base64 -d

# Kong
kubectl get secret kong-auth -n kong -o jsonpath='{.data.KONG_PASSWORD}' | base64 -d

# Redis
kubectl get secret redis-auth -n redis -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d
```

## 📚 Documentação Detalhada

Para informações detalhadas, consulte:
- **Monitoring**: [monitoring/README.md](monitoring/README.md) e [monitoring/ACESSO_MONITORING.md](monitoring/ACESSO_MONITORING.md)
- **ELK**: [ELK/README.md](ELK/README.md) e [ELK/ACESSO_ELK.md](ELK/ACESSO_ELK.md)
- **RabbitMQ**: [rabbitmq/README.md](rabbitmq/README.md) e [rabbitmq/ACESSO_RABBITMQ.md](rabbitmq/ACESSO_RABBITMQ.md)
- **NATS**: [nats/README.md](nats/README.md) e [nats/ACESSO_NATS.md](nats/ACESSO_NATS.md)
- **MongoDB**: [mongodb/README.md](mongodb/README.md) e [mongodb/ACESSO_MONGODB.md](mongodb/ACESSO_MONGODB.md)
- **MinIO**: [minio/README.md](minio/README.md) e [minio/ACESSO_MINIO.md](minio/ACESSO_MINIO.md)
- **n8n**: [n8n/README.md](n8n/README.md) e [n8n/ACESSO_N8N.md](n8n/ACESSO_N8N.md)
- **Kong**: [kong/ACESSO_KONG.md](kong/ACESSO_KONG.md)
- **Authentik**: [authentik/ACESSO_AUTHENTIK.md](authentik/ACESSO_AUTHENTIK.md)
- **Redis**: [redis/README.md](redis/README.md) e [redis/ACESSO_REDIS_STATS.md](redis/ACESSO_REDIS_STATS.md)

## 🚨 Troubleshooting Rápido

### Serviço não responde
```bash
# 1. Verificar se pod está rodando
kubectl get pods -n <namespace>

# 2. Ver logs
kubectl logs -n <namespace> <pod-name>

# 3. Verificar ingress
kubectl get ingress -n <namespace>

# 4. Verificar certificado TLS
kubectl get certificate -n <namespace>

# 5. Testar conectividade DNS
ping <service>.home.arpa

# 6. Verificar Traefik
kubectl get svc -n kube-system traefik
```

### Erro de certificado
Todos os certificados são self-signed via cert-manager:
```bash
# Ver certificados
kubectl get certificate --all-namespaces

# Ver issuer
kubectl get clusterissuer local-ca -o yaml
```

### Acesso negado
```bash
# Verificar senha do serviço (ver seção "Ver Senhas via kubectl" acima)

# Resetar senha do Grafana
kubectl delete secret grafana-admin -n monitoring
kubectl create secret generic grafana-admin \
  --from-literal=GF_SECURITY_ADMIN_USER=admin \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD=NewPass@123 \
  -n monitoring
kubectl rollout restart deployment/grafana -n monitoring
```

## 🛠️ Manutenção

### Atualizar Imagens
```bash
# Ver versões atuais
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].image}'

# Atualizar deployment
kubectl set image deployment/<name> <container>=<new-image> -n <namespace>

# Ou editar diretamente
kubectl edit deployment/<name> -n <namespace>
```

### Backup de Configurações
```bash
# Exportar todos os recursos
kubectl get all,cm,secret,ing,pvc --all-namespaces -o yaml > cluster-backup.yaml

# Exportar namespace específico
kubectl get all,cm,secret,ing,pvc -n monitoring -o yaml > monitoring-backup.yaml
```

## 📊 Monitoramento

### Dashboards Grafana Recomendados
1. **Node Exporter Full**: ID 1860
2. **Kubernetes Cluster Monitoring**: ID 315
3. **Prometheus Stats**: ID 2
4. **RabbitMQ Overview**: ID 10991
5. **Redis Dashboard**: ID 11835

### Importar Dashboard no Grafana
1. Acesse https://grafana.home.arpa/
2. Vá em "+ " → "Import"
3. Cole o ID do dashboard
4. Selecione data source "Prometheus"
5. Clique em "Import"

## 📞 Suporte

Para problemas específicos, consulte a seção de Troubleshooting em cada README:
- `/monitoring/README.md#troubleshooting`
- `/ELK/README.md#troubleshooting`
- `/rabbitmq/README.md#troubleshooting`
- `/minio/README.md#troubleshooting`
- `/redis/README.md#troubleshooting`
