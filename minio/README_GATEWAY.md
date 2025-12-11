# MinIO on Kubernetes with NGINX Gateway Fabric

This directory contains the configuration for deploying MinIO on Kubernetes using NGINX Gateway Fabric as the ingress controller via the Gateway API.

## Architecture

- **StatefulSet**: Manages the MinIO pods, ensuring stable identity and storage.
- **Service**: 
  - `minio-headless`: Used for internal communication between MinIO nodes (if clustered) and stable network identity.
  - `minio-service`: Used for client access to the S3 API (port 9000) and Console (port 9001).
- **Gateway API**:
  - `GatewayClass`: Defines the controller (`nginx`).
  - `Gateway`: Configures the listener for HTTP/HTTPS traffic.
  - `HTTPRoute`: Routes traffic based on hostnames (`minio.home.arpa` for API, `console.minio.home.arpa` for Console).

## Prerequisites

- Kubernetes cluster with Gateway API CRDs installed.
- NGINX Gateway Fabric installed.
- `kubectl` configured.

## Deployment

1. **Create Namespace**:
   ```bash
   kubectl apply -f 00-namespace.yaml
   ```

2. **Create Secrets**:
   ```bash
   kubectl apply -f 01-secret.yaml
   ```

3. **Create RBAC**:
   ```bash
   kubectl apply -f 03-rbac.yaml
   ```

4. **Deploy Services**:
   ```bash
   kubectl apply -f 11-headless-svc.yaml
   kubectl apply -f 12-client-svc.yaml
   ```

5. **Deploy StatefulSet**:
   ```bash
   kubectl apply -f 20-statefulset.yaml
   ```

6. **Configure Gateway**:
   ```bash
   kubectl apply -f 30-gateway-class.yaml
   kubectl apply -f 31-gateway.yaml
   kubectl apply -f 32-http-routes.yaml
   ```

## Access

- **IP do Cluster**: `192.168.1.51` (Node IP)
- **Portas**:
  - HTTP: `32401`
  - HTTPS: `30687`
- **URLs**:
  - API: `http://minio.home.arpa:32401`
  - Console: `http://console.minio.home.arpa:32401`

Configure seu arquivo `/etc/hosts` (ou DNS local) para apontar os domínios para `192.168.1.51`:
```
192.168.1.51 minio.home.arpa
192.168.1.51 console.minio.home.arpa
```

**Nota sobre LoadBalancer**: O status `<pending>` no External-IP é normal em ambientes sem um LoadBalancer provider (como MetalLB). O acesso via NodePort funciona normalmente.

## Security

- Default credentials are set in `01-secret.yaml`. **Change these for production.**
- TLS is configured in `31-gateway.yaml` but requires a valid `minio-tls` secret.

## Storage

- Uses `emptyDir` for testing. For production, uncomment the `volumeClaimTemplates` section in `20-statefulset.yaml` to use persistent storage.
