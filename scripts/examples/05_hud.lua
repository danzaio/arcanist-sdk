-- 05_hud.lua — HUD minimalista: esconde a UI do arcanist e mostra SO um quadrinho.
--
-- Este e' o padrao "produto": o usuario final nao ve a nossa UI de debug, so a sua.
-- O botao "Mostrar arcanist" traz a UI do host de volta (importante: sem uma saida
-- de emergencia, esconder o host deixa o usuario sem acesso as abas do bot).

local E  = require("sdk.engine")
local ST = require("sdk.storage")
local ui = game.overlay

local escondido = (ST.get("hud_host_escondido") == true)

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

    ui.separator()
    local novo = ui.checkbox("Esconder UI do arcanist", escondido)
    if novo ~= escondido then
      escondido = novo
      ST.set("hud_host_escondido", novo)
      ui.hide_host(novo)
    end
  end)
end

if escondido then
  ui.hide_host(true)
end
