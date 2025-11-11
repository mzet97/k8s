# ArgoCD ApplicationSets

Este documento descreve a configuração do ArgoCD com ApplicationSets para gerenciamento declarativo de aplicações.

## Arquitetura

Os ApplicationSets permitem gerenciar múltiplas aplicações ArgoCD de forma dinâmica usando geradores baseados em:

- Diretórios no Git
- Arquivos no Git
- Listas de clusters
- Pull requests

## Componentes

### 1. Projetos

Os projetos organizam as aplicações por domínio:

- **infrastructure**: Infraestrutura base (ingress, storage)
- **monitoring**: Monitoramento e observabilidade
- **data**: Aplicações de dados (Redis, bancos)
- **backup**: Backup e recuperação

### 2. ApplicationSets

#### infrastructure-apps

Gera aplicações para cada subdiretório em `infrastructure/*`:

```yaml
- infrastructure/backup
- infrastructure/monitoring
- infrastructure/ingress
- infrastructure/storage
```

#### monitoring-apps

Gera aplicações específicas para monitoramento:

```yaml
- infrastructure/monitoring/prometheus-federation
- infrastructure/monitoring/grafana
- infrastructure/monitoring/alertmanager
```

#### data-apps

Gerencia aplicações de dados:

```yaml
- applications/redis-ha
```

#### backup-apps

Gerencia soluções de backup:

```yaml
- infrastructure/backup/velero
```

## Instalação

### Pré-requisitos

- Kubernetes cluster rodando
- ArgoCD instalado
- kubectl ou microk8s configurado
- Repositório Git com as configurações

### Instalação Rápida

```bash
# Configurar ArgoCD e ApplicationSets
./scripts/setup-argocd-appsets.sh
```

### Instalação Manual

```bash
# Criar projetos
kubectl apply -f argocd/projects.yaml

# Criar ApplicationSets
kubectl apply -f argocd/applicationsets.yaml
```

## Configuração

### Repositório Git

Configure o repositório no ApplicationSet:

```yaml
repoURL: https://github.com/seu-usuario/k8s-cluster-config
revision: HEAD
```

### Sincronização

Configuração de sincronização automática:

```yaml
syncPolicy:
  automated:
    prune: true        # Remove recursos deletados
    selfHeal: true     # Auto-correção de divergências
    allowEmpty: false  # Não permite aplicações vazias
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
```

### Retry

Configuração de retry em caso de falha:

```yaml
retry:
  limit: 5
  backoff:
    duration: 5s
    factor: 2
    maxDuration: 3m
```

## Uso

### Visualizar ApplicationSets

```bash
# Listar ApplicationSets
kubectl get applicationsets -n argocd

# Descrever um ApplicationSet
kubectl describe applicationset infrastructure-apps -n argocd
```

### Visualizar Aplicações

```bash
# Listar todas as aplicações
kubectl get applications -n argocd

# Filtrar por projeto
kubectl get applications -n argocd -l app.kubernetes.io/instance=<project-name>
```

### Sincronização Manual

```bash
# Sincronizar uma aplicação
argocd app sync <app-name>

# Sincronizar todos os apps de um projeto
argocd app list -p <project-name> -o name | xargs argocd app sync
```

### Logs e Eventos

```bash
# Logs do ApplicationSet controller
kubectl logs -n argocd deployment/argocd-applicationset-controller

# Eventos de uma aplicação
kubectl get events -n argocd --field-selector involvedObject.name=<app-name>
```

## Estrutura de Diretórios

```
k8s/
├── applications/
│   └── redis-ha/
│       ├── kustomization.yaml
│       ├── redis-config.yaml
│       └── redis-deployment.yaml
├── infrastructure/
│   ├── backup/
│   │   └── velero/
│   │       ├── kustomization.yaml
│   │       ├── velero-config.yaml
│   │       └── velero-deployment.yaml
│   └── monitoring/
│       └── prometheus/
│           ├── kustomization.yaml
│           ├── prometheus-config.yaml
│           └── prometheus-deployment.yaml
└── argocd/
    ├── projects.yaml
    └── applicationsets.yaml
```

## Templates

### Template de ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: <name>
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: <repo-url>
      revision: <revision>
      directories:
      - path: <path-pattern>
  template:
    metadata:
      name: '{{path.basename}}'
      namespace: argocd
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      project: <project-name>
      source:
        repoURL: <repo-url>
        targetRevision: <revision>
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### Template de Projeto

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: <project-name>
  namespace: argocd
spec:
  description: <description>
  sourceRepos:
  - '*'
  destinations:
  - namespace: '<namespace-pattern>'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
```

## Troubleshooting

### ApplicationSet não gera aplicações

1. Verificar logs do controller:
   ```bash
   kubectl logs -n argocd deployment/argocd-applicationset-controller
   ```

2. Verificar sintaxe do ApplicationSet:
   ```bash
   kubectl apply -f applicationsets.yaml --dry-run=client
   ```

3. Verificar permissões:
   ```bash
   kubectl auth can-i create applications -n argocd --as=system:serviceaccount:argocd:argocd-applicationset-controller
   ```

### Aplicações não sincronizam

1. Verificar erros na aplicação:
   ```bash
   argocd app get <app-name>
   argocd app diff <app-name>
   ```

2. Verificar conectividade com repositório:
   ```bash
   argocd repo list
   ```

3. Verificar logs do controller:
   ```bash
   kubectl logs -n argocd deployment/argocd-application-controller
   ```

### Permissões insuficientes

1. Verificar RBAC:
   ```bash
   kubectl get clusterrolebinding | grep argocd
   kubectl get rolebinding -n argocd
   ```

2. Adicionar permissões necessárias:
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata:
     name: argocd-applicationset-controller
   rules:
   - apiGroups: ["argoproj.io"]
     resources: ["applications", "appprojects"]
     verbs: ["*"]
   ```

## Segurança

### RBAC

O ArgoCD precisa de permissões para criar e gerenciar aplicações:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-applicationset-controller
rules:
- apiGroups: ["argoproj.io"]
  resources: ["applications", "appprojects"]
  verbs: ["get", "list", "create", "update", "delete", "patch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "get", "list", "watch", "patch"]
```

### Network Policies

Recomenda-se criar Network Policies para restringir o acesso:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/part-of: argocd
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 8088
    - protocol: TCP
      port: 9001
    - protocol: TCP
      port: 9002
  egress:
  - {}
```

## Melhores Práticas

### 1. Organização de Projetos

- Use projetos para separar por ambiente (dev, staging, prod)
- Use projetos para separar por time ou domínio
- Configure permissões granulares por projeto

### 2. GitOps

- Mantenha todas as configurações no Git
- Use branches para diferentes ambientes
- Configure webhooks para sincronização automática

### 3. Segurança

- Use RBAC para controlar acesso
- Configure secrets para credenciais sensíveis
- Use network policies para isolamento

### 4. Monitoramento

- Monitore o ArgoCD com Prometheus
- Configure alertas para falhas de sincronização
- Use logs centralizados

### 5. Backup

- Faça backup do banco de dados do ArgoCD
- Mantenha as configurações no Git
- Teste procedimentos de recuperação

## Monitoramento

### Métricas do ArgoCD

- `argocd_app_sync_total`: Total de sincronizações
- `argocd_app_sync_failed_total`: Sincronizações falhadas
- `argocd_app_health_status`: Status de saúde das aplicações
- `argocd_app_sync_status`: Status de sincronização

### Dashboards

Use o Grafana com os dashboards do ArgoCD:

- ArgoCD Overview
- ArgoCD Applications
- ArgoCD Sync Performance

## Referências

- [ArgoCD ApplicationSets](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [ArgoCD Projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best-practices/)
- [GitOps Principles](https://www.weave.works/technologies/gitops/)