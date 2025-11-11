#!/bin/bash
set -e

echo "=== Gerenciamento de Backups com Velero ==="

# Função para criar backup
create_backup() {
    local name=$1
    local namespaces=$2
    local ttl=$3
    
    echo "Criando backup: $name"
    velero backup create "$name" \
        --include-namespaces "$namespaces" \
        --ttl "$ttl" \
        --wait
}

# Função para restaurar backup
restore_backup() {
    local backup_name=$1
    local namespaces=$2
    
    echo "Restaurando backup: $backup_name"
    velero restore create --from-backup "$backup_name" \
        --include-namespaces "$namespaces" \
        --wait
}

# Função para listar backups
list_backups() {
    echo "=== Backups Disponíveis ==="
    velero backup get
    
    echo ""
    echo "=== Agendamentos de Backup ==="
    velero schedule get
    
    echo ""
    echo "=== Restaurações ==="
    velero restore get
}

# Função para verificar status do backup
check_backup_status() {
    local backup_name=$1
    
    echo "Status do backup: $backup_name"
    velero backup describe "$backup_name" --details
}

# Função para criar backup manual
manual_backup() {
    echo "Criando backup manual..."
    
    read -p "Nome do backup (deixe vazio para gerar automaticamente): " backup_name
    if [ -z "$backup_name" ]; then
        backup_name="manual-backup-$(date +%Y%m%d-%H%M%S)"
    fi
    
    read -p "Namespaces para incluir (separados por vírgula, * para todos): " namespaces
    if [ -z "$namespaces" ]; then
        namespaces="default,monitoring,production"
    fi
    
    read -p "TTL do backup (ex: 24h, 7d, 30d): " ttl
    if [ -z "$ttl" ]; then
        ttl="7d"
    fi
    
    create_backup "$backup_name" "$namespaces" "$ttl"
}

# Função para criar agendamento de backup
schedule_backup() {
    echo "Criando agendamento de backup..."
    
    read -p "Nome do agendamento: " schedule_name
    if [ -z "$schedule_name" ]; then
        schedule_name="daily-backup"
    fi
    
    read -p "Cron expression (ex: '0 2 * * *' para 2 AM diariamente): " cron
    if [ -z "$cron" ]; then
        cron="0 2 * * *"
    fi
    
    read -p "Namespaces para incluir: " namespaces
    if [ -z "$namespaces" ]; then
        namespaces="default,monitoring,production"
    fi
    
    echo "Criando agendamento: $schedule_name"
    velero schedule create "$schedule_name" \
        --schedule="$cron" \
        --include-namespaces "$namespaces" \
        --ttl "720h"  # 30 dias
}

# Função para ver logs
check_logs() {
    echo "Verificando logs do Velero..."
    kubectl logs -n velero deployment/velero -f
}

# Menu principal
show_menu() {
    echo ""
    echo "=== Gerenciamento de Backups Velero ==="
    echo "1. Listar backups e agendamentos"
    echo "2. Criar backup manual"
    echo "3. Criar agendamento de backup"
    echo "4. Verificar status de um backup"
    echo "5. Restaurar backup"
    echo "6. Ver logs do Velero"
    echo "7. Executar backup de exemplo"
    echo "8. Sair"
    echo ""
}

# Função para executar backup de exemplo
example_backup() {
    echo "Executando backup de exemplo..."
    
    # Criar backup de exemplo
    velero backup create example-backup-$(date +%Y%m%d-%H%M%S) \
        --include-namespaces default,monitoring \
        --ttl 24h \
        --wait
    
    echo "Backup de exemplo criado com sucesso!"
}

# Verificar se Velero está instalado
if ! command -v velero &> /dev/null; then
    echo "Velero CLI não encontrado. Por favor, execute install-velero.sh primeiro."
    exit 1
fi

# Loop principal
while true; do
    show_menu
    read -p "Escolha uma opção: " choice
    
    case $choice in
        1)
            list_backups
            ;;
        2)
            manual_backup
            ;;
        3)
            schedule_backup
            ;;
        4)
            read -p "Nome do backup: " backup_name
            if [ -n "$backup_name" ]; then
                check_backup_status "$backup_name"
            else
                echo "Nome do backup é obrigatório"
            fi
            ;;
        5)
            read -p "Nome do backup para restaurar: " backup_name
            read -p "Namespaces para restaurar (deixe vazio para todos): " namespaces
            if [ -n "$backup_name" ]; then
                restore_backup "$backup_name" "$namespaces"
            else
                echo "Nome do backup é obrigatório"
            fi
            ;;
        6)
            check_logs
            ;;
        7)
            example_backup
            ;;
        8)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida. Por favor, tente novamente."
            ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done