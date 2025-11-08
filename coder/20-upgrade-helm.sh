#!/usr/bin/env bash

# Script de atualização do Coder via Helm
# Atualiza a instalação existente do Coder

set -euo pipefail

echo "🔄 Atualização do Coder via Helm"
echo "==============================="
echo ""

# Verificar se MicroK8s está disponível
if ! command -v microk8s &> /dev/null; then
    echo "❌ Erro: MicroK8s não encontrado."
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
    echo "❌ Erro: Helm3 não está habilitado."
    echo "   Execute: microk8s enable helm3"
    exit 1
fi

echo "✅ Helm3 está disponível"

# Verificar se o namespace coder existe
echo "🔍 Verificando namespace coder..."
if ! microk8s kubectl get namespace coder &> /dev/null; then
    echo "❌ Erro: Namespace 'coder' não encontrado."
    echo "   Execute primeiro: ./00-prereqs.sh"
    exit 1
fi

echo "✅ Namespace 'coder' encontrado"

# Verificar se existe uma instalação do Coder
echo "🔍 Verificando instalação existente..."
if ! microk8s helm3 list -n coder | grep -q "coder"; then
    echo "❌ Erro: Instalação do Coder não encontrada."
    echo "   Execute primeiro: ./10-install-helm.sh"
    exit 1
fi

echo "✅ Instalação do Coder encontrada"

# Mostrar versão atual
echo "📋 Informações da instalação atual:"
microk8s helm3 list -n coder
echo ""

# Verificar se o arquivo de valores existe
echo "🔍 Verificando arquivo de valores..."
if [[ ! -f "values/coder-values.yaml" ]]; then
    echo "❌ Erro: Arquivo values/coder-values.yaml não encontrado"
    exit 1
fi

echo "✅ Arquivo de valores encontrado"

# Verificar se o repositório está atualizado
echo "🔄 Atualizando repositórios Helm..."
if ! microk8s helm3 repo update; then
    echo "❌ Erro ao atualizar repositórios"
    exit 1
fi

echo "✅ Repositórios atualizados"
echo ""

# Verificar status atual dos pods
echo "📊 Status atual dos pods:"
microk8s kubectl -n coder get pods
echo ""

# Confirmar atualização
read -p "🔄 Continuar com a atualização? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Atualização cancelada pelo usuário."
    exit 0
fi

# Realizar backup das configurações atuais
echo "💾 Fazendo backup das configurações atuais..."
microk8s helm3 get values coder -n coder > "/tmp/coder-values-backup-$(date +%Y%m%d-%H%M%S).yaml" || true
echo "✅ Backup salvo em /tmp/"

# Atualizar Coder
echo "🚀 Atualizando Coder..."
echo "   Chart: coder-v2/coder"
echo "   Namespace: coder"
echo "   Values: values/coder-values.yaml"
echo ""

if ! microk8s helm3 upgrade coder coder-v2/coder -n coder -f values/coder-values.yaml --wait --timeout 10m; then
    echo "❌ Erro durante a atualização do Coder"
    echo ""
    echo "🔍 Logs para diagnóstico:"
    microk8s kubectl -n coder get pods
    microk8s kubectl -n coder describe pods
    echo ""
    echo "💾 Para reverter, use o backup em /tmp/"
    exit 1
fi

echo "✅ Coder atualizado com sucesso!"
echo ""

# Aguardar deployment estar pronto
echo "⏳ Aguardando deployment estar pronto..."
if ! microk8s kubectl -n coder rollout status deployment/coder --timeout=300s; then
    echo "❌ Timeout aguardando deployment estar pronto"
    echo ""
    echo "🔍 Status atual:"
    microk8s kubectl -n coder get pods
    microk8s kubectl -n coder describe deployment/coder
    exit 1
fi

echo "✅ Deployment está pronto"
echo ""

# Verificar saúde da aplicação
echo "🔍 Verificando saúde da aplicação..."
echo "📊 Status dos pods após atualização:"
microk8s kubectl -n coder get pods
echo ""

echo "📊 Status dos services:"
microk8s kubectl -n coder get svc
echo ""

# Mostrar informações da instalação atualizada
echo "📋 Informações da instalação atualizada:"
microk8s helm3 list -n coder
echo ""

# Verificar logs recentes
echo "📝 Logs recentes (últimas 10 linhas):"
microk8s kubectl -n coder logs deployment/coder --tail=10 | tail -n +1 || echo "⚠️  Não foi possível obter logs"
echo ""

echo "🎉 Atualização concluída com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Verifique o status completo: ./90-status.sh"
echo "   2. Teste o acesso: https://coder.seu-dominio.com"
echo "   3. Monitore os logs: kubectl -n coder logs -f deployment/coder"
echo ""
echo "💾 Backup das configurações anteriores disponível em /tmp/"
echo ""
