# Inventário de estudo — "Learn Docker in a Month of Lunches" × SwarmLab (Fases 1–3)

> Fonte varrida: `/home/lucas/Documents/Livros TI/07.learn_docker_ina_month.pdf` (490 págs. de PDF).
> **Páginas citadas = numeração impressa do livro** (página do PDF = impressa + 26; ex.: p. 99 do livro = p. 125 do PDF).
> "TIN" = exercício "Try it now". "Lab" = lab de fim de capítulo. Repositório do livro: `github.com/sixeyed/diamol`, branch `2e` (p. 13).

## 0. Correção de premissa (leia antes de tudo)

O arquivo **não é a 1ª edição (2020)**. É a **2ª edição, ©2025** (p. iv do PDF; ISBN 9781633438460), com saídas de `docker version` 28.2.2 / Compose v2.36.2 (p. 13). Consequências práticas:

1. **Compose já é o v2 (`docker compose`)**: o texto diz que o comando "used to be separate from the Docker CLI but is now built-in" (p. 101). Nenhuma listagem de Compose usa a chave `version:` — todas começam em `services:`. Restam só **três resíduos** de `docker-compose` com hífen (p. 101 texto, p. 113 texto, p. 145 comando, p. 421 comando do override Windows do Traefik).
2. **Docker Swarm NÃO é ensinado.** A única menção ao Swarm no livro inteiro é p. 281: "There used to be a choice of orchestration platforms: Docker Swarm, Apache DC/OS, and HashiCorp Nomad… there isn't really a choice any more" — o livro escolhe Kubernetes (cap. 15). Não há `docker swarm init`, `docker service`, `docker stack`, overlay, routing mesh, Raft, placement, drain, configs/secrets de cluster, rolling update de serviço nem rollback de Swarm. **A Fase 3 é quase inteiramente lacuna** (ver §4); o livro contribui só com fundamentos transferíveis (registry, health/dependency checks, config em camadas, logs, proxy, conceitos de orquestrador do cap. 15).
3. O livro é **multiplataforma/Windows-heavy** (comandos em PowerShell com crase como continuação de linha — p. 12; no Bash troque por `\`) e usa apps .NET/Java/Go/Node. **Python aparece só de passagem** (p. 53, 55, 56, 344); **uv nunca aparece**.

---

## 1. Mapa do livro → fases do SwarmLab

| Cap. | Título (páginas) | Fase(s) | Por quê |
|---|---|---|---|
| 1 | Before you begin (3–14) | 1 (setup) | Instalação, shell, verificação `docker version`/`docker compose version`, comandos de limpeza (p. 14). Avisa que "Docker doesn't connect multiple physical machines together" (p. 11) — motivação da Fase 3. |
| 2 | Understanding Docker and running Hello World (15–30) | 1 (revisão) + 3 (API do Engine) | Container = processo, `ls/top/logs/inspect/stats`, `--detach/--publish`, estados Exited; arquitetura Engine/API/CLI e API remota (p. 28–29) — base para segurança da API na Fase 3. |
| 3 | Building your own Docker images (31–44) | 1 (já visto) | Dockerfile, `ENV`, build context, camadas, `docker system df`, cache. Revisão rápida. |
| 4 | Packaging applications from source code (45–60) | 1 (já visto) + 2 (primeira rede) | Multi-stage; **primeira rede definida pelo usuário** (`docker network create nat`, `--network`, DNS por nome do container, p. 51–58). |
| 5 | Sharing images with Docker Hub and other registries (61–76) | 1 → **3** | Tags, push, **registry próprio em container**, `daemon.json` e `insecure-registries` (p. 69–71), estratégia de tags semver (p. 72–74), golden images. No Swarm todos os nós precisam puxar a imagem de um registry. |
| 6 | Using Docker volumes for persistent storage (77–96) | **2** (+3: volume local × perda de nó) | Camada gravável, volumes nomeados, `VOLUME`, bind mount, mount read-only, sombra de diretório, storage distribuído e o caso **Postgres + Azure Files** (p. 94). |
| 7 | Running multi-container apps with Docker Compose (99–117) | **2** | Anatomia do Compose, `up/down/stop/start/ps/logs`, `--scale`, DNS de serviço com múltiplos IPs, rede externa, `environment`, `secrets` de arquivo, Postgres em container. |
| 8 | Health checks and dependency checks (118–137) | 1 + **2** + 3 | `HEALTHCHECK`, `unhealthy` não reinicia nada em engine único (p. 123–124), dependency check no `CMD`, utilitário de check na linguagem do app, `healthcheck:` e `restart: on-failure` no Compose, autocura em cluster. |
| 9 | Adding observability with containerized monitoring (138–162) | 2 (parcial) / divergente | Prometheus + Grafana em Compose; `metrics-addr` no `daemon.json` (p. 139–140). **A casa não usa Prometheus/Grafana** — aproveitar só os conceitos (níveis de observabilidade, p. 160). |
| 10 | Running multiple environments with Docker Compose (163–183) | **2** | Nome de projeto `-p`, override files, `docker compose config`, isolamento por rede, `environment`/`env_file`/`secrets`/`.env`, `COMPOSE_FILE`/`COMPOSE_PROJECT_NAME`, extension fields `x-` + YAML merge. Base direta de dev/test/prod. |
| 11 | Building and testing apps with Docker and Docker Compose (184–204) | 2 (+1) | CI em containers (Gogs/Jenkins/registry), montagem de `docker.sock` e seu risco (p. 193), `build:` no Compose, `ARG`/`LABEL`, `${VAR:-default}` em tags de imagem. |
| 12 | Running containers on different platforms (207–227) | 1 (opcional) / 3 (contexts) | Multi-arch, manifests, Buildx; **`docker context`** (p. 222–223) e nota de que engines remotos precisam ser protegidos com SSH ou TLS (p. 222). Útil se as VMs tiverem arquitetura diferente do host. |
| 13 | Replatforming the legacy: Windows apps (228–248) | **fora** | Windows Server Containers/.NET Framework/SQL Server. Útil: **`depends_on` com `condition: service_healthy`** (listagem 13.5, p. 244–245) — o único lugar do livro onde isso aparece. |
| 14 | Containers in the cloud with Azure and Google Cloud (249–280) | **fora** | Azure Container Apps/Cloud Run. Útil: comparação registry privado × Docker Hub (14.2, p. 256), flags `--cpu/--memory` como ideia de cota (p. 250–261, mas na CLI do Azure). |
| 15 | Kubernetes: A primer (281–306) | **fora** (Kubernetes) | Útil como ponte conceitual para a Fase 3: orquestrador, estado desejado, réplicas, rollout escalonado que não substitui pods velhos se os novos não sobem (p. 297–298), config imutável no container → mudança gera rollout (p. 301), ConfigMaps/Secrets ≈ configs/secrets do Swarm. |
| 16 | CI/CD in the cloud with Docker and GitHub Actions (307–332) | 2 (smoke test) / fora (deploy K8s) | GHCR, labels de rastreabilidade, **smoke test end-to-end com Compose** (16.3, p. 322–325), estrutura portável de build (16.5). Deploy em Kubernetes (16.4) fora. |
| 17 | Optimizing your Docker images for size, speed, and security (335–359) | **1** | Deletar em camada posterior não reduz, `.dockerignore`, base mínima, **Trivy** (vuln, repo, misconfig), `USER`/FS read-only, `--no-install-recommends`, `--target`, ordem por frequência de mudança, versões explícitas. |
| 18 | Application configuration management in containers (360–381) | **2** (+3: configs/secrets) | Config em 3 níveis (release/ambiente/feature), override por arquivo em diretório conhecido + env var ganhando (12-factor), segredos fora da imagem, API de config segura, Compose documentando config. |
| 19 | Writing and managing application logs with Docker (382–404) | **2** (+3) | stdout/stderr, driver `json-file` e onde fica o log, **rotação `max-size`/`max-file`**, relay de log de arquivo, drivers de log (Fluentd/EFK), `logging:` no Compose, coletor por nó em cluster (p. 403). |
| 20 | Controlling HTTP traffic with a reverse proxy (405–432) | **2** (+3) | Proxy como único container com portas publicadas; nginx (20.1–20.3) e **Traefik por labels** (20.4): entrypoints/routers/services/middlewares, `Host()`, path prefix + strip, HTTPS com cert autoassinado, sticky sessions. |
| 21 | Asynchronous communication with a message queue (433–451) | 2 (conceitos) / divergente | Pub-sub com Redis e NATS, handlers escalados com `--scale`, mensagens perdidas sem assinante (p. 440–441). **O SwarmLab usa Postgres como fila** — aproveitar padrões, não as tecnologias. |
| 22 | Never the end (452–~456) | — | PoC, como vender Docker; sem conteúdo técnico novo. |

---

## 2. Conceitos por fase, em ordem pedagógica sugerida

Formato de cada item: **Conceito** — referência — exercício do livro (o que o livro manda fazer) → **adaptação SwarmLab** — armadilhas que o livro aponta.

### Fase 1 — Containerização da API FastAPI (complemento ao que o aluno já fez)

O aluno já cobriu Dockerfile básico, multi-stage, cache, `.dockerignore`, `USER`, `HEALTHCHECK`. O que o livro ainda acrescenta para a Fase 1:

1. **Container como processo e ciclo de vida (revisão)** — cap. 2, §2.3–2.4, p. 20–27.
   - TIN: `docker run --interactive --tty diamol/base:2e` (p. 21); `docker container ls/top/logs/inspect` (p. 22–23); `docker container ls --all` mostrando `Exited (0)` (p. 24); `run --detach --publish 8088:80` (p. 25); `docker container stats` (p. 27); `rm --force $(docker container ls --all --quiet)` (p. 27).
   - → SwarmLab: rodar a imagem da API com `-d -p 8000:8000`, inspecionar com `top` (ver que uvicorn é o processo), `stats`, `logs`, e o código de saída depois de matar o processo.
   - Armadilhas: containers parados **continuam existindo e ocupando disco** (p. 24); `ls` só mostra os em execução; o `rm -f $(...)` "won't ask for confirmation" (p. 27).
2. **Engine, API e CLI** — cap. 2, §2.5, p. 27–29.
   - Sem TIN específico (teoria). Pontos: o CLI é só cliente da API REST; a API pode ser exposta à rede; containerd/OCI por baixo.
   - → SwarmLab: guardar esta ideia para a Fase 3 (gerenciar nós remotos e proteger a API).
   - Armadilha (implícita): expor a API na rede sem proteção — o livro só diz que é configurável (p. 28) e que exige SSH ou TLS (p. 222).
3. **Variáveis de ambiente como entrada do app** — cap. 3, §3.1–3.3, p. 31–38.
   - TIN: `docker container run --env TARGET=google.com diamol/ch03-web-ping:2e` (p. 34); `-e TARGET=docker.com -e INTERVAL=5000` (p. 38).
   - → SwarmLab: a API lê `DATABASE_URL`, `LOG_LEVEL` etc. de env (pydantic-settings), com default que funciona sem nada.
4. **Camadas, tamanho lógico × físico** — cap. 3, §3.4, p. 39–41.
   - TIN: `docker image ls` + `docker system df` (p. 40–41).
   - → SwarmLab: medir a imagem da API e o cache de build do uv.
5. **Deletar arquivo em camada posterior não reduz a imagem** — cap. 17, §17.1, p. 336–339.
   - TIN: build de `ch17-build-context` v1 e v2 (com `RUN rm -rf docs`) e comparar tamanhos (p. 337); `docker history` (p. 338).
   - → SwarmLab: provar com `docker history` que `uv sync` + limpeza em outro `RUN` não economiza; usar multi-stage (venv copiado) em vez disso.
   - Armadilha: "Once data is in a layer, there's no way to remove it from the image" (p. 338).
6. **Build context e `.dockerignore`** — §17.1, p. 340–341.
   - TIN: `docker build ... --no-cache .` com e sem `.dockerignore` (p. 340).
   - → SwarmLab: confirmar que `.venv/`, `.git/`, `__pycache__/`, `.env` ficam fora do contexto (o livro recomenda incluir `.git` no ignore, p. 341).
7. **Escolha de imagem base: tamanho e superfície de ataque** — §17.2, p. 341–344.
   - TIN: app Java com JDK na imagem e "breakout" simulado compilando código dentro do container (p. 342–343).
   - → SwarmLab: comparar `python:3.x-slim` × alpine × distroless para a API; o livro abre exceção: em linguagens interpretadas (cita Python) "the build tool is the runtime" (p. 344) — mas o **uv** é ferramenta de build e não precisa ir para o estágio final.
   - Armadilha: curl na imagem é útil a invasor (p. 341); ferramenta de build na imagem final permite executar código arbitrário.
8. **Varredura de vulnerabilidade e misconfiguração com Trivy** — §17.2, p. 344–348.
   - TIN: `docker run -v trivy-cache:/root/.cache -it diamol/trivy:2e image --scanners vuln ...` com `--severity HIGH,CRITICAL` e `--ignorefile` (p. 344); `repository --scanners vuln` (p. 346); `--scanners misconfig` (p. 346).
   - → SwarmLab: varrer a imagem da API, o repo (`uv.lock` é lido como lista de dependências) e o Dockerfile; manter `.trivyignore` versionado; virar passo de gate que **reprova** (o livro: "You can supply an exit code to Trivy so that if it finds problems, the pipeline fails", p. 346).
   - Armadilhas: a base de vulnerabilidades muda; a misconfig mais comum é rodar como root (p. 348); FS read-only pode quebrar apps que precisam escrever.
9. **Instalação enxuta de pacotes do SO** — §17.3, p. 348–352.
   - TIN: `ch17-socat` v1 × v2 (`--no-install-recommends` + `rm -rf /var/lib/apt/lists/*` no mesmo `RUN`, p. 349–350); `ch17-ml-dataset` (baixar/extrair só o necessário, p. 350–352).
   - → SwarmLab: se a imagem precisar de `libpq` ou similar, aplicar o padrão em um único `RUN`.
10. **Multi-stage avançado: `--target`, cache por estágio, ordem por frequência de mudança** — §17.4, p. 352–357.
    - TIN: `docker image build ... --target download` / `--target expand` (p. 353); Jenkins v1 × v2 medindo tempo de rebuild (p. 354).
    - → SwarmLab: estágio `deps` (uv sync só com `pyproject.toml`+`uv.lock`) antes do código; `--target test` para rodar pytest dentro da imagem de build.
    - Armadilha: "don't over-cache": `RUN` de instalação fica em cache até a linha mudar → **fixar versões** (p. 355).
11. **Health check embutido e utilitário de check na linguagem do app** — cap. 8, §8.1 e §8.3, p. 118–131.
    - TIN: `ch08-numbers-api` sem e com `HEALTHCHECK` (p. 119–122); `docker container inspect` para ver `State.Health` com "failing streak" (p. 123); `--health-interval 5s` no `run` (p. 129).
    - → SwarmLab: trocar `curl` por um script Python (`python -c` ou módulo `healthcheck.py` usando `urllib`) para não precisar de curl na imagem slim.
    - Armadilhas: **um container `unhealthy` não é reiniciado nem substituído pelo Docker Engine sozinho** (p. 123–124); padrão é 30 s e 3 falhas (p. 121); check caro consome CPU/memória (p. 132, 136).
12. **ARG × ENV, LABEL e rastreabilidade da imagem** — cap. 11, §11.3, p. 196–199.
    - TIN: `docker compose -f docker-compose.yml -f docker-compose-build.yml build` e `docker image inspect -f '{{.Config.Labels}}'` (p. 195); `docker image build ... --build-arg BUILD_TAG=ch11` (p. 198).
    - → SwarmLab: `ARG GIT_SHA`/`BUILD_DATE` com default e `LABEL` (de preferência as chaves padrão `org.opencontainers.image.*`, que o livro não cita) na imagem da API.
    - Armadilha: `ARG` só existe no build; containers não veem (p. 197); sempre ter default no Dockerfile **e** no Compose (p. 198).
13. **Registries, tags e versionamento** — cap. 5, p. 61–76.
    - TIN: `docker login`, `docker image tag`, `docker image push` (p. 63–65); **registry local** `docker container run -d -p 5010:5000 --restart always diamol/registry:2e` (p. 67); tag `registry.local:5010/gallery/ui:v1` (p. 68); `docker info` para ver `insecure-registries` (p. 71); tags `latest`, `2`, `2.1`, `2.1.106` (p. 72).
    - → SwarmLab: subir um registry (imagem oficial `registry:2`/`distribution`) que será a fonte de imagens para os 5 nós na Fase 3; tag por versão semântica + SHA.
    - Armadilhas: registry HTTP exige entrada em `insecure-registries` no `daemon.json` (p. 69–70) — e é o que o livro faz; **na Fase 3 prefira TLS**; não dá para buscar/apagar imagens pela CLI, só pela API v2 do registry (lab p. 75–76); `latest` não diz nada sobre versão (§5.4).
14. **Golden images** — §5.5, p. 74–75; §17.2, p. 344.
    - TIN: build de `golden/dotnet-sdk:2e` e `golden/aspnet:2e` (p. 75).
    - → SwarmLab: opcional — uma base Python interna com usuário não-root e ajustes, da qual API, worker e migrator derivam.

### Fase 2 — Compose multi-container (api, worker, postgres, migrator, Traefik)

Ordem sugerida: dados → redes → Compose → saúde/ordem → config/segredos → ambientes → logs → proxy → build/testes → padrões de fila → backup.

1. **Por que o dado do container é efêmero (camada gravável, copy-on-write)** — cap. 6, §6.1, p. 77–82.
   - TIN: `rn1`/`rn2` + `docker container cp` (p. 78); `f1` + `cp url.txt f1:/input.txt` + `start --attach` (p. 80); `rm -f f1` e o dado some (p. 81).
   - → SwarmLab: subir um Postgres **sem** volume, criar tabela, `docker rm -f`, recriar → tabela sumiu. Esse é o "porquê" do volume.
   - Armadilha: parar ≠ remover; o dado só some na remoção (p. 79).
2. **Volumes nomeados, `VOLUME` no Dockerfile e `-v`** — §6.2, p. 82–87.
   - TIN: `todo1` + `inspect --format '{{json .Mounts}}'` + `docker volume ls` (p. 82–83); `--volumes-from` (p. 84); `docker volume create todo-list` e upgrade v1→v2 mantendo dados (p. 85–86).
   - → SwarmLab: volume nomeado `pgdata` em `/var/lib/postgresql/data`; trocar a tag do Postgres de patch e confirmar que os dados sobrevivem (ver lacuna: major exige `pg_upgrade`/dump).
   - Armadilhas: a imagem oficial do Postgres declara `VOLUME` → sem `-v` nasce **volume anônimo com ID aleatório** que você não acha depois (p. 87); compartilhar volume entre containers que escrevem o mesmo arquivo é má ideia (p. 85); "as an image user, it's better not to rely on the defaults and to work with named volumes" (p. 87).
3. **Bind mounts (inclusive read-only)** — §6.3, p. 88–91.
   - TIN: `--mount "type=bind,source=$source,target=$target"` com diretório `databases` (p. 88); config read-only `--mount "...,readonly"` em `/app/config` (p. 89–90).
   - → SwarmLab: bind de código para hot-reload só no override de **dev**; bind read-only para arquivos de config do Traefik; e — padrão da casa — **dados do Postgres em bind mount** em produção.
   - Armadilhas: bind é bidirecional e o livro nota que escrever no host exige permissão elevada, por isso aquela imagem roda como root (p. 89) → no SwarmLab, acertar UID/GID em vez de rodar como root.
4. **Limitações de mounts** — §6.4, p. 91–94.
   - TIN: `ch06-bind-mount` sem e com mount (diretório alvo é **substituído/sombreado**, p. 91–92); mount de arquivo único (p. 92–93).
   - → SwarmLab: montar `./config` em `/app` por engano esconde o código da imagem; teste isso de propósito.
   - Armadilhas: mount sombreia o diretório existente (p. 91); storage distribuído pode não suportar operações (Postgres em Azure Files falha em hard links, p. 94) e tem desempenho de rede — **relevante para "volume em NFS" no Swarm**.
5. **Modelo mental do filesystem** — §6.5, p. 94–96 (guia de quando usar camada gravável, bind local, bind distribuído, volume, camadas).
6. **Redes definidas pelo usuário e DNS** — cap. 4, p. 51–58; cap. 7, §7.3, p. 108–111.
   - TIN: `docker network create nat` + `--network nat` (p. 51–52); `docker compose up -d --scale iotd=3` + `exec -it ... sh` + `nslookup accesslog` (p. 109); remover container e ver o DNS seguir funcionando, `nslookup iotd` com 3 IPs (p. 110).
   - → SwarmLab: `nslookup postgres` de dentro do worker; escalar o worker para 3 e ver 3 IPs; entender que a API usa o **nome do serviço** em `DATABASE_URL`.
   - Armadilhas: IP muda a cada recriação, nunca fixe IP (p. 108–110); com vários IPs, o balanceamento é responsabilidade do cliente — "some apps take a simple approach of using the first address" (p. 110).
7. **Anatomia do Compose e ciclo de comandos** — cap. 7, §7.1–7.2, p. 99–108.
   - TIN: `docker compose up` (p. 101); `up --detach` (p. 104); `up -d --scale iotd=3` + `logs --tail=1 iotd` (p. 105); `stop`/`start`/`docker container ls` (p. 106); `down` + `up -d` volta a escala para 1 (p. 107).
   - → SwarmLab: primeiro `compose.yaml` com `api` + `postgres`; depois adicionar `worker`, `migrator`, `traefik`.
   - Armadilhas: Compose é **cliente**; o Engine não sabe que os containers formam um app (p. 107); escala feita na linha de comando não fica no arquivo e é perdida no `down`/`up` (p. 107); `down` remove redes e volumes declarados que não são `external` — ver lacuna sobre `down -v`; rede `external: true` precisa existir antes (p. 101–102).
8. **Postgres em Compose + `environment` + `secrets` de arquivo** — §7.4, p. 111–115.
   - Listagens 7.3/7.4 (p. 112–113): serviço `todo-db` publicando `5433:5432`, `secrets: source/target` lido de `file: ./config/secrets.json`.
   - TIN: `cd ./ch07/exercises/todo-list-postgres; docker compose up -d; docker compose ps` (p. 113); conectar com cliente SQL em `localhost:5433` (p. 114).
   - → SwarmLab: senha do Postgres via `secrets:` + `POSTGRES_PASSWORD_FILE=/run/secrets/...`; **não publicar 5432** no override de prod.
   - Armadilhas: no Compose de máquina única o secret é só um arquivo montado ("in reality, the file on the host gets surfaced into the container", p. 113) — não é cifrado; no Swarm, sim (Fase 3).
9. **Lab do cap. 7 (restart, bind para o banco, porta 80)** — §7.6, p. 117 — ver §3.
10. **Health checks no Compose e `restart`** — cap. 8, §8.4, p. 132–134.
    - Listagens 8.5/8.6: `healthcheck: interval/timeout/retries/start_period`, `test: ["CMD", ...]`, `restart: on-failure`.
    - TIN: `docker compose up -d` em `ch08/exercises/numbers` e ver nos logs o web falhar no dependency check, reiniciar e subir (p. 133–134).
    - → SwarmLab: `pg_isready` como healthcheck do Postgres; `/health` (liveness) na API; worker com check próprio (ex.: arquivo de heartbeat ou consulta leve).
    - Armadilhas: Compose também **não** substitui container unhealthy (p. 132); config agressiva de check é cara em produção (p. 132).
11. **Dependency check e fail-fast × ordem de inicialização** — §8.2, p. 124–127; §8.5, p. 135–136.
    - TIN: web sem API (p. 124); `numbers-web:2e-v2` que sai porque o `curl` falha (p. 126); v3 com utilitário (p. 131).
    - → SwarmLab: a API e o worker devem **falhar rápido** se o banco não estiver acessível na partida (e o `restart` resolve), em vez de subir "verdes" e quebrados.
    - Armadilhas: "Compose can only manage dependencies on a single machine" (p. 134); em cluster a ordem não é garantida (p. 124, 135) — **exatamente o caso do Swarm, que ignora `depends_on`**; check de dependência fora do seu controle pode derrubar seu app sem motivo (p. 136).
12. **`depends_on` com `condition: service_healthy`** — cap. 13, listagem 13.5, p. 244–245 (único exemplo do livro).
    - TIN: rodar o Nerd Dinner (Windows; não reproduzível no Linux).
    - → SwarmLab: `api` e `worker` com `depends_on: postgres: condition: service_healthy` e `migrator: condition: service_completed_successfully` (esta última **não está no livro**; ver lacunas).
13. **Configuração em camadas e 12-factor** — cap. 18, §18.1–18.5, p. 360–380.
    - TIN: access-log com e sem override em `/app/config-override` (p. 361–362); `-e APP_METRICS_ENABLED=true` vencendo o arquivo (p. 363); .NET `DOTNET_ENVIRONMENT=Test` (p. 365); Go/Viper com prefixo `IG_` (p. 372); app legado com utilitário de carga de config no `CMD` (p. 373–376); `docker compose up -d` em `ch18/exercises` e checar as 3 APIs `/config` (p. 378).
    - → SwarmLab: pydantic-settings com defaults (nível release), arquivo de override montado (nível ambiente) e env vars com prefixo (`SWARMLAB_`) ganhando (nível feature); endpoint `/config` só com campos não sensíveis e desligável.
    - Armadilhas: não empacotar config de todos os ambientes na imagem — server names, URLs, níveis de log já são informação útil a atacante (p. 368); "assume that your registry could be compromised" (p. 365); API de config: seletiva, autenticada, desligável (p. 370); lógica de startup extra aumenta tempo e risco → health check (p. 375).
14. **Múltiplos ambientes no mesmo host: projeto, override, `config`** — cap. 10, §10.1–10.2, p. 163–173.
    - TIN: subir o mesmo Compose duas vezes (nada acontece) e depois com `-p todo-test` + `docker container port` (p. 164–165); `docker compose -f a.yml -f b.yml config` (p. 168); dev/test/uat com `-p numbers-dev/test/uat` (p. 170); as três variantes de `down` e só a com mesmos `-f` e `-p` funciona (p. 172).
    - → SwarmLab: `compose.yaml` (base) + `compose.dev.yaml` (bind de código, reload, portas abertas, Postgres publicado) + `compose.test.yaml` (banco descartável, sem portas) + `compose.prod.yaml` (limites, restart, sem portas além do Traefik); validar sempre com `docker compose config`.
    - Armadilhas: nome do projeto padrão = nome do diretório (p. 165); ordem dos `-f` importa, da direita sobrepõe a esquerda (p. 169); `down` sem os mesmos arquivos e projeto não acha os recursos ou tenta apagar rede compartilhada (p. 172); muitos arquivos duplicados = drift (p. 166).
15. **`environment` × `env_file` × `secrets` × `.env`** — §10.3, p. 173–178.
    - TIN: `-f docker-compose.yml -f docker-compose-dev.yml -p todo-dev up -d` + `curl` + `logs --tail 4` (p. 175); `docker compose up -d` usando só o `.env` (p. 177).
    - Listagem 10.5: `"${TODO_WEB_PORT}:8080"`; Listagem 10.6: `.env` com `COMPOSE_PATH_SEPARATOR`, `COMPOSE_FILE`, `COMPOSE_PROJECT_NAME`.
    - → SwarmLab: `.env` (fora do git) define o ambiente padrão de dev; `env_file` para variáveis não sensíveis compartilhadas por api/worker/migrator; senha só em `secrets`.
    - Armadilhas: `environment` é texto plano, não use para dado sensível (p. 178); variável não definida gera aviso no `config` (figura 10.11, p. 180); o livro diz que o Compose "only looks for a file called .env… You can't specify a filename" (p. 178) — **desatualizado**, existe `--env-file` (ver lacunas).
16. **Extension fields `x-` e YAML anchors/merge** — §10.4, p. 179–181.
    - Listagens 10.7/10.8 (`x-labels: &logging` com `max-size`/`max-file`; `<<: *logging`). TIN: `docker compose -f ... -f docker-compose-prod.yml config` (p. 180).
    - → SwarmLab: `x-app-common` com `env_file`, `logging`, `restart`, `networks` reaproveitado por api/worker/migrator (mesma imagem, comandos diferentes).
    - Armadilha: anchors **não atravessam arquivos** — não dá para definir no base e usar no override (p. 181).
17. **Logs: stdout/stderr, onde ficam, rotação** — cap. 19, §19.1, p. 382–387.
    - TIN: `docker run -it diamol/ch19-timecheck:2e` (p. 383); `docker logs --tail 1`, `docker stop`, `inspect --format='{{.LogPath}}'` (p. 384); `--log-opt max-size=5k --log-opt max-file=3` + `inspect --format='{{json .HostConfig.LogConfig}}'` (p. 386).
    - → SwarmLab: uvicorn e worker logando em stdout (JSON estruturado com id de correlação); `logging: driver: json-file, options: max-size/max-file` em todos os serviços via `x-`.
    - Armadilhas: por padrão o arquivo de log **cresce sem limite até encher o disco** (p. 386); o log some quando o container é removido (p. 384–385).
18. **App que loga em arquivo / processo em background** — §19.2, p. 387–391.
    - TIN: `timecheck:2e-v2` sem logs + `exec ... cat /logs/timecheck.log` (p. 387–388); v3 com relay (p. 390).
    - → SwarmLab: garantir que nenhum componente escreva log só em arquivo; o worker deve ser o processo principal (foreground), não um daemon.
    - Armadilhas: com relay, se o relay morre o container sai mesmo com o app vivo, e vice-versa (p. 388–389); disco em dobro e latência (p. 390).
19. **Drivers de log e coleta central** — §19.3–19.5, p. 391–404.
    - TIN: Fluentd + `--log-driver=fluentd` (p. 391–392); stack EFK em Compose (p. 394); `logging: driver/options: tag` no Compose (listagem 19.3, p. 398); filtros por tag e override de config (p. 399–402).
    - → SwarmLab: opcional; o valor está em entender `logging:` por serviço e o padrão "coletor por nó" que vira serviço `mode: global` no Swarm.
    - Armadilhas: logs perdidos durante redeploy do coletor, sem buffer (p. 402); não escrever direto do app no armazenamento final (p. 404).
20. **Reverse proxy como única porta publicada** — cap. 20, §20.1, p. 405–410; §20.5, p. 429–431.
    - TIN (nginx, só para entender): `docker network create ch20` + compose do nginx (p. 406), who-am-I por hostname (p. 408).
    - → SwarmLab: só o Traefik publica 80/443; api sem `ports:` em prod; Postgres sem porta.
21. **Traefik por labels** — §20.4, p. 421–429.
    - TIN: subir Traefik e abrir dashboard em `:8080` (p. 421); who-am-I com `traefik.enable=true`, `traefik.http.routers.whoami.rule=Host(\`whoami.local\`)`, `traefik.http.services.whoami.loadBalancer.server.port=8080` (listagem 20.4, p. 424–425); image-gallery com path prefix + middleware de strip (p. 425); HTTPS com cert autoassinado e redirect HTTP→HTTPS (p. 426); sticky sessions com `--scale whoami=3` e cookies (p. 428).
    - → SwarmLab: `api.swarmlab.local` → api; `/docs` só em dev; redirect para HTTPS; `exposedByDefault=false`; dashboard protegido ou desligado em prod.
    - Armadilhas: Traefik precisa de acesso à API do Docker (montagem do socket, p. 421); **o livro não discute aqui o risco disso** (só no cap. 11, p. 193); sticky session pode apontar para container que já não existe (p. 428); o livro diz que o Traefik "doesn't have a cache (as of version 2)" (p. 425) — a versão do livro é a v2.
22. **Rede de dados separada** — o livro isola **ambientes** por rede (§10.2, p. 170–171), mas não ensina segmentar **camadas** do mesmo app. → SwarmLab: rede `edge` (traefik↔api) e rede `data` (api/worker/migrator↔postgres) com `internal: true` — ver lacunas.
23. **Build pelo Compose e variáveis em tags** — cap. 11, §11.3, p. 194–199.
    - Listagens 11.2/11.4: `image: ${REGISTRY:-docker.io}/...:2e-${BUILD_NUMBER:-local}`; `build: context/dockerfile/args` + `x-args`.
    - → SwarmLab: `compose.build.yaml` que constrói a imagem única (api/worker/migrator) e a etiqueta com `${REGISTRY:-localhost:5000}/swarmlab/app:${GIT_SHA:-local}`.
24. **Docker socket dentro de container** — §11.2, p. 193–194.
    - Listagem 11.1: bind de `/var/run/docker.sock`.
    - → SwarmLab: aplica ao Traefik; usar socket read-only ou um docker-socket-proxy (não citado no livro).
    - Armadilha que o livro aponta: "There's also a security concern here because the app in the container has full access" ao Engine (p. 193).
25. **Smoke test end-to-end com Compose** — cap. 16, §16.3, p. 322–325.
    - TIN: `./smoke-test.ps1 -Local` (p. 323) — sobe o app com Compose, faz requisições, derruba.
    - → SwarmLab: `make smoke` = `compose -p swarmlab-test up -d --wait` → migrator termina com 0 → POST de job → worker processa → GET confirma → `down`. Passo de gate que precisa conseguir reprovar.
26. **Padrões de mensageria assíncrona e escala de handlers** — cap. 21, p. 433–451.
    - TIN: Redis pub/sub (p. 435–437); NATS + to-do publicando eventos (p. 438–441); `docker compose up -d --scale save-handler=3` (p. 444); novo handler via override sem tocar no resto (p. 445–447).
    - → SwarmLab: os **conceitos** (worker escalável por `--scale worker=3`, adicionar consumidor novo sem mexer no produtor, request-response × fire-and-forget) com a fila em Postgres (`FOR UPDATE SKIP LOCKED`); demonstrar que 3 workers não processam o mesmo job.
    - Armadilhas que o livro aponta: Redis/NATS "effectively swallow" mensagens sem assinante (p. 440–441) — com Postgres a fila é **persistente e transacional**, então esse problema não existe, mas surgem outros (job travado, retentativa, idempotência) que o livro não cobre.
27. **Observabilidade (níveis)** — cap. 9, §9.5, p. 160–162 (conceitos). Os TIN de Prometheus/Grafana (p. 140–159) **ficam fora** pela regra da casa; ver divergências.

### Fase 3 — Swarm multinó (o que o livro oferece de fato)

O livro **não ensina Swarm**. O que dele serve, em ordem:

1. **Por que um orquestrador** — cap. 1 p. 11 ("Docker doesn't connect multiple physical machines together"); cap. 7 §7.5 p. 115–117 (Compose não mantém estado desejado: "If containers fail… Docker Compose won't restart or replace them"); cap. 15 p. 281 (o que um orquestrador faz: agenda containers em máquinas, rede, storage, substitui container se a máquina cai).
   - → SwarmLab: abrir a Fase 3 repetindo o lab do cap. 8 no Swarm e ver o serviço **substituir** tarefa unhealthy — o que o Engine sozinho não faz (p. 123–124).
2. **Estado desejado, réplicas, rollout escalonado** — cap. 15 §15.3, p. 292–298 (Kubernetes).
   - TIN: escalar Deployment para 3 (p. 294); aplicar spec com probes e ver rollout "one new pod… when it enters the Ready state, one of the old Pods is terminated" (p. 297–298).
   - → SwarmLab: equivalente em `docker service update --image ... --update-parallelism 1 --update-delay 10s --update-failure-action rollback --update-order start-first`; o conceito "se os novos não sobem, os velhos não são trocados" é o mesmo (precisa de healthcheck).
3. **Config imutável no container → mudança de config = nova tarefa** — cap. 15, p. 301; cap. 18, p. 363 ("changing environment variables… means replacing containers").
   - → SwarmLab: `docker config`/`docker secret` são imutáveis; rotacionar = criar `db_password_v2` e `service update --secret-rm/--secret-add`.
4. **ConfigMaps/Secrets ≈ configs/secrets de cluster** — cap. 15 §15.4, p. 298–305; cap. 7 p. 113 ("Secrets are usually provided by the container platform in a clustered environment… stored in the cluster database and can be encrypted"); cap. 18 p. 378.
   - → SwarmLab: o mesmo `secrets:` do Compose vira secret de verdade (cifrado no Raft) em `docker stack deploy`.
5. **Health e dependency checks em cluster** — cap. 8 §8.5, p. 135–136 (figura 8.11: ciclo de vida em cluster com reinício/substituição).
   - → SwarmLab: no Swarm `depends_on` é ignorado → o fail-fast da Fase 2 vira obrigatório.
6. **Registry acessível por todos os nós** — cap. 5 §5.3, p. 67–71.
   - → SwarmLab: registry como serviço no cluster (ou numa VM), com TLS; `docker stack deploy --with-registry-auth` se houver auth.
7. **Engine remoto, contexts e proteção da API** — cap. 2 p. 28–29; cap. 12 §12.4 p. 222–223 (`docker context show`, `docker context create --from ...`, `docker context ls`; "With multiple machines, you need to set up Docker to listen on the network, and secure it with SSH or TLS").
   - → SwarmLab: um context `ssh://` por manager; nunca expor 2375 sem TLS.
8. **Storage local × distribuído** — cap. 6 §6.4–6.5, p. 93–96.
   - → SwarmLab: volume local fica preso ao nó; se o nó do Postgres cai, o Swarm reagenda a tarefa em outro nó **sem os dados** → placement constraint fixando o Postgres num nó (label) + backup; storage de rede tem limitações de FS e desempenho (p. 94).
9. **Logs por nó** — cap. 19 p. 403–404 (Fluentd em cada nó coletando os containers locais).
   - → SwarmLab: `docker service logs` agrega; coletor seria `mode: global`.
10. **Reverse proxy na frente do cluster** — cap. 20 p. 429–430 ("publishing ports 80 and 443 from the container to the server (or all the servers in a cluster)").
    - → SwarmLab: Traefik v3 com provider Swarm, publicado em 80/443 via ingress routing mesh (ou `mode: host`), rodando em managers.
11. **Golden images, varredura e assinatura na cadeia de suprimento** — cap. 22 p. 454; cap. 17.

---

## 3. Labs de fim de capítulo e como viram tarefa no SwarmLab

| Lab | O que o livro pede | Tarefa SwarmLab derivada | Fase |
|---|---|---|---|
| 2.6 (p. 30) | Trocar o `index.html` do container web sem rebuild (pistas: `docker container --help`, caminho `htdocs`) | Usar `docker container cp` para trocar um arquivo estático da API num container rodando, provar que some ao recriar → motivação para imagem imutável | 1 |
| 3.6 (p. 44) | Produzir imagem **sem Dockerfile** (alterar arquivo e gerar imagem; pistas: `-it`, container parado mantém FS, dois subcomandos de `docker container`) | Fazer uma vez (é `commit`) e escrever no diário por que isso **não** é aceitável no SwarmLab (sem reprodutibilidade) | 1 |
| 4.6 (p. 60) | Otimizar Dockerfile Go: < 25 MB, mudança de HTML não recompila | Meta equivalente para a API: mudança só em `.py` não reexecuta `uv sync`; medir imagem final | 1 |
| 5.6 (p. 75–76) | Empurrar todas as tags para o registry local, listar, obter manifest e **apagar via API v2** (header específico no HEAD) | Mesmo lab no registry do SwarmLab + política de limpeza de tags antigas (e entender que apagar manifest exige garbage collection do registry) | 1→3 |
| 6.6 (p. 96) | Rodar `diamol/ch06-lab:2e` começando vazio e gravando em volume (o arquivo de config controla mais que log) | Subir o Postgres com volume nomeado e, numa segunda rodada, com bind mount em diretório do host com dono correto; destruir e recriar o container e provar persistência | 2 |
| 7.6 (p. 117) | Compose de teste: restart após reboot/restart do engine, banco em **bind mount**, web na porta 80 | `compose.test.yaml` com `restart: unless-stopped`, Postgres em bind mount, Traefik em 80; reiniciar o daemon (`sudo systemctl restart docker`) e verificar volta automática | 2 |
| 8.6 (p. 136–137) | App Node "memory hog": check de memória no startup (sai se insuficiente) e health a cada 5 s | Worker com check de partida (banco acessível e migração aplicada; senão sai ≠ 0) e healthcheck periódico; somar `mem_limit`/`deploy.resources` e observar OOM (`docker inspect` → `OOMKilled`) — a parte de limite **não está no livro** | 2 |
| 9.6 (p. 162) | Compose com app + Prometheus + Grafana com 3 métricas | **Não fazer como está** (regra da casa). Alternativa: endpoint `/health` e `/ready` + logs estruturados + alarme de ausência de heartbeat do worker | 2 |
| 10.6 (p. 182–183) | Dev padrão (`docker compose up`, banco em arquivo, porta 8089, v2) + test (projeto nomeado, banco em container com **volume via `PGDATA`**, porta 8080, imagem latest), ambos na mesma máquina | Exatamente o requisito de ambientes do SwarmLab: dev e test simultâneos na mesma máquina, com `-p`, redes e portas distintas | 2 |
| 11.6 (p. 204) | Override `docker-compose-build.yml`, job Jenkins, push no Gogs | Substituir Jenkins/Gogs por um script/Makefile local (ou GitHub Actions do cap. 16) que faz build, test, scan, tag e push para o registry do lab | 1/2 |
| 12.6 (p. 227) | Dockerfile multiplataforma | Opcional: imagem `linux/amd64`+`linux/arm64` com buildx se alguma VM for Arm | 1 |
| 13.6 (p. 248), 14.6 (p. 279), 15.6 (p. 306) | Windows / nuvem gerenciada / Kubernetes | Fora de escopo | — |
| 16.6 (p. 331–332) | Script que cria e envia manifest lists ao GHCR | Opcional (casa com 12.6) | — |
| 17.6 (p. 358–359) | Imagem com Docker CLI < 50 MB e rebuild < 1 s | Meta de tamanho e tempo de rebuild para a imagem da API medida em CI | 1 |
| 18.6 (p. 380–381) | Volumes para overrides de config, ambiente de teste, release 25.03 | Override de config do SwarmLab por arquivo montado + env var de release; verificar via `/config` | 2 |
| 19.6 (p. 404) | Fluentd para o app numbers: tag com app/serviço/imagem, split do tag, match de fallback | Opcional; versão mínima: `logging:` com `tag` e rotação em todos os serviços via `x-logging` | 2 |
| 20.6 (p. 431–432) | App de pi em `pi.local` atrás de proxy com **cache** e resiliência | Com Traefik não há cache nativo (o livro mesmo diz); adaptar para: `api.swarmlab.local` via Traefik, HTTPS, middleware de rate-limit/headers, e medir o comportamento quando a api cai (503 do proxy) | 2 |
| 21.6 (p. 450–451) | Adicionar handler `ch21-mutating-handler` e achar a config que publica `events.todo.itemsaved` | Adicionar um **segundo tipo de job** consumido por um worker separado sem alterar a API; e um teste com 3 workers provando que nenhum job é processado duas vezes | 2 |

---

## 4. Lacunas e trechos desatualizados (corrigir com a documentação atual)

### 4.1 Fase 3 inteira — não coberta
O livro não tem nada de: `docker swarm init/join` e tokens de join, `docker swarm join-token --rotate`, managers × workers, **quórum Raft** (3 managers toleram 1 falha), `docker node ls/update --availability drain/active`, `docker node promote/demote`, labels de nó e `deploy.placement.constraints`/`preferences`, `docker service create/scale/update/rollback/ps/logs`, `deploy.replicas`, `mode: global`, `update_config`/`rollback_config` (parallelism, delay, order, failure_action, monitor), `docker stack deploy/ps/services/rm`, **overlay networks** (incl. `--attachable`, `--opt encrypted`), **ingress routing mesh** × `mode: host`, VIP × `endpoint_mode: dnsrr`, `docker secret/config` de cluster, autolock (`docker swarm init --autolock`, `docker swarm unlock-key --rotate`), CA do Swarm e mTLS entre nós (`docker swarm ca --rotate`), portas a liberar (2377/tcp, 7946/tcp+udp, 4789/udp), backup do estado do Swarm (`/var/lib/docker/swarm`) e recuperação de quórum (`--force-new-cluster`), Traefik com provider Swarm. **Fonte**: docs.docker.com/engine/swarm/ (tutorial, "How nodes work", "Raft consensus in swarm mode", "Administer and maintain a swarm", "Manage sensitive data with Docker secrets", "Store configuration data using Docker Configs", "Use overlay networks", "Use swarm mode routing mesh") e a referência da seção `deploy` da Compose Specification.

### 4.2 Compose — o que falta ou está defasado
1. **Resíduos de `docker-compose` com hífen** (p. 101, 113, 145, 421): usar `docker compose`. A chave `version:` não aparece no livro (ok), mas o aluno vai achar na internet — ela é **obsoleta** na Compose Specification e gera aviso.
2. **Nome de arquivo**: o livro usa `docker-compose.yml` (p. 101); o nome canônico atual é `compose.yaml` (o legado ainda é aceito).
3. **`.env` "só pode ter esse nome"** (p. 178): falso hoje — existe `docker compose --env-file`, e também `env_file:` com `required: false`/formato.
4. **Ausentes**: `depends_on` com `condition: service_completed_successfully` (essencial para o **migrator**) e `restart: true`; `docker compose up --wait`; `docker compose run --rm`; `profiles` (ex.: migrator ou ferramentas só em perfil); `include:`; `docker compose watch`/`develop.watch` (hot reload moderno); `networks: internal: true`; `healthcheck.start_interval`; `init: true`; `stop_grace_period`/`stop_signal`; `read_only`, `tmpfs`, `cap_drop`, `security_opt: no-new-privileges`; `pids_limit`.
5. **Limites de recursos**: o livro **não ensina** `--memory`/`--cpus` no Docker nem `deploy.resources.limits/reservations` no Compose (só aparecem flags da CLI do Azure, p. 250–261). Ler docs de "Resource constraints" (cgroups v2, OOM killer, `OOMKilled`) e a seção `deploy.resources` da Compose Specification (que o Compose v2 aplica em modo não-Swarm).
6. **`down -v`**: o livro diz que `down` removeria volumes declarados no arquivo (p. 107); na prática atual `down` **não** remove volumes nomeados sem `-v`. Conferir na referência de `docker compose down` e tratar `-v` como operação destrutiva.
7. **Sinais e PID 1**: nada sobre SIGTERM, período de graça de 10 s, forma exec × shell no `CMD` (o livro usa forma shell com `&&` em dependency checks — p. 126, 130 — o que coloca `/bin/sh` como PID 1 e pode engolir o SIGTERM), `exec` no entrypoint, `tini`/`--init`. Crítico para o worker terminar o job corrente antes de sair e para o rolling update da Fase 3.
8. **Healthcheck × readiness**: o livro tem um único conceito de health; separar liveness (`/health`) de readiness (`/ready` verificando banco) vem de outras fontes.

### 4.3 Imagem, build e segurança
1. **BuildKit avançado** ausente: `RUN --mount=type=cache` (cache do uv), `--mount=type=secret`, heredocs, `# syntax=docker/dockerfile:1`, `COPY --link`, `--chmod`. Ver docs "Build cache"/"Optimize cache usage" e o guia oficial do uv para Docker.
2. **Scan**: o livro usa Trivy (válido); hoje também existe `docker scout` e geração de **SBOM/provenance** no `buildx` (`--sbom`, `--provenance`) — o livro só cita SBOM de passagem (p. 347).
3. **Registry com TLS e auth**: o livro configura **insecure registry** (p. 69–71); para a Fase 3 seguir "Deploy a registry server" (TLS, htpasswd) e a doc do Swarm sobre `--with-registry-auth`.
4. **`docker system prune` "regularly"** (p. 336): cuidado — sem `--volumes` não apaga volumes, mas a casa proíbe prune com volumes (incidente de 2026-06-16); preferir `docker image prune`/`builder prune` com filtros.
5. **Rootless Docker / user namespaces / seccomp/AppArmor**: não cobertos.
6. **Socket do Docker em containers** (p. 193, 421): falta a mitigação moderna (socket proxy com allowlist, montagem `:ro`, Traefik só em managers).

### 4.4 Postgres em container
O livro roda Postgres (p. 111–114, p. 183 `PGDATA`) mas **não cobre**: backup/restore (`pg_dump`/`pg_restore`, `pg_dumpall`, `docker exec` com stdin), restore testado, upgrade de versão major (dados não são compatíveis entre majors), `POSTGRES_PASSWORD_FILE`, `/docker-entrypoint-initdb.d` (só roda com diretório vazio), `shm_size`, permissões do bind mount. Fonte: página da imagem oficial `postgres` no Docker Hub + docs do PostgreSQL (backup/upgrade).

### 4.5 Traefik
O livro usa **Traefik v2** (p. 425: "as of version 2"). A casa usa **v3** — revisar: sintaxe de regras de roteador (v3 mudou parte da sintaxe de matchers e regex), provider Docker × provider Swarm (no v3 são providers separados: `providers.swarm`), labels em `deploy.labels` no Swarm (não em `labels` do container), `exposedByDefault=false`, ACME/Let's Encrypt e dashboard seguro. Fonte: doc.traefik.io (migração v2→v3 e "Docker Swarm provider").

### 4.6 Ferramentas datadas ou trocadas
Jenkins + Gogs (cap. 11) e scripts PowerShell (cap. 16) são escolhas didáticas; `diamol/*` são imagens do autor, não oficiais — no SwarmLab use sempre imagens oficiais fixadas por versão (e, idealmente, por digest).

---

## 5. Divergências com as decisões do projeto

| Decisão SwarmLab | O que o livro faz | Como conciliar |
|---|---|---|
| **uv** para dependências Python | Nunca menciona Python na prática nem uv; padrão do livro é "estágio SDK compila, estágio runtime copia" (cap. 4, 17) | O padrão vale: estágio builder com uv (imagem oficial do uv ou `COPY --from=ghcr.io/astral-sh/uv`), `uv sync --frozen --no-dev` primeiro só com `pyproject.toml`+`uv.lock` (cache, §17.4) e copiar o `.venv` para o runtime; o uv **não** vai para o runtime (§17.2, p. 343–344). Detalhes vêm do guia oficial do uv para Docker, não do livro. |
| **Traefik (v3)** como proxy; **nunca nginx** | Cap. 20 ensina nginx primeiro (§20.1–20.3: rotas, SSL com cert gerado, **cache**) e Traefik v2 depois (§20.4) | Ler §20.1–20.3 só como conceito de reverse proxy; praticar só §20.4, convertendo para v3. O lab 20.6 depende de cache (nginx) — adaptar como descrito em §3. |
| **Postgres como fila** (`FOR UPDATE SKIP LOCKED`); **sem Redis** | Cap. 21 usa Redis pub/sub e NATS; fala de RabbitMQ/Kafka (p. 449–450) | Aproveitar os padrões (pub-sub, request-response, fire-and-forget, escalar consumidores, novo consumidor sem mudar produtor). Implementação: tabela de jobs, `SELECT ... FOR UPDATE SKIP LOCKED LIMIT n`, idempotência, retentativa com backoff, job "preso" com lease/timeout, `LISTEN/NOTIFY` opcional. Nada disso está no livro. |
| **Linux nativo** (Engine em Linux, VMs Linux) | Livro centrado em Docker Desktop (Mac/Windows), PowerShell com crase, variantes Windows em quase todo exercício (caps. 6, 7, 10, 13, 19) | Ignorar trechos Windows; trocar crase por `\`; vantagem: no Linux o arquivo de log JSON e os volumes estão acessíveis no host (p. 384), e o `daemon.json` está em `/etc/docker` (p. 69). Docker roda sem sudo nesta máquina (convenção da casa); o `sudo` só nas VMs. |
| **Observabilidade sem Prometheus/Grafana** | Cap. 9 inteiro é Prometheus + Grafana (e cap. 18/19 citam métricas Prometheus) | Pular os TIN do cap. 9; ficar com §9.5 (níveis de observabilidade) e cap. 19 (logs). Usar healthcheck + logs estruturados + alarme por ausência de sinal. |
| **Segredos**: senha de banco no cofre do Swarm (`docker secret`); demais em `.env` fora do git, `chmod 600` | Compose `secrets` de arquivo (cap. 7, 10, 18) — está alinhado; mas `.env` do livro guarda portas e config de Compose (p. 178), e há senhas em texto em exemplos (`postgres/postgres`, p. 114) | Manter o padrão `secrets:` desde a Fase 2 para a migração à Fase 3 ser só trocar a origem; nunca senha em `environment`. |
| **Banco: bind-mount, rede `internal: true`, backup 2x/dia com cópia externa e restore testado** | Livro usa volume nomeado como padrão e bind mount como alternativa (cap. 6, lab 7.6); não fala de rede interna nem backup | Fase 2: bind mount para o Postgres + rede `data` com `internal: true` + rotina de `pg_dump` e restore testado (fonte externa ao livro). Fase 3: placement constraint no nó do banco. |
| **Imagem única para api/worker/migrator** | Livro tem uma imagem por componente (cap. 4, 7) | Livre escolha do projeto; o livro só reforça "build once, promote the same image" (§10.5, p. 182; §18.5, p. 379). |
| **Kubernetes fora de escopo** | Cap. 15 e §16.4 são Kubernetes; o livro declara que não há mais escolha além de K8s (p. 281) | Ler cap. 15 só como ponte conceitual (§2, Fase 3); a decisão de usar Swarm é do projeto e o livro não a apoia nem a ensina. |
