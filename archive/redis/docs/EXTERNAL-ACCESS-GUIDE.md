# Redis External Access - Complete Setup Guide

## 🚨 Solução Completa para Acesso Externo ao Redis

Esta é uma solução abrangente para resolver problemas de acesso ao Redis CLI de outras máquinas que não sejam o servidor.

### 📋 Problemas Identificados e Soluções

#### 1. **Erro nos Pods redis-proxy**
**Sintoma**: Pods em estado Error ou CrashLoopBackOff
**Causa**: Inconsistência nos nomes de secrets TLS
**Solução**:
```bash
# Executar script de correção automática
chmod +x fix-redis-proxy.sh
./fix-redis-proxy.sh

# OU correção manual
kubectl apply -f 42-redis-proxy-tls.yaml
kubectl wait --for=condition=complete job/redis-proxy-cert-generator -n redis --timeout=120s
kubectl rollout restart deployment/redis-proxy -n redis
```

#### 2. **Acesso Externo de Outras Máquinas**
**Sintoma**: Não consegue conectar ao Redis CLI de máquinas externas
**Causa**: DNS e configuração de rede não configurados
**Solução**:
```bash
# Script automático para configurar máquina cliente
chmod +x setup-external-client.sh
./setup-external-client.sh

# Irá automaticamente:
# - Detectar IP do cluster
# - Configurar DNS (/etc/hosts)
# - Instalar Redis CLI
# - Testar conectividade
# - Gerar script para Windows
```

#### 3. **Problemas de Conectividade de Rede**
**Sintoma**: Portas não acessíveis ou timeouts
**Causa**: Firewall, NodePort ou configuração de rede
**Solução**:
```bash
# Script de diagnóstico completo
chmod +x diagnose-network-connectivity.sh
./diagnose-network-connectivity.sh

# Irá verificar:
# - Status do cluster
# - Pods e services Redis
# - Conectividade de rede
# - Portas NodePort
# - Configuração DNS
```

### 🚀 Guia de Instalação Completa

#### Passo 1: Preparar o Ambiente
```bash
# Verificar se MicroK8s está funcionando
microk8s status --wait-ready

# Habilitar addons necessários
microk8s enable dns storage ingress cert-manager
```

#### Passo 2: Instalar Redis
```bash
# Navegar para pasta Redis
cd redis/

# Executar instalação completa
chmod +x install-redis.sh
./install-redis.sh

# Aguardar todos os pods ficarem prontos
kubectl wait --for=condition=ready pod -l app=redis-master -n redis --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis-replica -n redis --timeout=300s
```

#### Passo 3: Corrigir Problemas Comuns
```bash
# Executar script de correção
chmod +x fix-installation-issues.sh
./fix-installation-issues.sh

# Verificar status após correção
chmod +x test-installation.sh
./test-installation.sh
```

#### Passo 4: Configurar Acesso Externo
```bash
# No servidor (onde está o cluster)
chmod +x setup-external-client.sh
./setup-external-client.sh

# Irá gerar script para Windows em /tmp/setup-redis-client-windows.ps1
```

#### Passo 5: Configurar Máquinas Cliente

##### Linux/macOS:
```bash
# Copiar e executar o script setup-external-client.sh na máquina cliente
# Ou configurar manualmente:

# Obter IP do cluster (executar no servidor)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "IP do cluster: $NODE_IP"

# Na máquina cliente, adicionar ao /etc/hosts
echo "$NODE_IP redis.home.arpa" | sudo tee -a /etc/hosts
echo "$NODE_IP redis-proxy.home.arpa" | sudo tee -a /etc/hosts

# Instalar Redis CLI
sudo apt install redis-tools  # Ubuntu/Debian
# ou
sudo yum install redis        # RHEL/CentOS
# ou
brew install redis           # macOS
```

##### Windows:
```powershell
# Executar como Administrador
# Copiar script PowerShell gerado e executar:
PowerShell -ExecutionPolicy Bypass -File setup-redis-client-windows.ps1 -NodeIP <IP_DO_CLUSTER>

# Ou configurar manualmente:
# Editar C:\Windows\System32\drivers\etc\hosts
# Adicionar linha: <IP_DO_CLUSTER> redis.home.arpa

# Para Redis CLI no Windows:
# 1. Instalar WSL e executar: sudo apt install redis-tools
# 2. Ou usar Docker: docker run --rm -it redis:latest redis-cli -h redis.home.arpa -p 30379 -a Admin@123
```

### 🧪 Teste de Conectividade

#### Comandos de Teste Básico:
```bash
# Teste básico (via proxy HAProxy - recomendado)
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 ping

# Teste via IP direto
redis-cli -h <IP_DO_CLUSTER> -p 30379 -a Admin@123 ping

# Teste com TLS
redis-cli -h redis.home.arpa -p 30380 --tls --insecure -a Admin@123 ping

# Operações básicas
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 SET teste "funcionando"
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 GET teste
```

#### Dashboard de Monitoramento:
```bash
# HAProxy Stats Dashboard
http://<IP_DO_CLUSTER>:30404/stats
# Usuário: admin | Senha: admin123
```

### 📊 Portas de Acesso

| Porta | Serviço | Protocolo | Descrição |
|-------|---------|-----------|-----------|
| `30379` | Redis Proxy | TCP | **Recomendado** - Sem TLS (terminação no proxy) |
| `30380` | Redis Master | TCP+TLS | Acesso direto com TLS |
| `30381` | Redis Réplicas | TCP | Acesso direto às réplicas |
| `30382` | Redis Réplicas | TCP+TLS | Acesso às réplicas com TLS |
| `30404` | HAProxy Stats | HTTP | Dashboard de monitoramento |

### 🔧 Solução de Problemas

#### Se o acesso externo não funcionar:

1. **Verificar conectividade básica**:
```bash
# Testar se a porta está acessível
telnet <IP_DO_CLUSTER> 30379
# ou
nc -zv <IP_DO_CLUSTER> 30379
```

2. **Verificar firewall**:
```bash
# Ubuntu/Debian
sudo ufw allow 30379:30404/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=30379-30404/tcp
sudo firewall-cmd --reload
```

3. **Verificar status do cluster**:
```bash
# Executar diagnóstico completo
./diagnose-network-connectivity.sh
```

4. **Verificar pods Redis**:
```bash
kubectl get pods -n redis
kubectl logs -n redis -l app=redis-proxy
```

#### Logs Úteis:
```bash
# Logs dos pods Redis
kubectl logs -n redis -l app=redis-master
kubectl logs -n redis -l app=redis-replica
kubectl logs -n redis -l app=redis-proxy

# Status detalhado
kubectl describe pods -n redis
kubectl get svc -n redis -o wide
```

### 💡 Dicas Avançadas

#### Para Desenvolvimento:
```bash
# Port-forward local (para testes rápidos)
kubectl port-forward -n redis svc/redis-proxy-service 6379:6379

# Conectar localmente
redis-cli -h localhost -p 6379 -a Admin@123
```

#### Para Produção:
- Configure Load Balancer externo
- Use Ingress com TLS certificates
- Configure monitoramento adequado
- Implemente backup automático

#### Configuração para Aplicações:
```yaml
# Exemplo Spring Boot
spring:
  redis:
    host: redis.home.arpa
    port: 30379
    password: Admin@123
    timeout: 2000ms

# Exemplo Docker Compose
services:
  app:
    image: myapp:latest
    environment:
      - REDIS_URL=redis://redis.home.arpa:30379
      - REDIS_PASSWORD=Admin@123
    extra_hosts:
      - "redis.home.arpa:<IP_DO_CLUSTER>"
```

### 📞 Suporte

Se ainda tiver problemas após seguir este guia:

1. Execute o diagnóstico completo: `./diagnose-network-connectivity.sh`
2. Verifique os logs: `kubectl logs -n redis -l app=redis-proxy`
3. Teste conectividade de rede: `nc -zv <IP_DO_CLUSTER> 30379`
4. Verifique configuração de firewall e rede

### ✅ Checklist de Verificação

- [ ] MicroK8s funcionando com addons habilitados
- [ ] Pods Redis em estado Running
- [ ] Services NodePort criados corretamente
- [ ] DNS configurado na máquina cliente (/etc/hosts)
- [ ] Redis CLI instalado na máquina cliente
- [ ] Portas 30379-30404 acessíveis via rede
- [ ] Firewall configurado adequadamente
- [ ] Teste de conectividade bem-sucedido

---

**Este guia resolve os principais problemas de acesso externo ao Redis em clusters Kubernetes, proporcionando uma solução completa e automatizada.**