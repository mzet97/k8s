# Guia Manual para Corrigir Problemas dos Pods redis-proxy

## Problema Identificado
Os pods `redis-proxy-79bcc9c695-g6xnj` e `redis-proxy-79bcc9c695-p946k` estão em estado de **Error**.

## Causa Principal
O deployment do HAProxy está tentando montar um secret chamado `redis-tls-secret`, mas o job de geração de certificados cria um secret chamado `redis-proxy-tls`.

## Correção Já Aplicada
✅ **Arquivo corrigido**: `42-redis-proxy-tls.yaml`
- Linha 233: Alterado `secretName: redis-tls-secret` para `secretName: redis-proxy-tls`

## Passos para Resolver o Problema

### 1. Verificar o Estado Atual
```bash
# Verificar pods redis-proxy
kubectl get pods -n redis -l app=redis-proxy

# Verificar logs dos pods com erro
kubectl logs -n redis redis-proxy-79bcc9c695-g6xnj
kubectl logs -n redis redis-proxy-79bcc9c695-p946k
```

### 2. Verificar se o Secret Existe
```bash
# Verificar se o secret redis-proxy-tls existe
kubectl get secret redis-proxy-tls -n redis

# Se não existir, verificar se o job foi executado
kubectl get jobs -n redis
kubectl describe job redis-proxy-cert-generator -n redis
```

### 3. Aplicar a Correção
```bash
# Aplicar o manifesto corrigido
kubectl apply -f 42-redis-proxy-tls.yaml

# Aguardar o job de geração de certificados
kubectl wait --for=condition=complete job/redis-proxy-cert-generator -n redis --timeout=120s

# Verificar se o secret foi criado
kubectl get secret redis-proxy-tls -n redis
```

### 4. Reiniciar o Deployment
```bash
# Reiniciar o deployment para aplicar as correções
kubectl rollout restart deployment/redis-proxy -n redis

# Aguardar o rollout
kubectl rollout status deployment/redis-proxy -n redis --timeout=120s

# Verificar o status final
kubectl get pods -n redis -l app=redis-proxy
```

### 5. Verificar Conectividade
```bash
# Aguardar pods estarem prontos
kubectl wait --for=condition=ready pod -l app=redis-proxy -n redis --timeout=60s

# Obter IP do nó
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "IP do nó: $NODE_IP"

# Testar conexões (se redis-cli estiver disponível)
redis-cli -h $NODE_IP -p 30379 -a "Admin@123" ping  # Sem TLS
redis-cli -h $NODE_IP -p 30380 --tls --insecure -a "Admin@123" ping  # Com TLS

# Verificar dashboard HAProxy
curl http://$NODE_IP:30404/stats
```

## Diagnóstico Adicional

### Se os Pods Continuarem com Erro
```bash
# Verificar eventos do namespace
kubectl get events -n redis --sort-by='.lastTimestamp'

# Verificar describe dos pods
kubectl describe pods -n redis -l app=redis-proxy

# Verificar se o Redis Master está funcionando
kubectl get pods -n redis -l app=redis-master
kubectl exec -n redis redis-master-0 -- redis-cli --tls \
    --cert /tls/tls.crt \
    --key /tls/tls.key \
    --cacert /tls/ca.crt \
    -h redis-master.redis.svc.cluster.local -p 6380 \
    -a "Admin@123" ping
```

### Se o Job de Certificados Falhar
```bash
# Verificar logs do job
kubectl logs -n redis job/redis-proxy-cert-generator

# Deletar e recriar o job
kubectl delete job redis-proxy-cert-generator -n redis
kubectl apply -f 42-redis-proxy-tls.yaml
```

## Portas de Acesso
Após a correção, o Redis estará disponível em:
- **Redis sem TLS**: `NODE_IP:30379`
- **Redis com TLS**: `NODE_IP:30380`
- **Dashboard HAProxy**: `NODE_IP:30404` (admin/admin123)
- **Redis leitura sem TLS**: `NODE_IP:30381`
- **Redis leitura com TLS**: `NODE_IP:30382`

## Monitoramento Contínuo
```bash
# Monitorar pods em tempo real
kubectl get pods -n redis -l app=redis-proxy -w

# Monitorar logs em tempo real
kubectl logs -n redis -l app=redis-proxy -f
```

## Notas Importantes
1. ✅ A correção principal já foi aplicada no arquivo `42-redis-proxy-tls.yaml`
2. ⚠️ Certifique-se de que o kubectl está configurado corretamente
3. 🔧 O script `fix-redis-proxy.sh` pode ser usado se kubectl estiver disponível
4. 📋 Use este guia manual se houver problemas de conectividade com o cluster