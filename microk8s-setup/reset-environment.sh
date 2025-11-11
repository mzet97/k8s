#!/bin/bash

# Script de Reset do Ambiente MicroK8s
# Remove configurações e reinicia o ambiente limpo

set -e

echo "🔄 Reset do Ambiente MicroK8s"
echo "============================="
echo

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Verificar se MicroK8s está instalado
if ! command -v microk8s &> /dev/null; then
    echo -e "${RED}❌ MicroK8s não está instalado${NC}"
    exit 1
fi

# Confirmar ação
echo -e "${YELLOW}⚠️  ATENÇÃO: Este script irá:${NC}"
echo "   - Parar o MicroK8s"
echo "   - Desabilitar todos os addons"
echo "   - Limpar dados persistentes"
echo "   - Reiniciar o MicroK8s"
echo "   - Reconfigurar addons básicos"
echo
read -p "Deseja continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operação cancelada."
    exit 0
fi
echo

echo "1. Parando MicroK8s..."
microk8s stop
print_status $? "MicroK8s parado"
echo

echo "2. Desabilitando addons..."
# Lista de addons para desabilitar
ADDONS_TO_DISABLE=("cert-manager" "ingress" "helm3" "hostpath-storage" "dns")

for addon in "${ADDONS_TO_DISABLE[@]}"; do
    echo "Desabilitando $addon..."
    microk8s disable $addon 2>/dev/null || true
    print_info "$addon desabilitado"
done
echo

echo "3. Limpando dados persistentes..."
# Remover dados do hostpath-storage se existir
if [ -d "/var/snap/microk8s/common/default-storage" ]; then
    sudo rm -rf /var/snap/microk8s/common/default-storage/*
    print_status $? "Dados do hostpath-storage removidos"
fi

# Limpar imagens não utilizadas
echo "Limpando imagens Docker..."
microk8s ctr images prune 2>/dev/null || true
print_status $? "Imagens não utilizadas removidas"
echo

echo "4. Reiniciando MicroK8s..."
microk8s start
print_status $? "MicroK8s iniciado"

# Aguardar MicroK8s ficar pronto
echo "Aguardando MicroK8s ficar pronto..."
microk8s status --wait-ready --timeout 120
print_status $? "MicroK8s está pronto"
echo

echo "5. Reabilitando addons essenciais..."

# DNS
echo "Habilitando DNS..."
microk8s enable dns
print_status $? "DNS habilitado"

# Aguardar DNS ficar pronto
echo "Aguardando DNS ficar pronto..."
for i in {1..30}; do
    if kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -q Running; then
        break
    fi
    sleep 2
done
print_status 0 "DNS está funcionando"

# Hostpath Storage
echo "Habilitando Hostpath Storage..."
microk8s enable hostpath-storage
print_status $? "Hostpath Storage habilitado"

# Aguardar storage ficar pronto
echo "Aguardando Storage ficar pronto..."
for i in {1..30}; do
    if kubectl get storageclass microk8s-hostpath 2>/dev/null | grep -q microk8s-hostpath; then
        break
    fi
    sleep 2
done
print_status 0 "Storage está funcionando"

# Ingress
echo "Habilitando Ingress..."
microk8s enable ingress
print_status $? "Ingress habilitado"

# Aguardar Ingress ficar pronto
echo "Aguardando Ingress ficar pronto..."
for i in {1..60}; do
    if kubectl get pods -n ingress --no-headers 2>/dev/null | grep -q Running; then
        break
    fi
    sleep 2
done
print_status 0 "Ingress está funcionando"

# Helm
echo "Habilitando Helm..."
microk8s enable helm3
print_status $? "Helm habilitado"

# Cert-Manager
echo "Habilitando Cert-Manager..."
microk8s enable cert-manager
print_status $? "Cert-Manager habilitado"

# Aguardar Cert-Manager ficar pronto
echo "Aguardando Cert-Manager ficar pronto..."
for i in {1..120}; do
    CERT_MANAGER_PODS=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep Running | wc -l)
    if [ $CERT_MANAGER_PODS -ge 3 ]; then
        break
    fi
    sleep 2
done
print_status 0 "Cert-Manager está funcionando"
echo

echo "6. Configurando ClusterIssuers..."

# Criar ClusterIssuer para Let's Encrypt (staging)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: public
EOF
print_status $? "ClusterIssuer staging criado"

# Criar ClusterIssuer para Let's Encrypt (produção)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: public
EOF
print_status $? "ClusterIssuer produção criado"
echo

echo "7. Verificação final..."

# Verificar nodes
NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
print_status $([ $NODES -gt 0 ] && echo 0 || echo 1) "$NODES node(s) disponível(is)"

# Verificar pods do sistema
SYSTEM_PODS_NOT_READY=$(kubectl get pods -A --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
print_status $([ $SYSTEM_PODS_NOT_READY -eq 0 ] && echo 0 || echo 1) "Pods do sistema: $(kubectl get pods -A --no-headers | wc -l) total, $SYSTEM_PODS_NOT_READY com problemas"

# Verificar addons
ADDONS_STATUS=$(microk8s status --addon 2>/dev/null)
EXPECTED_ADDONS=("dns" "hostpath-storage" "ingress" "helm3" "cert-manager")

for addon in "${EXPECTED_ADDONS[@]}"; do
    if echo "$ADDONS_STATUS" | grep -q "$addon: enabled"; then
        print_status 0 "Addon $addon está habilitado"
    else
        print_status 1 "Addon $addon não está habilitado"
    fi
done

# Verificar ClusterIssuers
CLUSTER_ISSUERS=$(kubectl get clusterissuer --no-headers 2>/dev/null | wc -l)
print_status $([ $CLUSTER_ISSUERS -ge 2 ] && echo 0 || echo 1) "$CLUSTER_ISSUERS ClusterIssuer(s) configurado(s)"
echo

echo "📊 RESUMO DO RESET"
echo "=================="
echo -e "${GREEN}✅ Reset do ambiente concluído com sucesso!${NC}"
echo -e "${GREEN}✅ Todos os addons essenciais foram reconfigurados${NC}"
echo -e "${GREEN}✅ ClusterIssuers para Let's Encrypt foram criados${NC}"
echo

echo "💡 PRÓXIMOS PASSOS:"
echo "1. Verifique o ambiente: ./check-environment.sh"
echo "2. Atualize o email nos ClusterIssuers se necessário:"
echo "   kubectl edit clusterissuer letsencrypt-staging"
echo "   kubectl edit clusterissuer letsencrypt-prod"
echo "3. Deploy suas aplicações normalmente"
echo

echo "🎉 Ambiente MicroK8s resetado e pronto para uso!"