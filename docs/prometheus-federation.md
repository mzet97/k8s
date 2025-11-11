# Prometheus Federation

Este documento descreve a implementação do Prometheus Federation para alta disponibilidade e escalabilidade do monitoramento.

## Arquitetura

A arquitetura do Prometheus Federation consiste em:

- **Prometheus Global**: Instância global que federada métricas dos Prometheus Locais
- **Prometheus Local 1**: Instância local que coleta métricas do cluster
- **Prometheus Local 2**: Segunda instância local para redundância
- **Ingress**: Acesso externo com autenticação básica

## Componentes

### 1. ConfigMaps

- `prometheus-global-config`: Configuração do Prometheus Global
- `prometheus-local-1-config`: Configuração do Prometheus Local 1
- `prometheus-local-2-config`: Configuração do Prometheus Local 2
- `prometheus-global-rules`: Regras de alerta globais
- `prometheus-local-rules`: Regras de alerta locais

### 2. Deployments

- `prometheus-global`: 2 réplicas para alta disponibilidade
- `prometheus-local-1`: 1 réplica
- `prometheus-local-2`: 1 réplica

### 3. Serviços

- `prometheus-global-service`: Serviço do Prometheus Global
- `prometheus-local-1-service`: Serviço do Prometheus Local 1
- `prometheus-local-2-service`: Serviço do Prometheus Local 2

### 4. Ingress

- `prometheus-global-ingress`: Acesso externo ao Prometheus Global
- `prometheus-local-1-ingress`: Acesso externo ao Prometheus Local 1
- `prometheus-local-2-ingress`: Acesso externo ao Prometheus Local 2

## Instalação

### Pré-requisitos

- Kubernetes cluster rodando
- kubectl ou microk8s configurado
- Namespace `monitoring` criado
- Storage class disponível
- Ingress controller configurado
- cert-manager instalado (para TLS)

### Instalação rápida

```bash
# Tornar o script executável
chmod +x scripts/setup-prometheus-federation.sh

# Executar instalação completa
./scripts/setup-prometheus-federation.sh setup
```

### Instalação manual

```bash
# Criar namespace se não existir
kubectl create namespace monitoring

# Aplicar configurações
kubectl apply -f infrastructure/monitoring/prometheus-federation-config.yaml

# Aplicar regras
kubectl apply -f infrastructure/monitoring/prometheus-federation-rules.yaml

# Aplicar deployments
kubectl apply -f infrastructure/monitoring/prometheus-federation-deployment.yaml

# Aplicar ingress
kubectl apply -f infrastructure/monitoring/prometheus-federation-ingress.yaml
```

## Configuração

### Autenticação Básica

O script cria automaticamente um secret com autenticação básica:

```bash
# Usuário: admin
# Senha: prom-operator
```

Para criar uma senha personalizada:

```bash
# Gerar hash htpasswd
htpasswd -nb admin sua-senha-aqui | base64

# Atualizar secret
kubectl edit secret prometheus-basic-auth -n monitoring
```

### Federation

O Prometheus Global federada métricas agregadas dos Prometheus Locais:

- `job:up:avg`: Disponibilidade por job
- `job:cpu_usage:avg`: Uso de CPU por job
- `job:memory_usage:avg`: Uso de memória por job
- `job:disk_usage:avg`: Uso de disco por job

## Uso

### Comandos do script

```bash
# Configurar federation
./scripts/setup-prometheus-federation.sh setup

# Verificar status
./scripts/setup-prometheus-federation.sh status

# Testar federation
./scripts/setup-prometheus-federation.sh test

# Executar diagnóstico detalhado
./scripts/setup-prometheus-federation.sh diagnosis

# Acessar Prometheus Global
./scripts/setup-prometheus-federation.sh access

# Acessar Prometheus Local 1
./scripts/setup-prometheus-federation.sh access-local1

# Acessar Prometheus Local 2
./scripts/setup-prometheus-federation.sh access-local2

# Remover todos os recursos
./scripts/setup-prometheus-federation.sh cleanup

# Ajuda
./scripts/setup-prometheus-federation.sh help
```

### Acesso via port-forward

```bash
# Prometheus Global
kubectl port-forward -n monitoring $(kubectl get pods -n monitoring -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}') 9090:9090

# Prometheus Local 1
kubectl port-forward -n monitoring $(kubectl get pods -n monitoring -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}') 9091:9090

# Prometheus Local 2
kubectl port-forward -n monitoring $(kubectl get pods -n monitoring -l app=prometheus,component=local-2 -o jsonpath='{.items[0].metadata.name}') 9092:9090
```

### Acesso via Ingress

```bash
# Obter endereços do Ingress
kubectl get ingress -n monitoring

# Acessar via navegador
# https://prometheus-global.seu-dominio.com
# https://prometheus-local-1.seu-dominio.com
# https://prometheus-local-2.seu-dominio.com
```

## Troubleshooting

### Verificar logs

```bash
# Logs do Prometheus Global
kubectl logs -n monitoring -l app=prometheus,component=global

# Logs do Prometheus Local 1
kubectl logs -n monitoring -l app=prometheus,component=local-1

# Logs do Prometheus Local 2
kubectl logs -n monitoring -l app=prometheus,component=local-2
```

### Verificar targets

```bash
# Acessar Prometheus Global
# http://localhost:9090/targets

# Verificar se os targets estão UP
```

### Verificar federation

```bash
# Testar endpoint de federation
kubectl exec -n monitoring $(kubectl get pods -n monitoring -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}') -- wget -q -O- "http://localhost:9090/federate?match[]={__name__=~\"job:.*\"}"
```

### Problemas comuns

1. **Pods não iniciam**
   - Verificar recursos disponíveis
   - Verificar storage class
   - Verificar logs do pod

2. **Federation não funciona**
   - Verificar configuração do Prometheus Global
   - Verificar conectividade entre serviços
   - Verificar se os Prometheus Locais estão coletando métricas

3. **Ingress não funciona**
   - Verificar se o Ingress controller está rodando
   - Verificar cert-manager
   - Verificar DNS

## Monitoramento

### Métricas principais

- `prometheus_build_info`: Versão do Prometheus
- `prometheus_config_last_reload_success_timestamp_seconds`: Última recarga bem-sucedida
- `up`: Disponibilidade dos targets
- `scrape_duration_seconds`: Duração do scrape
- `scrape_samples_scraped`: Amostras coletadas

### Alertas

Os alertas estão configurados nos ConfigMaps de regras:

- **PrometheusDown**: Prometheus está down
- **PrometheusJobMissing**: Job está faltando
- **PrometheusTargetMissing**: Target está faltando
- **PrometheusScrapeError**: Erro no scrape
- **PrometheusHighMemory**: Alto uso de memória
- **PrometheusHighCPU**: Alto uso de CPU

## Performance

### Recomendações

- **Prometheus Global**: 2 réplicas, 2 CPU, 4GB RAM, 50GB disco
- **Prometheus Local**: 1 réplica, 1 CPU, 2GB RAM, 10GB disco
- **Retention**: 15 dias para Global, 7 dias para Local
- **Scrape interval**: 30s para Global, 15s para Local

### Otimização

- Usar recording rules para métricas agregadas
- Limitar o número de séries temporais
- Configurar retention adequada
- Usar SSD para storage

## Segurança

### Autenticação

- Autenticação básica via Ingress
- Secret com htpasswd
- TLS via cert-manager

### Network Policies

Recomenda-se criar Network Policies para restringir o acesso:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-network-policy
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  egress:
  - {}
```

## Manutenção

### Backup

```bash
# Backup do Prometheus Global
kubectl exec -n monitoring $(kubectl get pods -n monitoring -l app=prometheus,component=global -o jsonpath='{.items[0].metadata.name}') -- tar czf - /prometheus > prometheus-global-backup.tar.gz

# Backup do Prometheus Local 1
kubectl exec -n monitoring $(kubectl get pods -n monitoring -l app=prometheus,component=local-1 -o jsonpath='{.items[0].metadata.name}') -- tar czf - /prometheus > prometheus-local-1-backup.tar.gz
```

### Upgrade

```bash
# Atualizar imagens
kubectl set image deployment/prometheus-global prometheus=prom/prometheus:v2.45.0 -n monitoring
kubectl set image deployment/prometheus-local-1 prometheus=prom/prometheus:v2.45.0 -n monitoring
kubectl set image deployment/prometheus-local-2 prometheus=prom/prometheus:v2.45.0 -n monitoring

# Verificar rollout
kubectl rollout status deployment/prometheus-global -n monitoring
kubectl rollout status deployment/prometheus-local-1 -n monitoring
kubectl rollout status deployment/prometheus-local-2 -n monitoring
```

## Referências

- [Prometheus Federation](https://prometheus.io/docs/prometheus/latest/federation/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Kubernetes Monitoring](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)