-- ============================================================================
-- scripts/demo_ui/main.lua — EXEMPLO DE UI/UX PRO USUARIO FINAL
--
-- Este pack e' o ponto de partida do socio. Ele mostra, junto e funcionando:
--   1. a UI do bot (abas) sai da frente SOZINHA quando o pack desenha janela
--   2. sdk.storage                    -> as escolhas do usuario SOBREVIVEM ao restart
--   3. H.list() + H.get/H.set         -> painel de config do RTC GERADO DO CATALOGO
--   4. ui.table / collapsing / child  -> layout de produto sem boilerplate
--   5. Engine.spawn + wait            -> feature que roda sozinha no estado logic
--   6. game.alert                     -> aviso na tela pro usuario final
--
-- Pra usar: copie esta pasta pra scripts/meu_bot/ e mude o que quiser.
-- ============================================================================

local E  = require("sdk.engine")
local L  = require("sdk.localplayer")
local T  = require("sdk.tools")
local H  = require("sdk.helper")
local ST = require("sdk.storage")
local S  = require("sdk.shared")
local ui = game.overlay

-- ---------------------------------------------------------------------------
-- 1) CONFIGURACAO: le do DISCO (com defaults) e grava quando o usuario mexe
-- ---------------------------------------------------------------------------
local cfg = {
  auto_loot = (ST.get("auto_loot") == true),
  auto_heal = (ST.get("auto_heal") == true),
  heal_pct  = tonumber(ST.get("heal_pct")) or 60,
  loot_ms   = tonumber(ST.get("loot_ms")) or 2000,
}

-- Prova viva de persistencia: cada carregamento incrementa o contador no DISCO.
-- ATENCAO: main.lua roda nos DOIS estados (logic e ui) — sem o guard abaixo o
-- contador subiria de 2 em 2. Guarde qualquer escrita de load com HOST_STATE.
if HOST_STATE == "logic" then
  local sessoes = (tonumber(ST.get("sessoes")) or 0) + 1
  ST.set("sessoes", sessoes)
  S.set("sessoes", sessoes)
end

-- ---------------------------------------------------------------------------
-- 2) FEATURE: roda sozinha no estado logic (coroutine com wait)
-- ---------------------------------------------------------------------------
Engine.spawn(function()
  while true do
    -- Le do ST a cada volta: o que o usuario mexe na janela (estado ui) chega
    -- aqui na hora — as variaveis `cfg` de cada estado NAO se cruzam.
    wait(tonumber(ST.get("loot_ms")) or 2000)

    if ST.get("auto_loot") == true then
      local ok, err = T.quickloot()
      if not ok then S.set("ultimo_erro", tostring(err)) end
    end

    if ST.get("auto_heal") == true then
      local lp = E.localplayer()
      local limiar = tonumber(ST.get("heal_pct")) or 60
      if lp and lp.hp_pct < limiar then
        local ok = L.say("exura")
        if ok then game.alert("HP em " .. lp.hp_pct .. "% - curei") end
      end
    end
  end
end)

-- ---------------------------------------------------------------------------
-- 3) UI — todo frame, no estado ui
-- ---------------------------------------------------------------------------
function ui.frame()
  ui.window("Meu Bot", function()

    -- (a) stats numa tabela
    local lp = E.localplayer()
    if lp then
      ui.table("##stats", { "Pos", "HP", "Mana", "Nivel" }, { {
        ("%d,%d,%d"):format(lp.x, lp.y, lp.z),
        ("%d%%"):format(lp.hp_pct),
        ("%d%%"):format(lp.mana_pct),
        tostring(lp.level),
      } })
    else
      ui.text("sem personagem")
    end

    ui.separator()

    -- (b) automacao (com persistencia)
    ui.collapsing("Automacao", function()
      local v1 = ui.checkbox("Auto-loot", cfg.auto_loot)
      if v1 ~= cfg.auto_loot then
        cfg.auto_loot = v1
        ST.set("auto_loot", v1)
        game.alert(v1 and "Auto-loot LIGADO" or "Auto-loot desligado")
      end

      local v2 = ui.checkbox("Auto-heal (exura)", cfg.auto_heal)
      if v2 ~= cfg.auto_heal then
        cfg.auto_heal = v2
        ST.set("auto_heal", v2)
      end

      if cfg.auto_heal then
        local pct = ui.slider("Curar abaixo de (%)", cfg.heal_pct, 10, 95)
        if pct ~= cfg.heal_pct then
          cfg.heal_pct = pct
          ST.set("heal_pct", pct)
        end
      end

      local ms = ui.slider("Checar loot a cada (ms)", cfg.loot_ms, 500, 10000)
      if ms ~= cfg.loot_ms then
        cfg.loot_ms = ms
        ST.set("loot_ms", ms)
      end
    end)

    -- (c) CONFIG DO RTC gerada do catalogo: o socio nao precisa saber os nomes
    ui.collapsing("Auto do RTC", function()
      local por_grupo, ordem = {}, {}
      for _, f in ipairs(H.list()) do
        if not por_grupo[f.group] then
          por_grupo[f.group] = {}
          ordem[#ordem + 1] = f.group
        end
        table.insert(por_grupo[f.group], f)
      end

      for _, grupo in ipairs(ordem) do
        ui.collapsing(grupo, function()
          for _, f in ipairs(por_grupo[grupo]) do
            local atual = H.get(f.name)
            if f.type == "u8" and f.max == 1 then
              local novo = ui.checkbox(f.label, atual ~= 0)
              if novo ~= (atual ~= 0) then
                H.set(f.name, novo and "1" or "0")
                game.alert(f.name .. " = " .. (novo and "1" or "0"))
              end
            else
              local novo = ui.slider(f.name, atual, f.min, f.max)
              if novo ~= atual then
                H.set(f.name, tostring(novo))
              end
              ui.tooltip(f.label .. " (" .. f.min .. ".." .. f.max .. ")")
            end
          end
        end)
      end
    end)

    -- (d) ferramentas rapidas
    ui.collapsing("Ferramentas", function()
      if ui.button("Quickloot agora") then
        local ok, err = T.quickloot()
        game.alert(ok and "Loot ok" or ("Falhou: " .. tostring(err)))
      end
      ui.same_line()
      if ui.button("Parar") then
        L.stop()
        game.alert("Andar cancelado")
      end
    end)

    -- (e) aparencia: o usuario final escolhe o tema (persistido)
    ui.collapsing("Aparencia", function()
      local temas = ui.themes()
      local atual = ST.get("tema") or "moonlight"
      local idx = 1
      for i, t in ipairs(temas) do
        if t == atual then idx = i end
      end
      local novo = ui.combo("Tema", temas, idx)
      if novo ~= idx then
        local nome = temas[novo]
        ui.theme(nome)
        ST.set("tema", nome)
        game.alert("Tema: " .. nome)
      end
    end)

    -- (f) rodape: quantas vezes o bot ja' carregou (persistido em disco)
    ui.text("sessoes (persistido): " .. tostring(S.get("sessoes") or "?"))

    local err = S.get("ultimo_erro")
    if err then
      ui.color_text(1.0, 0.6, 0.3, "ultimo erro: " .. tostring(err))
    end
  end)
end

-- Aplica o tema que o usuario tinha salvo (roda quando a UI carrega)
if ST.get("tema") then
  ui.theme(ST.get("tema"))
end
