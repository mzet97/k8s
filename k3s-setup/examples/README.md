# Exemplos de Configuração com Traefik

Este diretório contém exemplos de como configurar suas aplicações usando o Traefik Ingress Controller que vem pré-instalado com o K3s.

## Arquivos de Exemplo

### `minio-traefik-ingress.yaml`
Configuração completa do MinIO com Traefik, incluindo:
- IngressRoute para Console e S3 API
- Redirecionamento HTTP → HTTPS
- Integração com cert-manager para TLS
- Exemplo usando Ingress padrão Kubernetes

### Como Usar os Exemplos

1. **Certifique-se que o namespace existe:**
   ```bash
   kubectl create namespace minio  # ou o namespace apropriado
   ```

2. **Aplique a configuração:**
   ```bash
   kubectl apply -f examples/minio-traefik-ingress.yaml
   ```

3. **Configure o /etc/hosts:**
   ```bash
   NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
   echo "$NODE_IP minio-console.local" | sudo tee -a /etc/hosts
   echo "$NODE_IP minio-s3.local" | sudo tee -a /etc/hosts
   ```

4. **Verifique a configuração:**
   ```bash
   kubectl get ingressroute -n minio
   kubectl get certificate -n minio
   ```

5. **Acesse no navegador:**
   - Console: `https://minio-console.local`
   - S3 API: `https://minio-s3.local`

## Adaptando para suas Aplicações

### Estrutura Básica de IngressRoute

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  entryPoints:
    - websecure  # HTTPS
  routes:
  - match: Host(`<hostname>`)
    kind: Rule
    services:
    - name: <service-name>
      port: <service-port>
  tls:
    secretName: <tls-secret>
```

### Com Middleware (exemplo: rate limiting)

```yaml
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: <namespace>
spec:
  rateLimit:
    average: 100
    burst: 50
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`<hostname>`)
    kind: Rule
    services:
    - name: <service-name>
      port: <service-port>
    middlewares:
    - name: rate-limit
  tls:
    secretName: <tls-secret>
```

## Aplicações do Projeto

### ArgoCD
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`argocd.home.arpa`)
    kind: Rule
    services:
    - name: argocd-server
      port: 80
  tls:
    secretName: argocd-tls
```

### Grafana
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`grafana.home.arpa`)
    kind: Rule
    services:
    - name: grafana
      port: 3000
  tls:
    secretName: grafana-tls
```

### Prometheus
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: prometheus
  namespace: monitoring
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`prometheus.home.arpa`)
    kind: Rule
    services:
    - name: prometheus
      port: 9090
  tls:
    secretName: prometheus-tls
```

## Usando Ingress Padrão (Alternativa Simples)

Se você preferir usar a API padrão de Ingress do Kubernetes:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <namespace>
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - <hostname>
    secretName: <tls-secret>
  rules:
  - host: <hostname>
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: <service-name>
            port:
              number: <port>
```

## Dicas

1. **Use IngressRoute para recursos avançados** do Traefik (middlewares, TCP routing, etc.)
2. **Use Ingress padrão para simplicidade** se você não precisa de recursos específicos do Traefik
3. **Sempre configure TLS** para ambientes de produção ou exposição externa
4. **Teste localmente** antes de aplicar em produção
5. **Monitore os logs** do Traefik para troubleshooting

## Troubleshooting

### Ingress não responde
```bash
# Verificar se o Traefik está rodando
kubectl get pods -n kube-system | grep traefik

# Ver logs do Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f

# Verificar se a IngressRoute foi criada
kubectl get ingressroute -A

# Verificar o serviço
kubectl get svc -n <namespace> <service-name>
```

### Certificado TLS não funciona
```bash
# Verificar certificados do cert-manager
kubectl get certificate -A

# Ver detalhes do certificado
kubectl describe certificate <cert-name> -n <namespace>

# Ver secret do TLS
kubectl get secret <tls-secret-name> -n <namespace>
```

### Porta não acessível
```bash
# Verificar NodePort do Traefik
kubectl get svc -n kube-system traefik

# Testar conectividade
curl -k https://<node-ip>:<https-nodeport> -H "Host: <hostname>"
```

## Recursos Adicionais

- [TRAEFIK_GUIDE.md](../TRAEFIK_GUIDE.md) - Guia completo do Traefik
- [Documentação Traefik](https://doc.traefik.io/traefik/)
- [K3s Networking](https://docs.k3s.io/networking)
