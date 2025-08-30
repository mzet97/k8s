# Redis Master-Replica com Alta Disponibilidade

## 📖 O que é este projeto?

Este projeto implementa uma solução completa de banco de dados Redis para Kubernetes, especificamente otimizada para MicroK8s. O Redis é um banco de dados em memória muito rápido, usado para cache, sessões de usuário e armazenamento de dados temporários.

### 🎯 Por que usar Redis Master-Replica?

- **Performance**: Redis é extremamente rápido (milhões de operações por segundo)
- **Confiabilidade**: Se o servidor principal falhar, as réplicas continuam funcionando
- **Escalabilidade**: Múltiplas réplicas distribuem a carga de leitura
- **Backup automático**: Seus dados são salvos automaticamente todos os dias

## 🚀 O que você vai ter depois da instalação

✅ **1 servidor Redis principal (master)** - onde os dados são escritos  
✅ **3 servidores Redis réplicas** - que copiam os dados do master  
✅ **Segurança TLS** - comunicação criptografada entre os serviços  
✅ **Backup diário automático** - seus dados salvos todo dia às 2h da manhã  
✅ **Monitoramento visual** - gráficos e alertas no Grafana  
✅ **Logs centralizados** - todos os logs organizados em um lugar  
✅ **Alta disponibilidade** - se um servidor falhar, os outros continuam  

## 📋 Requisitos do Sistema

### ✅ O que você precisa ter instalado:

1. **MicroK8s funcionando** (versão 1.20 ou superior)
   ```bash
   # Para verificar se está instalado:
   microk8s status
   ```

2. **Addons do MicroK8s habilitados**:
   ```bash
   # Habilitar os addons necessários:
   microk8s enable storage dns
   ```

3. **Pelo menos 3 nós no cluster** (para distribuir os serviços)
   ```bash
   # Para verificar quantos nós você tem:
   microk8s kubectl get nodes
   ```

4. **Recursos mínimos por servidor**:
   - 1 CPU por pod Redis
   - 512MB de RAM por pod Redis
   - 20GB de espaço em disco por pod Redis

### 🔧 Dependências técnicas:
- **Redis 7 Alpine** (baixado automaticamente)
- **Kubernetes 1.20+**
- **Volumes persistentes** (para salvar os dados)

> **⚠️ Importante para Produção**: O MicroK8s usa armazenamento local (HostPath). Se um servidor físico falhar, os dados desse servidor podem ser perdidos. Para ambientes críticos de produção, considere usar soluções de armazenamento distribuído como Rook/Ceph.

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

# 3) Aplicar certificados TLS (CRÍTICO - aguardar conclusão)
microk8s kubectl apply -f 02-tls-certificates.yaml

# AGUARDAR o job do CA completar (OBRIGATÓRIO)
microk8s kubectl -n redis wait --for=condition=complete job/redis-ca-generator --timeout=300s

# Verificar se o certificado foi criado
microk8s kubectl -n redis wait --for=condition=ready certificate/redis-server-cert --timeout=300s

# 4) Aplicar outras configurações
microk8s kubectl apply -f 03-rbac.yaml
microk8s kubectl apply -f 10-configmap.yaml
```

**✅ Verificação**: Você deve ver mensagens como "created" ou "configured" para cada comando. **IMPORTANTE**: Aguarde os certificados serem criados antes de continuar.

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

3. **Testar a replicação**:
   ```bash
   # Conectar no master e verificar as réplicas
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli -a "MinhaSenh@Forte123!" INFO replication
   ```

**✅ O que você deve ver**: 
- Todos os pods com status "Running"
- Logs sem erros críticos
- Informações mostrando 3 réplicas conectadas

### 🧪 Testando o Redis

#### Teste Básico de Funcionamento

**O que estamos fazendo**: Salvando e recuperando dados para garantir que está funcionando.

```bash
# 1) Conectar no Redis master
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli -a "MinhaSenh@Forte123!"

# 2) Dentro do Redis, execute estes comandos:
# Salvar um dado
SET teste "Meu primeiro dado no Redis!"

# Recuperar o dado
GET teste

# Ver informações do servidor
INFO server

# Sair do Redis
EXIT
```

#### Teste de Conectividade das Aplicações

**O que estamos fazendo**: Criando um pod temporário para testar a conexão como uma aplicação faria.

```bash
# Criar um pod temporário para teste
microk8s kubectl run redis-test --rm -it --restart=Never \
  --image=redis:7-alpine --namespace=redis -- \
  redis-cli -h redis-client.redis.svc.cluster.local -p 6379 -a "MinhaSenh@Forte123!"

# Dentro do cliente Redis, teste:
SET app_test "Conectado via serviço!"
GET app_test
EXIT
```

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

### 🎯 Para Iniciantes: Conexão Simples

**O que você precisa saber**: Suas aplicações podem se conectar ao Redis usando um endereço simples.

**Endereço para conexão**:
```
Host: redis-client.redis.svc.cluster.local
Porta: 6379
Senha: MinhaSenh@Forte123! (a que você configurou)
```

**Exemplo em diferentes linguagens**:

#### Python (usando redis-py)
```python
import redis

# Conectar ao Redis
r = redis.Redis(
    host='redis-client.redis.svc.cluster.local',
    port=6379,
    password='MinhaSenh@Forte123!',
    decode_responses=True
)

# Testar a conexão
r.set('minha_chave', 'meu_valor')
print(r.get('minha_chave'))  # Retorna: meu_valor
```

#### Node.js (usando redis)
```javascript
const redis = require('redis');

const client = redis.createClient({
    host: 'redis-client.redis.svc.cluster.local',
    port: 6379,
    password: 'MinhaSenh@Forte123!'
});

client.on('connect', () => {
    console.log('Conectado ao Redis!');
});

// Usar o Redis
client.set('minha_chave', 'meu_valor');
client.get('minha_chave', (err, result) => {
    console.log(result); // Retorna: meu_valor
});
```

#### Java (usando Jedis)
```java
import redis.clients.jedis.Jedis;

public class RedisExample {
    public static void main(String[] args) {
        Jedis jedis = new Jedis("redis-client.redis.svc.cluster.local", 6379);
        jedis.auth("MinhaSenh@Forte123!");
        
        jedis.set("minha_chave", "meu_valor");
        String valor = jedis.get("minha_chave");
        System.out.println(valor); // Retorna: meu_valor
        
        jedis.close();
    }
}
```

### 🚀 Para Desenvolvedores Avançados: Conexão com Réplicas

**O que isso oferece**: Melhor performance distribuindo leituras entre as réplicas.

**Endereços das réplicas individuais**:
```
Master (escrita): redis-master.redis.svc.cluster.local:6379
Réplica 1 (leitura): redis-replica-0.redis-replica.svc.cluster.local:6379
Réplica 2 (leitura): redis-replica-1.redis-replica.svc.cluster.local:6379
Réplica 3 (leitura): redis-replica-2.redis-replica.svc.cluster.local:6379
```

**Exemplo Node.js com master/replica**:
```javascript
const redis = require('redis');

// Cliente para escrita (master)
const masterClient = redis.createClient({
    host: 'redis-master.redis.svc.cluster.local',
    port: 6379,
    password: 'MinhaSenh@Forte123!'
});

// Cliente para leitura (réplicas)
const replicaClient = redis.createClient({
    host: 'redis-client.redis.svc.cluster.local', // Balanceamento automático
    port: 6379,
    password: 'MinhaSenh@Forte123!'
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
   <IP_DO_NO>:30379  # Acesso ao serviço principal
   ```

**Exemplo de conexão externa**:
```python
import redis

# Substitua <IP_DO_NO> pelo IP real do seu nó
r = redis.Redis(
    host='<IP_DO_NO>',
    port=30379,
    password='MinhaSenh@Forte123!'
)

r.set('teste_externo', 'funcionando!')
print(r.get('teste_externo'))
```

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

### ❌ Problemas Comuns e Soluções

#### Problema: "Problemas com Certificados TLS"

**Sintomas**: Pods não iniciam ou falham na configuração TLS.

**Soluções**:

1. **Verificar se o CA foi criado**:
   ```bash
   # Verificar se o CA foi criado
   microk8s kubectl -n redis get secret redis-ca-key-pair
   
   # Verificar status do certificado
   microk8s kubectl -n redis get certificate redis-server-cert
   microk8s kubectl -n redis describe certificate redis-server-cert
   
   # Verificar se o secret TLS foi criado
   microk8s kubectl -n redis get secret redis-tls-secret
   ```

2. **Se o job do CA falhou, deletar e recriar**:
   ```bash
   microk8s kubectl -n redis delete job redis-ca-generator
   microk8s kubectl apply -f 02-tls-certificates.yaml
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
   ```

4. **Se o storage não existir**:
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

3. **Testar a conectividade interna**:
   ```bash
   # Testar conexão TLS (porta 6380)
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli --tls --cert /tls/tls.crt --key /tls/tls.key --cacert /tls/ca.crt -h localhost -p 6380 -a "$(microk8s kubectl -n redis get secret redis-auth -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d)" ping
   
   # Testar conexão sem TLS (porta 6379)
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli -h localhost -p 6379 -a "$(microk8s kubectl -n redis get secret redis-auth -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d)" ping
   # Deve retornar: PONG
   ```

#### Problema: "A replicação não está funcionando"

**Sintomas**: Dados escritos no master não aparecem nas réplicas.

**Soluções**:

1. **Verificar o status da replicação**:
   ```bash
   # Ver informações de replicação
   microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli -a "SuaSenha" INFO replication
   ```

2. **Reexecutar a configuração de replicação**:
   ```bash
   # Deletar o job anterior
   microk8s kubectl -n redis delete job redis-replication-setup
   
   # Executar novamente
   microk8s kubectl apply -f 31-replication-setup-job.yaml
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

### 🆘 Comandos Úteis para Diagnóstico

```bash
# Ver todos os recursos do Redis
microk8s kubectl -n redis get all

# Ver eventos recentes (problemas)
microk8s kubectl -n redis get events --sort-by='.lastTimestamp'

# Ver detalhes de um pod específico
microk8s kubectl -n redis describe pod redis-master-0

# Ver logs de todos os pods
microk8s kubectl -n redis logs -l app=redis-master
microk8s kubectl -n redis logs -l app=redis-replica

# Reiniciar um pod problemático
microk8s kubectl -n redis delete pod redis-master-0
# O Kubernetes vai recriar automaticamente
```

### 📞 Quando Pedir Ajuda

Se os problemas persistirem, colete estas informações antes de pedir ajuda:

```bash
# Informações do sistema
microk8s version
microk8s kubectl version

# Status dos recursos
microk8s kubectl -n redis get pods,svc,pvc

# Logs dos pods
microk8s kubectl -n redis logs redis-master-0 > redis-master.log
microk8s kubectl -n redis logs redis-replica-0 > redis-replica.log

# Eventos
microk8s kubectl -n redis get events > redis-events.log
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

### 🤔 "O que é Redis e por que eu preciso dele?"
**Resposta**: Redis é um banco de dados super rápido que armazena dados na memória. É usado para:
- **Cache**: Acelerar aplicações web
- **Sessões**: Guardar dados de usuários logados
- **Filas**: Processar tarefas em background
- **Contadores**: Likes, visualizações, etc.

### 🤔 "Qual a diferença entre master e réplica?"
**Resposta**: 
- **Master**: Onde você escreve os dados (como salvar um post)
- **Réplica**: Cópia do master, usada para ler dados (como mostrar posts)
- Se o master falhar, uma réplica pode virar o novo master

### 🤔 "Meus dados estão seguros?"
**Resposta**: Sim! O projeto inclui:
- ✅ Senha para proteger o acesso
- ✅ Criptografia TLS para comunicação
- ✅ Backup automático diário
- ✅ Múltiplas cópias dos dados (réplicas)

### 🤔 "Quanto de recurso isso consome?"
**Resposta**: Recursos mínimos por servidor:
- **CPU**: 1 core
- **RAM**: 512MB
- **Disco**: 20GB
- **Total**: ~4 cores, 2GB RAM, 80GB disco para tudo

### 🤔 "Posso usar em produção?"
**Resposta**: Sim, mas considere:
- ✅ Para pequenas/médias aplicações: Perfeito
- ⚠️ Para aplicações críticas: Use storage distribuído (não HostPath)
- ✅ Inclui monitoramento, backup e alta disponibilidade

### 🤔 "Como sei se está funcionando bem?"
**Resposta**: Monitore estes indicadores:
```bash
# Status dos pods
microk8s kubectl -n redis get pods

# Uso de recursos
microk8s kubectl -n redis top pods

# Teste de conectividade
microk8s kubectl -n redis exec -it redis-master-0 -- redis-cli -a "SuaSenha" ping
```

### 🤔 "Posso escalar para mais réplicas?"
**Resposta**: Sim! Para adicionar mais réplicas:
1. Edite o arquivo `22-replica-statefulset.yaml`
2. Mude `replicas: 3` para `replicas: 5` (por exemplo)
3. Execute: `microk8s kubectl apply -f 22-replica-statefulset.yaml`

### 🤔 "E se eu quiser mudar a senha?"
**Resposta**: 
1. Edite o arquivo `01-secret.yaml` com a nova senha
2. Execute: `microk8s kubectl apply -f 01-secret.yaml`
3. Reinicie os pods: `microk8s kubectl -n redis delete pod --all`

## 📚 Próximos Passos

### Para Iniciantes:
1. ✅ **Instale e teste** seguindo este guia
2. 📖 **Aprenda Redis**: [Tutorial oficial Redis](https://redis.io/docs/getting-started/)
3. 🔧 **Integre com sua aplicação** usando os exemplos de código
4. 📊 **Ative o monitoramento** para acompanhar a performance

### Para Desenvolvedores:
1. 🔄 **Configure backup automático** para seus dados
2. 🛡️ **Ative alta disponibilidade** para ambientes críticos
3. 📈 **Implemente métricas customizadas** para sua aplicação
4. 🚀 **Considere Redis Cluster** para aplicações muito grandes

### Para Administradores:
1. 💾 **Configure storage distribuído** para produção
2. 🔐 **Implemente RBAC** mais restritivo
3. 🌐 **Configure ingress** para acesso externo seguro
4. 📋 **Documente procedimentos** de backup/restore

## 📞 Suporte e Contribuições

### 🆘 Precisa de Ajuda?
- 📖 **Documentação**: Releia as seções relevantes deste README
- 🔧 **Troubleshooting**: Use a seção "Resolução de Problemas"
- 💬 **Comunidade**: [Redis Community](https://redis.io/community/)
- 📚 **Kubernetes**: [Documentação oficial](https://kubernetes.io/docs/)

### 🤝 Contribuições
Contribuições são bem-vindas! Para contribuir:
1. 🍴 Faça um fork do repositório
2. 🌿 Crie uma branch para sua feature
3. ✅ Teste suas mudanças
4. 📝 Documente as alterações
5. 🔄 Abra um Pull Request

## 📄 Licenciamento

Este projeto está licenciado sob a **MIT License**.

### Resumo da Licença:
- ✅ Uso comercial permitido
- ✅ Modificação permitida  
- ✅ Distribuição permitida
- ✅ Uso privado permitido
- ❌ Sem garantias
- ❌ Sem responsabilidade do autor

**Copyright (c) 2025**

---

> 🎉 **Parabéns!** Você agora tem um Redis robusto e seguro rodando no seu Kubernetes! 🚀

