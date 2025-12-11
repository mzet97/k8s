# Guia de Migração: MicroK8s para K3s

Este guia descreve os passos para migrar seu ambiente de homelab de MicroK8s para K3s. A migração é motivada pela busca por uma solução mais leve, com menor consumo de recursos e um processo de setup mais simples.

## Motivação

-   **Leveza:** K3s é uma distribuição Kubernetes certificada pela CNCF, projetada para ser leve e com baixo consumo de recursos.
-   **Simplicidade:** A instalação e configuração do K3s são mais diretas.
-   **Estabilidade:** Para alguns usuários, o K3s pode oferecer uma experiência mais estável em ambientes de homelab.

## Pré-requisitos

-   Backup de todas as suas aplicações e dados importantes que estão rodando no MicroK8s. **Este processo é destrutivo e todos os dados do cluster serão perdidos.**
-   Acesso `root` ou um usuário com privilégios `sudo` na máquina do cluster.

## Passo 1: Desinstalar o MicroK8s

A primeira etapa é remover completamente o MicroK8s do sistema para evitar conflitos.

1.  **Navegue até o diretório de setup do MicroK8s:**

    ```bash
    cd ../microk8s-setup
    ```

2.  **Torne o script de desinstalação executável:**

    ```bash
    chmod +x uninstall-microk8s.sh
    ```

3.  **Execute o script de desinstalação:**

    ```bash
    sudo ./uninstall-microk8s.sh
    ```

    O script irá pedir uma confirmação. Digite `SIM` para continuar.

4.  **Reinicie o sistema (Recomendado):**

    Após a desinstalação, é altamente recomendável reiniciar a máquina para garantir que todos os componentes de rede e processos residuais do MicroK8s sejam removidos.

    ```bash
    sudo reboot
    ```

## Passo 2: Instalar o K3s

Com o sistema limpo, podemos agora instalar o K3s.

1.  **Navegue até o diretório de setup do K3s:**

    ```bash
    cd ../k3s-setup
    ```

2.  **Torne os scripts executáveis:**

    ```bash
    chmod +x *.sh
    ```

3.  **Execute o script de instalação:**

    ```bash
    sudo ./install-k3s.sh
    ```

    Este script irá baixar e instalar o K3s.

## Passo 3: Configurar o `kubectl`

Após a instalação, configure o `kubectl` para que seu usuário possa gerenciar o cluster sem `sudo`.

1.  **Execute o script de configuração:**

    ```bash
    sudo ./configure-k3s.sh
    ```

2.  **Verifique a instalação:**

    Abra um novo terminal ou recarregue seu perfil de shell (`source ~/.bashrc`, `source ~/.zshrc`, etc.) e execute:

    ```bash
    kubectl get nodes
    ```

    A saída deve mostrar o nó do seu cluster com o status `Ready`.

## Passo 4: Verificação Pós-Migração

Seu cluster K3s está agora operacional. No entanto, algumas verificações e configurações adicionais podem ser necessárias:

-   **Ingress Controller:** O K3s foi instalado sem um Ingress Controller. Você precisará instalar um, como o **NGINX Ingress Controller**, que é usado neste projeto. Navegue até o diretório `infrastructure/ingress-nginx` e aplique os manifestos.
-   **Storage Class:** K3s vem com um provisionador de armazenamento local (`local-path`). Verifique se ele atende às suas necessidades ou se você precisa de uma `StorageClass` diferente.
-   **Re-deploy de Aplicações:** Faça o deploy de suas aplicações no novo cluster K3s a partir dos seus backups ou manifestos.

## Considerações

-   **Diferenças de Comandos:** Comandos como `microk8s kubectl` são substituídos por `kubectl`.
-   **Addons:** Addons que eram habilitados no MicroK8s (como `dns`, `storage`, `ingress`) precisam ser instalados e gerenciados manualmente no K3s. O K3s já inclui CoreDNS.

A migração está concluída. Você agora tem um cluster Kubernetes mais leve e eficiente para o seu homelab.