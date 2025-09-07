#!/bin/bash

# Script para tornar todos os scripts executáveis
# Execute este script primeiro após baixar os arquivos

echo "🔧 Tornando scripts executáveis..."

# Diretório atual
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Lista de scripts para tornar executáveis
SCRIPTS=(
    "install-microk8s.sh"
    "configure-addons.sh"
    "check-environment.sh"
    "reset-environment.sh"
    "setup-complete.sh"
    "uninstall-microk8s.sh"
    "make-executable.sh"
)

# Tornar scripts executáveis
for script in "${SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        chmod +x "$SCRIPT_DIR/$script"
        echo "✅ $script agora é executável"
    else
        echo "⚠️  $script não encontrado"
    fi
done

echo
echo "🎉 Todos os scripts foram configurados!"
echo
echo "💡 Próximos passos:"
echo "   - Para instalação automatizada: ./setup-complete.sh"
echo "   - Para instalação manual: ./install-microk8s.sh"
echo "   - Para verificar ambiente: ./check-environment.sh"
echo "   - Para reset completo: ./reset-environment.sh"
echo