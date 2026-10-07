-- ============================================================================
-- scripts/heal/main.lua — cura automatica (pack pronto)
-- Liga/desliga, magia e limiar ficam SALVOS (sdk.storage).
-- ============================================================================
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
