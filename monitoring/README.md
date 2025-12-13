# 📊 Sistema de Monitoramento - Grafana + Prometheus + Loki (K3s)

## 🎯 O que é este projeto?

Sistema completo de **monitoramento** para Kubernetes K3s que permite:
- 📈 **Visualizar métricas** do seu cluster em dashboards
- 📝 **Agregar logs** de todas as aplicações
- 🚨 **Receber alertas** quando algo não está funcionando
- 📊 **Acompanhar performance** de aplicações e servidores

## 🏗️ Componentes Instalados

- **Grafana**: Interface web para dashboards e visualizações
- **Prometheus**: Coleta e armazena métricas do cluster
- **Loki**: Sistema de agregação de logs distribuído
- **Node Exporter**: Monitora recursos dos nodes (CPU, memória, disco)
- **Kube State Metrics**: Monitora recursos do Kubernetes (pods, services, etc.)

## ✨ O que você terá após a instalação

- 🌐 **Interface web do Grafana** - https://grafana.home.arpa/
- 🔍 **Interface do Prometheus** - https://prometheus.home.arpa/
- 📝 **Loki integrado ao Grafana** para consulta de logs
- 🔒 **Certificados TLS** para acesso seguro via cert-manager
- 💾 **Armazenamento persistente** para não perder dados
- 🚀 **Coleta automática** de métricas e logs

## 📋 Requisitos do Sistema

### ✅ Verificar se o K3s está funcionando
```bash
kubectl cluster-info
kubectl get nodes
```

### 🔧 Verificar cert-manager
```bash
# Verificar se cert-manager está instalado
kubectl get clusterissuer local-ca

# Se não estiver, instalar:
cd ~/k8s/certs && ./install-cert-manager.sh
```

### 💾 Verificar StorageClass
```bash
# K3s deve ter local-path por padrão
kubectl get storageclass local-path
```

## 🚀 Instalação Rápida

### Opção 1: Script Automatizado (Recomendado)
```bash
cd /home/k8s1/k8s/monitoring
./install-monitoring-k3s.sh
```

### Opção 2: Manual
```bash
cd /home/k8s1/k8s/monitoring

# 1. Namespace e RBAC
kubectl apply -f 00-namespace.yaml
kubectl apply -f 10-prometheus-rbac.yaml

# 2. Secrets e ConfigMaps
kubectl apply -f 01-grafana-admin-secret.yaml
kubectl apply -f 02-grafana-config-datasource.yaml
kubectl apply -f 11-prometheus-config.yaml

# 3. Certificados TLS
kubectl apply -f 42-prometheus-certificate.yaml
kubectl apply -f 32-grafana-certificate.yaml

# 4. Node Exporter e Kube State Metrics
kubectl apply -f 20-node-exporter-daemonset.yaml
kubectl apply -f 21-kube-state-metrics.yaml

# 5. Prometheus
kubectl apply -f 12-prometheus-statefulset.yaml
kubectl apply -f 40-prometheus-service.yaml
kubectl apply -f 41-prometheus-ingress.yaml

# 6. Loki
kubectl apply -f 50-loki-config.yaml

# 7. Grafana
kubectl apply -f 30-grafana-deployment.yaml
kubectl apply -f 31-grafana-ingress.yaml
```

## 🔌 Acesso

### Grafana (Dashboards)
- **URL**: https://grafana.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123` (configurada em 01-grafana-admin-secret.yaml)

### Prometheus (Métricas)
- **URL**: https://prometheus.home.arpa/
- **Sem autenticação** (acesso direto)

### Loki (Logs)
- **Interno**: `http://loki.monitoring.svc.cluster.local:3100`
- **Acesso via Grafana** (já configurado como datasource)

## 🌐 Configuração DNS

Configure os domínios para apontar para o Traefik LoadBalancer (192.168.1.51):

### No roteador (Recomendado)
```
grafana.home.arpa     → 192.168.1.51
prometheus.home.arpa  → 192.168.1.51
```

### No /etc/hosts (Linux/Mac)
```bash
sudo tee -a /etc/hosts <<EOF
192.168.1.51 grafana.home.arpa
192.168.1.51 prometheus.home.arpa
EOF
```

### No Windows
Edite `C:\Windows\System32\drivers\etc\hosts` como Administrador:
```
192.168.1.51 grafana.home.arpa
192.168.1.51 prometheus.home.arpa
```

## 📊 Usando o Grafana

### 1. Primeiro Acesso
1. Acesse https://grafana.home.arpa/
2. Login: `admin` / `Admin@123`
3. Você verá o Prometheus já configurado como datasource

### 2. Importar Dashboards
```bash
# Dashboards recomendados:
# - Node Exporter Full: ID 1860
# - Kubernetes Cluster Monitoring: ID 7249
# - Loki Dashboard: ID 13639

# No Grafana:
# Dashboards → Import → Digite o ID → Load → Select Prometheus datasource → Import
```

### 3. Consultar Métricas
```promql
# Uso de CPU por pod
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)

# Uso de memória por namespace
sum(container_memory_usage_bytes) by (namespace)

# Pods em execução
kube_pod_status_phase{phase="Running"}
```

### 4. Consultar Logs no Loki
```logql
# Todos os logs do namespace monitoring
{namespace="monitoring"}

# Logs de erro
{namespace="monitoring"} |= "error"

# Logs de um pod específico
{pod="prometheus-0"}
```

## 🔧 Operações Comuns

### Verificar Status
```bash
# Status dos pods
kubectl get pods -n monitoring

# Status dos services
kubectl get svc -n monitoring

# Status dos ingresses
kubectl get ingress -n monitoring

# PVCs
kubectl get pvc -n monitoring
```

### Ver Logs
```bash
# Logs do Grafana
kubectl logs -n monitoring -l app=grafana -f

# Logs do Prometheus
kubectl logs -n monitoring -l app=prometheus -f

# Logs do Loki
kubectl logs -n monitoring -l app=loki -f
```

### Alterar Senha do Grafana
```bash
# Editar secret
kubectl edit secret grafana-admin -n monitoring

# Ou recriar
kubectl delete secret grafana-admin -n monitoring
kubectl create secret generic grafana-admin \
  --from-literal=GF_SECURITY_ADMIN_USER=admin \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD=NovaSenha@123 \
  -n monitoring

# Reiniciar Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

### Reiniciar Componentes
```bash
# Reiniciar Grafana
kubectl rollout restart deployment/grafana -n monitoring

# Reiniciar Prometheus
kubectl rollout restart statefulset/prometheus -n monitoring

# Reiniciar Loki
kubectl rollout restart statefulset/loki -n monitoring
```

## 💾 Persistência

| Componente | Volume | StorageClass |
|------------|--------|--------------|
| Prometheus | 20Gi | local-path |
| Grafana | 10Gi | local-path |
| Loki | 10Gi | local-path |

## 🚨 Troubleshooting

### Grafana não carrega
```bash
# Verificar pod
kubectl get pods -n monitoring -l app=grafana
kubectl describe pod -n monitoring -l app=grafana

# Verificar logs
kubectl logs -n monitoring -l app=grafana

# Verificar ingress
kubectl get ingress -n monitoring grafana-ingress
```

### Prometheus não coleta métricas
```bash
# Verificar targets no Prometheus
# Acesse: https://prometheus.home.arpa/targets

# Verificar configuração
kubectl get configmap -n monitoring prometheus-config -o yaml

# Verificar service discovery
kubectl logs -n monitoring -l app=prometheus | grep discovery
```

### Loki não aparece no Grafana
```bash
# Verificar datasource
# No Grafana: Configuration → Data Sources → Loki

# Testar conexão
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://loki.monitoring.svc.cluster.local:3100/ready

# Verificar logs
kubectl logs -n monitoring -l app=loki
```

### Certificados não são criados
```bash
# Verificar cert-manager
kubectl get pods -n cert-manager

# Verificar certificados
kubectl get certificate -n monitoring
kubectl describe certificate -n monitoring prometheus-tls
kubectl describe certificate -n monitoring grafana-tls

# Verificar ClusterIssuer
kubectl get clusterissuer local-ca
```

## 🧹 Remoção

### Remover todos os componentes
```bash
kubectl delete namespace monitoring
```

### Ou remover individualmente
```bash
kubectl delete -f 31-grafana-ingress.yaml
kubectl delete -f 30-grafana-deployment.yaml
kubectl delete -f 50-loki-config.yaml
kubectl delete -f 41-prometheus-ingress.yaml
kubectl delete -f 40-prometheus-service.yaml
kubectl delete -f 12-prometheus-statefulset.yaml
kubectl delete -f 21-kube-state-metrics.yaml
kubectl delete -f 20-node-exporter-daemonset.yaml
kubectl delete -f 32-grafana-certificate.yaml
kubectl delete -f 42-prometheus-certificate.yaml
kubectl delete -f 11-prometheus-config.yaml
kubectl delete -f 02-grafana-config-datasource.yaml
kubectl delete -f 01-grafana-admin-secret.yaml
kubectl delete -f 10-prometheus-rbac.yaml
kubectl delete -f 00-namespace.yaml
```

## 📚 Componentes Opcionais

Os seguintes componentes estão disponíveis em `archive/monitoring/optional-advanced/` mas não são instalados por padrão:

- **Mimir**: Armazenamento de métricas de longo prazo
- **Tempo**: Sistema de distributed tracing
- **Pyroscope**: Continuous profiling
- **Alert Rules**: Regras de alertas Prometheus
- **ServiceMonitors**: Descoberta automática de serviços

Para instalá-los, consulte os arquivos em `archive/monitoring/optional-advanced/`.

## 📖 Referências

- [Grafana Docs](https://grafana.com/docs/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Loki Docs](https://grafana.com/docs/loki/latest/)
- [PromQL Cheatsheet](https://promlabs.com/promql-cheat-sheet/)
- [LogQL Guide](https://grafana.com/docs/loki/latest/logql/)

## 📄 Licença

MIT
