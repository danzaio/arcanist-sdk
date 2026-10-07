-- 03_eventos.lua — reagir ao jogo com Engine.on(...).
--
-- Os handlers rodam no estado LOGIC (ponto unico de callback, no tick).
-- O painel le o resultado pelo sdk.shared.

local S  = require("sdk.shared")
local ui = game.overlay

Engine.on("Hp", function(ev)
  S.set("hp", ev.pct)
  if tonumber(ev.pct) < 40 then
    game.log("[aviso] HP baixo: " .. tostring(ev.pct) .. "%")
  end
end)

Engine.on("Mana", function(ev)
  S.set("mana", ev.pct)
end)

Engine.on("Level", function(ev)
  S.set("level", ev.level)
end)

Engine.on("PositionChange", function(ev)
  S.set("pos", ev.x .. "," .. ev.y .. "," .. ev.z)
end)

Engine.on("Conditions", function(ev)
  S.set("pz", ev.in_pz)
  S.set("poisoned", ev.poisoned)
end)

function ui.frame()
  ui.window("03 eventos", function()
    ui.text("HP:    " .. tostring(S.get("hp") or "?") .. "%")
    ui.text("Mana:  " .. tostring(S.get("mana") or "?") .. "%")
    ui.text("Level: " .. tostring(S.get("level") or "?"))
    ui.text("Pos:   " .. tostring(S.get("pos") or "?"))
    ui.separator()
    ui.text("Em PZ:  " .. (S.get("pz") == true and "sim" or "nao"))
    ui.text("Veneno: " .. (S.get("poisoned") == true and "sim" or "nao"))
  end)
end
