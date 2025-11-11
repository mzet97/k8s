# Kubernetes Cluster Configuration

Este repositório contém a configuração completa para um cluster Kubernetes de alta disponibilidade com monitoramento, backup, e gerenciamento declarativo de aplicações.

## 🏗️ Arquitetura

O cluster é configurado com os seguintes componentes:

- **Backup**: Velero para backup e recuperação de desastres
- **Cache**: Redis High Availability com Sentinel e Cluster
- **Monitoramento**: Prometheus Federation para alta disponibilidade
- **GitOps**: ArgoCD com ApplicationSets para gerenciamento declarativo

## 📋 Pré-requisitos

- Kubernetes cluster (1.20+)
- kubectl ou microk8s configurado
- Storage class disponível
- Ingress controller (nginx ou similar)
- cert-manager para TLS

### ArgoCD ApplicationSets

- **Projetos**: Organização por domínios (infrastructure, monitoring, data, backup)
- **ApplicationSets**: Gerenciamento dinâmico de aplicações
- **GitOps**: Sincronização automática com repositório Git
- **Multi-ambiente**: Suporte para múltiplos ambientes
- **Auto-sync**: Sincronização e auto-cura automáticas

## 🚀 Instalação Rápida

### 1. Configurar Cluster Kubernetes

```bash
# Verificar se o cluster está rodando
kubectl get nodes

# Criar namespaces necessários
kubectl create namespace monitoring
kubectl create namespace velero
kubectl create namespace redis
kubectl create namespace argocd
```

### 2. Instalar ArgoCD com ApplicationSets

```bash
# Configurar ArgoCD e ApplicationSets
./scripts/setup-argocd-appsets.sh

# Acessar ArgoCD
# URL: https://<external-ip>
# Usuário: admin
# Senha: obtida via script
```

### 3. Instalar Prometheus Federation

```bash
# Configurar federation
./scripts/setup-prometheus-federation.sh setup

# Verificar status
./scripts/setup-prometheus-federation.sh status

# Testar federation
./scripts/setup-prometheus-federation.sh test
```

### 4. Instalar Redis HA

```bash
# Configurar Redis Sentinel
./scripts/setup-redis-ha.sh setup-sentinel

# Configurar Redis Cluster
./scripts/setup-redis-ha.sh setup-cluster

# Testar conectividade
./scripts/setup-redis-ha.sh test
```

### 5. Instalar Velero

```bash
# Configurar backup
./scripts/setup-backup.sh setup

# Verificar status
./scripts/setup-backup.sh status

# Executar backup de teste
./scripts/setup-backup.sh test
```

## 📁 Estrutura do Projeto

```
k8s/
├── applications/           # Aplicações do cluster
│   └── redis-ha/          # Configuração Redis HA
├── infrastructure/         # Infraestrutura base
│   ├── backup/            # Configuração Velero
│   │   └── velero/
│   │       ├── velero-config.yaml
│   │       └── velero-deployment.yaml
│   └── monitoring/        # Configuração Prometheus
│       └── prometheus/
│           ├── prometheus-config.yaml
│           └── prometheus-deployment.yaml
├── argocd/               # Configuração ArgoCD
│   ├── applicationsets.yaml
│   ├── projects.yaml
│   └── setup-argocd-appsets.sh
├── scripts/               # Scripts de automação
│   ├── setup-backup.sh
│   ├── setup-redis-ha.sh
│   ├── setup-prometheus-federation.sh
│   └── setup-argocd-appsets.sh
├── docs/                  # Documentação
│   ├── backup.md
│   ├── redis-ha.md
│   ├── prometheus-federation.md
│   └── argocd-appsets.md
├── tests/                 # Testes e validações
│   └── validate-cluster.sh
└── tests/
    └── validate-cluster.sh
```

## 📊 Monitoramento

### Prometheus Federation

- **Global**: http://prometheus-global.seu-dominio.com
- **Local 1**: http://prometheus-local-1.seu-dominio.com
- **Local 2**: http://prometheus-local-2.seu-dominio.com

### Métricas Principais

- Disponibilidade do cluster: `up`
- Uso de CPU: `node_cpu_seconds_total`
- Uso de memória: `node_memory_MemAvailable_bytes`
- Uso de disco: `node_filesystem_avail_bytes`
- Métricas federadas: `job:*`

## 🔒 Segurança

### Autenticação

- **Prometheus**: Autenticação básica (admin/prom-operator)
- **ArgoCD**: Autenticação via secret inicial
- **Redis**: Autenticação desabilitada por padrão (configurar conforme necessário)

### Network Policies

Recomenda-se criar Network Policies para restringir o acesso entre componentes.

## 🧪 Testes

### Validação do Cluster

```bash
# Executar testes completos
./tests/validate-cluster.sh

# Testar componentes individualmente
./scripts/setup-backup.sh test
./scripts/setup-redis-ha.sh test
./scripts/setup-prometheus-federation.sh test
```

### Testes de Disponibilidade

- Failover do Redis Sentinel
- Failover do Redis Cluster
- Federation do Prometheus
- Backup e restore com Velero

## 🔧 Manutenção

### Backup Manual

```bash
# Backup do cluster
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S)

# Listar backups
velero backup get

# Restaurar backup
velero restore create --from-backup <backup-name>
```

### Upgrade de Componentes

```bash
# Atualizar imagens
kubectl set image deployment/prometheus-global prometheus=prom/prometheus:v2.45.0 -n monitoring

# Verificar rollout
kubectl rollout status deployment/prometheus-global -n monitoring
```

## 🚨 Troubleshooting

### Problemas Comuns

1. **Pods não iniciam**
   ```bash
   kubectl describe pod <nome-do-pod>
   kubectl logs <nome-do-pod>
   ```

2. **Federation não funciona**
   ```bash
   ./scripts/setup-prometheus-federation.sh diagnosis
   ```

3. **Redis HA falha**
   ```bash
   ./scripts/setup-redis-ha.sh check-status
   ```

4. **ArgoCD não sincroniza**
   ```bash
   kubectl get applications -n argocd
   kubectl describe application <nome> -n argocd
   ```

### Logs e Diagnóstico

Cada script possui opções de diagnóstico:

```bash
# Diagnóstico detalhado Prometheus
./scripts/setup-prometheus-federation.sh diagnosis

# Status detalhado Redis
./scripts/setup-redis-ha.sh check-status

# Logs do Velero
kubectl logs -n velero deployment/velero
```

## 📚 Documentação

- [Backup com Velero](docs/backup.md)
- [Redis High Availability](docs/redis-ha.md)
- [Prometheus Federation](docs/prometheus-federation.md)
- [ArgoCD ApplicationSets](docs/argocd-appsets.md)

## 🤝 Contribuição

1. Faça fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Crie um Pull Request

## 📝 Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo LICENSE para detalhes.

## 🆘 Suporte

Para suporte e dúvidas:

1. Verifique a documentação em `docs/`
2. Execute os testes de validação
3. Verifique os logs dos componentes
4. Abra uma issue no repositório

## 🔮 Roadmap

- [ ] Adicionar Grafana para visualização
- [ ] Implementar Alertmanager
- [ ] Adicionar ElasticSearch para logs
- [ ] Implementar Istio Service Mesh
- [ ] Adicionar testes automatizados CI/CD