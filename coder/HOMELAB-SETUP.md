# 🏠 Configuração para Homelab

Este guia específico é para configurar o Coder em um ambiente homelab **sem IP público**.

## 🔧 Configurações Específicas para Homelab

### 1. Certificados Self-Signed

Para homelab sem IP público, o projeto está configurado para usar certificados self-signed:

- **ClusterIssuer**: `selfsigned-issuer` (em vez de Let's Encrypt)
- **Domínio local**: `coder.local`
- **Certificado**: Válido por 1 ano, renovação automática

### 2. Configuração de DNS Local

#### Opção A: Arquivo /etc/hosts (Linux/macOS)
```bash
# Adicionar ao /etc/hosts
echo "<IP-DO-MICROK8S> coder.local" | sudo tee -a /etc/hosts
```

#### Opção B: Arquivo hosts (Windows)
```cmd
# Editar C:\Windows\System32\drivers\etc\hosts
<IP-DO-MICROK8S> coder.local
```

#### Descobrir o IP do MicroK8s:
```bash
# IP do nó
microk8s kubectl get nodes -o wide

# Ou IP do ingress
microk8s kubectl -n ingress get svc
```

### 3. Acesso via HTTPS

**URL de acesso**: `https://coder.local`

⚠️ **Importante**: Como usa certificado self-signed, o navegador mostrará aviso de segurança. Clique em "Avançado" → "Continuar para coder.local".

### 4. Configuração Alternativa (HTTP)

Se preferir evitar certificados, pode configurar acesso HTTP:

#### 4.1. Modificar Ingress para HTTP
```yaml
# Em ingress/coder.ingress.yaml, comentar a seção tls:
spec:
  # tls:
  #   - hosts:
  #       - coder.local
  #     secretName: coder-tls
  rules:
    - host: coder.local
      # ...
```

#### 4.2. Atualizar CODER_ACCESS_URL
```yaml
# Em values/coder-values.yaml
env:
  - name: CODER_ACCESS_URL
    value: "http://coder.local"
```

### 5. Port-Forward como Alternativa

Se não quiser configurar DNS:

```bash
# Acesso direto via port-forward
microk8s kubectl -n coder port-forward service/coder 8080:80

# Acesse: http://localhost:8080
```

## 🚀 Instalação Rápida para Homelab

```bash
# 1. Tornar scripts executáveis
chmod +x *.sh

# 2. Verificar configuração homelab
./check-homelab-config.sh
# Este script valida todas as configurações específicas para homelab

# 3. Configurar pré-requisitos
./00-prereqs.sh

# 3. Instalar Coder
./10-install-helm.sh

# 4. Verificar status
./90-status.sh

# 5. Configurar DNS local
echo "$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}') coder.local" | sudo tee -a /etc/hosts
```

## 🔍 Verificações Específicas

### Testar Conectividade Interna
```bash
# Dentro do cluster
microk8s kubectl -n coder exec -it deployment/coder -- wget -qO- http://coder:80

# Port-forward para teste
microk8s kubectl -n coder port-forward service/coder 8080:80
curl http://localhost:8080
```

### Verificar Certificados
```bash
# Status do certificado
microk8s kubectl -n coder get certificate coder-tls

# Detalhes do certificado
microk8s kubectl -n coder describe certificate coder-tls
```

### Logs de Diagnóstico
```bash
# Logs do Coder
microk8s kubectl -n coder logs deployment/coder

# Logs do ingress
microk8s kubectl -n ingress logs -l name=nginx-ingress-microk8s
```

## 🛠️ Troubleshooting Homelab

### Problema: "Site não seguro"
**Solução**: Normal com certificados self-signed. Clique em "Avançado" → "Continuar".

### Problema: "coder.local não resolve"
**Soluções**:
1. Verificar entrada no `/etc/hosts`
2. Usar IP direto: `https://<IP-MICROK8S>`
3. Usar port-forward: `http://localhost:8080`

### Problema: "Conexão recusada"
**Verificações**:
1. MicroK8s rodando: `microk8s status`
2. Pods rodando: `microk8s kubectl -n coder get pods`
3. Ingress funcionando: `microk8s kubectl -n ingress get pods`

### Problema: Workspaces não conectam
**Solução**: Verificar se `CODER_ACCESS_URL` está correto e acessível dos workspaces.

## 📱 Acesso de Dispositivos Móveis

Para acessar de outros dispositivos na rede local:

1. **Descobrir IP do servidor**:
   ```bash
   ip addr show | grep inet
   ```

2. **Configurar DNS nos dispositivos** ou usar IP diretamente:
   ```
   https://<IP-DO-SERVIDOR>
   ```

3. **Aceitar certificado** em cada dispositivo.

## 🔐 Segurança em Homelab

### Recomendações:
- Use certificados self-signed apenas em rede local
- Configure firewall para bloquear acesso externo se necessário
- Considere VPN para acesso remoto seguro
- Monitore logs regularmente

### Backup:
```bash
# Backup da configuração
tar czf coder-backup-$(date +%Y%m%d).tar.gz .

# Backup dos dados (se usando PVC)
microk8s kubectl -n coder exec deployment/coder -- tar czf - /data > coder-data-backup.tar.gz
```

---

**Nota**: Esta configuração é otimizada para ambientes homelab privados. Para produção com acesso público, use Let's Encrypt e domínio real.