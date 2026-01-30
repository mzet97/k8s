# Como Usar os Scripts de Instalação

## ⚠️ IMPORTANTE: não use sudo para rodar scripts

Todos os scripts de instalação devem ser executados como usuário `k8s1` **sem sudo**.
Use `sudo` apenas quando o passo envolver o sistema operacional (por exemplo: editar `/etc/hosts` ou ajustar permissões), e quando estiver explicitamente indicado.

---

## ❌ ERRADO

```bash
sudo ./install-redis-k3s.sh          # ❌ NÃO faça isso!
sudo ./install-cert-manager.sh        # ❌ NÃO faça isso!
sudo ./install-monitoring-k3s.sh      # ❌ NÃO faça isso!
```

**Por quê?**
- Quando você usa `sudo`, o script roda como `root`
- O `root` não tem acesso ao kubeconfig do K3s configurado para o usuário `k8s1`
- Resultado: erro `connection refused`

---

## ✅ CORRETO

```bash
./install-redis-k3s.sh               # ✅ Faça assim!
./install-cert-manager.sh            # ✅ Faça assim!
./install-monitoring-k3s.sh          # ✅ Faça assim!
```

---

## 📋 Ordem de Instalação Recomendada

### 1. Cert-Manager (obrigatório primeiro)

```bash
cd ~/k8s/certs
./install-cert-manager.sh
```

### 2. Data Stores

```bash
# Redis
cd ~/k8s/redis
./install-redis-k3s.sh

# RabbitMQ
cd ~/k8s/rabbitmq
./install-rabbitmq-k3s.sh

# MinIO
cd ~/k8s/minio
./install-minio-k3s.sh
```

### 3. Monitoring

```bash
cd ~/k8s/monitoring
./install-monitoring-k3s.sh
```

### 4. ELK Stack (opcional)

```bash
cd ~/k8s/ELK
./install-elk-k3s.sh
```

---

## 🔍 Verificar Status

### Redis

```bash
kubectl get pods -n redis
kubectl get pvc -n redis
kubectl get svc -n redis
```

### RabbitMQ

```bash
kubectl get pods -n rabbitmq
kubectl get pvc -n rabbitmq
kubectl get ingress -n rabbitmq
```

### MinIO

```bash
kubectl get pods -n minio
kubectl get pvc -n minio
kubectl get ingress -n minio
```

### Monitoring

```bash
kubectl get pods -n monitoring
kubectl get pvc -n monitoring
kubectl get ingress -n monitoring
```

### ELK

```bash
kubectl get pods -n elk
kubectl get pvc -n elk
kubectl get ingress -n elk
```

---

## 🔑 Ver Senhas

### Redis

```bash
kubectl get secret redis-auth -n redis -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d
echo
```

### RabbitMQ

```bash
kubectl get secret rabbitmq-admin -n rabbitmq -o jsonpath='{.data.password}' | base64 -d
echo
```

### MinIO

```bash
kubectl get secret minio-creds -n minio -o jsonpath='{.data.rootPassword}' | base64 -d
echo
```

### Grafana

```bash
kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d
echo
```

---

## 🌍 Configurar /etc/hosts

```bash
# Obter IP do Traefik
TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Adicionar domínios
echo "$TRAEFIK_IP rabbitmq-mgmt.home.arpa" | sudo tee -a /etc/hosts
echo "$TRAEFIK_IP minio-console.home.arpa" | sudo tee -a /etc/hosts
echo "$TRAEFIK_IP minio-s3.home.arpa" | sudo tee -a /etc/hosts
echo "$TRAEFIK_IP prometheus.home.arpa" | sudo tee -a /etc/hosts
echo "$TRAEFIK_IP grafana.home.arpa" | sudo tee -a /etc/hosts
echo "$TRAEFIK_IP elasticsearch.home.arpa" | sudo tee -a /etc/hosts
echo "$TRAEFIK_IP kibana.home.arpa" | sudo tee -a /etc/hosts
```

---

## 🚨 Troubleshooting

### Erro: "connection refused"

**Causa**: Você usou `sudo`
**Solução**: Execute o script SEM sudo

### Erro: "ClusterIssuer 'local-ca' not found"

**Causa**: cert-manager não está instalado
**Solução**:
```bash
cd ~/k8s/certs
./install-cert-manager.sh
```

### Erro: "permission denied"

**Causa**: Arquivos com permissões erradas
**Solução** (como root):
```bash
sudo chown -R k8s1:k8s1 /home/k8s1/k8s/
sudo chmod -R u+rw /home/k8s1/k8s/
```

### Pod fica em "Pending"

**Verificar PVC**:
```bash
kubectl get pvc -n <namespace>
```

**Verificar eventos**:
```bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

---

## 📚 Documentação

- **Revisão Completa**: `~/k8s/COMPLETE_REVISION_SUMMARY.md`
- **Data Stores**: `~/k8s/FIXES_SUMMARY.md`
- **Monitoring/ELK**: `~/k8s/MONITORING_ELK_FIXES_SUMMARY.md`
- **DNS Standards**: `~/k8s/DNS-STANDARDS.md`
- **Traefik Guide**: `~/k8s/k3s-setup/TRAEFIK_GUIDE.md`

---

**Última atualização**: 2026-01-30
