# n8n no K3s

Implementação do n8n (Workflow Automation Tool) no cluster K3s.

## Estrutura

- `00-namespace.yaml`: Namespace `n8n`
- `01-pvc.yaml`: Volume persistente (5Gi) para dados do n8n (SQLite, workflows, credenciais)
- `10-service.yaml`: Service ClusterIP
- `20-deployment.yaml`: Deployment do n8n
- `30-ingress.yaml`: Ingress Traefik
- `31-certificate.yaml`: Certificado TLS (self-signed via local-ca)

## Instalação

Execute o script:

```bash
chmod +x install-n8n-k3s.sh
./install-n8n-k3s.sh
```

## Acesso

- **URL:** `https://n8n.home.arpa`

> **Nota:** No primeiro acesso, você será solicitado a criar uma conta de administrador.
