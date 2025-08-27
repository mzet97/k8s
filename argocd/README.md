# Argo CD (MicroK8s, single node) — Ingress + local CA

Bundle para instalar **Argo CD** no MicroK8s com:
- Ingress `public` (NGINX do MicroK8s)
- TLS via **cert-manager** (`ClusterIssuer local-ca`)
- Hostname: **argocd.home.arpa** (ajuste conforme seu hosts)

> **Pré-requisitos** no cluster:
> ```bash
> microk8s enable ingress
> microk8s enable cert-manager
> ```

## Deploy (passo-a-passo)

```bash
# 1) Namespace
kubectl apply -f argocd/00-namespace.yaml

# 2) Instalação Argo CD (kustomize remoto oficial)
#    (pode demorar alguns segundos para baixar)
kubectl apply -k argocd/

# 3) Ajustar URL externa e criar Ingress + Certificate
kubectl apply -f argocd/10-argocd-cm-url.yaml
kubectl apply -f argocd/20-argocd-ingress.yaml
kubectl apply -f argocd/21-argocd-certificate.yaml

# 4) Acompanhe os pods
kubectl -n argocd get pods -w

# 5) Descobrir senha inicial (usuario: admin)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```
**Importante:** No primeiro login, troque a senha do `admin` pela GUI.

## Acesso pelo navegador
1. No seu PC (Windows), adicione no `hosts` (admin):
   ```
   192.168.0.51  argocd.home.arpa
   ```
2. Acesse: **https://argocd.home.arpa**

## CLI opcional
- Via Ingress (pode precisar `--grpc-web` dependendo do cliente):  
  ```bash
  argocd login argocd.home.arpa --username admin --password <sua-senha> --grpc-web --insecure
  ```
- Ou via port-forward (sempre funciona):
  ```bash
  kubectl -n argocd port-forward svc/argocd-server 8080:80
  argocd login localhost:8080 --username admin --password <senha> --insecure
  ```

## Notas
- O Ingress aponta para o **svc/argocd-server porta 80** (HTTP interno), enquanto a borda TLS fica no Ingress com o certificado da **local-ca**.
- O `argocd-cm` define `url: https://argocd.home.arpa` para que a UI/links externos fiquem corretos.
- Se quiser mudar o host, edite: `20-argocd-ingress.yaml`, `21-argocd-certificate.yaml` e `10-argocd-cm-url.yaml`.
