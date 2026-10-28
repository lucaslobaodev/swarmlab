# Plano de estudos do SwarmLab: Fases 1, 2 e 3

> **SUBSTITUÍDO em 2026-10-28.** Plano vigente: `temas/docker/PLANO-FINAL.md` no repo `lucaslobaodev/acompanhamento-de-estudos`. Este arquivo fica só como histórico; a tradução da numeração está na Parte A3 do plano novo.

> Plano consolidado a partir de quatro inventários (livro, documentação oficial, comunidade) e de uma verificação de URLs e fatos feita em 2026-10-28. Quando um inventário e a verificação discordam, **vale a verificação**.
> O modo tutor (CLAUDE.md do projeto) segue este plano: **um passo por vez**, o Lucas escreve o código e roda os comandos, o Claude dá a ideia, a pista e a pergunta de checagem.

---

## 0. Como ler este plano

### 0.1 Estrutura
- **Fase → Módulo → Passo.** ID no formato `F2.M3.P4` (Fase 2, Módulo 3, Passo 4).
- Cada passo tem **uma ideia e uma tarefa**. Não junte passos. O próximo só começa depois que o critério de pronto do atual foi visto na saída do terminal.
- Campos de cada passo:
  - **Ideia:** o mínimo de teoria para conseguir fazer (1-2 linhas).
  - **Tarefa:** o que o Lucas escreve ou roda no SwarmLab.
  - **Pronto quando:** o que aparece na saída e prova que o passo terminou.
  - **Checagem:** pergunta verificável. O Lucas responde com as palavras dele ou com um comando que prova.
  - **Pista:** onde procurar, sem a resposta.
  - **Fontes:** livro (capítulo, página impressa), doc (URL), comunidade (URL).
  - **Armadilha:** erro conhecido, com link quando existir.
- **Experimentos** (`F2.E3`) têm sempre: **hipótese** (escrita pelo Lucas antes) → **como provocar** → **o que observar** → **registrar** em `docs/experiments/<ID>-<nome>.md` (hipótese, comandos, saída real, resultado, lição). Números só entram se vieram de execução real.

### 0.2 Legenda das fontes

"Inventário livro/docs/comunidade" e "verificação" referem-se aos arquivos em `docs/fontes/`.
| Marca | Significado |
|---|---|
| **Livro p. N** | *Learn Docker in a Month of Lunches*, 2ª ed. (Elton Stoneman, Manning, ©2025, ISBN 9781633438460). **Página impressa**; no PDF some 26 (p. 99 do livro = p. 125 do PDF). Comandos do livro estão em PowerShell: troque a crase de fim de linha por `\`. As imagens `diamol/*` são do autor. |
| **[abre]** | A URL respondeu HTTP 200 na verificação. O conteúdo **não** foi lido, só o resumo do inventário. Abra e confira antes de seguir a receita. |
| **[conferido]** | O conteúdo da página foi lido na verificação e sustenta o que o plano diz. |
| **[URL corrigida]** | A URL do inventário redirecionava ou estava quebrada; aqui está a URL final. |
| **(a confirmar na prática)** | Afirmação que a verificação **não** confirmou. Ou vira experimento, ou fica como hipótese. Nunca trate como fato. |

### 0.3 Regras de segurança que valem em todos os passos
1. **Nunca** `docker system prune --volumes` nem `docker volume prune`. Causaram perda real de dados. Para liberar espaço: `docker image prune`, `docker builder prune`, `docker container prune`, sempre olhando o que vai sair antes.
2. `docker compose down -v` só no projeto de **teste** (`-p swarmlab_test`), nunca no de dev com dados que você quer manter.
3. Experimento destrutivo (derrubar nó, encher disco, perder quorum, cortar rede) **só** nas VMs do laboratório.
4. Segredo nunca entra no git: `secrets/*.txt` e `.env` ficam no `.gitignore`, com `chmod 600`. Na Fase 3, a senha do banco vai para `docker secret`.
5. Restore por cima de um banco com dado que importa é ação irreversível: pare e confirme antes.

### 0.4 Decisões do projeto que este plano assume
- Python com **uv**; uma imagem só para `api`, `worker` e `migrator`, com comandos diferentes.
- **Traefik v3**: provider `docker` na Fase 2 e provider `swarm` na Fase 3. Nunca nginx.
- **Fila no Postgres** com `SELECT ... FOR UPDATE SKIP LOCKED`. Sem Redis.
- **Prometheus e Grafana ficam na Fase 4.** Aqui entram só ganchos: logs estruturados, `/health` e `/ready`, heartbeat do worker, e a nota de que o daemon expõe métricas por `metrics-addr`.
- Fora de escopo: Kubernetes, nginx, Redis.

---

## 1. Visão geral

| Fase | Objetivo | Critério de "fase concluída" (verificável) | Pré-requisitos | Esforço estimado |
|---|---|---|---|---|
| **1. Containerização** (complementos) | A imagem da API está pronta para rodar em cluster: para rápido e limpo, loga em stdout com rotação, tem limites, está num registry por digest, passou em lint e scan. Redes e volumes entendidos no Docker puro antes do Compose. | (1) `time docker stop` < 2 s e `Exited (0)`; (2) `docker inspect` mostra `OOMKilled: true` num teste provocado; (3) dois containers numa bridge sua se acham por nome e na bridge padrão não; (4) Postgres 18 sobrevive a `rm -f` + recriação com volume em `/var/lib/postgresql`; (5) imagem no registry local, puxada por `@sha256:`; (6) `hadolint` sem erro e `trivy image` com `--exit-code 1` usado como gate que já reprovou uma vez. | O que já está no PROGRESS.md. | 8 a 10 sessões |
| **2. Compose** | O SwarmLab inteiro (api, postgres, migrator, worker, traefik) sobe com um comando, com redes separadas, healthchecks, secrets, ambientes dev e teste, e backup/restore testado. | (1) `docker compose -p swarmlab_test up -d --wait` termina com todos `healthy` e o migrator `Exited (0)`; (2) `curl` em `api.localhost` via Traefik responde; o Postgres não tem porta publicada; (3) 3 workers processam N jobs sem duplicata (consulta prova); (4) restore de `pg_dump` num projeto novo devolve a mesma contagem; (5) `make destroy && make up` recria tudo do zero sem passo manual. | Fase 1 concluída. | 14 a 18 sessões |
| **3. Swarm multinó** | O mesmo app roda num Swarm de 5 nós (3 managers, 2 workers), com update/rollback automático, secrets do cluster, Traefik v3 com provider swarm, e falhas provocadas e registradas. | (1) `docker node ls` com 3 managers (1 `Leader`, 2 `Reachable`) e 2 workers; (2) `docker stack deploy` do SwarmLab a partir de imagem no registry; (3) update com `/health` quebrado volta sozinho (rollback); (4) quorum perdido e recuperado com `--force-new-cluster`, registrado; (5) nó do Postgres derrubado, RPO medido contra o backup; (6) pelo menos 12 experimentos de falha em `docs/experiments/`. | Fase 2 concluída; decisão do ambiente das VMs (F3.M0). | 18 a 24 sessões |

**Sessão** = um bloco de estudo de 1 a 2 horas. A estimativa é chute inicial; ajuste no PROGRESS.md depois das primeiras sessões.

**Contagem:** Fase 1: 9 módulos, 48 passos, 10 experimentos. Fase 2: 12 módulos, 58 passos, 14 experimentos. Fase 3: 15 módulos (F3.M0 é decisão), 57 passos, 20 experimentos.

---

## FASE 1 — Containerização (o que falta)

O Lucas já fez: Dockerfile multi-stage com uv, base fixada, cache de camadas, `.dockerignore`, usuário `app`, `HEALTHCHECK` em Python, e o experimento do `unhealthy`. **Não repetir.** O que falta, e ele apontou que não viu: logs, sinais/PID 1, limites, redes, volumes, registry/digest, BuildKit avançado, scan e lint.

Ordem: revisão → logs → sinais → limites → **redes → volumes** (ponte para o Compose) → BuildKit → registry → qualidade.

### F1.M0 — Revisão rápida (1 sessão curta)

**F1.M0.P1 — Ler o próprio Dockerfile em voz alta**
- Ideia: antes de acrescentar coisa, confirmar o que cada linha faz.
- Tarefa: explicar, linha por linha, o `Dockerfile` atual (por que `COPY uv.lock pyproject.toml .` vem antes de `COPY app`, por que `USER app` vem antes de `COPY`).
- Pronto quando: as 18 linhas foram explicadas sem consulta.
- Checagem: se você mudar só `app/main.py`, quais passos aparecem como `CACHED` no build?
- Pista: rode `docker build --progress=plain .` e procure `CACHED`.
- Fontes: livro cap. 3 (p. 31-44) e §17.4 (p. 352-357).

**F1.M0.P2 — O builder que roda seu build**
- Ideia: `docker build` hoje é `docker buildx build`; o build roda num *builder* (BuildKit).
- Tarefa: `docker buildx ls` e `docker buildx inspect`; anotar o driver do builder padrão.
- Pronto quando: o nome do builder e o driver (`docker` ou `docker-container`) estão anotados.
- Checagem: por que um livro antigo manda `DOCKER_BUILDKIT=1` e você não precisa?
- Pista: a página de BuildKit diz desde qual versão do Engine ele é o padrão.
- Fontes: https://docs.docker.com/build/buildkit/ [abre] · https://docs.docker.com/build/builders/ [abre] · https://docs.docker.com/build/concepts/overview/ [abre]
- Armadilha: o driver `docker` não suporta todos os exportadores de cache (ex.: `cache-to type=registry`).

**F1.M0.P3 — Qual image store a máquina usa**
- Ideia: o Engine 29 usa o containerd image store como padrão **em instalação nova**; quem atualizou continua no antigo. Isso muda `docker images` e o suporte a multi-plataforma.
- Tarefa: `docker version` e `docker info --format '{{.DriverStatus}}'`; anotar a versão do Engine e o store.
- Pronto quando: os dois valores estão no PROGRESS.md.
- Checagem: se sua máquina foi atualizada de uma versão anterior à 29, qual store ela usa?
- Fontes: https://docs.docker.com/engine/storage/containerd/ [conferido: padrão 29.0+ em instalação nova] · release notes: https://docs.docker.com/engine/release-notes/29/ [URL corrigida]

### F1.M1 — Logs (pendência da Fase 1)

**F1.M1.P1 — De onde vem o `docker logs`**
- Ideia: o Docker guarda o que o PID 1 escreve em stdout e stderr. O driver padrão é `json-file`, um arquivo no host.
- Tarefa: subir a API, fazer 3 requisições, rodar `docker logs --timestamps <c>` e achar o arquivo com `docker inspect --format '{{.LogPath}}' <c>`; abrir o arquivo com `sudo tail`.
- Pronto quando: a mesma linha aparece no `docker logs` e no arquivo JSON.
- Checagem: o que acontece com esse arquivo quando você roda `docker rm` no container?
- Pista: livro p. 384-385.
- Fontes: livro cap. 19, §19.1 (p. 382-387) · https://docs.docker.com/engine/logging/ [abre] · https://docs.docker.com/engine/logging/drivers/json-file/ [abre]

**F1.M1.P2 — Python segura a saída**
- Ideia: Python com stdout que não é terminal guarda a saída em buffer; o log atrasa ou some numa queda.
- Tarefa: adicionar um `print` no `/health`, rodar sem `-t` e ver se a linha aparece na hora; depois definir `PYTHONUNBUFFERED=1` no Dockerfile e comparar.
- Pronto quando: a linha aparece no `docker logs -f` no mesmo segundo da requisição.
- Checagem: por que o log do uvicorn aparece mesmo sem a variável, e o seu `print` não?
- Pista: o uvicorn usa o módulo `logging`; `print` usa `sys.stdout`.
- Fontes: inventário docs §1.18 (armadilha de `PYTHONUNBUFFERED`).

**F1.M1.P3 — Log estruturado (gancho da Fase 4)**
- Ideia: uma linha JSON por evento, com nível e um id de requisição, é o que a observabilidade da Fase 4 vai consumir.
- Tarefa: configurar `logging` do Python para emitir JSON em stdout, com `request_id` gerado por middleware do FastAPI.
- Pronto quando: `docker logs <c> | head -1 | python -m json.tool` funciona.
- Checagem: onde o worker da Fase 2 vai logar, em arquivo ou em stdout? Por quê?
- Pista: livro §19.2 (p. 387-391) mostra o que dá errado com log em arquivo.
- Fontes: livro §19.2 (p. 387-391).
- Armadilha: log só em arquivo dentro do container some do `docker logs` (livro p. 387-388).

**F1.M1.P4 — Rotação**
- Ideia: sem `max-size`, o `json-file` cresce até encher o disco.
- Tarefa: rodar a API com `--log-opt max-size=1m --log-opt max-file=3` e conferir com `docker inspect --format '{{json .HostConfig.LogConfig}}'`.
- Pronto quando: o `LogConfig` mostra as duas opções.
- Checagem: se você puser a rotação no `daemon.json`, os containers que já existem passam a rotacionar?
- Pista: a página de configuração de logging fala de containers novos.
- Fontes: livro p. 386 · https://docs.docker.com/engine/logging/configure/ [abre] · driver `local`: https://docs.docker.com/engine/logging/drivers/local/ [abre]
- **Experimento F1.E1 — Log sem limite.** Hipótese: sem `max-size`, o arquivo cresce sem parar. Provocar: um container que loga em loop por 1 minuto, sem e com `max-size=1m`. Observar: `ls -lh` no LogPath e a quantidade de arquivos. Registrar em `docs/experiments/F1-E1-log-rotacao.md`.

### F1.M2 — Sinais, PID 1, STOPSIGNAL e init (pendência da Fase 1)

**F1.M2.P1 — Quem é o PID 1**
- Ideia: o processo do `CMD` é o PID 1 do container. `docker stop` manda SIGTERM a ele, espera 10 s e manda SIGKILL.
- Tarefa: `docker top <c>` e `docker exec <c> cat /proc/1/cmdline | tr '\0' ' '`.
- Pronto quando: você confirmou que o PID 1 é o uvicorn.
- Checagem: o que significa exit code 137? E 143?
- Pista: 128 + número do sinal (`kill -l`).
- Fontes: https://docs.docker.com/reference/cli/docker/container/stop/ [abre] · https://hynek.me/articles/docker-signals/ [abre]

**F1.M2.P2 — Medir o stop atual**
- Ideia: com `CMD` em forma exec, o uvicorn recebe o SIGTERM e encerra limpo.
- Tarefa: `time docker stop <c>`, depois `docker inspect --format '{{.State.ExitCode}}' <c>` e as últimas linhas do log.
- Pronto quando: tempo, exit code e a linha "Shutting down" estão anotados.
- Checagem: por que o seu `CMD` em lista já resolve isso sem `tini`?
- Fontes: https://docs.docker.com/reference/dockerfile/#entrypoint [abre] (seção sobre forma exec × shell).
- **Experimento F1.E2 — Forma shell engole o sinal.** Hipótese: com `CMD uvicorn ...` (forma shell), o `docker stop` leva ~10 s e sai com 137. Provocar: build de uma tag `:shellform` com o CMD em forma shell; `time docker stop`. Observar: tempo, exit code, ausência de "Shutting down"; `docker top` mostra `/bin/sh -c` como PID 1. Registrar em `docs/experiments/F1-E2-sinais-shell-form.md`.
- Armadilha: um script de entrypoint em shell precisa terminar com `exec "$@"`, senão o shell vira PID 1 (https://hynek.me/articles/docker-signals/ [abre]).

**F1.M2.P3 — Build check que avisa da forma shell**
- Ideia: o BuildKit tem checks; `JSONArgsRecommended` avisa CMD em forma shell.
- Tarefa: `docker build --check .` na tag `:shellform` e na normal.
- Pronto quando: o aviso aparece só na `:shellform`.
- Checagem: por padrão o check reprova o build? Como transformá-lo em gate?
- Pista: diretiva `# check=` no topo do Dockerfile.
- Fontes: https://docs.docker.com/build/checks/ [abre] · https://docs.docker.com/reference/build-checks/ [abre]

**F1.M2.P4 — `uv run` no CMD**
- Ideia: `uv run` põe um processo no meio e pode sincronizar o ambiente na subida.
- Tarefa: só ler e responder (não precisa mudar o Dockerfile): por que o seu `CMD` chama `/swarmlab/.venv/bin/uvicorn` direto?
- Pronto quando: a resposta cita sinais e tempo de subida.
- Checagem: que flag do `uv run` evita a sincronização na subida?
- Pista: guia do uv para Docker.
- Fontes: https://docs.astral.sh/uv/guides/integration/docker/ [abre] · issues do uv: https://github.com/astral-sh/uv/issues [abre] (procure "uv run signal"; issue específica não verificada).

**F1.M2.P5 — STOPSIGNAL e tempo de graça**
- Ideia: `STOPSIGNAL` troca o sinal de parada; `docker stop -t N` muda a espera. O worker vai precisar de tempo para terminar o job corrente.
- Tarefa: escrever um `sandbox.py` (fora do git) que trata SIGTERM, dorme 15 s simulando trabalho e sai; rodar com `docker stop` (10 s padrão) e com `docker stop -t 30`.
- Pronto quando: no primeiro caso sai com 137, no segundo com 0.
- Checagem: no Compose, qual chave faz o papel do `-t 30`?
- Pista: `stop_grace_period` na referência de services.
- Fontes: https://docs.docker.com/reference/dockerfile/#stopsignal [abre] · https://docs.docker.com/reference/compose-file/services/ [abre] · palestra https://pycon.de/archive/2026/talks/python-hates-being-pid-1-writing-container-aware-code-for-kubernetes/ [abre] (exemplo em Kubernetes, mesma ideia).

**F1.M2.P6 — `--init` e processos filhos**
- Ideia: se o seu processo cria filhos, alguém precisa colher zumbis e repassar sinais; `--init` põe o `tini` como PID 1.
- Tarefa: rodar a API com `--init` e ver em `docker top` quem virou PID 1.
- Pronto quando: `docker-init` aparece como pai do uvicorn.
- Checagem: com uvicorn de 1 processo, você precisa de `--init`? E com `--workers 4`?
- Fontes: https://docs.docker.com/reference/cli/docker/container/run/#init [abre] · hynek (acima).

### F1.M3 — Limites de recurso (pendência da Fase 1)

**F1.M3.P1 — Sem limite, o container usa a máquina toda**
- Ideia: memória e CPU são limitadas por cgroups; por padrão não há limite.
- Tarefa: `docker stats --no-stream` com a API rodando; anotar a coluna `LIMIT`.
- Pronto quando: você viu que o limite é a RAM do host.
- Checagem: num nó de 1 GB da Fase 3, o que acontece se um container sem limite vazar memória?
- Fontes: https://docs.docker.com/engine/containers/resource_constraints/ [abre]

**F1.M3.P2 — Limite de memória e OOM**
- Ideia: passou do limite, o kernel mata o processo (OOM killer); o Docker marca `OOMKilled`.
- Tarefa: criar um endpoint `/debug/alloc?mb=N` (só em dev) que aloca memória; rodar com `--memory 128m --memory-swap 128m` e chamar com 300.
- Pronto quando: `docker inspect --format '{{.State.OOMKilled}} {{.State.ExitCode}}'` mostra `true 137`.
- Checagem: por que `--memory-swap` igual a `--memory`?
- Pista: sem isso o container pode usar swap.
- Fontes: resource_constraints (acima) · livro não cobre limites (só flags da CLI do Azure, p. 250-261).
- **Experimento F1.E3 — OOM.** Hipótese escrita antes. Provocar como acima. Observar `OOMKilled`, exit code, `dmesg | tail`. Registrar em `docs/experiments/F1-E3-oom.md`.

**F1.M3.P3 — CPU e PIDs**
- Ideia: `--cpus 0.5` limita tempo de CPU (throttling, não morte); `--pids-limit` barra fork bomb.
- Tarefa: endpoint que faz conta pesada por 5 s; rodar com `--cpus 0.25` e medir o tempo da requisição contra sem limite.
- Pronto quando: os dois tempos estão anotados e o de 0.25 é maior.
- Checagem: CPU estourada mata o container como memória estourada?
- Fontes: https://docs.docker.com/reference/cli/docker/container/run/ [abre]

**F1.M3.P4 — Filesystem read-only e capabilities**
- Ideia: `--read-only` + `--tmpfs /tmp` + `--cap-drop ALL` + `--security-opt no-new-privileges` reduzem o estrago de uma invasão.
- Tarefa: rodar a API com essas quatro flags; ver o que quebra e corrigir sem tirar as flags.
- Pronto quando: `/health` responde com as quatro flags ativas.
- Checagem: o que no Python tenta escrever no disco por padrão?
- Pista: `__pycache__`, `PYTHONDONTWRITEBYTECODE`.
- Fontes: https://docs.docker.com/engine/containers/run/#runtime-privilege-and-linux-capabilities [abre] · https://docs.docker.com/engine/security/ [abre] · livro §17.2 (p. 348, root é a misconfig mais comum).
- **Experimento F1.E4 — Read-only.** Hipótese, provocar com `--read-only` sem tmpfs, observar o erro, corrigir. Registrar em `docs/experiments/F1-E4-read-only.md`.

### F1.M4 — Redes: bridge e DNS por nome (antes do Compose)

**F1.M4.P1 — A bridge padrão**
- Ideia: todo container cai na rede `bridge` se você não disser nada; ela **não** tem DNS por nome.
- Tarefa: `docker network ls`; subir dois containers `python:3.14.10-slim-trixie` com `sleep infinity` sem `--network`; tentar `getent hosts <nome-do-outro>` de um no outro.
- Pronto quando: o nome não resolve, mas o IP (de `docker inspect`) responde.
- Checagem: por que nunca fixar IP de container?
- Pista: livro p. 108-110.
- Fontes: https://docs.docker.com/engine/network/ [abre] · https://docs.docker.com/engine/network/drivers/bridge/ [abre]

**F1.M4.P2 — Rede definida por você**
- Ideia: numa bridge criada por você, o Docker põe um DNS embutido (127.0.0.11) que resolve nome de container.
- Tarefa: `docker network create lab`; repetir o P1 com `--network lab`; olhar `/etc/resolv.conf` dentro.
- Pronto quando: `getent hosts` resolve o nome.
- Checagem: quem responde o DNS dentro do container?
- Fontes: livro cap. 4 (p. 51-58) · bridge (acima).

**F1.M4.P3 — Um container em duas redes**
- Ideia: um container pode estar em várias redes; é assim que o Traefik vai falar com a API sem enxergar o banco.
- Tarefa: criar `edge` e `data`; `a` só em `edge`, `b` em `edge` e `data` (`docker network connect`), `c` só em `data`. Testar quem resolve quem.
- Pronto quando: você tem a matriz "a↔b sim, b↔c sim, a↔c não".
- Checagem: em que rede fica cada serviço do SwarmLab (traefik, api, worker, migrator, postgres)?
- Fontes: https://docs.docker.com/reference/cli/docker/network/ não está nos inventários; use a página geral https://docs.docker.com/engine/network/ [abre].

**F1.M4.P4 — Rede `internal`**
- Ideia: `--internal` corta a saída para fora; o banco não precisa de internet.
- Tarefa: `docker network create --internal data_int`; de um container nela, tentar `python -c "import urllib.request; urllib.request.urlopen('https://example.com', timeout=3)"`.
- Pronto quando: dá erro de rede, e a resolução entre containers da mesma rede continua funcionando.
- Checagem: se você publicar porta (`-p`) num container que só está numa rede internal, ela fica acessível?
- Fontes: https://docs.docker.com/reference/compose-file/networks/ [abre] · inventário docs §2.3.

**F1.M4.P5 — Porta publicada e firewall**
- Ideia: `-p 5432:5432` publica em todas as interfaces; o Docker escreve regras de iptables que passam por cima do UFW.
- Tarefa: publicar um container em `-p 8001:8000` e em `-p 127.0.0.1:8002:8000`; comparar com `ss -ltnp`.
- Pronto quando: um aparece em `0.0.0.0` e o outro em `127.0.0.1`.
- Checagem: por que o Postgres do dev, se publicado, deve usar `127.0.0.1:`?
- Fontes: https://docs.docker.com/engine/network/packet-filtering-firewalls/ [abre] · https://docs.docker.com/engine/network/port-publishing/ [abre].
- **Experimento F1.E5 — UFW não protege porta publicada** (só se o UFW estiver ativo na máquina; se não, faça na Fase 3 numa VM). Hipótese, provocar com `ufw deny 8001` e acessar de outra máquina/VM, observar, registrar em `docs/experiments/F1-E5-ufw-portas.md`.

### F1.M5 — Volumes e bind mounts (antes do Compose)

**F1.M5.P1 — O dado do container é efêmero**
- Ideia: o que o container escreve vai para a camada gravável, que morre no `rm`.
- Tarefa: subir `postgres:18` (fixe a tag de patch que você conferir no Hub) **sem volume**, com senha só de laboratório por `-e`; criar uma tabela; `docker rm -f`; recriar; procurar a tabela.
- Pronto quando: a tabela sumiu.
- Checagem: parar (`stop`) também apaga o dado?
- Pista: livro p. 79.
- Fontes: livro cap. 6, §6.1 (p. 77-82).

**F1.M5.P2 — O volume anônimo que ninguém acha**
- Ideia: a imagem do Postgres declara `VOLUME`; sem `-v` nasce um volume anônimo com id aleatório.
- Tarefa: `docker volume ls` depois do P1; achar o volume órfão; `docker inspect` do container para ver `Mounts`.
- Pronto quando: você identificou qual volume anônimo era do Postgres.
- Checagem: em que caminho o `VOLUME` do Postgres 18 está declarado?
- Pista: `docker image inspect postgres:18 --format '{{json .Config.Volumes}} {{json .Config.Env}}'`.
- Fontes: livro p. 87 · https://hub.docker.com/_/postgres [abre].
- Armadilha: limpar volumes órfãos é com `docker volume rm <nome>` **um a um**, olhando o nome. Nunca `volume prune`.

**F1.M5.P3 — Volume nomeado no Postgres 18**
- Ideia: **no Postgres 18+, `PGDATA=/var/lib/postgresql/18/docker` e o `VOLUME` é `/var/lib/postgresql`. Monte o volume em `/var/lib/postgresql`.** Montar em `/var/lib/postgresql/data` (a receita de livros, blogs e da 17 para trás) **não persiste** os dados.
- Tarefa: `docker volume create pgdata_lab`; rodar o Postgres com `-v pgdata_lab:/var/lib/postgresql`; criar tabela; `rm -f`; recriar com o mesmo volume.
- Pronto quando: a tabela sobreviveu.
- Checagem: por que o livro (p. 183, `PGDATA`) e o inventário de docs (§2.5) não servem como estão para a sua versão?
- Fontes: verificação [conferido]: https://github.com/docker-library/docs/blob/master/postgres/content.md (PR docker-library/postgres#1259) · livro §6.2 (p. 82-87).
- **Experimento F1.E6 — Caminho errado do volume.** Hipótese: com `-v x:/var/lib/postgresql/data` no Postgres 18, os dados somem ao recriar. Provocar, observar `docker inspect` (Mounts) e o volume anônimo novo, registrar em `docs/experiments/F1-E6-pgdata-18.md`.

**F1.M5.P4 — Bind mount e dono do arquivo**
- Ideia: bind mount liga um diretório do host; o padrão da casa para dados de banco é bind mount. O UID do processo no container precisa poder escrever ali.
- Tarefa: criar `./lab-data/pg` no host e rodar o Postgres 18 com `--mount type=bind,source=$PWD/lab-data/pg,target=/var/lib/postgresql`; ver o dono dos arquivos com `ls -ln`.
- Pronto quando: o Postgres subiu e você sabe qual UID ficou dono dos arquivos.
- Checagem: por que `chmod 777` não é solução?
- Pista: UID do usuário `postgres` dentro da imagem (`docker run --rm postgres:18 id postgres`).
- Fontes: livro §6.3 (p. 88-91) · https://docs.docker.com/engine/storage/bind-mounts/ [abre] · armadilha UID/GID: blog do Nick Janetakis https://nickjanetakis.com/blog [abre] (post específico não verificado).
- Armadilha: `lab-data/` vai no `.gitignore` e no `.dockerignore`.

**F1.M5.P5 — Bind sombreia o diretório**
- Ideia: montar por cima de um diretório da imagem esconde o que estava lá.
- Tarefa: rodar a API com `-v $PWD/sandbox-vazio:/swarmlab/app` e ver o erro.
- Pronto quando: você explicou por que o uvicorn não acha `app.main`.
- Checagem: em que situação esse comportamento é útil (Fase 2, dev)?
- Fontes: livro §6.4 (p. 91-94).

**F1.M5.P6 — Bind read-only e tmpfs**
- Ideia: config se monta read-only; arquivo temporário vai em tmpfs (memória).
- Tarefa: montar um `sandbox-config.toml` em read-only e tentar escrever nele de dentro.
- Pronto quando: aparece "Read-only file system".
- Fontes: livro p. 89-90 · https://docs.docker.com/engine/storage/tmpfs/ [abre] · https://docs.docker.com/engine/storage/volumes/ [abre] · https://docs.docker.com/engine/storage/ [abre].

### F1.M6 — BuildKit: ARG × ENV, targets, cache mounts, secrets de build

**F1.M6.P1 — ARG × ENV**
- Ideia: `ARG` só existe no build; `ENV` vai para a imagem e para o container. ARG declarado antes do `FROM` só vale no `FROM`.
- Tarefa: parametrizar a versão do Python e do uv com `ARG`; usar o ARG depois do `FROM` sem redeclarar e ver que chega vazio; redeclarar.
- Pronto quando: `docker build --build-arg PYTHON_VERSION=...` funciona e você provou o escopo.
- Checagem: um container rodando enxerga o valor de um `ARG`?
- Fontes: https://docs.docker.com/reference/dockerfile/#arg [abre] · https://docs.docker.com/build/building/variables/ [abre] · livro §11.3 (p. 196-199; "sempre ter default", p. 198).

**F1.M6.P2 — LABEL de rastreabilidade**
- Ideia: a imagem deve dizer de que commit veio.
- Tarefa: `ARG GIT_SHA=local` + `LABEL org.opencontainers.image.revision=$GIT_SHA`; build com `--build-arg GIT_SHA=$(git rev-parse --short HEAD)`.
- Pronto quando: `docker image inspect -f '{{.Config.Labels}}'` mostra o SHA.
- Fontes: livro p. 195-199 (o livro não cita as chaves `org.opencontainers.*`).

**F1.M6.P3 — Segredo em ARG vaza**
- Ideia: ARG e ENV ficam gravados nos metadados.
- **Experimento F1.E7 — Vazamento por ARG.** Hipótese escrita antes. Provocar: `--build-arg TOKEN=abc123` usado num `RUN`. Observar: `docker history --no-trunc` mostra `abc123`; o build check `SecretsUsedInArgOrEnv` avisa. Registrar em `docs/experiments/F1-E7-arg-vaza.md`.
- Fontes: https://docs.docker.com/build/checks/ [abre].

**F1.M6.P4 — Secret de build**
- Ideia: `RUN --mount=type=secret` entrega o segredo só durante aquele `RUN`, sem gravar em camada.
- Tarefa: um `RUN --mount=type=secret,id=token test -f /run/secrets/token && wc -c /run/secrets/token`; build com `--secret id=token,src=./sandbox-token.txt`; repetir a busca do F1.E7.
- Pronto quando: o `wc` imprime o tamanho e o `history` não mostra o conteúdo.
- Checagem: secret de build é a mesma coisa que o `secrets:` do Compose?
- Fontes: https://docs.docker.com/build/building/secrets/ [abre].
- Armadilha: mudar o conteúdo do secret não invalida o cache sozinho.

**F1.M6.P5 — Cache mount do uv**
- Ideia: o cache do uv pode persistir entre builds fora das camadas.
- Tarefa: trocar o `RUN uv sync --locked` por `RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked`; adicionar uma dependência e medir `time docker build` antes e depois.
- Pronto quando: os dois tempos estão anotados e `docker buildx du` mostra o cache.
- Checagem: o cache mount vai junto quando você faz push da imagem?
- Pista: guia do uv (`UV_LINK_MODE=copy` por causa do aviso de hardlink).
- Fontes: https://docs.docker.com/build/cache/optimize/ [abre] · https://docs.docker.com/reference/dockerfile/#run---mount [abre] · https://docs.astral.sh/uv/guides/integration/docker/ [abre] · https://hynek.me/articles/docker-uv/ [abre] · https://devblogs.microsoft.com/ise/dockerizing-uv/ [URL corrigida].

**F1.M6.P6 — Duas camadas: dependências e projeto**
- Ideia: instalar as dependências sem o projeto (`--no-install-project`) com bind mount de `uv.lock`/`pyproject.toml` separa o que muda pouco do que muda muito.
- Tarefa: aplicar o padrão do guia do uv com `--mount=type=bind` para os dois arquivos.
- Pronto quando: mudar só `app/main.py` deixa o passo de dependências `CACHED`.
- **Experimento F1.E8 — Ordem errada invalida o cache.** Hipótese, inverter a ordem (copiar `app` antes do `uv sync`), editar um `.py`, observar o `uv sync` sem `CACHED`, registrar em `docs/experiments/F1-E8-cache-ordem.md`.
- Fontes: https://docs.docker.com/build/cache/invalidation/ [abre] · livro p. 354-355.

**F1.M6.P7 — Targets**
- Ideia: `--target` constrói até um stage; dá para ter `test` e `runtime` no mesmo Dockerfile, e o BuildKit pula stages de que o alvo não depende.
- Tarefa: criar um stage `test` (a partir do builder, com dependências de dev) que roda `pytest`; build `--target test` e `--target runtime`.
- Pronto quando: `--target runtime` não executa o pytest (confira no `--progress=plain`).
- Checagem: por que o stage de teste não deve virar a imagem publicada?
- Fontes: https://docs.docker.com/build/building/multi-stage/ [abre] · livro §17.4 (p. 353).

**F1.M6.P8 — `# syntax` e cache externo**
- Ideia: `# syntax=docker/dockerfile:1` escolhe o frontend; cache pode ser exportado para reusar em CI.
- Tarefa: exportar o cache com `--cache-to type=local,dest=./.buildcache`, apagar só o cache de build com `docker builder prune -af` e reconstruir com `--cache-from type=local,src=./.buildcache`.
- Pronto quando: os passos aparecem `CACHED` depois do prune.
- Checagem: `docker builder prune` apaga volume de banco?
- Pista: olhe o nome do comando — o que exatamente ele limpa?
- Fontes: https://docs.docker.com/build/buildkit/frontend/ [abre] · https://docs.docker.com/build/cache/backends/ [abre] · https://docs.docker.com/build/cache/ [abre].
- Armadilha: exportar cache pode exigir o driver `docker-container` (F1.M0.P2).

### F1.M7 — Registry, push e digest

**F1.M7.P1 — Tag é mutável, digest não**
- Ideia: a tag pode passar a apontar para outra imagem; o digest `sha256:` é o conteúdo.
- Tarefa: `docker buildx imagetools inspect python:3.14.10-slim-trixie`; anotar o digest do índice e o de `linux/amd64`.
- Pronto quando: os dois digests estão anotados e você sabe qual é qual.
- Checagem: qual dos dois você põe no `FROM ...@sha256:`, e por quê?
- Fontes: https://docs.docker.com/reference/cli/docker/image/pull/#pull-an-image-by-digest-immutable-identifier [abre] · https://docs.docker.com/reference/cli/docker/image/tag/ [abre].
- Armadilha: fixar digest congela os patches; precisa de rotina para atualizar.

**F1.M7.P2 — Registry local**
- Ideia: no Swarm, todo nó puxa a imagem de um registry. Antes, um registry local.
- Tarefa: subir a imagem oficial `registry` (fixe a tag que conferir no Hub; o inventário cita `registry:3`) em `127.0.0.1:5000`; `docker tag` da API para `localhost:5000/swarmlab/app:0.1.0`; `docker push`.
- Pronto quando: o push imprime um digest.
- Checagem: por que um registry em `localhost` não precisa de `insecure-registries`, e um em `192.168.x.x` sem TLS precisa?
- Fontes: livro cap. 5 (p. 61-76; registry local p. 67, `insecure-registries` p. 69-71) · https://hub.docker.com/_/registry [abre] · https://distribution.github.io/distribution/ [abre] · https://docs.docker.com/reference/cli/docker/image/push/ [abre] · https://docs.docker.com/reference/cli/dockerd/#insecure-registries [abre].

**F1.M7.P3 — Pull por digest**
- Ideia: rodar por digest garante que é exatamente a imagem testada.
- Tarefa: apagar a imagem local (`docker image rm`), puxar com `localhost:5000/swarmlab/app@sha256:...`, comparar com `docker inspect --format '{{.RepoDigests}}'`.
- Pronto quando: o digest do push e o `RepoDigests` batem.
- Checagem: se você der push de novo na tag `0.1.0` com código diferente, o que acontece com quem puxa por digest?
- **Experimento F1.E9 — Tag mutável.** Hipótese, provocar (push de duas imagens diferentes na mesma tag), observar digests, registrar em `docs/experiments/F1-E9-tag-mutavel.md`.

**F1.M7.P4 — Estratégia de tags e credenciais**
- Ideia: tag semântica + SHA; `latest` não diz nada. Login grava credencial em `~/.docker/config.json`.
- Tarefa: definir no PROGRESS.md a regra de tag do SwarmLab (ex.: `0.3.1` e `sha-abc1234`); ler sobre credential store.
- Pronto quando: a regra está escrita.
- Fontes: livro §5.4 (p. 72-74) · https://docs.docker.com/reference/cli/docker/login/#credential-stores [abre] · https://docs.docker.com/reference/cli/docker/login/ [abre].
- Armadilha: no livro, apagar imagem só pela API v2 do registry e precisa de garbage collection (lab 5.6, p. 75-76).

**F1.M7.P5 — Multi-plataforma (opcional)**
- Ideia: se alguma VM for Arm, a imagem precisa de `linux/arm64` também.
- Tarefa: só se aplicável: `docker buildx build --platform linux/amd64,linux/arm64 --push`.
- Fontes: https://docs.docker.com/build/building/multi-platform/ [abre] · livro cap. 12 (p. 207-227).

### F1.M8 — Qualidade: hadolint, dive, Trivy, Scout

**F1.M8.P1 — hadolint**
- Ideia: lint de Dockerfile acha erro antes do build.
- Tarefa: rodar o hadolint (pela imagem dele, sem instalar nada) no seu Dockerfile; corrigir ou justificar cada aviso.
- Pronto quando: zero erro; avisos ignorados estão justificados num comentário.
- Checagem: hadolint e `docker build --check` acham as mesmas coisas?
- Fontes: https://github.com/hadolint/hadolint [abre].

**F1.M8.P2 — dive**
- Ideia: ver camada por camada o que entrou e o que é desperdício.
- Tarefa: `dive` na imagem final e na do builder; anotar a eficiência e o maior arquivo inútil.
- Pronto quando: os números estão no PROGRESS.md.
- Checagem: apagar um arquivo num `RUN` seguinte diminui a imagem?
- Pista: livro p. 338 ("Once data is in a layer...").
- Fontes: https://github.com/wagoodman/dive [abre] · livro §17.1 (p. 336-339).

**F1.M8.P3 — Trivy na imagem**
- Ideia: scan de CVE por pacote do SO e do Python.
- Tarefa: rodar Trivy (pela imagem dele, com volume de cache nomeado para a base de vulnerabilidades) com `--severity HIGH,CRITICAL` na sua imagem.
- Pronto quando: a contagem está anotada com a data (a base muda com o tempo).
- Fontes: livro §17.2 (p. 344-348) · https://github.com/aquasecurity/trivy [abre].

**F1.M8.P4 — Trivy como gate que reprova**
- Ideia: passo de gate tem que conseguir reprovar; prove com um canário.
- Tarefa: rodar com `--exit-code 1 --severity CRITICAL` numa base antiga de propósito (canário) e na sua; ver os dois exit codes. Criar `.trivyignore` versionado se precisar aceitar um CVE, com motivo.
- Pronto quando: o canário dá exit 1 e a sua imagem dá 0 (ou os CVEs aceitos estão justificados).
- Checagem: por que um scan que nunca reprovou não prova nada?
- Fontes: livro p. 346 ("supply an exit code") · Trivy (acima).
- **Experimento F1.E10 — Scan como gate.** Hipótese, provocar com tag antiga, observar exit code, registrar em `docs/experiments/F1-E10-scan-gate.md`.

**F1.M8.P5 — Trivy no repo e no Dockerfile**
- Ideia: Trivy também lê o `uv.lock` e acha misconfig no Dockerfile.
- Tarefa: `repository`/`fs --scanners vuln` e `--scanners misconfig` no projeto.
- Pronto quando: as saídas foram lidas e cada achado tem destino (corrigir ou justificar).
- Fontes: livro p. 346.

**F1.M8.P6 — Docker Scout (comparação)**
- Ideia: o Scout lista CVEs e sugere base melhor; exige login no Docker Hub (inventário diz que o plano gratuito tem limites).
- Tarefa: `docker scout quickview` e `docker scout recommendations` na imagem; comparar a contagem com a do Trivy.
- Pronto quando: as duas contagens estão lado a lado.
- Checagem: por que dois scanners dão números diferentes para a mesma imagem?
- Fontes: https://docs.docker.com/scout/ [abre] · https://docs.docker.com/scout/quickstart/ [abre] · https://docs.docker.com/reference/cli/docker/scout/ [abre].
- **Não verificado:** "o Scout substitui o antigo `docker scan`" (a verificação não confirmou a frase). Grype é alternativa: https://github.com/anchore/grype [abre].

**F1.M8.P7 — Fechamento: `docker init` e checklist**
- Ideia: comparar o seu Dockerfile com o que o Docker gera e com o checklist oficial.
- Tarefa: rodar `docker init` numa **cópia** do projeto (fora do repo); listar três diferenças com o seu e justificar cada uma; passar pelo checklist de boas práticas.
- Pronto quando: as três diferenças e o checklist estão no PROGRESS.md.
- Fontes: https://docs.docker.com/reference/cli/docker/init/ [conferido: a página existe e traz exemplo de Python] · https://docs.docker.com/build/building/best-practices/ [abre] · https://docs.docker.com/guides/python/ [abre] · https://testdriven.io/blog/docker-best-practices/ [abre].
- Armadilha: o template não usa uv; não sobrescreva o seu Dockerfile.

**Fim da Fase 1:** conferir os 6 critérios da seção 1 e atualizar o PROGRESS.md.

---

## FASE 2 — Compose: o SwarmLab serviço a serviço

Ordem de construção: **api → postgres → migrator → worker → traefik**, depois config, ambientes, watch, operação, backup e destruir-e-recriar. Cada serviço entra só quando o anterior está verde.

Arquivos que o Lucas vai escrever: `compose.yaml` (base), `compose.override.yaml` (dev, carregado automaticamente), `compose.test.yaml`, `secrets/` (fora do git), `.env` (fora do git), `Makefile` ou `scripts/`.

### F2.M1 — Primeiro `compose.yaml`: só a API

**F2.M1.P1 — Compose v2 e o formato atual**
- Ideia: o comando é `docker compose` (plugin). O arquivo canônico é `compose.yaml`; a chave `version:` é obsoleta e só gera aviso.
- Tarefa: escrever `compose.yaml` com um serviço `api` que faz `build: .` e publica `8000`, substituindo o `docker run -p ...`.
- Pronto quando: `docker compose up -d` e `curl localhost:8000/health` respondem.
- Checagem: o Docker Engine sabe que esses containers formam "um app"?
- Pista: livro p. 107 (Compose é cliente).
- Fontes: livro cap. 7, §7.1-7.2 (p. 99-108) · https://docs.docker.com/compose/ [abre] · https://docs.docker.com/reference/compose-file/version-and-name/ [abre] · https://docs.docker.com/compose/intro/history/ [abre].
- Armadilha: exemplos da internet com `docker-compose` (hífen, v1) e `version: "3.8"`; o livro ainda tem quatro resíduos de hífen (p. 101, 113, 145, 421).

**F2.M1.P2 — O modelo normalizado**
- Ideia: `docker compose config` mostra o arquivo final que o Compose vai usar. É a ferramenta de depuração número 1.
- Tarefa: rodar `docker compose config` e achar no resultado o nome do projeto, a rede criada e o nome da imagem.
- Pronto quando: os três estão anotados.
- Checagem: de onde veio o nome do projeto?
- Fontes: https://docs.docker.com/compose/how-tos/project-name/ [abre] · livro p. 165.

**F2.M1.P3 — `image:` junto com `build:`**
- Ideia: dar nome à imagem construída permite reusar a mesma imagem para api, worker e migrator.
- Tarefa: acrescentar `image: localhost:5000/swarmlab/app:${APP_TAG:-dev}`; `docker compose build` e `docker images`.
- Pronto quando: a imagem aparece com esse nome.
- Fontes: https://docs.docker.com/reference/compose-file/build/ [abre] · livro §11.3 (p. 194-199).

**F2.M1.P4 — Ciclo de vida**
- Ideia: `up`, `ps`, `logs`, `stop`, `start`, `down`; escala feita na linha de comando não fica no arquivo.
- Tarefa: `up -d --scale api=2` (vai falhar pela porta; entenda por quê), depois `down`.
- Pronto quando: você explicou o erro de porta.
- Checagem: o que impede a escala: `ports` fixo ou `container_name`?
- Fontes: livro p. 105-107 · https://docs.docker.com/reference/cli/docker/compose/ [abre].

### F2.M2 — Postgres com dado persistente, secret e healthcheck

**F2.M2.P1 — Serviço `postgres` com bind mount**
- Ideia: padrão da casa: dados do banco em bind mount; Postgres 18+ monta em `/var/lib/postgresql`.
- Tarefa: serviço `postgres` com imagem `postgres:18.x` fixada, bind `./data/pg:/var/lib/postgresql` (sintaxe longa), sem `ports`.
- Pronto quando: `docker compose up -d postgres` sobe e os arquivos aparecem em `./data/pg`.
- Checagem: por que não publicar a 5432 na base?
- Fontes: verificação [conferido] (PGDATA 18+) · https://docs.docker.com/reference/compose-file/services/#volumes [abre] · https://docs.docker.com/reference/compose-file/volumes/ [abre] · livro lab 6.6 (p. 96) e 7.6 (p. 117).
- Armadilha: `data/` no `.gitignore` e no `.dockerignore`.

**F2.M2.P2 — Senha por secret, não por environment**
- Ideia: `environment` é texto plano visível no `docker inspect`; `secrets:` monta um arquivo em `/run/secrets/`. A imagem aceita `POSTGRES_PASSWORD_FILE`.
- Tarefa: `secrets/db_password.txt` (`chmod 600`, no `.gitignore`), `secrets:` top-level com `file:`, e `POSTGRES_PASSWORD_FILE=/run/secrets/db_password`.
- Pronto quando: `docker inspect` do postgres não mostra a senha, e `psql` entra com ela.
- Checagem: no Compose, o secret é cifrado?
- Pista: livro p. 113 ("the file on the host gets surfaced").
- Fontes: https://docs.docker.com/compose/how-tos/use-secrets/ [abre] · https://docs.docker.com/reference/compose-file/secrets/ [abre] · https://hub.docker.com/_/postgres [abre] · livro §7.4 (p. 111-115).
- Armadilha: `uid/gid/mode` de secret têm suporte parcial fora do Swarm.

**F2.M2.P3 — Healthcheck do Postgres**
- Ideia: `pg_isready` diz se o servidor aceita conexão.
- Tarefa: `healthcheck:` com `test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]`, `interval`, `timeout`, `retries`, `start_period`.
- Pronto quando: `docker compose ps` mostra `healthy`.
- Checagem: por que `$$` e não `$`?
- Fontes: https://docs.docker.com/reference/compose-file/services/#healthcheck [abre] · livro §8.4 (p. 132-134).
- Armadilha: na primeira subida o entrypoint roda os scripts de init e reinicia o servidor; o `pg_isready` pode ficar verde cedo demais (inventário comunidade, Fase 2 item 2). Use `-d` correto e `start_period`.

**F2.M2.P4 — `start_interval`**
- Ideia: checar rápido durante a subida e devagar depois.
- Tarefa: acrescentar `start_interval: 2s`.
- Pronto quando: o banco vira `healthy` mais cedo que com o `interval` normal (cronometre).
- Fontes: [conferido] Compose 2.20.2+ e Engine 25+: https://docs.docker.com/reference/dockerfile/#healthcheck · https://docs.docker.com/reference/compose-file/services/.

**F2.M2.P5 — Healthcheck no Compose não reinicia**
- Ideia: assim como no Docker puro (seu experimento 1), `unhealthy` no Compose é só rótulo.
- Tarefa: só responder, ligando ao experimento 1: quem vai agir sobre `unhealthy`?
- Pronto quando: resposta escrita no PROGRESS.md.
- Fontes: livro p. 132 · https://docs.docker.com/compose/how-tos/startup-order/ [abre].

### F2.M3 — Redes separadas e `internal`

**F2.M3.P1 — Rede `edge` e rede `data`**
- Ideia: traefik↔api na `edge`; api/worker/migrator↔postgres na `data`, que é `internal: true`.
- Tarefa: declarar as duas redes top-level e ligar `api` às duas e `postgres` só à `data`.
- Pronto quando: `docker compose config` mostra as redes e `docker network inspect` confirma `Internal: true`.
- Fontes: https://docs.docker.com/reference/compose-file/networks/ [abre] · https://docs.docker.com/compose/how-tos/networking/ [abre] · livro §10.2 (p. 170-171, isola ambientes, não camadas).

**F2.M3.P2 — Provar o isolamento**
- Tarefa: de dentro do postgres, tentar sair para a internet; de um container só na `edge`, tentar resolver `postgres`.
- Pronto quando: as duas tentativas falham, e a api resolve `postgres`.
- Checagem: por que o Traefik não pode ficar só numa rede `internal`?
- Pista: comunidade, Fase 2 item 3 (ACME e saída).
- **Experimento F2.E1 — Rede interna.** Hipótese, provocar, observar, registrar em `docs/experiments/F2-E1-rede-interna.md`.

**F2.M3.P3 — DNS de serviço**
- Ideia: a api acha o banco pelo **nome do serviço**; nunca por IP.
- Tarefa: definir `DATABASE_URL` usando `postgres` como host (a senha vem do arquivo do secret, lida pela app).
- Pronto quando: um endpoint `/ready` da api faz `SELECT 1` e responde 200.
- Checagem: qual a diferença entre `/health` (liveness) e `/ready` (readiness)?
- Fontes: livro §7.3 (p. 108-111) · inventário livro §4.2 item 8.

### F2.M4 — Migrator: tarefa que termina

**F2.M4.P1 — Mesmo imagem, outro comando**
- Ideia: o migrator é a mesma imagem com `command:` diferente; roda e sai com 0.
- Tarefa: escolher a ferramenta de migração (decisão do Lucas; ex.: Alembic) e criar a migração da tabela `jobs`; serviço `migrator` com `command:` e `restart: "no"`.
- Pronto quando: `docker compose ps -a` mostra o migrator `Exited (0)` e a tabela existe.
- Fontes: https://docs.docker.com/reference/compose-file/services/#restart [abre].
- Armadilha: migrator com `restart: always` entra em loop.

**F2.M4.P2 — ENTRYPOINT × CMD (opcional)**
- Ideia: um entrypoint pode aceitar `api`, `worker` ou `migrate`.
- Tarefa: decidir entre `command:` por serviço ou entrypoint com subcomando; se entrypoint em shell, terminar com `exec`.
- Fontes: https://docs.docker.com/reference/dockerfile/#understand-how-cmd-and-entrypoint-interact [abre].

**F2.M4.P3 — Ordem: banco saudável → migrator terminou → api**
- Ideia: `depends_on` com `condition: service_healthy` e `service_completed_successfully` (existe no Compose; **não** no Swarm).
- Tarefa: `migrator` depende de `postgres: service_healthy`; `api` depende de `migrator: service_completed_successfully`.
- Pronto quando: `docker compose up -d` sobe na ordem certa (veja os logs com timestamp).
- Fontes: [conferido] https://docs.docker.com/reference/compose-file/services/#depends_on · https://docs.docker.com/compose/how-tos/startup-order/ [abre] · livro listagem 13.5 (p. 244-245).
- **Experimento F2.E2 — Sem condition.** Hipótese: sem `service_healthy`, a api sobe antes do banco e falha. Provocar removendo a condition e recriando do zero. Registrar em `docs/experiments/F2-E2-ordem-start.md`.
- **Experimento F2.E3 — Migrator falha.** Hipótese: com `exit 1` no migrator, a api não sobe. Observar o estado da api. Registrar em `docs/experiments/F2-E3-migrator-falha.md`.

**F2.M4.P4 — Idempotência**
- Tarefa: `docker compose run --rm migrator` duas vezes.
- Pronto quando: a segunda roda sai com 0 sem mudar nada.
- Checagem: por que isso é obrigatório se o migrator rodar a cada deploy na Fase 3?
- Fontes: https://docs.docker.com/reference/cli/docker/compose/run/ [abre].

**F2.M4.P5 — Fail-fast e retry na app**
- Ideia: `depends_on` só vale no start. O banco pode cair depois, e no Swarm não há ordem nenhuma.
- Tarefa: a api tenta conectar com retry e backoff curto na subida e, se não conseguir em N segundos, sai com código ≠ 0.
- Pronto quando: com o banco parado, a api sai com erro claro no log em vez de subir "verde e quebrada".
- Fontes: livro §8.2 (p. 124-127) e §8.5 (p. 135-136).
- **Experimento F2.E4 — Banco cai depois do start.** Hipótese, `docker compose stop postgres` com a api rodando, observar `/ready` e a reconexão após `start`. Registrar em `docs/experiments/F2-E4-banco-cai.md`.

### F2.M5 — Worker e fila no Postgres

**F2.M5.P1 — Tabela de jobs e endpoint que enfileira**
- Ideia: a api grava um job (`status='pending'`); o worker consome.
- Tarefa: `POST /jobs` grava; `GET /jobs/{id}` lê o status.
- Pronto quando: um job criado aparece com `pending` no banco.

**F2.M5.P2 — Pegar um job com `FOR UPDATE SKIP LOCKED`**
- Ideia: cada worker trava a linha que pegou; os outros pulam linhas travadas.
- Tarefa: loop do worker: numa transação, `SELECT ... WHERE status='pending' ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 1`, processa, marca `done`.
- Pronto quando: o job vai para `done` e o log do worker mostra o id.
- Checagem: o que acontece com a trava se o worker morrer no meio da transação?
- Fontes: inventário livro §5 (o livro usa Redis/NATS; o padrão vem de fora). **O artigo da 2ndQuadrant citado pela comunidade sumiu** (redireciona para a home da EDB); procure equivalente no blog da EDB ou a doc do PostgreSQL sobre `SELECT ... FOR UPDATE`. Nenhum link verificado.

**F2.M5.P3 — Serviço `worker` no Compose**
- Tarefa: serviço `worker` (mesma imagem, outro comando), só na rede `data`, dependendo do migrator.
- Pronto quando: `docker compose logs -f worker` mostra jobs processados.

**F2.M5.P4 — Healthcheck do worker (heartbeat)**
- Ideia: o worker não tem HTTP; um arquivo de heartbeat atualizado a cada volta do loop serve de sinal de vida (gancho da Fase 4: "silêncio não é sucesso").
- Tarefa: o worker toca `/tmp/heartbeat`; healthcheck verifica se a idade do arquivo é < 30 s.
- Pronto quando: `docker compose ps` mostra o worker `healthy`; travando o loop de propósito, vira `unhealthy`.

**F2.M5.P5 — SIGTERM no worker**
- Ideia: no stop, o worker termina o job corrente e sai; precisa de `stop_grace_period` maior que o job mais longo.
- Tarefa: tratar SIGTERM no loop (flag de parada), `stop_grace_period: 40s`.
- Pronto quando: `docker compose stop worker` durante um job de 30 s termina com 0 e o job em `done`.
- Fontes: F1.M2 · https://docs.docker.com/reference/compose-file/services/ [abre].
- **Experimento F2.E5 — Grace curto.** Hipótese: com grace de 10 s e job de 30 s, o worker leva SIGKILL e o job volta a `pending`. Registrar em `docs/experiments/F2-E5-grace-period.md`.

**F2.M5.P6 — Escala e prova de não-duplicação**
- Tarefa: enfileirar 1000 jobs, `docker compose up -d --scale worker=3`, e escrever a consulta que prova zero duplicata (ex.: tabela de resultado com `UNIQUE(job_id)` ou contagem por `job_id`).
- Pronto quando: a consulta retorna 0 duplicatas e os 3 workers aparecem nos logs.
- Fontes: livro §21 (p. 444, escala de handlers) · https://docs.docker.com/reference/cli/docker/compose/up/ [abre].
- **Experimento F2.E6 — SKIP LOCKED com escala.** Registrar em `docs/experiments/F2-E6-skip-locked.md`.
- **Experimento F2.E7 — Worker morto no meio.** Hipótese: `docker compose kill -s SIGKILL worker` aborta a transação e o job volta para a fila. Repetir com SIGTERM. Registrar em `docs/experiments/F2-E7-worker-kill.md`.

**F2.M5.P7 — Job preso e retentativa**
- Ideia: se o processamento sai da transação (job longo), precisa de lease/timeout e contagem de tentativas; o livro não cobre.
- Tarefa: decidir (conversa, não aula) se o SwarmLab processa dentro da transação ou com lease; registrar a decisão.
- Pronto quando: decisão escrita no PROGRESS.md.

### F2.M6 — Traefik v3 com provider Docker

**F2.M6.P1 — Só o proxy publica porta**
- Ideia: o Traefik é o único serviço com `ports:` (80/443); a api perde o `ports`.
- Tarefa: serviço `traefik` (imagem v3 fixada) na rede `edge`, com provider docker e `exposedByDefault=false`.
- Pronto quando: o dashboard (só em dev) abre e não lista nenhum serviço ainda.
- Fontes: livro §20.1 e §20.4 (p. 405-410, 421-429; versão v2, converta) · https://doc.traefik.io/traefik/providers/docker/ [abre] · https://doc.traefik.io/traefik/routing/providers/docker/ [abre].

**F2.M6.P2 — Socket do Docker**
- Ideia: o provider lê a API do Docker pelo socket; montar o socket equivale a dar root no host, mesmo `:ro`.
- Tarefa: montar `/var/run/docker.sock:ro` **ou** usar um socket-proxy com allowlist; decidir e anotar o porquê.
- Fontes: https://docs.docker.com/engine/security/protect-access/ [abre] · livro p. 193 · https://github.com/Tecnativa/docker-socket-proxy [abre].

**F2.M6.P3 — Labels na api**
- Tarefa: labels `traefik.enable=true`, router com `Host(\`api.localhost\`)`, `loadbalancer.server.port=8000`, e `traefik.docker.network` apontando para a `edge`.
- Pronto quando: `curl -H 'Host: api.localhost' localhost/health` responde.
- Checagem: por que o label de rede é obrigatório quando a api está em duas redes?
- Armadilha: sintaxe de regras mudou do v2 para o v3; confira na doc do v3, não no livro.

**F2.M6.P4 — Escalar atrás do proxy**
- Tarefa: `--scale api=3` e ver no log de acesso (ou num header com o hostname) o balanceamento.
- Pronto quando: as respostas vêm de 3 containers diferentes.
- **Experimento F2.E8 — API cai atrás do proxy.** Hipótese sobre o código HTTP que o Traefik devolve com a api parada. Registrar em `docs/experiments/F2-E8-proxy-sem-backend.md`.

**F2.M6.P5 — HTTPS local e redirect (opcional)**
- Tarefa: entrypoint 443 com certificado autoassinado e redirect de 80 para 443.
- Fontes: livro p. 426.

### F2.M7 — Variáveis, `.env`, `env_file` e configs

**F2.M7.P1 — Dois mecanismos diferentes**
- Ideia: `.env` interpola o **arquivo Compose**; `environment`/`env_file` definem o ambiente **do container**.
- Tarefa: mover `APP_TAG` para o `.env` (fora do git) e `LOG_LEVEL` para um `env_file` comum.
- Pronto quando: `docker compose config --environment` mostra de onde veio cada valor.
- Fontes: https://docs.docker.com/compose/how-tos/environment-variables/ [abre] · https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/ [abre] · https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/ [abre] · livro §10.3 (p. 173-178).
- Armadilha: o livro diz que só existe o nome `.env` (p. 178); hoje existe `--env-file`.

**F2.M7.P2 — Variável obrigatória**
- Tarefa: `${APP_TAG:?defina APP_TAG}` na imagem.
- **Experimento F2.E9 — Interpolação obrigatória.** Hipótese, rodar sem a variável, observar a mensagem. Registrar em `docs/experiments/F2-E9-interpolacao.md`.

**F2.M7.P3 — Config em camadas na app**
- Ideia: default na imagem, arquivo de override montado, env var ganhando (12-factor).
- Tarefa: pydantic-settings com prefixo `SWARMLAB_`.
- Fontes: livro cap. 18 (p. 360-380).
- Armadilha: não empacotar config de todos os ambientes na imagem (livro p. 368).

**F2.M7.P4 — `configs:`**
- Tarefa: entregar a configuração estática ou dinâmica do Traefik como `configs:` (`file:` ou `content:`).
- Fontes: https://docs.docker.com/reference/compose-file/configs/ [abre].

**F2.M7.P5 — Extension fields e âncoras**
- Tarefa: `x-app-common` com `env_file`, `logging`, `networks` comuns a api/worker/migrator, usando `<<: *app-common`.
- Fontes: livro §10.4 (p. 179-181) · https://docs.docker.com/reference/compose-file/extension/ [abre] · https://docs.docker.com/reference/compose-file/fragments/ [abre].
- Armadilha: âncora não atravessa arquivos (livro p. 181).

### F2.M8 — Ambientes: override, merge, profiles

**F2.M8.P1 — `compose.override.yaml` de dev**
- Ideia: carregado automaticamente; aqui ficam portas locais, `/docs` e o Postgres em `127.0.0.1:5432`.
- Tarefa: mover para o override tudo que é só de dev.
- Pronto quando: `docker compose -f compose.yaml config` (sem override) não tem nenhuma porta além do Traefik.
- Fontes: https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/ [abre] · https://docs.docker.com/compose/how-tos/multiple-compose-files/ [abre].

**F2.M8.P2 — Regras do merge**
- Ideia: listas como `ports` são **concatenadas**; `!reset` e `!override` controlam.
- **Experimento F2.E10 — Merge concatena.** Hipótese, pôr `ports` na base e no override, ver com `config`, corrigir com `!reset`. Registrar em `docs/experiments/F2-E10-merge.md`.
- Fontes: https://docs.docker.com/reference/compose-file/merge/ [abre].

**F2.M8.P3 — Ambiente de teste paralelo**
- Tarefa: `compose.test.yaml` (sem portas de dev, banco descartável) e subir com `-p swarmlab_test` ao mesmo tempo que o dev.
- Pronto quando: `docker compose ls` mostra os dois projetos, com redes e dados separados.
- Fontes: livro §10.1-10.2 (p. 163-173) e lab 10.6 (p. 182-183).
- Armadilha: `down` sem os mesmos `-f` e `-p` não acha os recursos (livro p. 172); trocar o nome do projeto deixa volumes órfãos.

**F2.M8.P4 — Profiles**
- Ideia: serviço com profile só sobe se o profile for pedido.
- Tarefa: serviço `backup` (F2.M11) e ferramentas no profile `tools`.
- Pronto quando: `docker compose up -d` não sobe o `backup`; `--profile tools` sobe.
- Fontes: https://docs.docker.com/compose/how-tos/profiles/ [abre].
- Nota para a Fase 3: `profiles`, `develop` e `include` **não existem no schema do stack** [conferido].

**F2.M8.P5 — `include:` (leitura)**
- Ideia: compor um projeto a partir de outros arquivos (Compose 2.20.0+ [conferido]).
- Tarefa: só ler e decidir se o SwarmLab precisa (provavelmente não).
- Fontes: https://docs.docker.com/compose/how-tos/multiple-compose-files/include/ [abre] · https://docs.docker.com/reference/compose-file/include/ [conferido].

### F2.M9 — Desenvolvimento com `watch`

**F2.M9.P1 — `develop.watch` com sync**
- Ideia: Compose 2.22.0+ [conferido] sincroniza arquivos no container sem bind mount.
- Tarefa: `develop.watch` com `action: sync+restart` (ou `sync` + `--reload` do uvicorn no dev) para `app/`; `docker compose watch`.
- Pronto quando: editar um endpoint muda a resposta sem rebuild manual.
- Fontes: https://docs.docker.com/compose/how-tos/file-watch/ [abre] · https://docs.docker.com/reference/compose-file/develop/ [conferido].
- Armadilha: `sync` exige diretório gravável pelo usuário do container; na imagem os arquivos são do root (F1). Resolva só no target de dev.

**F2.M9.P2 — `rebuild` para dependências**
- Tarefa: `action: rebuild` para `uv.lock` e `pyproject.toml`.
- **Experimento F2.E11 — watch.** Hipótese sobre sync × rebuild, editar `.py` e depois `uv.lock`, observar. Registrar em `docs/experiments/F2-E11-watch.md`.

**F2.M9.P3 — Target de dev**
- Tarefa: `build.target` diferente em dev e na base.
- Fontes: https://docs.docker.com/reference/compose-file/build/ [abre].

### F2.M10 — Operação: logs, limites, hardening, restart

**F2.M10.P1 — Logging com rotação em todos os serviços**
- Tarefa: `logging: driver: json-file, options: {max-size, max-file}` via `x-logging`.
- Pronto quando: `docker inspect` de cada container mostra a rotação.
- Fontes: https://docs.docker.com/reference/compose-file/services/#logging [abre] · livro listagens 10.7/10.8 (p. 179-181).

**F2.M10.P2 — Limites de recurso**
- Ideia: o Compose v2 aplica `deploy.resources.limits` também fora do Swarm.
- Tarefa: limites de memória e CPU em api, worker e postgres.
- Pronto quando: `docker stats` mostra os limites.
- Fontes: https://docs.docker.com/reference/compose-file/deploy/#resources [abre].
- **Experimento F2.E12 — CPU do worker.** Hipótese, `cpus: 0.25` e job pesado, observar o throttling e a vazão de jobs. Registrar em `docs/experiments/F2-E12-cpu-worker.md`.

**F2.M10.P3 — Hardening no Compose**
- Tarefa: `read_only: true`, `tmpfs`, `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]` na api e no worker (repete F1.M3.P4 no arquivo).
- Fontes: https://docs.docker.com/reference/compose-file/services/ [abre].
- Nota para a Fase 3: `cap_add`/`cap_drop`, `tmpfs` e `sysctls` **funcionam** no stack; `security_opt` é **ignorado** com aviso [conferido, types.go].

**F2.M10.P4 — Restart policy**
- Tarefa: `restart: unless-stopped` em api, worker, postgres, traefik; `docker compose kill -s SIGKILL api` e ver `RestartCount`.
- Fontes: https://docs.docker.com/engine/containers/start-containers-automatically/ [abre].
- Nota: no Swarm, `restart` é ignorado; usa-se `deploy.restart_policy` [conferido].

**F2.M10.P5 — Volta depois de reiniciar o daemon**
- Tarefa: `sudo systemctl restart docker` e conferir que tudo volta sozinho.
- Fontes: livro lab 7.6 (p. 117).

**F2.M10.P6 — Ganchos para a Fase 4 (só anotar)**
- Tarefa: listar no PROGRESS.md os sinais que já existem (logs JSON, `/health`, `/ready`, heartbeat) e anotar que o daemon expõe métricas por `metrics-addr` no `daemon.json` (ex.: `127.0.0.1:9323`) [conferido: https://docs.docker.com/engine/daemon/prometheus/]. Não instalar Prometheus/Grafana agora.

### F2.M11 — Backup e restore do Postgres (testado)

**F2.M11.P1 — Dump lógico**
- Ideia: `pg_dump -Fc` gera um arquivo consistente com o banco rodando.
- Tarefa: `docker compose exec -T postgres pg_dump -Fc -U <user> <db> > backups/swarmlab-<data>.dump` (`backups/` fora do git).
- Pronto quando: o arquivo existe e `pg_restore --list` lê o conteúdo.
- Fontes: https://hub.docker.com/_/postgres [abre] · inventário docs §2.20 (livro não cobre backup).

**F2.M11.P2 — Restore num projeto de teste**
- Tarefa: subir `-p swarmlab_restore` vazio, restaurar com `pg_restore`, comparar `count(*)` de `jobs` com o original.
- Pronto quando: as contagens batem. **Esse é o critério: backup sem restore testado não conta.**
- Armadilha: restaurar por cima do banco de dev é irreversível; restaure sempre num projeto novo.

**F2.M11.P3 — Backup físico com o banco parado**
- Tarefa: parar o postgres, copiar o diretório do bind mount (`tar`), subir de novo; restaurar a cópia num projeto novo.
- Fontes: https://docs.docker.com/engine/storage/volumes/#back-up-restore-or-migrate-data-volumes [abre].
- **Experimento F2.E13 — Tar a quente.** Hipótese: `tar` do diretório com o banco rodando e escrevendo pode dar cópia inconsistente. Provocar com escrita contínua, restaurar, observar o log do Postgres na subida. Registrar em `docs/experiments/F2-E13-backup-a-quente.md`.

**F2.M11.P4 — Cópia fora do host**
- Ideia: backup só no host morre junto com o host. A regra da casa é cópia em storage externo.
- Tarefa: definir para onde a cópia vai no laboratório (outro disco, outra máquina) e escrever o script do serviço `backup` (profile `tools`).
- Pronto quando: um backup foi copiado para fora e restaurado de lá.

**F2.M11.P5 — Initdb só roda com diretório vazio**
- Tarefa: pôr um script em `/docker-entrypoint-initdb.d` e ver que ele não roda com dados existentes.
- Fontes: https://hub.docker.com/_/postgres [abre].

### F2.M12 — Destruir e recriar, smoke test

**F2.M12.P1 — `down` × `down -v`**
- Ideia: `down` remove containers e redes; `down -v` remove também volumes nomeados. Com bind mount, o diretório fica.
- **Experimento F2.E14 — `down -v`.** Só no projeto de teste. Hipótese sobre o que sobra com volume nomeado e com bind. Registrar em `docs/experiments/F2-E14-down-v.md`.

**F2.M12.P2 — `make up` / `make destroy`**
- Tarefa: alvos que sobem e destroem o ambiente de teste do zero, sem passo manual (inclui criar `secrets/` a partir de um exemplo se faltar).
- Pronto quando: `make destroy && make up` funciona numa pasta clonada limpa.

**F2.M12.P3 — `up --wait`**
- Tarefa: `docker compose up -d --wait` no alvo de teste.
- Pronto quando: o comando só retorna com tudo `healthy` (e falha se algo não ficar).
- Fontes: https://docs.docker.com/reference/cli/docker/compose/up/ [conferido: `--wait`; `--exit-code-from` implica `--abort-on-container-exit`].

**F2.M12.P4 — Smoke test que reprova**
- Tarefa: script: `up --wait` → migrator `Exited (0)` → `POST /jobs` → espera → `GET` mostra `done` → `down -v` (teste). Provar que reprova quebrando o worker de propósito.
- Pronto quando: verde com tudo certo e vermelho com o worker quebrado.
- Fontes: livro §16.3 (p. 322-325).

**F2.M12.P5 — Imagem no registry**
- Tarefa: `docker compose build` + `docker compose push` para o registry local com a tag da regra de F1.M7.P4. Isso prepara a Fase 3, que não faz build.
- Fontes: https://docs.docker.com/reference/cli/docker/compose/ [abre].

**Fim da Fase 2:** conferir os 5 critérios da seção 1.

---

## FASE 3 — Swarm multinó (3 managers, 2 workers)

O livro **não ensina Swarm** (a única menção é a p. 281). As fontes aqui são a doc oficial, a comunidade e, se o Lucas conseguir o PDF, o *Docker Deep Dive* 4ª ed. (cap. 11, Docker Swarm, e o capítulo de deploy de stack). Do livro valem as pontes conceituais: orquestrador (cap. 15, p. 281), rollout que não troca os velhos se os novos não sobem (p. 297-298), config imutável (p. 301), storage local × distribuído (p. 93-96).

### F3.M0 — Decisão do ambiente (conversa, não aula) — **decisão pendente do Lucas**

| Opção | RAM no notebook | Prós | Contras |
|---|---|---|---|
| A. 5 VMs locais: 3 managers de 1,5 GB + 2 workers de 1 GB | ~6,5 GB só para as VMs | Tudo offline, falha de rede e de disco fácil de provocar | Sobra ~4,5 GB para host, navegador e editor; apertado |
| B. 5 VMs locais enxutas: managers de 768 MB-1 GB (com drain, sem workload) + workers de 1 GB | ~4,3 a 5 GB | Cabe com folga | Postgres + api + traefik nos 2 workers; menos espaço para `start-first` |
| C. Rodízio local: manter só 3 VMs ligadas por experimento | ~3 a 4,5 GB | Leve | Experimentos de quorum com 5 nós precisam de todas ligadas |
| D. VMs na nuvem | ~0 no notebook | Rede real, IP público para testar firewall | Custo mensal (**não pesquisado nestes inventários**), cuidado com portas 2377/7946/4789 expostas |
| E. Play with Docker para ensaio | 0 | Ensaio de comandos sem VM | Sessões de 4 h, instável; não serve para o lab real |

- Estimativas de RAM vêm do inventário de docs; **o requisito mínimo de RAM por nó não foi verificado** (a confirmar na prática: medir com `free -m` e `docker stats` depois do primeiro deploy).
- Ferramentas de VM: Multipass https://canonical.com/multipass [URL corrigida] · Vagrant https://developer.hashicorp.com/vagrant [URL corrigida] + https://github.com/vagrant-libvirt/vagrant-libvirt [abre] · Play with Docker https://labs.play-with-docker.com/ [abre].
- **Pronto quando:** a opção escolhida e o orçamento de RAM estão no PROGRESS.md.

### F3.M1 — VMs e portas

**F3.M1.P1 — Criar as VMs**
- Tarefa: criar as VMs da opção escolhida (Ubuntu), com hostnames `mgr1..3`, `wrk1..2`, IP fixo na rede do laboratório; instalar Docker Engine.
- Pronto quando: `docker version` roda nas 5.
- Fontes: https://docs.docker.com/engine/install/ [abre] · https://docs.docker.com/engine/install/linux-postinstall/ [abre].
- Armadilha: VM clonada com o mesmo `machine-id` e hostname confunde o cluster.

**F3.M1.P2 — Portas do Swarm**
- Ideia [conferido]: 2377/tcp (gestão), 7946/tcp+udp (descoberta), 4789/udp (VXLAN, configurável) e protocolo IP 50 (ESP) para overlay criptografada. A 4789 nunca fora da rede confiável.
- Tarefa: liberar as portas no firewall das VMs só para a rede do laboratório; testar com `nc -zv` e `nc -zvu`.
- Pronto quando: as 4 aberturas estão testadas entre pares de VMs.
- Fontes: https://docs.docker.com/engine/swarm/swarm-tutorial/ [conferido].

**F3.M1.P3 — Contexts por SSH**
- Ideia: operar os nós do notebook sem expor a API do Docker em TCP.
- Tarefa: `docker context create mgr1 --docker host=ssh://<user>@mgr1`; `docker --context mgr1 info`.
- Pronto quando: os comandos rodam do notebook.
- Fontes: https://docs.docker.com/engine/manage-resources/contexts/ [abre] · livro §12.4 (p. 222-223).
- Armadilha: TCP 2375 sem TLS dá root a quem alcançar a porta (https://docs.docker.com/engine/security/protect-access/ [abre]).

### F3.M2 — init e join

**F3.M2.P1 — Conceitos mínimos**
- Ideia: nó (manager/worker), serviço (estado desejado), task (um container agendado), stack (vários serviços). O Swarm reconcilia o real com o desejado.
- Tarefa: ler a página de conceitos e explicar a diferença entre serviço e task com um exemplo do SwarmLab.
- Fontes: https://docs.docker.com/engine/swarm/key-concepts/ [abre] · https://docs.docker.com/engine/swarm/ [abre] · livro cap. 15 (p. 281).

**F3.M2.P2 — `swarm init`**
- Tarefa: no `mgr1`, `docker swarm init --advertise-addr <ip-do-mgr1>`.
- Pronto quando: `docker node ls` mostra um nó `Leader`.
- Checagem: o que dá errado sem `--advertise-addr` numa VM com duas interfaces?
- Fontes: https://docs.docker.com/engine/swarm/swarm-tutorial/create-swarm/ [abre] · https://docs.docker.com/reference/cli/docker/swarm/init/ [abre].
- Armadilha: o pool padrão de endereços pode colidir com a sua rede (`--default-addr-pool`).

**F3.M2.P3 — Join de managers e workers**
- Tarefa: `docker swarm join-token manager` e `worker`; entrar com `mgr2`, `mgr3`, `wrk1`, `wrk2`.
- Pronto quando: `docker node ls` mostra 1 `Leader`, 2 `Reachable` e 2 workers `Ready`.
- Fontes: https://docs.docker.com/engine/swarm/join-nodes/ [abre] · https://docs.docker.com/reference/cli/docker/swarm/join/ [abre].
- Armadilha: os tokens são segredos: nunca no git nem no PROGRESS.md.

**F3.M2.P4 — promote/demote**
- Tarefa: `docker node demote mgr3` e `promote` de volta; observar `MANAGER STATUS`.
- Pronto quando: você viu o nó perder e recuperar o papel.

### F3.M3 — Serviços

**F3.M3.P1 — Primeiro serviço**
- Tarefa: `docker service create --name whoami --replicas 3 -p 8080:80` de uma imagem simples; `docker service ps whoami`.
- Pronto quando: 3 tasks `Running` em nós diferentes.
- Fontes: https://docs.docker.com/engine/swarm/swarm-tutorial/deploy-service/ [abre] · https://docs.docker.com/reference/cli/docker/service/create/ [abre].

**F3.M3.P2 — Ciclo da task**
- Tarefa: `docker service ps --no-trunc`; desenhar os estados que a task atravessa.
- Fontes: https://docs.docker.com/engine/swarm/how-swarm-mode-works/services/ [abre].

**F3.M3.P3 — Scale e logs agregados**
- Tarefa: `docker service scale whoami=5`; `docker service logs whoami`.
- Pronto quando: os logs mostram linhas das 5 tasks.
- Fontes: https://docs.docker.com/engine/swarm/swarm-tutorial/scale-service/ [abre] · https://docs.docker.com/reference/cli/docker/service/logs/ [abre].

**F3.M3.P4 — Modo global e jobs**
- Ideia: `--mode global` põe uma task por nó; `replicated-job` roda até terminar (o migrator).
- Tarefa: um serviço global de exemplo; um `replicated-job` que imprime e sai.
- Pronto quando: o global tem 5 tasks; o job termina `Complete`.
- Fontes: https://docs.docker.com/engine/swarm/services/ [abre] · service create (acima).

**F3.M3.P5 — Autocura (fechando o experimento 1)**
- Tarefa: um serviço com healthcheck que passa a falhar; ver o Swarm substituir a task.
- **Experimento F3.E1 — unhealthy no Swarm.** Hipótese: diferente do Docker puro (experimento 1 da Fase 1), o Swarm mata e recria a task `unhealthy`. Registrar em `docs/experiments/F3-E1-unhealthy-swarm.md`.
- Fontes: livro p. 123-124 e figura 8.11 (p. 135-136).

### F3.M4 — Overlay, DNS e routing mesh

**F3.M4.P1 — Rede overlay**
- Tarefa: `docker network create -d overlay --attachable lab-ov`; um serviço nela e um container avulso também.
- Pronto quando: o avulso resolve o nome do serviço.
- Fontes: https://docs.docker.com/engine/network/drivers/overlay/ [URL corrigida; a de tutorial redireciona para cá] · https://docs.docker.com/engine/swarm/networking/ [abre].
- Armadilha: container avulso só entra em overlay `--attachable`.

**F3.M4.P2 — VIP × `tasks.`**
- Ideia: o nome do serviço resolve para um VIP (balanceado por IPVS); `tasks.<serviço>` resolve todas as tasks.
- Tarefa: `nslookup whoami` e `nslookup tasks.whoami`; escalar e repetir.
- Fontes: https://docs.docker.com/engine/swarm/networking/#configure-service-discovery [abre].
- **Experimento F3.E2 — VIP × tasks.** Registrar em `docs/experiments/F3-E2-vip-tasks.md`.
- Armadilha: o IPVS balanceia por conexão; pool de conexões persistentes fica preso a uma réplica.

**F3.M4.P3 — Routing mesh**
- Ideia: porta publicada em modo ingress responde em todos os nós, mesmo sem task ali.
- Tarefa: escalar `whoami` para 1 e fazer `curl` no IP de um nó sem a task.
- **Experimento F3.E3 — Routing mesh e IP do cliente.** Hipótese sobre o IP de origem que a app vê em `ingress` × `mode: host`. Registrar em `docs/experiments/F3-E3-routing-mesh.md`.
- Fontes: https://docs.docker.com/engine/swarm/ingress/ [abre] · comunidade: https://community.traefik.io/t/traefik2-docker-swarm-and-no-client-ip-on-running-services/7286.md [abre] · https://github.com/newsnowlabs/docker-ingress-routing-daemon [abre].

**F3.M4.P4 — Overlay criptografada**
- Tarefa: rede com `--opt encrypted`; `tcpdump -i any udp port 4789` com e sem.
- **Experimento F3.E4 — Overlay em claro × ESP.** Hipótese, comparar o tráfego, depois bloquear protocolo 50 e ver falhar. Registrar em `docs/experiments/F3-E4-overlay-encrypted.md`.
- Armadilha: firewall sem ESP faz a overlay criptografada falhar em silêncio.

**F3.M4.P5 — Firewall e MTU**
- **Experimento F3.E5 — Porta 7946 bloqueada.** Hipótese, bloquear num nó, observar descoberta/DNS falhando nele. Registrar em `docs/experiments/F3-E5-firewall-7946.md`. Comunidade: https://community.traefik.io/t/worker-service-wont-load-unless-ip-points-to-master/10791 [abre] · https://community.traefik.io/t/services-timeout-if-on-a-swarm-worker-node/19951 [abre].
- **Experimento F3.E6 — MTU.** Hipótese: com MTU de interface abaixo de 1500, ping passa e payload grande trava. Provocar baixando para 1400; corrigir com `com.docker.network.driver.mtu`. Registrar em `docs/experiments/F3-E6-mtu.md`. Fontes: https://github.com/moby/libnetwork/issues/2661 [abre] · https://forums.docker.com/t/tls-handshake-issues-in-docker-swarm-with-overlay-network/136065 [abre] · https://forums.docker.com/t/docker-swarm-ingress-network-is-not-forwarding-packets-to-the-containers/150908 [abre].

### F3.M5 — Registry acessível pelo cluster

**F3.M5.P1 — Imagem só local**
- **Experimento F3.E7 — Imagem que só existe no manager.** Hipótese: tasks agendadas em outros nós falham com "No such image". Provocar com um serviço de imagem construída só no `mgr1`. Registrar em `docs/experiments/F3-E7-imagem-local.md`.

**F3.M5.P2 — Registry no laboratório**
- Tarefa: um registry numa VM (ou serviço com placement fixo), de preferência com TLS; push da imagem do SwarmLab feito na Fase 2.
- Pronto quando: os 5 nós fazem `docker pull` da imagem.
- Fontes: livro §5.3 (p. 67-71; usa insecure, prefira TLS) · https://distribution.github.io/distribution/ [abre].
- Armadilha: registry sem TLS exige `insecure-registries` em **todos** os nós.

**F3.M5.P3 — Deploy por digest**
- Tarefa: entender `--resolve-image always|changed|never` e `--with-registry-auth` do `stack deploy`.
- Fontes: https://docs.docker.com/reference/cli/docker/stack/deploy/ [conferido].

### F3.M6 — `docker stack deploy` e o que muda do Compose

**F3.M6.P1 — Gerar o arquivo do stack**
- Ideia: `profiles`, `develop` e `include` não existem no schema do stack [conferido]; o loader do stack interpola com o **ambiente do shell**, e a verificação não achou leitura de `.env` (a confirmar na prática). Gere o arquivo final antes.
- Tarefa: `docker compose -f compose.yaml -f compose.swarm.yaml config > stack.yml` (o `stack.yml` gerado não vai para o git se tiver valor sensível).
- Pronto quando: o arquivo existe e você leu o que mudou.
- Fontes: https://github.com/docker/cli/blob/master/cli/command/stack/loader/loader.go [verificação] · https://docs.docker.com/engine/swarm/stack-deploy/ [abre].
- **Experimento F3.E8 — Stack e `.env`.** Hipótese: `docker stack deploy` não lê `.env`; uma `${VAR}` definida só lá chega vazia. Provocar e observar. Registrar em `docs/experiments/F3-E8-stack-env.md`.

**F3.M6.P2 — Primeiro deploy do SwarmLab**
- Tarefa: `docker stack deploy -c stack.yml swarmlab --detach=false 2>&1 | tee deploy.log`.
- Pronto quando: `docker stack services swarmlab` mostra as réplicas convergidas.
- Fontes: [conferido] stack deploy exige formato Compose 3.0+, avisa "Ignoring unsupported options", `--detach` é true por padrão.

**F3.M6.P3 — Ler os avisos contra a tabela**
- Tarefa: comparar cada linha "Ignoring unsupported options" do `deploy.log` com a tabela do Apêndice D; marcar o que você viu.
- **Experimento F3.E9 — Chaves ignoradas × proibidas.** Hipótese: `build` e `restart` geram aviso; `mem_limit` ou `extends` dão **erro**; `container_name` e `expose` só avisam como obsoletas. Provocar com um arquivo de teste que tem uma de cada. Registrar em `docs/experiments/F3-E9-stack-chaves.md`.
- Fontes: https://github.com/docker/cli/blob/master/cli/compose/types/types.go [conferido] · https://github.com/docker/cli/blob/master/cli/compose/schema/data/config_schema_v3.13.json [conferido].

**F3.M6.P4 — `depends_on` no Swarm**
- Ideia [conferido no schema, sem teste]: o stack só aceita a forma curta (lista); a forma longa com `condition:` **não passa no schema**; a forma curta é aceita, mas o Swarm não ordena a subida.
- **Experimento F3.E10 — `depends_on` no stack.** Hipótese: a forma longa dá erro de schema; a curta passa e a api sobe junto com o banco (sem ordem). Provocar e observar. Registrar em `docs/experiments/F3-E10-depends-on-stack.md`.
- Consequência: o retry da app (F2.M4.P5) e o migrator como `replicated-job` substituem a ordem.

**F3.M6.P5 — `compose.swarm.yaml`**
- Tarefa: escrever o override de Swarm: `deploy:` (replicas, resources, restart_policy, update_config), redes `overlay`, sem `build`, `restart`, `container_name`, `security_opt`, `depends_on` com condition.
- Pronto quando: um novo deploy sai sem nenhum aviso de chave ignorada.
- Fontes: https://docs.docker.com/reference/compose-file/deploy/ [abre].

### F3.M7 — Secrets e configs do cluster

**F3.M7.P1 — Secret de verdade**
- Ideia: no Swarm o secret fica cifrado no Raft e chega só aos nós com task que o usa, em tmpfs em `/run/secrets`.
- Tarefa: `printf %s "<senha>" | docker secret create db_password_v1 -` (cuidado com o histórico do shell; prefira ler de arquivo `chmod 600`); `external: true` no stack.
- Pronto quando: a api e o postgres sobem lendo o secret.
- Fontes: https://docs.docker.com/engine/swarm/secrets/ [abre] · livro p. 113 e §15.4 (p. 298-305).

**F3.M7.P2 — Rotação sem downtime**
- Tarefa: criar `db_password_v2`, trocar a senha no Postgres, `docker service update --secret-rm db_password_v1 --secret-add source=db_password_v2,target=db_password` na api.
- **Experimento F3.E11 — Rotação de secret.** Hipótese: as tasks são recriadas e `docker secret rm db_password_v1` em uso dá erro. Registrar em `docs/experiments/F3-E11-rotacao-secret.md`.

**F3.M7.P3 — Configs**
- Tarefa: a config do Traefik como `docker config` versionada (`traefik_v1`, `traefik_v2`).
- Fontes: https://docs.docker.com/engine/swarm/configs/ [abre] · livro p. 301 (config imutável → nova task).

### F3.M8 — Rolling update, rollback e healthcheck

**F3.M8.P1 — `update_config`**
- Ideia: `parallelism`, `delay`, `order: start-first|stop-first`, `failure_action: rollback`, `monitor`.
- Tarefa: configurar na api: `parallelism: 1`, `order: start-first`, `failure_action: rollback`, `monitor: 30s`.
- Fontes: https://docs.docker.com/reference/compose-file/deploy/#update_config [abre] · https://docs.docker.com/engine/swarm/swarm-tutorial/rolling-update/ [abre] · https://docs.docker.com/reference/cli/docker/service/update/ [abre].

**F3.M8.P2 — Update com carga**
- Tarefa: carga constante com hey/vegeta/k6 durante `service update --image` para uma versão nova.
- **Experimento F3.E12 — start-first × stop-first.** Hipótese sobre erros em cada modo. Medir erros reais. Registrar em `docs/experiments/F3-E12-update-order.md`.
- Fontes: https://github.com/rakyll/hey [abre] · https://github.com/tsenart/vegeta [abre] · https://github.com/grafana/k6 [abre].

**F3.M8.P3 — Rollback automático**
- **Experimento F3.E13 — Versão com `/health` quebrado.** Hipótese: com healthcheck e `failure_action: rollback`, o Swarm volta sozinho; sem healthcheck, a versão quebrada fica (task "saudável" assim que `running`). Observar `docker service ps` e `docker service inspect --format '{{json .UpdateStatus}}'`. Registrar em `docs/experiments/F3-E13-rollback.md`.
- Fontes: https://docs.docker.com/reference/compose-file/deploy/#rollback_config [abre] · https://docs.docker.com/reference/cli/docker/service/rollback/ [abre] · livro p. 297-298.
- Ressalva [conferido]: `healthcheck.start_interval` existe no schema v3.13; um bug fazia o Swarm não repassar o valor, corrigido numa 25.0.x (https://docs.docker.com/engine/release-notes/25.0/). Confira a versão do Engine das VMs.

**F3.M8.P4 — Rollback manual**
- Tarefa: `docker service rollback swarmlab_api` depois de um update bom.

### F3.M9 — Placement, drain e recursos

**F3.M9.P1 — Labels de nó e constraints**
- Tarefa: `docker node update --label-add db=true wrk1`; constraint `node.labels.db==true` no postgres.
- Fontes: https://docs.docker.com/engine/swarm/services/#control-service-placement [abre] · https://docs.docker.com/reference/compose-file/deploy/#placement [abre] · https://docs.docker.com/reference/cli/docker/node/update/ [abre].
- Armadilha: use `node.labels` (do operador), não `engine.labels` (o nó pode mudar).
- **Experimento F3.E14 — Constraint impossível.** Hipótese, `node.labels.gpu==true`, observar a task `pending` e a mensagem em `service ps --no-trunc`. Registrar em `docs/experiments/F3-E14-constraint.md`.

**F3.M9.P2 — Preferences e max por nó**
- Tarefa: espalhar a api com `placement.preferences.spread` e `max_replicas_per_node`.

**F3.M9.P3 — Drain**
- **Experimento F3.E15 — Drain e rebalanceamento.** Hipótese: no drain as tasks migram; ao voltar a `active`, o Swarm não rebalanceia até `service update --force`. Medir erros com carga. Registrar em `docs/experiments/F3-E15-drain.md`.
- Fontes: https://docs.docker.com/engine/swarm/swarm-tutorial/drain-node/ [abre] · https://docs.docker.com/engine/swarm/manage-nodes/ [abre].

**F3.M9.P4 — Managers sem workload**
- Tarefa: decidir (conversa) se os managers ficam em drain; aplicar.

**F3.M9.P5 — Reservas**
- **Experimento F3.E16 — Reservas excessivas.** Hipótese: reservando mais memória do que os nós têm, tasks ficam `pending` com "insufficient resources". Registrar em `docs/experiments/F3-E16-reservas.md`.
- Fontes: https://docs.docker.com/engine/swarm/services/#reserve-memory-or-cpus-for-a-service [abre] · https://docs.docker.com/reference/compose-file/deploy/#restart_policy [abre].

### F3.M10 — Volumes e perda de nó

**F3.M10.P1 — Volume é do nó**
- Ideia: volume/bind local fica no nó; o Swarm não replica dado.
- Tarefa: com o postgres preso a `wrk1` por constraint, confirmar onde estão os arquivos.
- Fontes: https://docs.docker.com/engine/swarm/services/#give-a-service-access-to-volumes-or-bind-mounts [abre] · livro §6.4-6.5 (p. 93-96).

**F3.M10.P2 — Perda do nó do banco**
- **Experimento F3.E17 — Nó do Postgres morre.** Hipótese: com constraint, a task fica `pending`; sem constraint, sobe em outro nó com dado **vazio**. Provocar desligando a VM. Medir o RPO contra o último backup externo da Fase 2 e o tempo para restaurar. Registrar em `docs/experiments/F3-E17-perda-no-banco.md`.

**F3.M10.P3 — Storage compartilhado (leitura)**
- Ideia: NFS/GlusterFS/CSI têm risco de fsync e corrupção com Postgres (comunidade, sem link verificado). Cluster volumes CSI existem no moby ("new feature"); o rótulo "experimental" **não foi verificado**.
- Fontes: https://github.com/moby/moby/blob/master/docs/cluster_volumes.md [abre] · livro p. 94 (Postgres em Azure Files falha em hard links).
- Tarefa: registrar no PROGRESS.md por que o SwarmLab fica com volume local + constraint + backup.

### F3.M11 — Quorum, Raft e recuperação

**F3.M11.P1 — A conta do quorum**
- Ideia: N managers toleram (N-1)/2 falhas; 3 toleram 1. Número ímpar, no máximo 7.
- Tarefa: responder: por que 2 managers são piores que 1?
- Fontes: https://docs.docker.com/engine/swarm/raft/ [abre] · https://docs.docker.com/engine/swarm/admin_guide/ [abre].

**F3.M11.P2 — Perda de 1 manager**
- **Experimento F3.E18 — 1 de 3 managers.** Hipótese, desligar o Leader, observar a eleição em `docker node ls` e o tempo. Registrar em `docs/experiments/F3-E18-perda-1-manager.md`.

**F3.M11.P3 — Backup do estado do Swarm**
- Tarefa: num manager, parar o Docker, copiar `/var/lib/docker/swarm` para fora da VM, subir de novo.
- Fontes: https://docs.docker.com/engine/swarm/admin_guide/#back-up-the-swarm [abre] · https://notes.kodekloud.com/docs/Docker-Certified-Associate-Exam-Course/Disaster-Recovery/Disaster-Recovery-Docker-Swarm/page [abre].
- Armadilha: o backup contém as chaves do Raft; com autolock precisa também da unlock key. Não restaurar o mesmo backup em vários nós.

**F3.M11.P4 — Perda de quorum e `--force-new-cluster`**
- **Experimento F3.E19 — 2 de 3 managers.** Hipótese: sem líder, comandos de gestão falham, mas as tasks que rodam continuam. Recuperar com `docker swarm init --force-new-cluster --advertise-addr <ip>` em **um** manager sobrevivente; readicionar os outros. Registrar em `docs/experiments/F3-E19-quorum.md`.
- Fontes: https://docs.docker.com/engine/swarm/admin_guide/#recover-from-disaster [abre] · https://docs.mirantis.com/mke/3.8/ops/disaster-recovery/disaster-recovery-swarm/recover-losing-quorum.html [abre] · https://infrahive-docs.pages.dev/runbooks/swarm-manager-quorum-loss-recovery/ [abre] · fóruns: https://forums.docker.com/t/how-do-i-recover-cluster-manager-automatically-after-losing-consensus/134203 [abre] · https://forums.docker.com/t/docker-19-03-12-the-swarm-does-not-have-a-leader-aferter-swarm-upgrade/98579 [abre].
- Armadilha (comunidade): depois da recuperação, overlay quebrada e manager tentando falar com nós antigos; os join tokens mudam.

**F3.M11.P5 — Partição de rede**
- **Experimento F3.E20 — Manager isolado.** Hipótese sobre eleição e tasks do lado isolado. Provocar com `iptables` só na VM. Registrar em `docs/experiments/F3-E20-particao.md`. Fonte: https://forums.docker.com/t/docker-swarm-possible-splitbrain-issue/119081 [abre].

**F3.M11.P6 — Perda de worker**
- Tarefa: desligar `wrk2` e medir o tempo até as tasks serem reagendadas (anotar no registro do F3.E17 ou em nota própria).

### F3.M12 — Segurança do cluster

**F3.M12.P1 — Rotação de token**
- Tarefa: `docker swarm join-token --rotate worker`; tentar join com o token antigo numa VM que saiu.
- Pronto quando: o token antigo é recusado.
- Fontes: https://docs.docker.com/engine/swarm/how-swarm-mode-works/pki/ [abre].

**F3.M12.P2 — Autolock**
- Tarefa: `docker swarm update --autolock=true`; guardar a unlock key fora do cluster e fora do git; reiniciar o Docker num manager; `docker swarm unlock`.
- Pronto quando: o manager não volta sem `unlock` e volta com ele.
- Fontes: https://docs.docker.com/engine/swarm/swarm_manager_locking/ [abre].

**F3.M12.P3 — CA e certificados**
- Tarefa: `docker swarm ca --rotate` e `--cert-expiry`; ler o que cada um faz antes de rodar.

**F3.M12.P4 — Socket e grupo docker**
- Tarefa: listar quem tem acesso ao socket em cada VM; anotar que o grupo `docker` equivale a root.
- Fontes: https://docs.docker.com/engine/security/ [abre] · https://docs.docker.com/engine/security/rootless/ [abre] · https://docs.docker.com/engine/security/userns-remap/ [abre].

### F3.M13 — Traefik v3 no Swarm

**F3.M13.P1 — Provider swarm**
- Ideia [conferido]: no v3 existe `providers.swarm`; `providers.docker.swarmMode` saiu.
- Tarefa: serviço `traefik` com `providers.swarm`, `exposedByDefault=false`, só nos managers, socket conforme a decisão de F2.M6.P2.
- Fontes: https://doc.traefik.io/traefik/reference/install-configuration/providers/swarm/ [URL corrigida] · versão fixada https://doc.traefik.io/traefik/v3.5/reference/install-configuration/providers/swarm/ [abre] · migração https://doc.traefik.io/traefik/migrate/v2-to-v3-details/ [conferido, seção SwarmMode].

**F3.M13.P2 — Labels em `deploy.labels`**
- Tarefa: mover os labels da api para `deploy.labels`, com `loadbalancer.server.port` explícito.
- **Experimento (dentro do passo)**: deixar um label no nível do container e ver que o provider não o enxerga (anotar no PROGRESS.md).

**F3.M13.P3 — `mode: host` + global**
- Tarefa: publicar 80/443 em `mode: host` com o Traefik `global` nos managers; repetir a medição de IP do F3.E3.
- Armadilha: `start-first` com porta em `mode: host` gera conflito de porta.

**F3.M13.P4 — Failover no rolling update**
- Tarefa: repetir o F3.E12 através do Traefik; ler sobre `loadbalancer.swarm=true` (usa o VIP) na doc v3.
- Fontes: https://community.traefik.io/t/seamless-failover-in-docker-swarm/6787 [abre].

### F3.M14 — Fechamento da Fase 3

**F3.M14.P1 — Reconstruir do zero**
- Tarefa: script/README curto que reconstrói o cluster e o stack a partir das VMs limpas (sem segredo no git).
- Pronto quando: rodou uma vez do zero.

**F3.M14.P2 — Revisão dos experimentos**
- Tarefa: conferir que os experimentos da Fase 3 têm hipótese, saída real e lição; atualizar o Apêndice E com o que foi confirmado.

**F3.M14.P3 — Ganchos da Fase 4**
- Tarefa: listar o que a Fase 4 vai observar (heartbeat do worker, `/ready`, eventos `docker events --filter type=service`, `metrics-addr` do daemon).
- Fontes: https://docs.docker.com/reference/cli/docker/system/events/ [abre] (a URL `container/events` está quebrada).

**Fim da Fase 3:** conferir os 6 critérios da seção 1.

---

## Apêndice A — Bibliografia

| Obra | Edição | Uso | Status |
|---|---|---|---|
| Elton Stoneman, *Learn Docker in a Month of Lunches* | 2ª ed., Manning, ©2025, ISBN 9781633438460 | Fases 1 e 2; pontes para a 3. **Não cobre Swarm.** Traefik v2. | PDF em mãos |
| Nigel Poulton, *Docker Deep Dive* | **4ª ed.** (jan/2025; O'Reilly id 9781837028351) tem o cap. 11, Docker Swarm, e capítulo de deploy de stack. **5ª ed.** (Packt, mai/2025, ISBN 9781806024025) tem Swarm "enxugado". | **Procurar o PDF da 4ª ed.** para a Fase 3. | Confirmado: https://www.oreilly.com/library/view/docker-deep-dive/9781837028351/chap13.xhtml · https://leanpub.com/dockerdeepdive · https://www.perlego.com/book/5522968/docker-deep-dive-zero-to-docker-in-a-single-book-pdf |
| Sean Kane & Karl Matthias, *Docker: Up & Running* | 3ª ed., O'Reilly, 2023, ISBN 9781098131821 | Operação em produção | Edição confirmada; **que cubra Swarm não foi confirmado** (só a 2ª ed. anunciava). https://www.oreilly.com/library/view/docker-up/9781098131814/preface01.html |
| Liz Rice, *Container Security* | 2ª ed. 2025 (segundo o inventário; não verificado) | Fase 1 (hardening) e Fase 3 (segurança) | A confirmar |
| Ian Miell & Aidan Hobson Sayers, *Docker in Practice* | 2ª ed., 2019 | Ideias; defasado (pré-Compose v2) | Não verificado |
| Itamar Turner-Trauring, *Python on Docker Production Handbook* | atualizado pelo autor (pago) | Fase 1 | https://pythonspeed.com/products/productionhandbook [abre] |
| Funky Penguin, *Geek Cookbook* | online | Fase 3 (Swarm + Traefik, parte em v2) | https://leanpub.com/read/geek-cookbook/leanpub-auto-traefik [abre]; fórum https://forum.funkypenguin.co.nz/t/traefik/1631 deu 502 na verificação |

Material online de apoio: container.training https://container.training/ [abre] e https://github.com/jpetazzo/container.training [abre] (trilha Swarm de 2017-2019) · Bret Fisher https://github.com/BretFisher/udemy-docker-mastery [abre], https://github.com/BretFisher/awesome-swarm [abre], https://github.com/BretFisher/dogvscat [abre] (antigo, usar como desenho) · https://github.com/docker/awesome-compose [abre] · https://github.com/dockersamples [abre] · https://github.com/nickjj/docker-flask-example [abre] · https://pythonspeed.com/docker/ [abre] · Julia Evans https://jvns.ca/blog/2016/10/10/what-even-is-a-container/ [abre] e https://wizardzines.com/zines/containers/ [abre] · palestra EuroPython 2020 https://ep2020.europython.eu/talks/CeKGczx-best-practices-for-production-ready-docker-packaging/ [abre].
Fontes de qualidade variável (só para confirmar, nunca primárias): oneuptime.com (ex.: https://oneuptime.com/blog/post/2026-01-25-docker-container-signal-handling/markdown, https://oneuptime.com/blog/post/2026-03-20-fix-swarm-mtu-issues-portainer-hetzner/view).
Não usar: o artigo SKIP LOCKED da 2ndQuadrant (sumiu) · `docker compose alpha viz` (não existe mais) · https://docs.docker.com/reference/cli/docker/container/events/ (404).
Não verificáveis por robô (abrir no navegador): https://stackoverflow.com/questions/31746182 · https://git.coopcloud.tech/coop-cloud/traefik/pulls/50 · página Packt do Deep Dive.

## Apêndice B — Ferramentas por fase

| Fase | Ferramenta | Link |
|---|---|---|
| 1 | hadolint | https://github.com/hadolint/hadolint |
| 1 | dive | https://github.com/wagoodman/dive |
| 1 | Trivy | https://github.com/aquasecurity/trivy |
| 1 | Docker Scout | https://docs.docker.com/scout/ |
| 1 | Grype (alternativa) | https://github.com/anchore/grype |
| 1-3 | lazydocker | https://github.com/jesseduffield/lazydocker |
| 1-2 | ctop (manutenção irregular) | https://github.com/bcicen/ctop |
| 2-3 | docker-socket-proxy | https://github.com/Tecnativa/docker-socket-proxy |
| 2-3 | Pumba (chaos em containers) | https://github.com/alexei-led/pumba |
| 2-3 | hey, vegeta, k6 (carga) | https://github.com/rakyll/hey · https://github.com/tsenart/vegeta · https://github.com/grafana/k6 |
| 3 | Multipass | https://canonical.com/multipass |
| 3 | Vagrant + libvirt | https://developer.hashicorp.com/vagrant · https://github.com/vagrant-libvirt/vagrant-libvirt |
| 3 | tc/netem, iptables, tcpdump, nc | ferramentas do Linux, nas VMs |
| 3 | docker-ingress-routing-daemon | https://github.com/newsnowlabs/docker-ingress-routing-daemon |
| 3 | Portainer CE / Swarmpit (opcional; não substitui a CLI) | https://github.com/portainer/portainer · https://github.com/swarmpit/swarmpit |

Todas as URLs acima abriram (HTTP 200) na verificação; o conteúdo não foi lido.

## Apêndice C — Glossário curto

- **Imagem / container:** receita imutável / processo rodando a partir dela.
- **Camada:** resultado de uma instrução do Dockerfile; cache por camada.
- **Digest:** hash `sha256:` do conteúdo; imutável. Tag é um apelido mutável.
- **PID 1:** o processo principal do container; recebe os sinais do `docker stop`.
- **Bind mount / volume / tmpfs:** diretório do host / área gerenciada pelo Docker / memória.
- **Bridge / overlay:** rede de um host / rede que atravessa os nós do Swarm (VXLAN).
- **Healthcheck:** comando que marca `healthy`/`unhealthy`. Só o Swarm age sobre isso.
- **Liveness / readiness:** "o processo está vivo" / "está pronto para receber tráfego" (`/health` × `/ready`).
- **Serviço / task / stack:** estado desejado / um container agendado / conjunto de serviços de um arquivo.
- **Manager / worker / Leader:** nó que guarda o estado (Raft) / nó que só roda tasks / manager que decide.
- **Raft / quorum:** algoritmo de consenso / maioria dos managers necessária para mudar o estado.
- **VIP / routing mesh:** IP virtual do serviço / porta publicada respondendo em todos os nós.
- **Drain:** nó que não recebe tasks.
- **RPO:** quanto dado se perde numa falha (tempo desde o último backup bom).
- **SKIP LOCKED:** cláusula do Postgres que pula linhas travadas por outra transação.

## Apêndice D — Compose × Swarm (`docker stack deploy`), verificado

Fonte [conferido]: https://github.com/docker/cli/blob/master/cli/compose/types/types.go e https://github.com/docker/cli/blob/master/cli/compose/schema/data/config_schema_v3.13.json. A página https://docs.docker.com/reference/compose-file/services/ **não** traz essa lista por chave (só avisa para `extends`).

| Categoria | Chaves | O que acontece |
|---|---|---|
| **Ignoradas com aviso "unsupported"** | `build`, `cgroupns_mode`, `cgroup_parent`, `devices`, `domainname`, `external_links`, `ipc`, `links`, `mac_address`, `network_mode`, `pid`, `privileged`, `restart`, `security_opt`, `shm_size`, `userns_mode` | Deploy segue, a chave não vale |
| **Obsoletas, só avisam** | `container_name`, `expose` | Deploy segue |
| **Proibidas (erro)** | `extends`, `volume_driver`, `volumes_from`, `cpu_quota`, `cpu_shares`, `cpuset`, `mem_limit`, `memswap_limit` | Deploy falha |
| **Não existem no schema v3** | `profiles`, `develop`, `include` | Gere o arquivo com `docker compose config` antes |
| **`depends_on`** | só a forma curta (lista) passa no schema; a forma com `condition:` não | Forma curta aceita, mas **o Swarm não ordena** (lido no schema; a confirmar na prática, F3.E10) |
| **Suportadas (que se achava que não)** | `cap_add`, `cap_drop`, `sysctls`, `tmpfs` | Funcionam |
| **No lugar de `restart`** | `deploy.restart_policy` | — |
| **Limites** | `deploy.resources` (no Swarm, `reservations` também afetam o agendamento) | — |
| **`.env`** | o loader interpola com o ambiente do shell; leitura de `.env` não encontrada; `env_file` por serviço continua aceito | A confirmar na prática (F3.E8) |
| **Secrets** | Compose: arquivo montado, sem cifra. Swarm: cifrado no Raft, entregue em tmpfs | — |
| **Portas** | Compose: só no host local. Swarm: ingress em todos os nós (ou `mode: host`) | — |
| **Redes** | Compose: `bridge`. Swarm: `overlay` | — |
| **Volumes** | Swarm cria o volume no nó onde a task cai | — |
| **`healthcheck.start_interval`** | no schema v3.13; bug de repasse corrigido numa 25.0.x | Confira a versão do Engine |

## Apêndice E — O que ficou "a confirmar na prática"

| Item | Onde vira experimento ou checagem |
|---|---|
| Requisito mínimo de RAM por nó do Swarm (as estimativas de 768 MB a 1,5 GB por VM são do inventário) | F3.M0 e medição com `free -m`/`docker stats` após o 1º deploy |
| `docker stack deploy` não lê `.env` | F3.E8 |
| `depends_on` curto aceito sem ordenar; longo recusado pelo schema | F3.E10 |
| Lista de chaves ignoradas/proibidas na versão do CLI instalada | F3.E9 |
| "Docker Scout substitui o `docker scan`" | Não usar como fato; F1.M8.P6 só compara contagens |
| "Docker Debug exige assinatura" | Não usado no plano |
| Cluster volumes CSI "experimental" | F3.M10.P3 (só leitura; o moby diz "new feature") |
| *Docker: Up & Running* 3ª ed. cobre Swarm | Folhear o sumário se conseguir o PDF |
| *Container Security* 2ª ed. (2025) | Confirmar edição antes de procurar |
| Limites do plano gratuito do Scout | F1.M8.P6 |
| Custo de VMs na nuvem (opção D) | Pesquisar se o Lucas escolher D |
| Conteúdo das páginas marcadas [abre] (só a existência foi verificada) | Abrir antes de cada passo |
| Tags exatas de `postgres:18.x`, `registry`, Traefik v3 | Conferir no Hub no dia de usar e fixar |
