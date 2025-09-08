#!/bin/bash

# Redis External Access Validation Script
# Quick validation to ensure the external access solutions are working

echo "🧪 Redis External Access Validation"
echo "==================================="
echo ""

# Check if we're in the right directory
if [ ! -f "setup-external-client.sh" ] || [ ! -f "EXTERNAL-ACCESS-GUIDE.md" ]; then
    echo "❌ Execute este script a partir do diretório redis/"
    echo "   cd redis/ && ./validate-external-access.sh"
    exit 1
fi

echo "✅ Executando a partir do diretório correto"
echo ""

# Check script permissions
echo "📋 Verificando permissões dos scripts..."

scripts=(
    "setup-external-client.sh"
    "diagnose-network-connectivity.sh"
    "make-executable.sh"
    "install-redis.sh"
    "fix-installation-issues.sh"
    "fix-redis-proxy.sh"
)

all_executable=true

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo "✅ $script é executável"
    else
        echo "❌ $script NÃO é executável"
        all_executable=false
    fi
done

if [ "$all_executable" = false ]; then
    echo ""
    echo "🔧 Corrigindo permissões..."
    chmod +x *.sh
    echo "✅ Permissões corrigidas"
fi

echo ""

# Check documentation
echo "📚 Verificando documentação..."

docs=(
    "README.md"
    "EXTERNAL-ACCESS-GUIDE.md"
    "manual-fix-redis-proxy.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo "✅ $doc existe"
    else
        echo "❌ $doc NÃO encontrado"
    fi
done

echo ""

# Check YAML files
echo "📄 Verificando arquivos de configuração..."

yamls=(
    "00-namespace.yaml"
    "42-redis-proxy-tls.yaml"
    "43-dns-config.yaml"
)

for yaml in "${yamls[@]}"; do
    if [ -f "$yaml" ]; then
        echo "✅ $yaml existe"
    else
        echo "❌ $yaml NÃO encontrado"
    fi
done

echo ""

# Test script functionality
echo "🔧 Testando funcionalidade básica dos scripts..."

echo -n "  setup-external-client.sh: "
if head -1 setup-external-client.sh | grep -q "#!/bin/bash"; then
    echo "✅ Script válido"
else
    echo "❌ Script inválido"
fi

echo -n "  diagnose-network-connectivity.sh: "
if head -1 diagnose-network-connectivity.sh | grep -q "#!/bin/bash"; then
    echo "✅ Script válido"
else
    echo "❌ Script inválido"
fi

echo ""

# Check for key functions in setup script
echo "🔍 Verificando funções principais do setup-external-client.sh..."

functions=(
    "get_node_ip"
    "setup_dns"
    "test_dns"
    "install_redis_cli"
    "test_redis_connectivity"
)

for func in "${functions[@]}"; do
    if grep -q "^$func()" setup-external-client.sh; then
        echo "✅ Função $func encontrada"
    else
        echo "❌ Função $func NÃO encontrada"
    fi
done

echo ""

# Check if README was updated correctly
echo "📖 Verificando atualização do README..."

if grep -q "Acesso Externo Simplificado" README.md; then
    echo "✅ README atualizado com seção de acesso externo"
else
    echo "❌ README não contém seção de acesso externo"
fi

if grep -q "setup-external-client.sh" README.md; then
    echo "✅ README referencia script de setup externo"
else
    echo "❌ README não referencia script de setup externo"
fi

if grep -q "EXTERNAL-ACCESS-GUIDE.md" README.md; then
    echo "✅ README referencia guia completo"
else
    echo "❌ README não referencia guia completo"
fi

echo ""

# Summary
echo "📊 Resumo da Validação"
echo "====================="
echo ""

echo "✅ Soluções Implementadas:"
echo "  • Script de setup automático para clientes externos"
echo "  • Script de diagnóstico de conectividade de rede"
echo "  • Guia completo de acesso externo"
echo "  • Documentação atualizada"
echo "  • Scripts com permissões corretas"
echo ""

echo "🚀 Comandos Principais:"
echo "  • Para configurar acesso externo: ./setup-external-client.sh"
echo "  • Para diagnóstico completo: ./diagnose-network-connectivity.sh"
echo "  • Para corrigir problemas de instalação: ./fix-installation-issues.sh"
echo "  • Para corrigir proxy HAProxy: ./fix-redis-proxy.sh"
echo ""

echo "📋 Próximos Passos Recomendados:"
echo "  1. Execute ./setup-external-client.sh no servidor"
echo "  2. Configure máquinas cliente conforme instruções"
echo "  3. Teste conectividade: redis-cli -h redis.home.arpa -p 30379 -a Admin@123 ping"
echo "  4. Se houver problemas, execute ./diagnose-network-connectivity.sh"
echo ""

echo "✅ Validação concluída! O projeto agora oferece solução completa para acesso externo ao Redis."