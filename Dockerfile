# ==============================================================================
# ESTÁGIO 1: Builder (Descarte de instaladores e lixo estrutural)
# ==============================================================================
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends tar && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/build

# Modificado para buscar os arquivos soltos na raiz trazidos pelo Runner
COPY ./appserver.tar.gz .
COPY ./webapp.tar.gz .

RUN mkdir -p appserver && \
    tar -xzf appserver.tar.gz -C appserver/ && \
    tar -xzf webapp.tar.gz -C appserver/

# ==============================================================================
# ESTÁGIO 2: Runner (Imagem Enxuta de Produção)
# ==============================================================================
FROM ubuntu:22.04 AS runner
LABEL maintainer="Rodrigo dos Santos Brandão <rodrigomicrosiga>"
LABEL version="24.3.1.5" 
LABEL description="TOTVS AppServer 24.3.1.5"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=pt_BR.UTF-8
ENV LANGUAGE=pt_BR:pt
ENV LC_ALL=pt_BR.UTF-8
ENV PATH="/totvs/protheus/bin/appserver:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 \
    libtinfo5 \
    libuuid1 \
    netcat-openbsd \
    unzip \
    locales \
    dmidecode \
    && echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /totvs/protheus/bin/appserver \
             /totvs/protheus/apo \
             /totvs/protheus/system \
             /totvs/protheus/systemload \
             /totvs/protheus/log \
             /totvs/protheus/data

# Copia os binários mesclados do builder
COPY --from=builder /tmp/build/appserver /totvs/protheus/bin/appserver/

# Modificado para copiar os scripts da raiz do contexto local
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./code_compiler.sh /usr/local/bin/code_compiler.sh
COPY ./patch_deployer.sh /usr/local/bin/patch_deployer.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
             /usr/local/bin/patch_deployer.sh \
             /usr/local/bin/code_compiler.sh \
             /totvs/protheus/bin/appserver/appsrvlinux

WORKDIR /totvs/protheus/bin/appserver
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]