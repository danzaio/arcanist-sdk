-- ============================================================================
-- scripts/autoloot/main.lua — auto-loot com botoes (pack pronto)
-- ============================================================================
local T  = require("sdk.tools")
local ST = require("sdk.storage")
local S  = require("sdk.shared")
local ui = game.overlay

local cfg = {
  ligado    = (ST.get("ligado") == true),
  intervalo = tonumber(ST.get("intervalo")) or 1500,
}

-- FEATURE (estado logic). Le do ST a cada volta (toggle da UI chega na hora).
spawn(function()
  while true do
    wait(tonumber(ST.get("intervalo")) or 1500)
    if ST.get("ligado") == true then
      local ok, err = T.quickloot()
      if ok then
        S.set("loots", (tonumber(S.get("loots")) or 0) + 1)
      else
        S.set("ultimo_erro", tostring(err))
      end
    end
  end
end)

-- UI (estado ui)
function ui.frame()
  ui.window("Auto-loot", function()
    local v = ui.checkbox("Lootar automaticamente", cfg.ligado)
    if v ~= cfg.ligado then
      cfg.ligado = v
      ST.set("ligado", v)
      game.alert(v and "Auto-loot LIGADO" or "Auto-loot desligado")
    end

    local ms = ui.slider("A cada (ms)", cfg.intervalo, 500, 5000)
    if ms ~= cfg.intervalo then
      cfg.intervalo = ms
      ST.set("intervalo", ms)
    end

    ui.separator()

    if ui.button("Lootar agora") then
      local ok, err = T.quickloot()
      game.alert(ok and "Loot ok" or ("Falhou: " .. tostring(err)))
    end

    ui.text("loots nesta sessao: " .. tostring(S.get("loots") or 0))
    local err = S.get("ultimo_erro")
    if err then ui.color_text(1.0, 0.6, 0.3, "ultimo erro: " .. tostring(err)) end
  end)
end
