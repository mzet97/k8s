# Grafana + Prometheus (MicroK8s, single node)

Bundle pronto para subir **Grafana** e **Prometheus** no MicroK8s usando:
- Ingress `public` (MicroK8s)
- Certs via **cert-manager** com `ClusterIssuer local-ca`
- StorageClass **microk8s-hostpath**
- Node Exporter (DaemonSet) + kube-state-metrics (Deployment)
- Sem Prometheus Operator (config é via ConfigMap)

> **Pré-requisitos no cluster**
> ```bash
> microk8s enable ingress
> microk8s enable cert-manager
> microk8s enable storage   # microk8s-hostpath
> ```

## Aplicar (ordem sugerida)

```bash
kubectl apply -f monitoring/00-namespace.yaml
kubectl apply -f monitoring/01-grafana-admin-secret.yaml
kubectl apply -f monitoring/02-grafana-config-datasource.yaml
kubectl apply -f monitoring/10-prometheus-rbac.yaml
kubectl apply -f monitoring/11-prometheus-config.yaml
kubectl apply -f monitoring/12-prometheus-statefulset.yaml
kubectl apply -f monitoring/20-node-exporter-daemonset.yaml
kubectl apply -f monitoring/21-kube-state-metrics.yaml
kubectl apply -f monitoring/30-grafana-deployment.yaml
kubectl apply -f monitoring/31-grafana-ingress.yaml
kubectl apply -f monitoring/32-grafana-certificate.yaml
kubectl apply -f monitoring/40-prometheus-service.yaml
kubectl apply -f monitoring/41-prometheus-ingress.yaml
kubectl apply -f monitoring/42-prometheus-certificate.yaml
```

## Hosts no cliente (Windows/Linux/macOS)
Adicione no arquivo hosts do seu PC (Windows: admin em `C:\Windows\System32\drivers\etc\hosts`):
```
192.168.0.51  grafana.home.arpa prometheus.home.arpa
```

## Conectar
- Grafana: `https://grafana.home.arpa` (admin / senha definida no Secret)
- Prometheus UI: `https://prometheus.home.arpa`
- Grafana já tem um **datasource** para `http://prometheus.monitoring.svc:9090`

## Senha do Grafana
Edite a senha em `monitoring/01-grafana-admin-secret.yaml` (campo `GF_SECURITY_ADMIN_PASSWORD`).

## Notas
- Prometheus persiste dados em PVC (20Gi) com StorageClass `microk8s-hostpath`.
- Grafana persiste `/var/lib/grafana` (10Gi) com a mesma StorageClass.
- Scrape padrão: **node-exporter** e **kube-state-metrics** (suficiente para dashboards gerais). É possível adicionar mais jobs no `prometheus.yml`.
- Sem Prometheus Operator para manter o bundle simples e portable.
