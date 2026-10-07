-- 01_hello.lua — o MENOR pack possivel: le o estado e desenha uma linha.
-- Pra usar: copie para scripts/meu_pack/main.lua e clique Carregar na aba "SDK Lua".

local E  = require("sdk.engine")
local ui = game.overlay

function ui.frame()
  ui.window("01 hello", function()
    local lp, err = E.localplayer()
    if lp then
      ui.text(("Ola! Pos %d,%d,%d   HP %d%%"):format(lp.x, lp.y, lp.z, lp.hp_pct))
    else
      ui.text("Sem personagem: " .. tostring(err))
    end
  end)
end
