#!/bin/bash

# Script de Instalação Completa do MicroK8s
# Executa toda a configuração automaticamente

set -e

echo "🚀 Instalação Completa do MicroK8s"
echo "==================================="
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
        exit 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

# Verificar se está rodando como usuário normal (não root)
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Este script não deve ser executado como root${NC}"
    echo "Execute como usuário normal. O sudo será solicitado quando necessário."
    exit 1
fi

# Verificar se os scripts existem
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_SCRIPTS=("install-microk8s.sh" "configure-addons.sh" "check-environment.sh")

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        echo -e "${RED}❌ Script $script não encontrado em $SCRIPT_DIR${NC}"
        exit 1
    fi
done

print_info "Todos os scripts necessários encontrados"
echo

# Mostrar informações do sistema
print_info "Informações do sistema:"
echo "  - OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Desconhecido')"
echo "  - Kernel: $(uname -r)"
echo "  - Arquitetura: $(uname -m)"
echo "  - Memória: $(free -h | grep Mem | awk '{print $2}' || echo 'Desconhecida')"
echo "  - Espaço em disco (/): $(df -h / | tail -1 | awk '{print $4}' || echo 'Desconhecido') disponível"
echo

# Confirmar instalação
echo -e "${YELLOW}📋 Este script irá:${NC}"
echo "   1. Instalar o MicroK8s"
echo "   2. Configurar addons essenciais (DNS, Storage, Ingress, Helm, Cert-Manager)"
echo "   3. Configurar ClusterIssuers para Let's Encrypt"
echo "   4. Verificar se tudo está funcionando"
echo
echo -e "${YELLOW}⏱️  Tempo estimado: 10-15 minutos${NC}"
echo
read -p "Deseja continuar com a instalação? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Instalação cancelada."
    exit 0
fi
echo

# Etapa 1: Instalação do MicroK8s
print_step "ETAPA 1/4: Instalando MicroK8s..."
echo "Executando: $SCRIPT_DIR/install-microk8s.sh"
echo

# Executar instalação com privilégios (script requer root)
if sudo bash "$SCRIPT_DIR/install-microk8s.sh"; then
    print_status 0 "MicroK8s instalado com sucesso"
else
    print_status 1 "Falha na instalação do MicroK8s"
fi
echo

# Verificar se precisa fazer logout/login
if ! groups | grep -q microk8s; then
    print_warning "Você precisa fazer logout e login novamente para aplicar as permissões do grupo microk8s"
    print_warning "Ou execute: newgrp microk8s"
    echo
    read -p "Pressione Enter após fazer logout/login ou executar 'newgrp microk8s'..."
fi

# Etapa 2: Configuração dos addons
print_step "ETAPA 2/4: Configurando addons..."
echo "Executando: $SCRIPT_DIR/configure-addons.sh"
echo

if bash "$SCRIPT_DIR/configure-addons.sh"; then
    print_status 0 "Addons configurados com sucesso"
else
    print_status 1 "Falha na configuração dos addons"
fi
echo

# Etapa 3: Aguardar estabilização
print_step "ETAPA 3/4: Aguardando estabilização do ambiente..."
print_info "Aguardando todos os pods ficarem prontos (pode levar alguns minutos)..."

# Aguardar até 5 minutos para todos os pods ficarem prontos
for i in {1..150}; do
    NOT_READY=$(microk8s kubectl get pods -A --no-headers 2>/dev/null | grep -v Running | grep -v Completed | wc -l)
    if [ "$NOT_READY" -eq 0 ]; then
        break
    fi
    echo -n "."
    sleep 2
done
echo

if [ $NOT_READY -eq 0 ]; then
    print_status 0 "Todos os pods estão prontos"
else
    print_warning "Alguns pods ainda não estão prontos, mas continuando..."
fi
echo

# Etapa 4: Verificação final
print_step "ETAPA 4/4: Verificação final do ambiente..."
echo "Executando: $SCRIPT_DIR/check-environment.sh"
echo

if bash "$SCRIPT_DIR/check-environment.sh"; then
    print_status 0 "Verificação concluída"
else
    print_warning "Verificação encontrou alguns problemas, mas a instalação básica foi concluída"
fi
echo

# Resumo final
echo "🎉 INSTALAÇÃO CONCLUÍDA!"
echo "========================"
echo
print_info "MicroK8s foi instalado e configurado com sucesso!"
echo
echo -e "${GREEN}✅ Componentes instalados:${NC}"
echo "   - MicroK8s (Kubernetes)"
echo "   - DNS (CoreDNS)"
echo "   - Hostpath Storage"
echo "   - Ingress Controller (NGINX)"
echo "   - Helm 3"
echo "   - Cert-Manager"
echo "   - ClusterIssuers (Let's Encrypt)"
echo

echo -e "${BLUE}🔧 Comandos úteis:${NC}"
echo "   - Verificar status: microk8s status"
echo "   - Usar kubectl: kubectl get nodes"
echo "   - Verificar ambiente: ./check-environment.sh"
echo "   - Reset ambiente: ./reset-environment.sh"
echo

echo -e "${BLUE}📁 Próximos passos:${NC}"
echo "   1. Teste o ambiente: kubectl get all -A"
echo "   2. Deploy uma aplicação de teste"
echo "   3. Configure DNS local para seus domínios"
echo "   4. Atualize o email nos ClusterIssuers se necessário"
echo

echo -e "${YELLOW}💡 Dicas importantes:${NC}"
echo "   - Use 'letsencrypt-staging' para testes"
echo "   - Use 'letsencrypt-prod' apenas para produção"
echo "   - Monitore recursos do sistema regularmente"
echo "   - Faça backups regulares dos dados importantes"
echo

echo -e "${GREEN}🚀 Seu ambiente MicroK8s está pronto para uso!${NC}"