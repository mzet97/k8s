#!/bin/bash
set -e

echo "=== Criando Sealed Secrets para o cluster ==="

# Verificar se kubeseal está instalado
if ! command -v kubeseal &> /dev/null; then
    echo "kubeseal não encontrado. Instalando..."
    # Instalar kubeseal (Linux amd64)
    KUBESEAL_VERSION="0.24.0"
    wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
    tar -xvzf "kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
    sudo install -m 755 kubeseal /usr/local/bin/kubeseal
    rm kubeseal "kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
fi

# Verificar se o controller de Sealed Secrets está rodando
if ! kubectl get deployment -n kube-system sealed-secrets-controller &> /dev/null; then
    echo "Instalando Sealed Secrets Controller..."
    kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
    
    echo "Aguardando controller ficar pronto..."
    kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n kube-system
fi

# Criar diretório temporário para secrets
TEMP_DIR=$(mktemp -d)
echo "Usando diretório temporário: $TEMP_DIR"

# Função para criar sealed secret
create_sealed_secret() {
    local name=$1
    local namespace=$2
    local key=$3
    local value=$4
    
    echo "Criando sealed secret: $name no namespace $namespace"
    
    # Criar secret temporário
    kubectl create secret generic "$name" \
        --from-literal="$key=$value" \
        --namespace="$namespace" \
        --dry-run=client -o yaml > "$TEMP_DIR/${name}-secret.yaml"
    
    # Converter para sealed secret
    kubeseal --format yaml < "$TEMP_DIR/${name}-secret.yaml" > "security/secrets/${name}-sealed.yaml"
    
    # Limpar secret temporário
    rm "$TEMP_DIR/${name}-secret.yaml"
    
    echo "✓ Sealed secret criado: security/secrets/${name}-sealed.yaml"
}

# Criar exemplos de sealed secrets
echo ""
echo "Criando exemplos de Sealed Secrets..."

# Grafana Admin Password
create_sealed_secret "grafana-admin-secret" "monitoring" "GF_SECURITY_ADMIN_PASSWORD" "admin123"

# Redis Password
create_sealed_secret "redis-password" "default" "redis-password" "redis123"

# Database Credentials
create_sealed_secret "postgres-credentials" "default" "POSTGRES_PASSWORD" "postgres123"

# API Keys
create_sealed_secret "api-keys" "default" "API_KEY" "your-api-key-here"

# Limpar diretório temporário
rm -rf "$TEMP_DIR"

echo ""
echo "=== Sealed Secrets criados com sucesso! ==="
echo ""
echo "Para aplicar os sealed secrets no cluster:"
echo "kubectl apply -f security/secrets/"
echo ""
echo "Para criar novos sealed secrets manualmente:"
echo "1. Crie um secret temporário:"
echo "   kubectl create secret generic my-secret --from-literal=key=value --dry-run=client -o yaml > temp-secret.yaml"
echo ""
echo "2. Converta para sealed secret:"
echo "   kubeseal --format yaml < temp-secret.yaml > my-sealed-secret.yaml"
echo ""
echo "3. Aplique o sealed secret:"
echo "   kubectl apply -f my-sealed-secret.yaml"
echo ""
echo "4. Remova o arquivo temporário:"
echo "   rm temp-secret.yaml"