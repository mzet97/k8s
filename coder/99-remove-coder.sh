#!/usr/bin/env bash

# Script de remoção completa do Coder
# Remove instalação Helm, recursos Kubernetes e dados persistentes

set -e

echo "🗑️  Remoção Completa do Coder"
echo "ATENÇÃO: Esta operação é irreversível!"
echo "===================================="
echo ""

# Flag opcional --force para remover sem confirmação
FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

# Verificar se MicroK8s está disponível
if ! command -v microk8s &> /dev/null; then
    echo "❌ MicroK8s não encontrado. Instale o MicroK8s primeiro."
    exit 1
fi

# Verificar se MicroK8s está rodando
if ! microk8s status --wait-ready --timeout 30 &> /dev/null; then
    echo "❌ MicroK8s não está rodando ou não está pronto."
    echo "   Execute: microk8s start"
    exit 1
fi

# Verificar se o namespace existe
if ! microk8s kubectl get namespace coder &> /dev/null; then
    echo "⚠️  Namespace 'coder' não encontrado. Pode já ter sido removido."
    exit 0
fi

echo "📋 Namespace 'coder' encontrado. Recursos atuais:"
microk8s kubectl -n coder get all,pvc,secrets,certificates,ingress 2>/dev/null || true
echo ""

# Confirmação do usuário
if [[ "$FORCE" != true ]]; then
    read -p "⚠️  Tem certeza que deseja remover COMPLETAMENTE o Coder? (digite 'sim' para confirmar): " confirmation
    if [ "$confirmation" != "sim" ]; then
        echo "❌ Operação cancelada pelo usuário."
        exit 0
    fi
else
    echo "⚙️  Remoção forçada (--force) habilitada, pulando confirmação."
fi

echo "🚀 Iniciando remoção do Coder..."
echo ""

# Verificar se helm3 está habilitado no MicroK8s
if microk8s helm3 version &> /dev/null; then
    MANUAL_REMOVAL=false
else
    echo "⚠️  Helm3 não está habilitado no MicroK8s. Tentaremos remoção manual."
    MANUAL_REMOVAL=true
fi

# Passo 1: Remover release do Helm (se disponível)
if [ "$MANUAL_REMOVAL" = false ]; then
    echo "🗑️  Passo 1: Removendo release do Helm..."
    if microk8s helm3 list -n coder | grep -q coder; then
        microk8s helm3 uninstall coder -n coder
        echo "✅ Release do Helm removido"
    else
        echo "⚠️  Release 'coder' não encontrado no Helm"
    fi
else
    echo "🗑️  Passo 1: Remoção manual (Helm não disponível)..."
fi

# Passo 2: Remover Ingress
echo "🗑️  Passo 2: Removendo Ingress..."
if [[ -f "ingress/coder.ingress.yaml" ]]; then
    microk8s kubectl delete -f ingress/coder.ingress.yaml --ignore-not-found=true
    echo "✅ Ingress removido"
else
    microk8s kubectl delete ingress coder -n coder --ignore-not-found=true
    echo "✅ Ingress removido (comando direto)"
fi

# Passo 3: Remover recursos manualmente
echo "🗑️  Passo 3: Removendo recursos Kubernetes..."

# Remover Deployments
echo "   Removendo Deployments..."
microk8s kubectl delete deployment --all -n coder --ignore-not-found=true

# Remover StatefulSets
echo "   Removendo StatefulSets..."
microk8s kubectl delete statefulset --all -n coder --ignore-not-found=true

# Remover Services
echo "   Removendo Services..."
microk8s kubectl delete service --all -n coder --ignore-not-found=true

# Remover ConfigMaps
echo "   Removendo ConfigMaps..."
microk8s kubectl delete configmap --all -n coder --ignore-not-found=true

# Remover Jobs e CronJobs
echo "   Removendo Jobs e CronJobs..."
microk8s kubectl delete job --all -n coder --ignore-not-found=true
microk8s kubectl delete cronjob --all -n coder --ignore-not-found=true

echo "✅ Recursos principais removidos"

# Passo 4: Remover certificados TLS
echo "🗑️  Passo 4: Removendo certificados TLS..."
if microk8s kubectl get certificate coder-tls -n coder &> /dev/null; then
    read -p "Remover certificados TLS? (digite 'sim' se não for reutilizar): " tls_confirmation
    if [ "$tls_confirmation" = "sim" ] || [ "$FORCE" = true ]; then
        microk8s kubectl delete certificate coder-tls -n coder --ignore-not-found=true
        microk8s kubectl delete secret coder-tls -n coder --ignore-not-found=true
        echo "✅ Certificados TLS removidos"
    else
        echo "⚠️  Certificados TLS mantidos para reutilização"
    fi
else
    echo "✅ Nenhum certificado TLS encontrado"
fi

# Passo 5: Remover PVCs (dados persistentes)
echo "🗑️  Passo 5: Removendo volumes persistentes..."
PVCS=$(microk8s kubectl get pvc -n coder --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$PVCS" -gt 0 ]; then
    echo "⚠️  ATENÇÃO: Isso removerá todos os dados persistentes do Coder!"
    if [ "$FORCE" = true ]; then
        pvc_confirmation="sim"
    else
        read -p "Confirma remoção dos dados persistentes? (digite 'sim'): " pvc_confirmation
    fi
    if [ "$pvc_confirmation" = "sim" ]; then
        microk8s kubectl delete pvc --all -n coder --ignore-not-found=true
        echo "✅ PVCs removidos (dados perdidos)"
    else
        echo "⚠️  PVCs mantidos (dados preservados)"
        echo "   Para remover manualmente: kubectl delete pvc --all -n coder"
    fi
else
    echo "✅ Nenhum PVC encontrado"
fi

# Passo 6: Remover PVs órfãos (se existirem)
echo "🗑️  Passo 6: Verificando PVs órfãos..."
ORPHAN_PVS=$(microk8s kubectl get pv | grep coder | grep Available | awk '{print $1}' || true)
if [ -n "$ORPHAN_PVS" ]; then
    echo "   Encontrados PVs órfãos: $ORPHAN_PVS"
    if [ "$FORCE" = true ]; then
        pv_confirmation="sim"
    else
        read -p "Remover PVs órfãos? (digite 'sim'): " pv_confirmation
    fi
    if [ "$pv_confirmation" = "sim" ]; then
        echo "$ORPHAN_PVS" | xargs microk8s kubectl delete pv --ignore-not-found=true
        echo "✅ PVs órfãos removidos"
    else
        echo "⚠️  PVs órfãos mantidos"
    fi
else
    echo "✅ Nenhum PV órfão encontrado"
fi

# Passo 7: Remover secrets específicos do Coder
echo "🗑️  Passo 7: Removendo secrets do Coder..."
if [[ -f "secrets/coder-db-url.secret.yaml" ]]; then
    if [ "$FORCE" = true ]; then
        secret_confirmation="sim"
    else
        read -p "Remover secret da URL do banco de dados? (digite 'sim'): " secret_confirmation
    fi
    if [ "$secret_confirmation" = "sim" ]; then
        microk8s kubectl delete -f secrets/coder-db-url.secret.yaml --ignore-not-found=true
        echo "✅ Secret da URL do banco removido"
    else
        echo "⚠️  Secret da URL do banco mantido"
    fi
else
    echo "⚠️  Arquivo de secret não encontrado"
fi

# Passo 8: Aguardar finalização
echo "⏳ Passo 8: Aguardando finalização da remoção..."
sleep 10

# Verificar se ainda existem recursos
echo "🔍 Verificando recursos restantes..."
REMAINING_PODS=$(microk8s kubectl get pods -n coder --no-headers 2>/dev/null | wc -l || echo "0")
REMAINING_SVCS=$(microk8s kubectl get svc -n coder --no-headers 2>/dev/null | wc -l || echo "0")
REMAINING_PVCS=$(microk8s kubectl get pvc -n coder --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$REMAINING_PODS" -eq 0 ] && [ "$REMAINING_SVCS" -eq 0 ]; then
    echo "✅ Todos os recursos principais removidos"
else
    echo "⚠️  Alguns recursos ainda existem:"
    echo "   Pods: $REMAINING_PODS"
    echo "   Services: $REMAINING_SVCS"
    echo "   PVCs: $REMAINING_PVCS"
    echo "   Execute: kubectl get all -n coder"
fi

# Passo 9: Opção de remover namespace
echo "🗑️  Passo 9: Namespace coder..."
if [ "$FORCE" = true ]; then
    ns_confirmation="sim"
else
    read -p "Remover namespace 'coder' completamente? (digite 'sim'): " ns_confirmation
fi
if [ "$ns_confirmation" = "sim" ]; then
    microk8s kubectl delete namespace coder --ignore-not-found=true
    echo "✅ Namespace 'coder' removido"
    echo "⏳ Aguardando finalização do namespace..."
    while microk8s kubectl get namespace coder &> /dev/null; do
        echo "   Aguardando namespace ser removido..."
        sleep 5
    done
    echo "✅ Namespace completamente removido"
else
    echo "⚠️  Namespace 'coder' mantido"
    echo "   Para remover manualmente: kubectl delete namespace coder"
fi

# Passo 10: Limpeza do Helm (repositório)
if [ "$MANUAL_REMOVAL" = false ]; then
    echo "🗑️  Passo 10: Limpeza do repositório Helm..."
    if [ "$FORCE" = true ]; then
        repo_confirmation="sim"
    else
        read -p "Remover repositório coder-v2 do Helm? (digite 'sim'): " repo_confirmation
    fi
    if [ "$repo_confirmation" = "sim" ]; then
        microk8s helm3 repo remove coder-v2 || echo "⚠️  Repositório coder-v2 não encontrado"
        echo "✅ Repositório coder-v2 removido"
    else
        echo "⚠️  Repositório coder-v2 mantido"
    fi
fi

# Resumo final
echo ""
echo "🎉 RESUMO DA REMOÇÃO"
echo "==================="
echo "✅ Release Helm: Removido"
echo "✅ Recursos K8s: Removidos"
echo "✅ Ingress: Removido"
if [ "$pvc_confirmation" = "sim" ]; then
    echo "✅ Dados persistentes: Removidos"
else
    echo "⚠️  Dados persistentes: Mantidos"
fi
if [ "$tls_confirmation" = "sim" ] || [ "$FORCE" = true ]; then
    echo "✅ Certificados TLS: Removidos"
else
    echo "⚠️  Certificados TLS: Mantidos"
fi
if [ "$ns_confirmation" = "sim" ]; then
    echo "✅ Namespace: Removido"
else
    echo "⚠️  Namespace: Mantido"
fi
echo ""
echo "🚀 Remoção do Coder concluída!"
echo ""
echo "📋 Para reinstalar:"
echo "   1. ./00-prereqs.sh"
echo "   2. ./10-install-helm.sh"
echo "   3. kubectl apply -f ingress/coder.ingress.yaml"
echo ""
echo "🔍 Para verificar limpeza:"
echo "   microk8s kubectl get all,pvc,secrets,certificates -n coder"
echo "   microk8s helm3 list -n coder"
echo ""