-- ============================================================================
-- scripts/hud/main.lua — painel de stats (pack pronto)
-- Mostra nome, nivel, posicao, HP, mana, cap, xp e condicoes ativas.
-- ============================================================================
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
