# 🚀 **ArgoCD - GitOps Continuous Delivery**

## 📋 **Visão Geral**

Este diretório contém as configurações para deploy do ArgoCD no Kubernetes, fornecendo uma plataforma completa de GitOps para entrega contínua.

## 🚀 **Componentes Incluídos**

- **ArgoCD Server**: Interface web e API para gerenciamento
- **ArgoCD Application Controller**: Controlador de aplicações
- **ArgoCD Repo Server**: Servidor de repositórios Git
- **ArgoCD Redis**: Cache para performance
- **Certificados TLS**: Segurança com HTTPS
- **Ingress**: Acesso externo configurado

## 📦 **O que você terá após a instalação**

- ✅ **GitOps workflow** completo
- ✅ **Interface web** para gerenciamento de aplicações
- ✅ **Sincronização automática** com repositórios Git
- ✅ **Rollback** e versionamento de deployments
- ✅ **Multi-cluster** support
- ✅ **RBAC** e controle de acesso
- ✅ **Certificados TLS** automáticos

---

## 🛠️ **Instalação**

### **Pré-requisitos**
- Kubernetes cluster funcionando
- cert-manager instalado
- Ingress controller configurado

```bash
microk8s enable ingress
microk8s enable cert-manager
```

### **Passo a passo:**

1. **Aplicar as configurações:**
   ```bash
   # Aplicar namespace
   kubectl apply -f 00-namespace.yaml
   
   # Instalar ArgoCD (kustomize oficial)
   kubectl apply -f 01-install-kustomization.yaml
   
   # Aplicar configurações customizadas
   kubectl apply -f 10-argocd-cm-url.yaml
   kubectl apply -f 20-argocd-ingress.yaml
   kubectl apply -f 21-argocd-certificate.yaml
   ```

2. **Verificar a instalação:**
   ```bash
   kubectl get pods -n argocd
   kubectl get svc -n argocd
   kubectl get ingress -n argocd
   ```

3. **Verificar certificados:**
   ```bash
   kubectl get certificates -n argocd
   ```

4. **Obter senha inicial (usuário: admin):**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
   ```

**⚠️ Importante:** No primeiro login, altere a senha padrão do usuário `admin`.

---

## 🌐 **Acesso Web**

### **Configurar arquivo hosts**

Adicione esta linha ao arquivo hosts do Windows (`C:\Windows\System32\drivers\etc\hosts`):

```
192.168.1.100  argocd.home.arpa
```

### **URLs de Acesso**

**ArgoCD Web UI:**
- URL: `https://argocd.home.arpa`
- 🔐 **Login**: admin / [senha obtida no passo 4]
- 🎛️ **Funcionalidades**: Gerenciamento de aplicações, repositórios, clusters

### **Acesso via CLI**

**Via Ingress:**
```bash
argocd login argocd.home.arpa --username admin --password <sua-senha> --grpc-web --insecure
```

**Via Port-Forward:**
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
argocd login localhost:8080 --username admin --password <senha> --insecure
```

---

## 🎯 **Primeiros Passos no ArgoCD**

### **1. Conectar Repositório Git**
1. Acesse "Settings" → "Repositories"
2. Clique em "Connect Repo"
3. Configure URL do repositório e credenciais
4. Teste a conexão

### **2. Criar Primeira Aplicação**
1. Clique em "+ New App"
2. Configure:
   - **Application Name**: nome da aplicação
   - **Project**: default
   - **Repository URL**: seu repositório Git
   - **Path**: caminho dos manifestos YAML
   - **Destination**: cluster e namespace
3. Clique em "Create"

### **3. Sincronizar Aplicação**
1. Selecione a aplicação criada
2. Clique em "Sync"
3. Revise as mudanças
4. Confirme a sincronização

---

## 📁 **Arquivos Principais**

| Arquivo | Descrição | Quando usar |
|---------|-----------|-------------|
| `00-namespace.yaml` | Namespace do ArgoCD | Sempre primeiro |
| `01-install-kustomization.yaml` | Instalação oficial do ArgoCD | Base do sistema |
| `10-argocd-cm-url.yaml` | ConfigMap com URL externa | Para links corretos |
| `20-argocd-ingress.yaml` | Ingress para acesso web | Para HTTPS externo |
| `21-argocd-certificate.yaml` | Certificado TLS | Para segurança |

---

## 🔧 **Configuração Avançada**

### **RBAC e Usuários**

Para criar usuários adicionais, edite o ConfigMap `argocd-cm`:

```yaml
data:
  accounts.developer: apiKey, login
  accounts.developer.enabled: "true"
```

### **Políticas de Acesso**

Configure políticas no ConfigMap `argocd-rbac-cm`:

```yaml
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:developer, applications, *, */*, allow
    g, developer, role:developer
```

---

## 🗑️ **Remoção**

### **Remover completamente:**
```bash
kubectl delete -k .
kubectl delete -f .
```

### **Remover configuração de hosts:**
Remova esta linha do arquivo hosts:
- `argocd.home.arpa`

---

## ❓ **Perguntas Frequentes (FAQ)**

### **Q: O que é ArgoCD?**
**A:** ArgoCD é uma ferramenta de entrega contínua declarativa para Kubernetes que segue o padrão GitOps, sincronizando automaticamente o estado do cluster com repositórios Git.

### **Q: Como funciona o GitOps?**
**A:** O GitOps usa Git como fonte única da verdade. Mudanças no repositório são automaticamente aplicadas no cluster, garantindo consistência e rastreabilidade.

### **Q: Posso gerenciar múltiplos clusters?**
**A:** Sim! ArgoCD suporta múltiplos clusters. Configure clusters adicionais em "Settings" → "Clusters".

### **Q: Como fazer rollback?**
**A:** Na interface da aplicação, clique em "History and Rollback", selecione a versão desejada e clique em "Rollback".

### **Q: Suporta Helm Charts?**
**A:** Sim! ArgoCD suporta Helm Charts, Kustomize, Jsonnet e manifestos YAML simples.

---

## 🚀 **Próximos Passos**

### **Para Iniciantes:**
- Explore a interface web
- Conecte seu primeiro repositório
- Crie uma aplicação simples
- Pratique sync e rollback

### **Para Desenvolvedores:**
- Configure webhooks para sync automático
- Use Helm Charts e Kustomize
- Implemente estratégias de deployment
- Configure health checks customizados

### **Para Administradores:**
- Configure RBAC e usuários
- Implemente políticas de segurança
- Configure múltiplos clusters
- Monitore métricas e logs

---

## 🤝 **Suporte e Contribuições**

- 📖 **Documentação**: [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- 🐛 **Issues**: Reporte problemas no repositório
- 💡 **Sugestões**: Contribua com melhorias

---

## 📊 **Informações Técnicas**

### 🏗️ **Arquitetura:**
- **ArgoCD Server**: API e interface web
- **Application Controller**: Monitora aplicações e sincroniza estado
- **Repo Server**: Gerencia repositórios Git
- **Redis**: Cache para performance
- **Dex**: Autenticação SSO (opcional)
- **Armazenamento**: Volumes persistentes para dados
- **Segurança**: Certificados TLS via cert-manager
- **Rede**: Ingress para acesso web externo

### ⚙️ **Configurações padrão:**
- **Protocolo**: HTTPS com certificados automáticos
- **Sync**: Manual (pode ser configurado como automático)
- **Retenção**: Histórico de deployments configurável
- **Health Check**: Verificação automática de saúde das aplicações
- **Pruning**: Remoção automática de recursos órfãos (opcional)

### 📝 **Notas Técnicas:**
- O Ingress aponta para `svc/argocd-server porta 80` (HTTP interno)
- TLS termination no Ingress com certificado local-ca
- ConfigMap `argocd-cm` define URL externa para links corretos
- Para alterar hostname: edite `10-argocd-cm-url.yaml`, `20-argocd-ingress.yaml` e `21-argocd-certificate.yaml`
