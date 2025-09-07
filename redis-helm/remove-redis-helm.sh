#!/bin/bash

# Script de remoção do Redis instalado via Helm
# Remove completamente a instalação incluindo PVCs e secrets

set -e

echo "🗑️  Remoção do Redis Helm - Bitnami"
echo "ATENÇÃO: Esta operação é irreversível!"
echo "======================================"

# Confirmação do usuário
read -p "Tem certeza que deseja remover completamente o Redis? (digite 'sim' para confirmar): " confirmation
if [ "$confirmation" != "sim" ]; then
    echo "❌ Operação cancelada pelo usuário."
    exit 0
fi

echo "🚀 Iniciando remoção do Redis..."

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

# Verificar se helm3 está habilitado no MicroK8s
if microk8s helm3 version &> /dev/null; then
    MANUAL_REMOVAL=false
else
    echo "⚠️  Helm3 não está habilitado no MicroK8s. Tentaremos remoção manual."
    MANUAL_REMOVAL=true
fi



# Verificar se o namespace existe
if ! microk8s kubectl get namespace redis &> /dev/null; then
    echo "⚠️  Namespace 'redis' não encontrado. Pode já ter sido removido."
    exit 0
fi

# Passo 1: Remover release do Helm (se disponível)
if [ "$MANUAL_REMOVAL" = false ]; then
    echo "🗑️  Passo 1: Removendo release do Helm..."
    if helm list -n redis | grep -q redis-cluster; then
        microk8s helm3 uninstall redis-cluster -n redis
        echo "✅ Release do Helm removido"
    else
        echo "⚠️  Release 'redis-cluster' não encontrado no Helm"
    fi
else
    echo "🗑️  Passo 1: Remoção manual (Helm não disponível)..."
fi

# Passo 2: Remover recursos manualmente
echo "🗑️  Passo 2: Removendo recursos Kubernetes..."

# Remover StatefulSets
echo "   Removendo StatefulSets..."
microk8s kubectl delete statefulset --all -n redis --ignore-not-found=true

# Remover Deployments
echo "   Removendo Deployments..."
microk8s kubectl delete deployment --all -n redis --ignore-not-found=true

# Remover Services
echo "   Removendo Services..."
microk8s kubectl delete service --all -n redis --ignore-not-found=true

# Remover ConfigMaps
echo "   Removendo ConfigMaps..."
microk8s kubectl delete configmap --all -n redis --ignore-not-found=true

# Remover Secrets (exceto TLS que pode ser reutilizado)
echo "   Removendo Secrets do Redis..."
microk8s kubectl delete secret -l app.kubernetes.io/name=redis -n redis --ignore-not-found=true

# Passo 3: Remover PVCs (dados persistentes)
echo "🗑️  Passo 3: Removendo volumes persistentes..."
echo "⚠️  ATENÇÃO: Isso removerá todos os dados do Redis!"
read -p "Confirma remoção dos dados persistentes? (digite 'sim'): " pvc_confirmation
if [ "$pvc_confirmation" = "sim" ]; then
    microk8s kubectl delete pvc --all -n redis --ignore-not-found=true
    echo "✅ PVCs removidos (dados perdidos)"
else
    echo "⚠️  PVCs mantidos (dados preservados)"
    echo "   Para remover manualmente: kubectl delete pvc --all -n redis"
fi

# Passo 4: Remover PVs órfãos (se existirem)
echo "🗑️  Passo 4: Verificando PVs órfãos..."
ORPHAN_PVS=$(microk8s kubectl get pv | grep redis | grep Available | awk '{print $1}' || true)
if [ -n "$ORPHAN_PVS" ]; then
    echo "   Encontrados PVs órfãos: $ORPHAN_PVS"
    read -p "Remover PVs órfãos? (digite 'sim'): " pv_confirmation
    if [ "$pv_confirmation" = "sim" ]; then
        echo "$ORPHAN_PVS" | xargs microk8s kubectl delete pv --ignore-not-found=true
        echo "✅ PVs órfãos removidos"
    else
        echo "⚠️  PVs órfãos mantidos"
    fi
else
    echo "✅ Nenhum PV órfão encontrado"
fi

# Passo 5: Remover certificados TLS (opcional)
echo "🗑️  Passo 5: Certificados TLS..."
if microk8s kubectl get certificate redis-tls-cert -n redis &> /dev/null; then
    read -p "Remover certificados TLS? (digite 'sim' se não for reutilizar): " tls_confirmation
    if [ "$tls_confirmation" = "sim" ]; then
        microk8s kubectl delete certificate redis-tls-cert -n redis --ignore-not-found=true
        microk8s kubectl delete secret redis-tls-secret -n redis --ignore-not-found=true
        echo "✅ Certificados TLS removidos"
    else
        echo "⚠️  Certificados TLS mantidos para reutilização"
    fi
else
    echo "✅ Nenhum certificado TLS encontrado"
fi

# Passo 6: Aguardar finalização
echo "⏳ Passo 6: Aguardando finalização da remoção..."
sleep 10

# Verificar se ainda existem recursos
echo "🔍 Verificando recursos restantes..."
REMAINING_PODS=$(microk8s kubectl get pods -n redis --no-headers 2>/dev/null | wc -l || echo "0")
REMAINING_SVCS=$(microk8s kubectl get svc -n redis --no-headers 2>/dev/null | wc -l || echo "0")
REMAINING_PVCS=$(microk8s kubectl get pvc -n redis --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$REMAINING_PODS" -eq 0 ] && [ "$REMAINING_SVCS" -eq 0 ]; then
    echo "✅ Todos os recursos principais removidos"
else
    echo "⚠️  Alguns recursos ainda existem:"
    echo "   Pods: $REMAINING_PODS"
    echo "   Services: $REMAINING_SVCS"
    echo "   PVCs: $REMAINING_PVCS"
    echo "   Execute: kubectl get all -n redis"
fi

# Passo 7: Opção de remover namespace
echo "🗑️  Passo 7: Namespace redis..."
read -p "Remover namespace 'redis' completamente? (digite 'sim'): " ns_confirmation
if [ "$ns_confirmation" = "sim" ]; then
    microk8s kubectl delete namespace redis --ignore-not-found=true
    echo "✅ Namespace 'redis' removido"
    echo "⏳ Aguardando finalização do namespace..."
    while microk8s kubectl get namespace redis &> /dev/null; do
        echo "   Aguardando namespace ser removido..."
        sleep 5
    done
    echo "✅ Namespace completamente removido"
else
    echo "⚠️  Namespace 'redis' mantido"
    echo "   Para remover manualmente: kubectl delete namespace redis"
fi

# Passo 8: Limpeza do Helm (repositório)
if [ "$MANUAL_REMOVAL" = false ]; then
    echo "🗑️  Passo 8: Limpeza do repositório Helm..."
    read -p "Remover repositório Bitnami do Helm? (digite 'sim'): " repo_confirmation
    if [ "$repo_confirmation" = "sim" ]; then
        microk8s helm3 repo remove bitnami || echo "⚠️  Repositório Bitnami não encontrado"
        echo "✅ Repositório Bitnami removido"
    else
        echo "⚠️  Repositório Bitnami mantido"
    fi
fi

# Resumo final
echo ""
echo "🎉 RESUMO DA REMOÇÃO"
echo "==================="
echo "✅ Release Helm: Removido"
echo "✅ Recursos K8s: Removidos"
if [ "$pvc_confirmation" = "sim" ]; then
    echo "✅ Dados persistentes: Removidos"
else
    echo "⚠️  Dados persistentes: Mantidos"
fi
if [ "$tls_confirmation" = "sim" ]; then
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
echo "🚀 Remoção do Redis Helm concluída!"
echo ""
echo "📋 Para reinstalar:"
echo "   cd redis-helm"
echo "   ./install-redis-helm.sh"
echo ""
echo "🔍 Para verificar limpeza:"
echo "   microk8s kubectl get all,pvc,secrets,certificates -n redis"
echo "   microk8s helm3 list -n redis"