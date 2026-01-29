# Plano de Ação: Implementação do Kong Gateway no K3s

Este plano segue o padrão de arquitetura e organização utilizado no [redis](file:///home/k8s1/k8s/redis), adaptado para o **Kong Gateway (OSS/Free)** em modo DB-less ou com PostgreSQL, garantindo alta disponibilidade e segurança.

## 1. Estrutura de Diretórios e Arquivos
Seguindo a convenção numérica observada no repositório:
- `00-namespace.yaml`: Definição do namespace `kong`.
- `01-secret.yaml`: Armazenamento seguro das credenciais (`admin` / `Admin@123`) e chaves de sessão.
- `02-tls-certificates.yaml`: Emissão de certificados TLS via `cert-manager` para as interfaces de administração.
- `03-rbac.yaml`: Permissões necessárias para o Kong Ingress Controller.
- `10-configmap.yaml`: Configurações do Kong (`kong.conf`) e declarações de plugins.
- `20-kong-deployment.yaml`: Deployment do Kong Gateway e Ingress Controller.
- `30-services.yaml`: Exposição das portas de Proxy (80/443) e Admin API (8001/8002).
- `40-ingress.yaml`: Regras de roteamento para acesso externo ao Kong Manager.
- `install-kong-k3s.sh`: Script automatizado de instalação.
- `ACESSO_KONG.md`: Guia rápido de acesso e comandos de teste.

## 2. Configuração de Segurança (SRE Standard)
- **Credenciais**: Utilização do usuário `admin` com a senha `Admin@123` injetados via variáveis de ambiente (`KONG_PASSWORD`) no container do Kong Manager.
- **TLS/SSL**: Implementação de HTTPS obrigatório para a Admin API e Manager, utilizando o `ClusterIssuer: local-ca` já existente no cluster.
- **Isolamento**: Namespace dedicado para garantir que as políticas de rede não interfiram em outros serviços.

## 3. Estratégia de Deploy
1. **Modo de Operação**: Implementação inicial em modo **DB-less** para máxima performance e simplicidade (configuração via ConfigMap declarativo), com provisionamento preparado para migração para PostgreSQL se necessário.
2. **Ingress Controller**: Integração com o Traefik do K3s para gerenciar o tráfego de entrada para o próprio Kong.
3. **Persistência**: Uso de `local-path` storage class para logs persistentes, se aplicável.

## 4. Verificação de Saúde (Health Check)
- Implementação de Liveness e Readiness probes apontando para o endpoint `/status` do Kong.
- Script de teste `test-kong-gateway.sh` para validar o roteamento de APIs após o deploy.

## 5. Próximos Passos (Após Aprovação)
1. Criação da pasta `\home\k8s1\k8s\kong`.
2. Geração dos manifestos baseados no template do Redis.
3. Execução do script de instalação e validação dos logs.

**Deseja que eu prossiga com a elaboração dos manifestos ou prefere ajustar algum detalhe do plano?**