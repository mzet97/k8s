# 🔧 Troubleshooting - Coder on MicroK8s

Este documento contém soluções para problemas comuns encontrados durante a instalação e operação do Coder no MicroK8s.

## 📋 Índice

- [Problemas de Instalação](#-problemas-de-instalação)
- [Problemas de Rede](#-problemas-de-rede)
- [Problemas de Certificados](#-problemas-de-certificados)
- [Problemas de Performance](#-problemas-de-performance)
- [Problemas de Armazenamento](#-problemas-de-armazenamento)
- [Comandos de Diagnóstico](#-comandos-de-diagnóstico)
- [Logs Importantes](#-logs-importantes)
- [Recuperação de Desastres](#-recuperação-de-desastres)

## 🚨 Problemas de Instalação

### MicroK8s não inicia

**Sintomas:**
- `microk8s status` mostra "not ready"
- Comandos kubectl falham

**Soluções:**

1. **Reiniciar MicroK8s:**
   ```bash
   microk8s stop
   microk8s start
   microk8s status --wait-ready
   ```

2. **Verificar logs do sistema:**
   ```bash
   journalctl -u snap.microk8s.daemon-kubelite
   ```

3. **Resetar MicroK8s (último recurso):**
   ```bash
   microk8s reset
   microk8s start
   # Reabilitar addons necessários
   microk8s enable dns ingress cert-manager helm3
   ```

### Addons não habilitam

**Sintomas:**
- `microk8s enable <addon>` falha
- Addons aparecem como "disabled"

**Soluções:**

1. **Verificar espaço em disco:**
   ```bash
   df -h
   ```

2. **Limpar imagens não utilizadas:**
   ```bash
   microk8s ctr images ls
   microk8s ctr images rm <image-name>
   ```

3. **Verificar conectividade de rede:**
   ```bash
   ping 8.8.8.8
   ```

### Script 00-prereqs.sh falha

**Sintomas:**
- Erro ao aplicar manifests
- Namespace não é criado

**Soluções:**

1. **Verificar permissões:**
   ```bash
   chmod +x 00-prereqs.sh
   ```

2. **Executar manualmente cada comando:**
   ```bash
   microk8s kubectl create namespace coder
   microk8s kubectl apply -f secrets/
   microk8s kubectl apply -f cert-manager/
   microk8s kubectl apply -f ingress/
   ```

3. **Verificar sintaxe dos YAML:**
   ```bash
   microk8s kubectl apply --dry-run=client -f secrets/namespace.yaml
   ```

## 🌐 Problemas de Rede

### Ingress não responde

**Sintomas:**
- `https://coder.local` não carrega
- Timeout de conexão

**Soluções:**

1. **Verificar status do ingress controller:**
   ```bash
   microk8s kubectl -n ingress get pods
   microk8s kubectl -n ingress logs -l name=nginx-ingress-microk8s
   ```

2. **Verificar configuração do ingress:**
   ```bash
   microk8s kubectl -n coder describe ingress coder
   ```

3. **Testar conectividade interna:**
   ```bash
   microk8s kubectl -n coder port-forward service/coder 8080:80
   # Teste: curl http://localhost:8080
   ```

4. **Verificar /etc/hosts:**
   ```bash
   echo "<CLUSTER-IP> coder.local" | sudo tee -a /etc/hosts
   ```

### DNS não resolve

**Sintomas:**
- Pods não conseguem resolver nomes
- Erro "nslookup: can't resolve"

**Soluções:**

1. **Verificar CoreDNS:**
   ```bash
   microk8s kubectl -n kube-system get pods -l k8s-app=kube-dns
   microk8s kubectl -n kube-system logs -l k8s-app=kube-dns
   ```

2. **Reiniciar CoreDNS:**
   ```bash
   microk8s kubectl -n kube-system rollout restart deployment/coredns
   ```

3. **Testar resolução DNS:**
   ```bash
   microk8s kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
   ```

### Service não acessível

**Sintomas:**
- Pods não conseguem se comunicar
- Erro de conexão entre serviços

**Soluções:**

1. **Verificar endpoints:**
   ```bash
   microk8s kubectl -n coder get endpoints
   ```

2. **Verificar labels e selectors:**
   ```bash
   microk8s kubectl -n coder describe service coder
   microk8s kubectl -n coder get pods --show-labels
   ```

3. **Testar conectividade:**
   ```bash
   microk8s kubectl -n coder exec -it <pod-name> -- wget -qO- http://coder:80
   ```

## 🔒 Problemas de Certificados

### Certificado TLS não é emitido

**Sintomas:**
- HTTPS não funciona
- Certificado aparece como "False" em Ready

**Soluções:**

1. **Verificar status do certificado:**
   ```bash
   microk8s kubectl -n coder describe certificate coder-tls
   ```

2. **Verificar cert-manager:**
   ```bash
   microk8s kubectl -n cert-manager get pods
   microk8s kubectl -n cert-manager logs deployment/cert-manager
   ```

3. **Verificar CertificateRequest:**
   ```bash
   microk8s kubectl -n coder get certificaterequests
   microk8s kubectl -n coder describe certificaterequest <name>
   ```

4. **Recriar certificado:**
   ```bash
   microk8s kubectl -n coder delete certificate coder-tls
   microk8s kubectl apply -f cert-manager/coder-certificate.yaml
   ```

### Erro de validação ACME

**Sintomas:**
- Certificado falha na validação
- Erro "challenge failed"

**Soluções:**

1. **Verificar challenges:**
   ```bash
   microk8s kubectl -n coder get challenges
   microk8s kubectl -n coder describe challenge <name>
   ```

2. **Verificar conectividade externa:**
   ```bash
   curl -I http://coder.local/.well-known/acme-challenge/test
   ```

3. **Usar certificado self-signed temporário:**
   ```bash
   # Editar cert-manager/coder-certificate.yaml
   # Trocar issuer para selfsigned-issuer
   ```

## ⚡ Problemas de Performance

### Pods lentos para iniciar

**Sintomas:**
- Pods ficam em "Pending" ou "ContainerCreating"
- Tempo de inicialização muito alto

**Soluções:**

1. **Verificar recursos disponíveis:**
   ```bash
   microk8s kubectl top nodes
   microk8s kubectl describe node
   ```

2. **Verificar pull de imagens:**
   ```bash
   microk8s kubectl -n coder describe pod <pod-name>
   ```

3. **Ajustar recursos no values.yaml:**
   ```yaml
   resources:
     requests:
       memory: "512Mi"
       cpu: "250m"
     limits:
       memory: "1Gi"
       cpu: "500m"
   ```

### Alto uso de CPU/Memória

**Sintomas:**
- Sistema lento
- Pods sendo killed (OOMKilled)

**Soluções:**

1. **Monitorar recursos:**
   ```bash
   microk8s kubectl -n coder top pods
   watch microk8s kubectl -n coder get pods
   ```

2. **Ajustar limits:**
   ```bash
   # Editar values/coder-values.yaml
   # Aumentar memory limits
   ```

3. **Verificar logs de aplicação:**
   ```bash
   microk8s kubectl -n coder logs deployment/coder --tail=100
   ```

## 💾 Problemas de Armazenamento

### PVC não é criado

**Sintomas:**
- Pods ficam em "Pending"
- Erro "pod has unbound immediate PersistentVolumeClaims"

**Soluções:**

1. **Verificar storage class:**
   ```bash
   microk8s kubectl get storageclass
   ```

2. **Habilitar storage addon:**
   ```bash
   microk8s enable storage
   ```

3. **Verificar PVs disponíveis:**
   ```bash
   microk8s kubectl get pv
   ```

### Dados perdidos após restart

**Sintomas:**
- Configurações não persistem
- Workspaces desaparecem

**Soluções:**

1. **Verificar PVC:**
   ```bash
   microk8s kubectl -n coder get pvc
   microk8s kubectl -n coder describe pvc <pvc-name>
   ```

2. **Verificar mount points:**
   ```bash
   microk8s kubectl -n coder describe pod <pod-name>
   ```

3. **Backup manual:**
   ```bash
   microk8s kubectl -n coder exec <pod-name> -- tar czf - /data > backup.tar.gz
   ```

## 🔍 Comandos de Diagnóstico

### Verificação Completa do Sistema

```bash
# Status geral
./90-status.sh

# Verificar dependências
./check-dependencies.sh status

# Recursos do cluster
microk8s kubectl get all -A

# Eventos recentes
microk8s kubectl get events --sort-by='.lastTimestamp' -A

# Uso de recursos
microk8s kubectl top nodes
microk8s kubectl top pods -A
```

### Coleta de Logs

```bash
# Logs do Coder
microk8s kubectl -n coder logs deployment/coder > coder-app.log

# Logs do sistema
journalctl -u snap.microk8s.daemon-kubelite > microk8s.log

# Logs do ingress
microk8s kubectl -n ingress logs -l name=nginx-ingress-microk8s > ingress.log

# Logs do cert-manager
microk8s kubectl -n cert-manager logs deployment/cert-manager > cert-manager.log
```

### Teste de Conectividade

```bash
# Pod de debug
microk8s kubectl run debug --image=busybox -it --rm --restart=Never -- sh

# Dentro do pod:
wget -qO- http://coder.coder.svc.cluster.local
nslookup coder.coder.svc.cluster.local
ping coder.coder.svc.cluster.local
```

## 📋 Logs Importantes

### Localizações de Logs

| Componente | Comando |
|------------|----------|
| Coder App | `microk8s kubectl -n coder logs deployment/coder` |
| MicroK8s | `journalctl -u snap.microk8s.daemon-kubelite` |
| Ingress | `microk8s kubectl -n ingress logs -l name=nginx-ingress-microk8s` |
| Cert-Manager | `microk8s kubectl -n cert-manager logs deployment/cert-manager` |
| CoreDNS | `microk8s kubectl -n kube-system logs -l k8s-app=kube-dns` |

### Padrões de Erro Comuns

| Erro | Causa Provável | Solução |
|------|----------------|----------|
| `ImagePullBackOff` | Imagem não encontrada | Verificar conectividade de rede |
| `CrashLoopBackOff` | Aplicação falha ao iniciar | Verificar logs da aplicação |
| `Pending` | Recursos insuficientes | Verificar CPU/memória disponível |
| `OOMKilled` | Falta de memória | Aumentar memory limits |
| `FailedMount` | Problema com volumes | Verificar PVC e storage class |

## 🚑 Recuperação de Desastres

### Backup Completo

```bash
#!/bin/bash
# Script de backup

BACKUP_DIR="coder-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup dos manifests
cp -r . "$BACKUP_DIR/manifests/"

# Backup da configuração Helm
microk8s helm3 get values coder -n coder > "$BACKUP_DIR/helm-values.yaml"

# Backup dos dados (se possível)
microk8s kubectl -n coder exec deployment/coder -- tar czf - /data > "$BACKUP_DIR/data.tar.gz"

echo "Backup criado em: $BACKUP_DIR"
```

### Restauração

```bash
#!/bin/bash
# Script de restauração

BACKUP_DIR="$1"

if [ -z "$BACKUP_DIR" ]; then
    echo "Uso: $0 <backup-directory>"
    exit 1
fi

# Remover instalação atual
./99-remove-coder.sh --force

# Restaurar manifests
cp -r "$BACKUP_DIR/manifests/"* .

# Reinstalar
./00-prereqs.sh
./10-install-helm.sh

# Restaurar dados (se necessário)
if [ -f "$BACKUP_DIR/data.tar.gz" ]; then
    microk8s kubectl -n coder exec deployment/coder -- tar xzf - -C / < "$BACKUP_DIR/data.tar.gz"
fi

echo "Restauração concluída"
```

### Reset Completo

```bash
#!/bin/bash
# Reset completo do ambiente

echo "⚠️  ATENÇÃO: Isso irá remover TUDO!"
read -p "Continuar? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Remover Coder
    ./99-remove-coder.sh --force
    
    # Reset MicroK8s
    microk8s reset
    
    # Reiniciar MicroK8s
    microk8s start
    microk8s status --wait-ready
    
    # Reabilitar addons
    microk8s enable dns ingress cert-manager helm3
    
    echo "✅ Reset completo realizado"
    echo "🚀 Execute ./00-prereqs.sh para reinstalar"
fi
```

## 📞 Suporte

Se os problemas persistirem:

1. **Colete informações de diagnóstico:**
   ```bash
   ./90-status.sh > diagnostics.txt
   microk8s kubectl get events -A --sort-by='.lastTimestamp' >> diagnostics.txt
   ```

2. **Consulte a documentação oficial:**
   - [Coder Docs](https://coder.com/docs)
   - [MicroK8s Docs](https://microk8s.io/docs)
   - [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)

3. **Comunidade:**
   - [Coder Discord](https://discord.gg/coder)
   - [MicroK8s Forum](https://discuss.kubernetes.io/c/microk8s)

---

**Nota**: Este documento é mantido pela comunidade. Contribuições são bem-vindas!