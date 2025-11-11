#!/bin/bash
# Script para configurar Sealed Secrets
set -e

echo "🔒 Configurando Sealed Secrets..."

# Instalar Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Aguardar controller estar pronto
kubectl wait --for=condition=ready pod -l name=sealed-secrets-controller -n kube-system --timeout=60s

echo "✅ Sealed Secrets controller instalado com sucesso!"

# Criar exemplo de sealed secret para Grafana
echo "🔐 Criando exemplo de sealed secret para Grafana..."
cat > /tmp/grafana-admin-password.txt << EOF
your-secure-admin-password
EOF

# Criar secret temporário
kubectl create secret generic grafana-admin-secret \
  --from-file=GF_SECURITY_ADMIN_PASSWORD=/tmp/grafana-admin-password.txt \
  --namespace=monitoring \
  --dry-run=client -o yaml > /tmp/grafana-admin-secret.yaml

# Instalar kubeseal se não existir
if ! command -v kubeseal &> /dev/null; then
    echo "📦 Instalando kubeseal..."
    wget -q https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
    tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz
    sudo mv kubeseal /usr/local/bin/
    rm kubeseal-0.24.0-linux-amd64.tar.gz
fi

# Criar sealed secret
kubeseal --format yaml < /tmp/grafana-admin-secret.yaml > security/secrets/grafana-admin-sealed.yaml

# Limpar arquivos temporários
rm -f /tmp/grafana-admin-password.txt /tmp/grafana-admin-secret.yaml

echo "✅ Sealed Secret para Grafana criado!"
echo "📁 Arquivo salvo em: security/secrets/grafana-admin-sealed.yaml"