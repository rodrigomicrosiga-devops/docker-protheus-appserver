# 🐳 TOTVS Protheus - Application Server 64-bits (Fábriga CI/CD)

Este repositório é um componente isolado da arquitetura TOTVS Protheus Modern DevOps [https://github.com/rodrigomicrosiga-devops/totvs-protheus-modern-devops], e isola e automatiza a esteira de build do **TOTVS AppServer** na organização **`rodrigomicrosiga-devops`**. Ele encapsula uma inteligência de orquestração multi-papel capaz de instanciar nós especialistas variando apenas a herança de argumentos em runtime.

---

## 🏗️ Arquitetura Operacional Dinâmica (Multi-Role Engine)

O container foi projetado sob o princípio da imutabilidade de infraestrutura: a mesma imagem gerada pelo pipeline assume diferentes comportamentos lógicos e perfis de segurança de acordo com a `ROLE` definida no provisionamento do ecossistema.

```mermaid
graph TD
    %% Inicialização
    A[Entrypoint do Container] -->|Lê Argumento ROLE| B{Qual o Modo?}
    
    %% Papéis
    B -->|CORE| C[Executa Processamento Master + Cria Semáforo]
    B -->|REST| D[Inicializa HTTPJOB / HTTPREST / Sockets]
    B -->|TELNET| E[Ativa SIGAACD para Coletores de Dados]
    B -->|UPDDISTR| H[Injeta upddistr_param.json e Roda Dicionário]
    
    %% Validações de Borda
    C & D & E & H --> I[Valida Conectividade via nc: DbAccess & License]
    I --> J[Garante Árvore Mínima de Diretórios nos Volumes]
    J --> K[Renderiza appserver.ini Dinamicamente com Regras de TDS]
    K --> L[Dispara Engine: appsrvlinux -console]

    %% Estilização
    style B fill:#f9f,stroke:#333,stroke-width:2px
    style L fill:#bfb,stroke:#333,stroke-width:2px
```

### ⚙️ Especificações Técnicas e Governança

* **Imagem Base**: Ubuntu 22.04 LTS com injeção de dependências de hardware (`dmidecode`) e libs nativas (`libtinfo5, netcat-openbsd`).

* **Regras de Escopo de TDS**: Bloqueio rígido automático de aplicação de patches, desconexão de usuários e monitoramento nos nós de produção (`core`, `rest`, `telnet`), liberando essas permissões apenas no papel `upddistr`. Esta imagem nunca aplica patch ou compila fonte — essa responsabilidade é exclusiva da imagem `appserver-dev-worker` (papéis `worker`/`compile`, ver [docker-protheus-appserver-worker](https://github.com/rodrigomicrosiga-devops/docker-protheus-appserver-worker)).

* **Bootstrap Isolado de Cargas**: Gerenciamento nativo e extração unificada via unzip dos arquivos cruciais de dicionário (`fiscal.zip`, `menus.zip`, `dicionarios.zip`) protegidos contra re-extrações destrutivas pós-first-boot.

### 🏷️ Rastreabilidade de Build

A tag da imagem publicada permanece fixa entre builds — só muda em uma nova release de versão. Para rastrear qual commit gerou um build específico sem depender da tag, o `pipeline` grava o label `org.opencontainers.image.revision` com o SHA do commit em toda imagem publicada:

```bash
docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' rodrigomicrosiga/appserver-dev:24.3.1.5
```

### 🚀 Como Executar a Imagem

A imagem exige a passagem do papel especialista como argumento de execução padrão:

```bash
# Executando um nó de processamento REST puro acoplado ao arquivo de credenciais
docker run -d --name protheus-rest --env-file .env.appserver rodrigomicrosiga/appserver-dev:24.3.1.5 rest
```