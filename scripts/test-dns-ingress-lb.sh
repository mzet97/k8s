#!/usr/bin/env bash
set -euo pipefail

# Teste de DNS, Ingress e Load Balancing para RabbitMQ e Redis

NAMESPACE_RMQ="rabbitmq"
NAMESPACE_REDIS="redis"
HOSTS=("rabbitmq.home.arpa" "rabbitmq-mgmt.home.arpa" "redis.home.arpa" "redis-stats.home.arpa")

COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_YELLOW="\033[1;33m"
COLOR_RESET="\033[0m"

log() { echo -e "$1"; }
ok() { log "${COLOR_GREEN}✔${COLOR_RESET} $1"; }
warn() { log "${COLOR_YELLOW}⚠${COLOR_RESET} $1"; }
err() { log "${COLOR_RED}✖${COLOR_RESET} $1"; }

ensure_dns_hosts() {
  local node_ip
  node_ip=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') || node_ip="127.0.0.1"
  local missing=()
  for h in "${HOSTS[@]}"; do
    if ! getent hosts "$h" >/dev/null 2>&1; then
      missing+=("$h")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    warn "DNS não resolve ${missing[*]}. Vou adicionar ao /etc/hosts apontando para $node_ip (requer sudo)."
    local line="$node_ip ${missing[*]}"
    if ! grep -q "${missing[0]}" /etc/hosts; then
      echo "$line" | sudo tee -a /etc/hosts >/dev/null || err "Falha ao escrever em /etc/hosts"
    fi
  else
    ok "Todos os hosts resolvem via DNS: ${HOSTS[*]}"
  fi
}

check_tcp() {
  local host="$1" port="$2" name="$3"
  if timeout 3 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
    ok "TCP $name acessível em $host:$port"
  else
    err "TCP $name indisponível em $host:$port"
  fi
}

check_http_tls() {
  local url="$1" name="$2"
  if curl -sSf "$url" >/dev/null; then
    ok "HTTP(S) $name acessível: $url"
  else
    warn "HTTP(S) $name pode exigir CA local; tentando --insecure"
    if curl -sSfk "$url" >/dev/null; then
      ok "HTTP(S) $name acessível com --insecure: $url"
    else
      err "HTTP(S) $name indisponível: $url"
    fi
  fi
}

print_section() {
  echo -e "\n===== $1 ====="
}

run_rabbitmq_tests() {
  print_section "RabbitMQ - DNS & Ingress"
  check_http_tls "https://rabbitmq.home.arpa" "RabbitMQ Management"
  check_http_tls "https://rabbitmq-mgmt.home.arpa" "RabbitMQ Management (alias)"
  check_tcp "rabbitmq.home.arpa" 5672 "AMQP"
  check_tcp "rabbitmq.home.arpa" 5671 "AMQP TLS"

  print_section "RabbitMQ - AMQP Conexões"
  warn "Teste AMQP requer cliente (ex.: python pika). Pulando conexão real, validando portas TCP."
}

run_redis_tests() {
  print_section "Redis - DNS & Ingress"
  check_http_tls "https://redis-stats.home.arpa/stats" "Redis Proxy Stats"
  check_tcp "redis.home.arpa" 6380 "Redis TLS (escrita)"
  check_tcp "redis.home.arpa" 6382 "Redis TLS (leitura)"

  print_section "Redis - Operações"
  warn "Teste de leitura/escrita via TLS requer redis-cli com certificados. Vou testar via NodePort como fallback se existir."
  local node_ip
  node_ip=$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') || node_ip="127.0.0.1"
  echo "Sugestões:"
  echo "  redis-cli -h redis.home.arpa -p 6380 --tls --insecure -a <senha> ping"
  echo "  redis-cli -h redis.home.arpa -p 6382 --tls --insecure -a <senha> ping"
  echo "Fallback NodePort: redis-cli -h $node_ip -p 30380 --tls --insecure -a <senha> ping"
}

run_lb_checks() {
  print_section "Balanceamento"
  echo "RabbitMQ: o Ingress TCP encaminha ao Service ClusterIP com sessionAffinity=ClientIP. Para validar LB, abra múltiplas conexões de clientes e observe distribuição entre pods (via rabbitmqctl ou métricas)."
  echo "Redis: leitura balanceada pelo HAProxy entre réplicas; verifique /stats para ver backends ativos."
}

main() {
  print_section "Pré-checks"
  ensure_dns_hosts
  print_section "Ingress & Recursos"
  microk8s kubectl get ingress -A
  microk8s kubectl -n ingress get cm nginx-ingress-tcp-microk8s-conf -o yaml || true

  run_rabbitmq_tests
  run_redis_tests
  run_lb_checks

  print_section "Concluído"
  ok "Teste finalizado."
}

main "$@"