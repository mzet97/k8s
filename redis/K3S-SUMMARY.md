# Redis no K3s - Resumo Executivo

## 🎯 O Que Foi Feito

Adaptei a configuração Redis Master-Replica para funcionar perfeitamente no K3s com Traefik e ServiceLB.

## 📊 Arquitetura

```
┌─────────────────────────────────────────────────┐
│              Redis Cluster (K3s)                 │
│                                                  │
│  ┌──────────────┐      ┌──────────────┐        │
│  │ Master       │◄─────┤ Replica 0    │        │
│  │  TLS: 6380   │      │  TLS: 6380   │        │
│  │      6379    │      │      6379    │        │
│  └──────────────┘      └──────────────┘        │
│         │                                        │
│         ├──────────────► Replica 1              │
│         └──────────────► Replica 2              │
│                                                  │
│  External Access (ServiceLB):                   │
│    192.168.1.51:6379 (non-TLS)                 │
│    192.168.1.51:6380 (TLS)                     │
└─────────────────────────────────────────────────┘
```

## 🚀 Instalação Rápida

```bash
cd ~/k8s/redis
./install-redis-k3s.sh
```

## ✅ Principais Mudanças

| Item | MicroK8s | K3s |
|------|----------|-----|
| **Storage** | microk8s-hostpath | ✅ local-path |
| **Acesso** | NodePort apenas | ✅ LoadBalancer + NodePort |
| **TLS** | CA própria | ✅ local-ca (global) |
| **IP Externo** | N/A | ✅ 192.168.1.51 (ServiceLB) |

## 📁 Arquivos Novos (K3s)

```
redis/
├── 21-master-statefulset-k3s.yaml    ← storageClass: local-path
├── 22-replica-statefulset-k3s.yaml   ← storageClass: local-path
├── 13-master-svc-k3s.yaml            ← ServiceLB + NodePort
├── 02-tls-certificates-k3s.yaml      ← Usa local-ca
├── install-redis-k3s.sh              ← Script automático
├── README-K3S.md                     ← Documentação completa
├── MIGRATION-K3S.md                  ← Guia de migração
└── K3S-SUMMARY.md                    ← Este arquivo
```

## 🔌 Como Conectar

### Interno (Apps no cluster)
```bash
redis-master.redis.svc.cluster.local:6379
```

### Externo (LoadBalancer - RECOMENDADO)
```bash
192.168.1.51:6379  # Seu IP pode variar
```

### Externo (NodePort - Fallback)
```bash
<NODE_IP>:30379
```

### Senha
```
Admin@123
```

## 🧪 Teste Rápido

```bash
# Interno
kubectl run test --rm -it --image=redis:7-alpine -- redis-cli -h redis-master.redis.svc.cluster.local -p 6379 -a Admin@123 ping

# Externo
EXTERNAL_IP=$(kubectl get svc -n redis redis-master-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
redis-cli -h $EXTERNAL_IP -p 6379 -a Admin@123 ping
```

## 📊 Status

```bash
# Verificar pods
kubectl get pods -n redis

# Verificar services
kubectl get svc -n redis

# Ver EXTERNAL-IP do LoadBalancer
kubectl get svc -n redis redis-master-lb
```

## 🔍 Componentes

### Services Criados

| Service | Type | Porta | Uso |
|---------|------|-------|-----|
| redis-master | ClusterIP | 6379, 6380 | Acesso interno |
| redis-master-lb | **LoadBalancer** | 6379, 6380 | **Acesso externo (ServiceLB)** |
| redis-master-nodeport | NodePort | 30379, 30380 | Fallback |
| redis-replica-headless | ClusterIP (headless) | 6379, 6380 | Service discovery |

### Certificados TLS

```bash
kubectl get certificate -n redis
# NAME                READY   SECRET
# redis-server-cert   True    redis-tls-secret
```

Usa **local-ca** ClusterIssuer (mesmo CA do cert-manager global).

### Storage

- **StorageClass**: `local-path` (default K3s)
- **Volume por pod**: 20Gi
- **Total**: ~80Gi (1 master + 3 replicas)

## 💡 Principais Benefícios

1. ✅ **ServiceLB**: Acesso via LoadBalancer sem cloud provider
2. ✅ **Porta padrão**: 6379/6380 ao invés de 30379/30380
3. ✅ **CA central**: Mesmos certificados que outras apps
4. ✅ **Mais leve**: K3s usa menos memória que MicroK8s
5. ✅ **Simplicidade**: Script de instalação automática

## 🛠️ Comandos Úteis

```bash
# Logs do master
kubectl logs -n redis redis-master-0 -f

# Status de replicação
kubectl exec -n redis redis-master-0 -- redis-cli -a Admin@123 INFO replication

# Conectar ao master
kubectl exec -it -n redis redis-master-0 -- redis-cli -a Admin@123

# Verificar TLS
kubectl get secret -n redis redis-tls-secret

# Escalar replicas
kubectl scale statefulset -n redis redis-replica --replicas=5
```

## 📚 Documentação Completa

- **README-K3S.md**: Guia completo de uso e troubleshooting
- **MIGRATION-K3S.md**: Como migrar de MicroK8s
- **README.md**: Documentação original

## ⚠️ Importante

- **Senha padrão**: `Admin@123` (altere em produção!)
- **Backup**: Sempre faça backup antes de qualquer mudança
- **PVCs**: Dados não são migrados automaticamente
- **Cert-manager**: Necessário antes da instalação

## 🎯 Próximos Passos

1. Instalar Redis:
   ```bash
   cd ~/k8s/redis
   ./install-redis-k3s.sh
   ```

2. Testar conectividade

3. Configurar aplicações para usar o Redis

4. (Opcional) Configurar backup automático

5. (Opcional) Integrar com Prometheus para monitoramento

## 🔗 Integração com Outros Serviços

### MinIO
```yaml
# MinIO pode usar Redis para cache
MINIO_CACHE_REDIS_ENDPOINT: "redis-master.redis.svc.cluster.local:6379"
```

### Aplicações no Cluster
```yaml
env:
- name: REDIS_HOST
  value: "redis-master.redis.svc.cluster.local"
- name: REDIS_PORT
  value: "6379"
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: redis-auth
      namespace: redis
      key: REDIS_PASSWORD
```

### Aplicações Externas
```yaml
REDIS_HOST: "192.168.1.51"  # EXTERNAL-IP do ServiceLB
REDIS_PORT: "6379"
REDIS_PASSWORD: "Admin@123"
```

## ✅ Checklist de Instalação

- [x] K3s instalado
- [x] cert-manager instalado
- [x] ClusterIssuer local-ca disponível
- [ ] Executar `./install-redis-k3s.sh`
- [ ] Verificar pods estão Running
- [ ] Verificar certificate está Ready
- [ ] Testar conectividade interna
- [ ] Testar conectividade externa
- [ ] Configurar aplicações clientes

## 🆘 Problemas Comuns

### Pods não ficam prontos
```bash
kubectl describe pod -n redis redis-master-0
kubectl logs -n redis redis-master-0
```

### LoadBalancer sem IP
```bash
kubectl get pods -n kube-system | grep svclb
# Use NodePort como fallback
```

### TLS não funciona
```bash
kubectl get certificate -n redis
kubectl describe certificate -n redis redis-server-cert
```

## 📞 Suporte

1. Verificar **README-K3S.md** seção "Troubleshooting"
2. Ver logs: `kubectl logs -n redis <pod-name>`
3. Ver eventos: `kubectl get events -n redis`
4. Consultar documentação do Redis: https://redis.io/docs/

---

**Criado para K3s** com Traefik, ServiceLB e cert-manager
