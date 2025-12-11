#!/usr/bin/env bash
set -euo pipefail

log() { printf "%s\n" "$1"; }

DRY_RUN=${DRY_RUN:-0}
run() {
  log "$1"
  shift || true
  if [ "$DRY_RUN" = "1" ]; then
    printf "DRY-RUN: %s\n" "$*"
  else
    "$@"
  fi
}

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi
SUDO_FLAGS=${SUDO_FLAGS:-}
BACKUP_DIR=${BACKUP_DIR:-$HOME/.kube}
K3S_KUBECONFIG=${K3S_KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}
KUBECONFIG_OUT=${KUBECONFIG_OUT:-$HOME/.kube/config}

ensure_dependencies() {
  if ! command -v curl >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      run "Instalando curl (apt)" $SUDO $SUDO_FLAGS apt-get update -y
      run "Instalando curl (apt)" $SUDO $SUDO_FLAGS apt-get install -y curl
    elif command -v dnf >/dev/null 2>&1; then
      run "Instalando curl (dnf)" $SUDO $SUDO_FLAGS dnf install -y curl
    elif command -v yum >/dev/null 2>&1; then
      run "Instalando curl (yum)" $SUDO $SUDO_FLAGS yum install -y curl
    elif command -v apk >/dev/null 2>&1; then
      run "Instalando curl (apk)" $SUDO $SUDO_FLAGS apk add --no-cache curl
    else
      log "Erro: curl não encontrado e nenhum gerenciador de pacotes suportado disponível"
      exit 1
    fi
  fi
}

backup_kubeconfig() {
  if [ -f "$HOME/.kube/config" ]; then
    ts=$(date +%Y%m%d%H%M%S)
    run "Criando diretório de backup em $BACKUP_DIR" mkdir -p "$BACKUP_DIR"
    run "Backup do kubeconfig" cp "$HOME/.kube/config" "$BACKUP_DIR/config.bak.$ts"
  fi
}

uninstall_microk8s() {
  if command -v microk8s >/dev/null 2>&1; then
    run "Parando MicroK8s" $SUDO $SUDO_FLAGS microk8s stop || true
  fi

  if command -v snap >/dev/null 2>&1 && snap list microk8s >/dev/null 2>&1; then
    run "Removendo MicroK8s (snap purge)" $SUDO $SUDO_FLAGS snap remove microk8s --purge
  else
    log "Snap com pacote microk8s não encontrado; pulando remoção via snap"
  fi

  run "Removendo grupo microk8s (se existir)" $SUDO $SUDO_FLAGS groupdel microk8s || true
}

install_k3s() {
  installer='curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -'
  if [ -n "$SUDO" ]; then
    run "Instalando K3s" $SUDO $SUDO_FLAGS sh -c "$installer"
  else
    run "Instalando K3s" sh -c "$installer"
  fi
}

configure_kubectl() {
  run "Criando diretório ~/.kube" mkdir -p "$HOME/.kube"
  if [ -f "$K3S_KUBECONFIG" ]; then
    export KUBECONFIG="$K3S_KUBECONFIG"
    out_dir=$(dirname "$KUBECONFIG_OUT")
    run "Criando diretório do kubeconfig destino" mkdir -p "$out_dir"
    run "Configurando kubeconfig" $SUDO $SUDO_FLAGS sh -c "cp '$K3S_KUBECONFIG' '$KUBECONFIG_OUT' || true"
    run "Ajustando permissões do kubeconfig" $SUDO $SUDO_FLAGS sh -c "chown '$(id -u)':'$(id -g)' '$KUBECONFIG_OUT' || true"
  fi
  if ! command -v kubectl >/dev/null 2>&1 && [ -x /usr/local/bin/kubectl ]; then
    run "Criando link simbólico de kubectl" $SUDO $SUDO_FLAGS ln -sf /usr/local/bin/kubectl /usr/bin/kubectl
  fi
}

wait_k3s_ready() {
  log "Aguardando K3s ficar pronto"
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY-RUN: pulando espera do cluster"
    return 0
  fi
  for i in $(seq 1 60); do
    if kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -q "Ready"; then
      log "K3s pronto"
      return 0
    fi
    sleep 2
  done
  log "Aviso: K3s pode não estar totalmente pronto ainda"
  return 1
}

verify_k3s() {
  run "Verificando serviço k3s" $SUDO $SUDO_FLAGS systemctl is-active --quiet k3s
  log "Serviço k3s ativo"
  run "Obtendo nós" kubectl get nodes
  run "Obtendo pods" kubectl get pods -A
}

main() {
  log "Iniciando migração de MicroK8s para K3s"
  ensure_dependencies
  backup_kubeconfig
  uninstall_microk8s
  install_k3s
  configure_kubectl
  wait_k3s_ready || true
  verify_k3s
  log "Migração concluída"
}

main "$@"
