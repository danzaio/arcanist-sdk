-- ============================================================================
-- scripts/refill/main.lua — M3: uma feature UTIL escrita so em Lua.
--
-- Refill de potions: de tempo em tempo conta as potions no inventario; se cair
-- abaixo do minimo, saca a diferenca do Supply Stash (sdk.stash.withdraw).
--
-- Seguranca: comeca DESLIGADO (liga pelo painel) e toda acao e' fail-closed —
-- sem container aberto / sem stash, ele so reporta o motivo e nao faz nada.
-- ============================================================================

local C  = require("sdk.containers")
local S  = require("sdk.stash")
local SH = require("sdk.shared")
local ui = game.overlay

local POTION_ID = 266      -- mana potion (troque pelo id que voce usa)
local MIN_COUNT = 50       -- abaixo disso, saca do stash
local CHECK_MS  = 5000     -- de quanto em quanto tempo confere

local function check()
  if SH.get("refill_on") ~= true then
    SH.set("refill_status", "desligado")
    return
  end

  local n = C.count_item(POTION_ID)
  if n == nil then
    SH.set("refill_status", "sem container aberto (abra a mochila)")
    return
  end

  SH.set("refill_count", n)
  if n < MIN_COUNT then
    local need = MIN_COUNT - n
    local ok, err = S.withdraw(POTION_ID, need)
    if ok then
      SH.set("refill_status", "sacei " .. need .. " do stash")
    else
      SH.set("refill_status", "falhou: " .. tostring(err))
    end
  else
    SH.set("refill_status", "ok")
  end
end

Engine.every(CHECK_MS, check)

function ui.frame()
  ui.window("Refill de potions", function()
    local on = (SH.get("refill_on") == true)
    local new_on = ui.checkbox("Ligado", on)
    if new_on ~= on then
      SH.set("refill_on", new_on)
      game.log("[refill] " .. (new_on and "ligado" or "desligado"))
    end

    ui.text(("Potion %d   minimo %d   checa a cada %ds"):format(POTION_ID, MIN_COUNT, CHECK_MS / 1000))
    ui.text("No inventario: " .. tostring(SH.get("refill_count") or "?"))
    ui.separator()
    ui.text("Status: " .. tostring(SH.get("refill_status") or "nunca rodou"))
  end)
end
