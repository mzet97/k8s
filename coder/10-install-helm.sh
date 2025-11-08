#!/usr/bin/env bash

# Script de instalação do Coder via Helm
# Instala o Coder usando o chart oficial no namespace coder

set -euo pipefail

echo "🚀 Instalação do Coder via Helm"
echo "==============================="
echo ""

# Verificar se MicroK8s está disponível
if ! command -v microk8s &> /dev/null; then
    echo "❌ Erro: MicroK8s não encontrado."
    echo "   Execute primeiro: ./00-prereqs.sh"
    exit 1
fi

echo "✅ MicroK8s encontrado"

# Verificar se MicroK8s está rodando
echo "⏳ Verificando status do MicroK8s..."
if ! microk8s status --wait-ready --timeout 30 &> /dev/null; then
    echo "❌ Erro: MicroK8s não está pronto."
    echo "   Execute: microk8s start"
    exit 1
fi

echo "✅ MicroK8s está pronto"

# Verificar se helm3 está habilitado
echo "🔍 Verificando Helm3..."
if ! microk8s helm3 version &> /dev/null; then
    echo "🔧 Habilitando Helm3..."
    if ! microk8s enable helm3; then
        echo "❌ Erro ao habilitar Helm3"
        exit 1
    fi
    echo "✅ Helm3 habilitado"
    sleep 10
else
    echo "✅ Helm3 já está habilitado"
fi

# Verificar se o namespace coder existe
echo "🔍 Verificando namespace coder..."
if ! microk8s kubectl get namespace coder &> /dev/null; then
    echo "❌ Erro: Namespace 'coder' não encontrado."
    echo "   Execute primeiro: ./00-prereqs.sh"
    exit 1
fi

echo "✅ Namespace 'coder' encontrado"

# Verificar se o arquivo de valores existe
echo "🔍 Verificando arquivo de valores..."
if [[ ! -f "values/coder-values.yaml" ]]; then
    echo "❌ Erro: Arquivo values/coder-values.yaml não encontrado"
    exit 1
fi

echo "✅ Arquivo de valores encontrado"
echo ""

# Adicionar repositório do Coder
echo "📦 Configurando repositório Helm do Coder..."
if microk8s helm3 repo list | grep -q "coder-v2"; then
    echo "✅ Repositório coder-v2 já está adicionado"
else
    echo "🔧 Adicionando repositório coder-v2..."
    if ! microk8s helm3 repo add coder-v2 https://helm.coder.com/v2; then
        echo "❌ Erro ao adicionar repositório do Coder"
        exit 1
    fi
    echo "✅ Repositório coder-v2 adicionado"
fi

# Atualizar repositórios
echo "🔄 Atualizando repositórios Helm..."
if ! microk8s helm3 repo update; then
    echo "❌ Erro ao atualizar repositórios"
    exit 1
fi

echo "✅ Repositórios atualizados"
echo ""

# Verificar se já existe uma instalação
echo "🔍 Verificando instalação existente..."
if microk8s helm3 list -n coder | grep -q "coder"; then
    echo "⚠️  Instalação do Coder já existe. Será atualizada."
    ACTION="upgrade"
else
    echo "✅ Nova instalação será realizada"
    ACTION="install"
fi

# Instalar/Atualizar Coder
echo "🚀 ${ACTION^}ando Coder..."
echo "   Chart: coder-v2/coder"
echo "   Namespace: coder"
echo "   Values: values/coder-values.yaml"
echo ""

if ! microk8s helm3 upgrade --install coder coder-v2/coder -n coder -f values/coder-values.yaml --wait --timeout 10m; then
    echo "❌ Erro durante a instalação/atualização do Coder"
    echo ""
    echo "🔍 Logs para diagnóstico:"
    microk8s kubectl -n coder get pods
    microk8s kubectl -n coder describe pods
    exit 1
fi

echo "✅ Coder instalado/atualizado com sucesso!"
echo ""

# Aguardar deployment estar pronto
echo "⏳ Aguardando deployment estar pronto..."
if ! microk8s kubectl -n coder rollout status deployment/coder --timeout=300s; then
    echo "❌ Timeout aguardando deployment estar pronto"
    echo ""
    echo "🔍 Status atual:"
    microk8s kubectl -n coder get pods
    exit 1
fi

echo "✅ Deployment está pronto"
echo ""

# Mostrar informações da instalação
echo "📋 Informações da instalação:"
microk8s helm3 list -n coder
echo ""

echo "🎉 Instalação concluída com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Configure o Ingress: kubectl apply -f ingress/coder.ingress.yaml"
echo "   2. Verifique o status: ./90-status.sh"
echo "   3. Acesse: https://coder.seu-dominio.com"
echo ""
echo "🔧 Para configurar o primeiro usuário admin:"
echo "   kubectl -n coder exec -it deployment/coder -- coder users create --username admin --email admin@example.com"
echo ""
