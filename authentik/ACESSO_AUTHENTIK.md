# Acesso ao Authentik

O Authentik foi configurado para utilizar um banco de dados PostgreSQL externo e o cluster Redis interno.

## URLs de Acesso

- **Interface Web**: [https://authentik.home.arpa](https://authentik.home.arpa)

## Credenciais Iniciais

Na primeira execução, o Authentik solicitará a criação de uma senha para o usuário administrador padrão (`akadmin`).

## Configurações Técnicas

- **Namespace**: `authentik`
- **Banco de Dados**: `spsql.home.arpa` (Base: `authentik`)
- **Redis**: `redis-master.redis.svc.cluster.local` (Cache/Fila)
- **Persistência**: PVC de 1Gi para `/media` (armazenamento de avatares/logos)

## Comandos Úteis

- **Verificar Status**:
  ```bash
  kubectl get pods -n authentik
  ```
- **Ver logs do Server**:
  ```bash
  kubectl logs -n authentik -l app.kubernetes.io/name=authentik-server -f
  ```
- **Ver logs do Worker**:
  ```bash
  kubectl logs -n authentik -l app.kubernetes.io/name=authentik-worker -f
  ```

## Estrutura de Arquivos

- `00-namespace.yaml`: Definição do isolamento.
- `01-secret.yaml`: Chaves de criptografia e senhas.
- `02-pvc.yaml`: Armazenamento persistente.
- `10-configmap.yaml`: Variáveis de ambiente e conexão.
- `20-server-deployment.yaml`: O core do Authentik.
- `21-worker-deployment.yaml`: Executor de tarefas em background.
- `30-service.yaml`: Exposição interna.
- `40-ingress.yaml`: Exposição externa via Traefik com TLS.
