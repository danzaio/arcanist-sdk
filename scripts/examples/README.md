# Exemplos do SDK Lua

Cada arquivo aqui é um **pack** pronto: copie para `scripts/<nome>/main.lua` e clique
**Carregar** na aba **SDK Lua** do arcanist.

| Arquivo | O que mostra |
|---|---|
| `01_hello.lua` | o mínimo: ler o estado e desenhar uma linha |
| `02_andar.lua` | **coroutine** (`Engine.spawn` + `wait`) com botão liga/desliga |
| `03_eventos.lua` | reagir ao jogo (`Engine.on` de Hp/Mana/Level/Posição/Condições) |
| `04_healer.lua` | feature útil: healer que fala `exura` abaixo de 60% |
| `05_hud.lua` | **HUD de produto**: esconde a UI do arcanist e mostra só o seu quadrinho |

**Exemplo completo (comece por ele):** `scripts/demo_ui/` — um bot com painel de verdade:
stats em tabela, toggles com persistência, **config do RTC gerada do catálogo** e o botão
de esconder a nossa UI.

## O modelo mental (leia isto primeiro)

O seu `main.lua` roda em **dois lugares**:

| Estado | Thread | O que vive aqui |
|---|---|---|
| `logic` | do script (~20 ms) | `Engine.on`, timers, **coroutines** (`spawn`/`wait`), ações **síncronas** |
| `ui` | da GUI (por frame) | só o `ui.frame()` — desenha e **enfileira** ações |

Eles **não compartilham variáveis**:

```lua
local S  = require("sdk.shared")   -- memória (some ao fechar)
local ST = require("sdk.storage")  -- DISCO (sobrevive ao restart) — use pra config
S.set("chave", 123)
ST.set("config_do_usuario", 123)
```

Pra saber onde você está: `HOST_STATE` (`"logic"` / `"ui"`) ou `game.is_ui`.

## Montando a UI do usuário final

```lua
local ui = game.overlay

function ui.frame()
  ui.window("Meu Bot", function()
    ui.table("##stats", {"Pos", "HP"}, {{"32370,32239,7", "100%"}})   -- tabela pronta
    ui.collapsing("Configuracoes", function()                          -- seção colapsável
      local v = ui.checkbox("Ligado", ST.get("ligado") == true)
      if v ~= (ST.get("ligado") == true) then ST.set("ligado", v) end  -- persiste!
      local pct = ui.slider("Curar em %", tonumber(ST.get("pct")) or 60, 10, 95)
      if pct ~= (tonumber(ST.get("pct")) or 60) then ST.set("pct", pct) end
    end)
    if ui.button("Fazer") then game.alert("feito!") end                -- toast
  end)
end
```

**Esconder a nossa UI de debug** (o usuário final só vê a sua):

```lua
ui.hide_host(true)          -- esconde a janela do arcanist
ui.host_hidden()            -- true se está escondida
```

> ⚠️ Deixe sempre um jeito de voltar (um checkbox na SUA janela) — senão o usuário fica
> sem acesso às abas do bot.

Widgets: `window`, `text`, `text_wrapped`, `bullet`, `separator`, `same_line`, `spacing`,
`tooltip`, `color_text`, `progress`, `button`, `checkbox`, `input`, `slider`, `combo`,
`selectable`, `collapsing`, `child`, `table`, `hide_host`, `host_hidden`.

## Configurando o auto do RTC (helper)

Não precisa saber os nomes dos campos — **leia o catálogo**:

```lua
local H = require("sdk.helper")
for _, f in ipairs(H.list()) do          -- 49 campos: name, label, group, type, min, max
  print(f.group, f.name, f.min, f.max, f.label)
end
H.get("auto_target")        -- valor atual (0/1)
H.set("auto_target", "1")   -- liga o auto-target
```

O `scripts/demo_ui/main.lua` monta o painel inteiro do RTC a partir desse catálogo.

## Coroutines — o jeito de escrever feature

```lua
Engine.spawn(function()
  while true do
    wait(1000)              -- devolve o controle; volta no próximo tick
    game.log("1 segundo")
  end
end)
```

`wait(ms)` só funciona **dentro** de `Engine.spawn` (fora dá erro de propósito).

## Ações devolvem ok, err

```lua
local ok, err = require("sdk.localplayer").say("oi")
if not ok then game.log("falhou: " .. tostring(err)) end
```

- `N.go(x,y,z)` = **pathfinding do cliente** (anda vários tiles, o mesmo do minimapa)
- `L.walk(x,y,z)` = 1 passo
- `L.attack(id)` = ataca (`0` cancela); `E.target()` = id do alvo atual

## Erros não derrubam o bot

Handler que quebra é isolado e logado — os outros continuam. `game.log(...)` aparece no
`arcanist.log` (ao lado do exe) e no log da GUI.
