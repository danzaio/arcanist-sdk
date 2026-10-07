-- ============================================================================
-- scripts/hello/main.lua — pack de exemplo do SDK Lua (M1: walking skeleton).
--
-- Prova as 4 coisas de uma vez:
--   1. leitura   (sdk.engine.localplayer)
--   2. UI        (game.overlay: janela, texto, barra, botao)
--   3. acao      (sdk.navigator.go -> ActionQueue -> executor)
--   4. evento    (Engine.on -> poller de estado)
--
-- O pack roda nos DOIS estados do host:
--   logic -> os eventos e as acoes vivem aqui (Engine.on, N.go sincrono)
--   ui    -> so o ui.frame() importa (desenha; cliques ENFILEIRAM acoes)
-- ============================================================================

local E  = require("sdk.engine")
local N  = require("sdk.navigator")
local S  = require("sdk.shared")
local ui = game.overlay

-- Os dois estados Lua NAO compartilham variaveis: o que o logic aprende chega
-- na UI pelo sdk.shared (KV em memoria).
Engine.on("PositionChange", function(ev)
  S.set("last_pos", ev.x .. "," .. ev.y .. "," .. ev.z)
end)

function ui.frame()
  ui.window("Hello SDK", function()
    local lp, err = E.localplayer()
    if lp then
      ui.text(("Pos %d,%d,%d   HP %d%%"):format(lp.x, lp.y, lp.z, lp.hp_pct))
      ui.progress(lp.hp_pct)
    else
      ui.text("Sem personagem: " .. tostring(err))
    end

    if ui.button("Passo (leste)") then
      local lp = E.localplayer()
      local ok, werr
      if lp then
        ok, werr = N.go(lp.x + 1, lp.y, lp.z)
      else
        ok, werr = false, "sem personagem"
      end
      game.log(ok and "passo ok" or ("passo falhou: " .. tostring(werr)))
    end

    ui.separator()
    ui.text("Evento PositionChange: " .. (S.get("last_pos") or "(ainda nao)"))
  end)
end
