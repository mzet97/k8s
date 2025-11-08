#!/usr/bin/env bash

# Script para tornar todos os scripts executáveis
# Facilita a configuração inicial do projeto

set -euo pipefail

echo "🔧 Tornando scripts executáveis..."
echo "================================="
echo ""

# Lista de scripts para tornar executáveis
SCRIPTS=(
    "00-prereqs.sh"
    "10-install-helm.sh"
    "20-upgrade-helm.sh"
    "90-status.sh"
    "99-remove-coder.sh"
    "make-executable.sh"
)

# Contador de sucessos
SUCCESS_COUNT=0
TOTAL_COUNT=${#SCRIPTS[@]}

echo "📋 Scripts a serem processados:"
for script in "${SCRIPTS[@]}"; do
    echo "   - $script"
done
echo ""

# Processar cada script
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if chmod +x "$script"; then
            echo "✅ $script - executável"
            ((SUCCESS_COUNT++))
        else
            echo "❌ $script - erro ao tornar executável"
        fi
    else
        echo "⚠️  $script - arquivo não encontrado"
    fi
done

echo ""
echo "📊 RESUMO"
echo "========="
echo "✅ Scripts processados com sucesso: $SUCCESS_COUNT/$TOTAL_COUNT"

if [ "$SUCCESS_COUNT" -eq "$TOTAL_COUNT" ]; then
    echo "🎉 Todos os scripts foram tornados executáveis!"
    echo ""
    echo "🚀 Próximos passos:"
    echo "   1. Execute: ./00-prereqs.sh"
    echo "   2. Execute: ./10-install-helm.sh"
    echo "   3. Verifique: ./90-status.sh"
else
    echo "⚠️  Alguns scripts não puderam ser processados."
    echo "   Verifique as permissões e tente novamente."
fi

echo ""