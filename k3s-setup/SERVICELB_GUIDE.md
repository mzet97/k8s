# ServiceLB (Klipper) - LoadBalancer para K3s

O ServiceLB (implementado pelo Klipper) é o balanceador de carga nativo do K3s para ambientes bare-metal. Ele permite usar serviços do tipo `LoadBalancer` sem precisar de um cloud provider.

## Status Atual

✅ **ServiceLB está ATIVO e FUNCIONANDO**

### Componentes Ativos

```
COMPONENTE                              STATUS      DESCRIÇÃO
svclb-traefik-a2e68ba7-mw4r9           Running     Pod do LoadBalancer
svclb-traefik-a2e68ba7 (DaemonSet)     1/1         DaemonSet gerenciando o LB
```

### Serviços LoadBalancer

```
NAMESPACE     SERVICE   TYPE           EXTERNAL-IP    PORTS
kube-system   traefik   LoadBalancer   192.168.1.51   80:31488/TCP, 443:32558/TCP
```

**EXTERNAL-IP**: `192.168.1.51` (IP do node `k8s1`)

## Como o ServiceLB Funciona

### Arquitetura

1. Quando você cria um Service tipo `LoadBalancer`
2. O ServiceLB cria automaticamente um **DaemonSet** chamado `svclb-<service-name>-<hash>`
3. Este DaemonSet cria um pod em **cada node** do cluster
4. Cada pod contém um container para **cada porta** do service
5. Os containers fazem proxy do tráfego do node para o ClusterIP do service

### Componentes do Pod ServiceLB

No exemplo do Traefik, o pod `svclb-traefik` tem 2 containers:

#### Container 1: lb-tcp-80
```yaml
Image: rancher/klipper-lb:v0.4.13
Host Port: 80
Environment:
  SRC_PORT: 80        # Porta no node
  DEST_PORT: 80       # Porta no ClusterIP
  DEST_IPS: 10.43.100.89  # ClusterIP do Traefik
```

#### Container 2: lb-tcp-443
```yaml
Image: rancher/klipper-lb:v0.4.13
Host Port: 443
Environment:
  SRC_PORT: 443
  DEST_PORT: 443
  DEST_IPS: 10.43.100.89
```

### Fluxo de Tráfego

```
Cliente (Browser)
    ↓
192.168.1.51:80 (Node IP - Host Port)
    ↓
svclb-traefik pod → lb-tcp-80 container
    ↓
10.43.100.89:80 (Traefik ClusterIP)
    ↓
Traefik Pod
    ↓
Aplicação Final
```

## Como Usar ServiceLB

### 1. Criar um Service LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
    name: http
  - port: 443
    targetPort: 8443
    name: https
```

### 2. Verificar o EXTERNAL-IP

```bash
kubectl get svc my-app

# Saída esperada:
# NAME     TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)
# my-app   LoadBalancer   10.43.x.x       192.168.1.51   80:xxxxx/TCP,443:xxxxx/TCP
```

O `EXTERNAL-IP` será o IP do seu node.

### 3. Verificar o Pod ServiceLB

```bash
# Listar pods ServiceLB
kubectl get pods -n kube-system | grep svclb

# Detalhar o pod
kubectl describe pod -n kube-system svclb-my-app-<hash>
```

### 4. Acessar o Serviço

Você pode acessar via:

**A) EXTERNAL-IP (IP do Node)**
```bash
curl http://192.168.1.51
```

**B) NodePort (se precisar de porta específica)**
```bash
curl http://192.168.1.51:31488
```

## Exemplos de Uso

### Exemplo 1: MinIO com LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: minio-lb
  namespace: minio
spec:
  type: LoadBalancer
  selector:
    app: minio
  ports:
  - port: 9000
    targetPort: 9000
    name: s3-api
  - port: 9001
    targetPort: 9001
    name: console
```

Depois de aplicar:
```bash
kubectl get svc -n minio minio-lb

# Acessar
# S3 API: http://192.168.1.51:9000
# Console: http://192.168.1.51:9001
```

### Exemplo 2: Aplicação Web Customizada

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: webapp-lb
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - port: 8080        # Porta externa
    targetPort: 80    # Porta do container
```

Acessar: `http://192.168.1.51:8080`

### Exemplo 3: Banco de Dados (PostgreSQL)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-lb
  namespace: database
spec:
  type: LoadBalancer
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
```

Conectar: `psql -h 192.168.1.51 -p 5432 -U user -d database`

## Multi-Node (Cluster com Múltiplos Nodes)

Em um cluster multi-node, o ServiceLB cria um pod em **cada node**:

```bash
# Cluster com 3 nodes
kubectl get pods -n kube-system | grep svclb-my-app

# Saída:
# svclb-my-app-xxxxx-node1   2/2   Running
# svclb-my-app-xxxxx-node2   2/2   Running
# svclb-my-app-xxxxx-node3   2/2   Running
```

Cada node pode ser usado como EXTERNAL-IP:
- `192.168.1.51` (node1)
- `192.168.1.52` (node2)
- `192.168.1.53` (node3)

Você pode usar qualquer um dos IPs para acessar o serviço!

## Comandos Úteis

### Listar Serviços LoadBalancer

```bash
# Todos os namespaces
kubectl get svc -A --field-selector spec.type=LoadBalancer

# Namespace específico
kubectl get svc -n kube-system -o wide
```

### Verificar Pods ServiceLB

```bash
# Listar todos os pods ServiceLB
kubectl get pods -n kube-system -l svccontroller.k3s.cattle.io/svcnamespace

# Logs de um pod ServiceLB específico
kubectl logs -n kube-system svclb-<service>-<hash> -c lb-tcp-<port>
```

### Verificar DaemonSets

```bash
# Listar DaemonSets do ServiceLB
kubectl get daemonset -n kube-system | grep svclb

# Descrever DaemonSet
kubectl describe daemonset -n kube-system svclb-<service>-<hash>
```

### Debug

```bash
# Ver eventos do namespace
kubectl get events -n kube-system --sort-by='.lastTimestamp'

# Ver detalhes do service
kubectl describe svc -n <namespace> <service-name>

# Verificar se a porta está aberta no node
sudo netstat -tlnp | grep <port>
# ou
sudo ss -tlnp | grep <port>
```

## Diferenças: LoadBalancer vs NodePort vs ClusterIP

| Tipo         | EXTERNAL-IP | Acesso Externo | Use Case                    |
|--------------|-------------|----------------|-----------------------------|
| ClusterIP    | Nenhum      | ❌ Não         | Comunicação interna apenas  |
| NodePort     | Nenhum      | ✅ Sim (porta alta) | Desenvolvimento/teste  |
| LoadBalancer | IP do Node  | ✅ Sim (porta padrão) | Produção (com ServiceLB) |

## Limitações do ServiceLB

1. **IP do Node**: O EXTERNAL-IP é sempre o IP do node, não um IP dedicado
2. **Conflito de Portas**: Dois serviços não podem usar a mesma porta no mesmo node
3. **Sem Health Checks**: Não há health checks automáticos como em cloud providers
4. **Bare-Metal**: Funciona apenas em ambientes bare-metal/on-premise

## Alternativas ao ServiceLB

Se você precisar de funcionalidades mais avançadas:

### MetalLB
```bash
# Instalar MetalLB (alternativa ao ServiceLB)
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.0/config/manifests/metallb-native.yaml

# Configurar pool de IPs
# (Requer configuração adicional)
```

### HAProxy ou NGINX externo
- LoadBalancer externo ao cluster
- Distribui tráfego para NodePorts

## Troubleshooting

### EXTERNAL-IP fica em \<pending\>

```bash
# Verificar se ServiceLB está habilitado
kubectl get pods -n kube-system | grep svclb

# Se não houver pods svclb, o ServiceLB pode estar desabilitado
# Para verificar:
sudo cat /etc/systemd/system/k3s.service | grep disable
```

### Porta não acessível

```bash
# 1. Verificar se o pod ServiceLB está rodando
kubectl get pods -n kube-system | grep svclb

# 2. Verificar logs do container
kubectl logs -n kube-system svclb-<service>-<hash> -c lb-tcp-<port>

# 3. Verificar firewall
sudo ufw status
sudo iptables -L -n | grep <port>

# 4. Testar localmente no node
curl localhost:<port>
```

### Service não recebe tráfego

```bash
# 1. Verificar endpoints
kubectl get endpoints -n <namespace> <service-name>

# 2. Verificar se os pods estão running
kubectl get pods -n <namespace> -l <selector>

# 3. Testar conexão direta ao ClusterIP
kubectl run test --rm -it --image=curlimages/curl -- sh
curl http://<cluster-ip>:<port>
```

## Verificação de Status

Para verificar se o ServiceLB está funcionando corretamente:

```bash
#!/bin/bash

echo "=== ServiceLB Status Check ==="
echo ""

echo "1. Serviços LoadBalancer:"
kubectl get svc -A --field-selector spec.type=LoadBalancer
echo ""

echo "2. Pods ServiceLB:"
kubectl get pods -n kube-system | grep svclb
echo ""

echo "3. DaemonSets ServiceLB:"
kubectl get daemonset -n kube-system | grep svclb
echo ""

echo "4. Teste de conectividade (Traefik):"
EXTERNAL_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "EXTERNAL-IP: $EXTERNAL_IP"
curl -I http://$EXTERNAL_IP 2>/dev/null | head -1
```

## Referências

- [K3s ServiceLB Documentation](https://docs.k3s.io/networking#service-load-balancer)
- [Klipper LB GitHub](https://github.com/k3s-io/klipper-lb)
- [Kubernetes LoadBalancer Service](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)
