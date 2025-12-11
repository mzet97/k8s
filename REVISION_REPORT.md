# Relatório de Revisão - Redis, RabbitMQ, MinIO, ELK

**Data**: 2025-12-11
**Revisor**: SRE Principal
**Objetivo**: Identificar e corrigir erros nas configurações para K3s

---

## 📊 Resumo Executivo

| Componente | Status | Erros Críticos | Erros Médios | Avisos |
|------------|--------|----------------|--------------|--------|
| **Redis** | ⚠️ NECESSITA CORREÇÃO | 1 | 0 | 0 |
| **RabbitMQ** | 🔴 BLOQUEADO | 2 | 1 | 0 |
| **MinIO** | 🔴 BLOQUEADO | 3 | 1 | 0 |
| **ELK** | ⚪ NÃO ENCONTRADO | - | - | - |

---

## 1️⃣ REDIS - Problemas Identificados

### 🔴 ERRO CRÍTICO #1: PodAntiAffinity com Label Incorreto

**Arquivo**: `/home/k8s1/k8s/redis/22-replica-statefulset-k3s.yaml`
**Linha**: 34

**Problema**:
```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values: ["redis-replica"]  # ❌ ERRADO
```

**O que acontece**:
- O podAntiAffinity está procurando pods com label `app: redis-replica`
- Mas os pods de replica têm label `app: redis-cluster` (linha 8 e 21)
- **RESULTADO**: O anti-affinity NUNCA vai funcionar
- **IMPACTO**: Múltiplas réplicas podem ser agendadas no mesmo node, violando alta disponibilidade

**Correção Necessária**:
```yaml
matchExpressions:
- key: app
  operator: In
  values: ["redis-cluster"]  # ✅ CORRETO
```

### ✅ Pontos Positivos do Redis

- ✅ StorageClass correto: `local-path` (K3s)
- ✅ DNS correto: `.home.arpa` e `.svc.cluster.local`
- ✅ Certificados TLS usando `local-ca` ClusterIssuer
- ✅ ServiceLB configurado corretamente
- ✅ Serviços headless e LoadBalancer bem estruturados

---

## 2️⃣ RABBITMQ - Problemas Identificados

### 🔴 ERRO CRÍTICO #1: Ingress Configurado para NGINX

**Arquivo**: `/home/k8s1/k8s/rabbitmq/30-management-ingress.yaml`
**Linhas**: 10, 18, 11-16

**Problema**:
```yaml
annotations:
  kubernetes.io/ingress.class: nginx  # ❌ K3s usa Traefik!
  nginx.ingress.kubernetes.io/proxy-body-size: "0"  # ❌ Annotation NGINX
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx  # ❌ NGINX não está instalado no K3s
```

**Impacto**:
- ⛔ **O Ingress NÃO VAI FUNCIONAR**
- O Traefik vai ignorar este Ingress
- RabbitMQ Management UI não será acessível externamente

**Correção Necessária**:
- Trocar para `ingressClassName: traefik`
- Remover annotations específicas do NGINX
- Adicionar annotations do Traefik se necessário
- **OU** usar `IngressRoute` (CRD do Traefik)

### 🔴 ERRO CRÍTICO #2: Dados Não Persistentes

**Arquivo**: `/home/k8s1/k8s/rabbitmq/20-statefulset.yaml`
**Linhas**: 166-169, 184

**Problema**:
```yaml
volumes:
- name: data
  emptyDir: {}  # ❌ Dados voláteis!
- name: logs
  emptyDir: {}  # ❌ Logs voláteis!

# volumeClaimTemplates temporarily replaced by emptyDir for homelab
```

**Impacto**:
- 💥 **PERDA DE DADOS ao reiniciar pod**
- Mensagens, filas, exchanges serão perdidos
- Logs não persistem entre restarts
- **INACEITÁVEL PARA PRODUÇÃO**

**Correção Necessária**:
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    storageClassName: local-path  # K3s
    resources:
      requests:
        storage: 10Gi
```

### ⚠️ AVISO: TLS Desabilitado

**Arquivo**: `/home/k8s1/k8s/rabbitmq/20-statefulset.yaml`
**Linhas**: 163-165

```yaml
volumes:
- name: ssl-certs
  emptyDir: {}  # TLS mount removido em homelab para simplificar
```

**Impacto**:
- Conexões AMQP e Management sem criptografia
- Senhas e dados trafegam em texto plano
- Aceitável apenas para desenvolvimento local

### ✅ Pontos Positivos do RabbitMQ

- ✅ DNS correto: `.home.arpa` nos certificados
- ✅ Certificados TLS criados com `local-ca`
- ✅ Estrutura de ConfigMap e Secrets adequada
- ✅ Probes de health configuradas
- ✅ PodAntiAffinity correto (usa `app.kubernetes.io/name`)

---

## 3️⃣ MINIO - Problemas Identificados

### 🔴 ERRO CRÍTICO #1: Ingress com Classe Inválida

**Arquivos**:
- `/home/k8s1/k8s/minio/21-minio-console-ingress.yaml` (linha 7)
- `/home/k8s1/k8s/minio/22-minio-s3-ingress.yaml` (linha 7)

**Problema**:
```yaml
annotations:
  kubernetes.io/ingress.class: public  # ❌ "public" não existe no K3s!
```

**Impacto**:
- ⛔ **Ingress não será processado pelo Traefik**
- Console e S3 API não estarão acessíveis
- MinIO ficará isolado internamente

**Correção Necessária**:
```yaml
annotations:
  kubernetes.io/ingress.class: traefik  # ✅ CORRETO
```

### 🔴 ERRO CRÍTICO #2: Annotation NGINX no S3 Ingress

**Arquivo**: `/home/k8s1/k8s/minio/22-minio-s3-ingress.yaml`
**Linha**: 9

**Problema**:
```yaml
annotations:
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"  # ❌ NGINX!
```

**Impacto**:
- Annotation será ignorada pelo Traefik
- Redirecionamento HTTPS pode não funcionar
- Configuração inconsistente

**Correção Necessária**:
- Remover annotation do NGINX
- Usar Middleware do Traefik para redirect HTTPS

### 🔴 ERRO CRÍTICO #3: Conflito de Configurações de Ingress

**Arquivos**: 21, 22 (Ingress) + 32 (HTTPRoute) + 30, 31 (Gateway)

**Problema**:
- Tem **Ingress padrão** (arquivos 21, 22)
- Tem **HTTPRoute/Gateway API** (arquivos 30, 31, 32)
- Tem **múltiplas definições para os mesmos endpoints**

**Impacto**:
- 💥 **CONFLITO**: Dois controladores tentando gerenciar as mesmas rotas
- Comportamento imprevisível
- Pode causar loops ou falhas de roteamento

**Correção Necessária**:
- Escolher UMA abordagem: Ingress OU Gateway API
- **Recomendado**: Usar `IngressRoute` do Traefik (mais simples para K3s)

### ⚠️ ERRO MÉDIO: Inconsistência de Domínios

**Problema**:

| Arquivo | Configuração | Domínio |
|---------|-------------|---------|
| StatefulSet linha 50 | `MINIO_SERVER_URL` | `minio.home.arpa` |
| StatefulSet linha 52 | `MINIO_BROWSER_REDIRECT_URL` | `console.minio.home.arpa` |
| Ingress 21 | Console | `console.minio.home.arpa` |
| Ingress 22 | S3 API | `minio-s3.home.arpa` ❌ |
| HTTPRoute | API | `minio.home.arpa` |
| HTTPRoute | Console | `console.minio.home.arpa` |

**Impacto**:
- Confusão entre `minio.home.arpa` e `minio-s3.home.arpa`
- Configuração interna não bate com Ingress externo

**Correção Necessária**:
- Padronizar:
  - **S3 API**: `minio-s3.home.arpa` (conforme DNS-STANDARDS.md)
  - **Console**: `minio-console.home.arpa` (conforme DNS-STANDARDS.md)
- Atualizar variáveis de ambiente no StatefulSet

### 🔴 ERRO CRÍTICO #4: Dados Não Persistentes

**Arquivo**: `/home/k8s1/k8s/minio/20-statefulset.yaml`
**Linhas**: 81-82

**Problema**:
```yaml
volumes:
- name: data
  emptyDir: {}  # ❌ Armazenamento volátil!
```

**Impacto**:
- 💥 **PERDA TOTAL DE DADOS ao reiniciar pod**
- Todos os objetos S3 serão perdidos
- **INACEITÁVEL PARA QUALQUER AMBIENTE**

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
        storage: 100Gi  # Ajustar conforme necessidade
```

### ✅ Pontos Positivos do MinIO

- ✅ DNS usa `.home.arpa`
- ✅ Certificados com `local-ca`
- ✅ Probes de health configuradas
- ✅ Service Account configurado
- ✅ Security Context adequado

---

## 4️⃣ ELK STACK

### ⚪ NÃO ENCONTRADO

Não foram encontrados arquivos de configuração para ELK (Elasticsearch, Logstash, Kibana) no projeto.

**Diretórios verificados**:
- `/home/k8s1/k8s/elk/` - não existe
- `/home/k8s1/k8s/elasticsearch/` - não existe
- `/home/k8s1/k8s/kibana/` - não existe
- `/home/k8s1/k8s/logstash/` - não existe

**Ação**: ⏭️ Nenhuma revisão necessária

---

## 📋 Plano de Correção Priorizado

### 🚨 PRIORIDADE CRÍTICA (Imediata)

1. **Redis**: Corrigir label no podAntiAffinity
2. **RabbitMQ**: Converter Ingress NGINX → Traefik
3. **RabbitMQ**: Adicionar volumeClaimTemplates para persistência
4. **MinIO**: Corrigir ingressClass de "public" → "traefik"
5. **MinIO**: Adicionar volumeClaimTemplates para persistência
6. **MinIO**: Resolver conflito Ingress vs Gateway API

### ⚠️ PRIORIDADE ALTA (Próximas 24h)

7. **MinIO**: Remover annotation NGINX
8. **MinIO**: Padronizar domínios conforme DNS-STANDARDS.md
9. **RabbitMQ**: Considerar habilitar TLS para produção

### ℹ️ PRIORIDADE MÉDIA (Próximos 7 dias)

10. **Todos**: Adicionar monitoramento e alertas
11. **Todos**: Implementar backups automatizados
12. **Todos**: Documentar procedimentos operacionais

---

## 🎯 Resumo de Impactos

### Impedimentos Totais (Não Funciona)

- ❌ RabbitMQ Management UI inacessível (Ingress NGINX)
- ❌ MinIO Console e S3 inacessível (Ingress classe "public")

### Riscos Críticos (Perda de Dados)

- 💥 RabbitMQ: Perda de mensagens/filas ao restart
- 💥 MinIO: Perda de objetos S3 ao restart

### Degradação de Serviço

- ⚠️ Redis: Réplicas podem agendar no mesmo node (SPoF)
- ⚠️ MinIO: Redirecionamento HTTPS pode não funcionar

---

## 📝 Próximos Passos

1. ✅ Relatório gerado
2. ⏳ Aplicar correções críticas
3. ⏳ Testar cada componente
4. ⏳ Validar persistência de dados
5. ⏳ Atualizar documentação

---

**Assinado**: SRE Principal
**Status**: AGUARDANDO APLICAÇÃO DE CORREÇÕES
