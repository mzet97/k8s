# Gateway API - Descontinuado

## ⚠️ Arquivos Descontinuados

Os seguintes arquivos foram renomeados para `.deprecated`:

- `30-gateway-class.yaml.deprecated`
- `31-gateway.yaml.deprecated`
- `32-http-routes.yaml.deprecated`

## Motivo da Descontinuação

**CONFLITO DE CONFIGURAÇÃO**: O MinIO estava configurado com duas formas diferentes de Ingress:

1. **Ingress padrão Kubernetes** (arquivos 21, 22) - ✅ MANTIDO
2. **Gateway API (HTTPRoute)** (arquivos 30, 31, 32) - ❌ REMOVIDO

**Problema**: Ambas as configurações tentavam gerenciar as mesmas rotas, causando:
- Comportamento imprevisível
- Potenciais conflitos de roteamento
- Complexidade desnecessária

## Solução Adotada

**Usar Ingress padrão do Kubernetes com Traefik**

### Arquivos Ativos:
- `21-minio-console-ingress.yaml` - Console MinIO
- `22-minio-s3-ingress.yaml` - S3 API

### Domínios Configurados:
- **Console**: `minio-console.home.arpa`
- **S3 API**: `minio-s3.home.arpa`

## Gateway API vs Ingress

### Por que escolhemos Ingress?

| Aspecto | Ingress | Gateway API |
|---------|---------|-------------|
| **Maturidade** | GA (estável) | Beta |
| **Complexidade** | Simples | Complexa |
| **Suporte K3s** | Nativo | Requer instalação |
| **Traefik** | Suporte completo | Suporte experimental |
| **Homelab** | ✅ Ideal | Overkill |

### Quando usar Gateway API?

Gateway API é recomendado para:
- Ambientes multi-tenant complexos
- Roteamento avançado entre múltiplos clusters
- Casos de uso específicos de Service Mesh
- Ambientes de produção enterprise

Para homelab e ambientes simples, **Ingress padrão é suficiente e mais estável**.

## Migração

Se você já aplicou os arquivos de Gateway API:

```bash
# Deletar recursos de Gateway API
kubectl delete httproute minio-api-route -n minio
kubectl delete httproute minio-console-route -n minio
kubectl delete gateway minio-gateway -n minio
kubectl delete gatewayclass minio-gateway-class

# Aplicar Ingress
kubectl apply -f 21-minio-console-ingress.yaml
kubectl apply -f 22-minio-s3-ingress.yaml
```

## Referências

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Traefik Ingress](https://doc.traefik.io/traefik/routing/providers/kubernetes-ingress/)
- [Gateway API Docs](https://gateway-api.sigs.k8s.io/)

---

**Data da mudança**: 2025-12-11
**Motivo**: Simplificação e remoção de conflitos
