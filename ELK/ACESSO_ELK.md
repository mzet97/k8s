# Como Acessar o ELK Stack

## ✅ ELK Stack Instalado com Sucesso

O **ELK Stack** (Elasticsearch + Logstash + Kibana + Filebeat) está disponível em:

**Kibana**: https://kibana.home.arpa/
**Elasticsearch API**: https://elasticsearch.home.arpa/

## 🔐 Credenciais de Acesso

### Kibana
- **Usuário**: `elastic`
- **Senha**: `Admin@123`

### Elasticsearch API
- **Usuário**: `elastic`
- **Senha**: `Admin@123`

## 📋 Informações da Instalação

| Componente | URL/Endpoint | Porta |
|------------|--------------|-------|
| **Kibana** | https://kibana.home.arpa/ | 5601 |
| **Elasticsearch API** | https://elasticsearch.home.arpa/ | 9200 |
| **Elasticsearch Interno** | elasticsearch.elk.svc.cluster.local | 9200/9300 |
| **Logstash** | logstash.elk.svc.cluster.local | 5044 |
| **Filebeat** | DaemonSet (todos os nodes) | - |

### Detalhes Técnicos

| Item | Valor |
|------|-------|
| **Namespace** | elk |
| **Ingress IP** | 192.168.1.51 |
| **TLS** | ✅ Sim (cert-manager local-ca) |
| **Elasticsearch Réplicas** | 3 (cluster mode) |
| **Persistência (cada réplica)** | 50Gi |
| **Total de Storage** | ~150Gi |
| **StorageClass** | local-path (K3s) |
| **Versão** | 7.17.16 (Elasticsearch, Kibana, Logstash, Filebeat) |

## 🌐 Configuração DNS

### Se já configurou no roteador:
✅ Você já apontou `*.home.arpa` para `192.168.1.51` no roteador
✅ Pode acessar diretamente:
   - https://kibana.home.arpa/
   - https://elasticsearch.home.arpa/

### Se ainda não configurou localmente:

**Linux/Mac**:
```bash
echo "192.168.1.51 kibana.home.arpa" | sudo tee -a /etc/hosts
echo "192.168.1.51 elasticsearch.home.arpa" | sudo tee -a /etc/hosts
```

**Windows** (como Administrador):
```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "192.168.1.51 kibana.home.arpa"
Add-Content C:\Windows\System32\drivers\etc\hosts "192.168.1.51 elasticsearch.home.arpa"
```

## 🧪 Testar Acesso

### Método 1: Browser (Kibana)
1. Abra o navegador
2. Acesse: https://kibana.home.arpa/
3. Aceite o certificado autoassinado (é esperado)
4. Navegue sem login

### Método 2: curl (Elasticsearch API)
```bash
# Testar saúde do cluster
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cluster/health?pretty

# Listar índices
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cat/indices?v

# Ver informações do cluster
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cat/nodes?v
```

### Método 3: Dentro do Cluster
```bash
# Entrar no pod do Elasticsearch
kubectl exec -it -n elk elasticsearch-0 -- sh

# Dentro do pod
curl http://localhost:9200/_cluster/health?pretty
curl http://localhost:9200/_cat/indices?v
```

## 📊 Kibana - Visualização e Dashboards

### 🎯 O que você pode fazer no Kibana

✅ **Discover**: Explorar logs e dados em tempo real
✅ **Visualize**: Criar visualizações (gráficos, tabelas, mapas)
✅ **Dashboard**: Criar painéis com múltiplas visualizações
✅ **Canvas**: Criar apresentações e infográficos
✅ **Maps**: Visualizar dados geográficos
✅ **Machine Learning**: Detectar anomalias (requer licença)
✅ **Observability**: Monitorar APM, métricas e logs
✅ **Security**: Análise de segurança (requer licença)
✅ **Stack Management**: Gerenciar índices, index patterns, saved objects

### Primeiros Passos no Kibana

#### 1. Criar Index Pattern

1. Acesse **Stack Management** → **Index Patterns**
2. Clique em **Create index pattern**
3. Digite o padrão do índice (ex: `filebeat-*`)
4. Selecione **@timestamp** como Time field
5. Clique em **Create index pattern**

#### 2. Explorar Logs no Discover

1. Acesse **Discover** no menu lateral
2. Selecione o index pattern criado
3. Ajuste o intervalo de tempo (canto superior direito)
4. Use a barra de busca para filtrar logs:
   - `kubernetes.namespace: "default"`
   - `log.level: "error"`
   - `message: *exception*`

#### 3. Criar Visualização

1. Acesse **Visualize** → **Create visualization**
2. Escolha o tipo (Line, Bar, Pie, etc)
3. Selecione o index pattern
4. Configure métricas e buckets
5. Clique em **Save**

#### 4. Criar Dashboard

1. Acesse **Dashboard** → **Create dashboard**
2. Clique em **Add**
3. Selecione as visualizações criadas
4. Organize os painéis
5. Clique em **Save**

### Queries KQL (Kibana Query Language)

```
# Logs de um namespace específico
kubernetes.namespace: "redis"

# Logs com erro
log.level: error OR log.level: ERROR

# Logs de um pod específico
kubernetes.pod.name: "redis-master-0"

# Combinar condições
kubernetes.namespace: "elk" AND log.level: "error"

# Buscar por texto
message: "connection refused"

# Range de tempo (além do seletor visual)
@timestamp >= "2025-12-11T00:00:00"

# Wildcards
kubernetes.pod.name: redis-*
```

## 🔍 Elasticsearch - API e Queries

### O que é o Elasticsearch

Elasticsearch é um motor de busca e analytics distribuído, baseado em Lucene. Armazena dados em formato JSON e permite buscas complexas.

### Comandos Úteis da API

```bash
# Saúde do cluster
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cluster/health?pretty

# Listar todos os índices
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cat/indices?v

# Ver nodes do cluster
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cat/nodes?v

# Estatísticas de um índice
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/filebeat-*/_stats?pretty

# Buscar documentos
curl -k -u elastic:Admin@123 -X GET "https://elasticsearch.home.arpa/filebeat-*/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "kubernetes.namespace": "redis"
    }
  },
  "size": 10
}
'

# Criar um índice
curl -k -u elastic:Admin@123 -X PUT "https://elasticsearch.home.arpa/my-index"

# Indexar um documento
curl -k -u elastic:Admin@123 -X POST "https://elasticsearch.home.arpa/my-index/_doc" -H 'Content-Type: application/json' -d'
{
  "message": "Hello from API",
  "timestamp": "2025-12-11T12:00:00"
}
'

# Deletar um índice
curl -k -u elastic:Admin@123 -X DELETE "https://elasticsearch.home.arpa/my-index"
```

### Elasticsearch Query DSL

```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "kubernetes.namespace": "redis" } }
      ],
      "filter": [
        { "range": { "@timestamp": { "gte": "now-1h" } } }
      ],
      "must_not": [
        { "match": { "log.level": "debug" } }
      ]
    }
  },
  "aggs": {
    "logs_per_namespace": {
      "terms": { "field": "kubernetes.namespace.keyword" }
    }
  },
  "size": 100,
  "sort": [
    { "@timestamp": "desc" }
  ]
}
```

## 📝 Logstash - Pipeline de Dados

### O que é o Logstash

Logstash é um pipeline de processamento de dados que ingere, transforma e envia dados para o Elasticsearch.

### Arquitetura

```
Input → Filter → Output
```

### Exemplo de Pipeline Logstash

```ruby
input {
  beats {
    port => 5044
  }
}

filter {
  if [kubernetes][namespace] == "redis" {
    mutate {
      add_tag => ["redis"]
    }
  }

  if [log][level] == "error" {
    mutate {
      add_tag => ["error"]
    }
  }

  grok {
    match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:msg}" }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logstash-%{+YYYY.MM.dd}"
  }
}
```

### Ver Pipeline Configurado

```bash
kubectl get configmap logstash-pipeline -n elk -o yaml
```

## 📋 Filebeat - Coletor de Logs

### O que é o Filebeat

Filebeat é um agente leve que coleta logs de arquivos e os envia para Logstash ou Elasticsearch.

### Como Funciona

1. Filebeat roda como **DaemonSet** (um pod por node)
2. Monta `/var/log/pods` dos hosts
3. Lê logs de todos os containers
4. Envia para Logstash (porta 5044)
5. Logstash processa e envia para Elasticsearch
6. Kibana permite visualizar os logs

### Ver Logs do Filebeat

```bash
kubectl logs -n elk -l app.kubernetes.io/name=filebeat -f
```

### Configuração do Filebeat

```yaml
filebeat.inputs:
- type: container
  paths:
    - /var/log/pods/*/*/*.log
  processors:
    - add_kubernetes_metadata:
        host: ${NODE_NAME}
        matchers:
        - logs_path:
            logs_path: "/var/log/pods/"

output.logstash:
  hosts: ["logstash:5044"]
```

## 🔧 Status dos Serviços

### Verificar Pods
```bash
kubectl get pods -n elk
kubectl get statefulset -n elk
kubectl get daemonset -n elk
```

### Ver Logs
```bash
# Elasticsearch
kubectl logs -n elk elasticsearch-0 -f

# Kibana
kubectl logs -n elk -l app.kubernetes.io/name=kibana -f

# Logstash
kubectl logs -n elk -l app.kubernetes.io/name=logstash -f

# Filebeat
kubectl logs -n elk -l app.kubernetes.io/name=filebeat -f
```

### Verificar Saúde do Cluster Elasticsearch
```bash
kubectl exec -n elk elasticsearch-0 -- curl http://localhost:9200/_cluster/health?pretty
```

### Verificar PVCs
```bash
kubectl get pvc -n elk
```

### Reiniciar Serviços
```bash
# Elasticsearch
kubectl rollout restart statefulset/elasticsearch -n elk

# Kibana
kubectl rollout restart deployment/kibana -n elk

# Logstash
kubectl rollout restart deployment/logstash -n elk

# Filebeat
kubectl rollout restart daemonset/filebeat -n elk
```

## 🚨 Troubleshooting

### Kibana não carrega
**Verificar se Elasticsearch está acessível**:
```bash
kubectl exec -n elk deployment/kibana -- curl http://elasticsearch:9200
```

### Elasticsearch cluster unhealthy
**Ver status**:
```bash
kubectl exec -n elk elasticsearch-0 -- curl http://localhost:9200/_cluster/health?pretty
```

**Possíveis causas**:
- Pods ainda inicializando (aguarde alguns minutos)
- Problemas de recursos (CPU/memória)
- Problemas de rede entre pods

### Logs não aparecem no Kibana

**1. Verificar se Filebeat está coletando logs**:
```bash
kubectl logs -n elk -l app.kubernetes.io/name=filebeat --tail=50
```

**2. Verificar se Logstash está recebendo**:
```bash
kubectl logs -n elk -l app.kubernetes.io/name=logstash --tail=50
```

**3. Verificar índices no Elasticsearch**:
```bash
curl -k -u elastic:Admin@123 https://elasticsearch.home.arpa/_cat/indices?v
```

**4. Criar Index Pattern no Kibana**:
- Stack Management → Index Patterns → Create
- Use padrão: `filebeat-*` ou `logstash-*`

### Disco cheio
**Verificar uso de disco**:
```bash
kubectl exec -n elk elasticsearch-0 -- df -h /usr/share/elasticsearch/data
```

**Limpar índices antigos**:
```bash
# Deletar índices com mais de 30 dias
curl -k -u elastic:Admin@123 -X DELETE "https://elasticsearch.home.arpa/filebeat-*-$(date -d '30 days ago' +%Y.%m.%d)"
```

**Configurar ILM (Index Lifecycle Management)**:
- No Kibana: Stack Management → Index Lifecycle Policies
- Configure retenção automática de dados

### Elasticsearch OOM (Out of Memory)

**Ver uso de memória**:
```bash
kubectl top pods -n elk
```

**Ajustar heap size** (editar ConfigMap):
```bash
kubectl edit configmap elasticsearch-config -n elk
```

Ajuste no arquivo `jvm.options`:
```
-Xms2g
-Xmx2g
```

Depois reinicie:
```bash
kubectl rollout restart statefulset/elasticsearch -n elk
```

## 📊 Casos de Uso

### Monitorar Logs de Aplicação

1. Aplicação escreve logs em stdout/stderr
2. Filebeat coleta os logs
3. Envia para Logstash
4. Logstash processa e indexa no Elasticsearch
5. Visualize no Kibana → Discover

### Alertas de Erro

1. Criar busca no Kibana para logs de erro
2. Stack Management → Alerting and Actions
3. Criar regra de alerta baseada na busca
4. Configurar ação (email, webhook, Slack)

### Análise de Performance

1. Indexar métricas de performance (response time, throughput)
2. Criar visualizações de séries temporais
3. Combinar em dashboard
4. Identificar gargalos e tendências

### Análise de Segurança

1. Indexar logs de auditoria e autenticação
2. Buscar por padrões suspeitos (tentativas de login falhas, comandos suspeitos)
3. Criar alertas para atividades anômalas
4. Investigar incidentes via Discover

## 📱 Acesso de Outros Dispositivos

### Mesmo Computador
✅ Kibana: https://kibana.home.arpa/
✅ Elasticsearch API: https://elasticsearch.home.arpa/

### Outro Computador na Mesma Rede
✅ Com DNS do roteador configurado, acesse diretamente os URLs acima

### Aplicações no Kubernetes
```bash
# Elasticsearch
http://elasticsearch.elk.svc.cluster.local:9200

# Logstash (Beats input)
logstash.elk.svc.cluster.local:5044
```

## 🔒 Segurança

### Autenticação Habilitada

✅ **X-Pack Security** está habilitado por padrão com as seguintes credenciais:
- **Usuário**: `elastic`
- **Senha**: `Admin@123`

### Recuperar Credenciais

Se precisar recuperar as credenciais configuradas:
```bash
# Ver usuário
kubectl get secret elastic-credentials -n elk -o jsonpath='{.data.username}' | base64 -d
echo

# Ver senha
kubectl get secret elastic-credentials -n elk -o jsonpath='{.data.password}' | base64 -d
echo
```

### Alterar Senha

Para alterar a senha do usuário `elastic`:

```bash
# Opção 1: Atualizar o secret
kubectl edit secret elastic-credentials -n elk
# Edite o campo 'password' com nova senha em base64

# Opção 2: Deletar e recriar o secret
kubectl delete secret elastic-credentials -n elk
kubectl create secret generic elastic-credentials \
  --from-literal=username=elastic \
  --from-literal=password=NovaSenha@123 \
  --from-literal=ELASTIC_USERNAME=elastic \
  --from-literal=ELASTIC_PASSWORD=NovaSenha@123 \
  -n elk

# Reiniciar pods para aplicar nova senha
kubectl rollout restart statefulset/elasticsearch -n elk
kubectl rollout restart deployment/kibana -n elk
kubectl rollout restart deployment/logstash -n elk
```

## 📚 Referências

- **Elasticsearch**: https://www.elastic.co/guide/en/elasticsearch/reference/7.17/index.html
- **Kibana**: https://www.elastic.co/guide/en/kibana/7.17/index.html
- **Logstash**: https://www.elastic.co/guide/en/logstash/7.17/index.html
- **Filebeat**: https://www.elastic.co/guide/en/beats/filebeat/7.17/index.html
- **KQL**: https://www.elastic.co/guide/en/kibana/7.17/kuery-query.html
- **Query DSL**: https://www.elastic.co/guide/en/elasticsearch/reference/7.17/query-dsl.html

## 🎉 Resumo

✅ ELK Stack instalado com sucesso
✅ Kibana: https://kibana.home.arpa/
✅ Elasticsearch API: https://elasticsearch.home.arpa/
✅ Elasticsearch: Cluster com 3 réplicas
✅ Persistência: 3x 50Gi (150Gi total)
✅ Filebeat: Coletando logs de todos os pods
✅ Logstash: Processando e indexando logs
✅ TLS configurado com cert-manager

**Analise seus logs com poder do ELK!** 🔍
