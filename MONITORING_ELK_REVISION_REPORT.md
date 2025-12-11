# Relatório de Revisão - Monitoring e ELK Stack

**Data**: 2025-12-11
**Revisor**: SRE Principal
**Objetivo**: Identificar e corrigir erros nas configurações para K3s

---

## 📊 Resumo Executivo

| Componente | Status | Erros Críticos | Erros Médios | Avisos |
|------------|--------|----------------|--------------|--------|
| **Prometheus** | 🔴 BLOQUEADO | 2 | 0 | 0 |
| **Grafana** | 🔴 BLOQUEADO | 2 | 0 | 0 |
| **Loki** | 🔴 BLOQUEADO | 1 | 0 | 0 |
| **Elasticsearch** | 🔴 CRÍTICO | 3 | 0 | 0 |
| **Kibana** | 🔴 BLOQUEADO | 1 | 0 | 0 |
| **Logstash** | ✅ OK | 0 | 0 | 0 |

**Total**: **9 ERROS CRÍTICOS** encontrados

---

## 1️⃣ PROMETHEUS - Problemas Identificados

### 🔴 ERRO CRÍTICO #1: StorageClass Incorreto

**Arquivo**: `/home/k8s1/k8s/monitoring/12-prometheus-statefulset.yaml`
**Linha**: 53

**Problema**:
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    resources:
      requests:
        storage: 20Gi
    storageClassName: microk8s-strict  # ❌ MicroK8s storage!
```

**Impacto**:
- ⛔ **PVC não será criado** (StorageClass não existe no K3s)
- ⛔ **Pod ficará em estado Pending indefinidamente**
- ⛔ **Prometheus não iniciará**
- 💥 **Perda de métricas** (sem persistência)

**Correção Necessária**:
```yaml
storageClassName: local-path  # ✅ K3s default
```

### 🔴 ERRO CRÍTICO #2: Ingress com Classe Inválida

**Arquivo**: `/home/k8s1/k8s/monitoring/41-prometheus-ingress.yaml`
**Linha**: 7

**Problema**:
```yaml
annotations:
  kubernetes.io/ingress.class: public  # ❌ "public" não existe!
```

**Impacto**:
- ⛔ **Ingress não será processado pelo Traefik**
- ⛔ **Prometheus UI inacessível externamente**
- 🚫 Impossível visualizar métricas via navegador

**Correção Necessária**:
```yaml
annotations:
  kubernetes.io/ingress.class: traefik  # ✅ Correto
spec:
  ingressClassName: traefik  # ✅ Adicionar
```

---

## 2️⃣ GRAFANA - Problemas Identificados

### 🔴 ERRO CRÍTICO #1: PVC com StorageClass Incorreto

**Arquivo**: `/home/k8s1/k8s/monitoring/30-grafana-deployment.yaml`
**Linha**: 26

**Problema**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-storage
  namespace: monitoring
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 10Gi
  storageClassName: microk8s-strict  # ❌ MicroK8s storage!
```

**Impacto**:
- ⛔ **PVC não será criado**
- ⛔ **Grafana pod em CrashLoopBackOff** (sem storage)
- 💥 **Perda de dashboards e configurações**
- 🚫 Grafana inacessível

**Correção Necessária**:
```yaml
storageClassName: local-path  # ✅ K3s default
```

### 🔴 ERRO CRÍTICO #2: Ingress com Classe Inválida

**Arquivo**: `/home/k8s1/k8s/monitoring/31-grafana-ingress.yaml`
**Linha**: 7

**Problema**:
```yaml
annotations:
  kubernetes.io/ingress.class: public  # ❌ "public" não existe!
```

**Impacto**:
- ⛔ **Grafana UI inacessível externamente**
- 🚫 Dashboards não disponíveis

**Correção Necessária**:
```yaml
annotations:
  kubernetes.io/ingress.class: traefik  # ✅ Correto
spec:
  ingressClassName: traefik  # ✅ Adicionar
```

---

## 3️⃣ LOKI - Problemas Identificados

### 🔴 ERRO CRÍTICO #1: StorageClass Incorreto

**Arquivo**: `/home/k8s1/k8s/monitoring/50-loki-config.yaml`
**Linha**: 204

**Problema**:
```yaml
volumeClaimTemplates:
- metadata:
    name: storage
  spec:
    accessModes:
      - ReadWriteOnce
    storageClassName: microk8s-strict  # ❌ MicroK8s storage!
    resources:
      requests:
        storage: 10Gi
```

**Impacto**:
- ⛔ **Loki pod não iniciará** (PVC pending)
- 💥 **Perda de logs** (sistema de logging inoperante)
- 🚫 Impossível fazer queries de logs

**Correção Necessária**:
```yaml
storageClassName: local-path  # ✅ K3s default
```

---

## 4️⃣ ELASTICSEARCH - Problemas Identificados

### 🔴 ERRO CRÍTICO #1: Dados Não Persistentes

**Arquivo**: `/home/k8s1/k8s/ELK/20-elasticsearch-statefulset.yaml`
**Linha**: 84-85

**Problema**:
```yaml
volumes:
  - name: data
    emptyDir: {}  # ❌ Armazenamento volátil!
```

**Impacto**:
- 💥 **PERDA TOTAL DE DADOS ao reiniciar pod**
- 💥 **Perda de índices e logs**
- 💥 **Cluster Elasticsearch instável**
- **CRÍTICO**: Com 3 réplicas usando emptyDir, cada restart perde 1/3 dos dados

**Correção Necessária**:
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    storageClassName: local-path
    resources:
      requests:
        storage: 50Gi  # Ajustar conforme necessidade
```

### 🔴 ERRO CRÍTICO #2: Ingress NGINX

**Arquivo**: `/home/k8s1/k8s/ELK/14-elasticsearch-ingress.yaml`
**Linhas**: 10, 14

**Problema**:
```yaml
annotations:
  kubernetes.io/ingress.class: nginx  # ❌ NGINX não existe!
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx  # ❌ Errado
```

**Impacto**:
- ⛔ **Elasticsearch API inacessível externamente**
- 🚫 Impossível fazer queries HTTP diretas

**Correção Necessária**:
```yaml
annotations:
  kubernetes.io/ingress.class: traefik
spec:
  ingressClassName: traefik
```

### 🔴 ERRO CRÍTICO #3: ServiceAccount Padrão

**Arquivo**: `/home/k8s1/k8s/ELK/20-elasticsearch-statefulset.yaml`
**Linha**: 21

**Problema**:
```yaml
spec:
  serviceAccountName: default  # ❌ Usando default!
```

**Impacto**:
- ⚠️ **Violação de segurança**
- ⚠️ Permissões inadequadas
- ⚠️ Não segue best practices

**Correção Necessária**:
- Criar ServiceAccount dedicado (conforme arquivo 03-rbac.yaml)
```yaml
serviceAccountName: elasticsearch  # ✅ Correto
```

---

## 5️⃣ KIBANA - Problemas Identificados

### 🔴 ERRO CRÍTICO #1: Ingress NGINX

**Arquivo**: `/home/k8s1/k8s/ELK/33-kibana-ingress.yaml`
**Linhas**: 10, 12, 14

**Problema**:
```yaml
annotations:
  kubernetes.io/ingress.class: nginx  # ❌ NGINX não existe!
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx  # ❌ Errado
```

**Impacto**:
- ⛔ **Kibana UI inacessível externamente**
- 🚫 Impossível visualizar logs via interface web
- 🚫 ELK Stack inutilizável

**Correção Necessária**:
```yaml
annotations:
  kubernetes.io/ingress.class: traefik
spec:
  ingressClassName: traefik
```

---

## 6️⃣ LOGSTASH - Status

### ✅ NENHUM ERRO ENCONTRADO

**Arquivo**: `/home/k8s1/k8s/ELK/41-logstash-deployment.yaml`

O Logstash está configurado corretamente:
- ✅ Deployment padrão (stateless)
- ✅ ConfigMap para pipeline
- ✅ Resources definidos
- ✅ Não requer persistência

**Observação**: Logstash funciona como pipeline, não armazena dados.

---

## 📋 Resumo de Erros por Tipo

### StorageClass Incorreto (4 erros)

| Componente | Arquivo | Linha | Atual | Correto |
|------------|---------|-------|-------|---------|
| Prometheus | 12-prometheus-statefulset.yaml | 53 | `microk8s-strict` | `local-path` |
| Grafana | 30-grafana-deployment.yaml | 26 | `microk8s-strict` | `local-path` |
| Loki | 50-loki-config.yaml | 204 | `microk8s-strict` | `local-path` |
| Elasticsearch | 20-elasticsearch-statefulset.yaml | 84 | `emptyDir` | `volumeClaimTemplates` |

### IngressClass Incorreto (4 erros)

| Componente | Arquivo | Linha | Atual | Correto |
|------------|---------|-------|-------|---------|
| Prometheus | 41-prometheus-ingress.yaml | 7 | `public` | `traefik` |
| Grafana | 31-grafana-ingress.yaml | 7 | `public` | `traefik` |
| Elasticsearch | 14-elasticsearch-ingress.yaml | 10 | `nginx` | `traefik` |
| Kibana | 33-kibana-ingress.yaml | 10 | `nginx` | `traefik` |

### Outros Erros (1 erro)

| Componente | Problema | Correção |
|------------|----------|----------|
| Elasticsearch | ServiceAccount default | Usar ServiceAccount dedicado |

---

## 🎯 Impacto Geral

### Componentes Totalmente Bloqueados

1. ❌ **Prometheus**: Não inicia (PVC pending)
2. ❌ **Grafana**: Não inicia (PVC pending)
3. ❌ **Loki**: Não inicia (PVC pending)
4. ❌ **Elasticsearch**: Inicia mas perde dados a cada restart
5. ❌ **Kibana**: Inicia mas UI inacessível
6. ✅ **Logstash**: Funcional (mas inútil sem Elasticsearch estável)

### Stack Inteiro Inoperante

```
┌─────────────────────────────────────────┐
│   MONITORING + ELK STACK = 100% DOWN    │
│                                         │
│  ❌ Sem métricas (Prometheus down)      │
│  ❌ Sem dashboards (Grafana down)       │
│  ❌ Sem logs agregados (Loki down)      │
│  ❌ Sem logs ELK (Elasticsearch volátil)│
│  ❌ Sem visualização (Kibana blocked)   │
└─────────────────────────────────────────┘
```

---

## 🔧 Plano de Correção Priorizado

### 🚨 PRIORIDADE CRÍTICA (Imediata)

1. **Corrigir StorageClass em todos os componentes**
   - Prometheus: `microk8s-strict` → `local-path`
   - Grafana: `microk8s-strict` → `local-path`
   - Loki: `microk8s-strict` → `local-path`
   - Elasticsearch: Adicionar `volumeClaimTemplates`

2. **Corrigir IngressClass em todos os Ingress**
   - Prometheus: `public` → `traefik`
   - Grafana: `public` → `traefik`
   - Elasticsearch: `nginx` → `traefik`
   - Kibana: `nginx` → `traefik`

3. **Corrigir ServiceAccount do Elasticsearch**
   - `default` → `elasticsearch`

### ⚠️ PRIORIDADE ALTA (Pós-correção)

4. Testar cada componente individualmente
5. Validar persistência de dados
6. Verificar acessibilidade via Ingress
7. Configurar retenção de dados adequada

### ℹ️ PRIORIDADE MÉDIA (Melhorias)

8. Adicionar monitoramento de disco (PVCs)
9. Configurar alertas para componentes down
10. Documentar procedimentos de backup
11. Implementar alta disponibilidade

---

## 📝 Checklist de Validação Pós-Correção

### Prometheus
- [ ] PVC criado com storageClass `local-path`
- [ ] Pod em estado Running
- [ ] Ingress acessível: `curl -k https://prometheus.home.arpa`
- [ ] UI funcional no navegador
- [ ] Métricas sendo coletadas

### Grafana
- [ ] PVC criado com storageClass `local-path`
- [ ] Pod em estado Running
- [ ] Ingress acessível: `curl -k https://grafana.home.arpa`
- [ ] UI funcional no navegador
- [ ] Datasources configurados

### Loki
- [ ] PVC criado com storageClass `local-path`
- [ ] Pod em estado Running
- [ ] Logs sendo ingeridos
- [ ] Queries funcionando

### Elasticsearch
- [ ] 3x PVCs criados (um por replica)
- [ ] 3 pods em estado Running
- [ ] Cluster healthy: `curl http://elasticsearch:9200/_cluster/health`
- [ ] Ingress acessível
- [ ] Dados persistidos após restart

### Kibana
- [ ] Pod em estado Running
- [ ] Conectado ao Elasticsearch
- [ ] Ingress acessível: `curl -k https://kibana.home.arpa`
- [ ] UI funcional

### Logstash
- [ ] Pod em estado Running
- [ ] Pipeline configurado
- [ ] Enviando dados para Elasticsearch

---

## 🌍 Domínios Configurados

Conforme `DNS-STANDARDS.md`:

| Serviço | Domínio | Status DNS |
|---------|---------|------------|
| Prometheus | `prometheus.home.arpa` | ✅ Correto |
| Grafana | `grafana.home.arpa` | ✅ Correto |
| Elasticsearch | `elasticsearch.home.arpa` | ✅ Correto |
| Kibana | `kibana.home.arpa` | ✅ Correto |

**Nota**: Domínios já estão corretos, apenas Ingress precisa ser corrigido.

---

## 📊 Comparação Antes/Depois

| Aspecto | Antes | Depois |
|---------|-------|--------|
| **Prometheus StorageClass** | ❌ microk8s-strict | ✅ local-path |
| **Prometheus Ingress** | ❌ public (não funciona) | ✅ traefik |
| **Grafana StorageClass** | ❌ microk8s-strict | ✅ local-path |
| **Grafana Ingress** | ❌ public (não funciona) | ✅ traefik |
| **Loki StorageClass** | ❌ microk8s-strict | ✅ local-path |
| **Elasticsearch Dados** | ❌ emptyDir (volátil) | ✅ PVC (persistente) |
| **Elasticsearch Ingress** | ❌ nginx (não funciona) | ✅ traefik |
| **Elasticsearch ServiceAccount** | ❌ default | ✅ elasticsearch |
| **Kibana Ingress** | ❌ nginx (não funciona) | ✅ traefik |

---

## 🚀 Próximos Passos

1. ✅ Relatório gerado
2. ⏳ Aplicar correções em monitoring
3. ⏳ Aplicar correções em ELK
4. ⏳ Testar cada componente
5. ⏳ Validar persistência
6. ⏳ Criar scripts de instalação
7. ⏳ Atualizar documentação

---

**Assinado**: SRE Principal
**Status**: AGUARDANDO APLICAÇÃO DE CORREÇÕES
**Severidade**: 🔴 CRÍTICO - Sistema de Observabilidade 100% Inoperante
