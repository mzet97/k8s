#!/bin/bash

# Script de Remoção do Redis Master-Replica no K3s
# Remove todos os recursos do Redis na ordem correta

set -e

# Flag opcional --force para remover sem confirmação
FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="redis"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${RED}🗑️  Iniciando remoção do Redis Master-Replica no K3s...${NC}"
echo ""

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ Erro: kubectl não encontrado.${NC}"
    exit 1
fi

# Verificar se o namespace redis existe
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠️  Namespace '$NAMESPACE' não encontrado. Nada para remover.${NC}"
    exit 0
fi

echo -e "${BLUE}📋 Namespace '$NAMESPACE' encontrado. Iniciando remoção...${NC}"
echo ""

# Mostrar recursos atuais antes da remoção
echo -e "${BLUE}📊 Recursos atuais no namespace $NAMESPACE:${NC}"
kubectl -n $NAMESPACE get all
echo ""

# Confirmar remoção
if [[ "$FORCE" != true ]]; then
  read -p "⚠️  Tem certeza que deseja remover TODOS os recursos do Redis? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${RED}❌ Remoção cancelada pelo usuário.${NC}"
      exit 0
  fi
else
  echo -e "${YELLOW}⚙️  Remoção forçada (--force) habilitada, pulando confirmação.${NC}"
fi

echo -e "${BLUE}🚀 Iniciando remoção dos recursos (ordem reversa)...${NC}"
echo ""

# 1. Remover Redis Commander
echo -e "${BLUE}1️⃣  Removendo Redis Commander...${NC}"
kubectl delete -f "$SCRIPT_DIR/50-redis-commander.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ Redis Commander removido${NC}"
echo ""

# 2. Remover StatefulSets
echo -e "${BLUE}2️⃣  Removendo StatefulSets Redis...${NC}"
kubectl delete -f "$SCRIPT_DIR/22-replica-statefulset-k3s.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/21-master-statefulset-k3s.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ StatefulSets removidos${NC}"
echo ""

# Aguardar pods serem terminados
echo -e "${YELLOW}⏳ Aguardando pods serem terminados...${NC}"
sleep 10
echo ""

# 3. Remover Services
echo -e "${BLUE}3️⃣  Removendo Services...${NC}"
kubectl delete -f "$SCRIPT_DIR/13-master-svc-k3s.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/12-client-svc.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/11-headless-svc.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ Services removidos${NC}"
echo ""

# 4. Remover ConfigMap
echo -e "${BLUE}4️⃣  Removendo ConfigMap...${NC}"
kubectl delete -f "$SCRIPT_DIR/10-configmap.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ ConfigMap removido${NC}"
echo ""

# 5. Remover TLS Certificates
echo -e "${BLUE}5️⃣  Removendo certificados TLS...${NC}"
kubectl delete -f "$SCRIPT_DIR/02-tls-certificates-k3s.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ Certificados TLS removidos${NC}"
echo ""

# 6. Remover RBAC e Secrets
echo -e "${BLUE}6️⃣  Removendo RBAC e Secrets...${NC}"
kubectl delete -f "$SCRIPT_DIR/03-rbac.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/01-secret.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ RBAC e Secrets removidos${NC}"
echo ""

# Verificar recursos restantes
echo -e "${BLUE}🔍 Verificando recursos restantes...${NC}"
REMAINING=$(kubectl -n $NAMESPACE get all --no-headers 2>/dev/null | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Ainda existem $REMAINING recursos no namespace:${NC}"
    kubectl -n $NAMESPACE get all
    echo ""
    read -p "🗑️  Deseja remover o namespace completo (remove TUDO incluindo PVCs)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🗑️  Removendo namespace completo...${NC}"
        kubectl delete namespace $NAMESPACE
        echo -e "${GREEN}✅ Namespace $NAMESPACE removido completamente${NC}"
    else
        echo -e "${YELLOW}⚠️  Namespace mantido com recursos restantes${NC}"
        read -p "🧹 Deseja remover os PVCs do namespace '$NAMESPACE'? (y/N): " -n 1 -r REPLY2
        echo
        if [[ $REPLY2 =~ ^[Yy]$ ]]; then
            kubectl -n $NAMESPACE delete pvc --all
            echo -e "${GREEN}✅ PVCs removidos${NC}"
        fi
    fi
else
    echo -e "${BLUE}7️⃣  Removendo namespace...${NC}"
    kubectl delete -f "$SCRIPT_DIR/00-namespace.yaml" --ignore-not-found=true
    echo -e "${GREEN}✅ Namespace removido${NC}"
fi
echo ""

# Verificação final
echo -e "${BLUE}🔍 Verificação final...${NC}"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠️  Namespace '$NAMESPACE' ainda existe com alguns recursos${NC}"
    kubectl -n $NAMESPACE get all 2>/dev/null || echo "Namespace vazio"
else
    echo -e "${GREEN}✅ Namespace '$NAMESPACE' removido completamente${NC}"
fi
echo ""

echo -e "${GREEN}🎉 Remoção concluída!${NC}"
echo ""
echo -e "${BLUE}📋 Limpeza adicional recomendada:${NC}"
echo "1. Remover entradas DNS locais, se criadas (hosts):"
echo "   - redis.home.arpa"
echo "   - redis-stats.home.arpa"
echo ""
echo "2. Verificar se não há PersistentVolumes órfãos:"
echo "   kubectl get pv"
echo ""
echo -e "${BLUE}📚 Consulte o README.md para reinstalação se necessário.${NC}"
