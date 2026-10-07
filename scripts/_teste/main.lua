-- ============================================================================
-- scripts/_teste/main.lua — VERIFICACAO AO VIVO (autonomo) + SCAN de vitais.
-- Executa a cadeia inteira sozinho e loga cada resultado em [teste].
-- Seguro: so le, fala uma vez, da 1 passo e CANCELA ataque (attack(0)).
-- ============================================================================

local E  = require("sdk.engine")
local L  = require("sdk.localplayer")
local T  = require("sdk.tools")
local C  = require("sdk.containers")
local S  = require("sdk.shared")
local ui = game.overlay

game.log("[teste] pack carregado (HOST_STATE=" .. tostring(HOST_STATE) .. ")")

Engine.on("PositionChange", function(ev)
  S.set("ultima_pos", ev.x .. "," .. ev.y .. "," .. ev.z)
  game.log("[teste] EVENTO PositionChange -> " .. ev.x .. "," .. ev.y .. "," .. ev.z)
end)

Engine.on("Hp", function(ev)
  game.log("[teste] EVENTO Hp -> " .. tostring(ev.pct) .. "% (type=" .. type(ev.pct) .. ")")
end)

Engine.on("Conditions", function(ev)
  game.log("[teste] EVENTO Conditions -> pz=" .. tostring(ev.in_pz) .. " (type=" .. type(ev.in_pz) .. ")")
end)

-- ===================== SCAN: achar o offset de vitais =====================
-- Le o LP pelo game.dbg e procura o blob (hp/hpmax/mana/manamax/level/soul/cap)
-- dentro de LP+0x000..0x3000. Pontua candidatos pelo formato do struct.
local function scan_vitais()
  local dbg = game.dbg
  local g = dbg.game_va()
  local s, e1 = dbg.read_bytes(g + 0x628, 8)
  if not s then
    game.log("[teste] SCAN: leitura do LP falhou: " .. tostring(e1))
    return nil
  end
  local lp_addr = string.unpack("<J", s)
  game.log(string.format("[teste] SCAN: Game=0x%X LP=0x%X", g, lp_addr))
  if lp_addr == 0 then
    game.log("[teste] SCAN: LP=0 (fora do mundo)")
    return nil
  end

  local raw, e2 = dbg.read_bytes(lp_addr, 0x3000)
  if not raw then
    game.log("[teste] SCAN: leitura do LP+0x3000 falhou: " .. tostring(e2))
    return nil
  end

  local function d(o) return string.unpack("<d", raw, o + 1) end
  local function inteiro(v) return v == v and v >= 0 and v <= 1e12 and (v % 1) == 0 end

  local achados = {}
  for o = 0, 0x3000 - 0x80, 8 do
    local hp, hpmax, cap = d(o), d(o + 0x08), d(o + 0x10)
    local xp, lvl = d(o + 0x28), d(o + 0x30)
    local mana, manamax = d(o + 0x40), d(o + 0x48)
    local soul = d(o + 0x70)
    local score = 0
    if hp >= 1 and hp <= 1e6 and hpmax >= 1 and hpmax <= 1e6 and hp <= hpmax then score = score + 2 end
    if mana >= 0 and mana <= 1e6 and manamax >= 0 and manamax <= 1e6 and mana <= manamax then score = score + 2 end
    if lvl >= 1 and lvl <= 1000 and inteiro(lvl) then score = score + 2 end
    if soul >= 0 and soul <= 1000 and inteiro(soul) then score = score + 1 end
    if cap >= 0 and cap <= 1e6 then score = score + 1 end
    if xp >= 0 and xp <= 1e12 then score = score + 1 end
    if score >= 6 then
      achados[#achados + 1] = string.format(
        "LP+0x%03X score=%d hp=%.0f/%.0f lvl=%.0f mana=%.0f/%.0f cap=%.0f xp=%.0f soul=%.0f",
        o, score, hp, hpmax, lvl, mana, manamax, cap, xp, soul)
    end
  end

  game.log("[teste] SCAN: " .. #achados .. " candidato(s) com score>=6")
  for i = 1, math.min(#achados, 6) do
    game.log("[teste]   " .. achados[i])
  end

  -- estados (u32) perto do offset antigo (0xAE8) e do novo, se houver
  local u32 = {}
  for o = 0xA00, 0xB80, 4 do
    local v = string.unpack("<I", raw, o + 1)
    if v ~= 0 and v ~= 0xFFFFFFFF then
      u32[#u32 + 1] = string.format("LP+0x%03X=0x%08X", o, v)
    end
  end
  game.log("[teste] SCAN states u32 (0xA00..0xB80): " .. table.concat(u32, " "))
  return lp_addr
end

-- =========================== sequencia principal ===========================
Engine.spawn(function()
  wait(1500)

  local lp_addr = scan_vitais()

  local lp, err = E.localplayer()
  if lp then
    game.log(("[teste] 1. localplayer OK -> pos %d,%d,%d  hp %d%%  mana %d%%  lvl %d  pz=%s"):format(
      lp.x, lp.y, lp.z, lp.hp_pct, lp.mana_pct, lp.level, tostring(lp.in_pz)))
    game.log("[teste] 1b. tipos: hp_pct=" .. type(lp.hp_pct) .. " in_pz=" .. type(lp.in_pz))
  else
    game.log("[teste] 1. localplayer FALHOU: " .. tostring(err))
  end

  local cs = E.creatures()
  local monstros, players = 0, 0
  for _, c in ipairs(cs) do
    if c.is_monster then monstros = monstros + 1 end
    if c.is_player then players = players + 1 end
  end
  game.log("[teste] 2. creatures -> " .. #cs .. " (monstros=" .. monstros .. " players=" .. players .. ")")
  game.log("[teste] 3. target atual -> " .. tostring(E.target()))

  local n, nerr = C.count_item(3031)
  game.log("[teste] 4. count_item(gold 3031) -> " .. tostring(n) .. " " .. tostring(nerr))

  -- PROBE dos slots do CORPO: qual offset tem itens de verdade?
  -- Conta ponteiros nao-nulos cujo id em +0x6C e plausivel (1..100000).
  local function body_slots(base, off)
    if not base then return "sem LP" end
    local s, e = game.dbg.read_bytes(base + off, 13 * 8)
    if not s then return "leitura falhou: " .. tostring(e) end
    local ocupados, validos = 0, 0
    for i = 0, 12 do
      local p = string.unpack("<J", s, i * 8 + 1)
      if p ~= 0 then
        ocupados = ocupados + 1
        local ib = game.dbg.read_bytes(p + 0x6C, 4)
        if ib then
          local id = string.unpack("<I", ib)
          if id > 0 and id < 100000 then validos = validos + 1 end
        end
      end
    end
    return ocupados .. " nao-nulos, " .. validos .. " com id plausivel"
  end
  game.log("[teste] 4b. CORPO LP+0xA48 (novo): " .. body_slots(lp_addr, 0xA48))
  game.log("[teste] 4c. CORPO LP+0x9B0 (antigo): " .. body_slots(lp_addr, 0x9B0))

  wait(1500)
  local ok_say, err_say = L.say("sdk teste ao vivo")
  game.log("[teste] 5. say -> " .. tostring(ok_say) .. " " .. tostring(err_say))

  wait(2000)
  local lp2 = E.localplayer()
  if lp2 then
    local ok_w, err_w = L.walk(lp2.x + 1, lp2.y, lp2.z)
    game.log("[teste] 6. walk(+1 leste) -> " .. tostring(ok_w) .. " " .. tostring(err_w))
  end

  wait(2500)
  local lp3 = E.localplayer()
  if lp3 then
    game.log(("[teste] 7. pos DEPOIS do walk -> %d,%d,%d"):format(lp3.x, lp3.y, lp3.z))
  end

  local ok_atk, err_atk = L.attack(0)
  game.log("[teste] 8. attack(0)/cancelar -> " .. tostring(ok_atk) .. " " .. tostring(err_atk))

  wait(1000)
  local ok_ql, err_ql = T.quickloot()
  game.log("[teste] 9. quickloot -> " .. tostring(ok_ql) .. " " .. tostring(err_ql))

  local ok_st, err_st = L.stop()
  game.log("[teste] 10. stop -> " .. tostring(ok_st) .. " " .. tostring(err_st))

  -- ================== HELPER/RTC: catalogo + leitura ==================
  local H = require("sdk.helper")
  local campos = H.list()
  game.log("[teste] 11. H.list() -> " .. #campos .. " campos")
  local grupos = {}
  for _, f in ipairs(campos) do
    grupos[f.group] = (grupos[f.group] or 0) + 1
  end
  local gs = {}
  for g, n in pairs(grupos) do gs[#gs + 1] = g .. "=" .. n end
  game.log("[teste] 11b. grupos: " .. table.concat(gs, " "))
  local ok_g, v_g = pcall(H.get, "auto_target")
  game.log("[teste] 11c. H.get(auto_target) -> " .. tostring(ok_g) .. " " .. tostring(v_g))
  local ok_g2, v_g2 = pcall(H.get, "auto_target_mode")
  game.log("[teste] 11d. H.get(auto_target_mode) -> " .. tostring(ok_g2) .. " " .. tostring(v_g2))
  local ok_g3, v_g3 = pcall(H.get, "shooter_enable")
  game.log("[teste] 11e. H.get(shooter_enable) -> " .. tostring(ok_g3) .. " " .. tostring(v_g3))

  -- ================== N.go MULTI-TILE (pathfinding do cliente) ==================
  wait(1000)
  local lpA = E.localplayer()
  if lpA then
    local ok_go, err_go = require("sdk.navigator").go(lpA.x + 5, lpA.y, lpA.z)
    game.log("[teste] 12. N.go(+5 tiles) -> " .. tostring(ok_go) .. " " .. tostring(err_go))
  end
  wait(4000)
  local lpB = E.localplayer()
  if lpB and lpA then
    local andou = lpB.x - lpA.x
    game.log("[teste] 12b. pos depois do go -> " .. lpB.x .. "," .. lpB.y .. "," .. lpB.z ..
             " (andou " .. andou .. " tiles; 1 = so um passo, >1 = pathfinding do cliente)")
  end

  wait(500)
  game.log("[teste] === FIM DA VERIFICACAO ===")
end)

function ui.frame()
  ui.window("Teste ao vivo", function()
    local lp = E.localplayer()
    if lp then
      ui.text(("Pos %d,%d,%d  HP %d%%  lvl %d"):format(lp.x, lp.y, lp.z, lp.hp_pct, lp.level))
      ui.progress(lp.hp_pct)
    else
      ui.text("sem personagem")
    end
    ui.separator()
    ui.text("Evento pos: " .. tostring(S.get("ultima_pos") or "(nenhum ainda)"))
    ui.text("Criaturas: " .. #E.creatures())
    ui.text("Target: " .. tostring(E.target()))
  end)
end
