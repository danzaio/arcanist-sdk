-- 02_andar.lua — COROUTINE: escreva em linha reta e use wait(ms) pra pausar.
--
-- Importante: coroutines/timers vivem no estado LOGIC (onde o tick acontece).
-- O painel (ui.frame) roda no estado ui — os dois conversam pelo sdk.shared.

local E  = require("sdk.engine")
local L  = require("sdk.localplayer")
local S  = require("sdk.shared")
local ui = game.overlay

-- Loop infinito em linha reta: cada wait() devolve o controle e volta no tick.
Engine.spawn(function()
  while true do
    wait(500)
    if S.get("andar_on") == true then
      local lp = E.localplayer()
      if lp then
        local ok, err = L.walk(lp.x + 1, lp.y, lp.z)
        if ok then
          S.set("voltas", (tonumber(S.get("voltas")) or 0) + 1)
        else
          game.log("andar falhou: " .. tostring(err))
        end
      end
    end
  end
end)

function ui.frame()
  ui.window("02 andar", function()
    local on = (S.get("andar_on") == true)
    local new_on = ui.checkbox("Andar (1 passo a leste)", on)
    if new_on ~= on then
      S.set("andar_on", new_on)
    end
    ui.text("Passos dados: " .. tostring(S.get("voltas") or 0))
  end)
end
