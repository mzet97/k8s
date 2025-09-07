# Redis Master-Replica no Kubernetes

## 🚨 Solução para Problemas de Instalação

### Erro "integer expression expected" no Script de Instalação

**Problema:** O script `install-redis.sh` falha com erro de expressão inteira.

**Solução:** Este erro foi corrigido na versão mais recente. Se ainda ocorrer:

```bash
# Execute o script de correção
chmod +x fix-installation-issues.sh
./fix-installation-issues.sh
```

### Erro "Reached the max retries per request limit"

Se você está enfrentando problemas de conexão com o Redis:

#### Passo 1: Instalar cert-manager
```bash
# Execute o script de instalação
chmod +x install-cert-manager.sh
./install-cert-manager.sh
```

#### Passo 2: Diagnosticar problemas
```bash
# Execute o script de diagnóstico completo
chmod +x fix-installation-issues.sh
./fix-installation-issues.sh

# Ou verificar status específico
chmod +x check-redis-status.sh
./check-redis-status.sh
```

#### Passo 3: Testar instalação
```bash
# Execute o script de teste
chmod +x test-installation.sh
./test-installation.sh
```

#### Passo 4: Testar conexão manual
```bash
# Obter IP do node
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Testar conexão TLS
redis-cli -h $NODE_IP -p 30380 --tls --insecure -a Admin@123 ping
```

## 📋 Visão Geral

Este projeto implementa uma solução completa de Redis Master-Replica para Kubernetes/MicroK8s com:

- ✅ **Alta Disponibilidade** - Master + 3 Réplicas
- ✅ **Segurança TLS** - Certificados automáticos
- ✅ **Acesso Externo** - Proxy HAProxy com terminação TLS
- ✅ **Monitoramento** - Métricas e logs centralizados
- ✅ **Backup Automático** - CronJobs configurados
- ✅ **DNS Simplificado** - Configuração `home.arpa`

## 🚀 Instalação Rápida

### Pré-requisitos
- Kubernetes 1.20+ ou MicroK8s
- cert-manager instalado
- kubectl configurado

### 🤖 Scripts de Automação (Recomendado)

Para facilitar a instalação e remoção, foram criados scripts automatizados:

```bash
# Instalação automática
./install-redis.sh

# Remoção automática
./remove-redis.sh

# Diagnóstico e correção de problemas
./fix-installation-issues.sh

# Teste da instalação
./test-installation.sh
```

**Características dos scripts:**
- ✅ **Verificação automática** de pré-requisitos (MicroK8s)
- ✅ **Ordem correta** de aplicação dos arquivos YAML
- ✅ **Aguarda certificados** TLS serem gerados
- ✅ **Aguarda pods** ficarem prontos
- ✅ **Configuração automática** de DNS com IP do nó
- ✅ **Diagnóstico automático** de problemas comuns
- ✅ **Correção automática** de erros de instalação
- ✅ **Testes pós-instalação** com validação completa
- ✅ **Verificação pós-instalação** com comandos de teste
- ✅ **Confirmação de segurança** antes da remoção
- ✅ **Limpeza completa** de recursos

### Comandos de Instalação Manual

```bash
# 1. Criar namespace e configurações básicas
microk8s kubectl apply -f 00-namespace.yaml
microk8s kubectl apply -f 01-secret.yaml
microk8s kubectl apply -f 03-rbac.yaml

# 2. Configurar TLS e certificados
microk8s kubectl apply -f 02-tls-certificates.yaml

# 3. Configurar Redis (ConfigMaps e Services)
microk8s kubectl apply -f 10-configmap.yaml
microk8s kubectl apply -f 11-headless-svc.yaml
microk8s kubectl apply -f 12-client-svc.yaml
microk8s kubectl apply -f 13-master-svc.yaml

# 4. Implantar Redis Master e Réplicas
microk8s kubectl apply -f 21-master-statefulset.yaml
microk8s kubectl apply -f 22-replica-statefulset.yaml

# 5. Configurar replicação
microk8s kubectl apply -f 31-replication-setup-job.yaml

# 6. Configurar acesso externo
microk8s kubectl apply -f 42-redis-proxy-tls.yaml
microk8s kubectl apply -f 43-dns-config.yaml

# 7. Configurar monitoramento e backup (opcional)
microk8s kubectl apply -f 50-backup-cronjob.yaml
microk8s kubectl apply -f 60-monitoring.yaml
microk8s kubectl apply -f 70-high-availability.yaml
```

### Verificação da Instalação

```bash
# Verificar status dos pods
microk8s kubectl -n redis get pods

# Verificar serviços
microk8s kubectl -n redis get svc

# Verificar certificados TLS
microk8s kubectl -n redis get certificates

# Verificar logs do master
microk8s kubectl -n redis logs redis-master-0
```

## 🗑️ Comandos de Remoção

### 🤖 Remoção Automática (Recomendado)

```bash
# Remoção automática com confirmação
./remove-redis.sh
```

**Características dos scripts de remoção:**
- ✅ **Verificação de pré-requisitos** (MicroK8s e namespace)
- ✅ **Confirmação de segurança** antes da remoção
- ✅ **Ordem reversa** de remoção (segura)
- ✅ **Verificação de recursos** restantes
- ✅ **Opção de limpeza completa** do namespace
- ✅ **Instruções pós-remoção** (DNS e PVs)

### Remoção Manual Completa

```bash
# Remover todos os recursos (ordem reversa)
microk8s kubectl delete -f 70-high-availability.yaml
microk8s kubectl delete -f 60-monitoring.yaml
microk8s kubectl delete -f 50-backup-cronjob.yaml
microk8s kubectl delete -f 43-dns-config.yaml
microk8s kubectl delete -f 42-redis-proxy-tls.yaml
microk8s kubectl delete -f 31-replication-setup-job.yaml
microk8s kubectl delete -f 22-replica-statefulset.yaml
microk8s kubectl delete -f 21-master-statefulset.yaml
microk8s kubectl delete -f 13-master-svc.yaml
microk8s kubectl delete -f 12-client-svc.yaml
microk8s kubectl delete -f 11-headless-svc.yaml
microk8s kubectl delete -f 10-configmap.yaml
microk8s kubectl delete -f 02-tls-certificates.yaml
microk8s kubectl delete -f 03-rbac.yaml
microk8s kubectl delete -f 01-secret.yaml

# Remover namespace (remove tudo)
microk8s kubectl delete namespace redis
```

### Remoção Seletiva

```bash
# Remover apenas o acesso externo
microk8s kubectl delete -f 42-redis-proxy-tls.yaml
microk8s kubectl delete -f 43-dns-config.yaml

# Remover apenas monitoramento
microk8s kubectl delete -f 60-monitoring.yaml

# Remover apenas backup
microk8s kubectl delete -f 50-backup-cronjob.yaml

# Parar Redis (manter dados)
microk8s kubectl -n redis scale statefulset redis-master --replicas=0
microk8s kubectl -n redis scale statefulset redis-replica --replicas=0
```

## 🧪 Testes via Redis CLI

### Configuração de DNS

Antes dos testes, configure o DNS local:

#### Linux/Mac
```bash
# Obter IP do nó
NODE_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "IP do nó: $NODE_IP"

# Adicionar ao /etc/hosts
echo "$NODE_IP redis.home.arpa" | sudo tee -a /etc/hosts
echo "$NODE_IP redis-proxy.home.arpa" | sudo tee -a /etc/hosts
```



### Testes Locais (mesma máquina do Kubernetes)

#### Teste Básico de Conectividade
```bash
# Via proxy HAProxy (recomendado)
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 ping

# Via TLS direto
redis-cli -h redis.home.arpa -p 30380 --tls --insecure -a Admin@123 ping

# Port-forward para desenvolvimento
microk8s kubectl -n redis port-forward svc/redis-client 6380:6380 &
redis-cli -h localhost -p 6380 --tls --insecure -a Admin@123 ping
```

#### Testes de Funcionalidade
```bash
# Teste de escrita/leitura
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 SET teste "funcionando"
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 GET teste

# Teste de replicação
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 SET replicacao "master-to-replica"
redis-cli -h redis.home.arpa -p 30381 -a Admin@123 GET replicacao

# Verificar informações do cluster
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 INFO replication
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 INFO server
```

#### Testes de Performance
```bash
# Benchmark básico
redis-benchmark -h redis.home.arpa -p 30379 -a Admin@123 -t set,get -n 10000 -c 10

# Teste de latência
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 --latency

# Monitoramento em tempo real
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 monitor
```

### Testes de Outras Máquinas

#### Configuração de DNS na Máquina Cliente

**Linux/Mac:**
```bash
# Substituir 192.168.0.52 pelo IP real do nó Kubernetes
echo "192.168.0.52 redis.home.arpa" | sudo tee -a /etc/hosts
echo "192.168.0.52 redis-proxy.home.arpa" | sudo tee -a /etc/hosts
```



#### Instalação do Redis CLI

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install redis-tools
```

**CentOS/RHEL:**
```bash
sudo yum install redis
# ou
sudo dnf install redis
```

**macOS:**
```bash
brew install redis
```



#### Testes de Conectividade Externa

```bash
# Teste básico de rede
ping redis.home.arpa
telnet redis.home.arpa 30379

# Teste Redis via proxy
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 ping

# Teste Redis com TLS
redis-cli -h redis.home.arpa -p 30380 --tls --insecure -a Admin@123 ping

# Teste de operações básicas
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 SET external_test "conectado_de_fora"
redis-cli -h redis.home.arpa -p 30379 -a Admin@123 GET external_test
```

#### Testes de Aplicação

**Python:**
```python
import redis

# Conectar via proxy
r = redis.Redis(host='redis.home.arpa', port=30379, password='Admin@123')

# Testar conexão
print(r.ping())  # Deve retornar True

# Testar operações
r.set('app_test', 'python_client')
print(r.get('app_test'))  # Deve retornar b'python_client'
```

**Node.js:**
```javascript
const redis = require('redis');

const client = redis.createClient({
    host: 'redis.home.arpa',
    port: 30379,
    password: 'Admin@123'
});

client.on('connect', () => {
    console.log('Conectado ao Redis');
    
    client.set('app_test', 'nodejs_client', (err, result) => {
        if (err) throw err;
        console.log('SET:', result);
        
        client.get('app_test', (err, result) => {
            if (err) throw err;
            console.log('GET:', result);
            client.quit();
        });
    });
});
```

## 🚀 Métodos de Acesso Externo

### 1. 🔥 Proxy HAProxy (Recomendado)

**Vantagens:**
- ✅ **Terminação TLS** no proxy (cliente não precisa de certificados)
- ✅ **Balanceamento automático** entre master e réplicas
- ✅ **Monitoramento integrado** com dashboard
- ✅ **Configuração simples** para aplicações

**Portas disponíveis:**
- `30379` - Redis sem TLS (proxy faz terminação)
- `30380` - Redis com TLS (passthrough)
- `30404` - Dashboard HAProxy Stats

### 2. 🔐 Acesso Direto NodePort

**Quando usar:** Aplicações que já possuem certificados TLS configurados

**Portas:**
- `30380` - Redis Master (TLS)
- `30381` - Redis Réplicas (TLS)

### 3. 🔧 Port-Forward (Desenvolvimento)

**Quando usar:** Desenvolvimento local temporário

```bash
# Port-forward para desenvolvimento
microk8s kubectl -n redis port-forward svc/redis-client 6380:6380

# Conectar localmente
redis-cli -h localhost -p 6380 --tls --insecure -a Admin@123
```

## 🔧 Troubleshooting

### Problemas Comuns

#### Connection refused
```bash
# Verificar se o proxy está rodando
microk8s kubectl -n redis get pods -l app=redis-proxy

# Verificar logs do proxy
microk8s kubectl -n redis logs -l app=redis-proxy

# Verificar serviços
microk8s kubectl -n redis get svc redis-proxy-external
```

#### DNS não resolve
```bash
# Testar resolução DNS
nslookup redis.home.arpa
ping redis.home.arpa

# Verificar arquivo hosts
cat /etc/hosts | grep redis
```

#### Erro de autenticação
```bash
# Verificar senha configurada
microk8s kubectl -n redis get secret redis-auth -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d

# Testar sem senha (se configurado)
redis-cli -h redis.home.arpa -p 30379 ping
```

### Problemas com Scripts de Automação

#### Script não executa (Linux/Mac)
```bash
# Verificar permissões
ls -la install-redis.sh remove-redis.sh

# Dar permissão de execução
chmod +x install-redis.sh remove-redis.sh

# Executar com bash explicitamente
bash install-redis.sh
```

#### MicroK8s não encontrado
```bash
# Verificar se MicroK8s está instalado
which microk8s

# Verificar se está no PATH
echo $PATH

# Adicionar ao PATH temporariamente
export PATH=$PATH:/snap/bin  # Linux (se instalado via snap)
```

#### Timeout aguardando recursos
```bash
# Verificar status dos pods manualmente
microk8s kubectl -n redis get pods -w

# Verificar eventos do namespace
microk8s kubectl -n redis get events --sort-by='.lastTimestamp'

# Verificar logs de pods com problemas
microk8s kubectl -n redis logs <pod-name>
```

### Comandos de Diagnóstico
```bash
# Status completo
microk8s kubectl -n redis get all

# Logs do proxy
microk8s kubectl -n redis logs -l app=redis-proxy --tail=50

# Teste de conectividade de rede
telnet redis.home.arpa 30379
nc -zv redis.home.arpa 30379

# Verificar portas abertas no nó
ss -tlnp | grep -E ":(30379|30380|30404)"
```

## 📊 Monitoramento

### Dashboard HAProxy
- **URL**: `http://redis.home.arpa:30404/stats`
- **Usuário**: `admin`
- **Senha**: `admin123`

### Métricas Disponíveis
- Status dos backends (master/réplicas)
- Conexões ativas
- Taxa de transferência
- Latência de resposta
- Erros de conexão

## 📋 Resumo das Portas

| Porta | Serviço | Protocolo | Descrição |
|-------|---------|-----------|----------|
| `30379` | Redis Proxy | TCP | **Recomendado** - Sem TLS (terminação no proxy) |
| `30380` | Redis Master | TCP+TLS | Acesso direto com TLS |
| `30381` | Redis Réplicas | TCP+TLS | Acesso direto às réplicas |
| `30404` | HAProxy Stats | HTTP | Dashboard de monitoramento |

## 🔐 Segurança

### Recomendações
- ✅ **Use sempre o proxy HAProxy** (porta 30379) para simplicidade
- ✅ **Configure firewall** para limitar acesso às portas
- ✅ **Use senhas fortes** e rotacione regularmente
- ✅ **Monitore conexões** através do dashboard HAProxy
- ✅ **Configure DNS interno** para evitar exposição de IPs

### Configuração de Firewall
```bash
# Exemplo para iptables (Linux)
sudo iptables -A INPUT -p tcp --dport 30379 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 30379 -j DROP
```

## 📚 Referência de Arquivos

### Arquivos Principais
- `00-namespace.yaml` - Namespace Redis
- `01-secret.yaml` - Credenciais de autenticação
- `02-tls-certificates.yaml` - Certificados TLS automáticos
- `21-master-statefulset.yaml` - Redis Master
- `22-replica-statefulset.yaml` - Redis Réplicas
- `42-redis-proxy-tls.yaml` - Proxy HAProxy
- `43-dns-config.yaml` - Configuração DNS

### Arquivos Opcionais
- `50-backup-cronjob.yaml` - Backup automático
- `60-monitoring.yaml` - Métricas Prometheus
- `70-high-availability.yaml` - Alta disponibilidade

### Scripts de Automação
- `install-redis.sh` - Script de instalação automática
- `remove-redis.sh` - Script de remoção automática
- `fix-installation-issues.sh` - Script de diagnóstico e correção de problemas
- `test-installation.sh` - Script de teste pós-instalação

**Funcionalidades dos scripts:**
- ✅ Verificação automática de pré-requisitos
- ✅ Aplicação na ordem correta dos arquivos YAML
- ✅ Aguarda certificados TLS e pods ficarem prontos
- ✅ Configuração automática de DNS com IP do nó Kubernetes
- ✅ Verificação pós-instalação com comandos de teste
- ✅ Remoção segura com confirmação do usuário
- ✅ Instruções de limpeza pós-remoção
- ✅ Diagnóstico automático de problemas comuns
- ✅ Correção automática de pods com falhas
- ✅ Validação completa da instalação
- ✅ Sugestões de correção para problemas específicos

---

## 📄 Licença

MIT License - Você pode usar, modificar e distribuir livremente

## 🙏 Agradecimentos

- **Redis Team** pela excelente documentação
- **Kubernetes Community** pelas melhores práticas
- **Contribuidores** que ajudaram a melhorar este projeto

---

<div align="center">

**🎉 Parabéns! Você agora tem um Redis de produção rodando no Kubernetes!**

*Implementação segura • Alta disponibilidade • Pronto para produção*

**⭐ Se este projeto foi útil, considere dar uma estrela no repositório!**

---

*Última atualização: Janeiro 2025 • Versão: 2.0.0*

</div>

