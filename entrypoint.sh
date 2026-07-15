#!/bin/bash
set -e

# Traduz o argumento do container em minúsculas (core, rest, telnet, worker, upddistr, compile)
ROLE=$(echo "$1" | tr '[:upper:]' '[:lower:]')
echo "=== [AppServer] Inicializando Modo Especialista: [${ROLE^^}] ==="

# Mapeamento dinâmico das variáveis globais injetadas pelo Docker Compose
PORT=${APP_PORT_MULTI}
LICENSE_HOST=${LICENSE_SERVER:-protheus_license}
LICENSE_PORT=${LICENSE_SERVER_PORT:-5555}
DB_PORT_INI=${DBACCESS_PORT:-7890}
DB_SERVER_INI=${DBACCESS_SERVER:-protheus_dbaccess}

# Garante o fallback do nome do RPO Customizado caso não esteja mapeado
RPO_CUSTOM_TARGET="${RPO_CUSTOM_NAME:-custom}"

# Tratamento exclusivo para o nome do log do ConsoleFile baseado no serviço
case "$ROLE" in
    core)     LOG_NAME="appserver_core.log"     ;;
    rest)     LOG_NAME="appserver_rest.log"     ;;
    telnet)   LOG_NAME="appserver_telnet.log"   ;;
    worker)   LOG_NAME="appserver_worker.log"   ;;
    upddistr) LOG_NAME="appserver_upddistr.log" ;;
    compile)  LOG_NAME="appserver_compiler.log" ;;
    *)        LOG_NAME="appserver.log"          ;;
esac

# 1. Aguarda a retaguarda de infraestrutura estar online de forma flexível
echo "⏳ Validando conectividade com o barramento de infraestrutura..."
while ! nc -z "$DB_SERVER_INI" "$DB_PORT_INI"; do sleep 1; done
while ! nc -z "$LICENSE_HOST" "$LICENSE_PORT"; do sleep 1; done
echo "✅ Conectividade com DbAccess e License Server established!"

# ==============================================================================
# 1.5 ALINHAMENTO DINÂMICO DO RPO OFICIAL (tttm120.rpo)
# ==============================================================================
echo "🔍 Verificando integridade do repositório de objetos (APO)..."
if [ -d "/totvs/protheus/apo" ]; then
    
    # 🧹 Limpeza de segurança: Se existir um tttm120.rpo com tamanho zero (criado incorretamente pelo sistema), deleta.
    if [ -f "/totvs/protheus/apo/tttm120.rpo" ] && [ ! -s "/totvs/protheus/apo/tttm120.rpo" ]; then
        echo "🧹 [RPO Align] Detectado tttm120.rpo inválido de tamanho zero. Removendo..."
        rm -f /totvs/protheus/apo/tttm120.rpo
    fi

    # Procura qualquer RPO que contenha "tttm120" no nome, ignorando caixa alta/baixa, exceto o destino correto
    RPO_MATCH=$(find /totvs/protheus/apo -maxdepth 1 -iname "*tttm120*.rpo" ! -name "tttm120.rpo" | head -n 1)
    
    if [ -n "$RPO_MATCH" ] && [ -f "$RPO_MATCH" ]; then
        echo "🔄 [RPO Align] Detectado RPO padrão com nomenclatura do portal: (${RPO_MATCH##*/})"
        echo "🚚 Forçando renomeação para tttm120.rpo para compatibilidade nativa..."
        # Remove fisicamente para garantir que o 'mv' não trave se o arquivo destino existir
        rm -f /totvs/protheus/apo/tttm120.rpo
        mv -f "$RPO_MATCH" /totvs/protheus/apo/tttm120.rpo
        echo "✅ RPO padrão renomeado e alinhado com sucesso!"
    else
        # Valida se o arquivo que restou é válido (existe e tem tamanho maior que zero)
        if [ -f "/totvs/protheus/apo/tttm120.rpo" ] && [ -s "/totvs/protheus/apo/tttm120.rpo" ]; then
            echo "⏭️  RPO padrão tttm120.rpo já está no formato correto e íntegro. Pulando alinhamento."
        else
            echo "⚠️  Aviso Crítico: Nenhum RPO padrão válido de tamanho correto foi localizado em /totvs/protheus/apo/!"
        fi
    fi
fi

# 2. Carga Inicial Isolada com Injeção Segura de Travas
echo "📦 Verificando integridade dos volumes isolados..."

# Garante a árvore mínima necessária dentro dos volumes do Docker
mkdir -p /totvs/protheus/system /totvs/protheus/systemload /totvs/protheus/log /totvs/protheus/data /totvs/protheus/apo/aporollback /totvs/protheus/patches_queue

# --- EXTRAÇÃO DINÂMICA DO FISCAL.ZIP (Busca por padrão de nome) ---
if [ ! -f "/totvs/protheus/system/.fiscal_boot_done" ]; then
    FISCAL_MATCH=$(find /tmp/source_system -maxdepth 1 -iname "*fiscal*.zip" | head -n 1)
    if [ -n "$FISCAL_MATCH" ] && [ -f "$FISCAL_MATCH" ]; then
        echo "📂 [First Boot] Extraindo dicionários de sistema (${FISCAL_MATCH##*/})..."
        touch /totvs/protheus/system/.fiscal_boot_done
        unzip -nq "$FISCAL_MATCH" -d /totvs/protheus/system/
        echo "✅ Arquivos de dicionário fiscal populados com sucesso!"
    else
        echo "⚠️  Aviso: Nenhum pacote com padrão '*fiscal*.zip' localizado em /tmp/source_system/"
    fi
else
    echo "⏭️  Arquivos de dicionário fiscal já inicializados anteriormente. Pulando."
fi

# --- EXTRAÇÃO DINÂMICA DO MENUS.ZIP (Busca por padrão de nome) ---
if [ ! -f "/totvs/protheus/system/.menus_boot_done" ]; then
    MENUS_MATCH=$(find /tmp/source_system -maxdepth 1 -iname "*menus*.zip" | head -n 1)
    if [ -n "$MENUS_MATCH" ] && [ -f "$MENUS_MATCH" ]; then
        echo "📂 [First Boot] Extraindo menus corporativos (${MENUS_MATCH##*/})..."
        touch /totvs/protheus/system/.menus_boot_done
        unzip -nq "$MENUS_MATCH" -d /totvs/protheus/system/
        if [ -d "/totvs/protheus/system/menus" ]; then
            echo "📂 Ajustando estrutura de diretórios do menus para a raiz da system..."
            mv /totvs/protheus/system/menus/* /totvs/protheus/system/ 2>/dev/null || true
            rmdir /totvs/protheus/system/menus 2>/dev/null || true
        fi
        echo "✅ Arquivos de menus populados com sucesso!"
    else
        echo "⚠️  Aviso: Nenhum pacote com padrão '*menus*.zip' localizado em /tmp/source_system/"
    fi
else
    echo "⏭️  Arquivos de menus já inicializados anteriormente. Pulando."
fi

# --- EXTRAÇÃO DINÂMICA DO SYSTEMLOAD (DICIONARIOS, HELP, WEB) ---
if [ ! -f "/totvs/protheus/systemload/.systemload_boot_done" ]; then
    echo "📂 [First Boot] Extraindo dados de carga in /totvs/protheus/systemload/ (Aguarde)..."
    touch /totvs/protheus/systemload/.systemload_boot_done

    # 1. Localiza e extrai o Dicionário de Carga (dicionarios)
    DIC_MATCH=$(find /tmp/source_systemload -maxdepth 1 -iname "*dicionario*.zip" | head -n 1)
    [ -n "$DIC_MATCH" ] && [ -f "$DIC_MATCH" ] && echo "📂 Extraindo ${DIC_MATCH##*/}..." && unzip -nq "$DIC_MATCH" -d /totvs/protheus/systemload/

    # 2. Localiza e extrai o Help de Sistema (help)
    HELP_MATCH=$(find /tmp/source_systemload -maxdepth 1 -iname "*help*.zip" | head -n 1)
    [ -n "$HELP_MATCH" ] && [ -f "$HELP_MATCH" ] && echo "📂 Extraindo ${HELP_MATCH##*/}..." && unzip -nq "$HELP_MATCH" -d /totvs/protheus/systemload/

    # 3. Localiza e extrai o Help Web (web)
    WEB_MATCH=$(find /tmp/source_systemload -maxdepth 1 -iname "*web*.zip" | head -n 1)
    [ -n "$WEB_MATCH" ] && [ -f "$WEB_MATCH" ] && echo "📂 Extraindo ${WEB_MATCH##*/}..." && unzip -nq "$WEB_MATCH" -d /totvs/protheus/systemload/

    echo "✅ Volume systemload populado com sucesso!"
else
    echo "⏭️  Volume systemload já inicializado anteriormente. Pulando extração."
fi

# ==============================================================================
# 2.5 ACOPLAMENTO FÍSICO DO WEBAPP.SO NA RAIZ DO APPSERVER (Evita Bug de subPath)
# ==============================================================================
if [ -f "/tmp/webapp_shared/webapp.so" ]; then
    echo "🔗 [Engine] Detectado webapp.so no volume temporario. Realizando link físico..."
    cp "/tmp/webapp_shared/webapp.so" "/totvs/protheus/bin/appserver/webapp.so"
    echo "✅ Biblioteca webapp.so acoplada na raiz de execucao com sucesso!"
else
    echo "⚠️  Aviso: webapp.so nao localizado em /tmp/webapp_shared/. O SmartClient HTML pode nao inicializar."
fi

# 3. Renderização dinâmica do appserver.ini com as variáveis validadas
cd /totvs/protheus/bin/appserver
echo "📝 Gerando appserver.ini dinâmico para o modo [${ROLE^^}]..."

cat <<EOF > appserver.ini
[${ENV_NAME}]
SourcePath=/totvs/protheus/apo
RPOCustom=/totvs/protheus/apo/${RPO_CUSTOM_TARGET}.rpo
RPOTLPP=/totvs/protheus/apo/tlpp.rpo
RootPath=/totvs/protheus
StartPath=/system/
RpoDb=SQL
RpoLanguage=Multi
RpoVersion=120
LocalFiles=SQLITE
LocalDbExtension=.db
StartSysInDB=1
TopMemoMega=50
DBPort=${DB_PORT_INI}
DBAlias=${DB_NAME}
DBServer=${DB_SERVER_INI}
DBDatabase=${DB_TYPE}

[Drivers]
Active=TCP
MultiProtocolPort=$( [ "$ROLE" = "upddistr" ] || [ "$ROLE" = "compile" ] && echo "0" || echo "1" )
MultiProtocolPortSecure=0

[TCP]
TYPE=TCPIP
Port=${PORT}

[LicenseClient]
Server=${LICENSE_HOST}
Port=${LICENSE_PORT}

[General]
$( [ "$ROLE" = "upddistr" ] || [ "$ROLE" = "compile" ] && echo ";app_environment=${ENV_NAME}" || echo "app_environment=${ENV_NAME}" )
ShowFullLog=0
MaxStringSize=500
MaxQuerySize=31960
PowerSchemeShowUpgradeSuggestion=0
ConsoleFile=/totvs/protheus/log/${LOG_NAME}
ConsoleLog=1
AsyncConsoleLog=1
BuildKillUsers=1

[WebApp]
Port=${PORT}
LastMainProg=SIGAADV,SIGACFG,MPSDU,SIGAMDI
EnvServer=${ENV_NAME}
NonStopOnError=1
EOF

# 🛡️ Injeção de Segurança e Governança Cirúrgica Baseada no Papel
if [ "$ROLE" = "worker" ] || [ "$ROLE" = "upddistr" ] || [ "$ROLE" = "compile" ]; then
    cat <<EOF >> appserver.ini

[WebMonitor]
Enable=0

[APP_MONITOR]
Enable=0
Gui=0

[TDS]
AllowMonitor=*
AllowApplyPatch=*
AllowEdit=*
EnableDisconnectUser=*
EnableSendMessage=*
EnableBlockNewConnection=*
EnableStopServer=*
EOF
else
    cat <<EOF >> appserver.ini

[WebMonitor]
Enable=0

[APP_MONITOR]
Enable=0
Gui=0

[TDS]
AllowMonitor=*
AllowApplyPatch=0
AllowEdit=0
EnableDisconnectUser=0
EnableSendMessage=0
EnableBlockNewConnection=0
EnableStopServer=0
EOF
fi

# Bloco estrutural WebApp comum a todos
cat <<EOF >> appserver.ini

[WebApp/webapp]
MPP=
EOF

# Append dos blocos especialistas dedicados (REST / TELNET / UPDDISTR)
if [ "$ROLE" = "rest" ]; then
    cat <<EOF >> appserver.ini

[HTTPJOB]
Main=HTTP_START
Environment=${ENV_NAME}

[ONSTART]
Jobs=HTTPJOB
RefreshRate=120

[HTTPV11]
Enable=1
Sockets=HTTPREST

[HTTPREST]
Port=${REST_HTTP_PORT}
URIs=HTTPURI
SECURITY=1

[HTTPURI]
URL=${REST_URI}
PrepareIn=${REST_PREP_ENV}
Instances=${REST_INSTANCES}
Stateless=1
CORSEnable=1
AllowOrigin=*
EOF
elif [ "$ROLE" = "telnet" ]; then
    cat <<EOF >> appserver.ini

[TELNET]
Enable=1
Environment=${ENV_NAME}
Main=SIGAACD
Port=${TELNET_PORT}
EOF
elif [ "$ROLE" = "upddistr" ]; then
    cat <<EOF >> appserver.ini

[UPDJOB]
MAIN=UPDDISTR
ENVIRONMENT=${ENV_NAME}

[ONSTART]
Jobs=UPDJOB
RefreshRate=900
EOF
fi

# 4. Inicialização do Binário Oficial com Verificação de Sanidade
echo "🔍 Validando integridade física do executável TOTVS..."
if [ ! -f "appsrvlinux" ]; then
    echo "❌ ERRO CRÍTICO: O binário appsrvlinux NÃO foi encontrado no diretório atual ($(pwd))!"
    exit 1
fi

echo "🔑 Forçando permissões de execução no binário..."
chmod +x appsrvlinux

# Se for o core master, assinala o semáforo para liberar os nós especialistas
if [ "$ROLE" = "core" ]; then
    echo "🎯 Criando semáforo de prontidão (.protheus_db_ready)..."
    touch /totvs/protheus/system/.protheus_db_ready
fi

# ⚡ ORCHESTRATION ENGINE
if [ "$ROLE" = "worker" ]; then
    echo "🚀 Preparando ambiente local do Worker..."
    cd /totvs/protheus/bin/appserver
    if [ -f "/usr/local/bin/patch_deployer.sh" ]; then
        echo "🤖 [Worker] Assumindo controle do contêiner em Foreground para execução síncrona..."
        exec /usr/local/bin/patch_deployer.sh
    else
        echo "❌ ERRO CRÍTICO: O script /usr/local/bin/patch_deployer.sh não foi encontrado!"
        exit 1
    fi
elif [ "$ROLE" = "compile" ]; then
    echo "🚀 Preparando ambiente local do Compilador GitOps..."
    cd /totvs/protheus/bin/appserver
    if [ -f "/usr/local/bin/code_compiler.sh" ]; then
        echo "🤖 [Compiler] Assumindo controle do contêiner em Foreground para compilação..."
        exec /usr/local/bin/code_compiler.sh
    else
        echo "❌ ERRO CRÍTICO: O script /usr/local/bin/code_compiler.sh não foi encontrado!"
        exit 1
    fi
elif [ "$ROLE" = "upddistr" ]; then
    echo "📝 Preparando arquivo de parâmetros upddistr_param.json..."
    
    cat <<EOF > /totvs/protheus/systemload/upddistr_param.json
{
 "user": "${UPD_USER:-admin}",
 "password": "${UPD_PASSWORD:-senha}", 
 "simulacao": ${UPD_SIMULACAO:-false},
 "localizacao": "${UPD_LOCALIZACAO:-BRA}",
 "sixexclusive": ${UPD_SIXEXCLUSIVE:-true},
 "empresas": ["${UPD_EMPRESAS:-99}"],
 "logprocess": ${UPD_LOGPROCESS:-false},
 "logatualizacao": ${UPD_LOGATUALIZACAO:-true},
 "logwarning": ${UPD_LOGWARNING:-false},
 "loginclusao": ${UPD_LOGINCLUSAO:-false},
 "logcritical": ${UPD_LOGCRITICAL:-true},
 "updstop": ${UPD_UPDSTOP:-false},
 "oktoall": ${UPD_OKTOALL:-true},
 "deletebkp": ${UPD_DELETEBKP:-false},
 "keeplog": ${UPD_KEEPLOG:-false},
 "typeenviroment": "${UPD_TYPEENVIRONMENT:-3}"
}
EOF

    echo "🚀 Disparando engine de compatibilização UPDDISTR em Foreground..."
    cd /totvs/protheus/bin/appserver
    
    rm -f /totvs/protheus/systemload/Result.json
    
    exec ./appsrvlinux -console
else
    echo "🚀 Disparando TOTVS Application Server Linux no modo [${ROLE^^}]..."
    cd /totvs/protheus/bin/appserver
    exec ./appsrvlinux -console
fi