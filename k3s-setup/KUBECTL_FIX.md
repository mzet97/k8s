# Correção do kubectl para K3s

## Problema Identificado

O `kubectl` estava redirecionando para o `microk8s kubectl` devido a aliases configurados no `.bashrc`.

```bash
# Aliases antigos no .bashrc (linhas 119-120)
alias kubectl="microk8s kubectl"
alias k="microk8s kubectl"
```

Isso causava o erro:
```
Command 'microk8s' not found, but can be installed with:
sudo snap install microk8s
```

## Solução Aplicada

### 1. Aliases Comentados
Os aliases do MicroK8s foram comentados no arquivo `/home/k8s1/.bashrc`:

```bash
# MicroK8s aliases (commented out - now using K3s)
# alias kubectl="microk8s kubectl"
# alias k="microk8s kubectl"
```

### 2. Kubeconfig do K3s
O kubeconfig do K3s já estava corretamente configurado em:
- **Origem**: `/etc/rancher/k3s/k3s.yaml`
- **Destino**: `/home/k8s1/.kube/config`

## Como Aplicar a Correção

**IMPORTANTE**: Você precisa recarregar o shell para aplicar as mudanças:

### Opção 1: Recarregar o .bashrc (Recomendado)
```bash
source ~/.bashrc
```

### Opção 2: Abrir um novo terminal
Feche e abra um novo terminal.

### Opção 3: Nova sessão de login
```bash
exec bash -l
```

## Verificação

Após recarregar o shell, teste:

```bash
# Verificar versão do kubectl
kubectl version --client

# Listar nodes
kubectl get nodes

# Listar todos os pods
kubectl get pods -A

# Verificar Traefik
kubectl get pods -n kube-system | grep traefik
```

## Status do Cluster K3s

### Cluster Info
```
NAME   STATUS   ROLES                  AGE   VERSION
k8s1   Ready    control-plane,master   13m   v1.33.6+k3s1
```

### Pods do Sistema
```
NAMESPACE     NAME                                      READY   STATUS
kube-system   coredns-6d668d687-z7dkn                   1/1     Running
kube-system   local-path-provisioner-869c44bfbd-g5n8m   1/1     Running
kube-system   metrics-server-7bfffcd44-9f4jx            1/1     Running
kube-system   traefik-865bd56545-lj9hb                  1/1     Running
kube-system   svclb-traefik-a2e68ba7-mw4r9              2/2     Running
```

### Traefik LoadBalancer
```
NAME      TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)
traefik   LoadBalancer   10.43.100.89   192.168.1.51   80:31488/TCP,443:32558/TCP
```

O Traefik está acessível em:
- **HTTP**: `http://192.168.1.51:80` ou `http://192.168.1.51:31488`
- **HTTPS**: `https://192.168.1.51:443` ou `https://192.168.1.51:32558`

## Restaurando MicroK8s (Se Necessário)

Se você precisar voltar para o MicroK8s no futuro, basta descomentar os aliases no `.bashrc`:

```bash
# Editar ~/.bashrc e descomentar:
alias kubectl="microk8s kubectl"
alias k="microk8s kubectl"

# Recarregar
source ~/.bashrc
```

## Comandos Úteis

### K3s
```bash
# Status do serviço
sudo systemctl status k3s

# Logs do K3s
sudo journalctl -u k3s -f

# Reiniciar K3s
sudo systemctl restart k3s
```

### kubectl
```bash
# Contexto atual
kubectl config current-context

# Ver configuração
kubectl config view

# Namespaces
kubectl get namespaces

# Recursos por namespace
kubectl get all -n kube-system
```

### Traefik
```bash
# Pods do Traefik
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Logs do Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f

# Serviço do Traefik
kubectl get svc -n kube-system traefik

# IngressRoutes (CRDs do Traefik)
kubectl get ingressroute -A
```

## Troubleshooting

### Ainda aparece erro do microk8s
Se após recarregar o shell ainda aparecer o erro, verifique:

1. **Confirme que os aliases foram comentados:**
   ```bash
   grep "kubectl" ~/.bashrc
   ```
   Deve mostrar as linhas comentadas com `#`

2. **Verifique outros arquivos de configuração:**
   ```bash
   grep "kubectl" ~/.bash_aliases ~/.zshrc ~/.profile 2>/dev/null
   ```

3. **Use o caminho completo temporariamente:**
   ```bash
   /usr/local/bin/kubectl get nodes
   ```

### kubectl não encontrado
Se aparecer "kubectl: command not found":

```bash
# Verificar se kubectl existe
which kubectl
ls -la /usr/local/bin/kubectl

# Adicionar ao PATH (se necessário)
export PATH="/usr/local/bin:$PATH"
```

### Permissão negada ao acessar cluster
Se aparecer erro de permissão:

```bash
# Verificar permissões do kubeconfig
ls -la ~/.kube/config

# Reconfigurar (se necessário)
cd ~/k8s/k3s-setup
sudo ./configure-k3s.sh
```

## Próximos Passos

Agora que o kubectl está funcionando com K3s, você pode:

1. **Explorar o cluster:**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   kubectl get svc -A
   ```

2. **Acessar o Traefik Dashboard** (veja TRAEFIK_GUIDE.md)

3. **Instalar Cert-Manager:**
   ```bash
   cd ~/k8s/certs
   kubectl apply -f .
   ```

4. **Deploy suas aplicações:**
   - MinIO: `cd ~/k8s/minio`
   - Redis: `cd ~/k8s/redis`
   - RabbitMQ: `cd ~/k8s/rabbitmq`
   - Monitoring: `cd ~/k8s/monitoring`
   - ArgoCD: `cd ~/k8s/argocd`

5. **Consultar os guias:**
   - `TRAEFIK_GUIDE.md` - Como usar Traefik
   - `examples/` - Exemplos de configuração
   - `README.md` - Documentação geral
