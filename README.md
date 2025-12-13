# Kubernetes Homelab (K3s)

Cluster Kubernetes K3s para homelab com stack completo de serviços.

## 🚀 Quick Start

### Acesso Rápido aos Serviços
📖 **[Ver Guia de Acesso Rápido](ACESSO_RAPIDO.md)** - Todas as URLs, usuários e senhas

| Serviço | URL | Docs |
|---------|-----|------|
| **Grafana** | https://grafana.home.arpa | [/monitoring](monitoring/) |
| **Prometheus** | https://prometheus.home.arpa | [/monitoring](monitoring/) |
| **Kibana** | https://kibana.home.arpa | [/ELK](ELK/) |
| **RabbitMQ** | https://rabbitmq-mgmt.home.arpa | [/rabbitmq](rabbitmq/) |
| **MinIO** | https://minio-console.home.arpa | [/minio](minio/) |
| **Redis Commander** | https://redis-stats.home.arpa | [/redis](redis/) |

**Senha padrão**: `Admin@123` (maioria dos serviços)
**IP do Traefik**: `192.168.1.51`

## 📦 Componentes Instalados

### Core Infrastructure
- **K3s**: Kubernetes lightweight distribution
- **Traefik**: Ingress controller e LoadBalancer (192.168.1.51)
- **cert-manager**: Gerenciamento de certificados TLS
- **local-path-provisioner**: Storage class padrão

### Monitoring & Logging
- **Prometheus**: Coleta de métricas
- **Grafana**: Visualização e dashboards
- **Loki**: Agregação de logs
- **node-exporter**: Métricas de nodes
- **kube-state-metrics**: Métricas do Kubernetes
- **Elasticsearch**: Busca e análise de logs
- **Kibana**: Visualização de logs
- **Logstash**: Processamento de logs
- **Filebeat**: Coleta de logs

### Databases & Message Queues
- **Redis**: In-memory database (1 master + 3 replicas)
- **RabbitMQ**: Message broker AMQP
- **MinIO**: Object storage (S3-compatible)

### Management
- **Portainer**: Gerenciamento visual do cluster

## 📚 Documentação

### Guias de Acesso
- **[ACESSO_RAPIDO.md](ACESSO_RAPIDO.md)** - ⭐ URLs, usuários e senhas de todos os serviços
- [ACESSO_COMPLETO.md](ACESSO_COMPLETO.md) - Guia detalhado de acesso
- [ACESSO_REDE_EXTERNA.md](ACESSO_REDE_EXTERNA.md) - Configuração para acesso externo

### Por Serviço
- [Monitoring (Prometheus + Grafana)](monitoring/README.md)
- [ELK Stack (Elasticsearch + Kibana)](ELK/README.md)
- [Redis](redis/README.md)
- [RabbitMQ](rabbitmq/README.md)
- [MinIO](minio/README.md)
- [K3s Setup](k3s-setup/README.md)
- [Certificados](certs/README.md)

### Guias Técnicos
- [Guia DNS Completo](GUIA_DNS_COMPLETO.md) - Configuração DNS detalhada
- [Padrões DNS](DNS-STANDARDS.md) - Convenções de nomenclatura
- [Como Usar Scripts](COMO_USAR_SCRIPTS.md) - Guia de scripts de instalação

## 🔧 Comandos Úteis

### Status Geral
```bash
# Ver todos os pods
kubectl get pods --all-namespaces

# Ver todos os services
kubectl get svc --all-namespaces

# Ver todos os ingress
kubectl get ingress --all-namespaces
```

### Por Namespace
```bash
kubectl get all -n monitoring   # Prometheus, Grafana, Loki
kubectl get all -n elk          # Elasticsearch, Kibana
kubectl get all -n rabbitmq     # RabbitMQ
kubectl get all -n minio        # MinIO
kubectl get all -n redis        # Redis
```

## 🚨 Troubleshooting Rápido

```bash
# 1. Verificar pod
kubectl get pods -n <namespace>

# 2. Ver logs
kubectl logs -n <namespace> <pod-name>

# 3. Verificar eventos
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 4. Verificar ingress
kubectl get ingress -n <namespace>

# 5. Verificar certificados
kubectl get certificate -n <namespace>
```

Ver documentação completa de troubleshooting em [ACESSO_RAPIDO.md](ACESSO_RAPIDO.md#troubleshooting-rápido)

## 🗂️ Estrutura do Repositório

```
.
├── README.md                  # Este arquivo
├── ACESSO_RAPIDO.md          # ⭐ Guia rápido de acesso
├── monitoring/               # Prometheus + Grafana + Loki
├── ELK/                      # Elasticsearch + Kibana + Logstash
├── redis/                    # Redis master-replica
├── rabbitmq/                 # RabbitMQ message broker
├── minio/                    # MinIO object storage
├── k3s-setup/               # Instalação e configuração K3s
├── certs/                   # Certificados TLS
└── archive/                 # Documentação arquivada
```

## 📄 Licença

MIT

---

⚠️ **Nota**: Esta configuração é para **homelab/desenvolvimento**.
Para produção, altere senhas e endureça a segurança!
