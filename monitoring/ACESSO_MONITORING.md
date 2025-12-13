# Como Acessar o Monitoring Stack (Grafana + Prometheus)

## 🚀 Stack de Monitoramento Instalado e Funcionando

### Grafana (Dashboards e Visualizações)
- **URL**: https://grafana.home.arpa/
- **Usuário**: `admin`
- **Senha**: `Admin@123`
- **Versão**: 10.4.0

### Prometheus (Métricas e Queries)
- **URL**: https://prometheus.home.arpa/
- **Sem autenticação** (acesso direto)
- **Versão**: 2.53.0

### Loki (Agregação de Logs)
- **Interno**: `http://loki.monitoring.svc.cluster.local:3100`
- **Não possui interface web** (acesso via Grafana)

## 🌐 Configuração DNS

Configure os seguintes domínios para apontar para `192.168.1.51`:

### No Roteador (Recomendado)
Configure wildcard DNS ou adicione entradas específicas:
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

## 📋 Informações da Instalação

| Componente | Detalhes |
|------------|----------|
| **Grafana UI** | https://grafana.home.arpa/ |
| **Prometheus UI** | https://prometheus.home.arpa/ |
| **Traefik IP** | 192.168.1.51 |
| **Namespace** | monitoring |
| **TLS** | ✅ Sim (cert-manager local-ca) |
| **Persistência** | ✅ Prometheus: 10Gi, Loki: 10Gi |

## 📊 Importar Dashboards Recomendados no Grafana

1. Acesse Grafana → Dashboards → "+ Import"
2. Cole o ID do dashboard
3. Selecione "Prometheus" como data source
4. Clique em "Import"

**Dashboards Recomendados**:
- **Node Exporter Full** (ID: 1860) - Métricas detalhadas do servidor
- **Kubernetes Cluster Monitoring** (ID: 315) - Visão geral do cluster
- **Kubernetes Pods** (ID: 747) - Métricas de pods
- **Prometheus Stats** (ID: 2) - Estatísticas do Prometheus
- **RabbitMQ Overview** (ID: 10991) - Métricas do RabbitMQ
- **Redis Dashboard** (ID: 11835) - Métricas do Redis
- **MinIO Dashboard** (ID: 13502) - Métricas do MinIO

## 🧪 Testar Acesso

### Via Browser

**Grafana**:
1. Abra: https://grafana.home.arpa/
2. Login: `admin` / `Admin@123`
3. Você deve ver o dashboard principal

**Prometheus**:
1. Abra: https://prometheus.home.arpa/
2. Acesso direto sem login
3. Você deve ver a interface de queries

### Via curl

```bash
# Grafana health check
curl -k -H "Host: grafana.home.arpa" https://192.168.1.51/api/health

# Prometheus health check
curl -k -H "Host: prometheus.home.arpa" https://192.168.1.51/-/healthy

# Testar query no Prometheus
curl -k -H "Host: prometheus.home.arpa" 'https://192.168.1.51/api/v1/query?query=up'
```

## 🚨 Troubleshooting

### Página não carrega

**Soluções**:
1. Limpe o cache do browser (Ctrl+Shift+Del)
2. Verifique se o domínio está configurado no /etc/hosts ou DNS
3. Teste em modo anônimo/privado
4. Verifique se os pods estão rodando:
```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=grafana --tail=50
```

### Login não funciona

```bash
# Verificar credenciais
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
```

### Dashboards não mostram dados

1. Verificar data source: Grafana → Configuration → Data sources
2. Testar conexão: Click em "Test" no data source
3. Verificar query: Use o Explore para testar queries manualmente

## 🔒 Segurança

### Alterar Senha do Grafana

**Via Grafana UI**:
1. Login com admin
2. Profile → Change Password
3. Insira a senha antiga e nova

**Via kubectl**:
```bash
kubectl edit secret grafana-admin -n monitoring
# Altere GF_SECURITY_ADMIN_PASSWORD (em base64)

# Reiniciar Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

## 🔧 Comandos Úteis

```bash
# Ver status dos pods
kubectl get pods -n monitoring

# Ver services
kubectl get svc -n monitoring

# Ver ingress
kubectl get ingress -n monitoring

# Logs do Grafana
kubectl logs -n monitoring -l app=grafana -f

# Logs do Prometheus
kubectl logs -n monitoring -l app=prometheus -f

# Reiniciar Grafana
kubectl rollout restart deployment/grafana -n monitoring

# Reiniciar Prometheus
kubectl rollout restart statefulset/prometheus -n monitoring
```

## 📚 Referências

- [Grafana Docs](https://grafana.com/docs/grafana/latest/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Loki Docs](https://grafana.com/docs/loki/latest/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)

## 🎉 Resumo

✅ Grafana: https://grafana.home.arpa/ (admin/Admin@123)
✅ Prometheus: https://prometheus.home.arpa/ (sem auth)
✅ Loki integrado ao Grafana
✅ Data sources pré-configurados
✅ TLS habilitado
✅ Persistência configurada
✅ Pronto para monitorar todo o cluster!

**Bom monitoramento!** 📊
