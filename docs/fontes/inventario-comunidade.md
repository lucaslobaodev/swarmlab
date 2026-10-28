# Inventário de fontes complementares — SwarmLab (Fases 1–3)

Data da pesquisa: 2026-10-28. Fora do escopo: doc oficial do Docker e "Learn Docker in a Month of Lunches".

**Legenda de verificação:**
- **[V]**: a URL apareceu nos resultados de busca desta pesquisa (existe; o conteúdo foi resumido pelo buscador).
- **[NV]**: URL conhecida de memória, mas NÃO conferida nesta pesquisa. Confira antes de usar.

Nível: I = iniciante, M = intermediário, A = avançado.

---

## 1. Fontes por fase (em ordem de leitura)

### Fase 1: containerização (FastAPI + uv)

| # | Tópico | Fonte | Tipo | Por que vale | Nível |
|---|---|---|---|---|---|
| 1 | uv em Docker (oficial do uv) | https://docs.astral.sh/uv/guides/integration/docker/ **[NV]** | Guia oficial (Astral) | Ensina cache mount, `UV_COMPILE_BYTECODE`, `--no-install-project` em duas camadas, `uv sync --locked` e multi-stage. É a referência primária para a Fase 1. | I/M |
| 2 | uv em Docker para produção | https://hynek.me/articles/docker-uv/ **[V]** | Blog (Hynek Schlawack) | Mostra multi-stage, usuário não-root e por que não usar o Python gerenciado pelo uv em produção. O autor diz manter o post atualizado. Leia depois do guia oficial. | M |
| 3 | Sinais e PID 1 | https://hynek.me/articles/docker-signals/ **[V]** | Blog (Hynek) | Explica bem forma exec × shell, `exec` no entrypoint e quando usar tini. É mais antigo (pré-2022), mas o conteúdo não envelheceu: `docker run --init` e `init: true` no Compose cobrem o caso de tini. | M |
| 4 | Empacotamento Python em Docker | https://pythonspeed.com/docker/ **[NV]** (página de produtos verificada: https://www.pythonspeed.com/products/docker/ **[V]**) | Blog/série (Itamar Turner-Trauring) | Tem a série gratuita de artigos (imagem base, por que evitar Alpine, cache de build, healthcheck). A busca não trouxe os artigos individuais, então navegue pelo índice. | I/M |
| 5 | Palestra "best practices for production-ready Docker packaging" | https://ep2020.europython.eu/talks/CeKGczx-best-practices-for-production-ready-docker-packaging/ **[V]** | Palestra (Itamar, 2020) | Roteiro de processo, útil como checklist. É de 2020 e anterior ao uv. | I |
| 6 | Boas práticas Docker para Python | https://testdriven.io/blog/docker-best-practices/ **[V]** | Blog | Checklist prático (não-root, ordem de camadas, `.dockerignore`). | I |
| 7 | Multi-stage + uv e problemas de cache | https://devblogs.microsoft.com/ise/?p=16241 **[V]** (2025) | Blog técnico | Discute armadilhas de cache de camadas com uv em CI. | M |
| 8 | Python como PID 1 | https://pycon.de/archive/2026/talks/python-hates-being-pid-1-writing-container-aware-code-for-kubernetes/ **[V]** | Palestra 2026 | O exemplo é Kubernetes, mas o tema (SIGTERM, PID 1, desligamento gracioso) vale igual para Swarm. | M |
| 9 | Namespaces/cgroups por dentro | https://jvns.ca/blog/2016/10/10/what-even-is-a-container/ **[NV]** e o zine "How Containers Work" https://wizardzines.com/zines/containers/ **[NV]** | Blog/zine (Julia Evans) | Dá a intuição do que um container é de fato. É antigo, mas conceitual. | I |
| 10 | Scan e SBOM | https://github.com/aquasecurity/trivy **[NV]** | Ferramenta + docs | Mais detalhes na seção 4. | I |

### Fase 2: Compose (api, worker, postgres, migrator, Traefik)

| # | Tópico | Fonte | Tipo | Por que vale | Nível |
|---|---|---|---|---|---|
| 1 | Material de curso do Bret Fisher | https://github.com/BretFisher/udemy-docker-mastery **[NV]** | Repo (curso Docker Mastery) | Exercícios de Compose e Swarm, com healthchecks e secrets. | I/M |
| 2 | Exemplos de Compose para produção e dev | https://github.com/BretFisher/docker-mastery-for-nodejs **[NV]** | Repo | Os padrões de healthcheck, depends_on e dev/prod servem para Python, apesar do nome. | M |
| 3 | Blog do Nick Janetakis | https://nickjanetakis.com/blog/ **[NV]** | Blog | Muitos posts curtos sobre Compose em dev/prod, override files, `.env`, usuário não-root e UID/GID de volume. Ele mantém um exemplo Flask + Docker (https://github.com/nickjj/docker-flask-example **[NV]**) que é modelo de Dockerfile e Compose de produção em Python. | I/M |
| 4 | Exemplos oficiais da Docker | https://github.com/docker/awesome-compose **[NV]** e https://github.com/dockersamples **[NV]** | Repos | Stacks prontas (inclui FastAPI e Postgres) e o example-voting-app, que também serve à Fase 3. | I |
| 5 | Traefik v3 com o provider Docker | https://doc.traefik.io/traefik/providers/docker/ **[NV]** | Doc Traefik | Labels, `exposedByDefault=false`, redes. | M |
| 6 | Fila em Postgres com SKIP LOCKED | https://www.2ndquadrant.com/en/blog/what-is-select-skip-locked-for-in-postgresql-9-5/ **[NV]** | Blog (Craig Ringer) | Explicação canônica de `FOR UPDATE SKIP LOCKED` para filas. É de 2016, mas o comportamento não mudou. | M |
| 7 | Backup e restore de Postgres em containers | Página da imagem oficial https://hub.docker.com/_/postgres **[NV]** | Doc da imagem | Cobre `docker-entrypoint-initdb.d`, `POSTGRES_PASSWORD_FILE` (secrets) e `PGDATA`. | I |

### Fase 3: Swarm multinó (3 managers + 2 workers)

| # | Tópico | Fonte | Tipo | Por que vale | Nível |
|---|---|---|---|---|---|
| 1 | Workshop completo de orquestração | https://container.training/ **[NV]** (repo https://github.com/jpetazzo/container.training **[NV]**) | Slides/labs (Jérôme Petazzoni) | O material de "Docker Swarm / orchestration workshop" ainda existe nos arquivos. É o melhor roteiro prático de Swarm (Raft, overlay, rolling update, secrets). A trilha de Swarm é de 2017–2019 e o foco atual do site é Kubernetes, mas os comandos de Swarm praticamente não mudaram. | M/A |
| 2 | Stack de referência para Swarm | Fork de BretFisher/dogvscat (repo original https://github.com/BretFisher/dogvscat **[NV]**; a existência foi inferida de forks/Docker Hub) | Repo | Cluster Swarm com Traefik, monitoramento e backups. É antigo (cerca de 2019, Traefik v1/v2), então use como desenho e não como YAML. | M |
| 3 | Traefik v3 provider Swarm | https://doc.traefik.io/reference/install-configuration/providers/swarm **[V]**; versão fixada: https://doc.traefik.io/traefik/v3.5/reference/install-configuration/providers/swarm/ **[V]** | Doc oficial Traefik | Em v3, o Swarm é um provider separado (`providers.swarm`). Labels ficam em `deploy.labels` e a porta do serviço é obrigatória (`loadbalancer.server.port`). Trata também de `useBindPortIP`. | M |
| 4 | Recuperação de quorum | https://docs.mirantis.com/mke/3.8/ops/disaster-recovery/disaster-recovery-swarm/recover-losing-quorum.html **[V]** | Doc Mirantis (dona do Swarm "enterprise") | Passo a passo de `--force-new-cluster` com demote e remove dos nós perdidos. | A |
| 5 | Runbook de quorum (comunidade) | https://infrahive-docs.pages.dev/runbooks/swarm-manager-quorum-loss-recovery/ **[V]** | Runbook | Chama atenção para "rodar em um único nó" e para a rotação dos join tokens. | A |
| 6 | Notas de DR de Swarm (DCA) | https://notes.kodekloud.com/docs/Docker-Certified-Associate-Exam-Course/Disaster-Recovery/Disaster-Recovery-Docker-Swarm/page **[V]** | Notas de curso | Resumo de backup de `/var/lib/docker/swarm` e restore. | M |
| 7 | IP real do cliente no Swarm | https://github.com/newsnowlabs/docker-ingress-routing-daemon **[V]** (releases verificadas) | Repo | A solução da comunidade para o routing mesh que esconde o IP do cliente (SNAT). | A |
| 8 | MTU em overlay | https://www.github.com/moby/libnetwork/issues/2661 **[V]** | Issue | Issue de referência; aponta moby/moby #41775, #43551, #43359 e #16841. | A |
| 9 | Play with Docker | https://labs.play-with-docker.com/ **[NV]** | Lab no navegador | Monta Swarm de 5 nós sem VM, bom para ensaiar antes do lab real. Sessões de 4 h; o serviço às vezes fica instável. | I |
| 10 | Lista curada | https://github.com/BretFisher/awesome-swarm **[NV]** | Lista awesome | Ponto de partida para ferramentas de Swarm (UI, backup, autoscale). | I/M |
| 11 | Geek Cookbook (Swarm + Traefik) | https://leanpub.com/read/geek-cookbook/leanpub-auto-traefik **[V]**; fórum https://forum.funkypenguin.co.nz/t/traefik/1631 **[V]** | Livro/receitas (Funky Penguin) | Receitas de Swarm self-hosted com Traefik e storage compartilhado. Parte do conteúdo é Traefik v2. | M |

---

## 2. Armadilhas reais (fóruns, issues)

### Fase 1
1. **App não recebe SIGTERM e o container leva 10 s para parar.**
   - Sintoma: `docker stop` demora cerca de 10 s e termina com exit code 137.
   - Causa: CMD em forma shell (o `sh` vira PID 1 e não repassa o sinal), ou script de entrypoint sem `exec`. Além disso, o kernel não aplica os handlers padrão ao PID 1.
   - Solução: CMD/ENTRYPOINT em forma exec, `exec "$@"` no entrypoint, `--init`/`init: true` (tini) se houver processos filhos, e handler de SIGTERM no app. Para uvicorn, forma exec já resolve o desligamento gracioso.
   - Links: https://hynek.me/articles/docker-signals/ [V]; https://oneuptime.com/blog/post/2026-01-25-docker-container-signal-handling/markdown [V]
2. **`uv run` no CMD.**
   - Sintoma: sinais passam por um processo intermediário, e o startup fica lento porque o uv sincroniza o ambiente na subida.
   - Solução: colocar `/app/.venv/bin` no PATH e chamar `uvicorn` direto, ou `uv run --no-sync`. O assunto aparece no guia do uv e em issues do astral-sh/uv. Issue específica [NV]: procure "uv run signal" em https://github.com/astral-sh/uv/issues.
3. **Alpine deixa o build de Python muito mais lento.**
   - Causa: wheels para musl são escassos, então muita dependência compila na hora.
   - Solução: usar `python:3.x-slim` (Debian).
   - Link: discussão citada em https://testdriven.io/blog/docker-best-practices/ [V] (o artigo original é do pythonspeed, "Using Alpine can make Python Docker builds 50× slower" [NV]).
4. **Volume com dono root e app não-root.**
   - Sintoma: `PermissionError` ao gravar em bind-mount.
   - Causa: o UID do container difere do dono no host.
   - Solução: fixar UID/GID no `useradd` (ex.: 1000 ou 10001), dar `chown` na imagem para volumes nomeados (o volume nomeado vazio herda o dono do diretório da imagem), e nunca usar `chmod 777`.
   - Fonte: posts de Nick Janetakis sobre UID/GID [NV].

### Fase 2
1. **`depends_on` não espera prontidão.**
   - Sintoma: a api cai com "connection refused" para o Postgres na primeira subida.
   - Solução: `depends_on: {db: {condition: service_healthy}}` com healthcheck `pg_isready`. Para o migrator, use `condition: service_completed_successfully`.
   - Observação: esse recurso existe no Compose v2 e NÃO funciona em `docker stack deploy` (Swarm ignora `depends_on`). Na Fase 3, o app precisa de retry próprio.
   - Pergunta canônica no Stack Overflow: "Docker Compose wait for container X before starting Y" [NV], https://stackoverflow.com/questions/31746182 [NV].
2. **`pg_isready` verde antes do init terminar.**
   - Causa: na primeira subida, o entrypoint do postgres reinicia o servidor depois de rodar os scripts de init.
   - Solução: healthcheck com `-U` e `-d` corretos e `start_period`, ou um healthcheck que faça uma query real.
3. **Rede `internal: true` corta a saída do Traefik ou o ACME.**
   - Solução: o proxy fica em duas redes (pública e interna), e só o banco fica isolado.
4. **Healthcheck do Docker diferente de restart.**
   - No Compose puro, container "unhealthy" NÃO é reiniciado (só o Swarm reage a unhealthy). Alternativas no Compose: `autoheal` ou deixar o processo morrer.

### Fase 3
1. **Routing mesh esconde o IP do cliente.**
   - Sintoma: o Traefik e o app veem um IP 10.0.0.x da ingress.
   - Causa: SNAT da ingress.
   - Soluções:
     - Publicar a porta do Traefik com `mode: host`. Custo: um container por nó naquela porta e sem roteamento entre nós, então rode o Traefik em `global` nos managers ou atrás de um LB/DNS.
     - Usar docker-ingress-routing-daemon.
     - Usar LB externo com PROXY protocol.
   - Links: https://community.traefik.io/t/traefik2-docker-swarm-and-no-client-ip-on-running-services/7286.md [V]; https://github.com/newsnowlabs/docker-ingress-routing-daemon [V]
2. **MTU de overlay maior que o caminho real (VPN, nuvem, VM aninhada).**
   - Sintoma: ping funciona, mas TLS, HTTP grande ou o Postgres travam e dão timeout intermitente.
   - Causa: overhead VXLAN de 50 bytes com MTU de interface abaixo de 1500.
   - Solução: `--opt com.docker.network.driver.mtu=1400` (ou interface − 50) na overlay. Se preciso, recrie a `ingress` com MTU menor. O MTU do daemon não se propaga para overlays.
   - Links: https://www.github.com/moby/libnetwork/issues/2661 [V]; https://forums.docker.com/t/tls-handshake-issues-in-docker-swarm-with-overlay-network/136065 [V]; https://forums.docker.com/t/docker-swarm-ingress-network-is-not-forwarding-packets-to-the-containers/150908 [V]; https://oneuptime.com/blog/post/2026-03-20-fix-swarm-mtu-issues-portainer-hetzner/view [V]
3. **Serviço só responde se o DNS aponta para o manager, ou dá timeout em worker.**
   - Causa comum: portas do Swarm bloqueadas no firewall entre VMs (2377/tcp, 7946/tcp+udp, 4789/udp), ou checksum offload de VXLAN em algumas NICs virtuais.
   - Links: https://community.traefik.io/t/worker-service-wont-load-unless-ip-points-to-master/10791 [V]; https://community.traefik.io/t/services-timeout-if-on-a-swarm-worker-node/19951 [V]
4. **Failover não é transparente com o Traefik.**
   - Causa: o Traefik fala com IPs de task, não com o VIP, então há janela de erro no rolling update.
   - Solução: healthcheck e `update_config.order: start-first`, ou `loadbalancer.swarm=true` (usa o VIP) conforme a doc v3.
   - Link: https://community.traefik.io/t/seamless-failover-in-docker-swarm/6787 [V]
5. **Perda de quorum.**
   - Sintoma: com 2 de 3 managers fora, "The swarm does not have a leader". Serviços que já rodam continuam, mas nada pode ser alterado.
   - Solução: `docker swarm init --force-new-cluster --advertise-addr <ip>` em UM único manager sobrevivente, depois readicionar managers. Os join tokens rotacionam.
   - Relatos pós-recuperação: overlay quebrada e manager "preso" tentando falar com nós antigos.
   - Links: https://forums.docker.com/t/how-do-i-recover-cluster-manager-automatically-after-losing-consensus/134203 [V]; https://forums.docker.com/t/docker-19-03-12-the-swarm-does-not-have-a-leader-aferter-swarm-upgrade/98579 [V]; https://forums.docker.com/t/docker-swarm-possible-splitbrain-issue/119081 [V]
6. **Postgres em Swarm e perda de nó.**
   - Volume local não acompanha a task. Se o nó morrer, o Swarm reagenda o Postgres em outro nó com volume VAZIO, ou fica pendente por constraint.
   - Solução de laboratório: placement constraint por label de nó, `replicas: 1`, backup externo, e aceitar downtime. Alternativas (NFS, GlusterFS, plugins CSI de Swarm em Docker 23+) têm riscos de fsync e corrupção com Postgres.
   - Fonte: discussões em r/docker e r/selfhosted [NV]. Não houve link específico verificado.
7. **Secrets no Swarm são imutáveis.**
   - Não se edita um secret. Para trocar: criar `db_password_v2`, fazer `service update --secret-rm/--secret-add`, depois remover o antigo. É o mesmo padrão de rotação que cai bem no lab.
8. **IPv6 com Traefik em `mode: host`.**
   - Criar `docker_gwbridge` com IPv6 antes do `swarm init`.
   - Link: https://leanpub.com/read/geek-cookbook/leanpub-auto-traefik [V]

---

## 3. Livros complementares

| Livro | Autor/ano | Atual? | Avaliação | Capítulos × fase |
|---|---|---|---|---|
| Docker Deep Dive (edição 2025 / 4ª ed. Packt) | Nigel Poulton, jan/2025. Packt: https://www.packtpub.com/en-id/product/docker-deep-dive-9781837028344 [V]; O'Reilly: https://www.oreilly.com/library/view/-/9781837028351/ [V] | Sim | O melhor complemento: curto, atualizado e um dos poucos livros recentes que ainda cobrem Swarm a fundo. Inclui Docker Scout, `docker init`, Compose e Wasm. | Imagens/containerizar app → F1; Compose, volumes e networking → F2; Swarm, overlay, deploy de stack e segurança (secrets, mTLS, Scout) → F3 |
| Docker: Up & Running, 3ª ed. | Sean Kane & Karl Matthias, O'Reilly, 2023 [NV] | Sim | Visão de operação em produção. A parte de orquestração cobre Swarm brevemente e foca em K8s. | Build/imagens → F1; Compose → F2; cap. de orquestração (só a parte Swarm) → F3 |
| Container Security, 2ª ed. | Liz Rice, O'Reilly, 2ª ed. 2025 [NV]; 1ª ed. 2020 | Sim | Namespaces, cgroups, capabilities, rootless, scanning. Base conceitual para "não-root" e hardening. | F1 (não-root, scan, imagem mínima); F3 (segurança do cluster) |
| Docker in Practice, 2ª ed. | Ian Miell & Aidan Hobson Sayers, Manning, 2019 [NV] | Parcial | Formato de receitas, bom para ideias. Swarm e Compose estão defasados (pré-BuildKit, pré-Compose v2). | Leitura seletiva |
| Python on Docker Production Handbook | Itamar Turner-Trauring (pythonspeed), https://pythonspeed.com/products/productionhandbook [V] | Atualizado pelo autor | Pago. Checklist com mais de 70 práticas para Python em Docker. | F1 |
| The Docker Book / Docker Mastery (curso Udemy) | Bret Fisher [NV] | Curso atualizado | Curso, não livro. Tem as seções de Swarm mais didáticas do mercado. | F2, F3 |

---

## 4. Ferramentas para o laboratório

| Ferramenta | Link | Para quê | Fase |
|---|---|---|---|
| hadolint | https://github.com/hadolint/hadolint [NV] | Lint de Dockerfile no gate | 1 |
| dive | https://github.com/wagoodman/dive [NV] | Inspecionar camadas e desperdício | 1 |
| Trivy | https://github.com/aquasecurity/trivy [NV] | Scan de CVE, segredos e misconfig, além de SBOM | 1 (e CI) |
| Docker Scout | CLI `docker scout` (coberto pelo livro do Poulton) | Scan e recomendação de base image | 1 |
| Grype/Syft | https://github.com/anchore/grype [NV] | Alternativa a Trivy e geração de SBOM | 1 |
| lazydocker | https://github.com/jesseduffield/lazydocker [NV] | TUI para containers, logs e stats | 1–3 |
| ctop | https://github.com/bcicen/ctop [NV] | "top" de containers. Manutenção irregular; prefira lazydocker | 1–2 |
| Multipass | https://multipass.run [NV] | 5 VMs Ubuntu rápidas com cloud-init | 3 |
| Vagrant + libvirt | https://www.vagrantup.com [NV]; https://github.com/vagrant-libvirt/vagrant-libvirt [NV] | VMs declarativas e reprodutíveis | 3 |
| Pumba | https://github.com/alexei-led/pumba [V] (via mirrors e secundárias; imagem ghcr.io/alexei-led/pumba) | Chaos: kill/pause/stop, netem (latência, perda), stress. Versão 1.x de 2026, suporta containerd | 2–3 |
| tc/netem + iptables nas VMs | (ferramentas do Linux) | Partição de rede entre nós (split-brain, quorum) | 3 |
| docker-ingress-routing-daemon | https://github.com/newsnowlabs/docker-ingress-routing-daemon [V] | IP real do cliente com routing mesh | 3 |
| k6 | https://github.com/grafana/k6 [NV] | Carga com cenários e thresholds (prova de "zero erro no rolling update") | 2–3 |
| hey | https://github.com/rakyll/hey [NV] | Carga simples via CLI | 2–3 |
| vegeta | https://github.com/tsenart/vegeta [NV] | Taxa constante; ótimo para medir erros durante falhas | 3 |
| Portainer CE / Swarmpit | https://github.com/portainer/portainer [NV]; https://github.com/swarmpit/swarmpit [NV] | UI de cluster. Opcional, mas não substitui CLI | 3 |
| docker-socket-proxy | https://github.com/Tecnativa/docker-socket-proxy [NV] | Não expor o socket inteiro ao Traefik | 2–3 |

---

## 5. Ideias de experimentos (da comunidade) para o SwarmLab

1. **Sinais (F1):** rodar com CMD em forma shell e em forma exec, medir o tempo de `docker stop` e o exit code (137 contra 0), e conferir nos logs do uvicorn o "Shutting down" gracioso.
2. **Tamanho e camadas (F1):** comparar slim × alpine × multi-stage com uv no `dive`. Mexer só no código e medir o rebuild (cache das dependências).
3. **Prontidão (F2):** remover o `condition: service_healthy` e ver a api cair. Depois, rodar o mesmo no `docker stack deploy` e mostrar que o Swarm ignora `depends_on`.
4. **Worker SKIP LOCKED (F2/F3):** escalar o worker para N réplicas, enfileirar 10 mil jobs e provar zero duplicidade (constraint única na tabela de resultado). Matar workers com pumba no meio.
5. **Restore testado (F2):** `pg_dump` para fora do host → `docker compose down -v` em ambiente de teste → restore → checagem de contagem. Lembre do inegociável: nunca `volume prune`.
6. **Rolling update sem erro (F3):** k6/vegeta em taxa constante durante `service update --image`, comparando `order: stop-first` × `start-first` e com e sem healthcheck. Depois forçar imagem quebrada e ver o rollback automático com `failure_action: rollback`. Inspirado nos labs de container.training e de Bret Fisher.
7. **Quorum (F3):**
   - Derrubar 1 manager: segue funcionando.
   - Derrubar 2 managers: sem líder, nada é alterável, mas os serviços continuam.
   - Recuperar com `--force-new-cluster`, depois restaurar backup de `/var/lib/docker/swarm` em um cluster novo.
8. **Partição de rede (F3):** isolar um manager com iptables e observar a eleição Raft e o que acontece com as tasks do lado isolado.
9. **Perda do nó do Postgres (F3):** desligar a VM que hospeda o banco, observar o reagendamento (ou o pending por constraint) e recuperar do backup externo.
10. **MTU (F3):** baixar o MTU de uma interface de VM (ex.: 1400) e reproduzir o timeout em payload grande. Corrigir com `com.docker.network.driver.mtu`.
11. **IP do cliente (F3):** registrar `X-Forwarded-For`/IP remoto com Traefik publicado em `ingress` × `host`.
12. **DNS em overlay (F3):** `nslookup tasks.api` × `api` (VIP) e `endpoint_mode: dnsrr`. Veja https://git.coopcloud.tech/coop-cloud/traefik/pulls/50 [V], uma discussão real de troca vip→dnsrr no Traefik.
13. **Rotação de secret (F3):** trocar a senha do Postgres via secret versionado sem downtime perceptível.
14. **Drain e manutenção (F3):** `node update --availability drain` em um worker durante carga, medindo os erros.

---

### Lacunas e cuidados desta pesquisa
- Muitas URLs canônicas (uv docs, pythonspeed, container.training, awesome-swarm, ferramentas) estão marcadas [NV]: são conhecidas, mas não foram abertas aqui. Confira antes de citar no plano.
- Material de Swarm da comunidade é majoritariamente de 2017–2021. Os comandos e conceitos (Raft, overlay, mesh) mudaram pouco, mas exemplos de Traefik anteriores à v3 precisam de tradução: provider `swarm` separado, labels em `deploy.labels`, sintaxe de regras v3.
- Sites como oneuptime.com são conteúdo de 2026 de qualidade variável (aparentam ser gerados em massa). Use só como confirmação, nunca como fonte primária.
