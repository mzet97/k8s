# Coder via Helm + Ingress + cert-manager

## Pré-requisitos (MicroK8s)
```bash
microk8s status --wait-ready
microk8s enable dns ingress cert-manager
# Se quiser IP de LB p/ outros serviços:
# microk8s enable metallb:10.0.0.240-10.0.0.250