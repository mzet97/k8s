# NATS no K3s

Implementação do NATS Server com JetStream (persistência) no cluster K3s.

## Estrutura

- `00-namespace.yaml`: Namespace `nats`
- `01-secret.yaml`: Credenciais (referência)
- `02-config.yaml`: Arquivo de configuração `nats.conf`
- `03-pvc.yaml`: Volume persistente (5Gi) para dados do JetStream
- `10-service.yaml`: Services internos (Client, Monitor, Headless)
- `11-loadbalancer.yaml`: Service LoadBalancer para acesso externo TCP (4222)
- `20-statefulset.yaml`: StatefulSet do NATS
- `30-ingress.yaml`: Ingress Traefik para o Monitoramento (8222)
- `31-certificate.yaml`: Certificado TLS para o Monitoramento

## Instalação

Execute o script:

```bash
chmod +x install-nats-k3s.sh
./install-nats-k3s.sh
```

## Acesso

- **Protocolo NATS (TCP):** `nats.home.arpa:4222`
- **Monitoramento (HTTP):** `https://nats-monitor.home.arpa`
- **Usuário:** `admin`
- **Senha:** `Admin@123`

> **JetStream:** Habilitado e configurado para usar persistência em arquivo (`/data`).
