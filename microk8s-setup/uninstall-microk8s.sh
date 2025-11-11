#!/bin/bash

# Script para remover completamente o MicroK8s
# Este script remove a instalação do MicroK8s e todos os dados associados

set -e

echo "========================================"
echo "    REMOÇÃO COMPLETA DO MICROK8S"
echo "========================================"
echo

# Função para verificar se o comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para parar serviços com timeout
stop_service_with_timeout() {
    local service=$1
    local timeout=30
    
    echo "Parando serviço $service..."
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        sudo systemctl stop "$service" || true
        
        # Aguardar até o serviço parar ou timeout
        local count=0
        while systemctl is-active --quiet "$service" 2>/dev/null && [ $count -lt $timeout ]; do
            sleep 1
            count=$((count + 1))
        done
        
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "⚠️  Serviço $service não parou no tempo esperado, forçando..."
            sudo systemctl kill "$service" || true
            sleep 2
        fi
    fi
}

# Verificar se o usuário tem certeza
echo "⚠️  ATENÇÃO: Este script irá remover COMPLETAMENTE o MicroK8s e todos os dados!"
echo "   - Todos os pods, serviços e volumes serão perdidos"
echo "   - Configurações e certificados serão removidos"
echo "   - Dados persistentes serão apagados"
echo
read -p "Tem certeza que deseja continuar? (digite 'SIM' para confirmar): " confirm

if [ "$confirm" != "SIM" ]; then
    echo "❌ Operação cancelada pelo usuário."
    exit 0
fi

echo
echo "🔄 Iniciando remoção do MicroK8s..."
echo

# 1. Parar o MicroK8s se estiver rodando
if command_exists microk8s; then
    echo "📋 Verificando status do MicroK8s..."
    
    # Tentar parar o MicroK8s normalmente
    echo "🛑 Parando MicroK8s..."
    microk8s stop || true
    
    # Aguardar um pouco
    sleep 5
    
    # Verificar se ainda está rodando
    if microk8s status --wait-ready --timeout 5 >/dev/null 2>&1; then
        echo "⚠️  MicroK8s ainda está rodando, tentando parada forçada..."
        sudo pkill -f microk8s || true
        sleep 3
    fi
fi

# 2. Parar serviços do sistema relacionados
echo "🛑 Parando serviços do sistema..."
services=(
    "snap.microk8s.daemon-apiserver"
    "snap.microk8s.daemon-controller-manager"
    "snap.microk8s.daemon-scheduler"
    "snap.microk8s.daemon-kubelet"
    "snap.microk8s.daemon-proxy"
    "snap.microk8s.daemon-etcd"
    "snap.microk8s.daemon-containerd"
)

for service in "${services[@]}"; do
    stop_service_with_timeout "$service"
done

# 3. Remover o snap do MicroK8s
echo "📦 Removendo snap do MicroK8s..."
if snap list | grep -q microk8s; then
    sudo snap remove microk8s --purge || {
        echo "⚠️  Falha na remoção normal, tentando remoção forçada..."
        sudo snap remove microk8s --purge --force || true
    }
else
    echo "ℹ️  Snap do MicroK8s não encontrado."
fi

# 4. Limpar diretórios e arquivos residuais
echo "🧹 Limpando arquivos e diretórios residuais..."

# Diretórios comuns do MicroK8s
directories_to_remove=(
    "/var/snap/microk8s"
    "/snap/microk8s"
    "/var/lib/microk8s"
    "/etc/microk8s"
    "/home/$USER/.kube"
    "/root/.kube"
    "/tmp/microk8s*"
)

for dir in "${directories_to_remove[@]}"; do
    if [ -d "$dir" ] || [ -f "$dir" ]; then
        echo "  Removendo: $dir"
        sudo rm -rf "$dir" 2>/dev/null || true
    fi
done

# 5. Limpar configurações de rede
echo "🌐 Limpando configurações de rede..."

# Remover interfaces de rede do MicroK8s
interfaces=$(ip link show | grep -E "(cni0|flannel|vxlan.calico|docker0|br-)" | cut -d: -f2 | cut -d@ -f1 | tr -d ' ' || true)
for interface in $interfaces; do
    if [ -n "$interface" ]; then
        echo "  Removendo interface: $interface"
        sudo ip link delete "$interface" 2>/dev/null || true
    fi
done

# Limpar regras de iptables relacionadas ao Kubernetes
echo "🔥 Limpando regras de iptables..."
sudo iptables -t nat -F || true
sudo iptables -t mangle -F || true
sudo iptables -F || true
sudo iptables -X || true

# 6. Limpar processos residuais
echo "🔄 Verificando processos residuais..."
processes=$(ps aux | grep -E "(microk8s|containerd|kubelet|kube-)" | grep -v grep | awk '{print $2}' || true)
if [ -n "$processes" ]; then
    echo "  Terminando processos residuais..."
    echo "$processes" | xargs sudo kill -9 2>/dev/null || true
fi

# 7. Limpar montagens
echo "💾 Verificando montagens..."
mounts=$(mount | grep microk8s | awk '{print $3}' || true)
for mount_point in $mount_points; do
    if [ -n "$mount_point" ]; then
        echo "  Desmontando: $mount_point"
        sudo umount "$mount_point" 2>/dev/null || true
    fi
done

# 8. Limpar grupos e usuários (se criados)
echo "👥 Verificando usuários e grupos..."
if getent group microk8s >/dev/null 2>&1; then
    echo "  Removendo grupo microk8s..."
    sudo groupdel microk8s 2>/dev/null || true
fi

# 9. Limpar aliases e configurações do shell
echo "🐚 Limpando configurações do shell..."
shell_files=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
    "/root/.bashrc"
    "/root/.zshrc"
    "/root/.profile"
)

for file in "${shell_files[@]}"; do
    if [ -f "$file" ]; then
        # Remover aliases do kubectl relacionados ao microk8s
        sudo sed -i '/microk8s/d' "$file" 2>/dev/null || true
        sudo sed -i '/alias kubectl/d' "$file" 2>/dev/null || true
    fi
done

# 10. Verificação final
echo
echo "🔍 Verificação final..."
echo

# Verificar se o comando microk8s ainda existe
if command_exists microk8s; then
    echo "❌ ERRO: Comando microk8s ainda está disponível!"
    echo "   Pode ser necessário reiniciar o sistema ou remover manualmente."
else
    echo "✅ Comando microk8s removido com sucesso."
fi

# Verificar diretórios residuais
residual_dirs=$(find /var /snap /etc -name "*microk8s*" -type d 2>/dev/null || true)
if [ -n "$residual_dirs" ]; then
    echo "⚠️  Diretórios residuais encontrados:"
    echo "$residual_dirs"
    echo "   Considere removê-los manualmente se necessário."
else
    echo "✅ Nenhum diretório residual encontrado."
fi

# Verificar processos residuais
residual_processes=$(ps aux | grep -E "(microk8s|containerd|kubelet)" | grep -v grep || true)
if [ -n "$residual_processes" ]; then
    echo "⚠️  Processos residuais encontrados:"
    echo "$residual_processes"
    echo "   Considere reiniciar o sistema."
else
    echo "✅ Nenhum processo residual encontrado."
fi

echo
echo "========================================"
echo "         REMOÇÃO CONCLUÍDA"
echo "========================================"
echo
echo "✅ MicroK8s foi removido do sistema."
echo
echo "📋 Próximos passos recomendados:"
echo "   1. Reiniciar o sistema para garantir limpeza completa"
echo "   2. Verificar se não há configurações residuais em ~/.kube/"
echo "   3. Se necessário, reinstalar usando ./setup-complete.sh"
echo
echo "⚠️  Nota: Se você planeja reinstalar o MicroK8s:"
echo "   - Aguarde pelo menos 2 minutos após a remoção"
echo "   - Considere reiniciar o sistema antes da reinstalação"
echo "   - Use ./setup-complete.sh para uma instalação limpa"
echo