-- ============================================================================
-- scripts/1_painel/main.lua — UI básica de produto (pack de teste do Dan)
-- Auto-carrega junto com o bot. Layout: cabeçalho, barras, tabela, ações e tema.
-- ============================================================================
local E  = require("sdk.engine")
local L  = require("sdk.localplayer")
local T  = require("sdk.tools")
local ST = require("sdk.storage")
local ui = game.overlay

local cfg = {
  tema = ST.get("tema") or "moonlight",
}

-- contador de sessoes (persistido; guard pro main.lua que roda 2x)
if HOST_STATE == "logic" then
  ST.set("sessoes", (tonumber(ST.get("sessoes")) or 0) + 1)
end

function ui.frame()
  ui.window("Painel", function()
    local lp = E.localplayer()

    -- cabecalho
    if lp then
      local nome = (lp.name ~= nil and lp.name ~= "") and lp.name or "personagem"
      ui.text(("%s   -   nivel %d"):format(nome, lp.level))
    else
      ui.color_text(1.0, 0.6, 0.3, "sem personagem - entre no jogo")
    end
    ui.separator()

    -- barras de HP / Mana
    local hp = lp and lp.hp_pct or 0
    local mp = lp and lp.mana_pct or 0
    ui.text(("HP  %d%%"):format(hp))
    ui.progress(hp)
    ui.text(("Mana  %d%%"):format(mp))
    ui.progress(mp)
    ui.separator()

    -- tabela de stats
    if lp then
      ui.table("##stats", { "Pos", "Cap", "XP", "Stamina" }, { {
        ("%d,%d,%d"):format(lp.x, lp.y, lp.z),
        tostring(lp.cap),
        tostring(lp.xp),
        tostring(lp.stamina),
      } })

      -- condicoes ativas
      local cond = {}
      if lp.poisoned then cond[#cond + 1] = "veneno" end
      if lp.paralyzed then cond[#cond + 1] = "para" end
      if lp.hasted then cond[#cond + 1] = "haste" end
      if lp.manashielded then cond[#cond + 1] = "manashield" end
      if lp.in_pz then cond[#cond + 1] = "PZ" end
      if #cond > 0 then
        ui.color_text(1.0, 0.75, 0.2, table.concat(cond, "  |  "))
      end
    end

    ui.separator()

    -- acoes rapidas (a UI enfileira; o logic executa)
    if ui.button("Lootar agora") then
      local ok, err = T.quickloot()
      game.alert(ok and "Loot ok" or ("Falhou: " .. tostring(err)))
    end
    ui.same_line()
    if ui.button("Parar") then
      L.stop()
      game.alert("Andar cancelado")
    end
    ui.same_line()
    if ui.button("Fechar janelas") then
      T.close_all()
    end

    ui.separator()

    -- aparencia (tema persistido + esconder a UI do bot com volta)
    ui.collapsing("Aparencia", function()
      local temas = ui.themes()
      local idx = 1
      for i, t in ipairs(temas) do
        if t == cfg.tema then idx = i end
      end
      local novo = ui.combo("Tema", temas, idx)
      if novo ~= idx then
        cfg.tema = temas[novo]
        ui.theme(cfg.tema)
        ST.set("tema", cfg.tema)
        game.alert("Tema: " .. cfg.tema)
      end
      ui.tooltip("Troca o tema do bot inteiro (fica salvo)")
    end)

    ui.text("sessoes: " .. tostring(ST.get("sessoes") or "?"))
  end)
end

-- aplica o tema que ficou salvo (roda quando a UI carrega)
if HOST_STATE == "ui" and ST.get("tema") then
  ui.theme(ST.get("tema"))
end
