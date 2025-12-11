# Configuração do K3s

Este diretório contém scripts para automatizar a instalação e configuração de um cluster Kubernetes com K3s.

## Pré-requisitos

-   Uma máquina Linux (Ubuntu, Debian, CentOS, etc.)
-   Acesso `root` ou um usuário com privilégios `sudo`
-   `curl` instalado no sistema
-   Mínimo de 512MB RAM (recomendado: 1GB+)
-   Mínimo de 1 CPU core

## Scripts

### `install-k3s.sh`

Este script instala o K3s na sua máquina. Ele foi configurado para:

-   **Traefik habilitado**: O controlador de Ingress padrão do K3s (Traefik) está habilitado e pronto para uso
-   **ServiceLB habilitado**: O balanceador de carga integrado está habilitado para serviços do tipo LoadBalancer
-   **Kubeconfig legível**: O arquivo `kubeconfig` é criado com permissões 644 para facilitar o acesso inicial

**Uso:**

```bash
chmod +x install-k3s.sh
sudo ./install-k3s.sh
```

**O que o script faz:**
- Baixa e instala o K3s via script oficial
- Configura o serviço systemd do K3s
- Cria o kubeconfig em `/etc/rancher/k3s/k3s.yaml`
- Registra toda a saída em `/var/log/k3s-install.log`

### `configure-k3s.sh`

Após a instalação, este script configura o `kubectl` para o seu usuário. Ele:

-   Copia o arquivo `k3s.yaml` para `~/.kube/config` do usuário que executou sudo
-   Ajusta as permissões e ownership corretamente
-   Faz backup do kubeconfig existente (se houver)
-   Testa a configuração do kubectl

**Uso:**

```bash
chmod +x configure-k3s.sh
sudo ./configure-k3s.sh
```

**Importante**: Este script deve ser executado com `sudo` por um usuário não-root. Não execute como root diretamente.

### `uninstall-k3s.sh`

Este script remove completamente o K3s do seu sistema, incluindo:

-   Execução do script de desinstalação oficial do K3s
-   Limpeza de diretórios residuais (`/etc/rancher`, `/var/lib/rancher`, etc.)
-   Remoção de binários e symlinks
-   Parada de serviços relacionados

**Uso:**

```bash
chmod +x uninstall-k3s.sh
sudo ./uninstall-k3s.sh
```

**Atenção**: Este script pedirá confirmação antes de prosseguir. A operação é destrutiva e todos os workloads em execução serão removidos.

## Passos para a Instalação

### Instalação Rápida

1.  **Tornar os scripts executáveis:**

    ```bash
    cd k3s-setup
    chmod +x *.sh
    ```

2.  **Instalar o K3s:**

    ```bash
    sudo ./install-k3s.sh
    ```

3.  **Configurar o kubectl:**

    ```bash
    sudo ./configure-k3s.sh
    ```

4.  **Verificar a instalação:**

    ```bash
    kubectl get nodes
    ```

    A saída deve mostrar o nó do seu cluster com o status `Ready`.

    ```bash
    kubectl get pods -A
    ```

    Deve mostrar os pods do sistema em execução (CoreDNS, etc.).

## Próximos Passos

Após a instalação bem-sucedida do K3s:

1.  **Verificar Traefik:**
    ```bash
    kubectl get pods -n kube-system | grep traefik
    kubectl get svc -n kube-system traefik
    ```

2.  **Instalar Cert-Manager** (para certificados TLS):
    ```bash
    cd ../certs
    kubectl apply -f .
    ```

3.  **Deploy suas aplicações:**
    - ArgoCD: `cd ../../argocd`
    - MinIO: `cd ../../minio`
    - Redis: `cd ../../redis`
    - RabbitMQ: `cd ../../rabbitmq`
    - Monitoring: `cd ../../monitoring`

**Nota sobre Ingress Controllers:**
- K3s vem com Traefik pré-instalado como controlador de Ingress
- Se você preferir usar NGINX Ingress Controller, você pode desabilitar o Traefik reinstalando com a flag `--disable traefik` ou rodando ambos (não recomendado)

## Troubleshooting

### K3s não inicia

Verifique os logs do serviço:
```bash
sudo journalctl -u k3s -f
```

### kubectl não funciona

Verifique se o kubeconfig está configurado:
```bash
ls -la ~/.kube/config
echo $KUBECONFIG
```

Se necessário, configure manualmente:
```bash
export KUBECONFIG=~/.kube/config
```

### Reiniciar o K3s

```bash
sudo systemctl restart k3s
```

### Verificar status do K3s

```bash
sudo systemctl status k3s
```

## Logs

Todos os scripts mantêm logs em:
- Instalação: `/var/log/k3s-install.log`
- Desinstalação: `/var/log/k3s-uninstall.log`

## Arquitetura

O K3s instalado inclui os seguintes componentes habilitados:

### Componentes Core
- **CoreDNS**: Para resolução de nomes DNS no cluster
- **Local Path Provisioner**: Para provisionamento automático de volumes persistentes
- **Kube-proxy**: Para roteamento de rede dentro do cluster
- **Metrics Server**: Para métricas de recursos (CPU, memória)

### Componentes de Rede
- **Traefik Ingress Controller**: Controlador de Ingress padrão para expor serviços HTTP/HTTPS
  - Acesso via NodePort (portas 80 e 443)
  - Suporte para IngressRoute (CRDs do Traefik) e Ingress (padrão Kubernetes)
  - Dashboard disponível em `traefik.kube-system.svc.cluster.local`

- **ServiceLB (Klipper)**: Balanceador de carga para bare-metal
  - Implementa serviços do tipo LoadBalancer
  - Atribui IPs do node para serviços LoadBalancer
  - Ideal para ambientes sem cloud provider

### Diferenças do K3s padrão
Nesta instalação, mantivemos todos os componentes padrão do K3s habilitados para simplificar o setup e aproveitar a integração nativa.
