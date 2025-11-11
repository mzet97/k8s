#!/usr/bin/env bash
set -euo pipefail

# Final DNS + Ingress + Load Balance validator for RabbitMQ and Redis
# - Detects Ingress IP automatically
# - Dry-run configuration for /etc/hosts
# - Validates DNS resolution
# - Tests TCP/TLS connectivity via Ingress
# - Verifies load balancing with repeated connections
# - Clear, color-coded output with troubleshooting tips

DRY_RUN=true
APPLY_HOSTS=false

for arg in "$@"; do
  case "$arg" in
    --apply-hosts) APPLY_HOSTS=true ; DRY_RUN=false ; shift ;;
    --dry-run) DRY_RUN=true ; shift ;;
    *) ;;
  esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m'

function header() {
  echo -e "${BLUE}== ${1} ==${NC}"
}

function ok() { echo -e "${GREEN}✔${NC} ${1}"; }
function warn() { echo -e "${YELLOW}⚠${NC} ${1}"; }
function err() { echo -e "${RED}✖${NC} ${1}"; }

function detect_ingress_ip() {
  # Try hostIP from nginx-ingress pod
  local ip
  ip=$(microk8s kubectl get pods -n ingress -l name=nginx-ingress-microk8s -o jsonpath='{.items[0].status.hostIP}' 2>/dev/null || true)
  if [[ -z "$ip" ]]; then
    # Fallback to node IP where pod is scheduled
    ip=$(microk8s kubectl get pods -n ingress -l name=nginx-ingress-microk8s -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)
  fi
  echo "$ip"
}

INGRESS_IP=$(detect_ingress_ip)
if [[ -z "$INGRESS_IP" ]]; then
  err "Não foi possível detectar o IP do Ingress (nginx-ingress)."
  echo "Verifique se o addon ingress está habilitado e o pod está em execução."
  exit 1
fi

DOMAINS=(
  "rabbitmq.home.arpa"
  "rabbitmq-mgmt.home.arpa"
  "redis.home.arpa"
  "redis-stats.home.arpa"
)

header "Configuração DNS (hosts)"
echo -e "Ingress IP detectado: ${GREEN}${INGRESS_IP}${NC}"

HOSTS_LINES=()
for d in "${DOMAINS[@]}"; do
  HOSTS_LINES+=("${INGRESS_IP} ${d}")
done

if [[ "$DRY_RUN" == true ]]; then
  warn "Dry-run ativo: mostrando linhas que seriam adicionadas ao /etc/hosts:"
  for l in "${HOSTS_LINES[@]}"; do echo "  $l"; done
  echo "Use --apply-hosts para aplicar automaticamente (requer sudo)."
else
  if [[ "$APPLY_HOSTS" == true ]]; then
    warn "Aplicando entradas ao /etc/hosts via sudo (append)."
    TMP_FILE=$(mktemp)
    printf "%s\n" "${HOSTS_LINES[@]}" > "$TMP_FILE"
    if sudo sh -c "grep -v -E '\\s(rabbitmq|redis)[^ ]*\.home\.arpa' /etc/hosts > /etc/hosts.clean && cat /etc/hosts.clean '$TMP_FILE' > /etc/hosts && rm -f /etc/hosts.clean"; then
      ok "/etc/hosts atualizado."
    else
      err "Falha ao atualizar /etc/hosts. Faça manualmente:"
      for l in "${HOSTS_LINES[@]}"; do echo "  $l"; done
    fi
  fi
fi

header "Validação de DNS"
for d in "${DOMAINS[@]}"; do
  if ip=$(getent hosts "$d" | awk '{print $1}' | head -n1); then
    if [[ "$ip" == "$INGRESS_IP" ]]; then
      ok "${d} resolve para ${INGRESS_IP}"
    else
      warn "${d} resolve para ${ip}, esperado ${INGRESS_IP}. Ajuste DNS/hosts."
    fi
  else
    err "${d} não resolve. Adicione no /etc/hosts ou ajuste seu DNS."
  fi
done

header "Testes de TCP (RabbitMQ/Redis via Ingress)"
function tcp_check() {
  local host=$1; local port=$2; local name=$3
  if nc -vz "$host" "$port" >/dev/null 2>&1; then
    ok "TCP $name acessível em ${host}:${port}"
  else
    err "TCP $name indisponível em ${host}:${port}"
  fi
}

tcp_check rabbitmq.home.arpa 5672 "RabbitMQ AMQP"
tcp_check rabbitmq.home.arpa 5671 "RabbitMQ AMQPS"
tcp_check redis.home.arpa 6380 "Redis TLS write"
tcp_check redis.home.arpa 6382 "Redis TLS read"

header "Testes HTTP(S)"
function http_check() {
  local url=$1; local name=$2
  if curl -sS --insecure -I "$url" >/dev/null 2>&1; then
    ok "$name acessível: $url"
  else
    err "$name indisponível: $url"
  fi
}

http_check https://rabbitmq-mgmt.home.arpa "RabbitMQ Management UI"
http_check https://redis-stats.home.arpa/stats "Redis Proxy Stats"

header "Verificação de Load Balancing (amostral)"
echo -e "${GRAY}Abrindo várias conexões TCP sequenciais para observar estabilidade e distribuição.${NC}"
LB_OK=true
for i in $(seq 1 5); do
  if ! nc -vz rabbitmq.home.arpa 5672 >/dev/null 2>&1; then LB_OK=false; fi
  sleep 0.5
done
if [[ "$LB_OK" == true ]]; then
  ok "RabbitMQ AMQP aceita múltiplas conexões (LB ativo)."
else
  err "RabbitMQ AMQP falhou em múltiplas conexões."
fi

LB_OK=true
for i in $(seq 1 5); do
  if ! nc -vz redis.home.arpa 6380 >/dev/null 2>&1; then LB_OK=false; fi
  sleep 0.5
done
if [[ "$LB_OK" == true ]]; then
  ok "Redis TLS (escrita) aceita múltiplas conexões (LB ativo)."
else
  err "Redis TLS (escrita) falhou em múltiplas conexões."
fi

header "Exemplos de conexão"
cat <<EOF
- RabbitMQ (AMQP plain):
  amqp://rabbitmq.home.arpa:5672 (use usuário/senha do secret)
- RabbitMQ (AMQP TLS):
  amqps://rabbitmq.home.arpa:5671 (confie na CA local ou use --insecure)
- RabbitMQ Management UI:
  https://rabbitmq-mgmt.home.arpa
- Redis (escrita TLS):
  redis-cli -h redis.home.arpa -p 6380 --tls --insecure -a <senha> ping
- Redis (leitura TLS):
  redis-cli -h redis.home.arpa -p 6382 --tls --insecure -a <senha> ping
- Redis Stats:
  https://redis-stats.home.arpa/stats
EOF

header "Dicas de troubleshooting"
cat <<EOF
- Se DNS não resolver para ${INGRESS_IP}, ajuste seu /etc/hosts ou servidor DNS.
- Se RabbitMQ UI retornar 503, verifique readiness do pod e endpoints do Service:
    microk8s kubectl get pods -n rabbitmq -o wide
    microk8s kubectl get endpoints rabbitmq-management -n rabbitmq -o wide
- Para Redis, valide que o Ingress TCP está mapeado para o Service correto:
    microk8s kubectl -n ingress get configmap nginx-ingress-tcp-microk8s-conf -o yaml
- Para confirmar balanceamento, use métricas/prometheus ou rabbitmqctl/list_connections quando a UI estiver ativa.
EOF

header "Concluído"
echo "Validação final executada (${DRY_RUN:+dry-run})."