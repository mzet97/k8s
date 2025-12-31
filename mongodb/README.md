# MongoDB no K3s

Configuração do MongoDB com interface de gerenciamento web (Mongo Express).

## Estrutura

- `00-namespace.yaml`: Namespace `mongodb`
- `01-secret.yaml`: Credenciais (`mongo-root-username`, `mongo-root-password`)
- `11-headless-svc.yaml`: Service Headless
- `12-client-svc.yaml`: Service LoadBalancer (Acesso Externo)
- `20-statefulset.yaml`: StatefulSet do MongoDB (mongo:4.4 - compatível com CPUs sem AVX)
- `30-mongo-express.yaml`: Interface Web de gerenciamento (Ingress: `mongodb-console.home.arpa`)

## ⚠️ Nota de Compatibilidade (Versão 4.4)

Estamos utilizando a versão **MongoDB 4.4.18** intencionalmente.

- **Motivo:** O MongoDB 5.0+ exige processadores com suporte a instruções **AVX**. O hardware atual deste cluster não possui esse suporte.
- **Aviso de "End-of-Life":** Ao conectar com clientes modernos, você pode receber um aviso de que a versão 4.4 está "end-of-life". Isso é esperado e inevitável neste hardware. O banco funcionará normalmente.

## Instalação

Execute o script:

```bash
chmod +x install-mongodb-k3s.sh
./install-mongodb-k3s.sh
```

## Acesso

**Console Web (Mongo Express):**
- URL: `https://mongodb-console.home.arpa`
- User: `admin`
- Pass: (veja `01-secret.yaml`)

**Externo (Connection String):**
- Host: `mongodb.home.arpa`
- Port: `27017`
- URL: `mongodb://admin:Admin%40123@mongodb.home.arpa:27017/?authSource=admin`
