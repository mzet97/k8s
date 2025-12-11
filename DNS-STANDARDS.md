# Padrões de DNS para o Homelab K3s

Este documento define os padrões de nomenclatura DNS para o cluster K3s.

## 🎯 Domínios Utilizados

### `.home.arpa` - Domínios Externos

**Uso**: Todos os serviços expostos externamente via Ingress/IngressRoute

**Padrão RFC 8375**: `.home.arpa` é o domínio recomendado pela IETF para redes domésticas.

**Exemplos:**
```
argocd.home.arpa
grafana.home.arpa
minio-console.home.arpa
minio-s3.home.arpa
prometheus.home.arpa
redis-stats.home.arpa
```

### `.local` - RESERVADO PARA ROTEADORES

⚠️ **NÃO USAR**: O domínio `.local` é reservado exclusivamente para os roteadores da rede.

**Motivo**: mDNS (Multicast DNS) usado por roteadores e dispositivos de rede local.

### `.svc.cluster.local` - DNS Interno do Kubernetes

**Uso**: Comunicação entre serviços dentro do cluster (gerenciado automaticamente pelo Kubernetes)

**Formato**: `<service>.<namespace>.svc.cluster.local`

**Exemplos:**
```
redis-master.redis.svc.cluster.local
minio.minio.svc.cluster.local
grafana.monitoring.svc.cluster.local
```

**Nota**: Estes FQDNs são gerados automaticamente pelo Kubernetes e não devem ser alterados.

## 📋 Convenções de Nomenclatura

### Serviços de Aplicação

| Tipo de Serviço | Padrão | Exemplo |
|-----------------|--------|---------|
| **UI/Console** | `<app>.home.arpa` | `grafana.home.arpa` |
| **API** | `<app>-api.home.arpa` | `redis-api.home.arpa` |
| **Console Dedicado** | `<app>-console.home.arpa` | `minio-console.home.arpa` |
| **S3/Storage** | `<app>-s3.home.arpa` | `minio-s3.home.arpa` |
| **Admin** | `<app>-admin.home.arpa` | `rabbitmq-admin.home.arpa` |

### Serviços de Infraestrutura

| Serviço | Domínio | Porta |
|---------|---------|-------|
| **Traefik Dashboard** | `traefik.home.arpa` | 80/443 |
| **ArgoCD** | `argocd.home.arpa` | 80/443 |
| **Grafana** | `grafana.home.arpa` | 80/443 |
| **Prometheus** | `prometheus.home.arpa` | 80/443 |
| **MinIO Console** | `minio-console.home.arpa` | 80/443 |
| **MinIO S3 API** | `minio-s3.home.arpa` | 80/443 |
| **K8s Dashboard** | `dashboard.home.arpa` | 80/443 |

### Serviços de Monitoramento

| Serviço | Domínio |
|---------|---------|
| **Grafana** | `grafana.home.arpa` |
| **Prometheus** | `prometheus.home.arpa` |
| **Alertmanager** | `alertmanager.home.arpa` |
| **Loki** | `loki.home.arpa` |
| **Jaeger** | `jaeger.home.arpa` |

## 🔧 Configuração

### 1. Adicionar ao /etc/hosts (Desenvolvimento)

Para acessar serviços localmente durante desenvolvimento:

```bash
# Obter IP do Traefik LoadBalancer
EXTERNAL_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Adicionar entradas ao /etc/hosts
cat <<EOF | sudo tee -a /etc/hosts
# Homelab K3s Services
$EXTERNAL_IP argocd.home.arpa
$EXTERNAL_IP grafana.home.arpa
$EXTERNAL_IP prometheus.home.arpa
$EXTERNAL_IP minio-console.home.arpa
$EXTERNAL_IP minio-s3.home.arpa
$EXTERNAL_IP traefik.home.arpa
$EXTERNAL_IP dashboard.home.arpa
EOF
```

### 2. DNS Server Local (Produção)

Configure seu DNS server (Pi-hole, dnsmasq, bind9, etc.) para resolver `*.home.arpa`:

#### Pi-hole

```bash
# /etc/dnsmasq.d/02-homelab.conf
address=/home.arpa/192.168.1.51
```

#### dnsmasq

```bash
# /etc/dnsmasq.conf
address=/home.arpa/192.168.1.51
```

#### CoreDNS (dentro do K3s)

```yaml
# Editar ConfigMap do CoreDNS
kubectl edit configmap -n kube-system coredns

# Adicionar:
home.arpa:53 {
    hosts {
        192.168.1.51 grafana.home.arpa
        192.168.1.51 prometheus.home.arpa
        192.168.1.51 argocd.home.arpa
        fallthrough
    }
}
```

### 3. Wildcard DNS (Recomendado)

Configure wildcard DNS no seu servidor DNS local:

```bash
# Todos os subdomínios *.home.arpa apontam para o Traefik
*.home.arpa → 192.168.1.51
```

## 📝 Template de Ingress/IngressRoute

### IngressRoute (Traefik)

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  entryPoints:
    - websecure
  routes:
  - match: Host(`<app-name>.home.arpa`)  # ✅ Usar .home.arpa
    kind: Rule
    services:
    - name: <service-name>
      port: <port>
  tls:
    secretName: <app-name>-tls
```

### Ingress (Padrão K8s)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <namespace>
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: local-ca
spec:
  tls:
  - hosts:
    - <app-name>.home.arpa  # ✅ Usar .home.arpa
    secretName: <app-name>-tls
  rules:
  - host: <app-name>.home.arpa  # ✅ Usar .home.arpa
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

## 🔒 Certificados TLS

### Cert-Manager Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: <app-name>-tls
  namespace: <namespace>
spec:
  secretName: <app-name>-tls
  issuerRef:
    name: local-ca
    kind: ClusterIssuer
  dnsNames:
  - <app-name>.home.arpa  # ✅ Usar .home.arpa
  - www.<app-name>.home.arpa  # Se necessário
```

## 🌍 Tabela de Domínios do Projeto

### Aplicações Principais

| Aplicação | Domínio | Service Interno | Porta |
|-----------|---------|-----------------|-------|
| ArgoCD | `argocd.home.arpa` | `argocd-server.argocd.svc.cluster.local` | 80/443 |
| Grafana | `grafana.home.arpa` | `grafana.monitoring.svc.cluster.local` | 3000 |
| Prometheus | `prometheus.home.arpa` | `prometheus.monitoring.svc.cluster.local` | 9090 |
| MinIO Console | `minio-console.home.arpa` | `minio-console.minio.svc.cluster.local` | 9001 |
| MinIO S3 | `minio-s3.home.arpa` | `minio.minio.svc.cluster.local` | 9000 |
| Redis Master | N/A (LoadBalancer) | `redis-master.redis.svc.cluster.local` | 6379/6380 |
| RabbitMQ | `rabbitmq.home.arpa` | `rabbitmq.rabbitmq.svc.cluster.local` | 5672/15672 |

### Dashboards e Ferramentas

| Ferramenta | Domínio | Descrição |
|------------|---------|-----------|
| Traefik Dashboard | `traefik.home.arpa` | Dashboard do Traefik |
| K8s Dashboard | `dashboard.home.arpa` | Kubernetes Dashboard |
| Alertmanager | `alertmanager.home.arpa` | Gerenciamento de alertas |
| Loki | `loki.home.arpa` | Agregação de logs |

## ❌ O Que NÃO Fazer

```yaml
# ❌ ERRADO - Não usar .local
dnsNames:
  - myapp.local

# ❌ ERRADO - Não usar domínios públicos que você não possui
dnsNames:
  - myapp.com
  - myapp.example.com

# ❌ ERRADO - Não misturar padrões
dnsNames:
  - myapp.home.arpa
  - myapp.local  # Inconsistente!

# ✅ CORRETO - Usar .home.arpa consistentemente
dnsNames:
  - myapp.home.arpa
  - api.myapp.home.arpa
  - admin.myapp.home.arpa
```

## 🔍 Verificação e Teste

### Testar Resolução DNS

```bash
# Via /etc/hosts
ping grafana.home.arpa

# Via DNS server
nslookup grafana.home.arpa
dig grafana.home.arpa

# Via kubectl (interno)
kubectl run -it dns-test --image=busybox --rm -- nslookup redis-master.redis.svc.cluster.local
```

### Testar Acesso HTTP/HTTPS

```bash
# HTTP (deve redirecionar para HTTPS)
curl -I http://grafana.home.arpa

# HTTPS
curl -k https://grafana.home.arpa

# Com certificado confiável (após importar CA)
curl https://grafana.home.arpa
```

## 📚 Referências

- [RFC 8375 - Special-Use Domain 'home.arpa'](https://www.rfc-editor.org/rfc/rfc8375.html)
- [Kubernetes DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Traefik Routing](https://doc.traefik.io/traefik/routing/routers/)
- [cert-manager Documentation](https://cert-manager.io/docs/)

## 🔄 Migração de .local para .home.arpa

Se você tem configurações antigas usando `.local`:

```bash
# Buscar todos os arquivos com .local
grep -r "\.local" . --include="*.yaml" | grep -v "svc.cluster.local"

# Substituir em massa (CUIDADO!)
find . -name "*.yaml" -type f -exec sed -i 's/myapp\.local/myapp.home.arpa/g' {} \;
```

⚠️ **IMPORTANTE**: Sempre faça backup antes de substituir em massa!

## 📝 Checklist para Novos Serviços

Ao adicionar um novo serviço:

- [ ] Escolher nome de domínio seguindo padrão `<app>.home.arpa`
- [ ] Criar Certificate com dnsNames usando `.home.arpa`
- [ ] Criar IngressRoute/Ingress com Host `<app>.home.arpa`
- [ ] Adicionar entrada ao DNS server ou /etc/hosts
- [ ] Testar resolução DNS
- [ ] Testar acesso HTTP e HTTPS
- [ ] Documentar na tabela de domínios acima

---

**Mantido por**: SRE Team
**Última atualização**: 2025-12-11
