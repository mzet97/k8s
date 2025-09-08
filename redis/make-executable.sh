#!/bin/bash

# Script to make all Redis scripts executable
# This ensures all shell scripts in the Redis directory have proper permissions

echo "🔧 Making all Redis scripts executable..."

# Find all .sh files in current directory and make them executable
for script in *.sh; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo "✅ Made executable: $script"
    fi
done

echo ""
echo "📋 Available Redis scripts:"
echo ""

# List all executable scripts with descriptions
scripts=(
    "install-redis.sh|Instala Redis master-replica completo"
    "setup-external-client.sh|Configura acesso externo automaticamente"
    "diagnose-network-connectivity.sh|Diagnóstico completo de conectividade"
    "fix-installation-issues.sh|Corrige problemas de instalação"
    "fix-redis-proxy.sh|Corrige problemas do HAProxy proxy"
    "test-installation.sh|Testa instalação após setup"
    "test-redis-connections.sh|Testa várias conexões Redis"
    "check-redis-status.sh|Verifica status geral do Redis"
    "diagnose-redis-connection.sh|Diagnóstica problemas de conexão"
    "fix-redis-connection.sh|Corrige problemas específicos de conexão"
    "fix-hpa-issues.sh|Corrige problemas de HPA/metrics"
    "install-cert-manager.sh|Instala cert-manager se necessário"
    "install-metrics-server.sh|Instala metrics-server"
    "enable-metrics-server.sh|Habilita metrics-server no MicroK8s"
    "remove-redis.sh|Remove instalação completa do Redis"
)

for script_info in "${scripts[@]}"; do
    IFS='|' read -r script_name description <<< "$script_info"
    if [ -f "$script_name" ]; then
        echo "  $script_name - $description"
    fi
done

echo ""
echo "🚀 Para acesso externo rápido, execute:"
echo "  ./setup-external-client.sh"
echo ""
echo "🔍 Para diagnóstico completo, execute:"
echo "  ./diagnose-network-connectivity.sh"
echo ""
echo "✅ Todos os scripts estão prontos para uso!"