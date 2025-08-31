# 🚀 Redis Master-Replica com Alta Disponibilidade

> **Solução completa de Redis para Kubernetes/MicroK8s com TLS, backup automático e monitoramento**

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.20+-blue.svg)](https://kubernetes.io/)
[![Redis](https://img.shields.io/badge/Redis-7.0-red.svg)](https://redis.io/)
[![TLS](https://img.shields.io/badge/TLS-Enabled-green.svg)](#)
[![Backup](https://img.shields.io/badge/Backup-Automated-orange.svg)](#)

## 📑 Índice

### 🚀 **Início Rápido**
- [📖 Visão Geral](#-visão-geral)
- [📋 Pré-requisitos](#-pré-requisitos)
- [⚡ Instalação Rápida](#-instalação-rápida)
- [✅ Verificação](#-verificação-e-testes)

### 🔧 **Configuração Detalhada**
- [🛠️ Instalação Passo a Passo](#️-instalação-passo-a-passo)
- [🔐 Configuração de Segurança](#-configuração-de-segurança)
- [🌐 Conectando Aplicações](#-como-conectar-suas-aplicações-ao-redis)

### 📊 **Recursos Avançados**
- [💾 Backup e Restore](#-backup-automático)
- [📈 Monitoramento](#-monitoramento-e-alertas)
- [🛡️ Alta Disponibilidade](#️-alta-disponibilidade)
- [🌐 Acesso Externo](#-acesso-de-fora-do-kubernetes-opcional)

### 🔧 **Manutenção**
- [🔧 Troubleshooting](#-resolução-de-problemas)
- [📋 Comandos Úteis](#-comandos-úteis-para-diagnóstico)
- [🗑️ Remoção](#️-como-remover-o-redis-se-necessário)

### 📚 **Referência**
- [📁 Arquivos do Projeto](#-lista-de-arquivos-do-projeto)
- [❓ FAQ](#-perguntas-frequentes-faq)
- [📞 Suporte](#-suporte-e-contribuições)

---

## 📖 Visão Geral

Este projeto implementa uma **solução completa de Redis** para Kubernetes, especificamente otimizada para **MicroK8s**. O Redis é um banco de dados em memória extremamente rápido, ideal para cache, sessões de usuário e armazenamento de dados temporários.

### 🎯 Por que usar Redis Master-Replica?

| Benefício | Descrição | Impacto |
|-----------|-----------|----------|
| **⚡ Performance** | Milhões de operações por segundo | Aplicações 10x mais rápidas |
| **🛡️ Confiabilidade** | Réplicas mantêm serviço se master falhar | 99.9% de disponibilidade |
| **📈 Escalabilidade** | Múltiplas réplicas distribuem leitura | Suporta mais usuários |
| **💾 Backup Automático** | Dados salvos diariamente | Zero perda de dados |
| **🔐 Segurança TLS** | Comunicação criptografada | Dados protegidos |
| **📊 Monitoramento** | Métricas e alertas visuais | Problemas detectados rapidamente |

## 🚀 O que você vai ter depois da instalação

✅ **1 servidor Redis principal (master)** - onde os dados são escritos  
✅ **3 servidores Redis réplicas** - que copiam os dados do master  
✅ **Segurança TLS** - comunicação criptografada entre os serviços  
✅ **Backup diário automático** - seus dados salvos todo dia às 2h da manhã  
✅ **Monitoramento visual** - gráficos e alertas no Grafana  
✅ **Logs centralizados** - todos os logs organizados em um lugar  
✅ **Alta disponibilidade** - se um servidor falhar, os outros continuam  

## ⚡ Instalação Rápida

> **🚀 Para usuários experientes que querem instalar rapidamente**

### Pré-requisitos Rápidos
```bash
# Verificar MicroK8s
microk8s status

# Habilitar addons necessários
microk8s enable storage dns

# Verificar nós disponíveis
microk8s kubectl get nodes
```

### Instalação em 5 Comandos
```bash
# 1. Navegar para o diretório
cd d:\TI\git\k8s\redis

# 2. Configurar senha (edite 01-secret.yaml primeiro!)
microk8s kubectl apply -f 00-namespace.yaml -f 01-secret.yaml -f 03-rbac.yaml

# 3. Certificados TLS (AGUARDAR conclusão!)
microk8s kubectl apply -f 02-tls-certificates.yaml
microk8s kubectl -n redis wait --for=condition=complete job/redis-ca-generator --timeout=300s

# 4. Configurações e serviços
microk8s kubectl apply -f 10-configmap.yaml -f 11-headless-svc.yaml -f 12-client-svc.yaml -f 13-master-svc.yaml

# 5. Redis master, réplicas e replicação
microk8s kubectl apply -f 21-master-statefulset.yaml -f 22-replica-statefulset.yaml
microk8s kubectl apply -f 31-replication-setup-job.yaml
```

### Verificação Rápida
```bash
# Status dos pods
microk8s kubectl -n redis get pods

# Teste de conectividade TLS
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 ping
```

**✅ Sucesso**: Deve retornar `PONG` e todos os pods `Running`

---

## 📋 Pré-requisitos

### ✅ Requisitos Obrigatórios

| Componente | Versão Mínima | Como Verificar | Como Instalar |
|------------|---------------|----------------|---------------|
| **MicroK8s** | 1.20+ | `microk8s status` | [Guia oficial](https://microk8s.io/) |
| **Storage addon** | - | `microk8s status` | `microk8s enable storage` |
| **DNS addon** | - | `microk8s status` | `microk8s enable dns` |

### 💻 Recursos Mínimos

| Recurso | Por Pod | Total (4 pods) | Recomendado |
|---------|---------|----------------|-------------|
| **CPU** | 0.5 core | 2 cores | 4 cores |
| **RAM** | 512MB | 2GB | 4GB |
| **Disco** | 10GB | 40GB | 80GB |
| **Nós** | - | 1 mínimo | 3+ nós |

### 🔧 Dependências Automáticas
- **Redis 7 Alpine** (baixado automaticamente)
- **cert-manager** (para certificados TLS)
- **Volumes persistentes** (HostPath no MicroK8s)

> **⚠️ Produção**: MicroK8s usa armazenamento local (HostPath). Para ambientes críticos, considere storage distribuído como Rook/Ceph.

## 🛠️ Instalação Passo a Passo

> **💡 Dica**: Todos os comandos devem ser executados no terminal onde você tem acesso ao MicroK8s.

### Passo 1: 🔐 Configurar a Senha do Redis

**O que estamos fazendo**: Definindo uma senha segura para proteger o acesso ao Redis.

1. **Abra o arquivo de senha**:
   ```bash
   # Navegue até a pasta do projeto
   cd d:\TI\git\k8s\redis
   
   # Edite o arquivo de senha (use seu editor preferido)
   notepad 01-secret.yaml
   ```

2. **Configure sua senha** (substitua `SuaSenhaSegura123` por uma senha forte):
   ```yaml
   # Conteúdo do arquivo 01-secret.yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: redis-auth
     namespace: redis
   type: Opaque
   stringData:
     REDIS_PASSWORD: "MinhaSenh@Forte123!"
   ```

3. **Salve o arquivo** e feche o editor.

### Passo 2: 🚀 Instalar os Componentes Básicos

**O que estamos fazendo**: Criando o "espaço" (namespace) e as configurações básicas do Redis.

```bash
# 1) Criar o namespace (como uma "pasta" no Kubernetes)
microk8s kubectl apply -f 00-namespace.yaml

# 2) Aplicar a senha que você configurou
microk8s kubectl apply -f 01-secret.yaml

# 3) Aplicar RBAC (permissões necessárias para o job do CA)
microk8s kubectl apply -f 03-rbac.yaml

# 4) Aplicar certificados TLS (CRÍTICO - aguardar conclusão)
microk8s kubectl apply -f 02-tls-certificates.yaml

# AGUARDAR o job do CA completar (OBRIGATÓRIO)
microk8s kubectl -n redis wait --for=condition=complete job/redis-ca-generator --timeout=300s

# Verificar se o certificado foi criado
microk8s kubectl -n redis wait --for=condition=ready certificate/redis-server-cert --timeout=300s

# 5) Aplicar configurações do Redis
microk8s kubectl apply -f 10-configmap.yaml
```

**✅ Verificação**: Você deve ver mensagens como "created" ou "configured" para cada comando. **IMPORTANTE**: 
- O RBAC deve ser aplicado ANTES dos certificados TLS
- Aguarde os certificados serem criados antes de continuar
- Se o job `redis-ca-generator` falhar, verifique os logs: `microk8s kubectl -n redis logs job/redis-ca-generator`

### Passo 3: 🌐 Criar os Serviços de Rede

**O que estamos fazendo**: Configurando como os serviços Redis vão se comunicar.

```bash
# Criar os serviços de rede
microk8s kubectl apply -f 11-headless-svc.yaml
microk8s kubectl apply -f 12-client-svc.yaml
microk8s kubectl apply -f 13-master-svc.yaml
```

### Passo 4: 🗄️ Instalar o Redis Master e Réplicas

**O que estamos fazendo**: Criando os servidores Redis (1 master + 3 réplicas).

```bash
# Instalar o Redis Master
microk8s kubectl apply -f 21-master-statefulset.yaml

# Aguardar o master ficar pronto (pode levar 1-2 minutos)
microk8s kubectl -n redis get pods -w
# Pressione Ctrl+C quando ver: redis-master-0 1/1 Running

# Instalar as Réplicas
microk8s kubectl apply -f 22-replica-statefulset.yaml

# Aguardar todas as réplicas ficarem prontas
microk8s kubectl -n redis get pods -w
# Pressione Ctrl+C quando ver todas com status "1/1 Running"
```

**✅ Verificação**: Execute este comando para ver todos os pods:
```bash
microk8s kubectl -n redis get pods
# Você deve ver:
# redis-master-0    1/1 Running
# redis-replica-0   1/1 Running  
# redis-replica-1   1/1 Running
# redis-replica-2   1/1 Running
```

### Passo 5: 🔗 Configurar a Replicação

**O que estamos fazendo**: Fazendo as réplicas copiarem os dados do master.

```bash
# Executar o job de configuração da replicação
microk8s kubectl apply -f 31-replication-setup-job.yaml

# Acompanhar o progresso (deve levar 30-60 segundos)
microk8s kubectl -n redis logs job/redis-replication-setup -f
```

**✅ Verificação**: Você deve ver mensagens indicando que a replicação foi configurada com sucesso.

## ✅ Verificação e Testes

### Passo 6: 🔍 Verificar se Tudo Está Funcionando

**O que estamos fazendo**: Testando se o Redis foi instalado corretamente.

1. **Verificar o status de todos os componentes**:
   ```bash
   # Ver todos os pods (serviços) do Redis
   microk8s kubectl -n redis get pods
   
   # Ver os serviços de rede
   microk8s kubectl -n redis get services
   
   # Ver os volumes de armazenamento
   microk8s kubectl -n redis get pvc
   ```

2. **Verificar os logs do master**:
   ```bash
   # Ver se o master está funcionando bem
   microk8s kubectl -n redis logs redis-master-0
   ```

3. **Testar a conectividade TLS (porta 6380)**:
   ```bash
   # Conectar no master usando TLS (porta 6380)
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 INFO replication
   
   # Teste simples de conectividade TLS
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 ping
   ```
   
   **⚠️ Nota Importante**: O Redis está configurado para usar **apenas TLS na porta 6380**. A porta 6379 (não-TLS) está desabilitada por segurança.

**✅ O que você deve ver**: 
- Todos os pods com status "Running"
- Logs sem erros críticos
- Informações mostrando 3 réplicas conectadas

### 🧪 Testando o Redis

#### Teste Básico de Funcionamento

**O que estamos fazendo**: Salvando e recuperando dados para garantir que está funcionando.

```bash
# 1) Conectar no Redis master usando TLS (porta 6380)
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380

# 2) Dentro do Redis, execute estes comandos:
# Salvar um dado
SET teste "Meu primeiro dado no Redis!"

# Recuperar o dado
GET teste

# Ver informações do servidor
INFO server

# Ver informações de replicação
INFO replication

# Sair do Redis
EXIT
```

**⚠️ Configuração TLS**: O Redis está configurado para aceitar apenas conexões TLS na porta 6380. Tentativas de conexão na porta 6379 resultarão em "Connection refused" - isso é o comportamento esperado e correto.

#### Teste de Conectividade das Aplicações

**O que estamos fazendo**: Testando a conexão como uma aplicação faria.

**Opção 1: Teste direto no pod master**
```bash
# Conectar diretamente no pod master
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380

# Dentro do cliente Redis, teste:
SET app_test "Conectado via TLS!"
GET app_test
EXIT
```

**Opção 2: Teste de conectividade de rede (sem TLS)**
```bash
# Criar um pod temporário para teste de rede
microk8s kubectl run redis-network-test --rm -it --restart=Never \
  --image=busybox --namespace=redis -- \
  nc -zv redis-client.redis.svc.cluster.local 6380

# Deve retornar: Connection to redis-client.redis.svc.cluster.local 6380 port [tcp/*] succeeded!
```

**⚠️ Nota sobre TLS**: Para aplicações externas, você precisará configurar os certificados TLS adequadamente. O Redis não aceita conexões não-TLS por motivos de segurança.

**✅ O que você deve ver**: Os comandos devem funcionar sem erros e retornar os dados salvos.

### 📱 Exemplo de Aplicação Cliente

**Para desenvolvedores**: Aqui está um exemplo de como uma aplicação pode se conectar ao Redis:

```yaml
# Salve como: exemplo-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minha-app-redis
  namespace: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minha-app
  template:
    metadata:
      labels:
        app: minha-app
    spec:
      containers:
      - name: app
        image: redis:7-alpine
        command: ["sleep", "3600"]
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-auth
              key: REDIS_PASSWORD
        - name: REDIS_HOST
          value: "redis-client.redis.svc.cluster.local"
        - name: REDIS_PORT
          value: "6379"
```

```bash
# Para testar a aplicação:
microk8s kubectl apply -f exemplo-app.yaml
microk8s kubectl -n redis exec -it deployment/minha-app-redis -- redis-cli -h $REDIS_HOST -p $REDIS_PORT -a "$REDIS_PASSWORD"
```

## 🔌 Como Conectar Suas Aplicações ao Redis

### 📋 Informações de Conexão

| Parâmetro | Valor | Observações |
|-----------|-------|-------------|
| **Host** | `redis-client.redis.svc.cluster.local` | Balanceamento automático |
| **Porta** | `6380` | **Apenas TLS** (6379 desabilitada) |
| **Senha** | Configurada em `01-secret.yaml` | Padrão: `Admin@123` |
| **TLS** | **Obrigatório** | Certificados necessários |
| **Master** | `redis-master.redis.svc.cluster.local:6380` | Para escrita |
| **Réplicas** | `redis-replica-*.redis.svc.cluster.local:6380` | Para leitura |

### 🎯 Cenários de Conexão

#### 🟢 Cenário 1: Aplicação Dentro do Kubernetes (Recomendado)
**Quando usar**: Sua aplicação roda como pod no mesmo cluster

**Vantagens**: 
- ✅ Rede interna (mais rápida)
- ✅ Certificados automáticos
- ✅ Balanceamento de carga

#### 🟡 Cenário 2: Desenvolvimento Local
**Quando usar**: Testando aplicação na sua máquina

**Configuração**: Port-forward ou acesso externo

#### 🔴 Cenário 3: Aplicação Externa
**Quando usar**: Aplicação fora do Kubernetes

**Requisitos**: Configurar ingress e certificados

### 💻 Exemplos de Código

#### Python (usando redis-py com TLS)
```python
import redis
import ssl

# Conectar ao Redis com TLS
r = redis.Redis(
    host='redis-client.redis.svc.cluster.local',
    port=6380,
    password='MinhaSenh@Forte123!',
    ssl=True,
    ssl_cert_reqs=ssl.CERT_REQUIRED,
    ssl_ca_certs='/path/to/ca.crt',
    ssl_certfile='/path/to/tls.crt',
    ssl_keyfile='/path/to/tls.key',
    decode_responses=True
)

# Testar a conexão
r.set('minha_chave', 'meu_valor')
print(r.get('minha_chave'))  # Retorna: meu_valor
```

**Para desenvolvimento/teste sem TLS** (menos seguro):
```python
# APENAS para desenvolvimento - conectar diretamente no pod
# Execute dentro do cluster Kubernetes
r = redis.Redis(
    host='redis-master.redis.svc.cluster.local',
    port=6380,
    ssl=True,
    ssl_cert_reqs=ssl.CERT_NONE,  # Ignora verificação de certificado
    decode_responses=True
)
```

#### Node.js (usando redis com TLS)
```javascript
const redis = require('redis');
const fs = require('fs');

const client = redis.createClient({
    host: 'redis-client.redis.svc.cluster.local',
    port: 6380,
    password: 'MinhaSenh@Forte123!',
    tls: {
        ca: fs.readFileSync('/path/to/ca.crt'),
        cert: fs.readFileSync('/path/to/tls.crt'),
        key: fs.readFileSync('/path/to/tls.key'),
        rejectUnauthorized: true
    }
});

client.on('connect', () => {
    console.log('Conectado ao Redis com TLS!');
});

// Usar o Redis
client.set('minha_chave', 'meu_valor');
client.get('minha_chave', (err, result) => {
    console.log(result); // Retorna: meu_valor
});
```

**Para desenvolvimento/teste** (menos seguro):
```javascript
// APENAS para desenvolvimento - sem verificação de certificado
const client = redis.createClient({
    host: 'redis-client.redis.svc.cluster.local',
    port: 6380,
    tls: {
        rejectUnauthorized: false  // Ignora verificação de certificado
    }
});
```

### 🚀 Para Desenvolvedores Avançados: Conexão com Réplicas

**O que isso oferece**: Melhor performance distribuindo leituras entre as réplicas.

**Endereços das réplicas individuais (TLS)**:
```
Master (escrita): redis-master.redis.svc.cluster.local:6380
Réplica 1 (leitura): redis-replica-0.redis-replica.svc.cluster.local:6380
Réplica 2 (leitura): redis-replica-1.redis-replica.svc.cluster.local:6380
Réplica 3 (leitura): redis-replica-2.redis-replica.svc.cluster.local:6380
```

**⚠️ Importante**: Todas as conexões devem usar TLS na porta 6380.

**Exemplo Node.js com master/replica (TLS)**:
```javascript
const redis = require('redis');
const fs = require('fs');

// Configuração TLS comum
const tlsConfig = {
    ca: fs.readFileSync('/path/to/ca.crt'),
    cert: fs.readFileSync('/path/to/tls.crt'),
    key: fs.readFileSync('/path/to/tls.key'),
    rejectUnauthorized: true
};

// Cliente para escrita (master)
const masterClient = redis.createClient({
    host: 'redis-master.redis.svc.cluster.local',
    port: 6380,
    password: 'MinhaSenh@Forte123!',
    tls: tlsConfig
});

// Cliente para leitura (réplicas)
const replicaClient = redis.createClient({
    host: 'redis-client.redis.svc.cluster.local', // Balanceamento automático
    port: 6380,
    password: 'MinhaSenh@Forte123!',
    tls: tlsConfig
});

// Escrever no master
masterClient.set('usuario:123', JSON.stringify({nome: 'João', idade: 30}));

// Ler das réplicas
replicaClient.get('usuario:123', (err, result) => {
    console.log(JSON.parse(result));
});
```

### 🌐 Acesso de Fora do Kubernetes (Opcional)

**Quando usar**: Se você quiser conectar de aplicações que rodam fora do Kubernetes.

1. **Primeiro, habilite o acesso externo**:
   ```bash
   microk8s kubectl apply -f 40-external-access.yaml
   ```

2. **Descubra o IP dos seus nós**:
   ```bash
   microk8s kubectl get nodes -o wide
   ```

3. **Use as portas externas**:
   ```
   <IP_DO_NO>:30380  # Acesso ao serviço principal (TLS)
   ```
   
   **⚠️ Nota**: O acesso externo também usa TLS na porta 30380.

**Exemplo de conexão externa (TLS)**:
```python
import redis
import ssl

# Substitua <IP_DO_NO> pelo IP real do seu nó
r = redis.Redis(
    host='<IP_DO_NO>',
    port=30380,
    password='MinhaSenh@Forte123!',
    ssl=True,
    ssl_cert_reqs=ssl.CERT_NONE,  # Para desenvolvimento
    decode_responses=True
)

r.set('teste_externo', 'funcionando!')
print(r.get('teste_externo'))
```

**⚠️ Importante**: Para produção, configure os certificados TLS adequadamente em vez de usar `ssl_cert_reqs=ssl.CERT_NONE`.

## 🔄 Recursos Avançados (Opcional)

### 💾 Backup Automático

**O que é**: Seus dados Redis são salvos automaticamente todos os dias.

**Para ativar o backup**:
```bash
# Instalar o sistema de backup
microk8s kubectl apply -f 50-backup-cronjob.yaml

# Verificar se o backup está configurado
microk8s kubectl -n redis get cronjob
```

**Para fazer um backup manual**:
```bash
# Executar backup agora
microk8s kubectl -n redis create job redis-backup-manual --from=cronjob/redis-backup

# Ver o progresso
microk8s kubectl -n redis logs job/redis-backup-manual -f
```

**Para restaurar um backup**:
```bash
# Listar backups disponíveis
microk8s kubectl -n redis exec -it redis-master-0 -- ls -la /backup/

# Restaurar um backup específico (substitua a data)
microk8s kubectl -n redis exec -it redis-master-0 -- /scripts/restore.sh backup-2025-01-XX.rdb
```

### 📊 Monitoramento e Alertas

**O que é**: Gráficos e alertas para acompanhar a saúde do Redis.

**Para ativar o monitoramento**:
```bash
# Instalar monitoramento
microk8s kubectl apply -f 60-monitoring.yaml
microk8s kubectl apply -f 61-prometheus-rules.yaml
microk8s kubectl apply -f 62-logging.yaml

# Verificar se está funcionando
microk8s kubectl -n redis get pods | grep exporter
```

**Para ver as métricas**:
```bash
# Ver métricas do Redis
microk8s kubectl -n redis port-forward svc/redis-exporter-master 9121:9121
# Abra http://localhost:9121/metrics no navegador
```

### 🛡️ Alta Disponibilidade

**O que é**: Configurações para garantir que o Redis continue funcionando mesmo se algo der errado.

**Para ativar**:
```bash
# Instalar configurações de alta disponibilidade
microk8s kubectl apply -f 70-high-availability.yaml

# Verificar políticas de disponibilidade
microk8s kubectl -n redis get poddisruptionbudget
```

## 📋 Lista de Arquivos do Projeto

### 📁 Arquivos Principais (Obrigatórios)

| Arquivo | O que faz | Quando usar |
|---------|-----------|-------------|
| `00-namespace.yaml` | Cria o "espaço" do Redis | Sempre (primeiro arquivo) |
| `01-secret.yaml` | Guarda a senha | Sempre (configure sua senha aqui) |
| `02-tls-certificates.yaml` | Certificados de segurança | Sempre |
| `03-rbac.yaml` | Permissões de segurança | Sempre |
| `10-configmap.yaml` | Configurações do Redis | Sempre |
| `11-headless-svc.yaml` | Rede interna | Sempre |
| `12-client-svc.yaml` | Rede para aplicações | Sempre |
| `13-master-svc.yaml` | Rede do master | Sempre |
| `21-master-statefulset.yaml` | Servidor Redis master | Sempre |
| `22-replica-statefulset.yaml` | Servidores Redis réplicas | Sempre |
| `31-replication-setup-job.yaml` | Configura replicação | Sempre |

### 📁 Arquivos Opcionais (Recursos Avançados)

| Arquivo | O que faz | Quando usar |
|---------|-----------|-------------|
| `40-external-access.yaml` | Acesso de fora do Kubernetes | Se precisar conectar externamente |
| `50-backup-cronjob.yaml` | Backup automático | Recomendado para produção |
| `60-monitoring.yaml` | Monitoramento com métricas | Para acompanhar performance |
| `61-prometheus-rules.yaml` | Alertas e dashboards | Para monitoramento avançado |
| `62-logging.yaml` | Logs centralizados | Para análise de logs |
| `70-high-availability.yaml` | Alta disponibilidade | Para ambientes críticos |

### 🎯 Ordem de Instalação Recomendada

**Instalação Básica** (para começar):
1. **Namespace e configurações básicas**:
   ```bash
   microk8s kubectl apply -f 00-namespace.yaml
   microk8s kubectl apply -f 01-secret.yaml
   microk8s kubectl apply -f 03-rbac.yaml
   ```

2. **Certificados TLS (IMPORTANTE: aguardar conclusão)**:
   ```bash
   microk8s kubectl apply -f 02-tls-certificates.yaml
   
   # Aguardar o job do CA completar
   microk8s kubectl -n redis wait --for=condition=complete job/redis-ca-generator --timeout=300s
   
   # Verificar se o certificado foi criado
   microk8s kubectl -n redis wait --for=condition=ready certificate/redis-server-cert --timeout=300s
   ```

3. **Configurações e serviços**:
   ```bash
   microk8s kubectl apply -f 10-configmap.yaml
   microk8s kubectl apply -f 11-headless-svc.yaml
   microk8s kubectl apply -f 12-client-svc.yaml
   microk8s kubectl apply -f 13-master-svc.yaml
   ```

4. **Servidores Redis**:
   ```bash
   microk8s kubectl apply -f 21-master-statefulset.yaml
   microk8s kubectl apply -f 22-replica-statefulset.yaml
   ```

5. **Configurar replicação**:
   ```bash
   microk8s kubectl apply -f 31-replication-setup-job.yaml
   ```

**Recursos Avançados** (depois que o básico estiver funcionando):
1. Arquivo 50 (backup automático)
2. Arquivos 60-62 (monitoramento)
3. Arquivo 70 (alta disponibilidade)
4. Arquivo 40 (acesso externo, se necessário)

## 🔧 Resolução de Problemas

### 🚨 Diagnóstico Rápido

```bash
# Status geral do Redis
microk8s kubectl -n redis get pods,svc,pvc,certificate,secret

# Teste de conectividade TLS
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 ping

# Logs dos componentes principais
microk8s kubectl -n redis logs redis-master-0 --tail=50
microk8s kubectl -n redis logs job/redis-ca-generator

# Eventos recentes
microk8s kubectl -n redis get events --sort-by='.lastTimestamp' --field-selector type!=Normal
```

### 📊 Matriz de Problemas

| Sintoma | Causa Provável | Solução Rápida | Seção Detalhada |
|---------|----------------|----------------|------------------|
| 🔴 Pods `Pending` | Recursos insuficientes | Verificar `kubectl describe pod` | [Recursos](#problema-recursos-insuficientes) |
| 🟡 Pods `CrashLoopBackOff` | Certificados TLS | Verificar job CA | [Certificados TLS](#problema-certificados-tls) |
| 🔵 `Connection refused` | Porta incorreta (6379) | Usar porta 6380 com TLS | [Conectividade](#problema-conectividade) |
| 🟠 Job CA falha | Permissões RBAC | Aplicar RBAC primeiro | [RBAC](#problema-rbac) |
| 🟣 Replicação não funciona | Configuração de rede | Verificar serviços | [Replicação](#problema-replicação) |

---

### ❌ Problemas Detalhados

#### 🔴 Problema: Certificados TLS

**Sintomas**: 
- Job `redis-ca-generator` falha ou timeout
- Pods não iniciam com erros TLS
- Secret `redis-tls-secret` não criado

**Diagnóstico**:

1. **Verificar status do job do CA**:
   ```bash
   # Verificar se o job existe e seu status
   microk8s kubectl -n redis get job redis-ca-generator
   
   # Ver logs do job para identificar o problema
   microk8s kubectl -n redis logs job/redis-ca-generator
   
   # Verificar se o job completou
   microk8s kubectl -n redis describe job redis-ca-generator
   ```

2. **Verificar se os secrets foram criados**:
   ```bash
   # Verificar se o CA foi criado
   microk8s kubectl -n redis get secret redis-ca-key-pair
   
   # Verificar se o secret TLS foi criado
   microk8s kubectl -n redis get secret redis-tls-secret
   
   # Ver detalhes dos secrets
   microk8s kubectl -n redis describe secret redis-ca-key-pair
   microk8s kubectl -n redis describe secret redis-tls-secret
   ```

3. **Verificar status do certificado**:
   ```bash
   # Verificar status do certificado
   microk8s kubectl -n redis get certificate redis-server-cert
   microk8s kubectl -n redis describe certificate redis-server-cert
   
   # O status deve mostrar "True" para Ready
   ```

**Soluções**:

1. **Se o job do CA falhou por falta de permissões**:
   ```bash
   # Aplicar RBAC primeiro (se não foi feito)
   microk8s kubectl apply -f 03-rbac.yaml
   
   # Deletar e recriar o job
   microk8s kubectl -n redis delete job redis-ca-generator
   microk8s kubectl apply -f 02-tls-certificates.yaml
   ```

2. **Se o job falhou por timeout**:
   ```bash
   # Deletar o job e tentar novamente
   microk8s kubectl -n redis delete job redis-ca-generator
   
   # Recriar o job
   microk8s kubectl apply -f 02-tls-certificates.yaml
   
   # Aguardar com timeout maior
   microk8s kubectl -n redis wait --for=condition=complete job/redis-ca-generator --timeout=600s
   ```

3. **Se o secret já existe (erro "already exists")**:
   ```bash
   # Deletar os secrets existentes
   microk8s kubectl -n redis delete secret redis-ca-key-pair redis-tls-secret
   
   # Deletar e recriar o job
   microk8s kubectl -n redis delete job redis-ca-generator
   microk8s kubectl apply -f 02-tls-certificates.yaml
   ```

4. **Solução completa (reset dos certificados)**:
   ```bash
   # Deletar todos os recursos relacionados a certificados
   microk8s kubectl -n redis delete job redis-ca-generator
   microk8s kubectl -n redis delete secret redis-ca-key-pair redis-tls-secret
   microk8s kubectl -n redis delete certificate redis-server-cert
   
   # Aguardar alguns segundos
   sleep 10
   
   # Recriar tudo na ordem correta
   microk8s kubectl apply -f 03-rbac.yaml
   microk8s kubectl apply -f 02-tls-certificates.yaml
   
   # Aguardar conclusão
   microk8s kubectl -n redis wait --for=condition=complete job/redis-ca-generator --timeout=300s
   microk8s kubectl -n redis wait --for=condition=ready certificate/redis-server-cert --timeout=300s
   ```

**Verificação Final**:
```bash
# Verificar se tudo foi criado corretamente
microk8s kubectl -n redis get job,certificate,secret | grep -E "(redis-ca-generator|redis-server-cert|redis-ca-key-pair|redis-tls-secret)"

# Testar se os certificados estão funcionando
microk8s kubectl -n redis exec -it redis-master-0 -- ls -la /tls/
# Deve mostrar: ca.crt, tls.crt, tls.key
```

#### Problema: "Os pods não estão iniciando"

**Sintomas**: Quando você executa `microk8s kubectl -n redis get pods`, vê status como "Pending" ou "CrashLoopBackOff".

**Soluções**:

1. **Verificar se há recursos suficientes**:
   ```bash
   # Ver se os nós têm espaço
   microk8s kubectl describe nodes
   
   # Ver detalhes do problema
   microk8s kubectl -n redis describe pod redis-master-0
   ```

2. **Verificar se o storage está funcionando**:
   ```bash
   # Ver se a classe de armazenamento existe
   microk8s kubectl get storageclass
   
   # Deve mostrar: microk8s-hostpath
   ```

3. **Verificar se todos os secrets existem**:
   ```bash
   # Verificar se todos os secrets necessários foram criados
   microk8s kubectl -n redis get secrets
   
   # Deve mostrar: redis-auth, redis-ca-key-pair, redis-tls-secret
   ```

4. **Verificar se os certificados TLS foram criados**:
   ```bash
   # Verificar status dos certificados
   microk8s kubectl -n redis get certificate
   microk8s kubectl -n redis describe certificate redis-server-cert
   
   # Verificar se o secret TLS existe
   microk8s kubectl -n redis get secret redis-tls-secret
   ```

5. **Se o storage não existir**:
   ```bash
   # Habilitar o addon de storage
   microk8s enable storage
   ```

#### Problema: "Não consigo conectar no Redis"

**Sintomas**: Erros de conexão ao tentar usar o Redis.

**Soluções**:

1. **Verificar se todos os pods estão rodando**:
   ```bash
   microk8s kubectl -n redis get pods
   # Todos devem estar "1/1 Running"
   ```

2. **Verificar se a senha está correta**:
   ```bash
   # Ver a senha configurada
   microk8s kubectl -n redis get secret redis-auth -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d
   ```

3. **Testar a conectividade TLS (CORRETO)**:
   ```bash
   # Testar conexão TLS (porta 6380) - MÉTODO CORRETO
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 ping
   # Deve retornar: PONG
   
   # Testar com informações de replicação
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 INFO replication
   ```

4. **⚠️ IMPORTANTE - Porta 6379 está DESABILITADA**:
   ```bash
   # Tentativa de conexão na porta 6379 resultará em "Connection refused"
   # Isso é NORMAL e ESPERADO por motivos de segurança
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli -h localhost -p 6379 ping
   # Resultado esperado: Could not connect to Redis at localhost:6379: Connection refused
   ```

5. **Verificar configuração TLS**:
   ```bash
   # Verificar se os certificados estão montados corretamente
   microk8s kubectl -n redis exec -it redis-master-0 -- ls -la /tls/
   # Deve mostrar: ca.crt, tls.crt, tls.key
   
   # Verificar configuração do Redis
   microk8s kubectl -n redis exec -it redis-master-0 -- cat /etc/redis/redis.conf | grep -E "(port|tls-port)"
   # Deve mostrar: port 0, tls-port 6380
   ```

#### Problema: "A replicação não está funcionando"

**Sintomas**: Dados escritos no master não aparecem nas réplicas.

**Soluções**:

1. **Verificar o status da replicação (usando TLS)**:
   ```bash
   # Ver informações de replicação usando TLS
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 INFO replication
   
   # Verificar se as réplicas estão conectadas
   microk8s kubectl -n redis exec -it redis-replica-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 INFO replication
   ```

2. **Reexecutar a configuração de replicação**:
   ```bash
   # Deletar o job anterior
   microk8s kubectl -n redis delete job redis-replication-setup
   
   # Executar novamente
   microk8s kubectl apply -f 31-replication-setup-job.yaml
   
   # Acompanhar os logs do job
   microk8s kubectl -n redis logs job/redis-replication-setup -f
   ```

3. **Verificar conectividade entre master e réplicas**:
   ```bash
   # Testar se as réplicas conseguem se conectar ao master
   microk8s kubectl -n redis exec -it redis-replica-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h redis-master.redis.svc.cluster.local -p 6380 ping
   ```

#### Problema: "Performance está lenta"

**Soluções**:

1. **Verificar distribuição dos pods**:
   ```bash
   # Ver em quais nós os pods estão rodando
   microk8s kubectl -n redis get pods -o wide
   ```

2. **Verificar uso de recursos**:
   ```bash
   # Ver uso de CPU e memória
   microk8s kubectl -n redis top pods
   ```

3. **Verificar logs por erros**:
   ```bash
   # Ver logs do master
   microk8s kubectl -n redis logs redis-master-0
   
   # Ver logs das réplicas
   microk8s kubectl -n redis logs redis-replica-0
   ```

## 📋 Referência Rápida de Comandos

### 🔍 Monitoramento e Status

```bash
# Status completo do Redis
microk8s kubectl -n redis get pods,svc,pvc,certificate,secret,job

# Monitoramento em tempo real
microk8s kubectl -n redis get pods -w

# Uso de recursos
microk8s kubectl -n redis top pods

# Eventos importantes
microk8s kubectl -n redis get events --sort-by='.lastTimestamp' --field-selector type!=Normal
```

### 🔧 Diagnóstico e Logs

```bash
# Logs dos componentes principais
microk8s kubectl -n redis logs redis-master-0 --tail=100 -f
microk8s kubectl -n redis logs redis-replica-0 --tail=100 -f
microk8s kubectl -n redis logs job/redis-ca-generator
microk8s kubectl -n redis logs job/redis-replication-setup

# Detalhes de pods problemáticos
microk8s kubectl -n redis describe pod redis-master-0
microk8s kubectl -n redis describe pod redis-replica-0

# Status dos certificados TLS
microk8s kubectl -n redis get certificate,secret
microk8s kubectl -n redis describe certificate redis-server-cert
```

### 🧪 Testes de Conectividade

```bash
# Teste básico TLS
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 ping

# Informações de replicação
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 INFO replication

# Teste de escrita/leitura
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 SET teste "funcionando"
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 GET teste

# Conectividade de rede
microk8s kubectl run redis-network-test --rm -it --restart=Never --image=busybox --namespace=redis -- nc -zv redis-client.redis.svc.cluster.local 6380
```

### 🔄 Operações de Manutenção

```bash
# Reiniciar pods (recreação automática)
microk8s kubectl -n redis delete pod redis-master-0
microk8s kubectl -n redis delete pod redis-replica-0

# Recriar job de replicação
microk8s kubectl -n redis delete job redis-replication-setup
microk8s kubectl apply -f 31-replication-setup-job.yaml

# Reset completo de certificados TLS
microk8s kubectl -n redis delete job redis-ca-generator
microk8s kubectl -n redis delete secret redis-ca-key-pair redis-tls-secret
microk8s kubectl apply -f 02-tls-certificates.yaml

# Verificar configuração do Redis
microk8s kubectl -n redis exec -it redis-master-0 -- cat /etc/redis/redis.conf | grep -E "(port|tls)"
```

### 📊 Comandos de Performance

```bash
# Estatísticas do Redis
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 INFO stats

# Informações de memória
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 INFO memory

# Clientes conectados
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 INFO clients

# Latência
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 --latency
```

### 📞 Quando Pedir Ajuda

Se os problemas persistirem, colete estas informações antes de pedir ajuda:

```bash
# Informações do sistema
microk8s version
microk8s kubectl version

# Status dos recursos
microk8s kubectl -n redis get pods,svc,pvc,certificate,secret

# Logs dos pods
microk8s kubectl -n redis logs redis-master-0 > redis-master.log
microk8s kubectl -n redis logs redis-replica-0 > redis-replica.log

# Logs do job do CA (se existir)
microk8s kubectl -n redis logs job/redis-ca-generator > redis-ca-generator.log 2>/dev/null || echo "Job CA não encontrado"

# Eventos
microk8s kubectl -n redis get events > redis-events.log

# Configuração do Redis
microk8s kubectl -n redis exec redis-master-0 -- cat /etc/redis/redis.conf > redis-config.log

# Status dos certificados
microk8s kubectl -n redis describe certificate redis-server-cert > redis-certificates.log
```

## 🗑️ Como Remover o Redis (Se Necessário)

> **⚠️ ATENÇÃO**: Isso vai apagar TODOS os dados do Redis permanentemente!

### Remoção Completa

```bash
# 1) Remover os recursos avançados (se instalados)
microk8s kubectl delete -f 70-high-availability.yaml --ignore-not-found
microk8s kubectl delete -f 62-logging.yaml --ignore-not-found
microk8s kubectl delete -f 61-prometheus-rules.yaml --ignore-not-found
microk8s kubectl delete -f 60-monitoring.yaml --ignore-not-found
microk8s kubectl delete -f 50-backup-cronjob.yaml --ignore-not-found
microk8s kubectl delete -f 40-external-access.yaml --ignore-not-found

# 2) Remover os jobs
microk8s kubectl delete -f 31-replication-setup-job.yaml --ignore-not-found

# 3) Remover os StatefulSets (servidores Redis)
microk8s kubectl delete -f 22-replica-statefulset.yaml --ignore-not-found
microk8s kubectl delete -f 21-master-statefulset.yaml --ignore-not-found

# 4) Remover serviços de rede
microk8s kubectl delete -f 13-master-svc.yaml --ignore-not-found
microk8s kubectl delete -f 12-client-svc.yaml --ignore-not-found
microk8s kubectl delete -f 11-headless-svc.yaml --ignore-not-found

# 5) Remover configurações
microk8s kubectl delete -f 10-configmap.yaml --ignore-not-found
microk8s kubectl delete -f 03-rbac.yaml --ignore-not-found
microk8s kubectl delete -f 02-tls-certificates.yaml --ignore-not-found
microk8s kubectl delete -f 01-secret.yaml --ignore-not-found

# 6) Remover volumes de dados (CUIDADO: apaga todos os dados!)
microk8s kubectl -n redis delete pvc --all

# 7) Remover o namespace
microk8s kubectl delete -f 00-namespace.yaml
```

### Remoção Apenas dos Dados (Manter Configuração)

```bash
# Se você quiser apenas limpar os dados mas manter a configuração:
microk8s kubectl -n redis delete pvc --all
microk8s kubectl -n redis delete pod --all
# Os pods vão reiniciar automaticamente com dados limpos
```

## ❓ Perguntas Frequentes (FAQ)

## 📚 Glossário

| Termo | Descrição |
|-------|----------|
| **Master** | Servidor Redis principal que aceita operações de escrita e leitura |
| **Réplica** | Servidor Redis secundário, somente leitura, que sincroniza com o master |
| **TLS** | Transport Layer Security - protocolo de criptografia para conexões seguras |
| **StatefulSet** | Tipo de deployment Kubernetes para aplicações com estado (dados persistentes) |
| **PVC** | Persistent Volume Claim - solicitação de armazenamento persistente |
| **Service** | Abstração de rede Kubernetes para expor aplicações |
| **Secret** | Objeto Kubernetes para armazenar dados sensíveis (senhas, certificados) |
| **Job** | Tarefa Kubernetes que executa até completar (ex: setup de certificados) |
| **RBAC** | Role-Based Access Control - controle de acesso baseado em funções |
| **Headless Service** | Service sem IP próprio, usado para descoberta de pods individuais |

## ❓ Perguntas Frequentes (FAQ)

### 🔰 Básico

**P: O que é Redis e para que serve?**
R: Redis é um banco de dados em memória de alta performance, usado como cache, armazenamento de sessões, filas de mensagens e banco de dados principal para aplicações que precisam de baixa latência.

**P: Qual a diferença entre master e réplica?**
R: O master aceita operações de escrita e leitura. As réplicas são somente leitura e sincronizam automaticamente com o master, permitindo distribuir a carga de leitura.

**P: Por que usar TLS obrigatório?**
R: TLS garante que todas as comunicações sejam criptografadas, protegendo dados sensíveis em trânsito e atendendo requisitos de segurança corporativa.

### 🚀 Operação

**P: É seguro usar em produção?**
R: Sim! Esta configuração inclui:
- TLS obrigatório com certificados automáticos
- Autenticação por senha forte
- Backups automáticos diários
- Alta disponibilidade com múltiplas réplicas
- Monitoramento e alertas integrados

**P: Quanto de recurso consome?**
R: **Mínimo por servidor:** 2GB RAM, 2 CPU cores, 20GB storage
**Recomendado:** 4GB RAM, 4 CPU cores, 50GB storage
**Total cluster:** 12GB RAM, 12 CPU cores (3 servidores)

**P: Como verificar se está funcionando corretamente?**
R: Execute a verificação completa:
```bash
# Status dos pods
microk8s kubectl -n redis get pods

# Teste de conectividade
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 ping
```

### ⚙️ Configuração

**P: Posso escalar as réplicas?**
R: Sim! Edite o arquivo `22-replica-statefulset.yaml`:
```yaml
spec:
  replicas: 5  # Altere para o número desejado
```
Aplique: `microk8s kubectl apply -f 22-replica-statefulset.yaml`

**P: Como mudar a senha do Redis?**
R: 1. Gere nova senha em base64: `echo -n "nova_senha" | base64`
2. Edite o secret: `microk8s kubectl -n redis edit secret redis-auth`
3. Substitua o valor em `data.REDIS_PASSWORD`
4. Reinicie os pods: `microk8s kubectl -n redis delete pods --all`

**P: Como acessar de fora do cluster?**
R: Use o acesso externo opcional:
1. Aplique: `microk8s kubectl apply -f 40-external-access.yaml`
2. Descubra o IP: `microk8s kubectl get nodes -o wide`
3. Conecte na porta 30380 com TLS

### 🔧 Troubleshooting

**P: Pod fica em estado Pending?**
R: Verifique recursos disponíveis:
```bash
microk8s kubectl describe node
microk8s kubectl -n redis describe pod <pod-name>
```

**P: Erro de certificado TLS?**
R: Reset completo dos certificados:
```bash
microk8s kubectl -n redis delete job redis-ca-generator
microk8s kubectl -n redis delete secret redis-ca-key-pair redis-tls-secret
microk8s kubectl apply -f 02-tls-certificates.yaml
```

**P: Replicação não funciona?**
R: Recrie o job de replicação:
```bash
microk8s kubectl -n redis delete job redis-replication-setup
microk8s kubectl apply -f 31-replication-setup-job.yaml
```

## 🔄 Histórico de Melhorias

### ✅ Versão Atual - Melhorias Implementadas

**🔐 Segurança TLS Aprimorada**:
- ✅ Correção do job `redis-ca-generator` com permissões RBAC adequadas
- ✅ Instalação automática do kubectl no job do CA
- ✅ Uso de service account token para autenticação
- ✅ Configuração TLS obrigatória na porta 6380 (porta 6379 desabilitada por segurança)
- ✅ Certificados TLS automáticos com renovação

**📋 Ordem de Instalação Corrigida**:
- ✅ RBAC aplicado antes dos certificados TLS
- ✅ Aguardo obrigatório da conclusão dos certificados antes do StatefulSet
- ✅ Verificações de status em cada etapa

**🔧 Troubleshooting Expandido**:
- ✅ Seção específica para problemas de certificados TLS
- ✅ Comandos de diagnóstico detalhados
- ✅ Soluções para problemas comuns de conectividade
- ✅ Explicação sobre porta 6379 desabilitada (comportamento esperado)

**📖 Documentação Atualizada**:
- ✅ Exemplos de código com TLS para Python, Node.js e Java
- ✅ Comandos de teste corrigidos para usar TLS
- ✅ Instruções claras sobre configuração de certificados
- ✅ Seção de verificação final expandida

## 🚀 Próximos Passos

### 🔰 Para Iniciantes
- [ ] **Instalação Básica**
  - Seguir o guia de [Instalação Rápida](#-instalação-rápida)
  - Executar todos os [testes de verificação](#-verificação-e-testes)
  - Verificar logs e status dos pods

- [ ] **Primeiro Uso**
  - Conectar uma aplicação simples usando os [exemplos de código](#-como-conectar-suas-aplicações-ao-redis)
  - Testar operações básicas (SET, GET, DEL)
  - Monitorar uso de recursos

- [ ] **Aprendizado**
  - Estudar a [arquitetura do Redis](#-visão-geral)
  - Entender conceitos do [glossário](#-glossário)
  - Praticar com comandos da [referência rápida](#-comandos-úteis-para-diagnóstico)

### 👨‍💻 Para Desenvolvedores
- [ ] **Integração com Aplicações**
  - Implementar cache usando os exemplos fornecidos
  - Configurar conexões de leitura nas réplicas
  - Implementar tratamento de erros e reconexão

- [ ] **Otimização de Performance**
  - Distribuir leituras entre réplicas
  - Implementar connection pooling
  - Monitorar latência e throughput

- [ ] **Testes e Qualidade**
  - Criar testes automatizados de conectividade
  - Simular cenários de falha
  - Integrar com pipeline CI/CD

### 🔧 Para Administradores
- [ ] **Produção e Segurança**
  - Configurar [backup automático](#-backup-automático)
  - Implementar [monitoramento](#-monitoramento-e-alertas)
  - Configurar alertas para problemas críticos
  - Revisar políticas de segurança

- [ ] **Operações Avançadas**
  - Documentar procedimentos de recuperação
  - Planejar estratégia de escalabilidade
  - Configurar [alta disponibilidade](#️-alta-disponibilidade)
  - Implementar rotação de senhas

- [ ] **Monitoramento Contínuo**
  - Configurar dashboards no Grafana
  - Definir SLAs e métricas de performance
  - Implementar logs centralizados
  - Criar runbooks para incidentes

### 🌟 Recursos Avançados Disponíveis
- **Backup Automático**: Proteção de dados com snapshots diários
- **Monitoramento**: Métricas detalhadas com Prometheus/Grafana
- **Alta Disponibilidade**: Políticas de distribuição entre nós
- **Acesso Externo**: Conexão segura de fora do cluster
- **Certificados TLS**: Criptografia automática end-to-end

## 📞 Suporte e Contribuições

## 🎯 Conclusão

Este projeto fornece uma implementação completa e segura do Redis no Kubernetes, adequada tanto para desenvolvimento quanto para produção. Com **TLS obrigatório**, **alta disponibilidade**, **backups automáticos** e **monitoramento integrado**, você tem uma base sólida para suas aplicações.

### ✅ O que você conseguiu:
- **Segurança**: Comunicação criptografada e autenticação obrigatória
- **Confiabilidade**: Master-replica com failover automático
- **Observabilidade**: Logs, métricas e alertas configurados
- **Manutenibilidade**: Documentação completa e troubleshooting detalhado
- **Escalabilidade**: Fácil adição de réplicas conforme necessário

### 🔄 Próximos Passos Recomendados:
1. **Teste** a instalação seguindo o [guia rápido](#-instalação-rápida)
2. **Conecte** sua primeira aplicação usando os [exemplos](#-como-conectar-suas-aplicações-ao-redis)
3. **Configure** recursos avançados conforme sua necessidade
4. **Monitore** a performance e ajuste conforme necessário

---

## 📞 Suporte e Contribuições

### 🆘 Precisa de Ajuda?

**Antes de pedir ajuda, execute o diagnóstico:**
```bash
# Coleta informações para suporte
microk8s kubectl -n redis get pods,svc,pvc,certificate,secret,job
microk8s kubectl -n redis get events --sort-by='.lastTimestamp'
microk8s kubectl -n redis logs redis-master-0 --tail=50
```

**Canais de Suporte:**
- 🐛 **Issues**: Abra uma issue no repositório com as informações coletadas
- 📚 **Documentação**: [Redis Official Docs](https://redis.io/docs/)
- 👥 **Comunidade**: [Redis Community](https://redis.io/community/)
- 🔧 **Kubernetes**: [Kubernetes Documentation](https://kubernetes.io/docs/)

### 🤝 Como Contribuir

Contribuições são bem-vindas! Siga estes passos:

1. **Fork** este repositório
2. **Crie** uma branch: `git checkout -b feature/nova-funcionalidade`
3. **Implemente** suas mudanças
4. **Teste** completamente
5. **Documente** as alterações
6. **Envie** um Pull Request

**Tipos de contribuições aceitas:**
- 🐛 Correções de bugs
- ✨ Novas funcionalidades
- 📝 Melhorias na documentação
- 🔧 Otimizações de performance
- 🧪 Testes adicionais

### 🗺️ Roadmap

**Próximas versões:**
- [ ] **v2.0**: Suporte a Redis Cluster
- [ ] **v2.1**: Integração com Istio Service Mesh
- [ ] **v2.2**: Backup para S3/MinIO
- [ ] **v2.3**: Certificados com cert-manager
- [ ] **v2.4**: Dashboard customizado no Grafana
- [ ] **v2.5**: Suporte a Redis Modules

**Melhorias contínuas:**
- [ ] Testes automatizados
- [ ] Helm Charts
- [ ] Operador Kubernetes
- [ ] Multi-cluster deployment

---

## 📄 Licença

Este projeto está licenciado sob a **MIT License** - veja o arquivo [LICENSE](LICENSE) para detalhes.

```
MIT License - Você pode usar, modificar e distribuir livremente
```

---

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

*Última atualização: Janeiro 2025 • Versão: 1.2.0*

</div>

