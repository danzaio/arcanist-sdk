-- 04_healer.lua — uma feature UTIL: healer simples, escrito so em Lua.
--
-- Regra: se HP < 60%, fala "exura". Confere a cada 1s, numa coroutine.
-- Comeca DESLIGADO (liga no painel) — nada acontece sozinho.

local E  = require("sdk.engine")
local L  = require("sdk.localplayer")
local S  = require("sdk.shared")
local ui = game.overlay

local HP_MIN = 60

Engine.spawn(function()
  while true do
    wait(1000)
    if S.get("heal_on") == true then
      local lp = E.localplayer()
      if lp and tonumber(lp.hp_pct) < HP_MIN then
        local ok, err = L.say("exura")
        S.set("heal_status", ok and ("curei com " .. tostring(lp.hp_pct) .. "%")
                                 or ("falhou: " .. tostring(err)))
      end
    end
  end
end)

function ui.frame()
  ui.window("04 healer", function()
    local on = (S.get("heal_on") == true)
    local new_on = ui.checkbox("Ligado", on)
    if new_on ~= on then
      S.set("heal_on", new_on)
      game.log("[healer] " .. (new_on and "ligado" or "desligado"))
    end
    ui.text("Cura abaixo de " .. HP_MIN .. "% (fala 'exura')")
    ui.separator()
    ui.text("Status: " .. tostring(S.get("heal_status") or "nunca rodou"))
  end)
end
