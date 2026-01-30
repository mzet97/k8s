# Acesso ao Kong Gateway

Este guia descreve como acessar e testar o Kong Gateway implantado no K3s.

## Credenciais
- **Usuário**: `admin`
- **Senha**: `Admin@123`

## Endpoints de Acesso

### 1. Proxy (Data Plane)
O tráfego das suas APIs deve ser direcionado para o serviço LoadBalancer.
- **URL**: `http://192.168.1.51:80` ou `https://192.168.1.51:443`
- **Teste**:
  ```bash
  curl -i http://localhost/example
  ```

### 2. Admin API
A API de administração está protegida por Basic Auth e exposta via Ingress.
- **URL**: `https://kong-admin.home.arpa`
- **Teste com Curl**:
  ```bash
  curl -u admin:Admin@123 -k https://kong-admin.home.arpa/status
  ```

### 3. Kong Manager (Interface Web)
O Kong Manager Open Source foi habilitado para gestão visual das APIs.
- **URL**: `https://kong-manager.home.arpa`
- **Credenciais**: `admin` / `Admin@123`

### 4. Métricas e Status
O status interno pode ser verificado diretamente no pod:
- **Porta**: `8100` (interno)

## Arquitetura DB-less
Esta instalação utiliza o modo **DB-less**. As configurações de rotas e serviços são definidas no arquivo `10-configmap.yaml` dentro do bloco `kong.yml`.

Para aplicar novas configurações:
1. Edite o `10-configmap.yaml`.
2. Aplique com `kubectl apply -f 10-configmap.yaml`.
3. Reinicie o pod do Kong para ler a nova configuração (ou use o endpoint `/config` da Admin API).

## Comandos Úteis
```bash
# Verificando logs
kubectl logs -n kong -l app=kong

# Verificando status dos pods
kubectl get pods -n kong
```
