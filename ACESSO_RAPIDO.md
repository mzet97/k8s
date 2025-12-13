# 🚀 Guia de Acesso Rápido - K3s Homelab

Documentação consolidada de acesso a todos os serviços do cluster K3s.

## 📊 Resumo dos Serviços

| Serviço | URL | Usuário | Senha | Porta Externa |
|---------|-----|---------|-------|---------------|
| **Grafana** | https://grafana.home.arpa | admin | Admin@123 | - |
| **Prometheus** | https://prometheus.home.arpa | - | - | - |
| **Kibana** | https://kibana.home.arpa | elastic | Admin@123 | - |
| **RabbitMQ** | https://rabbitmq-mgmt.home.arpa | admin | Admin@123 | rabbitmq.home.arpa:5672 |
| **MinIO Console** | https://minio-console.home.arpa | admin | Admin@123 | - |
| **MinIO S3 API** | https://minio-s3.home.arpa | admin | Admin@123 | - |
| **Redis Commander** | https://redis-stats.home.arpa | - | Admin@123 | 192.168.1.51:6379 |
| **Portainer** | https://portainer.home.arpa | admin | (definida no setup) | - |

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
192.168.1.51 rabbitmq-mgmt.home.arpa
192.168.1.51 rabbitmq.home.arpa
192.168.1.51 minio-console.home.arpa
192.168.1.51 minio-s3.home.arpa
192.168.1.51 redis-stats.home.arpa
192.168.1.51 portainer.home.arpa
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
- **Usuário**: `elastic`
- **Senha**: `Admin@123`
- **Namespace**: `elk`

**Elasticsearch**:
- **Interno**: `http://elasticsearch.elk.svc.cluster.local:9200`
- **Usuário**: `elastic`
- **Senha**: `Admin@123`

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

### Portainer

**URL**: https://portainer.home.arpa/
- **Usuário**: `admin`
- **Senha**: (definida no primeiro acesso)
- **Namespace**: `portainer`

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

# MinIO
kubectl get pods -n minio
kubectl get svc -n minio

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

# MinIO
kubectl logs -n minio minio-0 -f

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
| Grafana | admin | grafana-admin-secret |
| Kibana | elastic | elasticsearch-credentials |
| RabbitMQ | admin | rabbitmq-admin |
| MinIO | admin | minio-creds |
| Redis | - | redis-secret |

### Ver Senhas via kubectl
```bash
# Grafana
kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d

# Elasticsearch/Kibana
kubectl get secret elasticsearch-credentials -n elk -o jsonpath='{.data.password}' | base64 -d

# RabbitMQ
kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.password}' | base64 -d

# MinIO
kubectl get secret minio-creds -n minio -o jsonpath='{.data.rootPassword}' | base64 -d

# Redis
kubectl get secret redis-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d
```

## 📚 Documentação Detalhada

Para informações detalhadas, consulte:
- **Monitoring**: `/monitoring/README.md` e `/monitoring/ACESSO_MONITORING.md`
- **ELK**: `/ELK/README.md` e `/ELK/ACESSO_ELK.md`
- **RabbitMQ**: `/rabbitmq/README.md` e `/rabbitmq/ACESSO_RABBITMQ.md`
- **MinIO**: `/minio/README.md` e `/minio/ACESSO_MINIO.md`
- **Redis**: `/redis/README.md` e `/redis/ACESSO_REDIS_STATS.md`

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
kubectl delete secret grafana-admin-secret -n monitoring
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=NewPass@123 \
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
- `/elk/README.md#troubleshooting`
- `/rabbitmq/README.md#troubleshooting`
- `/minio/README.md#troubleshooting`
- `/redis/README.md#troubleshooting`
