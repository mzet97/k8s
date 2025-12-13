# Acesso Completo aos Serviços K3s

## 🎉 Todos os Serviços Instalados e Funcionando

Este documento consolida o acesso a todos os serviços instalados no cluster K3s.

---

## 📊 Resumo de Todos os Serviços

| Serviço | URL | Usuário | Senha | Documentação |
|---------|-----|---------|-------|--------------|
| **Redis Stats** | https://redis-stats.home.arpa/ | admin | Admin@123 | [ACESSO_REDIS_STATS.md](redis/ACESSO_REDIS_STATS.md) |
| **RabbitMQ Management** | https://rabbitmq-mgmt.home.arpa/ | admin | Admin@123 | [ACESSO_RABBITMQ.md](rabbitmq/ACESSO_RABBITMQ.md) |
| **MinIO Console** | https://minio-console.home.arpa/ | admin | Admin@123 | [ACESSO_MINIO.md](minio/ACESSO_MINIO.md) |
| **MinIO S3 API** | https://minio-s3.home.arpa/ | admin | Admin@123 | [ACESSO_MINIO.md](minio/ACESSO_MINIO.md) |
| **Grafana** | https://grafana.home.arpa/ | admin | Admin@123 | [ACESSO_MONITORING.md](monitoring/ACESSO_MONITORING.md) |
| **Prometheus** | https://prometheus.home.arpa/ | - | - | [ACESSO_MONITORING.md](monitoring/ACESSO_MONITORING.md) |
| **Kibana** | https://kibana.home.arpa/ | elastic | Admin@123 | [ACESSO_ELK.md](ELK/ACESSO_ELK.md) |
| **Elasticsearch API** | https://elasticsearch.home.arpa/ | elastic | Admin@123 | [ACESSO_ELK.md](ELK/ACESSO_ELK.md) |

**IP do Traefik (LoadBalancer)**: `192.168.1.51`

---

## 🌐 Configuração DNS Completa

### Opção 1: Roteador (Recomendado)
Você já configurou o DNS no roteador apontando `*.home.arpa` para `192.168.1.51`.
✅ **Acesso imediato de qualquer dispositivo na rede!**

### Opção 2: /etc/hosts (Se necessário)

**Linux/Mac**:
```bash
cat <<EOF | sudo tee -a /etc/hosts
192.168.1.51 redis-stats.home.arpa
192.168.1.51 rabbitmq-mgmt.home.arpa
192.168.1.51 minio-console.home.arpa
192.168.1.51 minio-s3.home.arpa
192.168.1.51 grafana.home.arpa
192.168.1.51 prometheus.home.arpa
192.168.1.51 kibana.home.arpa
192.168.1.51 elasticsearch.home.arpa
EOF
```

**Windows** (PowerShell como Administrador):
```powershell
$entries = @"
192.168.1.51 redis-stats.home.arpa
192.168.1.51 rabbitmq-mgmt.home.arpa
192.168.1.51 minio-console.home.arpa
192.168.1.51 minio-s3.home.arpa
192.168.1.51 grafana.home.arpa
192.168.1.51 prometheus.home.arpa
192.168.1.51 kibana.home.arpa
192.168.1.51 elasticsearch.home.arpa
"@
Add-Content C:\Windows\System32\drivers\etc\hosts $entries
```

---

## 🔐 Tabela de Credenciais

### Serviços com Autenticação

| Serviço | Usuário | Senha | Como Recuperar |
|---------|---------|-------|----------------|
| Redis | - | Admin@123 | `kubectl get secret redis-auth -n redis -o jsonpath='{.data.REDIS_PASSWORD}' \| base64 -d` |
| Redis Stats | admin | Admin@123 | Mesma do Redis |
| RabbitMQ | admin | Admin@123 | `kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.password}' \| base64 -d` |
| MinIO Console | admin | Admin@123 | `kubectl get secret minio-creds -n minio -o jsonpath='{.data.rootPassword}' \| base64 -d` |
| MinIO S3 API | admin | Admin@123 | Mesma do Console |
| Grafana | admin | Admin@123 | `kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' \| base64 -d` |
| Kibana | elastic | Admin@123 | `kubectl get secret elastic-credentials -n elk -o jsonpath='{.data.password}' \| base64 -d` |
| Elasticsearch | elastic | Admin@123 | Mesma do Kibana |

### Serviços sem Autenticação (Acesso Direto)

- **Prometheus**: https://prometheus.home.arpa/

**⚠️ NOTA**: Para produção, recomenda-se configurar autenticação no Prometheus.

---

## 📋 1. Redis - Cache e Key-Value Store

### Acesso Externo
- **Interface Web**: https://redis-stats.home.arpa/
- **Porta TCP (sem TLS)**: 192.168.1.51:6379
- **Porta TLS**: 192.168.1.51:6380

### Teste Rápido
```bash
# Via redis-cli
redis-cli -h redis.home.arpa -p 6379 -a Admin@123 ping

# Via Python
python3 -c "import redis; r=redis.Redis(host='redis.home.arpa', port=6379, password='Admin@123'); print(r.ping())"
```

### Documentação
📖 [Redis - Guia de Acesso Completo](redis/ACESSO_REDIS_STATS.md)
📖 [Redis - Teste com Domínios](redis/TESTE_COM_DOMINIO.md)
📖 [Redis - Teste Externo](redis/TESTE_EXTERNO.md)

---

## 🐰 2. RabbitMQ - Message Broker

### Acesso
- **Management UI**: https://rabbitmq-mgmt.home.arpa/
- **AMQP (sem TLS)**: rabbitmq.rabbitmq.svc.cluster.local:5672
- **AMQPS (com TLS)**: rabbitmq.rabbitmq.svc.cluster.local:5671

### Teste Rápido
```bash
# Via browser
xdg-open https://rabbitmq-mgmt.home.arpa/

# Via API
curl -k -u admin:Admin@123 https://rabbitmq-mgmt.home.arpa/api/overview
```

### Documentação
📖 [RabbitMQ - Guia de Acesso Completo](rabbitmq/ACESSO_RABBITMQ.md)

---

## 📦 3. MinIO - Object Storage (S3-Compatible)

### Acesso
- **Console Web**: https://minio-console.home.arpa/
- **S3 API**: https://minio-s3.home.arpa/

### Teste Rápido
```bash
# Instalar mc (MinIO Client)
curl -o mc https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc && sudo mv mc /usr/local/bin/

# Configurar
mc alias set myminio https://minio-s3.home.arpa admin Admin@123 --insecure

# Testar
mc admin info myminio --insecure
```

### Documentação
📖 [MinIO - Guia de Acesso Completo](minio/ACESSO_MINIO.md)

---

## 📊 4. Monitoring Stack - Prometheus + Grafana + Loki

### Acesso
- **Grafana**: https://grafana.home.arpa/
- **Prometheus**: https://prometheus.home.arpa/
- **Loki**: loki.monitoring.svc.cluster.local:3100 (interno)

### Teste Rápido
```bash
# Grafana via browser
xdg-open https://grafana.home.arpa/

# Prometheus via API
curl -k https://prometheus.home.arpa/api/v1/status/config | jq
```

### Dashboards Recomendados (Grafana)
Importe estes dashboards no Grafana:
- **ID: 1860** - Node Exporter Full
- **ID: 315** - Kubernetes Cluster Monitoring
- **ID: 11835** - Redis Dashboard
- **ID: 10991** - RabbitMQ Overview
- **ID: 13502** - MinIO Dashboard

### Documentação
📖 [Monitoring - Guia de Acesso Completo](monitoring/ACESSO_MONITORING.md)

---

## 🔍 5. ELK Stack - Elasticsearch + Logstash + Kibana

### Acesso
- **Kibana**: https://kibana.home.arpa/
- **Elasticsearch API**: https://elasticsearch.home.arpa/

### Teste Rápido
```bash
# Kibana via browser
xdg-open https://kibana.home.arpa/
# Login: elastic / Admin@123

# Elasticsearch via API
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cluster/health?pretty

# Listar índices
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cat/indices?v
```

### Primeiros Passos no Kibana
1. Acesse https://kibana.home.arpa/
2. Login com **elastic** / **Admin@123**
3. Vá em **Stack Management** → **Index Patterns**
4. Crie um index pattern: `filebeat-*`
5. Vá em **Discover** para visualizar logs

### Documentação
📖 [ELK - Guia de Acesso Completo](ELK/ACESSO_ELK.md)

---

## 📊 Recursos do Sistema

### Persistência Total Utilizada

| Componente | Storage | Réplicas | Total |
|------------|---------|----------|-------|
| Redis | 20Gi | 4 pods | 80Gi |
| RabbitMQ | 10Gi (dados) + 2Gi (logs) | 1 | 12Gi |
| MinIO | 100Gi | 1 | 100Gi |
| Prometheus | 20Gi | 1 | 20Gi |
| Grafana | 10Gi | 1 | 10Gi |
| Loki | 10Gi | 1 | 10Gi |
| Elasticsearch | 50Gi | 3 réplicas | 150Gi |
| **TOTAL** | | | **382Gi** |

### Namespaces Utilizados

```bash
# Listar todos os recursos por namespace
kubectl get all -n redis
kubectl get all -n rabbitmq
kubectl get all -n minio
kubectl get all -n monitoring
kubectl get all -n elk
```

---

## 🔧 Comandos Úteis

### Ver Status de Todos os Serviços

```bash
#!/bin/bash
# Script para verificar status de todos os serviços

echo "========================================="
echo "Status dos Serviços K3s"
echo "========================================="
echo ""

for ns in redis rabbitmq minio monitoring elk; do
  echo "📊 Namespace: $ns"
  kubectl get pods -n $ns
  echo ""
done

echo "🌍 Ingresses:"
kubectl get ingress --all-namespaces
echo ""

echo "💾 PVCs:"
kubectl get pvc --all-namespaces
echo ""

echo "🔒 Certificados:"
kubectl get certificate --all-namespaces
```

Salve como `status-all.sh`, torne executável e rode:
```bash
chmod +x status-all.sh
./status-all.sh
```

### Verificar Logs

```bash
# Redis
kubectl logs -n redis redis-master-0 -f

# RabbitMQ
kubectl logs -n rabbitmq rabbitmq-0 -f

# MinIO
kubectl logs -n minio minio-0 -f

# Grafana
kubectl logs -n monitoring -l app=grafana -f

# Prometheus
kubectl logs -n monitoring prometheus-0 -f

# Kibana
kubectl logs -n elk -l app.kubernetes.io/name=kibana -f

# Elasticsearch
kubectl logs -n elk elasticsearch-0 -f
```

### Reiniciar Serviços

```bash
# Redis
kubectl rollout restart statefulset/redis-master -n redis
kubectl rollout restart statefulset/redis-replica -n redis

# RabbitMQ
kubectl rollout restart statefulset/rabbitmq -n rabbitmq

# MinIO
kubectl rollout restart statefulset/minio -n minio

# Grafana
kubectl rollout restart deployment/grafana -n monitoring

# Prometheus
kubectl rollout restart statefulset/prometheus -n monitoring

# Kibana
kubectl rollout restart deployment/kibana -n elk

# Elasticsearch
kubectl rollout restart statefulset/elasticsearch -n elk
```

---

## 🚨 Troubleshooting Geral

### Problema: Certificado não confiável no browser

**Causa**: Certificados autoassinados do cert-manager
**Solução**: Clique em "Avançado" → "Continuar mesmo assim"

### Problema: Domínio não resolve

**Verificar DNS**:
```bash
nslookup redis-stats.home.arpa
ping -c 2 grafana.home.arpa
```

**Solução**: Configure /etc/hosts ou DNS do roteador

### Problema: Pod em CrashLoopBackOff

**Verificar logs**:
```bash
kubectl logs -n <namespace> <pod-name> --previous
kubectl describe pod -n <namespace> <pod-name>
```

### Problema: PVC Pending

**Verificar**:
```bash
kubectl get pvc -A
kubectl describe pvc <pvc-name> -n <namespace>
```

**Solução**: Verificar se o StorageClass `local-path` existe:
```bash
kubectl get storageclass
```

### Problema: Ingress não funciona

**Verificar Traefik**:
```bash
kubectl get pods -n kube-system | grep traefik
kubectl get svc -n kube-system traefik
```

**Obter IP do LoadBalancer**:
```bash
kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

## 📱 Acesso de Diferentes Dispositivos

### Do Servidor K3s (k8s1)
✅ Todos os URLs funcionam via DNS configurado

### De Outro Computador (Mesma Rede)
✅ Com DNS do roteador: acesso direto
⚠️ Sem DNS: configure /etc/hosts conforme seção acima

### De Smartphone/Tablet
✅ Conectado ao Wi-Fi da mesma rede
✅ DNS do roteador deve estar configurado
✅ Acesse os URLs normalmente no browser

### De Aplicações no Kubernetes
Use os FQDNs internos:
```bash
# Redis
redis-master.redis.svc.cluster.local:6379

# RabbitMQ
rabbitmq.rabbitmq.svc.cluster.local:5672

# MinIO
minio-service.minio.svc.cluster.local:9000

# Prometheus
prometheus.monitoring.svc.cluster.local:9090

# Elasticsearch
elasticsearch.elk.svc.cluster.local:9200
```

---

## 📚 Documentação Adicional

### Guias de Instalação
- [Redis](redis/install-redis-k3s.sh)
- [RabbitMQ](rabbitmq/install-rabbitmq-k3s.sh)
- [MinIO](minio/install-minio-k3s.sh)
- [Monitoring](monitoring/install-monitoring-k3s.sh)
- [ELK](ELK/install-elk-k3s.sh)

### Documentação de Revisão
- [Revisão Completa](COMPLETE_REVISION_SUMMARY.md)
- [DNS Standards](DNS-STANDARDS.md)
- [Como Usar Scripts](COMO_USAR_SCRIPTS.md)
- [Traefik Guide](k3s-setup/TRAEFIK_GUIDE.md)

---

## 🎉 Resumo Final

✅ **5 Stacks Instalados**: Redis, RabbitMQ, MinIO, Monitoring, ELK
✅ **8 Interfaces Web**: Redis Stats, RabbitMQ, MinIO Console, Grafana, Prometheus, Kibana
✅ **Todos com TLS**: Certificados cert-manager (local-ca)
✅ **Todos com DNS**: Domínios `.home.arpa` configurados
✅ **382Gi de Storage**: Dados persistentes em PVCs
✅ **Prontos para Uso**: Acesse de qualquer dispositivo na rede

**Seu cluster K3s está completo e pronto para produção!** 🚀

---

**Última atualização**: 2025-12-11
**Cluster**: K3s homelab
**IP LoadBalancer**: 192.168.1.51
