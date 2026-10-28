# Verificação dos inventários de Docker (2026-10-28)

Método: as 237 URLs únicas foram abertas por HTTP (curl, seguindo redirect, User-Agent de navegador). "OK" na tabela 1 significa que a página **existe** (HTTP 200 sem redirect). O **conteúdo** só foi lido nas páginas da tabela 2 e nas linhas marcadas como "conteúdo conferido". Não conferi o conteúdo das demais páginas que responderam 200, nem as afirmações de versão do inventario-livro.md que ficam fora da tabela 2.

## 1. URLs

### 1a. Problemas encontrados
| Arquivo | URL citada | Status | URL correta / observação |
|---|---|---|---|
| docs | https://docs.docker.com/reference/cli/docker/container/events/ | QUEBRADA (404) | Use https://docs.docker.com/reference/cli/docker/system/events/ (que já está citada). |
| docs | https://docs.docker.com/reference/cli/docker/compose/alpha/viz/ (se citada; o texto fala em `alpha/viz` (*)) | QUEBRADA (404) | Não achei `alpha viz` no índice atual do `docker compose`. Retire o item. |
| docs | https://docs.docker.com/engine/network/tutorials/overlay/ | REDIRECIONA | https://docs.docker.com/engine/network/drivers/overlay/ |
| docs | https://docs.docker.com/engine/release-notes/ | REDIRECIONA | https://docs.docker.com/engine/release-notes/29/ |
| docs | https://docs.docker.com/engine/swarm/ (citada como fonte de "cluster volumes CSI") | CONTEÚDO DIFERENTE | A página não fala em CSI nem em cluster volumes. A fonte é https://github.com/moby/moby/blob/master/docs/cluster_volumes.md (existe e trata de CSI, mas não traz a palavra "experimental"). |
| docs | https://docs.docker.com/reference/compose-file/services/ ("cada chave indica se é ignorada no Swarm") | CONTEÚDO DIFERENTE | A página só avisa isso para `extends`. A lista real está no código do CLI (tabela 2). |
| docs | https://docs.docker.com/reference/cli/docker/debug/ ("exige assinatura") | CONTEÚDO DIFERENTE / não confirmado | A página não menciona assinatura nem plano. |
| comunidade/docs | https://doc.traefik.io/reference/install-configuration/providers/swarm | REDIRECIONA | https://doc.traefik.io/traefik/reference/install-configuration/providers/swarm/ |
| comunidade | https://www.2ndquadrant.com/en/blog/what-is-select-skip-locked-for-in-postgresql-9-5/ | QUEBRADA de fato | Redireciona para a home da enterprisedb.com. O artigo sumiu; busque um equivalente no blog da EDB. |
| comunidade | https://forum.funkypenguin.co.nz/t/traefik/1631 | QUEBRADA (502 na hora do teste) | Tente de novo mais tarde; pode ter sido instabilidade. |
| comunidade | https://git.coopcloud.tech/coop-cloud/traefik/pulls/50 | NÃO VERIFICÁVEL | Fica atrás de um desafio anti-bot (Anubis). |
| comunidade | https://stackoverflow.com/questions/31746182 | NÃO VERIFICÁVEL (403 para robô) | Provavelmente existe; abra no navegador. |
| comunidade | https://www.oreilly.com/library/view/-/9781837028351/ | 403 para robô | Uma busca confirma que é o Docker Deep Dive, 4ª ed. (jan/2025). |
| comunidade | https://www.packtpub.com/en-id/product/docker-deep-dive-9781837028344 | 403 para robô | Não confirmei. |
| comunidade | https://devblogs.microsoft.com/ise/?p=16241 | REDIRECIONA | https://devblogs.microsoft.com/ise/dockerizing-uv/ |
| comunidade | https://multipass.run | REDIRECIONA | https://canonical.com/multipass |
| comunidade | https://www.vagrantup.com | REDIRECIONA | https://developer.hashicorp.com/vagrant |
| comunidade | https://www.pythonspeed.com/products/docker/ · https://nickjanetakis.com/blog/ · https://www.github.com/moby/libnetwork/issues/2661 | REDIRECIONA (só muda a forma da URL) | Inofensivo. |

### 1b. Demais URLs: HTTP 200 sem redirect (a página existe; o conteúdo não foi lido, salvo indicação na tabela 2)
Lista completa no formato arquivo|URL em `map.txt`, e o status bruto de cada uma em `url-status.txt`, ambos no mesmo scratchpad.

## 2. Fatos técnicos
| Afirmação | Arquivo | Veredito | Valor correto | Prova |
|---|---|---|---|---|
| O que `stack deploy` ignora | docs §stack | CORRIGIDO | O CLI tem três listas. **Ignoradas com aviso "unsupported"**: build, cgroupns_mode, cgroup_parent, devices, domainname, external_links, ipc, links, mac_address, network_mode, pid, privileged, restart, security_opt, shm_size, userns_mode. **Obsoletas, só avisam**: container_name, expose. **Proibidas (dão erro)**: extends, volume_driver, volumes_from, cpu_quota, cpu_shares, cpuset, mem_limit, memswap_limit. | https://github.com/docker/cli/blob/master/cli/compose/types/types.go |
| `cap_add`/`cap_drop` não suportados ou "só em versões recentes" | docs | CORRIGIDO | São suportados: existem no tipo `ServiceConfig` e no schema v3. | mesmo types.go (campo CapAdd) e https://github.com/docker/cli/blob/master/cli/compose/schema/data/config_schema_v3.13.json |
| `sysctls`, `tmpfs` ignorados (*) | docs | CORRIGIDO | Estão no tipo e no schema e não aparecem na lista unsupported, ou seja, são suportados. | types.go |
| `healthcheck.start_interval` no Swarm | docs | CONFIRMADO, com ressalva | Está no schema v3.13. Um bug fazia o Swarm não repassar o valor ao container; a correção (moby#47163) saiu numa versão 25.0.x. | https://docs.docker.com/engine/release-notes/25.0/ |
| `depends_on` no stack | docs/livro | CORRIGIDO / refinado | O schema v3 só aceita a forma curta (lista). A forma longa com `condition:` (`service_healthy`, `service_completed_successfully`) não passa no schema do stack deploy. A forma curta é aceita, mas o Swarm não ordena a subida. Lido no schema, sem teste prático. | config_schema_v3.13.json (`depends_on: list_of_strings`) |
| `profiles`, `develop`, `include` no stack | docs | CONFIRMADO (não suportados) | Não existem no schema v3 do CLI. Gere o arquivo com `docker compose config` antes. | config_schema_v3.13.json |
| `stack deploy` não lê `.env` | docs | CONFIRMADO em parte | O loader do stack interpola com o ambiente do shell. Não achei leitura de `.env` no loader. `env_file` por serviço continua aceito no schema. A doc da página não trata do assunto. Não testei. | https://github.com/docker/cli/blob/master/cli/command/stack/loader/loader.go |
| `stack deploy` exige Compose 3.0+ e avisa "Ignoring unsupported options" | docs | CONFIRMADO | — | https://docs.docker.com/reference/cli/docker/stack/deploy/ |
| containerd image store é o padrão no Engine 29 em instalação nova | docs | CONFIRMADO | 29.0+ em instalações novas. Quem atualizou continua no armazenamento antigo. | https://docs.docker.com/engine/storage/containerd/ |
| PGDATA mudou no Postgres 18+ | docs | CONFIRMADO, com detalhe | No 18+, `PGDATA=/var/lib/postgresql/18/docker` e `VOLUME /var/lib/postgresql`. Monte o volume em **/var/lib/postgresql**, não em `/data`. A frase do inventário, "montar /var/lib/postgresql/data", vale **só até a 17**. | https://github.com/docker-library/docs/blob/master/postgres/content.md (PR docker-library/postgres#1259) |
| `HEALTHCHECK --start-interval` exige Engine 25+ (padrão 5s) | docs | CONFIRMADO | Engine 25.0+ | https://docs.docker.com/reference/dockerfile/#healthcheck |
| Compose `start_interval` | docs | CONFIRMADO | Compose 2.20.2+ | https://docs.docker.com/reference/compose-file/services/ |
| `depends_on.condition: service_completed_successfully` | docs | CONFIRMADO (no Compose) | Existe, ao lado de `service_healthy` e `required`. | services/ |
| `restart` no Compose / no Swarm | docs | CONFIRMADO | O Compose usa `restart`. O stack ignora essa chave (lista unsupported); use `deploy.restart_policy`. | types.go |
| `docker compose up --exit-code-from` (*) e `--wait` | docs | CONFIRMADO | `--exit-code-from` implica `--abort-on-container-exit`. | https://docs.docker.com/reference/cli/docker/compose/up/ |
| `develop.watch` | docs | CONFIRMADO | Compose 2.22.0+ | https://docs.docker.com/reference/compose-file/develop/ |
| `include:` | docs | CONFIRMADO | Compose 2.20.0+ | https://docs.docker.com/reference/compose-file/include/ |
| `docker init` | docs | CONFIRMADO (a página existe e traz exemplos para Go, Node, Python, Rust, .NET, PHP e Java) | — | https://docs.docker.com/reference/cli/docker/init/ |
| Docker Scout (substitui o `docker scan`) | docs | NÃO CONSEGUI VERIFICAR a frase "substitui o scan". A página do Scout existe. | — | https://docs.docker.com/scout/ |
| Portas do Swarm | docs | CONFIRMADO | 2377/tcp, 7946/tcp+udp, 4789/udp (configurável) e IP protocolo 50 (ESP) para overlay criptografada. | https://docs.docker.com/engine/swarm/swarm-tutorial/ |
| Traefik v3: `providers.swarm` | docs/comunidade | CONFIRMADO | No v3 existe um provider Swarm próprio. `providers.docker.swarmMode` saiu. | https://doc.traefik.io/traefik/migrate/v2-to-v3-details/ (seção SwarmMode) · https://doc.traefik.io/traefik/reference/install-configuration/providers/swarm/ |
| DHI (*) | docs | CONFIRMADO (página OK) | O núcleo é gratuito, sob Apache 2.0. Os planos pagos acrescentam FIPS/STIG e SLA. | https://docs.docker.com/dhi/ |
| Métricas Prometheus do daemon (*) | docs | CONFIRMADO | `metrics-addr` no daemon.json, por exemplo `127.0.0.1:9323`. | https://docs.docker.com/engine/daemon/prometheus/ |
| `compose bridge` (*) | docs | CONFIRMADO (página existe) | — | https://docs.docker.com/compose/bridge/ |
| dependent-images (*) | docs | CONFIRMADO (`additional_contexts` com `service:`) | — | https://docs.docker.com/compose/how-tos/dependent-images/ |
| Docker Debug "exige assinatura" (*) | docs | NÃO CONSEGUI VERIFICAR | A página não fala disso. | https://docs.docker.com/reference/cli/docker/debug/ |
| Cluster volumes CSI "experimental" (*) | docs | NÃO CONSEGUI VERIFICAR o rótulo "experimental" | O doc do moby descreve o recurso como "new feature". | cluster_volumes.md |
| Docker Deep Dive (ed. 2025) cobre Swarm | comunidade | CONFIRMADO | A 4ª ed. (jan/2025) tem o cap. 11, Docker Swarm, e um capítulo de deploy de stack. Existe também uma 5ª ed. (Packt, mai/2025, ISBN 9781806024025) com um capítulo de Swarm "enxugado" (Perlego). | https://www.oreilly.com/library/view/docker-deep-dive/9781837028351/chap13.xhtml · https://leanpub.com/dockerdeepdive · https://www.perlego.com/book/5522968/docker-deep-dive-zero-to-docker-in-a-single-book-pdf |
| Docker: Up & Running 3ª ed. (2023), "Swarm de leve" | comunidade | PARCIAL | Edição, autores e data (abr–mai/2023, O'Reilly, ISBN 9781098131821) confirmados. Que a cobertura de Swarm seja breve **não** foi confirmado; só a 2ª ed. anunciava Swarm. | https://www.oreilly.com/library/view/docker-up/9781098131814/preface01.html |
| Requisito mínimo de RAM por nó (*) | docs | NÃO CONSEGUI VERIFICAR | — | — |

## 3. O que o plano NÃO pode usar como está
1. A lista de chaves ignoradas pelo `stack deploy` no inventario-docs. Substitua pelas três listas do types.go. Principais correções: `cap_add`/`cap_drop`, `sysctls` e `tmpfs` **funcionam**. `extends`, `volumes_from`, `mem_limit` e `cpu_*` **dão erro** em vez de serem ignorados. `container_name` e `expose` só geram aviso.
2. A afirmação de que a página services/ "indica por chave o que o Swarm ignora". Não indica.
3. `depends_on` com `condition:` num arquivo de stack. Não passa no schema v3. O Swarm não ordena serviços; use healthcheck, retry na aplicação ou um job de migração.
4. O caminho do volume do Postgres. Na versão 18+, monte em `/var/lib/postgresql`. Montar em `/var/lib/postgresql/data` não persiste os dados.
5. As URLs quebradas: `container/events` (use `system/events`), `compose alpha viz` e o blog da 2ndQuadrant. Troque também as que redirecionam pela URL final.
6. "Docker Debug exige assinatura", "cluster volumes experimental", "Scout substitui scan" e "Up & Running cobre Swarm de leve". Nenhuma foi verificada; não use como fato.
7. A citação do Docker Deep Dive precisa dizer a edição. Há a 4ª (jan/2025) e a 5ª (mai/2025), com o Swarm enxugado.
