# Inventário de estudo — SwarmLab (Fases 1, 2 e 3)

Fonte: documentação oficial em docs.docker.com, consultada em 2026-10-28. Abra cada URL antes de estudar o tópico: a doc muda, e nas URLs marcadas com (*) esta varredura não confirmou trecho a trecho o que vem depois.
Conferido diretamente nesta varredura: a página de `docker stack deploy` (Compose >= 3.0, `--detach` padrão true, `--prune`, `--resolve-image`, aviso "Ignoring unsupported options: links") e o tutorial de Swarm (portas 2377/tcp, 7946/tcp+udp, 4789/udp, protocolo IP 50 para overlay criptografada, recomendação de não expor 4789 fora da rede confiável).

Legenda dos itens: **Conceito** · **Doc** · **Comandos/chaves** · **Exercício (SwarmLab)** · **Armadilhas**

---

## FASE 1 — Containerização (o que falta depois do que já foi feito)

### 1.1 Revisão: modelo de build com BuildKit e o builder
- **Conceito:** BuildKit é o backend padrão de `docker build` desde o Engine 23.0. Hoje `docker build` é um atalho para `docker buildx build`, e a build roda num *builder* (driver `docker` ou `docker-container`).
- **Doc:** https://docs.docker.com/build/concepts/overview/ · https://docs.docker.com/build/buildkit/ · https://docs.docker.com/build/builders/
- **Comandos:** `docker buildx ls`, `docker buildx inspect`, `docker buildx create --driver docker-container --use`, `docker build --progress=plain`
- **Exercício:** rode `docker buildx ls` e anote o builder padrão. Construa a API com `--progress=plain` e identifique na saída cada `CACHED` e a linha de cada stage.
- **Armadilhas:** livro de ~2020 fala de `DOCKER_BUILDKIT=1`, que hoje é desnecessário. O driver `docker` não suporta todos os exporters de cache (por exemplo, `type=registry` para cache-to exige o driver `docker-container`).

### 1.2 ARG × ENV, build-args, escopo de ARG
- **Conceito:** ARG só existe em tempo de build e tem escopo por stage (um ARG declarado antes do `FROM` só vale no `FROM`, a menos que seja redeclarado). ENV persiste na imagem e no container.
- **Doc:** https://docs.docker.com/reference/dockerfile/#arg · https://docs.docker.com/reference/dockerfile/#env · https://docs.docker.com/build/building/variables/
- **Comandos:** `ARG PYTHON_VERSION=3.14.10`, `FROM python:${PYTHON_VERSION}-slim-trixie`, `docker build --build-arg PYTHON_VERSION=...`
- **Exercício:** parametrize a versão do Python e a versão do uv via ARG. Prove o escopo: use o ARG depois do `FROM` sem redeclarar e veja que ele chega vazio. Depois redeclare e veja o valor. Rode `docker history` e veja que ARG/ENV aparecem nos metadados.
- **Armadilhas:** segredo em ARG ou ENV fica gravado no histórico e nos metadados da imagem; use secret mount (1.4). A doc tem build checks que alertam sobre isso (1.9).

### 1.3 Cache mounts (`RUN --mount=type=cache`) e bind mounts de build
- **Conceito:** um cache persistente entre builds (cache do uv/pip) que não entra na camada. O `--mount=type=bind` monta arquivos do contexto sem precisar de COPY.
- **Doc:** https://docs.docker.com/build/cache/optimize/ · https://docs.docker.com/reference/dockerfile/#run---mount · guia uv (externo, da Astral, para referência cruzada: https://docs.astral.sh/uv/guides/integration/docker/)
- **Comandos:** `RUN --mount=type=cache,target=/root/.cache/uv --mount=type=bind,source=uv.lock,target=uv.lock --mount=type=bind,source=pyproject.toml,target=pyproject.toml uv sync --locked --no-install-project`
- **Exercício:** meça o tempo da build com e sem cache mount depois de mudar uma dependência (`time docker build ...`). Confirme com `docker buildx du` que o cache existe fora das camadas.
- **Armadilhas:** o cache mount não vai para a imagem nem para o registry, então em CI ele se perde sem cache externo (1.6). Com `UV_LINK_MODE` padrão (hardlink) aparece um aviso quando o cache está em outro filesystem; a doc do uv recomenda `UV_LINK_MODE=copy`.

### 1.4 Secrets de build e SSH
- **Conceito:** passar credencial para um RUN sem gravá-la em camada.
- **Doc:** https://docs.docker.com/build/building/secrets/
- **Comandos:** `RUN --mount=type=secret,id=pypi_token,env=PYPI_TOKEN ...`, `docker build --secret id=pypi_token,src=./token.txt`, `RUN --mount=type=ssh`, `--ssh default`
- **Exercício:** simule um índice privado: um RUN que faz `test -f /run/secrets/x && wc -c /run/secrets/x`. Depois rode `docker history --no-trunc` e `docker save` + `grep` para provar que o conteúdo não está na imagem. Repita com ARG e veja o vazamento.
- **Armadilhas:** a mudança do conteúdo do secret não invalida o cache por si só. Não confunda secret de build com secret de runtime (Compose/Swarm).

### 1.5 Targets e multi-stage avançado
- **Conceito:** `--target` constrói até um stage. Isso permite stages `dev`, `test` e `prod` no mesmo Dockerfile.
- **Doc:** https://docs.docker.com/build/building/multi-stage/
- **Comandos:** `docker build --target test .`, `FROM base AS test`
- **Exercício:** crie um stage `test` que roda `pytest`. Mostre que `--target prod` não executa o stage de teste, porque o BuildKit pula stages não dependentes.
- **Armadilhas:** com BuildKit, stages que o target não usa são ignorados, o que muda a ordem que um livro antigo descreve.

### 1.6 Cache externo e invalidação
- **Conceito:** a ordem das instruções define o cache. Cache backends (`inline`, `registry`, `local`, `gha`) permitem reutilizar cache em CI.
- **Doc:** https://docs.docker.com/build/cache/ · https://docs.docker.com/build/cache/invalidation/ · https://docs.docker.com/build/cache/backends/
- **Comandos:** `--cache-to type=registry,ref=...`, `--cache-from`, `--no-cache`, `--no-cache-filter`, `docker builder prune`
- **Exercício:** exporte o cache para `type=local,dest=./.buildcache`, apague o cache local com `docker builder prune -af` e reconstrua com `--cache-from type=local,src=./.buildcache`. Observe os `CACHED`.
- **Armadilhas:** `docker builder prune` apaga o cache de build. É diferente de `docker volume prune`, que a casa proíbe.

### 1.7 Sinais, PID 1, init e STOPSIGNAL
- **Conceito:** o processo do CMD/ENTRYPOINT é o PID 1 e recebe SIGTERM no `docker stop`. Depois do timeout (10 s por padrão) vem o SIGKILL. A shell form (`/bin/sh -c`) não repassa sinais. `--init` injeta o tini como PID 1 para colher zumbis e repassar sinais.
- **Doc:** https://docs.docker.com/reference/dockerfile/#entrypoint (seção sobre exec × shell form e sinais) · https://docs.docker.com/reference/dockerfile/#stopsignal · https://docs.docker.com/reference/cli/docker/container/run/#init · https://docs.docker.com/reference/cli/docker/container/stop/
- **Comandos:** `STOPSIGNAL SIGTERM`, `docker run --init`, `docker stop -t 30`, `docker kill -s SIGINT`
- **Exercício:** troque o CMD do uvicorn para shell form, rode `docker stop` com `time` e observe cerca de 10 s, com exit code 137. Volte para exec form: o shutdown é rápido, com exit 0, e o log mostra "Shutting down". No worker (Fase 2), trate SIGTERM para terminar o job corrente.
- **Armadilhas:** um script entrypoint em shell precisa de `exec "$@"`. O exit 137 significa SIGKILL, por timeout ou por OOM.

### 1.8 ENTRYPOINT × CMD e a interação entre eles
- **Doc:** https://docs.docker.com/reference/dockerfile/#understand-how-cmd-and-entrypoint-interact
- **Exercício:** crie um entrypoint que aceita `api`, `worker` ou `migrate` e use a mesma imagem para os três serviços da Fase 2.
- **Armadilhas:** `docker run img args` substitui o CMD, não o ENTRYPOINT. Para trocar o ENTRYPOINT, use `--entrypoint`.

### 1.9 Build checks e lint do Dockerfile
- **Conceito:** desde o Buildx 0.15 / Dockerfile 1.8, o build roda checks (por exemplo `SecretsUsedInArgOrEnv`, `JSONArgsRecommended`, `FromAsCasing`).
- **Doc:** https://docs.docker.com/build/checks/ · https://docs.docker.com/reference/build-checks/
- **Comandos:** `docker build --check .`, `# check=error=true` no topo do Dockerfile
- **Exercício:** faça o build passar com `--check` sem avisos. Provoque `JSONArgsRecommended` com CMD em shell form.
- **Armadilhas:** por padrão o check é aviso e não falha a build. Ative `error=true` para usá-lo como gate.

### 1.10 Dockerfile frontend e syntax directive
- **Doc:** https://docs.docker.com/build/buildkit/frontend/ · https://docs.docker.com/reference/dockerfile/#syntax
- **Comandos:** `# syntax=docker/dockerfile:1`
- **Armadilhas:** fixar `:1` traz as features estáveis mais recentes. Para reprodutibilidade, fixe uma versão.

### 1.11 Tags, digests e reprodutibilidade
- **Conceito:** tag é mutável e digest (`sha256:`) é imutável. Fixar `FROM python:3.14.10-slim-trixie@sha256:...` garante a mesma base.
- **Doc:** https://docs.docker.com/reference/cli/docker/image/pull/#pull-an-image-by-digest-immutable-identifier · https://docs.docker.com/dhi/ (*) · https://docs.docker.com/reference/cli/docker/image/tag/
- **Comandos:** `docker images --digests`, `docker buildx imagetools inspect python:3.14.10-slim-trixie`, `docker inspect --format '{{.RepoDigests}}'`
- **Exercício:** obtenha o digest do índice multi-plataforma e fixe-o no FROM. Explique a diferença entre o digest do índice e o do manifesto de `linux/amd64`.
- **Armadilhas:** o digest de índice multi-arch é diferente do digest por plataforma. Fixar digest congela patches de segurança, então você precisa de um processo para atualizar (Scout, 1.15).

### 1.12 Registries, push, login e registry local
- **Conceito:** imagem é publicada como `registry/namespace/repo:tag`. O Swarm (Fase 3) precisa de registry, porque os nós puxam a imagem.
- **Doc:** https://docs.docker.com/reference/cli/docker/image/push/ · https://docs.docker.com/reference/cli/docker/login/ · https://docs.docker.com/docker-hub/ · imagem `registry` (Distribution): https://hub.docker.com/_/registry · https://distribution.github.io/distribution/ (projeto CNCF, citado pela doc)
- **Comandos:** `docker run -d -p 5000:5000 --name registry registry:3`, `docker tag api localhost:5000/swarmlab/api:0.1.0`, `docker push`, `docker login`
- **Exercício:** suba um registry local, faça push e pull e compare o digest exibido no push com `RepoDigests`.
- **Armadilhas:** um registry sem TLS fora de localhost exige `insecure-registries` no daemon.json (https://docs.docker.com/reference/cli/dockerd/#insecure-registries). Credenciais vão para `~/.docker/config.json`; use credential helper (https://docs.docker.com/reference/cli/docker/login/#credential-stores).

### 1.13 Multi-plataforma
- **Doc:** https://docs.docker.com/build/building/multi-platform/
- **Comandos:** `docker buildx build --platform linux/amd64,linux/arm64 --push`
- **Exercício (opcional):** gere uma imagem amd64+arm64 para o registry local e inspecione-a com `imagetools inspect`.
- **Armadilhas:** o image store clássico não guarda listas multi-plataforma localmente. É preciso o containerd image store ou `--push`.

### 1.14 Containerd image store (mudança recente)
- **Conceito:** o Docker Engine 29 passou a usar o containerd image store como padrão em instalações novas. Ele muda `docker images`, o suporte a multi-plataforma e attestations.
- **Doc:** https://docs.docker.com/engine/storage/containerd/ · https://docs.docker.com/engine/release-notes/ (*)
- **Exercício:** `docker info | grep -i "storage driver"` e `docker info --format '{{.DriverStatus}}'` para saber qual store a máquina usa.
- **Armadilhas:** um livro antigo descreve overlay2 com o image store clássico, e os caminhos em `/var/lib/docker` mudam.

### 1.15 Docker Scout: vulnerabilidades e SBOM
- **Conceito:** analisa a imagem, lista CVEs por pacote, recomenda uma base melhor e gera SBOM.
- **Doc:** https://docs.docker.com/scout/ · https://docs.docker.com/scout/quickstart/ · https://docs.docker.com/reference/cli/docker/scout/
- **Comandos:** `docker scout quickview`, `docker scout cves --only-severity critical,high`, `docker scout recommendations`, `docker scout compare`, `docker scout sbom`
- **Exercício:** compare `python:3.14.10-slim-trixie` com a imagem final e registre o número de CVEs. Teste `--exit-code` como gate que falha.
- **Armadilhas:** exige login no Docker Hub e o plano gratuito tem limites. Resultado de CVE muda com o tempo sem mudar a imagem.

### 1.16 Attestations: SBOM e provenance
- **Doc:** https://docs.docker.com/build/metadata/attestations/
- **Comandos:** `docker buildx build --sbom=true --provenance=mode=max --push`
- **Armadilhas:** attestations exigem push ou o containerd store. Elas aparecem como manifestos `unknown/unknown` no registry.

### 1.17 Rodar o container: recursos, usuário, filesystem read-only, capabilities
- **Conceito:** limites de memória e CPU (cgroups), `--read-only` com `--tmpfs`, `--cap-drop ALL`, `--security-opt no-new-privileges`.
- **Doc:** https://docs.docker.com/engine/containers/resource_constraints/ · https://docs.docker.com/reference/cli/docker/container/run/ · https://docs.docker.com/engine/security/ (*) · https://docs.docker.com/engine/containers/run/#runtime-privilege-and-linux-capabilities
- **Comandos:** `--memory 256m --memory-swap 256m --cpus 0.5 --pids-limit 100 --read-only --tmpfs /tmp --cap-drop ALL`
- **Exercício:** rode a API com `--read-only` e veja o que quebra (por exemplo `__pycache__` ou `/tmp`). Corrija com tmpfs ou `PYTHONDONTWRITEBYTECODE`. Use `docker stats` para ver o limite.
- **Armadilhas:** sem `--memory-swap` igual a `--memory`, o container pode usar swap. Um processo morto por OOM aparece com `OOMKilled: true` no `docker inspect`.

### 1.18 Logs e logging drivers
- **Conceito:** stdout e stderr do PID 1 vão para o driver. O padrão é `json-file`, sem rotação a menos que seja configurada. O driver `local` comprime e rotaciona.
- **Doc:** https://docs.docker.com/engine/logging/ · https://docs.docker.com/engine/logging/configure/ · https://docs.docker.com/engine/logging/drivers/json-file/ · https://docs.docker.com/engine/logging/drivers/local/ · https://docs.docker.com/engine/logging/dual-logging/
- **Comandos:** `docker logs -f --since 5m --timestamps`, `--log-opt max-size=10m --log-opt max-file=3`, `"log-driver"` no daemon.json
- **Exercício:** configure a rotação na API, gere logs em loop e confira o arquivo em `docker inspect --format '{{.LogPath}}'`. Faça a API logar em JSON no stdout.
- **Armadilhas:** a mudança no daemon.json só vale para containers novos. Logar em arquivo dentro do container esconde o log de `docker logs`. Python precisa de `PYTHONUNBUFFERED=1` para não atrasar a saída.

### 1.19 Inspeção e depuração
- **Doc:** https://docs.docker.com/reference/cli/docker/container/exec/ · https://docs.docker.com/reference/cli/docker/inspect/ · https://docs.docker.com/reference/cli/docker/debug/ (Docker Debug, exige assinatura) (*) · https://docs.docker.com/reference/cli/docker/container/events/ (*) · https://docs.docker.com/reference/cli/docker/system/events/
- **Comandos:** `docker exec -it`, `docker inspect --format`, `docker events`, `docker top`, `docker diff`, `docker cp`
- **Exercício:** use `docker events` em outro terminal enquanto para o container e veja o evento `die` com o `exitCode`.

### 1.20 `docker init`
- **Conceito:** gera Dockerfile, compose.yaml e .dockerignore de referência para Python.
- **Doc:** https://docs.docker.com/reference/cli/docker/init/
- **Exercício:** rode `docker init` numa cópia do projeto e compare o resultado com o seu Dockerfile (usuário, cache mount, bind mount). Liste três diferenças e justifique cada uma.
- **Armadilhas:** o template não usa uv por padrão. Não sobrescreva o seu Dockerfile.

### 1.21 Guia oficial de Python
- **Doc:** https://docs.docker.com/guides/python/ (*) · boas práticas gerais: https://docs.docker.com/build/building/best-practices/
- **Exercício:** passe pelo checklist de best-practices e marque item a item no seu Dockerfile.

---

## FASE 2 — Compose (api, worker, postgres, migrator, traefik)

### 2.1 Compose v2 e o formato atual
- **Conceito:** o comando é `docker compose`, um plugin escrito em Go. A especificação é a Compose Specification, e o campo `version:` é obsoleto e gera aviso. O arquivo canônico é `compose.yaml`.
- **Doc:** https://docs.docker.com/compose/ · https://docs.docker.com/compose/intro/history/ · https://docs.docker.com/reference/compose-file/ · https://docs.docker.com/reference/compose-file/version-and-name/
- **Comandos:** `docker compose version`, `docker compose config`, `docker compose up -d`, `ps`, `logs -f`, `down`
- **Exercício:** escreva o `compose.yaml` mínimo com api e postgres. Rode `docker compose config` e leia o modelo normalizado.
- **Armadilhas:** `docker-compose` (v1, Python) está sem suporte desde 2023. Exemplos com `version: "3.8"` ainda funcionam, mas com aviso.

### 2.2 Nome do projeto e prefixos
- **Doc:** https://docs.docker.com/compose/how-tos/project-name/
- **Comandos:** `name:` no topo, `-p`, `COMPOSE_PROJECT_NAME`
- **Exercício:** suba o mesmo arquivo como `-p swarmlab_dev` e `-p swarmlab_test` ao mesmo tempo e observe redes e volumes separados.
- **Armadilhas:** o nome muda o prefixo dos volumes, então trocar o nome do projeto "perde" (órfã) os dados antigos.

### 2.3 Redes do Docker: bridge, DNS embutido e `internal`
- **Conceito:** a bridge padrão não tem DNS por nome. Uma bridge definida pelo usuário tem DNS embutido (127.0.0.11). `internal: true` bloqueia a saída externa. Cada serviço resolve pelo nome do serviço e pelos `aliases`.
- **Doc:** https://docs.docker.com/engine/network/ · https://docs.docker.com/engine/network/drivers/bridge/ · https://docs.docker.com/compose/how-tos/networking/ · https://docs.docker.com/reference/compose-file/networks/ · https://docs.docker.com/engine/network/packet-filtering-firewalls/
- **Comandos:** `docker network ls/inspect`, chaves `networks:`, `internal: true`, `aliases`, `ipam`
- **Exercício:** crie as redes `edge` (traefik e api), `backend` (api, worker, migrator, postgres) e `db` com `internal: true`. Prove que o postgres não sai para a internet (`docker compose exec postgres sh -c 'getent hosts example.com'`) e que o traefik não resolve `postgres`.
- **Armadilhas:** publicar porta (`ports:`) num serviço de rede interna não o torna acessível. O Docker manipula o iptables, e regras de UFW não bloqueiam portas publicadas (veja packet-filtering-firewalls).

### 2.4 Portas publicadas × expose
- **Doc:** https://docs.docker.com/reference/compose-file/services/#ports · https://docs.docker.com/engine/network/port-publishing/ (*)
- **Exercício:** publique a porta do postgres em `127.0.0.1:5432:5432` só no override de dev. Confirme com `ss -ltnp` que não está em `0.0.0.0`.
- **Armadilhas:** `5432:5432` sem IP expõe a porta em todas as interfaces.

### 2.5 Storage: volumes nomeados, bind mounts, tmpfs
- **Doc:** https://docs.docker.com/engine/storage/ · https://docs.docker.com/engine/storage/volumes/ · https://docs.docker.com/engine/storage/bind-mounts/ · https://docs.docker.com/engine/storage/tmpfs/ · https://docs.docker.com/reference/compose-file/volumes/ · https://docs.docker.com/reference/compose-file/services/#volumes
- **Comandos:** sintaxe longa (`type: volume|bind|tmpfs`, `read_only`, `bind.create_host_path`), `docker volume inspect`
- **Exercício:** use um volume nomeado `pgdata` para o banco e um bind mount read-only para `traefik.yml`. Rode `docker compose down` e depois `up`: os dados ficam. Rode `down -v`: os dados somem. Para seguir a regra da casa, refaça usando bind mount para os dados do Postgres e compare as permissões (UID 999 no host).
- **Armadilhas:** `down -v` apaga volumes nomeados. Nunca use `docker volume prune`/`system prune --volumes` (inegociável da casa). Bind mount com UID errado gera `permission denied`. Um volume anônimo nasce do `VOLUME` da imagem do postgres e é criado se você não montar `/var/lib/postgresql/data`; confira em https://hub.docker.com/_/postgres o caminho `PGDATA` da versão usada, porque ele mudou nas imagens 18+ (*).

### 2.6 Variáveis, interpolação e `.env`
- **Conceito:** há dois mecanismos diferentes. O `.env` interpola o arquivo Compose. `env_file:` e `environment:` definem o ambiente do container. A doc define uma precedência.
- **Doc:** https://docs.docker.com/compose/how-tos/environment-variables/ · https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/ · https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/ · https://docs.docker.com/compose/how-tos/environment-variables/best-practices/
- **Comandos:** `${VAR:?erro}`, `${VAR:-default}`, `--env-file`, `docker compose config --environment`
- **Exercício:** use `${API_TAG:?defina API_TAG}` e confirme que o `up` falha sem a variável.
- **Armadilhas:** a doc recomenda não passar dado sensível por variável de ambiente e usar secrets. O `.env` não pode entrar no git.

### 2.7 Secrets no Compose
- **Conceito:** um arquivo do host é montado em `/run/secrets/<nome>`. A imagem postgres aceita `POSTGRES_PASSWORD_FILE`.
- **Doc:** https://docs.docker.com/compose/how-tos/use-secrets/ · https://docs.docker.com/reference/compose-file/secrets/
- **Comandos:** `secrets:` top-level com `file:` ou `environment:`, `secrets:` por serviço
- **Exercício:** crie `secrets/db_password.txt` (fora do git, chmod 600), use `POSTGRES_PASSWORD_FILE` e faça a API ler o arquivo. Prove com `docker inspect` que a senha não aparece no ambiente.
- **Armadilhas:** no Compose (fora do Swarm) o secret é um bind mount e não é criptografado. As opções uid/gid/mode só são parcialmente suportadas fora do Swarm (veja a doc).

### 2.8 Configs
- **Doc:** https://docs.docker.com/reference/compose-file/configs/
- **Exercício:** entregue a configuração dinâmica do Traefik como `configs:` (com `content:` inline ou `file:`).

### 2.9 Healthchecks
- **Conceito:** o estado de saúde passa por `starting`, `healthy` e `unhealthy`. `start_period` e `start_interval` (adicionado no Engine 25) são opções de tempo.
- **Doc:** https://docs.docker.com/reference/compose-file/services/#healthcheck · https://docs.docker.com/reference/dockerfile/#healthcheck
- **Comandos:** `test: ["CMD-SHELL","pg_isready -U $$POSTGRES_USER"]`, `docker inspect --format '{{json .State.Health}}'`
- **Exercício:** dê healthcheck ao postgres (pg_isready), à api (`/health`) e ao worker (heartbeat em arquivo ou query). Observe a transição de estado com `docker compose ps`.
- **Armadilhas:** escreva `$$` para escapar a interpolação do Compose. O container `unhealthy` não reinicia sozinho no Compose; quem reage é o Swarm.

### 2.10 Ordem de start: `depends_on` com condition
- **Doc:** https://docs.docker.com/compose/how-tos/startup-order/ · https://docs.docker.com/reference/compose-file/services/#depends_on
- **Chaves:** `condition: service_started | service_healthy | service_completed_successfully`, `restart: true`, `required: false`
- **Exercício:** declare `postgres (healthy)` → `migrator (completed_successfully)` → `api` e `worker`. Faça a migração falhar (exit 1) e veja que a api não sobe.
- **Armadilhas:** `depends_on` só vale no start. Ele não protege contra o banco cair depois, então a app ainda precisa de retry. O Swarm ignora `depends_on`.

### 2.11 Migrator: one-off e tarefa que termina
- **Doc:** https://docs.docker.com/reference/cli/docker/compose/run/ · https://docs.docker.com/reference/compose-file/services/#restart
- **Comandos:** `docker compose run --rm migrator`, `restart: "no"`, `docker compose up --exit-code-from` (*)
- **Exercício:** rode o migrator duas vezes e prove que a migração é idempotente. Verifique o status `Exited (0)`.
- **Armadilhas:** um migrator com `restart: always` entra em loop.

### 2.12 Restart policies
- **Doc:** https://docs.docker.com/engine/containers/start-containers-automatically/ · https://docs.docker.com/reference/compose-file/services/#restart
- **Exercício:** use `restart: unless-stopped` na api, mate o processo com `docker compose kill -s SIGKILL api` e observe o restart e o contador `RestartCount`.

### 2.13 Limites de recursos no Compose
- **Doc:** https://docs.docker.com/reference/compose-file/deploy/#resources · https://docs.docker.com/reference/compose-file/services/ (`mem_limit`, `cpus`, `pids_limit`)
- **Exercício:** coloque `deploy.resources.limits.memory: 256M` no worker e um endpoint que aloca memória. Observe o `OOMKilled`.
- **Armadilhas:** o Compose v2 aplica `deploy.resources` mesmo fora do Swarm, enquanto o v1 antigo exigia `--compatibility`.

### 2.14 Profiles
- **Doc:** https://docs.docker.com/compose/how-tos/profiles/
- **Comandos:** `profiles: [tools]`, `--profile`, `COMPOSE_PROFILES`
- **Exercício:** coloque `pgadmin` (ou um serviço `backup`) e o `migrator` em profiles. Note que `docker compose up` não os sobe.
- **Armadilhas:** um serviço sem profile sempre sobe. Rodar um serviço com profile explicitamente com `run` ativa o profile dele.

### 2.15 Múltiplos arquivos: override, merge, extends, include
- **Doc:** https://docs.docker.com/compose/how-tos/multiple-compose-files/ · https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/ · https://docs.docker.com/compose/how-tos/multiple-compose-files/extends/ · https://docs.docker.com/compose/how-tos/multiple-compose-files/include/ · https://docs.docker.com/reference/compose-file/merge/ · https://docs.docker.com/reference/compose-file/fragments/ · https://docs.docker.com/reference/compose-file/extension/
- **Chaves:** `compose.override.yaml` (carregado automaticamente), `-f a -f b`, `include:`, `extends:`, `!reset`, `!override`, âncoras YAML e `x-` extensions
- **Exercício:** crie `compose.yaml` (base), `compose.override.yaml` (dev: bind mount do código, portas locais), `compose.test.yaml` e `compose.prod.yaml`. Use `docker compose -f compose.yaml -f compose.prod.yaml config` para ver o merge. Use `!reset` para remover `ports` em prod.
- **Armadilhas:** sequências como `ports` são concatenadas no merge, não substituídas. Caminhos relativos resolvem a partir do primeiro arquivo.

### 2.16 Ambientes dev/test/prod
- **Doc:** https://docs.docker.com/compose/how-tos/production/
- **Exercício:** crie um alvo `make test` que sobe o ambiente de teste com `-p swarmlab_test`, roda pytest via `run --rm` e faz `down -v` somente no projeto de teste.

### 2.17 `compose watch` (develop.watch)
- **Doc:** https://docs.docker.com/compose/how-tos/file-watch/ · https://docs.docker.com/reference/compose-file/develop/
- **Chaves:** `develop.watch[].action: sync | rebuild | sync+restart | sync+exec`, `path`, `target`, `ignore`
- **Exercício:** use `sync` para `src/` e `rebuild` para `uv.lock`. Edite um endpoint e veja o reload; mude uma dependência e veja o rebuild.
- **Armadilhas:** `sync` exige que a imagem tenha o diretório gravável pelo usuário do container. watch não substitui bind mount em todos os casos.

### 2.18 Build pelo Compose
- **Doc:** https://docs.docker.com/reference/compose-file/build/ · https://docs.docker.com/compose/how-tos/dependent-images/ (*) · Bake: https://docs.docker.com/build/bake/
- **Chaves:** `build.context`, `target`, `args`, `secrets`, `cache_from`, `image:` junto com `build:`
- **Exercício:** a mesma imagem com `target: dev` em dev e `target: prod` em prod. Use `docker compose build --pull`.

### 2.19 Traefik v3 com provider Docker
- **Doc (Docker):** https://docs.docker.com/engine/security/protect-access/ (exposição do socket). **Doc (Traefik, externa):** https://doc.traefik.io/traefik/providers/docker/ · https://doc.traefik.io/traefik/routing/providers/docker/
- **Exercício:** traefik na rede `edge`, socket montado `:ro` (ou por um socket-proxy), `exposedByDefault=false` e labels na api. Acesse `api.localhost`.
- **Armadilhas:** montar `/var/run/docker.sock` equivale a dar root no host, mesmo com `:ro`. Quando o container está em várias redes, o label `traefik.docker.network` é obrigatório.

### 2.20 Backup e restore do Postgres
- **Doc:** https://docs.docker.com/engine/storage/volumes/#back-up-restore-or-migrate-data-volumes · https://hub.docker.com/_/postgres (seção de inicialização e variáveis)
- **Comandos:** `docker compose exec -T postgres pg_dump -Fc -U app app > backup.dump`, `pg_restore`, backup do volume com `docker run --rm -v pgdata:/data -v $PWD:/backup alpine tar czf ...`
- **Exercício:** popule jobs, faça o dump lógico, destrua o projeto de teste, restaure e compare `count(*)`. Compare com o backup físico do volume com o banco parado.
- **Armadilhas:** o tar do volume com o banco rodando dá cópia inconsistente. Restaurar por cima é ação irreversível (portão humano da casa). Os scripts de `/docker-entrypoint-initdb.d` só rodam com o volume vazio.

### 2.21 Ciclo de vida e comandos de operação
- **Doc:** https://docs.docker.com/reference/cli/docker/compose/
- **Comandos:** `up --wait`, `up --build`, `up --force-recreate`, `up --no-deps`, `restart`, `stop`, `top`, `events`, `ls`, `cp`, `pull`, `push`, `config --services`, `alpha/viz` (*)
- **Exercício:** use `docker compose up -d --wait` em CI e veja que ele retorna só quando todos os serviços estão healthy.

### 2.22 Escala local
- **Doc:** https://docs.docker.com/reference/cli/docker/compose/up/ (`--scale`) · https://docs.docker.com/reference/compose-file/deploy/#replicas
- **Exercício:** rode `--scale worker=3` e prove no banco que SKIP LOCKED distribui os jobs sem duplicar.
- **Armadilhas:** `container_name` e porta fixa no host impedem a escala.

### 2.23 Outros recursos do Compose para conhecer
- `post_start`/`pre_stop` lifecycle hooks: https://docs.docker.com/compose/how-tos/lifecycle/
- `docker compose bridge` (converter para k8s, fora de escopo): https://docs.docker.com/compose/bridge/ (*)
- Compose e GPU: fora de escopo.
- Referência de serviços (todas as chaves): https://docs.docker.com/reference/compose-file/services/
- `init: true`, `stop_signal`, `stop_grace_period`: https://docs.docker.com/reference/compose-file/services/
- `logging:` por serviço: https://docs.docker.com/reference/compose-file/services/#logging
- `read_only`, `cap_drop`, `security_opt`, `user`: https://docs.docker.com/reference/compose-file/services/

---

## FASE 3 — Swarm multinó (3 managers + 2 workers)

### 3.1 Conceitos-chave do Swarm mode
- **Conceito:** node (manager/worker), service, task, stack, estado desejado × estado real, reconciliação.
- **Doc:** https://docs.docker.com/engine/swarm/ · https://docs.docker.com/engine/swarm/key-concepts/ · https://docs.docker.com/engine/swarm/how-swarm-mode-works/nodes/ · https://docs.docker.com/engine/swarm/how-swarm-mode-works/services/
- **Exercício:** desenhe o ciclo de uma task (`new` → `assigned` → `preparing` → `running` → ...) usando `docker service ps --no-trunc`.

### 3.2 Preparar as VMs e as portas
- **Doc:** https://docs.docker.com/engine/swarm/swarm-tutorial/ · https://docs.docker.com/engine/install/ (*) · https://docs.docker.com/engine/install/linux-postinstall/
- **Portas (conferido):** 2377/tcp (gestão do cluster), 7946/tcp+udp (descoberta entre nós), 4789/udp (VXLAN, configurável) e protocolo IP 50 (ESP) para overlay criptografada. A doc pede que 4789 nunca seja exposta fora da rede confiável.
- **Exercício:** crie 5 VMs pequenas (por exemplo multipass/libvirt/Vagrant, de 1 a 1,5 GB cada, rodando 3 a 5 por vez dentro dos 11 GB). Libere as portas e teste com `nc -zv` e `nc -zvu`.
- **Armadilhas:** VMs clonadas com o mesmo `machine-id` e o mesmo hostname confundem. Firewall que não libera ESP faz a overlay criptografada falhar em silêncio.

### 3.3 Criar o cluster e entrar nele
- **Doc:** https://docs.docker.com/engine/swarm/swarm-tutorial/create-swarm/ · https://docs.docker.com/engine/swarm/join-nodes/ · https://docs.docker.com/reference/cli/docker/swarm/init/ · https://docs.docker.com/reference/cli/docker/swarm/join/
- **Comandos:** `docker swarm init --advertise-addr <ip>`, `docker swarm join-token manager|worker`, `docker node ls`, `docker node promote/demote`, `--data-path-addr`, `--default-addr-pool`
- **Exercício:** suba 3 managers e 2 workers. Confira `Leader`/`Reachable` em `docker node ls`.
- **Armadilhas:** sem `--advertise-addr`, uma VM com várias interfaces anuncia o IP errado. O pool padrão 10.0.0.0/8 pode colidir com a sua rede.

### 3.4 Raft, quorum e quantidade de managers
- **Conceito:** com N managers o cluster tolera (N-1)/2 falhas. 3 managers toleram 1 falha. A doc recomenda número ímpar de managers e no máximo 7.
- **Doc:** https://docs.docker.com/engine/swarm/raft/ · https://docs.docker.com/engine/swarm/admin_guide/
- **Exercício:** com 3 managers, desligue 1: o cluster continua operando. Desligue 2: `docker service ls` falha por falta de quorum, mas as tasks que já rodam seguem vivas.
- **Armadilhas:** 2 managers são piores que 1, porque perder qualquer um quebra o quorum. Managers também recebem tasks; use drain se quiser managers dedicados.

### 3.5 Recuperação: backup, restore e force-new-cluster
- **Doc:** https://docs.docker.com/engine/swarm/admin_guide/#back-up-the-swarm · https://docs.docker.com/engine/swarm/admin_guide/#recover-from-disaster · https://docs.docker.com/engine/swarm/admin_guide/#force-the-swarm-to-rebalance
- **Comandos:** parar o Docker num manager e copiar `/var/lib/docker/swarm`, `docker swarm init --force-new-cluster --advertise-addr ...`, `docker swarm unlock` (com autolock)
- **Exercício:** faça o backup de um manager. Derrube 2 managers, rode `--force-new-cluster` no restante, confirme que os services voltam e depois readicione managers.
- **Armadilhas:** o backup inclui as chaves de criptografia do Raft. Com autolock ativo, você precisa também da unlock key. A doc diz para não restaurar o mesmo backup em vários nós.

### 3.6 Services: réplicas, global, scale
- **Doc:** https://docs.docker.com/engine/swarm/services/ · https://docs.docker.com/engine/swarm/swarm-tutorial/deploy-service/ · https://docs.docker.com/engine/swarm/swarm-tutorial/scale-service/ · https://docs.docker.com/reference/cli/docker/service/create/
- **Comandos:** `docker service create --replicas 3`, `--mode global`, `--mode replicated-job`/`global-job`, `docker service scale`, `ps`, `logs`, `inspect --pretty`
- **Exercício:** api com 3 réplicas, worker com 2, e um serviço global de exemplo (agente de métricas). O migrator vira `replicated-job`.
- **Armadilhas:** jobs (`replicated-job`) existem desde o Engine 20.10 e não estão no livro de 2020. `docker service logs` agrega o log de todas as réplicas.

### 3.7 Overlay networks, criptografia e attachable
- **Doc:** https://docs.docker.com/engine/network/drivers/overlay/ · https://docs.docker.com/engine/network/tutorials/overlay/ · https://docs.docker.com/engine/swarm/networking/
- **Comandos:** `docker network create -d overlay --opt encrypted --attachable backend`
- **Exercício:** crie as redes `edge`, `backend` e `db` (`internal`). Criptografe a `db` e use `tcpdump` na VM em `udp port 4789` para comparar o tráfego com e sem criptografia (sem criptografia aparece SQL em texto; com criptografia aparece ESP).
- **Armadilhas:** a criptografia tem custo de desempenho. A doc avisa que overlay criptografada não é suportada em nós Windows. Containers standalone só entram na rede se ela for `--attachable`.

### 3.8 Service discovery, DNS e VIP × dnsrr
- **Conceito:** cada service ganha um VIP e o DNS resolve o nome do service para o VIP, com balanceamento via IPVS. `tasks.<serviço>` resolve os IPs de todas as tasks. `endpoint_mode: dnsrr` dispensa o VIP.
- **Doc:** https://docs.docker.com/engine/swarm/networking/#configure-service-discovery · https://docs.docker.com/engine/network/drivers/overlay/
- **Exercício:** num container attachable, rode `nslookup api` (1 IP, o VIP) e `nslookup tasks.api` (3 IPs).
- **Armadilhas:** conexões persistentes (pool do Postgres) ficam presas a uma réplica, porque o IPVS balanceia por conexão.

### 3.9 Ingress routing mesh e modo host
- **Doc:** https://docs.docker.com/engine/swarm/ingress/
- **Comandos:** `--publish published=80,target=80`, `mode=host`, customizar a rede ingress (`docker network rm ingress` + criar com `--ingress`)
- **Exercício:** publique o traefik em 80/443. Acesse pelo IP de um worker que não roda o traefik e veja a resposta (o routing mesh). Depois mude para `mode: host` com `mode: global` e compare. Veja o IP de origem no log de acesso do Traefik nos dois modos.
- **Armadilhas:** no ingress, o IP de origem do cliente se perde (aparece o IP interno). Por isso Traefik costuma rodar com `mode: host`.

### 3.10 Placement: constraints, labels, preferences, max_replicas
- **Doc:** https://docs.docker.com/engine/swarm/services/#control-service-placement · https://docs.docker.com/reference/cli/docker/node/update/ · https://docs.docker.com/reference/compose-file/deploy/#placement
- **Comandos:** `docker node update --label-add db=true node4`, `node.labels.db==true`, `node.role==manager`, `placement.preferences.spread`, `max_replicas_per_node`
- **Exercício:** fixe o postgres no nó com label `db=true` (por causa do volume local). Espalhe a api por zona com labels `zone=a|b`.
- **Armadilhas:** use `node.labels` (definidas pelo operador), não `engine.labels`, que o próprio nó pode alterar. Uma constraint impossível deixa a task em `pending` para sempre.

### 3.11 Disponibilidade: drain, pause, active
- **Doc:** https://docs.docker.com/engine/swarm/swarm-tutorial/drain-node/ · https://docs.docker.com/engine/swarm/manage-nodes/
- **Exercício:** dê drain no worker1 e observe as tasks migrando. Volte para `active` e veja que o Swarm não rebalanceia sozinho (use `docker service update --force`).
- **Armadilhas:** drain não afeta containers standalone.

### 3.12 Secrets e configs no Swarm
- **Conceito:** ficam guardados criptografados no Raft e são entregues apenas aos nós com tasks que os usam, em tmpfs em `/run/secrets`. São imutáveis, e a rotação é feita criando um novo e trocando no service.
- **Doc:** https://docs.docker.com/engine/swarm/secrets/ · https://docs.docker.com/engine/swarm/configs/
- **Comandos:** `printf %s "$PW" | docker secret create db_password_v2 -`, `docker service update --secret-rm db_password_v1 --secret-add source=db_password_v2,target=db_password`
- **Exercício:** rotacione a senha do banco sem downtime da api, versionando o nome do secret.
- **Armadilhas:** não dá para atualizar um secret no lugar nem remover um secret em uso. Use `echo` com cuidado para não deixar a senha no histórico do shell.

### 3.13 Rolling update, rollback e healthcheck
- **Doc:** https://docs.docker.com/engine/swarm/swarm-tutorial/rolling-update/ · https://docs.docker.com/reference/compose-file/deploy/#update_config · https://docs.docker.com/reference/compose-file/deploy/#rollback_config · https://docs.docker.com/reference/cli/docker/service/update/ · https://docs.docker.com/reference/cli/docker/service/rollback/
- **Chaves:** `parallelism`, `delay`, `failure_action: pause|continue|rollback`, `monitor`, `max_failure_ratio`, `order: stop-first|start-first`
- **Exercício:** publique a v2 da api com `/health` quebrado, com `failure_action: rollback`, `order: start-first` e `monitor: 30s`. Observe o rollback automático em `docker service ps api` e `docker service inspect --format '{{json .UpdateStatus}}'`.
- **Armadilhas:** sem HEALTHCHECK, uma task é considerada saudável assim que entra em `running`. `start-first` com porta em mode host gera conflito de porta.

### 3.14 Restart policy e recursos no Swarm
- **Doc:** https://docs.docker.com/reference/compose-file/deploy/#restart_policy · https://docs.docker.com/reference/compose-file/deploy/#resources · https://docs.docker.com/engine/swarm/services/#reserve-memory-or-cpus-for-a-service
- **Exercício:** reserve 512M para o postgres num worker de 1 GB e escale a api até as tasks ficarem `pending` com "insufficient resources".

### 3.15 `docker stack deploy`
- **Doc:** https://docs.docker.com/reference/cli/docker/stack/deploy/ · https://docs.docker.com/engine/swarm/stack-deploy/
- **Comandos (conferido):** `docker stack deploy -c compose.yaml -c compose.prod.yaml swarmlab`, `--prune`, `--resolve-image always|changed|never`, `--with-registry-auth`, `--detach=false`, `docker stack ps/services/rm`
- **Exercício:** publique o SwarmLab a partir do mesmo `compose.yaml` com um override de swarm. Rode `--detach=false` para acompanhar a convergência.
- **Armadilhas:** `stack deploy` não faz build, então a imagem precisa estar num registry acessível a todos os nós. `--detach` é true por padrão. O comando não interpola `.env` como o `docker compose` faz; use `docker compose config` para gerar o arquivo final (veja a seção 3 deste documento).

### 3.16 Volumes no Swarm e perda de nó
- **Doc:** https://docs.docker.com/engine/swarm/services/#give-a-service-access-to-volumes-or-bind-mounts · https://docs.docker.com/engine/storage/volumes/#use-a-volume-driver (*) · cluster volumes (CSI, experimental): https://docs.docker.com/engine/swarm/ (*) e https://github.com/moby/moby/blob/master/docs/cluster_volumes.md (*)
- **Exercício:** com o postgres usando volume local no node4, derrube o node4: a task não pode subir em outro nó sem perder dados (ou fica pending por constraint). Documente o RPO dessa situação usando o backup da Fase 2.
- **Armadilhas:** volume local é por nó, e o Swarm não replica dados. Sem constraint, o Swarm recria o banco em outro nó com um volume vazio.

### 3.17 Segurança do cluster
- **Doc:** https://docs.docker.com/engine/swarm/how-swarm-mode-works/pki/ · https://docs.docker.com/engine/swarm/swarm_manager_locking/ · https://docs.docker.com/engine/security/protect-access/ · https://docs.docker.com/engine/security/ · https://docs.docker.com/engine/security/rootless/ · https://docs.docker.com/engine/security/userns-remap/
- **Comandos:** `docker swarm join-token --rotate worker|manager`, `docker swarm update --autolock=true`, `docker swarm unlock-key --rotate`, `docker swarm ca --rotate`, `docker swarm update --cert-expiry 720h`
- **Exercício:** rotacione o token de worker e prove que o token antigo falha num join. Ative autolock, reinicie um manager e veja que ele não volta sem `docker swarm unlock`. Exponha a API do Docker por SSH (`DOCKER_HOST=ssh://`) em vez de TCP sem TLS, e use `docker context`.
- **Armadilhas:** a doc avisa que TCP 2375 sem TLS dá root a qualquer um. A unlock key fica fora do cluster e, perdida, só se recupera com backup. O grupo `docker` equivale a root.

### 3.18 Contexts e operação remota
- **Doc:** https://docs.docker.com/engine/manage-resources/contexts/
- **Comandos:** `docker context create swarm --docker host=ssh://user@mgr1`, `docker --context swarm node ls`

### 3.19 Observar o cluster
- **Doc:** https://docs.docker.com/reference/cli/docker/service/logs/ · https://docs.docker.com/reference/cli/docker/system/events/ · https://docs.docker.com/engine/daemon/prometheus/ (*)
- **Exercício:** use `docker events --filter type=service` durante um update.

### 3.20 Traefik no Swarm
- **Doc (externa):** https://doc.traefik.io/traefik/providers/swarm/ (no Traefik v3 o Swarm é um provider separado do Docker)
- **Exercício:** traefik global nos managers em `mode: host`, com labels em `deploy.labels` (não em `labels`) e `loadbalancer.server.port` explícito.
- **Armadilhas:** labels no nível do container não são vistos pelo provider Swarm.

---

## 2. Funcionalidades novas/recentes (2023-2026) que um livro de ~2020 não cobre

| Tema | O que mudou | URL |
|---|---|---|
| Compose v2 | `docker compose` como plugin em Go. O v1 (`docker-compose`, Python) perdeu suporte em 2023. | https://docs.docker.com/compose/intro/history/ |
| Compose Specification | Um único formato sem versões 2.x/3.x. `version:` é obsoleto e só gera aviso. | https://docs.docker.com/reference/compose-file/version-and-name/ |
| `compose.yaml` | O nome preferido do arquivo. | https://docs.docker.com/compose/intro/compose-application-model/ |
| `develop.watch` / `compose watch` | Sync e rebuild automáticos em dev. | https://docs.docker.com/compose/how-tos/file-watch/ |
| `include:` | Compor projetos a partir de outros arquivos. | https://docs.docker.com/compose/how-tos/multiple-compose-files/include/ |
| `!reset` / `!override` | Controle fino do merge. | https://docs.docker.com/reference/compose-file/merge/ |
| `depends_on.restart`, `required` | Opções novas de dependência. | https://docs.docker.com/reference/compose-file/services/#depends_on |
| `service_completed_successfully` | Habilita o padrão migrator. | https://docs.docker.com/compose/how-tos/startup-order/ |
| `up --wait` | Bloqueia até os serviços ficarem healthy. | https://docs.docker.com/reference/cli/docker/compose/up/ |
| Lifecycle hooks `post_start`/`pre_stop` | Hooks de ciclo de vida. | https://docs.docker.com/compose/how-tos/lifecycle/ |
| `configs.content` / `secrets.environment` | Conteúdo inline. | https://docs.docker.com/reference/compose-file/configs/ |
| BuildKit padrão | Padrão no Engine 23+, e `docker build` usa buildx. | https://docs.docker.com/build/buildkit/ |
| `RUN --mount` (cache/secret/ssh/bind) | Disponível no Dockerfile 1.2+ e estável. | https://docs.docker.com/reference/dockerfile/#run---mount |
| `COPY --link`, `--chmod`, `--parents`, `--exclude` | Opções novas de COPY. | https://docs.docker.com/reference/dockerfile/#copy |
| Heredocs no Dockerfile | `RUN <<EOF`. | https://docs.docker.com/reference/dockerfile/#here-documents |
| Build checks | `--check` e `# check=`. | https://docs.docker.com/build/checks/ |
| Bake | Builds declarativas (HCL/Compose). | https://docs.docker.com/build/bake/ |
| Attestations (SBOM, provenance) | Metadados de supply chain. | https://docs.docker.com/build/metadata/attestations/ |
| `docker init` | Scaffolding. | https://docs.docker.com/reference/cli/docker/init/ |
| Docker Scout | Substitui o antigo `docker scan` (Snyk). | https://docs.docker.com/scout/ |
| Docker Hardened Images | Bases endurecidas. | https://docs.docker.com/dhi/ (*) |
| Containerd image store | Padrão em instalações novas do Engine 29. | https://docs.docker.com/engine/storage/containerd/ |
| `HEALTHCHECK --start-interval` | Engine 25+. | https://docs.docker.com/reference/dockerfile/#healthcheck |
| Swarm jobs | `replicated-job` e `global-job`, Engine 20.10. | https://docs.docker.com/reference/cli/docker/service/create/ |
| `stack deploy` com múltiplos `-c` e `--detach` | `--detach` padrão true. | https://docs.docker.com/reference/cli/docker/stack/deploy/ |
| Cluster volumes (CSI) no Swarm | Experimental. | https://docs.docker.com/engine/swarm/ (*) |
| Traefik v3 provider `swarm` separado | Provider próprio para Swarm. | https://doc.traefik.io/traefik/providers/swarm/ |
| `docker scan`, `--link`, `docker-machine` | Removidos ou obsoletos. | https://docs.docker.com/engine/deprecated/ |

Leia a página de features obsoletas (https://docs.docker.com/engine/deprecated/) e as release notes (https://docs.docker.com/engine/release-notes/) antes de seguir qualquer receita do livro.

---

## 3. Compose × Swarm (`docker stack deploy`)

Fontes: https://docs.docker.com/reference/cli/docker/stack/deploy/ (conferido: exige Compose >= 3.0 e avisa "Ignoring unsupported options" — exemplo `links`) · https://docs.docker.com/reference/compose-file/deploy/ · https://docs.docker.com/engine/swarm/stack-deploy/ · https://docs.docker.com/reference/compose-file/services/ (cada chave indica se é ignorada no Swarm) (*)

**Suportadas e específicas do Swarm (bloco `deploy:`):** `mode` (replicated/global, e jobs), `replicas`, `placement` (constraints, preferences, max_replicas_per_node), `resources` (limits/reservations), `restart_policy`, `update_config`, `rollback_config`, `endpoint_mode` (vip/dnsrr), `labels` (do service, as que o Traefik lê). Também: `secrets`/`configs` com `external: true`, redes `overlay` com `attachable`/`encrypted` via `driver_opts`, `healthcheck`, `ports` em sintaxe longa com `mode: host|ingress`.

**Ignoradas ou não suportadas pelo `stack deploy` (verifique a mensagem "Ignoring unsupported options" na saída):**
- `build` (não há build: use a imagem de um registry)
- `depends_on` (sem ordem de start; a app precisa de retry)
- `links`, `external_links` (o exemplo da própria doc)
- `container_name` (as tasks recebem nome gerado)
- `restart` (use `deploy.restart_policy`)
- `network_mode`, `cgroup_parent`, `devices` (*), `userns_mode`, `security_opt` (*), `cap_add/cap_drop` (só suportadas em versões recentes do Engine; confirme na referência de services) (*)
- `profiles`, `develop` (watch), `include` e `extends` (*): são recursos do `docker compose`. Gere o arquivo final com `docker compose config` antes do stack deploy.
- `env_file` e `.env`: o stack deploy não lê `.env` automaticamente para interpolação (*). Exporte as variáveis ou use `docker compose config > stack.yml`.
- `tmpfs` com opções, `sysctls` (*)

**Diferenças de comportamento:**
- Secrets no Compose são bind mounts de arquivo. No Swarm ficam criptografados no Raft e são entregues em tmpfs.
- Recursos: no Compose v2, `deploy.resources.limits` é aplicado localmente. No Swarm, as `reservations` também afetam o agendamento.
- `ports` publicadas: no Swarm o padrão é o ingress mesh em todos os nós. No Compose a porta é publicada só no host local.
- Redes: no Swarm o driver padrão é `overlay`. No Compose é `bridge`.
- Volumes: no Swarm o volume é criado no nó onde a task cai.

Exercício de consolidação: rode `docker compose -f compose.yaml -f compose.swarm.yaml config > stack.yml` e depois `docker stack deploy -c stack.yml swarmlab --detach=false 2>&1 | tee deploy.log`. Liste cada "Ignoring unsupported options" e marque item a item a lista acima com a sua observação.

---

## 4. Experimentos de falha e observação

### Fase 1 (notebook)
1. **Sinal e shell form.** Hipótese: CMD em shell form atrasa o stop. Provocar: trocar o CMD e rodar `time docker stop`. Observar ~10 s e exit 137, contra ~0 s e exit 0 em exec form.
2. **OOM.** Hipótese: passar do limite de memória mata o processo. Provocar: `--memory 64m` e um endpoint que aloca 200 MB. Observar `OOMKilled: true` e exit 137 no `docker inspect`, e `dmesg`.
3. **Vazamento por ARG.** Hipótese: um segredo passado por ARG fica na imagem. Provocar: `--build-arg TOKEN=abc`. Observar o token em `docker history --no-trunc`. Repetir com `--mount=type=secret` e ver que ele some.
4. **Invalidação de cache.** Hipótese: COPY do código antes de `uv sync` refaz as dependências a cada mudança. Provocar: inverter a ordem e editar um .py. Observar `uv sync` sem `CACHED`.
5. **Read-only.** Hipótese: `--read-only` quebra a escrita em `/tmp`. Provocar e corrigir com `--tmpfs /tmp`.
6. **Healthcheck unhealthy.** Hipótese: um `/health` que retorna 500 leva a `unhealthy` depois de `retries`. Observar `.State.Health.Log`.
7. **Logs sem rotação.** Hipótese: `json-file` sem `max-size` cresce sem limite. Provocar: log em loop por 1 minuto. Observar o tamanho do arquivo em LogPath; depois aplicar `max-size=1m` e ver a rotação.
8. **Scout como gate.** Hipótese: `docker scout cves --exit-code --only-severity critical` falha numa base antiga. Provocar: usar uma tag antiga do Python. Observar o exit code diferente de zero.
9. **Tag mutável.** Hipótese: `:latest` muda sem aviso. Provocar: `docker pull` e comparar digests em dias diferentes.
10. **Root × não-root.** Hipótese: sem USER, o processo roda como root. Observar com `docker exec id` e com `ps` no host.

### Fase 2 (notebook)
1. **Ordem de start.** Sem `condition: service_healthy`, a api sobe antes do banco. Observar o erro de conexão no log; com condition, ele desaparece.
2. **Migrator falha.** Hipótese: `service_completed_successfully` barra a api. Provocar: `exit 1` no migrator. Observar a api em `Created` e não `Up`.
3. **Banco cai depois do start.** Provocar: `docker compose stop postgres`. Observar se a api e o worker se reconectam ao `start` (o retry é da app; `depends_on` não ajuda).
4. **Rede interna.** Provocar: `docker compose exec postgres` tentando acesso externo. Observar a falha. O traefik tentando resolver `postgres` também falha.
5. **Porta exposta indevidamente.** Provocar: publicar `5432:5432` e conferir com `ss -ltn` em `0.0.0.0`. Ver que o UFW não bloqueia (packet-filtering-firewalls).
6. **`down -v`.** Hipótese: apaga os dados. Provocar no projeto de teste. Observar o banco vazio. Com bind mount, o diretório permanece.
7. **SKIP LOCKED com escala.** `--scale worker=3` e 1000 jobs. Observar zero processamento duplicado (consulta de contagem por job_id).
8. **Worker morto no meio do job.** `docker compose kill -s SIGKILL worker` durante um job. Observar se o lock é liberado (a transação aborta) e o job volta para a fila. Repetir com SIGTERM para ver o shutdown gracioso.
9. **`stop_grace_period`.** Um job longo (30 s) com grace de 10 s. Observar o SIGKILL. Aumente para 40 s e veja o término limpo.
10. **Backup/restore.** Hipótese: um tar do volume com o banco rodando pode corromper. Observar comparando pg_dump e restore (consistentes) com o tar a quente.
11. **Override merge.** `ports` em base e override são concatenados. Observar com `config`. Corrigir com `!reset`.
12. **Interpolação obrigatória.** Rodar sem `API_TAG` e observar a falha com mensagem clara.
13. **Limite de CPU.** `cpus: 0.25` no worker e um job pesado. Observar o throttling em `docker stats`.
14. **watch.** Editar um arquivo e observar o sync; editar `uv.lock` e observar o rebuild.

### Fase 3 (VMs pequenas; não precisa manter as 5 ligadas ao mesmo tempo)
1. **Perda de 1 de 3 managers.** Observar que o cluster segue e outro líder é eleito (`docker node ls`).
2. **Perda de 2 de 3 managers.** Observar a perda do quorum: comandos de gestão falham e as tasks existentes continuam. Recuperar com `--force-new-cluster`.
3. **Perda de um worker.** Observar as tasks reagendadas (o nó vira `Down` depois do heartbeat) e o tempo até o reagendamento.
4. **Banco num nó que morre.** Com constraint, a task fica pending. Sem constraint, ela sobe noutro nó com volume vazio. Ver a perda de dados e o RPO.
5. **Rolling update quebrado.** Imagem com /health falho e `failure_action: rollback`. Observar o rollback automático.
6. **start-first × stop-first.** Medir a disponibilidade com `curl` em loop durante o update. Observar erros apenas no stop-first.
7. **Routing mesh.** `curl` no IP de um nó sem réplica: responde. Observar o IP de origem no log do Traefik (ingress × host).
8. **VIP × tasks.** `nslookup api` e `nslookup tasks.api`. Escalar e ver a lista mudar.
9. **Overlay criptografada.** `tcpdump -i any udp port 4789` com e sem `encrypted`. Observar texto claro × ESP. Bloquear o protocolo 50 no firewall e ver a comunicação falhar.
10. **Firewall.** Bloquear 7946 num nó e observar falhas de descoberta e de rede overlay (resolução de serviço falha nesse nó).
11. **Constraint impossível.** `node.labels.gpu==true` e a task fica pending. Observar a mensagem em `docker service ps --no-trunc`.
12. **Reservas excessivas.** Observar "insufficient resources".
13. **Drain.** Drain de um worker: tasks migram. Voltar para active: não rebalanceia até `update --force`.
14. **Rotação de token.** O join com o token antigo falha depois de `--rotate`.
15. **Autolock.** Reiniciar o Docker num manager com autolock ativo e ver que ele não entra no cluster sem `unlock`.
16. **Rotação de secret.** Trocar `db_password_v1` por `v2` e observar as tasks recriadas. Tentar `docker secret rm` em uso e ver o erro.
17. **stack deploy ignorando chaves.** Observar os avisos "Ignoring unsupported options" (por exemplo `build`, `depends_on`).
18. **Imagem só local.** Deploy de uma imagem que só existe no manager. Observar tasks em outros nós com "No such image" e rejeitadas. Corrigir com o registry e `--with-registry-auth`.
19. **Backup do Swarm.** Parar o Docker, copiar `/var/lib/docker/swarm`, destruir o nó e restaurar seguindo o admin guide.

**Orçamento de RAM sugerido (11 GB):** 3 VMs de 1,5 GB (managers) e 2 de 1 GB (workers) dão 6,5 GB. Isso é viável fechando o resto. Para reduzir, use managers sem workload (drain) com 768 MB a 1 GB. O requisito mínimo de RAM por nó não foi confirmado na doc do Engine (*), então ajuste depois de medir com `free -m`.
