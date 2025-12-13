#!/bin/bash
set -e

# Script de Remoção do ELK Stack no K3s
# Remove todos os recursos do ELK na ordem correta

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

NAMESPACE="elk"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${RED}🗑️  Iniciando remoção do ELK Stack no K3s...${NC}"
echo ""

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ Erro: kubectl não encontrado.${NC}"
    exit 1
fi

# Verificar se o namespace elk existe
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
  read -p "⚠️  Tem certeza que deseja remover TODOS os recursos do ELK Stack? (y/N): " -n 1 -r
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

# 1. Remover Filebeat
echo -e "${BLUE}1️⃣  Removendo Filebeat (DaemonSet)...${NC}"
kubectl delete -f "$SCRIPT_DIR/51-filebeat-daemonset.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/50-filebeat-configmap.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ Filebeat removido${NC}"
echo ""

# 2. Remover Kibana
echo -e "${BLUE}2️⃣  Removendo Kibana...${NC}"
kubectl delete -f "$SCRIPT_DIR/33-kibana-ingress.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/30-kibana-deployment.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/31-kibana-svc.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/34-tls-certificates.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ Kibana removido${NC}"
echo ""

# 3. Remover Logstash
echo -e "${BLUE}3️⃣  Removendo Logstash...${NC}"
kubectl delete -f "$SCRIPT_DIR/41-logstash-deployment.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/42-logstash-svc.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/40-logstash-configmap.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ Logstash removido${NC}"
echo ""

# Aguardar pods serem terminados
echo -e "${YELLOW}⏳ Aguardando pods serem terminados...${NC}"
sleep 10
echo ""

# 4. Remover Elasticsearch
echo -e "${BLUE}4️⃣  Removendo Elasticsearch (StatefulSet)...${NC}"
kubectl delete -f "$SCRIPT_DIR/14-elasticsearch-ingress.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/20-elasticsearch-statefulset.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/12-client-svc.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/11-headless-svc.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/15-elasticsearch-tls.yaml" --ignore-not-found=true
kubectl delete -f "$SCRIPT_DIR/10-elasticsearch-configmap.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ Elasticsearch removido${NC}"
echo ""

# 5. Remover RBAC
echo -e "${BLUE}5️⃣  Removendo RBAC...${NC}"
kubectl delete -f "$SCRIPT_DIR/03-rbac.yaml" --ignore-not-found=true
echo -e "${GREEN}✅ RBAC removido${NC}"
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
    echo -e "${BLUE}6️⃣  Removendo namespace...${NC}"
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
echo "   - elasticsearch.home.arpa"
echo "   - kibana.home.arpa"
echo ""
echo "2. Verificar se não há PersistentVolumes órfãos:"
echo "   kubectl get pv"
echo ""
echo -e "${BLUE}📚 Consulte o README.md para reinstalação se necessário.${NC}"
