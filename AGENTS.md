# AGENTS.md — SDK Lua do Arcanist

> ## 📌 PARA O CIRO (leia só isto, 2 minutos)
>
> Este arquivo é o **manual completo do bot**. Quem escreve o código é a sua **IA** — você só
> precisa mandar **este arquivo inteiro** pra ela e pedir as coisas em português normal.
>
> **1. Comece a conversa com a sua IA assim:**
> *"Leia o AGENTS.md inteiro antes de escrever qualquer código. Ele tem a API completa do
> bot, as regras e exemplos prontos. Depois me diga que entendeu e eu te peço as coisas."*
>
> **2. Depois é só pedir.** Exemplos do que você pode pedir:
> - *"faz um painel que mostra meu HP, mana e nível"*
> - *"faz ele curar quando meu HP ficar abaixo de 60%"*
> - *"faz uma lista dos monstros por perto com a distância"*
> - *"faz um botão que liga e desliga o auto-loot"*
> - *"quero que tudo que eu configurar fique salvo quando eu fechar o bot"*
>
> **3. A IA te devolve um arquivo `main.lua`.** Você:
> - cria uma pasta em `scripts\` (ex: `scripts\meubot\`) e põe o `main.lua` dentro
> - no bot: aba **SDK Lua** → **Rescan** → **Carregar** no seu pack
> - mudou o código? **Reload** (recarrega na hora)
>
> **4. Já tem 4 packs prontos no pacote pra ver funcionando:** `scripts\heal`, `scripts\hud`,
> `scripts\autoloot`, `scripts\radar` — é só clicar **Carregar** em cada um (§6.6 tem o código).
>
> **5. Deu erro?** Copie a mensagem laranja de "ultimo erro" (ou as últimas linhas do
> `arcanist.log`) e mande pra IA: *"deu esse erro, conserta"*. Ela tem tudo que precisa aqui.
>
> O resto deste documento é o manual técnico que a **sua IA** usa. Você não precisa entender
> o código — só pedir, testar e mandar o erro de volta quando tiver.

Este documento é para um **agente de IA** que vai criar packs (features + UI) para o
**arcanist**, o bot do RubinOT. Leia o documento inteiro antes de escrever qualquer código.
Tudo que existe está aqui — **não invente funções, campos ou eventos** que não estejam
neste arquivo. Se precisar de algo que não está aqui, pergunte ao humano.

O que o SDK permite, em uma frase: **ler o estado do jogo, executar ações no cliente e
desenhar a interface do usuário final — tudo em Lua, sem tocar em C++.**

---

## 1. Como um pack funciona (o modelo dos 2 estados)

Um **pack** é só uma pasta com um `main.lua` dentro, colocada ao lado do `arcanist.exe`:

```
scripts/
  meu_bot/
    main.lua
```

O `main.lua` roda em **dois lugares ao mesmo tempo**, chamados de **estados**:

| Estado  | O que é                        | O que roda lá |
|---------|--------------------------------|---------------|
| `logic` | thread do script (background)  | registra eventos, spawna coroutines, **executa ações** (andar, atacar, usar item...) |
| `ui`    | thread da GUI (desenha o ImGui)| define `ui.frame()`, que o host chama **a cada quadro**; só desenha e enfileira |

Motivo: uma ação no cliente pode bloquear até ~2 segundos esperando o jogo responder. Se a
UI executasse ações direto, a janela congelaria. Então a UI só **pede**; o `logic` **executa**.

Como os dois estados **não compartilham memória Lua**, use:
- `sdk.shared` — memória compartilhada (some quando o pack é descarregado);
- `sdk.storage` — disco (sobrevive a restart; é o mesmo mapa do shared + gravação).

Para saber em qual estado você está: `HOST_STATE` (string `"logic"` ou `"ui"`) ou
`game.is_ui` (boolean).

### Exemplo mínimo completo

```lua
-- scripts/meu_bot/main.lua
local E  = require("sdk.engine")
local T  = require("sdk.tools")
local S  = require("sdk.shared")
local ui = game.overlay

-- Roda nos DOIS estados. Escrita de config no load precisa do guard:
if HOST_STATE == "logic" then
  S.set("sessoes", (S.get("sessoes") or 0) + 1)
end

-- FEATURE (estado logic): coroutine que roda sozinha
spawn(function()
  while true do
    wait(2000)
    local lp = E.localplayer()
    if lp then S.set("hp_pct", lp.hp_pct) end
  end
end)

-- UI (estado ui): o host chama isto a cada quadro
function ui.frame()
  ui.window("Meu Bot", function()
    ui.text("HP: " .. tostring(S.get("hp_pct") or "?") .. "%")
    if ui.button("Quickloot agora") then T.quickloot() end
  end)
end
```

---

## 2. Regras de ouro (quebrar = bug)

1. **Ações só no `logic`.** No estado `ui` elas são **enfileiradas** e devolvem `true` na
   hora; o resultado real (e o erro, se houver) só aparece no log (`[script] <acao> falhou: ...`).
2. **UI só no estado `ui`.** `game.overlay.*` fora do `ui.frame` dá erro
   `game.overlay: so funciona no estado ui`.
3. **`wait()` só dentro de `Engine.spawn`.** Fora de coroutine é erro de propósito
   (para um `while true do wait() end` solto não congelar o carregamento).
4. **`goto` é palavra reservada do Lua** — a função pública é **`N.go(x, y, z)`**.
5. **O `main.lua` roda DUAS VEZES** (um por estado). Qualquer escrita no load precisa do
   guard `if HOST_STATE == "logic" then ... end`.
6. **Config do usuário vai pro `sdk.storage`** (não pro shared) — o usuário espera rever
   depois de reiniciar o bot.
7. **Nunca invente API.** Só existe o que está neste documento.
8. **O pack não pode "derrubar" o bot**: erros em handler/timer/coroutine/UI são capturados
   (`pcall`) e vão pro log + campo "ultimo erro". Mas erro no carregamento do `main.lua`
   faz o **Carregar falhar** — o motivo aparece no log.

---

## 3. Ciclo de desenvolvimento (criar → carregar → testar)

1. Crie `scripts/<nome_do_pack>/main.lua` ao lado do `arcanist.exe`.
2. No bot, aba **SDK Lua**:
   - **Rescan** — re-escaneia a pasta `scripts\` (aparece a contagem de packs);
   - **Carregar** (botão ao lado de cada pack) — carrega aquele pack;
   - **Reload** — recarrega o pack atual (use após editar o código);
   - **status** — `host: rodando|parado | pack: carregado|nao carregado`;
   - **ultimo erro** — aparece em laranja quando algo falha.
3. No boot, o bot carrega **o primeiro pack que encontrar** em `scripts\` (a ordem não é
   garantida). Para escolher outro, clique **Carregar** nele.
4. Log completo: **`arcanist.log`** ao lado do exe. Linhas relevantes:
   - `[sdk]` — carregamento de pack, rescan;
   - `[script]` — erros de ação, erros de `ui.frame`, falhas de storage;
   - `[lua]` — `game.log(...)` e erros de handler/timer/coroutine (`[lua][erro]`);
   - `[alerta]` — `game.alert(...)`.
5. Para testar rápido: **Carregar** → editar o arquivo → **Reload** → ver o log.

O pack de referência é **`scripts/demo_ui/`** — um painel de produto completo. Copie a
pasta e modifique. Outros: `scripts/examples/01..05`, `scripts/hello`, `scripts/refill`,
`scripts/_teste` (auto-verificação).

---

## 4. Referência completa da API

Convenção de retorno das **ações**: no `logic` devolvem `true` em sucesso ou
`nil, "mensagem"` em falha (use `local ok, err = ...`). No `ui` devolvem `true` na hora
(ação vai pra fila). As **leituras** devolvem o valor ou `nil, err`.

### 4.1 Globais

| Função | Retorno | Descrição |
|---|---|---|
| `game.log(...)` | — | Escreve no log do bot (junta os argumentos com tab). |
| `game.alert(...)` | — | Toast na tela do usuário + log `[alerta]`. Funciona nos DOIS estados. |
| `game.is_ui` | bool | `true` no estado `ui`. |
| `game.overlay` | tabela | A UI (só no estado `ui`). Ver §4.15. |
| `game.dbg` | tabela | Ferramenta de pesquisa (ver §4.16). Não use em pack de produção. |
| `HOST_STATE` | string | `"logic"` ou `"ui"`. |
| `wait(ms)` | — | Atalho de `Engine.wait` (só dentro de `spawn`). |
| `spawn(fn)` | id | Atalho de `Engine.spawn`. |
| `game.key(nome)` | bool | A tecla está pressionada **agora**? Leitura **global** — funciona com o **jogo em foco** (não precisa da janela do bot focada). |
| `game.key_pressed(nome)` | bool | A tecla **acabou de ser apertada** (borda). A leitura **consome** a borda (dispara 1x) — chame num lugar só, normalmente no `logic`. |

Nomes de tecla aceitos: `f1`..`f12`, `insert`, `delete`, `home`, `end`, `pageup`, `pagedown`,
`up`/`down`/`left`/`right`, `space`, `enter`, `escape`, `tab`, `a`..`z`, `0`..`9`. (Nome
desconhecido devolve `false`; prefira F-keys pra não conflitar com digitação.)

```lua
-- hotkey: aperta F1 -> loota (com o JOGO em foco e ate com a UI do bot escondida)
spawn(function()
  while true do
    wait(50)
    if game.key_pressed("f1") then T.quickloot() end
  end
end)
```

### 4.2 `sdk.engine` — leitura do jogo

```lua
local E = require("sdk.engine")
```

| Função | Retorno | Campos |
|---|---|---|
| `E.localplayer()` | tabela ou `nil, err` | `id, name, x, y, z, hp, hp_max, mana, mana_max, cap, hp_pct, mana_pct, dir, level, xp, stamina, alive, poisoned, paralyzed, hasted, manashielded, in_pz, drunk` |
| `E.creatures()` | lista (array) | itens com `id, name, x, y, z, dist, hp_pct, is_player, is_monster, is_npc, is_self, skull` |
| `E.creature(id)` | tabela ou `nil` | procura o `id` na lista acima |
| `E.target()` | inteiro | id do alvo atual; `0` = sem alvo |
| `E.equipment()` | tabela | itens **equipados**, por slot — só os slots ocupados: `{helmet={slot="helmet",id=1234,count=1}, backpack={...}, ...}` |

Slots do equipamento: `helmet`, `amulet`, `backpack`, `armor`, `right` (arma), `left` (escudo),
`legs`, `boots`, `ring`, `ammo`. Slot vazio = ausente na tabela.

```lua
local eq = E.equipment()
if eq and eq.helmet then
  ui.text(("elmo: id %d (x%d)"):format(eq.helmet.id, eq.helmet.count))
end
```

Observações:
- `hp_pct` / `mana_pct` são 0..100.
- `is_self` = você mesmo. `is_player` = **outros** jogadores (convenção ElfBot/rxbot).
- `x, y, z` são a posição real do personagem.

### 4.3 `sdk.localplayer` — ações do seu char

```lua
local L = require("sdk.localplayer")
```

| Função | Argumentos | Descrição |
|---|---|---|
| `L.walk(x, y, z)` | tile | Anda 1 passo na direção do tile (síncrono). |
| `L.step(dir)` | 0..7 | Um passo em direção explícita: **0=N, 1=E, 2=S, 3=W, 4=NE, 5=SE, 6=SW, 7=NW** (mesma convenção do ElfBot/rxbot). |
| `L.say(texto)` | string | Fala no chat (ex: `"exura"`). |
| `L.stop()` | — | Cancela o andar. |
| `L.attack(id)` | creature id | Ataca; `0` cancela o ataque. |
| `L.use_item(cid, slot, item_id)` | — | Usa item de um container (`cid` 0 = inventário). |
| `L.use_at(x, y, z, item_id)` | — | Usa item num tile. |
| `L.move_item(from_cid, from_slot, to_cid, to_slot, item_id[, count])` | `count` default 1 | Move item entre containers. |
| `L.close_all()` | — | Fecha todas as janelas. |

### 4.4 `sdk.navigator` — ir para um tile

```lua
local N = require("sdk.navigator")
N.go(x, y, z)   -- pathfinding DO CLIENTE (o mesmo do minimapa): anda vários tiles sozinho
```

### 4.5 `sdk.tools`

```lua
local T = require("sdk.tools")
T.quickloot()    -- loota os corpos por perto
T.close_all()    -- fecha todas as janelas
```

### 4.6 `sdk.stash` — Supply Stash

```lua
local ST = require("sdk.stash")
ST.stow(cid)             -- esvazia o container aberto no stash de UMA vez (SEM VOLTA — testar com item barato)
ST.withdraw(item_id, count)  -- saca item do stash
```

### 4.7 `sdk.npc` — comprar / vender

```lua
local N = require("sdk.npc")
N.buy(item_id[, count[, ignore_cap[, in_backpack]]])  -- count=1, ignore_cap=false, in_backpack=false
N.sell(item_id[, count])                              -- count=1
```

### 4.8 `sdk.helper` — o RTC (auto-target, auto-cast, cura...)

```lua
local H = require("sdk.helper")

H.list()              -- catálogo COMPLETO: lista de {name, label, group, type, min, max}
H.get(name)           -- valor atual (número)
H.set(name, valor)    -- grava; valor é SEMPRE string (ex: "1", "0", "70")
H.threshold_set(key, valor)  -- chaves: cura_hp_pct, pocao_hp_pct, mana_treino_pct, sio_hp_pct, custom.*
```

Regra de ouro do painel do RTC: **não decore nomes de campo** — itere `H.list()` e monte os
controles a partir do catálogo (`type == "u8" and max == 1` → checkbox; senão slider
`min..max`). Exemplo completo em §6.3.

### 4.9 `sdk.cavebot`

```lua
local C = require("sdk.cavebot")
C.start() / C.stop()
C.set(key, value)   -- chaves: walk_mode, walk_interval_s, prewalk_expiry_s, terreno_timeout_s, pause_on_target
C.route_load(path) / C.route_save(path) / C.route_clear()
```

### 4.10 `sdk.containers`

```lua
local K = require("sdk.containers")
K.count_item(item_id)   -- quantos desse item você tem (inventário + abertos)
```

### 4.11 `sdk.shared` — memória entre os dois estados

```lua
local S = require("sdk.shared")
S.set(chave, valor)   -- valor: bool, number ou string. S.set(k, nil) apaga.
S.get(chave)          -- valor ou nil
S.del(chave)          -- true se existia
S.count()             -- quantas chaves
```

### 4.12 `sdk.storage` — persistente (disco)

```lua
local ST = require("sdk.storage")
ST.set(chave, valor)  -- grava NO DISCO a cada chamada. Retorna true | nil, err.
ST.get(chave)         -- valor ou nil
ST.del(chave)         -- true se existia (também grava)
ST.all()              -- tabela com tudo
ST.save()             -- grava tudo de novo (true | nil, err)
```

- Arquivo: **`scripts/<nome_do_pack>/storage.dat`** (por pack).
- `sdk.storage` e `sdk.shared` são **o mesmo mapa** — a diferença é que o storage grava em
  disco. Ou seja: `ST.set` também fica visível no `S.get`.
- Use storage para **configuração do usuário** (o que ele mexeu no painel).
- **Não chame `ST.set` a cada frame da UI** — só quando o usuário mudar algo.

### 4.13 `Engine` — eventos, timers e coroutines

Também acessível como `sdk.schedule` (mesmas funções: `every`, `after`, `cancel`, `now`,
`spawn`, `wait`, `spawn_count`).

| Função | Retorno | Descrição |
|---|---|---|
| `Engine.on(nome, fn)` | id | Registra handler de um evento (§4.14). |
| `Engine.onAny(fn)` | id | Handler de TODOS os eventos. |
| `Engine.off(id)` | bool | Remove um handler. |
| `Engine.help(name)` | — | Loga uma dica sobre o evento (os campos dependem do poller). |
| `Engine.every(ms, fn)` | id | Timer repetitivo (roda no estado logic). |
| `Engine.after(ms, fn)` | id | Timer de uma vez só. |
| `Engine.cancel(id)` | bool | Cancela timer, coroutine ou handler pelo id. |
| `Engine.now()` | ms | Relógio monotônico em milissegundos. |
| `Engine.spawn(fn, ...)` | id | Roda `fn` numa coroutine (a feature "em linha reta"). |
| `Engine.wait(ms)` | — | Pausa a coroutine por `ms`. **Só dentro de spawn.** |
| `Engine.spawn_count()` | int | Quantas coroutines vivas. |

```lua
Engine.on("Hp", function(ev)
  if ev.pct < 30 then game.alert("HP baixo: " .. ev.pct .. "%") end
end)

spawn(function()
  while true do
    wait(1000)
    -- feature aqui
  end
end)
```

### 4.14 Eventos (disparam SÓ quando o valor muda)

A primeira leitura de cada evento vira baseline (não emite). Handler recebe uma tabela `ev`
com os campos + `ev.name`.

| Evento | Campos |
|---|---|
| `"Hp"` | `pct, hp, hp_max` |
| `"Mana"` | `pct, mana, mana_max` |
| `"PositionChange"` | `x, y, z` |
| `"Level"` | `level, xp` |
| `"Conditions"` | `poisoned, paralyzed, hasted, manashielded, in_pz, drunk, alive` |

### 4.15 `game.overlay` — a UI (só no estado `ui`)

```lua
local ui = game.overlay
function ui.frame() ... end   -- o host chama a cada quadro
```

| Função | Retorno | Descrição |
|---|---|---|
| `ui.window(titulo, fn)` | — | Janela; `fn` desenha o corpo (protegida; sempre fecha). |
| `ui.text(...)` | — | Texto (junta argumentos com tab). |
| `ui.text_wrapped(...)` | — | Texto com quebra de linha. |
| `ui.bullet(...)` | — | Item com marcador. |
| `ui.separator()` | — | Linha divisória. |
| `ui.same_line()` | — | Próximo widget na mesma linha. |
| `ui.spacing()` | — | Espaço vertical. |
| `ui.tooltip(...)` | — | Tooltip do último widget. |
| `ui.color_text(r, g, b, texto)` | — | Texto colorido (r,g,b floats 0..1). |
| `ui.progress(pct)` | — | Barra de progresso 0..100 (clampa). |
| `ui.button(label)` | bool | `true` no clique. |
| `ui.checkbox(label[, valor])` | bool | Novo estado (nil tolerado = false). |
| `ui.input(label[, valor])` | string | Texto atual do campo (você decide se salva). |
| `ui.slider(label, valor[, min, max])` | int | `min`=0, `max`=100 por padrão. |
| `ui.combo(label, lista[, indice])` | int | Índice **1-based** (1 = primeiro item). |
| `ui.selectable(label[, selecionado])` | bool | `true` no clique. |
| `ui.child(id, fn)` | — | Área com scroll. |
| `ui.collapsing(label, fn)` | — | Seção que abre/fecha. |
| `ui.table(id, headers, rows)` | — | Tabela pronta: `headers` = lista de strings; `rows` = lista de listas. |
| `ui.hide_host([bool])` | bool | Esconde a UI de debug do bot (default `true`). Retorna o estado. |
| `ui.host_hidden()` | bool | A UI do bot está escondida? |
| `ui.theme(nome)` | — | Troca o tema (erro se nome inválido). |
| `ui.themes()` | lista | Nomes válidos dos temas. |

Temas: `"moonlight"` (default), `"eggplant"`, `"cyan"`, `"dark"`.

### 4.16 `game.dbg` — pesquisa (não usar em produção)

```lua
game.dbg.game_va()            -- endereço do Game (VA)
game.dbg.read_bytes(va, n)    -- string com n bytes lidos (ou nil, err)
game.dbg.hex(s)               -- string de bytes -> hex legível
```

---

## 5. Esqueleto de pack (template de produto)

```lua
-- ============================================================================
-- scripts/meu_bot/main.lua — pack modelo
-- ============================================================================
local E  = require("sdk.engine")
local L  = require("sdk.localplayer")
local T  = require("sdk.tools")
local H  = require("sdk.helper")
local ST = require("sdk.storage")
local S  = require("sdk.shared")
local ui = game.overlay

-- 1) CONFIG (disco, com defaults)
local cfg = {
  auto_loot = (ST.get("auto_loot") == true),
  heal_pct  = tonumber(ST.get("heal_pct")) or 60,
  tema      = ST.get("tema") or "moonlight",
  hide_host = (ST.get("hide_host") == true),
}

-- 2) ESCRITAS DE LOAD só no logic (o main.lua roda 2x!)
if HOST_STATE == "logic" then
  ST.set("sessoes", (tonumber(ST.get("sessoes")) or 0) + 1)
end

-- 3) FEATURE (logic): coroutine com wait
spawn(function()
  while true do
    wait(2000)
    if ST.get("auto_loot") == true then   -- le do ST: o toggle da UI chega aqui na hora
      local ok, err = T.quickloot()
      if not ok then S.set("ultimo_erro", tostring(err)) end
    end
  end
end)

-- 4) EVENTOS (logic)
Engine.on("Hp", function(ev)
  if ev.pct < (tonumber(ST.get("heal_pct")) or 60) then
    local ok = L.say("exura")
    if ok then game.alert("HP " .. ev.pct .. "% - curei") end
  end
end)

-- 5) UI (ui): desenha todo frame
function ui.frame()
  ui.window("Meu Bot", function()
    local lp = E.localplayer()
    if lp then
      ui.table("##stats", { "Pos", "HP", "Mana", "Nivel" }, { {
        ("%d,%d,%d"):format(lp.x, lp.y, lp.z),
        ("%d%%"):format(lp.hp_pct),
        ("%d%%"):format(lp.mana_pct),
        tostring(lp.level),
      } })
    else
      ui.text("sem personagem")
    end

    ui.separator()

    ui.collapsing("Automacao", function()
      local v = ui.checkbox("Auto-loot", cfg.auto_loot)
      if v ~= cfg.auto_loot then
        cfg.auto_loot = v
        ST.set("auto_loot", v)
      end
    end)

    local err = S.get("ultimo_erro")
    if err then ui.color_text(1.0, 0.6, 0.3, "ultimo erro: " .. tostring(err)) end
  end)
end

-- 6) aplica o que o usuário já tinha escolhido
if cfg.hide_host then ui.hide_host(true) end
ui.theme(cfg.tema)
```

---

## 6. Receitas

### 6.1 Config persistida (o usuário mexe, sobrevive restart)

```lua
local v = ui.checkbox("Auto-loot", cfg.auto_loot)
if v ~= cfg.auto_loot then
  cfg.auto_loot = v
  ST.set("auto_loot", v)      -- grava no disco
  game.alert(v and "Auto-loot LIGADO" or "Auto-loot desligado")
end
```

### 6.2 Feature em coroutine

```lua
spawn(function()
  while true do
    wait(500)
    -- roda a cada 500ms, sem travar a UI
  end
end)
```

### 6.3 Painel do RTC gerado do catálogo (sem decorar nomes)

```lua
ui.collapsing("Auto do RTC", function()
  local por_grupo, ordem = {}, {}
  for _, f in ipairs(H.list()) do
    if not por_grupo[f.group] then
      por_grupo[f.group] = {}; ordem[#ordem + 1] = f.group
    end
    table.insert(por_grupo[f.group], f)
  end
  for _, grupo in ipairs(ordem) do
    ui.collapsing(grupo, function()
      for _, f in ipairs(por_grupo[grupo]) do
        local atual = H.get(f.name)
        if f.type == "u8" and f.max == 1 then
          local novo = ui.checkbox(f.label, atual ~= 0)
          if novo ~= (atual ~= 0) then H.set(f.name, novo and "1" or "0") end
        else
          local novo = ui.slider(f.name, atual, f.min, f.max)
          if novo ~= atual then H.set(f.name, tostring(novo)) end
          ui.tooltip(f.label .. " (" .. f.min .. ".." .. f.max .. ")")
        end
      end
    end)
  end
end)
```

### 6.4 UI mostrando o que o logic está fazendo (via shared)

```lua
-- no logic: S.set("estado", "caçando")
-- no ui:
ui.text("estado: " .. tostring(S.get("estado") or "-"))
```

### 6.5 Esconder a UI do bot (entrega pro usuário final)

```lua
-- (a) num controle do TEU painel (o usuário liga/desliga quando quiser):
ui.hide_host(true)

-- (b) JÁ NO CARREGAMENTO do pack (o usuário nunca vê a UI do bot):
if HOST_STATE == "ui" then
  ui.hide_host(true)
end
```

**IMPORTANTE:** se você esconder a UI do bot, o **TEU painel precisa ter como trazer de volta**
(um checkbox "mostrar UI do bot" que chama `ui.hide_host(false)`) — senão o usuário fica sem
como chegar nas abas do bot. O `demo_ui` faz exatamente isso (checkbox + fica salvo).

**Dica de layout:** o painel do pack é uma janela ImGui normal — arraste pela barra de título.
Os painéis do pack ficam **SEMPRE na frente** das abas do bot: clicar no host **não** os cobre
(o host nunca sobe na frente deles). Quer a tela só com o teu painel? Esconda o host (acima).

### 6.6 Packs prontos (já vêm na pasta `scripts\` do pacote)

São a base mais rápida que existe: **clique Carregar** na aba SDK Lua pra ver funcionando, ou
copie a pasta, mude o nome e edite. O código completo de cada um:

**`scripts/heal/` — cura automática** (liga/desliga + magia + % salvos):

```lua
local E  = require("sdk.engine")
local L  = require("sdk.localplayer")
local ST = require("sdk.storage")
local S  = require("sdk.shared")
local ui = game.overlay

local cfg = {
  ligado = (ST.get("ligado") == true),
  spell  = ST.get("spell") or "exura",
  hp_min = tonumber(ST.get("hp_min")) or 60,
}

-- FEATURE (estado logic). Le os toggles do ST a cada volta: o que o usuario
-- mexe na janela chega aqui na hora (as variaveis de cada estado NAO se cruzam).
spawn(function()
  while true do
    wait(300)
    if ST.get("ligado") == true then
      local lp = E.localplayer()
      local limiar = tonumber(ST.get("hp_min")) or 60
      if lp and lp.hp_pct < limiar then
        local spell = ST.get("spell") or "exura"
        local ok, err = L.say(spell)
        if ok then
          S.set("ultima_cura", lp.hp_pct .. "% com " .. spell)
        else
          S.set("ultimo_erro", tostring(err))
        end
      end
    end
  end
end)

-- UI (estado ui)
function ui.frame()
  ui.window("Heal", function()
    local lp = E.localplayer()
    if lp then
      ui.text(("HP %d%%   Mana %d%%"):format(lp.hp_pct, lp.mana_pct))
      ui.progress(lp.hp_pct)
    else
      ui.text("sem personagem")
    end

    ui.separator()

    local v = ui.checkbox("Cura automatica", cfg.ligado)
    if v ~= cfg.ligado then
      cfg.ligado = v
      ST.set("ligado", v)
      game.alert(v and "Heal LIGADO" or "Heal desligado")
    end

    local pct = ui.slider("Curar abaixo de (%)", cfg.hp_min, 10, 95)
    if pct ~= cfg.hp_min then
      cfg.hp_min = pct
      ST.set("hp_min", pct)
    end

    local sp = ui.input("Magia", cfg.spell)
    if sp ~= cfg.spell then
      cfg.spell = sp
      ST.set("spell", sp)
    end

    local ult = S.get("ultima_cura")
    if ult then ui.color_text(0.4, 1.0, 0.4, "ultima cura: " .. tostring(ult)) end
    local err = S.get("ultimo_erro")
    if err then ui.color_text(1.0, 0.6, 0.3, "ultimo erro: " .. tostring(err)) end
  end)
end
```

**`scripts/hud/` — painel de stats** (HP, mana, cap, xp, condições):

```lua
local E  = require("sdk.engine")
local ST = require("sdk.storage")
local ui = game.overlay

-- conta quantas vezes o bot carregou este pack (fica salvo no disco)
if HOST_STATE == "logic" then
  ST.set("sessoes", (tonumber(ST.get("sessoes")) or 0) + 1)
end

function ui.frame()
  ui.window("HUD", function()
    local lp = E.localplayer()
    if not lp then
      ui.text("sem personagem (loga no jogo)")
      return
    end

    ui.text(("%s  -  nivel %d"):format(lp.name, lp.level))
    ui.text(("Pos: %d, %d, %d"):format(lp.x, lp.y, lp.z))
    ui.separator()

    ui.text(("HP %d%%"):format(lp.hp_pct))
    ui.progress(lp.hp_pct)
    ui.text(("Mana %d%%"):format(lp.mana_pct))
    ui.progress(lp.mana_pct)
    ui.separator()

    ui.text("Cap: " .. lp.cap .. "   |   XP: " .. lp.xp)
    ui.text("Stamina: " .. lp.stamina)

    local estados = {}
    if lp.poisoned then estados[#estados + 1] = "ENVENENADO" end
    if lp.paralyzed then estados[#estados + 1] = "PARALISADO" end
    if lp.hasted then estados[#estados + 1] = "haste" end
    if lp.manashielded then estados[#estados + 1] = "manashield" end
    if lp.in_pz then estados[#estados + 1] = "PZ" end
    if lp.drunk then estados[#estados + 1] = "bebado" end
    if #estados > 0 then
      ui.color_text(1.0, 0.75, 0.2, table.concat(estados, "  |  "))
    else
      ui.text("sem condicoes ativas")
    end

    ui.separator()
    ui.text("sessoes (salvo): " .. tostring(ST.get("sessoes") or "?"))
  end)
end
```

**`scripts/autoloot/` — auto-loot com botões:**

```lua
local T  = require("sdk.tools")
local ST = require("sdk.storage")
local S  = require("sdk.shared")
local ui = game.overlay

local cfg = {
  ligado    = (ST.get("ligado") == true),
  intervalo = tonumber(ST.get("intervalo")) or 1500,
}

-- FEATURE (estado logic). Le do ST a cada volta (toggle da UI chega na hora).
spawn(function()
  while true do
    wait(tonumber(ST.get("intervalo")) or 1500)
    if ST.get("ligado") == true then
      local ok, err = T.quickloot()
      if ok then
        S.set("loots", (tonumber(S.get("loots")) or 0) + 1)
      else
        S.set("ultimo_erro", tostring(err))
      end
    end
  end
end)

-- UI (estado ui)
function ui.frame()
  ui.window("Auto-loot", function()
    local v = ui.checkbox("Lootar automaticamente", cfg.ligado)
    if v ~= cfg.ligado then
      cfg.ligado = v
      ST.set("ligado", v)
      game.alert(v and "Auto-loot LIGADO" or "Auto-loot desligado")
    end

    local ms = ui.slider("A cada (ms)", cfg.intervalo, 500, 5000)
    if ms ~= cfg.intervalo then
      cfg.intervalo = ms
      ST.set("intervalo", ms)
    end

    ui.separator()

    if ui.button("Lootar agora") then
      local ok, err = T.quickloot()
      game.alert(ok and "Loot ok" or ("Falhou: " .. tostring(err)))
    end

    ui.text("loots nesta sessao: " .. tostring(S.get("loots") or 0))
    local err = S.get("ultimo_erro")
    if err then ui.color_text(1.0, 0.6, 0.3, "ultimo erro: " .. tostring(err)) end
  end)
end
```

**`scripts/radar/` — monstros por perto + botão de atacar:**

```lua
local E  = require("sdk.engine")
local L  = require("sdk.localplayer")
local ui = game.overlay

function ui.frame()
  ui.window("Radar", function()
    local perto = {}
    for _, c in ipairs(E.creatures()) do
      if c.is_monster then perto[#perto + 1] = c end
    end
    table.sort(perto, function(a, b) return a.dist < b.dist end)

    ui.text(#perto .. " monstro(s) por perto")
    ui.separator()

    if #perto == 0 then
      ui.text("nenhum monstro na tela")
      return
    end

    for i = 1, math.min(#perto, 8) do
      local c = perto[i]
      ui.text(("%s  (%d tiles, %d%% hp)"):format(c.name, c.dist, c.hp_pct))
      ui.same_line()
      -- o clique enfileira a acao (a UI nunca despacha na hora); erro real vai pro log
      if ui.button("Atacar##m" .. c.id) then
        local ok, err = L.attack(c.id)
        game.alert(ok and ("Atacando " .. c.name) or ("Falhou: " .. tostring(err)))
      end
    end
  end)
end
```

---

## 7. Armadilhas (leia 2x)

- **`main.lua` roda 2x** — escrita no load sem o guard `HOST_STATE == "logic"` duplica
  (ex: contador subindo de 2 em 2).
- **Ação no `ui` não é imediata** — ela vai pra fila. Não leia o resultado no mesmo frame.
- **`wait()` fora de `spawn`** = erro de propósito.
- **`ui.*` fora do estado `ui`** = erro claro no log.
- **`goto` reservado** → use `N.go`.
- **`ui.combo` é 1-based**; `ui.slider` default 0..100; `ui.progress` clampa 0..100.
- **`ST.set` grava a cada chamada** — não use dentro do loop de frame sem necessidade.
- **Storage só aceita bool / number / string.**
- **`H.set` recebe string sempre** (`"1"`, `"0"`, `"70"`).
- **`H.list()`** devolve o catálogo do bot — se o jogo não estiver conectado, pode vir
  vazio; trate com `if #lista == 0 then ... end`.
- **`ui.window` / `ui.collapsing` / `ui.child` são protegidos** — o fechamento é garantido
  mesmo com erro no corpo.
- **`ui.checkbox` com `nil`** é tolerado (vira `false`) — útil antes da chave existir.
- **`game.dbg` é ferramenta de pesquisa**, não vai em pack de produção.
- **Config do painel não chega sozinha no `logic`.** O `main.lua` roda em DOIS estados e as
  variáveis de um NÃO existem no outro. Quando o usuário mexe num toggle, a UI grava com
  `ST.set`/`S.set` — e o seu loop/evento no `logic` deve **ler `ST.get`/`S.get` a cada
  volta** (nunca guardar o valor numa variável local criada no load). O `ST.set`/`S.set`
  sincroniza os dois estados na hora.
- **Não existe função fora deste documento.** Se falta algo, pergunte.

### Socorro rápido (deu errado?)

| Sintoma | O que fazer |
|---|---|
| A janela do pack não aparece | A aba **SDK Lua** mostra `pack: carregado`? Se não, clique **Carregar**. Se sim, veja o "ultimo erro" e o `arcanist.log`. |
| "ultimo erro: ..." em laranja | Copie a mensagem inteira e mande pro agente de IA com "conserta isso". |
| "Carregar falhou" | Erro no `main.lua` (a mensagem diz a linha). Mande pro agente. |
| O botão não faz nada na hora | Ação no estado `ui` é **enfileirada** (não executa na hora). O erro real aparece no log como `[script] <ação> falhou`. |
| Não sei qual pack está carregado | Aba **SDK Lua** — o pack marcado com `<- atual` é o que está rodando. |
| Nada acontece e o log está limpo | Confira se o jogo está aberto **e logado** (o bot precisa do personagem em jogo). |

---

---

## 8. Checklist antes de entregar um pack

- [ ] Carrega com **log limpo** (sem `[script] erro`, sem `[lua][erro]`).
- [ ] Roda nos dois estados sem erro (o `main.lua` é executado 2x).
- [ ] Config do usuário persiste entre restarts (`sdk.storage`).
- [ ] Nenhuma ação disparada do estado `ui`.
- [ ] `wait` só dentro de `spawn`.
- [ ] Toggles/config sincronizam entre os estados (o loop do `logic` lê `ST.get`/`S.get`).
- [ ] Se é pack de produto: `ui.hide_host(true)` aplicado e tema salvo.
- [ ] Testado com o jogo aberto: Carregar → usar → Reload → conferir `arcanist.log`.

---

## 9. Exemplos e documentação

No pacote (ao lado do exe):

| Pack | O que mostra |
|---|---|
| `scripts/demo_ui/` | **O MODELO de produto** — stats, toggles persistidos, painel do RTC, tema, hide_host, alertas, coroutine. Comece por ele. |
| `scripts/heal/` | **Pack pronto:** cura automática (liga/desliga, magia e % salvos). |
| `scripts/hud/` | **Pack pronto:** painel de stats (HP, mana, cap, xp, condições). |
| `scripts/autoloot/` | **Pack pronto:** auto-loot com botões. |
| `scripts/radar/` | **Pack pronto:** monstros por perto + botão de atacar. |
| `scripts/examples/01_hello.lua` | O mínimo. |
| `scripts/examples/02_andar.lua` | Andar e navegar. |
| `scripts/examples/03_eventos.lua` | Eventos. |
| `scripts/examples/04_healer.lua` | Healer. |
| `scripts/examples/05_hud.lua` | HUD de produto. |
| `scripts/refill/` | Refill de poções pelo Supply Stash. |
| `scripts/hello/` | "Olá mundo". |
| `scripts/_teste/` | Auto-verificação da instalação. |

Documentação online (a mesma referência, formatada): **https://danzaio.github.io/arcanist-sdk/**
