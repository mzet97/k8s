# Guia de Uso do Traefik no K3s

O K3s agora está instalado com o Traefik habilitado como Ingress Controller padrão. Este guia mostra como utilizá-lo em seu homelab.

## Verificando a Instalação do Traefik

Após instalar o K3s, verifique se o Traefik está rodando:

```bash
# Verificar pods do Traefik
kubectl get pods -n kube-system | grep traefik

# Verificar serviço do Traefik
kubectl get svc -n kube-system traefik

# Ver detalhes completos
kubectl describe svc -n kube-system traefik
```

Saída esperada:
```
NAME      TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
traefik   LoadBalancer   10.43.x.x       <node-ip>     80:xxxxx/TCP,443:xxxxx/TCP   1m
```

## Estrutura do Traefik no K3s

O Traefik é instalado com:
- **Namespace**: `kube-system`
- **Deployment**: `traefik`
- **Service**: `traefik` (tipo LoadBalancer via Klipper)
- **Portas**:
  - `80`: HTTP (NodePort dinâmico)
  - `443`: HTTPS (NodePort dinâmico)

## Usando Ingress com Traefik

### Opção 1: Ingress Padrão Kubernetes

Exemplo de Ingress usando a API padrão do Kubernetes:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: default
  annotations:
    # Especificar Traefik como IngressClass (opcional no K3s, é o padrão)
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: myapp.home.arpa
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80
```

Aplicar:
```bash
kubectl apply -f my-app-ingress.yaml
```

### Opção 2: IngressRoute (CRD do Traefik)

O Traefik fornece CRDs próprias com recursos avançados:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-ingressroute
  namespace: default
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`myapp.home.arpa`)
    kind: Rule
    services:
    - name: my-app-service
      port: 80
```

Com TLS:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-ingressroute-tls
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`myapp.home.arpa`)
    kind: Rule
    services:
    - name: my-app-service
      port: 80
  tls:
    secretName: my-app-tls-cert
```

## Middleware (Recursos Avançados)

O Traefik suporta middlewares para adicionar funcionalidades:

### Redirecionamento HTTP → HTTPS

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
  namespace: default
spec:
  redirectScheme:
    scheme: https
    permanent: true
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-http
  namespace: default
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`myapp.home.arpa`)
    kind: Rule
    services:
    - name: my-app-service
      port: 80
    middlewares:
    - name: redirect-https
```

### Basic Auth

```yaml
# Criar secret com credenciais (htpasswd format)
# htpasswd -nb admin mypassword
apiVersion: v1
kind: Secret
metadata:
  name: authsecret
  namespace: default
data:
  users: YWRtaW46JGFwcjEkSDY1dnFXajgkRmpGOG9iVWFSdkxCTEQ0TnZWMTVuMAo=
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: basic-auth
  namespace: default
spec:
  basicAuth:
    secret: authsecret
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app-protected
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`myapp.home.arpa`)
    kind: Rule
    services:
    - name: my-app-service
      port: 80
    middlewares:
    - name: basic-auth
  tls: {}
```

### Rate Limiting

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: default
spec:
  rateLimit:
    average: 100
    burst: 50
```

## Acessando o Dashboard do Traefik

O Traefik inclui um dashboard web. Para habilitá-lo:

### 1. Criar IngressRoute para o Dashboard

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: kube-system
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`traefik.local`)
    kind: Rule
    services:
    - name: api@internal
      kind: TraefikService
```

### 2. Adicionar ao /etc/hosts

```bash
# Obter o IP do node
kubectl get nodes -o wide

# Adicionar ao /etc/hosts
echo "<NODE_IP> traefik.local" | sudo tee -a /etc/hosts
```

### 3. Acessar o Dashboard

Abrir no navegador: `http://traefik.local`

## Integrando com Cert-Manager

Para certificados TLS automáticos com Let's Encrypt:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: default
spec:
  secretName: myapp-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: myapp-secure
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`myapp.example.com`)
    kind: Rule
    services:
    - name: my-app-service
      port: 80
  tls:
    secretName: myapp-tls-cert
```

## Adaptando Aplicações Existentes

Se você tem manifestos usando NGINX Ingress, pode adaptá-los para Traefik:

### NGINX Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: app.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

### Traefik Equivalente
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: default-strip-prefix@kubernetescrd
spec:
  rules:
  - host: app.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: strip-prefix
  namespace: default
spec:
  stripPrefix:
    prefixes:
      - /api
```

## Troubleshooting

### Verificar logs do Traefik

```bash
# Obter nome do pod
kubectl get pods -n kube-system | grep traefik

# Ver logs
kubectl logs -n kube-system <traefik-pod-name> -f
```

### Verificar configuração

```bash
# Ver todas as IngressRoutes
kubectl get ingressroute -A

# Ver todos os Middlewares
kubectl get middleware -A

# Descrever IngressRoute específica
kubectl describe ingressroute <name> -n <namespace>
```

### Ingress não funciona

1. Verificar se o serviço existe:
   ```bash
   kubectl get svc -n <namespace>
   ```

2. Verificar se o Ingress/IngressRoute foi criado:
   ```bash
   kubectl get ingress -A
   kubectl get ingressroute -A
   ```

3. Verificar eventos:
   ```bash
   kubectl get events -n <namespace>
   ```

## Recursos Adicionais

- [Documentação Oficial do Traefik](https://doc.traefik.io/traefik/)
- [Traefik no K3s](https://rancher.com/docs/k3s/latest/en/networking/#traefik-ingress-controller)
- [Exemplos de Middlewares](https://doc.traefik.io/traefik/middlewares/overview/)
- [IngressRoute CRD](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)

## Comparação: Quando usar NGINX vs Traefik

| Recurso | Traefik | NGINX Ingress |
|---------|---------|---------------|
| Configuração | CRDs nativas + Ingress | Ingress + Annotations |
| Dashboard | Sim (nativo) | Não |
| Auto-discovery | Sim | Sim |
| Middlewares | CRDs dedicadas | Annotations |
| Performance | Excelente | Excelente |
| Curva de aprendizado | Média | Baixa |
| Integração K3s | Nativa | Manual |

**Recomendação para homelab:** Use o Traefik que já vem com K3s para simplificar o setup. Só migre para NGINX se tiver requisitos específicos.
