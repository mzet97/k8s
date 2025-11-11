# MicroK8s Setup - Configuração Completa

Este diretório contém scripts para instalação e configuração completa do MicroK8s em uma máquina única.

## 📋 Pré-requisitos

- Sistema Ubuntu/Debian
- Usuário com privilégios sudo
- Conexão com internet
- Pelo menos 4GB de RAM
- Pelo menos 20GB de espaço em disco

## 🚀 Scripts Disponíveis

### 1. `install-microk8s.sh`
Instala o MicroK8s e configura o ambiente básico.

**O que faz:**
- Atualiza o sistema
- Instala dependências necessárias
- Instala o MicroK8s via snap
- Adiciona o usuário ao grupo microk8s
- Configura alias para kubectl
- Verifica se a instalação está funcionando

### 2. `configure-addons.sh`
Configura os addons essenciais do MicroK8s.

**O que faz:**
- Habilita DNS
- Habilita Hostpath Storage
- Habilita Ingress
- Habilita Helm
- Habilita Cert-Manager
- Configura ClusterIssuer para certificados Let's Encrypt
- Verifica se todos os addons estão funcionando

### 3. `check-environment.sh`
Script de verificação completa do ambiente MicroK8s.

**O que faz:**
- Verifica se MicroK8s está instalado e rodando
- Verifica status de todos os addons
- Testa conectividade DNS
- Verifica pods do sistema
- Analisa recursos do sistema
- Fornece diagnóstico detalhado de problemas

### 4. `reset-environment.sh`
Script para reset completo do ambiente MicroK8s.

**O que faz:**
- Para o MicroK8s
- Desabilita todos os addons
- Limpa dados persistentes
- Reinicia o ambiente
- Reconfigura addons essenciais
- Recria ClusterIssuers

### 5. `setup-complete.sh`
Script de instalação completa automatizada.

**O que faz:**
- Executa todos os scripts em sequência
- Verifica pré-requisitos
- Monitora o progresso da instalação
- Fornece relatório final detalhado
- Inclui verificações de integridade

### 6. `uninstall-microk8s.sh`
Script de remoção completa do MicroK8s.

**O que faz:**
- Remove completamente a instalação do MicroK8s
- Limpa todos os dados persistentes e configurações
- Para todos os serviços relacionados
- Remove interfaces de rede e regras de iptables
- Limpa processos e montagens residuais
- Fornece verificação final do sistema
- Inclui confirmação de segurança antes da remoção

## 📝 Instruções de Uso

### Instalação Automatizada (Recomendado)

```bash
# 1. Clone o repositório ou baixe os scripts
cd /caminho/para/microk8s-setup

# 2. Torne os scripts executáveis
chmod +x make-executable.sh
./make-executable.sh

# 3. Execute a instalação completa automatizada
./setup-complete.sh
```

### Instalação Manual (Passo a Passo)

```bash
# 1. Clone o repositório ou baixe os scripts
cd /caminho/para/microk8s-setup

# 2. Torne os scripts executáveis
chmod +x *.sh

# 3. Execute a instalação do MicroK8s
./install-microk8s.sh

# 4. Faça logout e login novamente (ou execute):
newgrp microk8s

# 5. Configure os addons
./configure-addons.sh

# 6. Verifique a instalação
./check-environment.sh
```

### Verificação da Instalação

```bash
# Verificação completa automatizada (recomendado)
./check-environment.sh

# Verificações manuais (opcional)
microk8s status
kubectl get nodes
microk8s status --addon
kubectl get pods -A
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

### Scripts de Manutenção

```bash
# Verificação completa do ambiente
./check-environment.sh

# Reset completo do ambiente (em caso de problemas)
./reset-environment.sh
```

## 🗑️ Remoção Completa

Para remover completamente o MicroK8s do sistema:

```bash
./uninstall-microk8s.sh
```

**⚠️ ATENÇÃO:** Este script remove TUDO relacionado ao MicroK8s:
- Todos os pods, serviços e volumes
- Configurações e certificados
- Dados persistentes
- Interfaces de rede
- Regras de iptables

**Recomendações:**
- Faça backup de dados importantes antes da remoção
- Reinicie o sistema após a remoção para limpeza completa
- Aguarde pelo menos 2 minutos antes de reinstalar

## 🔧 Configurações Importantes

### DNS
- O addon DNS é essencial para resolução de nomes dentro do cluster
- Permite que os pods se comuniquem usando nomes de serviço

### Hostpath Storage
- Fornece armazenamento persistente usando o sistema de arquivos local
- Ideal para ambientes de desenvolvimento e teste
- **Nota:** Em produção, considere usar soluções de armazenamento mais robustas

### Ingress
- Permite acesso externo aos serviços do cluster
- Suporta roteamento baseado em host e path
- Integrado com cert-manager para certificados TLS automáticos

### Helm
- Gerenciador de pacotes para Kubernetes
- Facilita a instalação e gerenciamento de aplicações

### Cert-Manager
- Gerencia certificados TLS automaticamente
- Integrado com Let's Encrypt para certificados gratuitos
- Configurado com ClusterIssuer para produção e staging

## 🌐 Acesso aos Serviços

### Configuração de DNS Local (Opcional)

Para acessar serviços via nomes de domínio localmente, adicione ao `/etc/hosts`:

```bash
# Exemplo para serviços locais
127.0.0.1 app.local
127.0.0.1 api.local
127.0.0.1 grafana.local
```

### Portas Padrão

- **HTTP:** 80 (Ingress)
- **HTTPS:** 443 (Ingress com TLS)
- **NodePort:** 30000-32767 (para serviços NodePort)

## 🔍 Troubleshooting

### Problemas Comuns

1. **MicroK8s não inicia:**
   ```bash
   sudo snap restart microk8s
   microk8s inspect
   ```

2. **Addons não funcionam:**
   ```bash
   microk8s disable <addon>
   microk8s enable <addon>
   ```

3. **Problemas de DNS:**
   ```bash
   microk8s disable dns
   microk8s enable dns
   ```

4. **Cert-manager não funciona:**
   ```bash
   kubectl logs -n cert-manager deployment/cert-manager
   kubectl describe clusterissuer letsencrypt-prod
   ```

### Logs Úteis

```bash
# Logs do MicroK8s
sudo journalctl -u snap.microk8s.daemon-kubelite

# Logs de um pod específico
kubectl logs -n <namespace> <pod-name>

# Logs do Ingress
kubectl logs -n ingress daemonset/nginx-ingress-microk8s-controller
```

## 🔄 Manutenção

### Atualização do MicroK8s

## 🌐 Troubleshooting de Rede (CNI/Ingress)

### Sintomas frequentes
- Pods não conseguem resolver `kubernetes.default.svc.cluster.local`
- Serviços `ClusterIP` não acessíveis entre pods
- `Ingress` responde 404/timeout mesmo com serviço saudável
- `NodePort` inacessível de fora do nó

### Causas prováveis
- `sysctl` não habilitado para `bridge-nf-call-iptables` e `ip_forward`
- `iptables` em modo `nft` com regras não compatíveis com kube-proxy
- `UFW` ativo bloqueando `FORWARD` ou portas essenciais
- CNI (Calico/Flannel/Cilium) não inicializado corretamente

### Verificações rápidas
```bash
# Verificar sysctl
sudo sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# Verificar backend do iptables
sudo iptables -V

# Verificar UFW
sudo ufw status
grep DEFAULT_FORWARD_POLICY /etc/default/ufw

# Verificar CNI
ip link show cni0 || echo "cni0 ausente"
kubectl -n kube-system get ds kube-proxy || true
kubectl -n kube-system get pods -l k8s-app=calico-node || true
kubectl -n kube-system get ds kube-flannel-ds || true
kubectl -n kube-system get pods -l k8s-app=cilium || true
```

### Correções recomendadas
```bash
# 1) Ajustar sysctl
echo -e "net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-kubernetes-network.conf
sudo sysctl --system

# 2) Ajustar iptables para legacy (se nft causar problemas)
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy

# 3) Ajustar UFW (se ativo)
sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo ufw allow 6443/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 30000:32767/tcp
sudo ufw allow 30000:32767/udp
sudo ufw reload

# 4) Reiniciar componentes
sudo snap restart microk8s
kubectl -n kube-system rollout restart ds/kube-proxy || true
```

### Testes de saúde
```bash
# DNS interno
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local

# Acesso Service via ClusterIP a partir de outro pod
kubectl run curl --image=radial/busyboxplus:curl -it --rm --restart=Never -- curl -sS http://<service_cluster_ip>:<port>

# Ingress
kubectl -n ingress logs -l app.kubernetes.io/component=controller --tail=100
kubectl get ingress -A
```

### Observações
- Em ambientes modernos, `iptables-nft` costuma funcionar, mas problemas de compatibilidade podem ocorrer. Use `legacy` se notar falhas de roteamento.
- Se usar `UFW`, garanta que o `FORWARD` esteja `ACCEPT` ou considere desabilitar temporariamente para diagnóstico.
- Após uma remoção completa (`uninstall-microk8s.sh`), reinicie o host antes de reinstalar para limpar interfaces residuais.

```bash
# Atualizar para a versão mais recente
sudo snap refresh microk8s

# Atualizar para uma versão específica
sudo snap refresh microk8s --channel=1.28/stable
```

### Backup da Configuração

```bash
# Backup da configuração do kubectl
cp ~/.kube/config ~/.kube/config.backup

# Backup dos recursos do cluster (opcional)
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
```

### Limpeza

```bash
# Remover pods em estado de erro
kubectl delete pods --field-selector=status.phase=Failed -A

# Limpar imagens não utilizadas
microk8s ctr images prune
```

## 📚 Próximos Passos

Após a instalação e configuração:

1. **Deploy de aplicações:** Use os manifestos YAML nos outros diretórios
2. **Monitoramento:** Configure Prometheus e Grafana
3. **Backup:** Implemente estratégias de backup para dados importantes
4. **Segurança:** Configure RBAC e políticas de rede
5. **CI/CD:** Integre com ArgoCD ou outras ferramentas de CI/CD

## 🆘 Suporte

Para mais informações:
- [Documentação oficial do MicroK8s](https://microk8s.io/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)