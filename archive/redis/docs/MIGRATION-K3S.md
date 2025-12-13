# Guia de Migração: Redis de MicroK8s para K3s

Este guia explica as mudanças necessárias para migrar a configuração Redis de MicroK8s para K3s.

## Resumo Executivo

| Componente | Status | Ação Necessária |
|------------|--------|-----------------|
| **Arquitetura** | ✅ Mantida | Nenhuma - Master/Replica permanece igual |
| **TLS** | ✅ Mantido | Mudança no ClusterIssuer |
| **Storage** | ⚠️ Mudado | Atualizar storageClass |
| **Acesso Externo** | ✅ Melhorado | ServiceLB + NodePort |
| **Cert-Manager** | ✅ Mantido | Usar local-ca global |

## Mudanças Detalhadas

### 1. StorageClass

**Antes (MicroK8s):**
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    storageClassName: microk8s-hostpath  # ❌ Não existe no K3s
```

**Depois (K3s):**
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    storageClassName: local-path  # ✅ Default do K3s
```

**Impacto:**
- Dados existentes em PVCs do MicroK8s **não serão migrados** automaticamente
- Necessário backup e restore manual
- Volumes serão recriados no K3s

### 2. Acesso Externo

**Antes (MicroK8s):**
```yaml
# Apenas NodePort
apiVersion: v1
kind: Service
metadata:
  name: redis-master
spec:
  type: NodePort
  ports:
  - port: 6379
    nodePort: 30379
  - port: 6380
    nodePort: 30380
```

**Depois (K3s):**
```yaml
# Opção 1: LoadBalancer (ServiceLB) - RECOMENDADO
apiVersion: v1
kind: Service
metadata:
  name: redis-master-lb
spec:
  type: LoadBalancer  # ServiceLB do K3s
  ports:
  - port: 6379
  - port: 6380

# Opção 2: NodePort (fallback)
apiVersion: v1
kind: Service
metadata:
  name: redis-master-nodeport
spec:
  type: NodePort
  ports:
  - port: 6379
    nodePort: 30379
  - port: 6380
    nodePort: 30380
```

**Vantagens do ServiceLB:**
- EXTERNAL-IP automaticamente atribuído
- Portas padrão (6379, 6380) ao invés de portas altas (30379, 30380)
- Mais fácil de usar em aplicações cliente
- Compatível com cloud-like LoadBalancer

### 3. Certificados TLS

**Antes (MicroK8s):**
```yaml
# CA própria do Redis
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: redis-selfsigned-ca-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: redis-server-cert
spec:
  issuerRef:
    name: redis-ca-issuer  # Issuer específico do Redis
    kind: Issuer
```

**Depois (K3s):**
```yaml
# Usa CA global do cluster
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: redis-server-cert
spec:
  issuerRef:
    name: local-ca  # ClusterIssuer global
    kind: ClusterIssuer
```

**Vantagens:**
- Certificados gerenciados centralmente
- Mesma CA para todos os serviços do cluster
- Facilita integração entre serviços
- Menos recursos para manter

## Processo de Migração

### Passo 1: Backup dos Dados (CRÍTICO!)

```bash
# 1. Fazer snapshot RDB
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 SAVE

# 2. Copiar RDB do MicroK8s
kubectl cp redis/redis-master-0:/data/dump.rdb ./redis-backup-$(date +%Y%m%d).rdb

# 3. Backup AOF (se habilitado)
kubectl cp redis/redis-master-0:/data/appendonly.aof ./redis-backup-aof-$(date +%Y%m%d).aof

# 4. Exportar configurações
kubectl get secret -n redis redis-auth -o yaml > redis-secret-backup.yaml
kubectl get configmap -n redis redis-config -o yaml > redis-config-backup.yaml
```

### Passo 2: Desinstalar Redis do MicroK8s

```bash
# Anotar senha atual
kubectl get secret -n redis redis-auth -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d

# Deletar recursos
kubectl delete statefulset -n redis redis-master redis-replica
kubectl delete svc -n redis --all
kubectl delete pvc -n redis --all
kubectl delete namespace redis
```

### Passo 3: Preparar K3s

```bash
# 1. Verificar K3s está rodando
kubectl get nodes

# 2. Instalar cert-manager se necessário
cd ~/k8s/certs
./install-cert-manager.sh

# 3. Verificar local-ca ClusterIssuer
kubectl get clusterissuer local-ca
```

### Passo 4: Instalar Redis no K3s

```bash
cd ~/k8s/redis
./install-redis-k3s.sh
```

### Passo 5: Restore dos Dados

```bash
# 1. Aguardar todos os pods ficarem prontos
kubectl wait --for=condition=ready pod -l role=master -n redis --timeout=120s

# 2. Parar Redis temporariamente
kubectl scale statefulset -n redis redis-master --replicas=0
kubectl scale statefulset -n redis redis-replica --replicas=0

# 3. Copiar backup para o pod (quando subir)
kubectl scale statefulset -n redis redis-master --replicas=1
kubectl wait --for=condition=ready pod redis-master-0 -n redis --timeout=60s

# 4. Parar Redis (processo)
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 SHUTDOWN NOSAVE

# 5. Copiar dados
kubectl cp ./redis-backup-20251211.rdb redis/redis-master-0:/data/dump.rdb

# 6. Reiniciar pod
kubectl delete pod -n redis redis-master-0

# 7. Aguardar subir
kubectl wait --for=condition=ready pod redis-master-0 -n redis --timeout=60s

# 8. Verificar dados
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 GET <key-de-teste>

# 9. Subir replicas
kubectl scale statefulset -n redis redis-replica --replicas=3
```

### Passo 6: Verificar Replicação

```bash
# Verificar info de replicação
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123 INFO replication

# Deve mostrar 3 slaves conectados
```

### Passo 7: Atualizar Aplicações Clientes

**Antes (MicroK8s NodePort):**
```yaml
# Aplicação conectava via NodePort
REDIS_HOST: "<NODE_IP>"
REDIS_PORT: "30379"
```

**Depois (K3s LoadBalancer):**
```yaml
# Opção 1: ServiceLB (RECOMENDADO)
REDIS_HOST: "<EXTERNAL_IP>"  # IP do ServiceLB
REDIS_PORT: "6379"

# Opção 2: DNS interno (melhor para apps no cluster)
REDIS_HOST: "redis-master.redis.svc.cluster.local"
REDIS_PORT: "6379"

# Opção 3: NodePort (fallback)
REDIS_HOST: "<NODE_IP>"
REDIS_PORT: "30379"
```

## Comparação de Conectividade

### MicroK8s

```bash
# Interno
redis-cli -h redis-master.redis.svc.cluster.local -p 6379 -a Admin@123 ping

# Externo (NodePort)
redis-cli -h <NODE_IP> -p 30379 -a Admin@123 ping
```

### K3s

```bash
# Interno (mesmo)
redis-cli -h redis-master.redis.svc.cluster.local -p 6379 -a Admin@123 ping

# Externo (LoadBalancer - NOVO!)
redis-cli -h <EXTERNAL_IP> -p 6379 -a Admin@123 ping

# Externo (NodePort - mantido)
redis-cli -h <NODE_IP> -p 30379 -a Admin@123 ping
```

## Troubleshooting da Migração

### Dados não aparecem após restore

```bash
# 1. Verificar arquivo foi copiado
kubectl exec -n redis redis-master-0 -- ls -lh /data/

# 2. Ver logs do Redis
kubectl logs -n redis redis-master-0 | grep -i "db loaded"

# 3. Verificar permissões
kubectl exec -n redis redis-master-0 -- ls -la /data/dump.rdb

# 4. Forçar load do RDB
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 DEBUG RELOAD
```

### Replicas não sincronizam

```bash
# 1. Ver status de replicação no master
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 INFO replication

# 2. Ver logs das replicas
kubectl logs -n redis redis-replica-0 | grep -i master

# 3. Verificar conectividade
kubectl exec -n redis redis-replica-0 -- redis-cli -h redis-master.redis.svc.cluster.local -p 6380 -a Admin@123 ping

# 4. Reiniciar replicas
kubectl rollout restart statefulset -n redis redis-replica
```

### LoadBalancer EXTERNAL-IP fica pending

```bash
# 1. Verificar ServiceLB está ativo
kubectl get pods -n kube-system | grep svclb

# 2. Ver eventos do service
kubectl describe svc -n redis redis-master-lb

# 3. Usar NodePort como alternativa
kubectl get svc -n redis redis-master-nodeport
```

### Certificados TLS não funcionam

```bash
# 1. Verificar certificate está ready
kubectl get certificate -n redis redis-server-cert

# 2. Ver detalhes
kubectl describe certificate -n redis redis-server-cert

# 3. Verificar secret foi criado
kubectl get secret -n redis redis-tls-secret

# 4. Ver cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager | grep redis
```

## Checklist de Migração

- [ ] Backup de dados (RDB e AOF)
- [ ] Backup de secrets e configmaps
- [ ] Anotar senha do Redis
- [ ] K3s instalado e funcionando
- [ ] cert-manager instalado
- [ ] ClusterIssuer local-ca configurado
- [ ] Desinstalar Redis do MicroK8s
- [ ] Instalar Redis no K3s
- [ ] Restore de dados
- [ ] Verificar replicação
- [ ] Testar conectividade interna
- [ ] Testar conectividade externa (LoadBalancer)
- [ ] Atualizar aplicações clientes
- [ ] Monitorar logs por 24h
- [ ] Backup do novo ambiente

## Rollback (Se Necessário)

Se algo der errado, você pode voltar para MicroK8s:

```bash
# 1. Instalar MicroK8s
sudo snap install microk8s --classic

# 2. Habilitar addons
microk8s enable dns storage

# 3. Reinstalar Redis com manifests antigos
kubectl apply -f 21-master-statefulset.yaml  # versão MicroK8s
kubectl apply -f 22-replica-statefulset.yaml  # versão MicroK8s

# 4. Restore backup
# (mesmo processo de restore descrito acima)
```

## Benefícios da Migração

✅ **Performance**: K3s usa menos recursos (~150MB vs ~500MB)
✅ **ServiceLB**: Acesso via LoadBalancer sem cloud provider
✅ **Certificados**: Gerenciamento centralizado com local-ca
✅ **Simplicidade**: Menos componentes para manter
✅ **Traefik**: Ingress controller moderno built-in
✅ **Leveza**: Melhor para homelabs e edge computing

## Arquivos Criados para K3s

- `21-master-statefulset-k3s.yaml` - Master com local-path
- `22-replica-statefulset-k3s.yaml` - Replicas com local-path
- `13-master-svc-k3s.yaml` - Services com LoadBalancer
- `02-tls-certificates-k3s.yaml` - Certificados com local-ca
- `install-redis-k3s.sh` - Script de instalação
- `README-K3S.md` - Documentação K3s
- `MIGRATION-K3S.md` - Este guia

## Suporte

Para problemas durante a migração:

1. Verificar logs: `kubectl logs -n redis <pod-name>`
2. Ver eventos: `kubectl get events -n redis --sort-by='.lastTimestamp'`
3. Consultar documentação: `README-K3S.md`
4. Verificar troubleshooting: README-K3S.md seção "Troubleshooting"
