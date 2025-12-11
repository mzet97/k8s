# Cert-Manager - Gerenciamento de Certificados TLS

Este diretório contém a configuração do cert-manager para gerenciar certificados TLS no cluster K3s.

## Instalação Rápida

```bash
cd ~/k8s/certs
./install-cert-manager.sh
```

O script irá:
1. Instalar CRDs do cert-manager
2. Instalar cert-manager (controller, webhook, cainjector)
3. Aguardar todos os componentes ficarem prontos
4. Aplicar ClusterIssuers para desenvolvimento local
5. Verificar a instalação

## ClusterIssuers Disponíveis

### 1. selfsigned-root
Issuer raiz auto-assinado para criar uma CA local.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-root
spec:
  selfSigned: {}
```

### 2. local-ca
ClusterIssuer que usa a CA local para emitir certificados confiáveis no cluster.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: local-ca
spec:
  ca:
    secretName: local-root-ca
```

**Uso recomendado para**: Desenvolvimento local, homelab

## Como Criar Certificados

### Método 1: Usando Certificate Resource

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: default
spec:
  secretName: my-app-tls-secret
  issuerRef:
    name: local-ca
    kind: ClusterIssuer
  dnsNames:
  - myapp.home.arpa
  - www.myapp.home.arpa
```

Aplicar:
```bash
kubectl apply -f my-app-certificate.yaml
```

### Método 2: Usando Annotations no Ingress

#### Com Ingress Padrão (Traefik)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: local-ca
spec:
  tls:
  - hosts:
    - myapp.home.arpa
    secretName: my-app-tls-secret
  rules:
  - host: myapp.home.arpa
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

O cert-manager irá automaticamente criar um Certificate e Secret com o certificado TLS.

#### Com IngressRoute (Traefik CRD)

Para IngressRoute, você precisa criar o Certificate manualmente (Método 1) e referenciá-lo:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: default
spec:
  secretName: myapp-tls-secret
  issuerRef:
    name: local-ca
    kind: ClusterIssuer
  dnsNames:
  - myapp.home.arpa
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`myapp.home.arpa`)
    kind: Rule
    services:
    - name: my-app
      port: 80
  tls:
    secretName: myapp-tls-secret
```

## Verificando Certificados

### Listar Certificados

```bash
# Todos os namespaces
kubectl get certificate -A

# Namespace específico
kubectl get certificate -n default
```

### Ver Detalhes do Certificado

```bash
kubectl describe certificate my-app-tls -n default
```

### Ver Secret do Certificado

```bash
kubectl get secret my-app-tls-secret -n default -o yaml
```

### Ver Logs do cert-manager

```bash
# Controller
kubectl logs -n cert-manager -l app=cert-manager -f

# Webhook
kubectl logs -n cert-manager -l app=webhook -f

# CA Injector
kubectl logs -n cert-manager -l app=cainjector -f
```

## Configuração para Let's Encrypt (Produção)

Para usar Let's Encrypt em produção (requer domínio público e IP acessível):

### Staging (Testes)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: seu-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: traefik
```

### Production

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: seu-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
```

**Importante**: Use staging para testes primeiro, pois Let's Encrypt tem rate limits!

## Exemplos de Uso

### MinIO com TLS

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio-tls
  namespace: minio
spec:
  secretName: minio-tls-secret
  issuerRef:
    name: local-ca
    kind: ClusterIssuer
  dnsNames:
  - minio.home.arpa
  - minio-console.home.arpa
  - s3.minio.home.arpa
```

### ArgoCD com TLS

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls
  namespace: argocd
spec:
  secretName: argocd-server-tls
  issuerRef:
    name: local-ca
    kind: ClusterIssuer
  dnsNames:
  - argocd.home.arpa
```

### Grafana com TLS

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: grafana-tls
  namespace: monitoring
spec:
  secretName: grafana-tls-secret
  issuerRef:
    name: local-ca
    kind: ClusterIssuer
  dnsNames:
  - grafana.home.arpa
```

## Troubleshooting

### Certificate em estado "False" ou "Pending"

```bash
# Ver detalhes
kubectl describe certificate <name> -n <namespace>

# Ver CertificateRequest
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>

# Ver Order (para ACME/Let's Encrypt)
kubectl get order -n <namespace>
kubectl describe order <name> -n <namespace>

# Ver Challenge (para ACME/Let's Encrypt)
kubectl get challenge -n <namespace>
kubectl describe challenge <name> -n <namespace>
```

### Certificado não renova automaticamente

Cert-manager renova certificados automaticamente quando faltam 2/3 do tempo de validade.

```bash
# Forçar renovação
kubectl delete certificaterequest -n <namespace> -l cert-manager.io/certificate-name=<cert-name>
```

### ClusterIssuer não está "Ready"

```bash
kubectl describe clusterissuer <name>

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100
```

### Secret não foi criado

Verifique:
1. Certificate está em estado "Ready"
2. Namespace do secret existe
3. Permissões corretas

```bash
kubectl get certificate <name> -n <namespace> -o yaml
```

## Comandos Úteis

```bash
# Status geral do cert-manager
kubectl get pods -n cert-manager
kubectl get clusterissuer
kubectl get certificate -A

# Ver recursos do cert-manager
kubectl api-resources | grep cert-manager

# Deletar e recriar certificado
kubectl delete certificate <name> -n <namespace>
kubectl apply -f <certificate-file>.yaml

# Ver eventos
kubectl get events -n cert-manager --sort-by='.lastTimestamp'
kubectl get events -n <app-namespace> --sort-by='.lastTimestamp'
```

## Desinstalação

Para remover o cert-manager:

```bash
# Deletar recursos
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml

# Deletar CRDs (CUIDADO: remove todos os certificados!)
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.crds.yaml

# Deletar namespace
kubectl delete namespace cert-manager
```

## Referências

- [Documentação Oficial](https://cert-manager.io/docs/)
- [Tutorials](https://cert-manager.io/docs/tutorials/)
- [Troubleshooting](https://cert-manager.io/docs/troubleshooting/)
- [Integração com Traefik](https://doc.traefik.io/traefik/https/acme/)

## Arquivos

- `install-cert-manager.sh` - Script de instalação automatizado
- `00-cert-manager-issuers.yaml` - ClusterIssuers para desenvolvimento local
- `README.md` - Este arquivo
