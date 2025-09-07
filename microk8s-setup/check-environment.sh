#!/bin/bash

# Script de Verificação Completa do Ambiente MicroK8s
# Verifica se todos os componentes estão funcionando corretamente

set -e

echo "🔍 Verificação Completa do Ambiente MicroK8s"
echo "============================================="
echo

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir status
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
echo "1. Verificando instalação do MicroK8s..."
if command -v microk8s &> /dev/null; then
    print_status 0 "MicroK8s está instalado"
    MICROK8S_VERSION=$(microk8s version --short 2>/dev/null || echo "Versão não disponível")
    print_info "Versão: $MICROK8S_VERSION"
else
    print_status 1 "MicroK8s não está instalado"
    echo "Execute: ./install-microk8s.sh"
    exit 1
fi
echo

# Verificar status do MicroK8s
echo "2. Verificando status do MicroK8s..."
if microk8s status --wait-ready --timeout 30 &> /dev/null; then
    print_status 0 "MicroK8s está rodando"
else
    print_status 1 "MicroK8s não está rodando corretamente"
    echo "Tentando obter mais informações:"
    microk8s status
fi
echo

# Verificar addons
echo "3. Verificando addons habilitados..."
ADDONS_STATUS=$(microk8s status --addon 2>/dev/null)

# Lista de addons esperados
EXPECTED_ADDONS=("dns" "hostpath-storage" "ingress" "helm3" "cert-manager")

for addon in "${EXPECTED_ADDONS[@]}"; do
    if echo "$ADDONS_STATUS" | grep -q "$addon: enabled"; then
        print_status 0 "Addon $addon está habilitado"
    else
        print_status 1 "Addon $addon não está habilitado"
    fi
done
echo

# Verificar kubectl
echo "4. Verificando kubectl..."
if command -v kubectl &> /dev/null; then
    print_status 0 "kubectl está disponível"
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || echo "Versão não disponível")
    print_info "Versão: $KUBECTL_VERSION"
else
    print_status 1 "kubectl não está disponível"
    print_warning "Verifique se o alias foi configurado ou use 'microk8s kubectl'"
fi
echo

# Verificar nodes
echo "5. Verificando nodes do cluster..."
NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ $NODES -gt 0 ]; then
    print_status 0 "$NODES node(s) encontrado(s)"
    echo "Detalhes dos nodes:"
    kubectl get nodes -o wide
else
    print_status 1 "Nenhum node encontrado"
fi
echo

# Verificar pods do sistema
echo "6. Verificando pods do sistema..."
SYSTEM_PODS_NOT_READY=$(kubectl get pods -A --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
if [ $SYSTEM_PODS_NOT_READY -eq 0 ]; then
    print_status 0 "Todos os pods do sistema estão rodando"
else
    print_status 1 "$SYSTEM_PODS_NOT_READY pod(s) do sistema não estão rodando"
    echo "Pods com problemas:"
    kubectl get pods -A --field-selector=status.phase!=Running
fi
echo

# Verificar DNS
echo "7. Verificando DNS..."
DNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep Running | wc -l)
if [ $DNS_PODS -gt 0 ]; then
    print_status 0 "DNS está funcionando ($DNS_PODS pod(s))"
else
    print_status 1 "DNS não está funcionando"
fi
echo

# Verificar Ingress
echo "8. Verificando Ingress..."
INGRESS_PODS=$(kubectl get pods -n ingress --no-headers 2>/dev/null | grep Running | wc -l)
if [ $INGRESS_PODS -gt 0 ]; then
    print_status 0 "Ingress está funcionando ($INGRESS_PODS pod(s))"
else
    print_status 1 "Ingress não está funcionando"
fi
echo

# Verificar Cert-Manager
echo "9. Verificando Cert-Manager..."
CERT_MANAGER_PODS=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep Running | wc -l)
if [ $CERT_MANAGER_PODS -ge 3 ]; then
    print_status 0 "Cert-Manager está funcionando ($CERT_MANAGER_PODS pod(s))"
else
    print_status 1 "Cert-Manager não está funcionando completamente"
    if [ $CERT_MANAGER_PODS -gt 0 ]; then
        print_warning "Apenas $CERT_MANAGER_PODS pod(s) rodando, esperado: 3"
    fi
fi

# Verificar ClusterIssuers
CLUSTER_ISSUERS=$(kubectl get clusterissuer --no-headers 2>/dev/null | wc -l)
if [ $CLUSTER_ISSUERS -gt 0 ]; then
    print_status 0 "$CLUSTER_ISSUERS ClusterIssuer(s) configurado(s)"
    kubectl get clusterissuer
else
    print_status 1 "Nenhum ClusterIssuer configurado"
fi
echo

# Verificar armazenamento
echo "10. Verificando armazenamento..."
STORAGE_CLASSES=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
if [ $STORAGE_CLASSES -gt 0 ]; then
    print_status 0 "$STORAGE_CLASSES StorageClass(es) disponível(is)"
    kubectl get storageclass
else
    print_status 1 "Nenhuma StorageClass encontrada"
fi
echo

# Teste de conectividade DNS
echo "11. Testando conectividade DNS..."
DNS_TEST_POD="dns-test-$(date +%s)"
kubectl run $DNS_TEST_POD --image=busybox --rm -it --restart=Never --command -- nslookup kubernetes.default.svc.cluster.local &> /dev/null
if [ $? -eq 0 ]; then
    print_status 0 "Teste de DNS passou"
else
    print_status 1 "Teste de DNS falhou"
fi
echo

# Verificar recursos do sistema
echo "12. Verificando recursos do sistema..."
if command -v free &> /dev/null; then
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    print_info "Uso de memória: ${MEMORY_USAGE}%"
fi

if command -v df &> /dev/null; then
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    print_info "Uso de disco (/): ${DISK_USAGE}%"
    
    if [ $DISK_USAGE -gt 80 ]; then
        print_warning "Uso de disco alto (${DISK_USAGE}%)"
    fi
fi
echo

# Resumo final
echo "📊 RESUMO DA VERIFICAÇÃO"
echo "========================"

# Contar problemas
PROBLEMS=0

# Verificações básicas
if ! microk8s status --wait-ready --timeout 5 &> /dev/null; then
    ((PROBLEMS++))
fi

if [ $SYSTEM_PODS_NOT_READY -gt 0 ]; then
    ((PROBLEMS++))
fi

if [ $DNS_PODS -eq 0 ]; then
    ((PROBLEMS++))
fi

if [ $INGRESS_PODS -eq 0 ]; then
    ((PROBLEMS++))
fi

if [ $CERT_MANAGER_PODS -lt 3 ]; then
    ((PROBLEMS++))
fi

if [ $PROBLEMS -eq 0 ]; then
    echo -e "${GREEN}🎉 Ambiente MicroK8s está funcionando perfeitamente!${NC}"
    echo -e "${GREEN}✅ Todos os componentes estão operacionais${NC}"
else
    echo -e "${YELLOW}⚠️  Encontrados $PROBLEMS problema(s) no ambiente${NC}"
    echo -e "${YELLOW}🔧 Verifique os itens marcados com ❌ acima${NC}"
fi

echo
echo "💡 DICAS:"
echo "- Para logs detalhados: kubectl logs -n <namespace> <pod-name>"
echo "- Para reiniciar MicroK8s: sudo snap restart microk8s"
echo "- Para reconfigurar addons: ./configure-addons.sh"
echo "- Para logs do sistema: sudo journalctl -u snap.microk8s.daemon-kubelite"
echo

echo "✅ Verificação concluída!"