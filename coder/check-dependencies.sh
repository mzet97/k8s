#!/usr/bin/env bash

# Script de verificação de dependências para o projeto Coder
# Pode ser usado por outros scripts para validar pré-requisitos

set -euo pipefail

# Função para verificar se um comando existe
check_command() {
    local cmd="$1"
    local description="$2"
    
    if command -v "$cmd" &> /dev/null; then
        echo "✅ $description ($cmd) - disponível"
        return 0
    else
        echo "❌ $description ($cmd) - não encontrado"
        return 1
    fi
}

# Função para verificar status do MicroK8s
check_microk8s_status() {
    echo "🔍 Verificando status do MicroK8s..."
    
    if ! command -v microk8s &> /dev/null; then
        echo "❌ MicroK8s não está instalado"
        echo "   Instale com: sudo snap install microk8s --classic"
        return 1
    fi
    
    if ! microk8s status --wait-ready --timeout 10 &> /dev/null; then
        echo "❌ MicroK8s não está pronto"
        echo "   Execute: microk8s start"
        return 1
    fi
    
    echo "✅ MicroK8s está operacional"
    return 0
}

# Função para verificar addons do MicroK8s
check_microk8s_addons() {
    echo "🔍 Verificando addons do MicroK8s..."
    
    local required_addons=("dns" "ingress" "cert-manager" "helm3")
    local missing_addons=()
    
    for addon in "${required_addons[@]}"; do
        if microk8s status | grep -q "$addon: enabled"; then
            echo "✅ Addon $addon - habilitado"
        else
            echo "❌ Addon $addon - não habilitado"
            missing_addons+=("$addon")
        fi
    done
    
    if [ ${#missing_addons[@]} -gt 0 ]; then
        echo "⚠️  Addons faltando: ${missing_addons[*]}"
        echo "   Execute: microk8s enable ${missing_addons[*]}"
        return 1
    fi
    
    return 0
}

# Função para verificar arquivos necessários
check_required_files() {
    echo "🔍 Verificando arquivos necessários..."
    
    local required_files=(
        "values/coder-values.yaml"
        "secrets/namespace.yaml"
        "cert-manager/coder-certificate.yaml"
        "ingress/coder-ingress.yaml"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file - encontrado"
        else
            echo "❌ $file - não encontrado"
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo "⚠️  Arquivos faltando: ${missing_files[*]}"
        return 1
    fi
    
    return 0
}

# Função para verificar namespace
check_namespace() {
    echo "🔍 Verificando namespace 'coder'..."
    
    if microk8s kubectl get namespace coder &> /dev/null; then
        echo "✅ Namespace 'coder' existe"
        return 0
    else
        echo "❌ Namespace 'coder' não existe"
        echo "   Execute: ./00-prereqs.sh"
        return 1
    fi
}

# Função para verificar instalação do Helm
check_helm_installation() {
    echo "🔍 Verificando instalação do Coder via Helm..."
    
    if ! microk8s helm3 version &> /dev/null; then
        echo "❌ Helm3 não está disponível"
        return 1
    fi
    
    if microk8s helm3 list -n coder | grep -q "coder"; then
        echo "✅ Release 'coder' encontrada"
        local status=$(microk8s helm3 list -n coder | grep coder | awk '{print $8}')
        echo "📊 Status da release: $status"
        return 0
    else
        echo "❌ Release 'coder' não encontrada"
        echo "   Execute: ./10-install-helm.sh"
        return 1
    fi
}

# Função principal de verificação
main() {
    local mode="${1:-basic}"
    local exit_code=0
    
    echo "🔍 Verificação de Dependências do Coder"
    echo "======================================="
    echo "Modo: $mode"
    echo ""
    
    # Verificações básicas (sempre executadas)
    echo "📋 1. COMANDOS BÁSICOS"
    echo "======================"
    
    check_command "microk8s" "MicroK8s" || exit_code=1
    check_command "kubectl" "kubectl (via microk8s)" || exit_code=1
    check_command "helm" "Helm (via microk8s)" || exit_code=1
    
    echo ""
    
    # Verificação do MicroK8s
    echo "📋 2. STATUS DO MICROK8S"
    echo "========================"
    
    check_microk8s_status || exit_code=1
    echo ""
    
    # Verificação dos addons
    echo "📋 3. ADDONS DO MICROK8S"
    echo "========================"
    
    check_microk8s_addons || exit_code=1
    echo ""
    
    # Verificações específicas baseadas no modo
    case "$mode" in
        "prereqs")
            echo "📋 4. ARQUIVOS NECESSÁRIOS"
            echo "==========================="
            check_required_files || exit_code=1
            echo ""
            ;;
        "install")
            echo "📋 4. NAMESPACE"
            echo "==============="
            check_namespace || exit_code=1
            echo ""
            
            echo "📋 5. ARQUIVOS NECESSÁRIOS"
            echo "==========================="
            check_required_files || exit_code=1
            echo ""
            ;;
        "status")
            echo "📋 4. NAMESPACE"
            echo "==============="
            check_namespace || exit_code=1
            echo ""
            
            echo "📋 5. INSTALAÇÃO HELM"
            echo "====================="
            check_helm_installation || exit_code=1
            echo ""
            ;;
    esac
    
    # Resumo final
    echo "📊 RESUMO DA VERIFICAÇÃO"
    echo "========================"
    
    if [ $exit_code -eq 0 ]; then
        echo "✅ Todas as dependências estão satisfeitas"
        echo "🚀 Sistema pronto para operação"
    else
        echo "❌ Algumas dependências não estão satisfeitas"
        echo "⚠️  Resolva os problemas acima antes de continuar"
    fi
    
    echo ""
    return $exit_code
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi