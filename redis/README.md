# Redis Master-Replica no Kubernetes

## 📋 Visão Geral

Este projeto implementa uma solução completa de Redis Master-Replica para Kubernetes/MicroK8s com:

- ✅ **Alta Disponibilidade** - Master + 3 Réplicas
- ✅ **Segurança TLS** - Certificados automáticos
- ✅ **Monitoramento** - Métricas e logs centralizados
- ✅ **Backup Automático** - CronJobs configurados
- ✅ **DNS Simplificado** - Configuração `home.arpa`

## 🏛️ Arquitetura

A arquitetura é composta pelos seguintes componentes:

- **Master StatefulSet**: Garante que uma única instância do Redis Master esteja sempre em execução.
- **Replica StatefulSet**: Gerencia 3 réplicas do Redis, garantindo alta disponibilidade para leitura.
- **Services**:
  - `redis-master`: Expõe o Redis Master internamente no cluster e externamente via NodePort.
  - `redis-replica-headless`: Serviço headless para as réplicas, usado para descoberta.
  - `redis-client`: Ponto de entrada para clientes, balanceando a carga entre master e réplicas.
- **Certificados TLS**: Gerenciados automaticamente pelo `cert-manager` para garantir a comunicação segura.
- **ConfigMaps e Secrets**: Armazenam as configurações do Redis e as credenciais de autenticação.

## 🚀 Instalação

A instalação pode ser feita de forma automatizada ou manual.

### 🤖 Scripts de Automação (Recomendado)

```bash
# Instalação automática
./install-redis.sh

# Remoção automática
./remove-redis.sh
```

### Comandos de Instalação Manual

```bash
# 1. Criar namespace e configurações básicas
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-secret.yaml
kubectl apply -f 03-rbac.yaml

# 2. Configurar TLS e certificados
kubectl apply -f 02-tls-certificates.yaml

# 3. Configurar Redis (ConfigMaps e Services)
kubectl apply -f 10-configmap.yaml
kubectl apply -f 11-headless-svc.yaml
kubectl apply -f 12-client-svc.yaml
kubectl apply -f 13-master-svc.yaml

# 4. Implantar Redis Master e Réplicas
kubectl apply -f 21-master-statefulset.yaml
kubectl apply -f 22-replica-statefulset.yaml

# 5. Configurar acesso externo (NodePort)
# (O serviço redis-master já está configurado para NodePort)
```

## 🧪 Testes via Redis CLI

### Configuração de DNS

Adicione a seguinte entrada ao seu arquivo `/etc/hosts`:

```
<IP_DO_NÓ> redis.home.arpa
```

### Comandos de Teste

```bash
# Via NodePort direto (não-TLS)
redis-cli -h <IP_DO_NÓ> -p 30379 -a Admin@123 ping

# Via TLS direto
redis-cli -h redis.home.arpa -p 30380 --tls --insecure -a Admin@123 ping
```

## 📄 Licença

MIT License