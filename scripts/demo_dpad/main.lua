-- ============================================================================
-- scripts/demo_dpad/main.lua — exemplo de LAYOUT (grade, linhas, lista com scroll)
--
-- Referencia de layout (web): o painel de Waypoints do OTCv8 (o cliente do RubinOT
-- e' fork do OTCv8) usa LINHAS DE 3 BOTOES + lista + label de posicao:
--   modules/game_bot/panels/waypoints.lua  (Add|Edit|Remove / Goto|Use|UseWith / ...)
-- Aqui a mesma ideia: columns(3) para as linhas de acao, same_line para pares,
-- begin_child para a lista com scroll e uma grade 3x3 pro pad de direcoes.
-- ============================================================================
local ui = game.overlay

local escolha = "?"
local wp = { "32347,32251,10", "32350,32251,10", "32350,32255,10" }
local sel = 1

local function acao(nome)
  if ui.button(nome) then
    escolha = nome
    game.log("[dpad] acao: " .. nome)
  end
end

function ui.frame()
  ui.window("Waypoints", function()
    ui.text("ultima acao: " .. escolha)
    ui.separator()

    -- LINHA DE 3 ACOES (padrao OTCv8): Add | Edit | Remove
    ui.columns(3, "##acoes1", false)
    acao("Add") ui.next_column()
    acao("Edit") ui.next_column()
    acao("Remove")
    ui.columns(1)

    -- LINHA DE 3 COMANDOS: Goto | Use | UseWith
    ui.columns(3, "##acoes2", false)
    acao("Goto") ui.next_column()
    acao("Use") ui.next_column()
    acao("UseWith")
    ui.columns(1)

    ui.separator()

    -- GRADE 3x3 (o "D-pad" de direcoes): center/south/down/up/east/west...
    ui.columns(3, "##pad", false)
    local dirs = { "NW", "N", "NE", "W", "CENTER", "E", "SW", "S", "SE" }
    for i, d in ipairs(dirs) do
      if ui.button(d) then
        escolha = d
        game.log("[dpad] direcao: " .. d)
      end
      if i % 3 ~= 0 then ui.next_column() end
    end
    ui.columns(1)

    ui.separator()

    -- LISTA com scroll (como a TextList do OTCv8): begin_child com altura fixa
    ui.text("Waypoints:")
    if ui.begin_child("##lista", 0, 70, true) then
      for i, w in ipairs(wp) do
        if ui.selectable(w, i == sel) then
          sel = i
          escolha = "wp " .. i
        end
      end
    end
    ui.end_child()

    -- Botoes na MESMA linha, com offset (antes: sempre um embaixo do outro).
    if ui.button("esquerda") then escolha = "esquerda" end
    ui.same_line(200)
    if ui.button("direita") then escolha = "direita" end

    ui.separator()
    -- Espaco disponivel na janela (pra calcular alinhamentos).
    local w, h = ui.get_content_region_avail()
    ui.text(("espaco livre: %dx%d"):format(math.floor(w), math.floor(h)))
  end)
end
