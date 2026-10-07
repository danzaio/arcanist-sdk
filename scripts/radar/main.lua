-- ============================================================================
-- scripts/radar/main.lua — monstros por perto (pack pronto)
-- Lista os monstros na tela (mais perto primeiro) com botao de atacar.
-- ============================================================================
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
