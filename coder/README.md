# 🚀 Coder on MicroK8s

Este projeto configura o [Coder](https://coder.com/) em um cluster MicroK8s, fornecendo um ambiente de desenvolvimento remoto completo e seguro.

## 📋 Índice

- [Pré-requisitos](#-pré-requisitos)
- [Instalação Rápida](#-instalação-rápida)
- [Configuração Homelab](#-configuração-homelab)
- [Scripts Disponíveis](#-scripts-disponíveis)
- [Configuração](#-configuração)
- [Uso](#-uso)
- [Monitoramento](#-monitoramento)
- [Troubleshooting](#-troubleshooting)
- [Remoção](#-remoção)

## 🔧 Pré-requisitos

### Sistema Operacional
- Ubuntu 20.04+ ou distribuição Linux compatível
- Pelo menos 4GB de RAM disponível
- 20GB de espaço em disco livre

### MicroK8s
1. **Instalar MicroK8s** (se não estiver instalado):
   ```bash
   sudo snap install microk8s --classic
   sudo usermod -a -G microk8s $USER
   newgrp microk8s
   ```

2. **Verificar status**: `microk8s status`

3. **Habilitar addons essenciais**:
   ```bash
   microk8s enable dns
   microk8s enable ingress
   microk8s enable cert-manager
   microk8s enable helm3
   ```

4. **Habilitar MetalLB** (opcional, para LoadBalancer):
   ```bash
   microk8s enable metallb:10.64.140.43-10.64.140.49
   ```
   > **Nota**: Ajuste o range de IPs conforme sua rede

### Verificação dos Pré-requisitos
Execute o script de verificação:
```bash
./00-prereqs.sh
```

## ⚡ Instalação Rápida

1. **Clone este repositório**:
   ```bash
   git clone <repository-url>
   cd k8s/coder
   ```

2. **Torne os scripts executáveis**:
   ```bash
   chmod +x *.sh
   ```

3. **Execute a instalação**:
   ```bash
   ./00-prereqs.sh    # Configura pré-requisitos
   ./10-install-helm.sh  # Instala o Coder via Helm
   ```

4. **Verifique o status**:
   ```bash
   ./90-status.sh
   ```

## 🏠 Configuração Homelab

**Para ambientes homelab sem IP público**, este projeto inclui configurações específicas:

- **Certificados self-signed** em vez de Let's Encrypt
- **Domínio local**: `coder.home.arpa`
- **Configuração DNS local** necessária

### Configuração Rápida para Homelab

1. **Configure DNS local**:
   ```bash
   # Linux/macOS - adicionar ao /etc/hosts
   echo "$(microk8s kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}') coder.home.arpa" | sudo tee -a /etc/hosts
   
   # Windows - editar C:\Windows\System32\drivers\etc\hosts
   # <IP-DO-MICROK8S> coder.home.arpa
   ```

https://coder.home.arpa
   > ⚠️ **Nota**: Aceite o certificado self-signed no navegador

3. **Alternativa via Port-Forward**:
   ```bash
   microk8s kubectl -n coder port-forward service/coder 8080:80
   # Acesse: http://localhost:8080
   ```

📖 **Guia completo**: Veja [HOMELAB-SETUP.md](HOMELAB-SETUP.md) para configurações detalhadas de homelab.

## 📜 Scripts Disponíveis

| Script | Descrição | Uso |
|--------|-----------|-----|
| `00-prereqs.sh` | Configura namespace, certificados e pré-requisitos | `./00-prereqs.sh` |
| `10-install-helm.sh` | Instala o Coder usando Helm | `./10-install-helm.sh` |
| `20-upgrade-helm.sh` | Atualiza a instalação do Coder | `./20-upgrade-helm.sh` |
| `90-status.sh` | Mostra status detalhado da instalação | `./90-status.sh` |
| `99-remove-coder.sh` | Remove completamente o Coder | `./99-remove-coder.sh [--force]` |

### Detalhes dos Scripts

#### 🔧 00-prereqs.sh
- Verifica se MicroK8s está rodando
- Cria namespace `coder`
- Aplica configurações de certificados TLS
- Configura ingress e secrets necessários

#### 📦 10-install-helm.sh
- Adiciona repositório Helm do Coder
- Instala/atualiza o Coder com configurações personalizadas
- Verifica se a instalação foi bem-sucedida
- Mostra instruções de acesso

#### 🔄 20-upgrade-helm.sh
- Atualiza repositórios Helm
- Faz backup das configurações atuais
- Executa upgrade da release
- Verifica saúde pós-upgrade

#### 📊 90-status.sh
- Status completo de todos os recursos
- Informações de Helm releases
- Status de certificados TLS
- Logs da aplicação
- Verificações de conectividade
- Comandos úteis para diagnóstico

#### 🗑️ 99-remove-coder.sh
- Remove release Helm
- Limpa recursos residuais
- Remove PVCs e dados persistentes
- Opção `--force` para remoção sem confirmação

## ⚙️ Configuração

### Arquivos de Configuração

- **`values/coder-values.yaml`**: Configurações principais do Helm
- **`secrets/`**: Secrets e certificados
- **`ingress/`**: Configurações de ingress
- **`cert-manager/`**: Certificados TLS

### Personalização

1. **Editar valores do Helm**:
   ```bash
   nano values/coder-values.yaml
   ```

2. **Configurar domínio personalizado**:
   - Edite `ingress/coder-ingress.yaml`
   - Atualize `cert-manager/coder-certificate.yaml`

3. **Ajustar recursos**:
   - Modifique `requests` e `limits` em `coder-values.yaml`

## 🎯 Uso

### Acessando o Coder

1. **Via Ingress** (recomendado):
   ```
   https://coder.home.arpa
   ```
   > **Nota**: Configure seu `/etc/hosts` ou DNS para apontar para o IP do cluster

2. **Via Port-Forward**:
   ```bash
   microk8s kubectl -n coder port-forward service/coder 8080:80
   ```
   Acesse: `http://localhost:8080`

### Primeiro Acesso

1. Acesse a interface web
2. Crie uma conta de administrador
3. Configure templates de workspace
4. Convide usuários (se necessário)

### Comandos Úteis

```bash
# Ver logs em tempo real
microk8s kubectl -n coder logs -f deployment/coder

# Reiniciar deployment
microk8s kubectl -n coder rollout restart deployment/coder

# Listar workspaces
microk8s kubectl -n coder get pods -l app.kubernetes.io/name=coder

# Verificar certificados
microk8s kubectl -n coder get certificates
```

## 📊 Monitoramento

### Status da Aplicação
```bash
./90-status.sh
```

### Métricas e Logs
```bash
# CPU e memória dos pods
microk8s kubectl -n coder top pods

# Eventos do namespace
microk8s kubectl -n coder get events --sort-by='.lastTimestamp'

# Logs detalhados
microk8s kubectl -n coder logs deployment/coder --previous
```

## 🔍 Troubleshooting

### Problemas Comuns

#### Pod não inicia
```bash
# Verificar eventos
microk8s kubectl -n coder describe pod <pod-name>

# Verificar logs
microk8s kubectl -n coder logs <pod-name>
```

#### Certificado TLS não funciona
```bash
# Status do certificado
microk8s kubectl -n coder describe certificate coder-tls

# Logs do cert-manager
microk8s kubectl -n cert-manager logs deployment/cert-manager
```

#### Ingress não responde
```bash
# Verificar ingress
microk8s kubectl -n coder describe ingress coder

# Status do nginx-ingress
microk8s kubectl -n ingress get pods
```

#### Problemas de conectividade
```bash
# Testar conectividade interna
microk8s kubectl -n coder exec -it <pod-name> -- wget -qO- http://coder:80

# Verificar DNS
microk8s kubectl -n coder exec -it <pod-name> -- nslookup coder
```

### Logs de Diagnóstico
```bash
# Coletar logs completos
microk8s kubectl -n coder logs deployment/coder > coder-logs.txt

# Status completo do cluster
microk8s kubectl get all -n coder > coder-status.txt
```

## 🗑️ Remoção

### Remoção Completa
```bash
./99-remove-coder.sh
```

### Remoção Forçada (sem confirmação)
```bash
./99-remove-coder.sh --force
```

### Remoção Manual
```bash
# Remover release Helm
microk8s helm3 uninstall coder -n coder

# Remover namespace
microk8s kubectl delete namespace coder

# Limpar PVs órfãos
microk8s kubectl get pv | grep coder | awk '{print $1}' | xargs microk8s kubectl delete pv
```

## 📚 Recursos Adicionais

- [Documentação oficial do Coder](https://coder.com/docs)
- [Helm Chart do Coder](https://github.com/coder/coder/tree/main/helm)
- [Documentação do MicroK8s](https://microk8s.io/docs)
- [Troubleshooting do cert-manager](https://cert-manager.io/docs/troubleshooting/)

## 🤝 Contribuição

Para contribuir com este projeto:

1. Faça um fork do repositório
2. Crie uma branch para sua feature
3. Teste suas alterações
4. Envie um pull request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para detalhes.

---

**Nota**: Este projeto é mantido pela comunidade e não é oficialmente suportado pela Coder Technologies Inc.