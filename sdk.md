# SDK Lua do Arcanist — referência completa (build 39)

Inventário gerado do código (`bind_sdk.cpp` / `bind_engine.cpp` / `bind_game.cpp`).
Detalhes + exemplos: `AGENTS.md`. Convenção: tudo devolve `ok`/`nil, err` (fail-closed).

## `sdk.engine` — leitura do jogo

| Função | Retorno |
|---|---|
| `E.localplayer()` | tabela: `id, name, x, y, z, hp, hp_max, mana, mana_max, cap, hp_pct, mana_pct, dir, level, xp, stamina, alive, poisoned, paralyzed, hasted, manashielded, in_pz, drunk, burning, electrified, battlesign, drowning, freezing, dazzled, cursed, strengthened, redbattlesign, bleeding` |
| `E.creatures()` | lista: `{id, name, x, y, z, dist, hp_pct, is_player, is_monster, is_npc, is_self, skull, dir, look, level, party}` |
| `E.creature(id)` | um item da lista acima, ou `nil` |
| `E.target()` | id do alvo atual (`0` = sem alvo) |
| `E.equipment()` | equipados por slot: `{helmet, amulet, backpack, armor, right, left, legs, boots, ring, ammo}` = `{slot, index (1..10), id, count}` |
| `E.tiles([raio])` | sqm ao redor (raio 1..15, default 8): `{{x,y,z,items={{id,count}},creatures={ids}}}` — máx 2-5x/s |
| `E.chat([n])` | últimas `n` mensagens (default 20, máx 50): `{{author, text, mode, channel_id, channel, time}}` — `mode`: 1 say, 2 whisper, 3 yell, 4 pm-out, 5/11 pm-in |

## `sdk.localplayer` — ação: andar e falar

| Função | Efeito |
|---|---|
| `L.walk(x, y, z)` | 1 passo em direção ao tile |
| `L.step(dir)` | 1 passo na direção (0=N 1=E 2=S 3=W 4=NE 5=SE 6=SW 7=NW) |
| `N.go(x, y, z)` | pathfinding do cliente até o tile (`sdk.navigator`) |
| `L.stop()` | cancela o andar |
| `L.say(text)` | fala normal |
| `L.whisper(text)` | sussurro (modo 2) |
| `L.yell(text)` | grito (modo 3) |
| `L.channel(id, text)` | canal (modo 7) |
| `L.pm(nome, text)` | privada (modo 5) |
| `L.npc(text)` | fala no chat do NPC (modo 11): `say("hi")` + `npc("thais")` + `npc("yes")` |
| `L.attack(id)` | ataca o id (`0` = para) |
| `L.fight_modes(fight, chase, safe)` | fight 1=offensive 2=balanced 3=defensive; chase 0=parado 1=seguindo |
| `L.follow(id)` | segue a criatura |
| `L.look(x, y, z)` | olha o item de cima do tile |
| `L.turn(dir)` | vira sem andar (0=N 1=E 2=S 3=W) |
| `L.browse(x, y, z)` | pede os dados do tile pro servidor |

## `sdk.localplayer` — ação: itens

| Função | Efeito |
|---|---|
| `L.use_item(cid, slot, id)` | usa item de container aberto (`cid` 0 = primeira janela) |
| `L.use_at(x, y, z, id)` | usa item no tile; no corpo: `(65535, slot, 0, id)` |
| `L.use_ground(x, y, z, [n])` | usa o n-ésimo item do tile sem saber o id (default 1 = o de baixo; escada) |
| `L.use_tool(id)` | usa ferramenta via hotkey (corda, pá, facão) |
| `L.use_on(id, x, y, z)` | COM MIRA no objeto (chave na porta, corda no buraco) |
| `L.use_on_creature(x, y, z, item_id, stackpos, creature_id)` | usa item EM criatura (runa no monstro, poção no amigo) |
| `L.move_item(...)` | move item entre containers |
| `L.rotate(x, y, z, id)` | gira item (porta, cama) — hipótese, confirmar ao vivo |
| `L.close_all()` | fecha todos os containers |

## `sdk.containers` — mochilas e depot

| Função | Efeito |
|---|---|
| `K.open()` / `K.list()` | containers ABERTOS: `{{id, name, capacity, items={{slot, id, count, is_container}}}}` |
| `K.open_backpacks()` | fecha tudo, abre a equipada + as de dentro 1x1; devolve os cids |
| `K.close(cid)` | fecha UM container |
| `K.up(cid)` | sobe um nível (bp interna → pai) |
| `K.seek(cid, index)` | pagina do container a partir de index |
| `K.count_item(id)` | quantos desse item você tem (inventário + abertos) |

## `sdk.npc` — trade

| Função | Efeito |
|---|---|
| `N.trade_open()` | `true` se a janela de trade está aberta (abre com `say("hi")` + `npc("trade")`) |
| `N.offers()` | ofertas: `{{id, name, count, weight, buy, sell}}` |
| `N.buy(id, [qtd, ignore_cap, in_backpack])` | compra no NPC aberto |
| `N.sell(id, [qtd])` | vende no NPC aberto |

## `sdk.stash`

| Função | Efeito |
|---|---|
| `ST.stow(cid)` | deposita o container no stash |
| `ST.withdraw(id, [qtd])` | saca do stash |

## `sdk.helper` — RTC (config remota)

| Função | Efeito |
|---|---|
| `H.set(campo, "valor")` | configura (sempre string, ex `"70"`) |
| `H.get(campo)` | lê o valor atual |
| `H.list()` | catálogo COMPLETO `{name, label, group, type, min, max}` — itere em vez de decorar |
| `H.threshold_set(chave, valor)` | atalho de limite |

## `sdk.cavebot`

`start` / `stop` / `set` + `route_load` / `route_save` / `route_clear` — waypoints e execução.

## `sdk.tools` / `sdk.shared` / `sdk.storage` / `sdk.schedule`

`quickloot()` · `close_all()` (também em `L`) · `shared` = memória entre estados (`set/get/del/count`) · `storage` = disco (`set/get/del/save/all`) · `schedule` = `every/after/cancel/now`.

## `sdk.navigator`

`go(x, y, z)` (o `N.go` acima).

## `game.*` — utilidades

`log(text)` · `key(nome)` / `key_pressed(nome)` (F1..F12, INSERT, espaço, setas — funciona com o jogo em foco) · `alert(text)`.

## `game.dbg` — pesquisa

`game_va()` · `read_bytes(va, n)` (janela de leitura crua) · `hex(bytes)`.

## `ui.*` — painel do script

`window` / `text` / `color_text` / `text_wrapped` / `button` / `checkbox` / `input` / `slider` / `combo` / `selectable` / `table` / `child` / `collapsing` / `bullet` / `progress` / `separator` / `spacing` / `tooltip` / `theme` / `themes` — primitivos ImGui (ver `AGENTS.md` §UI). INSERT mostra/esconde; clique atravessa onde não tem painel.

## Eventos (`Engine.on`)

`Hp {pct, hp, hp_max}` · `Mana {...}` · `PositionChange {x, y, z}` · `Level {level, xp}` · `Conditions {poisoned, paralyzed, ...}` — disparam quando o valor MUDA.
