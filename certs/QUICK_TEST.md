# Teste Rápido do Cert-Manager

Guia rápido para testar se o cert-manager está funcionando corretamente.

## Passo 1: Aplicar o Exemplo

```bash
cd ~/k8s/certs
kubectl apply -f example-certificate.yaml
```

Isso irá criar:
- Namespace `cert-test`
- Certificate `test-certificate`
- Deployment nginx
- Service
- IngressRoute com TLS

## Passo 2: Verificar o Certificado

```bash
# Ver o Certificate
kubectl get certificate -n cert-test

# Ver detalhes
kubectl describe certificate test-certificate -n cert-test

# Ver o Secret gerado
kubectl get secret test-tls-secret -n cert-test
```

**Saída esperada:**
```
NAME               READY   SECRET            AGE
test-certificate   True    test-tls-secret   30s
```

Se `READY = True`, o certificado foi emitido com sucesso! ✅

## Passo 3: Verificar o Secret TLS

```bash
# Ver dados do certificado
kubectl get secret test-tls-secret -n cert-test -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A 2 "Subject:"

# Ver DNS names
kubectl get secret test-tls-secret -n cert-test -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A 1 "Subject Alternative Name"
```

## Passo 4: Configurar /etc/hosts

Adicione o IP do Traefik ao /etc/hosts:

```bash
# Obter IP do Traefik
kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Adicionar ao /etc/hosts (substitua <IP> pelo IP obtido)
echo "<IP> test.home.arpa" | sudo tee -a /etc/hosts
```

Exemplo:
```bash
echo "192.168.1.51 test.home.arpa" | sudo tee -a /etc/hosts
```

## Passo 5: Testar HTTPS

Abra o navegador e acesse:

```
https://test.home.arpa
```

Ou teste via curl:

```bash
# Aceitar certificado auto-assinado
curl -k https://test.home.arpa

# Ou confiar no certificado (recomendado para desenvolvimento)
# Primeiro, extraia o certificado CA
kubectl get secret -n cert-manager local-root-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/local-ca.crt

# Importe no navegador ou sistema
# No Chrome/Firefox: Settings → Certificates → Authorities → Import
# No Linux: sudo cp /tmp/local-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates
```

## Passo 6: Verificar Redirecionamento HTTP → HTTPS

```bash
# Deve redirecionar para HTTPS
curl -I http://test.home.arpa
```

Você deve ver um `Location: https://test.home.arpa` no response.

## Verificar Logs (Se houver problemas)

```bash
# Logs do cert-manager
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Eventos do Certificate
kubectl describe certificate test-certificate -n cert-test

# Ver CertificateRequest
kubectl get certificaterequest -n cert-test
kubectl describe certificaterequest -n cert-test <nome>
```

## Limpeza

Para remover o teste:

```bash
kubectl delete -f example-certificate.yaml
kubectl delete namespace cert-test
```

## Problemas Comuns

### Certificate fica em "False" ou "Pending"

```bash
# Ver por que falhou
kubectl describe certificate test-certificate -n cert-test

# Ver logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100 | grep test-certificate
```

### Secret não foi criado

Verifique se o Certificate está Ready:
```bash
kubectl get certificate -n cert-test
```

Se não estiver, veja os eventos:
```bash
kubectl describe certificate test-certificate -n cert-test
```

### HTTPS não funciona

1. Verifique se o IngressRoute está criado:
   ```bash
   kubectl get ingressroute -n cert-test
   ```

2. Verifique se o pod nginx está rodando:
   ```bash
   kubectl get pods -n cert-test
   ```

3. Verifique se o service está OK:
   ```bash
   kubectl get svc -n cert-test
   ```

4. Verifique se o DNS está resolvendo:
   ```bash
   ping test.home.arpa
   ```

## Próximos Passos

Após confirmar que funciona:

1. Use este exemplo como template para suas aplicações
2. Crie certificados para MinIO, Grafana, ArgoCD, etc.
3. Configure ClusterIssuer para Let's Encrypt (se quiser usar em produção)

## Exemplo Rápido para MinIO

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio-tls
  namespace: minio
spec:
  secretName: minio-tls-secret
  issuerRef:
    name: local-ca
    kind: ClusterIssuer
  dnsNames:
  - minio.home.arpa
  - minio-console.home.arpa
```

Depois, configure o IngressRoute do MinIO para usar `secretName: minio-tls-secret`.
