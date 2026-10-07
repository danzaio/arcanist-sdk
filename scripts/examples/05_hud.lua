-- 05_hud.lua — HUD minimalista: so o teu quadrinho, sem a UI do bot.
--
-- Este e' o padrao "produto": a UI do bot (abas) sai da frente SOZINHA quando o
-- pack desenha uma janela. INSERT traz ela de volta quando quiser (gerenciar
-- packs/debug) — nao precisa de nenhuma chamada no script.

local E  = require("sdk.engine")
local ui = game.overlay

function ui.frame()
  ui.window("HUD", function()
    local lp = E.localplayer()
    if lp then
      ui.text(("HP %d%%   MP %d%%"):format(lp.hp_pct, lp.mana_pct))
      ui.progress(lp.hp_pct)
      ui.text(("Pos %d,%d,%d"):format(lp.x, lp.y, lp.z))
    else
      ui.text("sem personagem")
    end
  end)
end
