#!/usr/bin/env bash

# Script de verificação específico para configuração homelab
# Valida configurações locais sem IP público

set -euo pipefail

echo "🏠 Verificação de Configuração Homelab"
echo "====================================="
echo ""

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

# Verificar MicroK8s
echo "📋 1. VERIFICAÇÃO DO MICROK8S"
echo "============================="

if ! check_command "microk8s" "MicroK8s"; then
    echo "❌ MicroK8s não encontrado. Instale com:"
    echo "   sudo snap install microk8s --classic"
    exit 1
fi

if ! microk8s status --wait-ready --timeout 10 &> /dev/null; then
    echo "❌ MicroK8s não está pronto"
    echo "   Execute: microk8s start"
    exit 1
fi

echo "✅ MicroK8s está operacional"
echo ""

# Verificar IP do cluster
echo "📋 2. INFORMAÇÕES DE REDE"
echo "========================="

CLUSTER_IP=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}' 2>/dev/null || echo "N/A")
echo "📡 IP do cluster: $CLUSTER_IP"

# Verificar se coder.local está configurado
if grep -q "coder.local" /etc/hosts 2>/dev/null; then
    echo "✅ coder.local configurado no /etc/hosts"
    HOSTS_IP=$(grep "coder.local" /etc/hosts | awk '{print $1}' | head -1)
    echo "📍 IP configurado: $HOSTS_IP"
    
    if [ "$HOSTS_IP" != "$CLUSTER_IP" ]; then
        echo "⚠️  IP no /etc/hosts ($HOSTS_IP) difere do cluster ($CLUSTER_IP)"
        echo "   Considere atualizar: sudo sed -i 's/$HOSTS_IP/$CLUSTER_IP/g' /etc/hosts"
    fi
else
    echo "❌ coder.local não configurado no /etc/hosts"
    echo "   Execute: echo '$CLUSTER_IP coder.local' | sudo tee -a /etc/hosts"
fi

echo ""

# Verificar configurações específicas do homelab
echo "📋 3. CONFIGURAÇÕES HOMELAB"
echo "==========================="

# Verificar ingress
if [ -f "ingress/coder.ingress.yaml" ]; then
    if grep -q "coder.local" ingress/coder.ingress.yaml; then
        echo "✅ Ingress configurado para coder.local"
    else
        echo "❌ Ingress não configurado para coder.local"
    fi
    
    if grep -q "selfsigned-issuer" ingress/coder.ingress.yaml; then
        echo "✅ Ingress configurado para certificados self-signed"
    else
        echo "⚠️  Ingress pode estar configurado para Let's Encrypt (não funciona sem IP público)"
    fi
else
    echo "❌ Arquivo ingress/coder.ingress.yaml não encontrado"
fi

# Verificar ClusterIssuer self-signed
if [ -f "cert-manager/clusterissuer-selfsigned.yaml" ]; then
    echo "✅ ClusterIssuer self-signed disponível"
else
    echo "❌ ClusterIssuer self-signed não encontrado"
fi

# Verificar valores do Helm
if [ -f "values/coder-values.yaml" ]; then
    if grep -q "coder.local" values/coder-values.yaml; then
        echo "✅ Valores do Helm configurados para coder.local"
    else
        echo "❌ Valores do Helm não configurados para coder.local"
    fi
else
    echo "❌ Arquivo values/coder-values.yaml não encontrado"
fi

# Verificar secret do banco
if [ -f "secrets/coder-db-url.secret.yaml" ]; then
    if grep -q "sslmode=disable" secrets/coder-db-url.secret.yaml; then
        echo "✅ Secret do banco configurado para homelab (sslmode=disable)"
    else
        echo "⚠️  Secret do banco pode precisar de ajuste para homelab"
    fi
    
    if grep -q "sua_senha" secrets/coder-db-url.secret.yaml; then
        echo "⚠️  ATENÇÃO: Atualize as credenciais do banco em secrets/coder-db-url.secret.yaml"
    fi
else
    echo "❌ Secret do banco não encontrado"
fi

echo ""

# Verificar conectividade
echo "📋 4. TESTE DE CONECTIVIDADE"
echo "============================="

# Testar resolução DNS
if command -v nslookup &> /dev/null; then
    if nslookup coder.local &> /dev/null; then
        echo "✅ coder.local resolve corretamente"
    else
        echo "❌ coder.local não resolve"
    fi
fi

# Testar conectividade com o IP do cluster
if command -v ping &> /dev/null && [ "$CLUSTER_IP" != "N/A" ]; then
    if ping -c 1 "$CLUSTER_IP" &> /dev/null; then
        echo "✅ IP do cluster ($CLUSTER_IP) é acessível"
    else
        echo "❌ IP do cluster ($CLUSTER_IP) não é acessível"
    fi
fi

echo ""

# Verificar se o Coder está instalado
echo "📋 5. STATUS DA INSTALAÇÃO"
echo "=========================="

if microk8s kubectl get namespace coder &> /dev/null; then
    echo "✅ Namespace 'coder' existe"
    
    if microk8s helm3 list -n coder | grep -q "coder"; then
        echo "✅ Coder instalado via Helm"
        
        READY_PODS=$(microk8s kubectl -n coder get pods --no-headers | grep -c "Running" || echo "0")
        TOTAL_PODS=$(microk8s kubectl -n coder get pods --no-headers | wc -l || echo "0")
        echo "📊 Pods: $READY_PODS/$TOTAL_PODS rodando"
        
        if [ "$READY_PODS" -gt 0 ]; then
            echo "✅ Coder está rodando"
        else
            echo "❌ Coder não está rodando"
        fi
    else
        echo "❌ Coder não instalado"
        echo "   Execute: ./10-install-helm.sh"
    fi
else
    echo "❌ Namespace 'coder' não existe"
    echo "   Execute: ./00-prereqs.sh"
fi

echo ""

# Resumo e próximos passos
echo "📋 RESUMO E PRÓXIMOS PASSOS"
echo "==========================="

echo "🌐 URLs de acesso:"
echo "   HTTPS: https://coder.local"
echo "   HTTP:  http://coder.local (se configurado)"
echo "   Port-forward: microk8s kubectl -n coder port-forward service/coder 8080:80"
echo ""

echo "🔧 Comandos úteis:"
echo "   Status: ./90-status.sh"
echo "   Logs: microk8s kubectl -n coder logs deployment/coder"
echo "   Restart: microk8s kubectl -n coder rollout restart deployment/coder"
echo ""

echo "📖 Documentação:"
echo "   Guia homelab: cat HOMELAB-SETUP.md"
echo "   Troubleshooting: cat TROUBLESHOOTING.md"
echo ""

echo "✅ Verificação de configuração homelab concluída!"