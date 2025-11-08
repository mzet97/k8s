#!/usr/bin/env bash

# Script de configuração de pré-requisitos para o Coder
# Configura MicroK8s, addons necessários e recursos base

set -euo pipefail

echo "🚀 Configuração de Pré-requisitos do Coder"
echo "==========================================="
echo ""

# Verificar se MicroK8s está instalado
if ! command -v microk8s &> /dev/null; then
    echo "❌ Erro: MicroK8s não encontrado."
    echo "   Instale o MicroK8s primeiro: snap install microk8s --classic"
    exit 1
fi

echo "✅ MicroK8s encontrado"

# Verificar e aguardar MicroK8s estar pronto
echo "⏳ Verificando status do MicroK8s..."
if ! microk8s status --wait-ready --timeout 60; then
    echo "❌ Erro: MicroK8s não está pronto após 60 segundos."
    echo "   Execute: microk8s start"
    exit 1
fi

echo "✅ MicroK8s está pronto"
echo ""

# Verificar addons necessários
echo "🔧 Verificando e habilitando addons necessários..."

# Lista de addons necessários
ADDONS=("dns" "ingress" "cert-manager")

for addon in "${ADDONS[@]}"; do
    echo "   Verificando addon: $addon"
    if microk8s status | grep -q "$addon: enabled"; then
        echo "   ✅ $addon já está habilitado"
    else
        echo "   🔧 Habilitando $addon..."
        if ! microk8s enable "$addon"; then
            echo "   ❌ Erro ao habilitar $addon"
            exit 1
        fi
        echo "   ✅ $addon habilitado com sucesso"
    fi
done

echo ""
echo "⏳ Aguardando pods dos addons estarem prontos..."
microk8s kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=180s || echo "⚠️ Aviso: Cert-manager pode não estar totalmente pronto."
microk8s kubectl wait --for=condition=available deployment/ingress-nginx-controller -n ingress --timeout=180s || echo "⚠️ Aviso: Ingress Controller pode não estar totalmente pronto."

# Verificar se kubectl está funcionando
echo "🔍 Verificando conectividade com cluster..."
if ! microk8s kubectl cluster-info &> /dev/null; then
    echo "❌ Erro: Não foi possível conectar ao cluster Kubernetes"
    exit 1
fi

echo "✅ Conectividade com cluster OK"
echo ""

# Aplicar recursos Kubernetes
echo "📦 Aplicando recursos Kubernetes..."

# Verificar se arquivos existem antes de aplicar
FILES=(
    "namespace.yaml"
    "secrets/coder-db-url.secret.yaml"
    "cert-manager/clusterissuer-letsencrypt-staging.yaml"
    "cert-manager/clusterissuer-letsencrypt-prod.yaml"
)

for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Erro: Arquivo $file não encontrado"
        exit 1
    fi
done

echo "✅ Todos os arquivos necessários encontrados"
echo ""

# Aplicar namespace primeiro
echo "1️⃣ Criando namespace..."
if microk8s kubectl apply -f namespace.yaml; then
    echo "✅ Namespace aplicado com sucesso"
else
    echo "❌ Erro ao aplicar namespace"
    exit 1
fi

# Aplicar secrets
echo "2️⃣ Aplicando secrets..."
if microk8s kubectl apply -f secrets/coder-db-url.secret.yaml; then
    echo "✅ Secrets aplicados com sucesso"
else
    echo "❌ Erro ao aplicar secrets"
    exit 1
fi

# Aplicar ClusterIssuers
echo "3️⃣ Aplicando ClusterIssuer self-signed para homelab..."
if microk8s kubectl apply -f cert-manager/clusterissuer-selfsigned.yaml; then
    echo "✅ ClusterIssuer self-signed aplicado"
else
    echo "❌ Erro ao aplicar ClusterIssuer self-signed"
    exit 1
fi

echo ""
echo "🎉 Pré-requisitos configurados com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Execute: ./10-install-helm.sh"
echo "   2. Configure o Ingress: kubectl apply -f ingress/coder.ingress.yaml"
echo "   3. Verifique o status: ./90-status.sh"
echo ""
