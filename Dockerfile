# ==============================================================================
# ESTÁGIO 1: Builder (Extração e Limpeza por Strip)
# ==============================================================================
FROM debian:bookworm-slim AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    tar \
    binutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build

# 🌟 SUPORTE DINÂMICO: Copia apenas o instalador do AppServer com tolerância de caixa no nome
COPY ./*[aA][pP][pP][sS][eE][rR][vV][eE][rR]*.[tT][aA][rR].[gG][zZ] ./appserver.tar.gz

RUN mkdir -p appserver && \
    tar -xzf appserver.tar.gz -C appserver/

# ⚡ A MÁGICA DO STRIP: Remove símbolos de debug recursivamente de todas as libs e binários
RUN find appserver/ -type f -name "*.so*" -exec strip --strip-unneeded {} + 2>/dev/null || true
RUN strip --strip-unneeded appserver/appsrvlinux 2>/dev/null || true

# ==============================================================================
# ESTÁGIO 2: Runner (Imagem Ultra-Leve de Produção)
# ==============================================================================
FROM debian:bookworm-slim AS runner
LABEL maintainer="Rodrigo dos Santos Brandão <rodrigomicrosiga>"
LABEL version="24.3.1.5" 
LABEL description="TOTVS AppServer 24.3.1.5 - Ultra Light"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=pt_BR.UTF-8 \
    LANGUAGE=pt_BR:pt \
    LC_ALL=pt_BR.UTF-8 \
    PATH="/totvs/protheus/bin/appserver:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 \
    libtinfo5 \
    libuuid1 \
    netcat-openbsd \
    unzip \
    locales \
    dmidecode \
    # 🖨️ Dependências nativas necessárias para o TOTVS Printer rodar perfeitamente
    libdrm2 \
    libxcb-glx0 \
    libx11-xcb1 \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libsm6 \
    libcups2 \
    libglx0 \
    libopengl0 \
    libegl1 \
    libfreetype6 \
    libfontconfig1 \
    # 🌟 Adições para resolver o erro do XCB Shape e Fixes:
    libxcb-shape0 \
    libxcb-xfixes0 \
    # 🌟 Adição de bibliotecas complementares:
    libxcb-xinput0 \
    libxcb-randr0 \
    libxcb-shm0 \
    libxcb-sync1 \
    && echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /totvs/protheus/bin/appserver \
             /totvs/protheus/apo \
             /totvs/protheus/system \
             /totvs/protheus/systemload \
             /totvs/protheus/log \
             /totvs/protheus/data

# Copia apenas os binários limpos do AppServer do builder
COPY --from=builder /tmp/build/appserver /totvs/protheus/bin/appserver/

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./code_compiler.sh /usr/local/bin/code_compiler.sh
COPY ./patch_deployer.sh /usr/local/bin/patch_deployer.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
             /usr/local/bin/patch_deployer.sh \
             /usr/local/bin/code_compiler.sh \
             /totvs/protheus/bin/appserver/appsrvlinux

WORKDIR /totvs/protheus/bin/appserver
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]