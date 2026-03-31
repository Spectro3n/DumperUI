--[[
    DumperUI v1.1
    Módulo de interface para Dumper Pro — posicionamento corrigido + visual refinado
    Carrega via: local UI = loadstring(game:HttpGet("url"))()
    
    API retornada (inalterada):
        UI:GetConfig()         → tabela com todas as configs
        UI:SetFolder(name)     → atualiza campo de pasta
        UI:Log(msg, color)     → escreve no terminal
        UI:SetProgress(c, m)   → barra de progresso
        UI:SetStats(t)         → atualiza métricas
        UI:SetPhase(text)      → fase atual
        UI:SetRunning(bool)    → alterna Start/Stop + badge
        UI:SetBadge(text, col) → badge customizado
        UI:SetStatus(text)     → barra inferior
        UI:ClearLog()          → limpa terminal
        UI:ShowPage(n)         → 1=config, 2=scanner
        UI:Destroy()           → remove tudo
        
        UI.OnStart             → callback
        UI.OnStop              → callback
        UI.OnSaveInstance      → callback
]]

local TS      = game:GetService("TweenService")
local UIS     = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LP      = Players.LocalPlayer

for _, n in ipairs({"DPro", "DumperProV5", "DumperProUI"}) do
    pcall(function() CoreGui:FindFirstChild(n):Destroy() end)
    pcall(function() if gethui then gethui():FindFirstChild(n):Destroy() end end)
end

-- ═══════════════════════════════════════════
--  PALETTE
-- ═══════════════════════════════════════════

local P = {
    bg   = Color3.fromRGB(12, 12, 20),
    pnl  = Color3.fromRGB(18, 18, 30),
    card = Color3.fromRGB(26, 26, 40),
    elev = Color3.fromRGB(34, 34, 52),
    brd  = Color3.fromRGB(42, 42, 62),
    acc  = Color3.fromRGB(139, 92, 246),
    accH = Color3.fromRGB(167, 139, 250),
    ok   = Color3.fromRGB(16, 185, 129),
    err  = Color3.fromRGB(239, 68, 68),
    wrn  = Color3.fromRGB(245, 158, 11),
    inf  = Color3.fromRGB(56, 189, 248),
    t1   = Color3.fromRGB(226, 232, 240),
    t2   = Color3.fromRGB(148, 163, 184),
    t3   = Color3.fromRGB(75, 85, 105),
}

local logC = {
    white  = P.t1,
    green  = P.ok,
    red    = P.err,
    yellow = P.wrn,
    orange = Color3.fromRGB(251, 146, 60),
    gray   = P.t3,
    blue   = P.inf,
}

local Fr = Enum.Font.SourceSans
local Fm = Enum.Font.SourceSansSemibold
local Fb = Enum.Font.SourceSansBold
local Fc = Enum.Font.RobotoMono

-- ═══════════════════════════════════════════
--  CONFIG DEFAULTS
-- ═══════════════════════════════════════════

local config = {
    folder      = "",
    mode        = "safe",
    saveMode    = "individual",
    dumpLocal   = true,
    dumpModule  = true,
    dumpDisabled = true,
    scanNil     = true,
    scanGC      = true,
    scanReg     = true,
    scanThreads = false,
    scanRunning = true,
    scanLoaded  = true,
    scanConn    = true,
    scanAll     = false,
    dumpRemotes = true,
    dumpHooks   = true,
    dumpUI      = true,
    dumpInfo    = true,
    dumpConsts  = false,
    dumpUpvals  = false,
}

pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    config.folder = info and info.Name or ""
end)
if config.folder == "" then config.folder = "Game_" .. game.PlaceId end

local execName = "Unknown"
pcall(function() if identifyexecutor then execName = identifyexecutor() end end)

-- ═══════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════

local ti = function(d)
    return TweenInfo.new(d or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function mk(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then pcall(function() inst[k] = v end) end
    end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local function rnd(p, r)
    mk("UICorner", {CornerRadius = r or UDim.new(0, 6), Parent = p})
end
local function stk(p, c, th)
    return mk("UIStroke", {Color = c or P.brd, Thickness = th or 1, Parent = p})
end
local function pad(p, t, b, l, r)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
        PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r), Parent = p,
    })
end
local function lay(p, g)
    mk("UIListLayout", {Padding = UDim.new(0, g or 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p})
end

-- ═══════════════════════════════════════════
--  COMPONENTS
-- ═══════════════════════════════════════════

local function section(parent, text, order)
    local f = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
        LayoutOrder = order, Parent = parent,
    })
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 4),
        BackgroundTransparency = 1, Text = text:upper(),
        TextColor3 = P.t3, TextSize = 10, Font = Fb,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
    })
    mk("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = P.brd, BackgroundTransparency = 0.5,
        BorderSizePixel = 0, Parent = f,
    })
end

local function toggle(parent, label, key, order)
    local val = config[key]

    local row = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, LayoutOrder = order, Parent = parent,
    })

    local box = mk("Frame", {
        Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = val and P.acc or P.bg,
        BackgroundTransparency = val and 0 or 0.5, Parent = row,
    })
    rnd(box, UDim.new(0, 3))
    local boxStroke = stk(box, val and P.acc or P.brd)

    local check = mk("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = val and "✓" or "", TextColor3 = Color3.new(1, 1, 1),
        TextSize = 10, Font = Fb, Parent = box,
    })

    local lbl = mk("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1, Text = label, TextColor3 = val and P.t1 or P.t2,
        TextSize = 12, Font = Fr, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })

    row.MouseEnter:Connect(function()
        if not config[key] then TS:Create(box, ti(0.1), {BackgroundTransparency = 0.3}):Play() end
    end)
    row.MouseLeave:Connect(function()
        if not config[key] then TS:Create(box, ti(0.1), {BackgroundTransparency = 0.5}):Play() end
    end)

    row.MouseButton1Click:Connect(function()
        val = not val; config[key] = val
        TS:Create(box, ti(), {
            BackgroundColor3 = val and P.acc or P.bg,
            BackgroundTransparency = val and 0 or 0.5,
        }):Play()
        boxStroke.Color = val and P.acc or P.brd
        check.Text = val and "✓" or ""
        lbl.TextColor3 = val and P.t1 or P.t2
    end)
end

local function cards(parent, key, opts, order)
    local frame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1,
        LayoutOrder = order, Parent = parent,
    })

    local items = {}
    local gap = 6
    for i, opt in ipairs(opts) do
        local sel = config[key] == opt.id
        local card = mk("TextButton", {
            Size = UDim2.new(0.5, -gap / 2, 1, 0),
            Position = UDim2.new((i - 1) * 0.5, i == 1 and 0 or gap / 2, 0, 0),
            BackgroundColor3 = sel and P.elev or P.card,
            Text = "", AutoButtonColor = false, Parent = frame,
        })
        rnd(card)
        local s = stk(card, sel and P.acc or P.brd)

        local ttl = mk("TextLabel", {
            Size = UDim2.new(1, -12, 0, 18), Position = UDim2.new(0, 6, 0, 10),
            BackgroundTransparency = 1, Text = opt.title,
            TextColor3 = sel and P.t1 or P.t2, TextSize = 13, Font = Fb,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
        })
        mk("TextLabel", {
            Size = UDim2.new(1, -12, 0, 12), Position = UDim2.new(0, 6, 0, 30),
            BackgroundTransparency = 1, Text = opt.desc,
            TextColor3 = P.t3, TextSize = 10, Font = Fc,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
        })

        local radio = mk("Frame", {
            Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 8, 0, 50),
            BackgroundColor3 = sel and P.acc or P.brd, Parent = card,
        })
        rnd(radio, UDim.new(0, 5))

        if opt.badge then
            local bc = opt.badge == "SLOW" and P.wrn or P.inf
            local b = mk("TextLabel", {
                Size = UDim2.new(0, 36, 0, 14), Position = UDim2.new(1, -42, 0, 8),
                BackgroundColor3 = bc, BackgroundTransparency = 0.8,
                Text = opt.badge, TextColor3 = bc, TextSize = 9, Font = Fb, Parent = card,
            })
            rnd(b, UDim.new(0, 3))
        end

        items[i] = {btn = card, stk = s, ttl = ttl, radio = radio}
    end

    for i, it in ipairs(items) do
        it.btn.MouseButton1Click:Connect(function()
            config[key] = opts[i].id
            for j, it2 in ipairs(items) do
                local s = (j == i)
                TS:Create(it2.btn, ti(), {BackgroundColor3 = s and P.elev or P.card}):Play()
                it2.stk.Color = s and P.acc or P.brd
                it2.ttl.TextColor3 = s and P.t1 or P.t2
                TS:Create(it2.radio, ti(), {BackgroundColor3 = s and P.acc or P.brd}):Play()
            end
        end)
    end
end

-- ═══════════════════════════════════════════
--  SCREEN GUI
-- ═══════════════════════════════════════════

local gui = mk("ScreenGui", {
    Name = "DPro", ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ResetOnSpawn = false,
})
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui); gui.Parent = CoreGui
    elseif gethui then gui.Parent = gethui()
    else gui.Parent = CoreGui end
end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

-- ═══════════════════════════════════════════
--  MAIN WINDOW
-- ═══════════════════════════════════════════

local WIN_W, WIN_H = 660, 430
local HDR_H = 42
local SIDE_W = 42
local fullSize = UDim2.new(0, WIN_W, 0, WIN_H)

local win = mk("Frame", {
    Size = fullSize,
    Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
    BackgroundColor3 = P.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Parent = gui,
})
rnd(win, UDim.new(0, 10))
stk(win)

-- accent stripe
mk("Frame", {
    Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = P.acc,
    BorderSizePixel = 0, Parent = win,
})

-- ═══════════════════════════════════════════
--  HEADER  (buttons laid out right→left, no overlap)
-- ═══════════════════════════════════════════
--  Layout verification (window 660 px wide):
--    btnX     28 px  @ (1,-36)  → pixels 624-652   ✓
--    btnMin   28 px  @ (1,-70)  → pixels 590-618   gap 6 ✓
--    btnStart 100 px @ (1,-180) → pixels 480-580   gap 10 ✓
--    btnSave  92 px  @ (1,-280) → pixels 380-472   gap 8 ✓
--    badge    52 px  @ (0,164)  → pixels 164-216   gap 164 ✓

local hdr = mk("Frame", {
    Size = UDim2.new(1, 0, 0, HDR_H), Position = UDim2.new(0, 0, 0, 2),
    BackgroundColor3 = P.pnl, BorderSizePixel = 0, Parent = win,
})
mk("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = P.brd, BorderSizePixel = 0, Parent = hdr,
})

mk("TextLabel", {
    Size = UDim2.new(0, 120, 1, 0), Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1, Text = "◆ DUMPER PRO",
    TextColor3 = P.t1, TextSize = 14, Font = Fb,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr,
})
mk("TextLabel", {
    Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(0, 136, 0, 1),
    BackgroundTransparency = 1, Text = "v5",
    TextColor3 = P.t3, TextSize = 9, Font = Fc,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = hdr,
})

local badge = mk("TextLabel", {
    Size = UDim2.new(0, 52, 0, 20), Position = UDim2.new(0, 164, 0.5, -10),
    BackgroundColor3 = P.ok, BackgroundTransparency = 0.82,
    Text = "Ready", TextColor3 = P.ok, TextSize = 10, Font = Fm, Parent = hdr,
})
rnd(badge, UDim.new(0, 4))

-- ── Header buttons (right → left) ──

local btnX = mk("TextButton", {
    Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -36, 0.5, -14),
    BackgroundColor3 = P.err, BackgroundTransparency = 0.6,
    Text = "✕", TextColor3 = P.t1, TextSize = 11, Font = Fb,
    AutoButtonColor = false, Parent = hdr,
})
rnd(btnX)

local btnMin = mk("TextButton", {
    Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -70, 0.5, -14),
    BackgroundColor3 = P.card, Text = "—", TextColor3 = P.t2,
    TextSize = 13, Font = Fb, AutoButtonColor = false, Parent = hdr,
})
rnd(btnMin)

local btnStart = mk("TextButton", {
    Size = UDim2.new(0, 100, 0, 28), Position = UDim2.new(1, -180, 0.5, -14),
    BackgroundColor3 = P.acc, Text = "▶  START", TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12, Font = Fb, AutoButtonColor = false, Parent = hdr,
})
rnd(btnStart)

local btnStop = mk("TextButton", {
    Size = UDim2.new(0, 100, 0, 28), Position = UDim2.new(1, -180, 0.5, -14),
    BackgroundColor3 = P.err, Text = "■  STOP", TextColor3 = Color3.new(1, 1, 1),
    TextSize = 12, Font = Fb, AutoButtonColor = false, Visible = false, Parent = hdr,
})
rnd(btnStop)

local btnSave = mk("TextButton", {
    Size = UDim2.new(0, 92, 0, 28), Position = UDim2.new(1, -280, 0.5, -14),
    BackgroundColor3 = P.card, Text = "saveinstance", TextColor3 = P.t2,
    TextSize = 10, Font = Fc, AutoButtonColor = false, Parent = hdr,
})
rnd(btnSave); stk(btnSave)

-- ═══════════════════════════════════════════
--  SIDEBAR
-- ═══════════════════════════════════════════

local side = mk("Frame", {
    Size = UDim2.new(0, SIDE_W, 1, -(HDR_H + 2 + 46)),
    Position = UDim2.new(0, 0, 0, HDR_H + 2),
    BackgroundColor3 = P.pnl, BorderSizePixel = 0, Parent = win,
})
mk("Frame", {
    Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = P.brd, BorderSizePixel = 0, Parent = side,
})

local indicator = mk("Frame", {
    Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 0, 0, 14),
    BackgroundColor3 = P.acc, BorderSizePixel = 0, Parent = side,
})
rnd(indicator, UDim.new(0, 1))

local sideIcons = {"⚙", "▶"}
local sideBtns = {}
for i, icon in ipairs(sideIcons) do
    sideBtns[i] = mk("TextButton", {
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(0.5, -15, 0, 8 + (i - 1) * 40),
        BackgroundColor3 = i == 1 and P.acc or P.card,
        BackgroundTransparency = i == 1 and 0.15 or 0.6,
        Text = icon, TextColor3 = i == 1 and P.t1 or P.t2,
        TextSize = 14, Font = Fr, AutoButtonColor = false, Parent = side,
    })
    rnd(sideBtns[i])
end

-- ═══════════════════════════════════════════
--  BODY
-- ═══════════════════════════════════════════

local body = mk("Frame", {
    Size = UDim2.new(1, -(SIDE_W + 8), 1, -(HDR_H + 2 + 46)),
    Position = UDim2.new(0, SIDE_W + 4, 0, HDR_H + 2),
    BackgroundTransparency = 1, ClipsDescendants = true, Parent = win,
})

-- ────────────────────────────────
--  PAGE 1 — CONFIG
-- ────────────────────────────────

local pgCfg = mk("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = body})

local colL = mk("ScrollingFrame", {
    Size = UDim2.new(0.46, 0, 1, 0), BackgroundTransparency = 1,
    ScrollBarThickness = 2, ScrollBarImageColor3 = P.acc,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = pgCfg,
})
pad(colL, 8, 8, 8, 4); lay(colL, 8)

local colR = mk("ScrollingFrame", {
    Size = UDim2.new(0.54, -4, 1, 0), Position = UDim2.new(0.46, 4, 0, 0),
    BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = P.acc,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = pgCfg,
})
pad(colR, 8, 8, 4, 8); lay(colR, 5)

-- LEFT

section(colL, "Output", 1)

mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
    Text = "Save name", TextColor3 = P.t2, TextSize = 11, Font = Fr,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = colL,
})

local folderBox = mk("TextBox", {
    Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = P.card,
    Text = config.folder, PlaceholderText = "folder name...",
    TextColor3 = P.t1, PlaceholderColor3 = P.t3,
    TextSize = 11, Font = Fc, ClearTextOnFocus = false,
    LayoutOrder = 3, Parent = colL,
})
rnd(folderBox); stk(folderBox); pad(folderBox, 0, 0, 8, 8)

local pathLbl = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1,
    Text = "→ workspace/" .. config.folder .. "/",
    TextColor3 = P.t3, TextSize = 9, Font = Fc,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 4, Parent = colL,
})

folderBox.FocusLost:Connect(function()
    config.folder = folderBox.Text
    pathLbl.Text = "→ workspace/" .. folderBox.Text .. "/"
end)

section(colL, "Mode", 10)
cards(colL, "mode", {
    {id = "safe",  title = "SAFE",  desc = "Stable · ~2-5 min", badge = "SLOW"},
    {id = "turbo", title = "TURBO", desc = "Fast · ~30-90s",    badge = "FAST"},
}, 11)

section(colL, "Format", 20)
cards(colL, "saveMode", {
    {id = "individual", title = "INDIVIDUAL", desc = "One file per script"},
    {id = "single",     title = "SINGLE FILE", desc = "All in one .lua"},
}, 21)

-- RIGHT

section(colR, "Scripts", 1)
toggle(colR, "LocalScripts",      "dumpLocal",    2)
toggle(colR, "ModuleScripts",     "dumpModule",   3)
toggle(colR, "Include disabled",  "dumpDisabled", 4)

section(colR, "Deep scan — hidden / deleted / GC", 10)
toggle(colR, "Nil instances (deleted)",   "scanNil",     11)
toggle(colR, "Garbage collector",         "scanGC",      12)
toggle(colR, "Lua registry",              "scanReg",     13)
toggle(colR, "Threads / coroutines",      "scanThreads", 14)
toggle(colR, "Running scripts",           "scanRunning", 15)
toggle(colR, "Loaded modules",            "scanLoaded",  16)
toggle(colR, "Event connections",         "scanConn",    17)
toggle(colR, "All instances (full mem)",  "scanAll",     18)

section(colR, "Extras", 30)
toggle(colR, "Remotes & bindables",  "dumpRemotes", 31)
toggle(colR, "Hook detection",       "dumpHooks",   32)
toggle(colR, "UI tree (PlayerGui)",  "dumpUI",      33)
toggle(colR, "Game info file",       "dumpInfo",    34)
toggle(colR, "Constants (debug)",    "dumpConsts",  35)
toggle(colR, "Upvalues (debug)",     "dumpUpvals",  36)

-- ────────────────────────────────
--  PAGE 2 — SCANNER
-- ────────────────────────────────

local pgScan = mk("Frame", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Visible = false, Parent = body,
})

local statsBar = mk("Frame", {
    Size = UDim2.new(1, -8, 0, 28), Position = UDim2.new(0, 4, 0, 4),
    BackgroundColor3 = P.card, BorderSizePixel = 0, Parent = pgScan,
})
rnd(statsBar); pad(statsBar, 0, 0, 10, 10)

local statsLbl = mk("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Text = "Found: 0   Done: 0   Failed: 0   Remotes: 0",
    TextColor3 = P.t2, TextSize = 11, Font = Fc,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = statsBar,
})

local phaseLbl = mk("TextLabel", {
    Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 0, 36),
    BackgroundTransparency = 1, Text = "Phase: idle",
    TextColor3 = P.t3, TextSize = 10, Font = Fc,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = pgScan,
})

mk("Frame", {
    Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 0, 54),
    BackgroundColor3 = P.brd, BackgroundTransparency = 0.4,
    BorderSizePixel = 0, Parent = pgScan,
})

local terminal = mk("ScrollingFrame", {
    Size = UDim2.new(1, -8, 1, -60), Position = UDim2.new(0, 4, 0, 58),
    BackgroundColor3 = P.card, ScrollBarThickness = 3, ScrollBarImageColor3 = P.acc,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = pgScan,
})
rnd(terminal); pad(terminal, 6, 6, 8, 8); lay(terminal, 2)

local termIdx = 0

-- ═══════════════════════════════════════════
--  BOTTOM BARS
-- ═══════════════════════════════════════════

local progBg = mk("Frame", {
    Size = UDim2.new(1, -12, 0, 14), Position = UDim2.new(0, 6, 1, -42),
    BackgroundColor3 = P.card, BorderSizePixel = 0, Parent = win,
})
rnd(progBg, UDim.new(0, 4))

local progFill = mk("Frame", {
    Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = P.acc,
    BorderSizePixel = 0, Parent = progBg,
})
rnd(progFill, UDim.new(0, 4))

local progLbl = mk("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Text = "", TextColor3 = P.t1, TextSize = 9, Font = Fc,
    ZIndex = 3, Parent = progBg,
})

local statusLbl = mk("TextLabel", {
    Size = UDim2.new(1, -12, 0, 18), Position = UDim2.new(0, 6, 1, -24),
    BackgroundTransparency = 1,
    Text = "✓ Ready  ·  " .. config.folder .. "  ·  " .. execName .. "  ·  " .. game.PlaceId,
    TextColor3 = P.t3, TextSize = 9, Font = Fc,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = win,
})

-- ═══════════════════════════════════════════
--  NAVIGATION
-- ═══════════════════════════════════════════

local pages = {pgCfg, pgScan}
local curPage = 1

local function switchPage(idx)
    curPage = idx
    for i, pg in ipairs(pages) do pg.Visible = (i == idx) end
    for i, btn in ipairs(sideBtns) do
        TS:Create(btn, ti(), {
            BackgroundColor3 = i == idx and P.acc or P.card,
            BackgroundTransparency = i == idx and 0.15 or 0.6,
        }):Play()
        btn.TextColor3 = i == idx and P.t1 or P.t2
    end
    TS:Create(indicator, ti(0.18), {
        Position = UDim2.new(0, 0, 0, 8 + (idx - 1) * 40 + 6),
    }):Play()
end

for i, btn in ipairs(sideBtns) do
    btn.MouseButton1Click:Connect(function() switchPage(i) end)
end

-- ═══════════════════════════════════════════
--  DRAG
-- ═══════════════════════════════════════════

do
    local dragging, dragStart, winStart
    hdr.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; winStart = win.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            win.Position = UDim2.new(winStart.X.Scale, winStart.X.Offset + d.X,
                                     winStart.Y.Scale, winStart.Y.Offset + d.Y)
        end
    end)
end

-- ═══════════════════════════════════════════
--  CONTROLS
-- ═══════════════════════════════════════════

local minimized = false

btnMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    TS:Create(win, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0, WIN_W, 0, HDR_H + 2) or fullSize,
    }):Play()
    btnMin.Text = minimized and "+" or "—"
end)

btnX.MouseButton1Click:Connect(function()
    TS:Create(win, TweenInfo.new(0.15), {Size = UDim2.new(0, WIN_W, 0, 0)}):Play()
    task.wait(0.17); gui:Destroy()
end)

UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightControl then win.Visible = not win.Visible end
end)

for _, b in ipairs({btnStart, btnStop, btnSave, btnMin, btnX}) do
    local orig = b.BackgroundTransparency
    b.MouseEnter:Connect(function()
        TS:Create(b, ti(0.1), {BackgroundTransparency = math.max(orig - 0.15, 0)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TS:Create(b, ti(0.1), {BackgroundTransparency = orig}):Play()
    end)
end

-- ═══════════════════════════════════════════
--  OPEN ANIMATION
-- ═══════════════════════════════════════════

win.BackgroundTransparency = 1
win.Size = UDim2.new(0, WIN_W, 0, 0)
TS:Create(win, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
    Size = fullSize, BackgroundTransparency = 0,
}):Play()

-- ═══════════════════════════════════════════
--  API  (todas as funções mantidas)
-- ═══════════════════════════════════════════

local pulseActive = false
local API = {}
API.OnStart = nil
API.OnStop = nil
API.OnSaveInstance = nil

function API:GetConfig()
    return config
end

function API:SetFolder(name)
    config.folder = name
    folderBox.Text = name
    pathLbl.Text = "→ workspace/" .. name .. "/"
end

function API:Log(msg, color)
    color = color or "white"
    termIdx = termIdx + 1
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Text = "[" .. os.date("%H:%M:%S") .. "] " .. msg,
        TextColor3 = logC[color] or P.t1, TextSize = 10, Font = Fc,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = termIdx, Parent = terminal,
    })
    task.defer(function()
        terminal.CanvasPosition = Vector2.new(0, terminal.AbsoluteCanvasSize.Y)
    end)
end

function API:ClearLog()
    for _, c in ipairs(terminal:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    termIdx = 0
end

function API:SetProgress(cur, max)
    max = max or 1
    local pct = max > 0 and cur / max or 0
    TS:Create(progFill, TweenInfo.new(0.2), {
        Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0),
    }):Play()
    progLbl.Text = string.format("%d / %d  (%d%%)", cur, max, math.floor(pct * 100))
end

function API:SetStats(s)
    local parts = {}
    if s.total   then parts[#parts + 1] = "Found: " .. s.total end
    if s.ok      then parts[#parts + 1] = "Done: " .. s.ok end
    if s.fail    then parts[#parts + 1] = "Failed: " .. s.fail end
    if s.remotes then parts[#parts + 1] = "Remotes: " .. s.remotes end
    if s.hooks   then parts[#parts + 1] = "Hooks: " .. s.hooks end
    statsLbl.Text = table.concat(parts, "   ")
end

function API:SetPhase(text)
    phaseLbl.Text = "Phase: " .. tostring(text)
end

function API:SetStatus(text)
    statusLbl.Text = text
end

function API:SetBadge(text, color)
    badge.Text = text
    badge.TextColor3 = logC[color] or P.ok
    badge.BackgroundColor3 = logC[color] or P.ok
end

function API:SetRunning(running)
    btnStart.Visible = not running
    btnStop.Visible = running
    pulseActive = running

    if running then
        badge.Text = "LIVE"
        badge.TextColor3 = P.acc
        badge.BackgroundColor3 = P.acc
        switchPage(2)
        task.spawn(function()
            while pulseActive do
                TS:Create(badge, TweenInfo.new(0.5), {BackgroundTransparency = 0.4}):Play()
                task.wait(0.5)
                if not pulseActive then break end
                TS:Create(badge, TweenInfo.new(0.5), {BackgroundTransparency = 0.85}):Play()
                task.wait(0.5)
            end
        end)
    else
        badge.Text = "Done"
        badge.TextColor3 = P.ok
        badge.BackgroundColor3 = P.ok
        badge.BackgroundTransparency = 0.8
    end
end

function API:ShowPage(n)
    switchPage(n)
end

function API:Destroy()
    pulseActive = false
    gui:Destroy()
end

-- wire buttons
btnStart.MouseButton1Click:Connect(function()
    if API.OnStart then API.OnStart() end
end)
btnStop.MouseButton1Click:Connect(function()
    if API.OnStop then API.OnStop() end
end)
btnSave.MouseButton1Click:Connect(function()
    if API.OnSaveInstance then API.OnSaveInstance() end
end)

return API