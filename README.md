# MicroK8s Home ARPA Ingress Bundle

This repo contains a reproducible setup for:
- Local CA via cert-manager
- Dashboard at `https://dashboard.home.arpa`
- MinIO Console at `https://minio.home.arpa`
- MinIO S3 API at `https://s3.home.arpa`

> **Pre-reqs** (on MicroK8s cluster):
> ```bash
> microk8s enable ingress
> microk8s enable cert-manager
> microk8s enable storage
> ```

## Apply (order)

```bash
# 1) Cluster issuers (self-signed root CA + local-ca)
kubectl apply -f certs/00-cert-manager-issuers.yaml

# 2) Dashboard (RBAC + Ingress + Certificate)
kubectl apply -f dashboard/10-dashboard-rbac.yaml
kubectl apply -f dashboard/11-dashboard-ingress.yaml
kubectl apply -f dashboard/12-dashboard-certificate.yaml

# 3) MinIO (Console Service + Ingress + Certificate + S3 Ingress+Cert)
kubectl apply -f minio/20-minio-console-svc.yaml
kubectl apply -f minio/21-minio-console-ingress.yaml
kubectl apply -f minio/23-minio-console-certificate.yaml

kubectl apply -f minio/22-minio-s3-ingress.yaml
kubectl apply -f minio/24-minio-s3-certificate.yaml
```

## Hostnames (on your client machine)
Add to your client OS hosts file (Windows needs admin):
```
192.168.0.51  dashboard.home.arpa minio.home.arpa s3.home.arpa
```

## Export CA to trust on clients
```bash
kubectl -n cert-manager get secret local-root-ca -o jsonpath='{.data.ca\.crt}' | base64 -d > local-root-ca.crt
# Import local-root-ca.crt into your OS trusted root (Windows: LocalMachine\Root)
```

## Notes
- Assumes MinIO tenant label is `v1.min.io/tenant: microk8s`. If your tenant name differs, update the selector in `minio/20-minio-console-svc.yaml`.
- All Ingress resources use `kubernetes.io/ingress.class: public` (MicroK8s default controller).
- Certificates are created explicitly (no need to rely on ingress-shim), via `ClusterIssuer local-ca`.
- The Dashboard backend is HTTPS inside the cluster, so the Dashboard Ingress sets `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"`.
- MinIO Console is exposed at 9090; S3 API is exposed separately at `s3.home.arpa` pointing to the `minio` service (port 80 → targetPort 9000).
- If you change hostnames, update both the Ingress hosts and the Certificate `dnsNames` accordingly.
