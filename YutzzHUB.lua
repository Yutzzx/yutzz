-- Yutzz HUB Script using Axion UI Library
-- Hitbox ESP is transparent (invisible but functional)

local Axion = loadstring(game:HttpGet("https://raw.githubusercontent.com/adamowaissi22-boop/Axom-Scripts-/refs/heads/main/Axion%20Ui%20Library"))()

-- =============================================
-- CONFIG
-- =============================================

local Config = {
    Players = {
        Killer   = {Color = Color3.fromRGB(255, 93, 108)},
        Survivor = {Color = Color3.fromRGB(64, 224, 255)}
    },
    Objects = {
        Generator = {Color = Color3.fromRGB(150, 0, 200)},
        Gate      = {Color = Color3.fromRGB(255, 255, 255)},
        Pallet    = {Color = Color3.fromRGB(74, 255, 181)},
        Window    = {Color = Color3.fromRGB(74, 255, 181)},
        Hook      = {Color = Color3.fromRGB(132, 255, 169)}
    },
    HITBOX_Enabled      = false,
    HITBOX_Size         = 10,
    HITBOX_Transparency = 1,
    HITBOX_ESP          = false,
    HITBOX_ESP_Color    = Color3.fromRGB(255, 50, 50)
}

local MaskNames = {
    ["Richard"] = "Rooster",  ["Tony"]   = "Tiger",
    ["Brandon"] = "Panther",  ["Cobra"]  = "Cobra",
    ["Richter"] = "Rat",      ["Rabbit"] = "Rabbit",
    ["Alex"]    = "Chainsaw"
}

local MaskColors = {
    ["Richard"] = Color3.fromRGB(255, 0, 0),
    ["Tony"]    = Color3.fromRGB(255, 255, 0),
    ["Brandon"] = Color3.fromRGB(160, 32, 240),
    ["Cobra"]   = Color3.fromRGB(0, 255, 0),
    ["Richter"] = Color3.fromRGB(0, 0, 0),
    ["Rabbit"]  = Color3.fromRGB(255, 105, 180),
    ["Alex"]    = Color3.fromRGB(255, 255, 255)
}

-- =============================================
-- SERVICES
-- =============================================

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local Lighting            = game:GetService("Lighting")
local TweenService        = game:GetService("TweenService")

local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = LocalPlayer:WaitForChild("PlayerGui")

-- =============================================
-- STATE
-- =============================================

local ActiveGenerators  = {}
local LastUpdateTick    = 0
local LastFullESPRefresh= 0
local OriginalHitboxSizes = {}

-- Hitbox ESP drawing (transparent — still shows outline only, no fill)
local HitboxESPBoxes    = {}
local ESPDrawingEnabled = false

local TouchID    = 8822
local ActionPath = "Survivor-mob.Controls.action.check"
local HeartbeatConnection  = nil
local VisibilityConnection = nil
local IndicatorGui         = nil

local speedHackEnabled     = false
local desiredSpeed         = 16
local speedConnections     = {}
local autoSkillcheckEnabled= true
local fullbrightEnabled    = true

-- =============================================
-- AXION WINDOW
-- =============================================

local Window = Axion:CreateWindow({
    Name              = "Yutzz HUB",
    Subtitle          = "Mobile Script",
    Version           = "v2.0",
    LoadingTitle      = "Yutzz HUB",
    LoadingSubtitle   = "Loading modules...",
    Theme             = "Default",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "YutzzConfig",
        FileName   = "YutzzSettings"
    },
    AnimationSpeed = 0.3,
    RippleEnabled  = true,
    CornerRadius   = 12,
    ToggleKey      = Enum.KeyCode.RightShift
})

-- =============================================
-- TABS
-- =============================================

local PlayerTab  = Window:CreateTab({Name = "Player",  Icon = "⚡"})
local HitboxTab  = Window:CreateTab({Name = "Hitbox",  Icon = "🎯"})
local GameTab    = Window:CreateTab({Name = "Game",    Icon = "🔧"})
local SettingsTab= Window:CreateTab({Name = "Settings",Icon = "⚙️"})

-- =============================================
-- ROLE / TEAM HELPERS
-- =============================================

local function GetRole()
    local team = LocalPlayer.Team
    if not team then return "None" end
    local name = team.Name:lower()
    if name:find("killer")   then return "Killer"   end
    if name:find("survivor") then return "Survivor" end
    return "None"
end

local function IsSurvivor(player)
    if not player.Team then return false end
    return player.Team.Name:lower():find("survivor") ~= nil
end

-- =============================================
-- SPEED HACK FUNCTIONS (defined before UI use)
-- =============================================

local function applySpeed(humanoid)
    if humanoid and speedHackEnabled then
        humanoid.WalkSpeed = desiredSpeed
    end
end

local function setupSpeedEnforcement(humanoid)
    for _, conn in ipairs(speedConnections) do conn:Disconnect() end
    speedConnections = {}
    if humanoid then
        applySpeed(humanoid)
        table.insert(speedConnections, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if speedHackEnabled and humanoid.WalkSpeed ~= desiredSpeed then
                humanoid.WalkSpeed = desiredSpeed
            end
        end))
        table.insert(speedConnections, RunService.Heartbeat:Connect(function()
            if speedHackEnabled and humanoid.WalkSpeed ~= desiredSpeed then
                humanoid.WalkSpeed = desiredSpeed
            end
        end))
    end
end

local function onCharacterAddedSpeed(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid then setupSpeedEnforcement(humanoid) end
end

-- =============================================
-- ESP DRAWING (TRANSPARENT HITBOX BOX)
-- =============================================

local function CheckDrawingSupport()
    local ok = pcall(function()
        local test = Drawing.new("Line")
        test:Remove()
    end)
    ESPDrawingEnabled = ok
    return ok
end
CheckDrawingSupport()

local function CreateHitboxESPBox(player)
    if not ESPDrawingEnabled then return end
    if HitboxESPBoxes[player] then return end

    local drawings = {}

    -- 4 corner-bracket lines per corner = 8 lines (white corners only, no fill box)
    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Transparency = 1
        line.Visible = false
        table.insert(drawings, line)
    end

    -- Name label
    local nameLabel = Drawing.new("Text")
    nameLabel.Size = 13
    nameLabel.Center = true
    nameLabel.Outline = true
    nameLabel.Color = Config.HITBOX_ESP_Color
    nameLabel.Visible = false
    table.insert(drawings, nameLabel)

    -- Distance label
    local distLabel = Drawing.new("Text")
    distLabel.Size = 11
    distLabel.Center = true
    distLabel.Outline = true
    distLabel.Color = Color3.fromRGB(255, 255, 255)
    distLabel.Visible = false
    table.insert(drawings, distLabel)

    HitboxESPBoxes[player] = {
        drawings   = drawings,
        cornerTL1  = drawings[1], cornerTL2 = drawings[2],
        cornerTR1  = drawings[3], cornerTR2 = drawings[4],
        cornerBL1  = drawings[5], cornerBL2 = drawings[6],
        cornerBR1  = drawings[7], cornerBR2 = drawings[8],
        nameLabel  = drawings[9],
        distLabel  = drawings[10],
    }
end

local function RemoveHitboxESPBox(player)
    if HitboxESPBoxes[player] then
        for _, drawing in ipairs(HitboxESPBoxes[player].drawings) do
            pcall(function() drawing:Remove() end)
        end
        HitboxESPBoxes[player] = nil
    end
end

local function RemoveAllHitboxESPBoxes()
    for player in pairs(HitboxESPBoxes) do
        RemoveHitboxESPBox(player)
    end
    HitboxESPBoxes = {}
end

local function UpdateHitboxESPBox(player)
    if not ESPDrawingEnabled then return end
    if not Config.HITBOX_ESP then RemoveHitboxESPBox(player); return end
    if not player.Character then RemoveHitboxESPBox(player); return end

    local root     = player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        RemoveHitboxESPBox(player); return
    end

    if not HitboxESPBoxes[player] then CreateHitboxESPBox(player) end
    local esp = HitboxESPBoxes[player]
    if not esp then return end

    local camera   = workspace.CurrentCamera
    local halfSize = Config.HITBOX_Size / 2
    local pos      = root.Position

    local corners3D = {
        pos + Vector3.new(-halfSize,  halfSize, -halfSize),
        pos + Vector3.new( halfSize,  halfSize, -halfSize),
        pos + Vector3.new( halfSize, -halfSize, -halfSize),
        pos + Vector3.new(-halfSize, -halfSize, -halfSize),
        pos + Vector3.new(-halfSize,  halfSize,  halfSize),
        pos + Vector3.new( halfSize,  halfSize,  halfSize),
        pos + Vector3.new( halfSize, -halfSize,  halfSize),
        pos + Vector3.new(-halfSize, -halfSize,  halfSize),
    }

    local anyOnScreen = false
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, corner in ipairs(corners3D) do
        local sp, onScreen = camera:WorldToViewportPoint(corner)
        if onScreen then anyOnScreen = true end
        if sp.Z > 0 then
            minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y)
            maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y)
        end
    end

    if not anyOnScreen or minX == math.huge then
        for _, d in ipairs(esp.drawings) do d.Visible = false end
        return
    end

    local myRoot   = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local distance = myRoot and math.floor((root.Position - myRoot.Position).Magnitude) or 0
    local cornerLen= math.clamp(math.min((maxX - minX) * 0.25, (maxY - minY) * 0.25), 4, 20)

    -- Only corner brackets, no fill — visually subtle / transparent look
    local w = Color3.fromRGB(255, 255, 255)
    esp.cornerTL1.From = Vector2.new(minX, minY); esp.cornerTL1.To = Vector2.new(minX + cornerLen, minY); esp.cornerTL1.Color = w; esp.cornerTL1.Visible = true
    esp.cornerTL2.From = Vector2.new(minX, minY); esp.cornerTL2.To = Vector2.new(minX, minY + cornerLen); esp.cornerTL2.Color = w; esp.cornerTL2.Visible = true
    esp.cornerTR1.From = Vector2.new(maxX, minY); esp.cornerTR1.To = Vector2.new(maxX - cornerLen, minY); esp.cornerTR1.Color = w; esp.cornerTR1.Visible = true
    esp.cornerTR2.From = Vector2.new(maxX, minY); esp.cornerTR2.To = Vector2.new(maxX, minY + cornerLen); esp.cornerTR2.Color = w; esp.cornerTR2.Visible = true
    esp.cornerBL1.From = Vector2.new(minX, maxY); esp.cornerBL1.To = Vector2.new(minX + cornerLen, maxY); esp.cornerBL1.Color = w; esp.cornerBL1.Visible = true
    esp.cornerBL2.From = Vector2.new(minX, maxY); esp.cornerBL2.To = Vector2.new(minX, maxY - cornerLen); esp.cornerBL2.Color = w; esp.cornerBL2.Visible = true
    esp.cornerBR1.From = Vector2.new(maxX, maxY); esp.cornerBR1.To = Vector2.new(maxX - cornerLen, maxY); esp.cornerBR1.Color = w; esp.cornerBR1.Visible = true
    esp.cornerBR2.From = Vector2.new(maxX, maxY); esp.cornerBR2.To = Vector2.new(maxX, maxY - cornerLen); esp.cornerBR2.Color = w; esp.cornerBR2.Visible = true

    local teamName = (player.Team and player.Team.Name:lower()) or ""
    local boxColor = Config.HITBOX_ESP_Color
    if teamName:find("killer")   then boxColor = Config.Players.Killer.Color
    elseif teamName:find("survivor") then boxColor = Config.Players.Survivor.Color end

    local baseName = player.Name
    local selectedKillerAttr = player:GetAttribute("SelectedKiller")
    if teamName:find("killer") and selectedKillerAttr and tostring(selectedKillerAttr) ~= "" then
        baseName = tostring(selectedKillerAttr)
    end

    esp.nameLabel.Text     = baseName
    esp.nameLabel.Position = Vector2.new((minX + maxX) / 2, minY - 16)
    esp.nameLabel.Color    = boxColor
    esp.nameLabel.Visible  = true

    esp.distLabel.Text     = "[" .. distance .. " studs]"
    esp.distLabel.Position = Vector2.new((minX + maxX) / 2, maxY + 2)
    esp.distLabel.Visible  = true
end

-- =============================================
-- CORE ESP / GAME FUNCTIONS
-- =============================================

local function SetupGui()
    if PlayerGui:FindFirstChild("ChasedInds") then
        PlayerGui:FindFirstChild("ChasedInds"):Destroy()
    end
    IndicatorGui = Instance.new("ScreenGui")
    IndicatorGui.Name          = "ChasedInds"
    IndicatorGui.IgnoreGuiInset= true
    IndicatorGui.DisplayOrder  = 999
    IndicatorGui.ResetOnSpawn  = false
    IndicatorGui.Parent        = PlayerGui
end

local function GetGameValue(obj, name)
    if not obj then return nil end
    local attr = obj:GetAttribute(name)
    if attr ~= nil then return attr end
    local child = obj:FindFirstChild(name)
    if child then
        local ok, val = pcall(function() return child.Value end)
        if ok then return val end
    end
    return nil
end

local function ApplyHighlight(object, color)
    local h = object:FindFirstChild("H") or Instance.new("Highlight")
    h.Name              = "H"
    h.Adornee           = object
    h.FillColor         = color
    h.OutlineColor      = color
    h.FillTransparency  = 0.8
    h.OutlineTransparency = 0.3
    h.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent            = object
end

local function CreateBillboardTag(text, color, size, textSize)
    local billboard = Instance.new("BillboardGui")
    billboard.Name        = "BitchHook"
    billboard.AlwaysOnTop = true
    billboard.Size        = size or UDim2.new(0, 120, 0, 30)

    local label = Instance.new("TextLabel")
    label.Name                 = "BitchHook"
    label.Size                 = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text                 = text
    label.TextColor3           = color
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3     = Color3.new(0, 0, 0)
    label.Font                 = Enum.Font.GothamBold
    label.TextSize             = textSize or 10
    label.TextWrapped          = true
    label.RichText             = true
    label.Parent               = billboard

    return billboard
end

local function updatePlayerNametag(player)
    if not IndicatorGui or not IndicatorGui.Parent then return end
    if not player.Character then
        for _, n in ipairs({player.Name, player.Name.."_Chased", player.Name.."_Killer"}) do
            local m = IndicatorGui:FindFirstChild(n) if m then m:Destroy() end
        end
        return
    end

    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not rootPart then return end

    local teamName           = (player.Team and player.Team.Name:lower()) or ""
    local selectedKillerAttr = GetGameValue(player, "SelectedKiller")
    local isKnocked          = GetGameValue(player.Character, "Knocked")
    local isHooked           = GetGameValue(player.Character, "IsHooked")
    local isChased           = GetGameValue(player.Character, "IsChased")
    local isKiller           = teamName:find("killer") ~= nil

    local color = isKiller and Config.Players.Killer.Color or Config.Players.Survivor.Color
    if isHooked then
        color = Color3.fromRGB(255, 182, 193)
    elseif humanoid and humanoid.Health < humanoid.MaxHealth then
        color = isKnocked and Color3.fromRGB(200, 100, 0) or Color3.fromRGB(200, 200, 0)
    end

    local distance = 0
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        distance = math.floor((rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
    end

    local baseName = (isKiller and selectedKillerAttr and tostring(selectedKillerAttr) ~= "") and tostring(selectedKillerAttr) or player.Name
    local nameText = baseName .. "\n[" .. distance .. " studs]"

    local billboard = rootPart:FindFirstChild("BitchHook")
    if not billboard then
        billboard = CreateBillboardTag(nameText, color)
        billboard.Adornee = rootPart
        billboard.Parent  = rootPart
    else
        local lbl = billboard:FindFirstChild("BitchHook") or billboard:FindFirstChildOfClass("TextLabel")
        if lbl then lbl.Text = nameText; lbl.TextColor3 = color end
    end

    ApplyHighlight(player.Character, color)

    -- Mask display
    local rawMask = GetGameValue(player, "Mask") or GetGameValue(player.Character, "Mask")
    local hasMask = false
    if isKiller and string.match(tostring(selectedKillerAttr):lower(), "masked") and rawMask then
        for key, name in pairs(MaskNames) do
            if key:lower() == tostring(rawMask):lower() then
                hasMask = true
                local maskBillboard = rootPart:FindFirstChild("MaskHook")
                if not maskBillboard then
                    maskBillboard = CreateBillboardTag(name, MaskColors[key] or Color3.new(1,1,1), UDim2.new(0, 100, 0, 20), 12)
                    maskBillboard.Name         = "MaskHook"
                    maskBillboard.StudsOffset  = Vector3.new(0, 3, 0)
                    maskBillboard.Adornee      = rootPart
                    maskBillboard.Parent       = rootPart
                else
                    local lbl = maskBillboard:FindFirstChild("BitchHook") or maskBillboard:FindFirstChildOfClass("TextLabel")
                    if lbl then lbl.Text = name; lbl.TextColor3 = MaskColors[key] or Color3.new(1,1,1) end
                end
                break
            end
        end
    end
    if not hasMask then
        local mb = rootPart:FindFirstChild("MaskHook") if mb then mb:Destroy() end
    end

    -- Chased indicator
    local chasedLabel2D = IndicatorGui:FindFirstChild(player.Name .. "_Chased")
    if isChased then
        local ct3 = billboard:FindFirstChild("ChasedLabel")
        if not ct3 then
            ct3 = Instance.new("TextLabel", billboard)
            ct3.Name                 = "ChasedLabel"
            ct3.Size                 = UDim2.new(1, 0, 1, 0)
            ct3.Position             = UDim2.new(0, 0, -1.2, 0)
            ct3.BackgroundTransparency = 1
            ct3.Font                 = Enum.Font.GothamBold
            ct3.TextSize             = 24
        end
        ct3.Text = "!!"; ct3.TextColor3 = color; ct3.TextStrokeTransparency = 0

        if not chasedLabel2D then
            chasedLabel2D = Instance.new("TextLabel", IndicatorGui)
            chasedLabel2D.Name                 = player.Name .. "_Chased"
            chasedLabel2D.BackgroundTransparency = 1
            chasedLabel2D.Font                 = Enum.Font.GothamBold
            chasedLabel2D.TextSize             = 24
            chasedLabel2D.TextStrokeTransparency = 0
            chasedLabel2D.AnchorPoint          = Vector2.new(0.5, 0.5)
            chasedLabel2D.Size                 = UDim2.new(0, 40, 0, 40)
        end
        chasedLabel2D.Text = "!!"; chasedLabel2D.TextColor3 = color

        local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(rootPart.Position)
        if onScreen then
            chasedLabel2D.Visible = false
        else
            chasedLabel2D.Visible = true
            local vc = workspace.CurrentCamera.ViewportSize / 2
            local dir = Vector2.new(screenPos.X, screenPos.Y) - vc
            if screenPos.Z < 0 then dir = -dir end
            local ms = math.max(math.abs(dir.X) / (vc.X - 30), math.abs(dir.Y) / (vc.Y - 30))
            chasedLabel2D.Position = UDim2.new(0, vc.X + dir.X / (ms == 0 and 1 or ms), 0, vc.Y + dir.Y / (ms == 0 and 1 or ms))
        end
    else
        if chasedLabel2D then chasedLabel2D:Destroy() end
        local ct3 = billboard and billboard:FindFirstChild("ChasedLabel") if ct3 then ct3:Destroy() end
    end

    -- Off-screen killer indicator
    local killerLabel2D = IndicatorGui:FindFirstChild(player.Name .. "_Killer")
    if isKiller then
        if not killerLabel2D then
            killerLabel2D = Instance.new("TextLabel", IndicatorGui)
            killerLabel2D.Name                 = player.Name .. "_Killer"
            killerLabel2D.BackgroundTransparency = 1
            killerLabel2D.Font                 = Enum.Font.GothamBold
            killerLabel2D.TextSize             = 10
            killerLabel2D.TextStrokeTransparency = 0
            killerLabel2D.Size                 = UDim2.new(0, 120, 0, 30)
            killerLabel2D.RichText             = true
            killerLabel2D.AnchorPoint          = Vector2.new(0.5, 0.5)
        end
        killerLabel2D.Text = baseName .. "\n[" .. distance .. " studs]"
        killerLabel2D.TextColor3 = color

        local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(rootPart.Position)
        if not onScreen then
            killerLabel2D.Visible = true
            local vc = workspace.CurrentCamera.ViewportSize / 2
            local dir = Vector2.new(screenPos.X, screenPos.Y) - vc
            if screenPos.Z < 0 then dir = -dir end
            local ms = math.max(math.abs(dir.X) / (vc.X - 30), math.abs(dir.Y) / (vc.Y - 30))
            killerLabel2D.Position = UDim2.new(0, vc.X + dir.X / (ms == 0 and 1 or ms), 0, vc.Y + dir.Y / (ms == 0 and 1 or ms))
        else
            killerLabel2D.Visible = false
        end
    elseif killerLabel2D then
        killerLabel2D:Destroy()
    end

    if Config.HITBOX_ESP and ESPDrawingEnabled then
        UpdateHitboxESPBox(player)
    elseif HitboxESPBoxes[player] then
        RemoveHitboxESPBox(player)
    end
end

local function updateGeneratorProgress(generator)
    if not generator or not generator.Parent then return true end
    local percent = GetGameValue(generator, "RepairProgress") or GetGameValue(generator, "Progress") or 0

    local billboard = generator:FindFirstChild("GenBitchHook")
    if percent >= 100 then
        if billboard then billboard:Destroy() end
        local h = generator:FindFirstChild("H") if h then h:Destroy() end
        return true
    end

    local cp = math.clamp(percent, 0, 100)
    local finalColor = cp < 50
        and Config.Objects.Generator.Color:Lerp(Color3.fromRGB(180, 180, 0), cp / 50)
        or  Color3.fromRGB(180, 180, 0):Lerp(Color3.fromRGB(0, 150, 0), (cp - 50) / 50)

    local percentStr = string.format("[%.2f%%]", percent)
    if not billboard then
        billboard = CreateBillboardTag(percentStr, finalColor)
        billboard.Name        = "GenBitchHook"
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.Adornee     = generator:FindFirstChild("defaultMaterial", true) or generator
        billboard.Parent      = generator
    else
        local lbl = billboard:FindFirstChild("BitchHook") or billboard:FindFirstChildOfClass("TextLabel")
        if lbl then lbl.Text = percentStr; lbl.TextColor3 = finalColor end
    end
    return false
end

local function updateNextKillerDisplay()
    if not IndicatorGui or not IndicatorGui.Parent then return end
    local label   = IndicatorGui:FindFirstChild("NextKillerDisplay")
    local teamName= (LocalPlayer.Team and LocalPlayer.Team.Name:lower()) or ""
    if teamName:find("spectator") or teamName:find("lobby") then
        if not label then
            label = Instance.new("TextLabel", IndicatorGui)
            label.Name                 = "NextKillerDisplay"
            label.Size                 = UDim2.new(0, 220, 0, 30)
            label.Position             = UDim2.new(0.5, 0, 0, 45)
            label.AnchorPoint          = Vector2.new(0.5, 0)
            label.BackgroundTransparency = 0.5
            label.BackgroundColor3     = Color3.new(0, 0, 0)
            label.TextColor3           = Color3.new(1, 1, 1)
            label.Font                 = Enum.Font.GothamBold
            label.TextSize             = 14
            label.RichText             = true
            label.Text                 = "Next Killer: Calculating..."
        end
        local plrs = Players:GetPlayers()
        table.sort(plrs, function(a, b)
            local aA = GetGameValue(a, "AllowKiller") or false
            local bA = GetGameValue(b, "AllowKiller") or false
            if aA ~= bA then return aA == true end
            return (GetGameValue(a, "KillerChance") or 0) > (GetGameValue(b, "KillerChance") or 0)
        end)
        local nk = plrs[1]
        if nk then
            label.Text = "Next Killer: <font color=\"rgb(255,0,0)\">" .. (nk == LocalPlayer and "YOU" or tostring(GetGameValue(nk, "SelectedKiller") or nk.Name)) .. "</font>"
        end
    elseif label then
        label:Destroy()
    end
end

local function RefreshESP()
    ActiveGenerators = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Window" then ApplyHighlight(obj, Config.Objects.Window.Color) end
    end
    local Map = workspace:FindFirstChild("Map")
    if not Map then return end
    for _, obj in ipairs(Map:GetDescendants()) do
        if obj.Name == "Generator" then
            ApplyHighlight(obj, Config.Objects.Generator.Color)
            table.insert(ActiveGenerators, obj)
        elseif obj.Name == "Hook" then
            local m = obj:FindFirstChild("Model")
            if m then
                for _, p in ipairs(m:GetDescendants()) do
                    if p:IsA("MeshPart") then ApplyHighlight(p, Config.Objects.Hook.Color) end
                end
            end
        elseif obj.Name == "Palletwrong" or obj.Name == "Pallet" then
            ApplyHighlight(obj, Config.Objects.Pallet.Color)
        elseif obj.Name == "Gate" then
            ApplyHighlight(obj, Config.Objects.Gate.Color)
        end
    end
end

local function GetActionTarget()
    local current = PlayerGui
    for segment in string.gmatch(ActionPath, "[^%.]+") do
        current = current and current:FindFirstChild(segment)
    end
    return current
end

local function TriggerMobileButton()
    local b = GetActionTarget()
    if b and b:IsA("GuiObject") then
        local p, s, i = b.AbsolutePosition, b.AbsoluteSize, GuiService:GetGuiInset()
        local cx, cy = p.X + (s.X / 2) + i.X, p.Y + (s.Y / 2) + i.Y
        pcall(function()
            VirtualInputManager:SendTouchEvent(TouchID, 0, cx, cy)
            task.wait(0.01)
            VirtualInputManager:SendTouchEvent(TouchID, 2, cx, cy)
        end)
    end
end

local function InitializeAutobuy()
    if not autoSkillcheckEnabled then return end
    task.spawn(function()
        local prompt = PlayerGui:WaitForChild("SkillCheckPromptGui", 10)
        local check  = prompt and prompt:WaitForChild("Check", 10)
        if not check then return end
        local line, goal = check:WaitForChild("Line"), check:WaitForChild("Goal")
        if VisibilityConnection then VisibilityConnection:Disconnect() end
        VisibilityConnection = check:GetPropertyChangedSignal("Visible"):Connect(function()
            if LocalPlayer.Team and LocalPlayer.Team.Name == "Survivors" and check.Visible and autoSkillcheckEnabled then
                if HeartbeatConnection then HeartbeatConnection:Disconnect() end
                HeartbeatConnection = RunService.Heartbeat:Connect(function()
                    local lr = line.Rotation % 360
                    local gr = goal.Rotation % 360
                    local ss, se = (gr + 101) % 360, (gr + 115) % 360
                    if (ss > se and (lr >= ss or lr <= se)) or (lr >= ss and lr <= se) then
                        TriggerMobileButton()
                        if HeartbeatConnection then HeartbeatConnection:Disconnect(); HeartbeatConnection = nil end
                    end
                end)
            elseif HeartbeatConnection then
                HeartbeatConnection:Disconnect(); HeartbeatConnection = nil
            end
        end)
    end)
end

local function UpdateHitboxes()
    local function restoreAll()
        for player, origSize in pairs(OriginalHitboxSizes) do
            if player and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then root.Size = origSize; root.Transparency = 1; root.CanCollide = true end
            end
        end
        OriginalHitboxSizes = {}
    end

    if GetRole() ~= "Killer" or not Config.HITBOX_Enabled then
        restoreAll(); return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsSurvivor(player) then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum  = char:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health > 0 then
                    if not OriginalHitboxSizes[player] then
                        OriginalHitboxSizes[player] = root.Size
                    end
                    local size = Config.HITBOX_Size
                    root.Size         = Vector3.new(size, size, size)
                    root.CanCollide   = false
                    root.Transparency = Config.HITBOX_Transparency
                elseif root and OriginalHitboxSizes[player] then
                    root.Size         = OriginalHitboxSizes[player]
                    root.Transparency = 1
                    root.CanCollide   = true
                    OriginalHitboxSizes[player] = nil
                end
            end
        end
    end
end

-- =============================================
-- AXION UI — PLAYER TAB
-- =============================================

local PlayerSection = PlayerTab:CreateSection("Player Settings")

local speedToggle = PlayerSection:CreateToggle({
    Name         = "Speed Hack",
    CurrentValue = false,
    Flag         = "SpeedHack",
    Callback     = function(value)
        speedHackEnabled = value
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not value and humanoid then
            humanoid.WalkSpeed = 16
            for _, conn in ipairs(speedConnections) do conn:Disconnect() end
            speedConnections = {}
        elseif value and humanoid then
            setupSpeedEnforcement(humanoid)
        end
    end
})

local walkSpeedSlider = PlayerSection:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 300},
    Increment    = 1,
    Suffix       = " studs/s",
    CurrentValue = 16,
    Flag         = "WalkSpeed",
    Callback     = function(value)
        desiredSpeed     = value
        speedHackEnabled = true
        speedToggle:Set(true)
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        applySpeed(humanoid)
    end
})

-- =============================================
-- AXION UI — HITBOX TAB
-- =============================================

local HitboxSection = HitboxTab:CreateSection("Hitbox Settings")

local hitboxToggle = HitboxSection:CreateToggle({
    Name         = "Enable Hitbox",
    CurrentValue = false,
    Flag         = "HitboxEnabled",
    Callback     = function(value)
        Config.HITBOX_Enabled = value
        if not value then
            for player, origSize in pairs(OriginalHitboxSizes) do
                if player and player.Character then
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root then root.Size = origSize; root.Transparency = 1; root.CanCollide = true end
                end
            end
            OriginalHitboxSizes = {}
        end
    end
})

local hitboxSizeSlider = HitboxSection:CreateSlider({
    Name         = "Hitbox Size",
    Range        = {5, 50},
    Increment    = 1,
    Suffix       = " studs",
    CurrentValue = 10,
    Flag         = "HitboxSize",
    Callback     = function(value)
        Config.HITBOX_Size = value
    end
})

local hitboxTransparencySlider = HitboxSection:CreateSlider({
    Name         = "Hitbox Transparency",
    Range        = {0, 100},
    Increment    = 1,
    Suffix       = "%",
    CurrentValue = 100,
    Flag         = "HitboxTransparency",
    Callback     = function(value)
        -- 100% = fully invisible (1), 0% = fully visible (0)
        Config.HITBOX_Transparency = value / 100
    end
})

local hitboxESPToggle = HitboxSection:CreateToggle({
    Name         = "Hitbox ESP (Corner Brackets)",
    CurrentValue = false,
    Flag         = "HitboxESP",
    Callback     = function(value)
        Config.HITBOX_ESP = value
        if not value then RemoveAllHitboxESPBoxes() end
    end
})

local espColorPicker = HitboxSection:CreateColorPicker({
    Name     = "ESP Bracket Color",
    Color    = Color3.fromRGB(255, 50, 50),
    Flag     = "ESPColor",
    Callback = function(color)
        Config.HITBOX_ESP_Color = color
    end
})

-- =============================================
-- AXION UI — GAME TAB
-- =============================================

local GameSection = GameTab:CreateSection("Game Settings")

local autoSkillToggle = GameSection:CreateToggle({
    Name         = "Auto Skillcheck",
    CurrentValue = true,
    Flag         = "AutoSkill",
    Callback     = function(value)
        autoSkillcheckEnabled = value
        if value then
            InitializeAutobuy()
        else
            if HeartbeatConnection  then HeartbeatConnection:Disconnect();  HeartbeatConnection  = nil end
            if VisibilityConnection then VisibilityConnection:Disconnect(); VisibilityConnection = nil end
        end
    end
})

local fullbrightToggle = GameSection:CreateToggle({
    Name         = "Fullbright",
    CurrentValue = true,
    Flag         = "Fullbright",
    Callback     = function(value)
        fullbrightEnabled = value
        if not value then
            Lighting.Ambient       = Color3.fromRGB(127, 127, 127)
            Lighting.OutdoorAmbient= Color3.fromRGB(127, 127, 127)
            Lighting.Brightness    = 1
            Lighting.ClockTime     = 14
            Lighting.GlobalShadows = true
            Lighting.FogEnd        = 100000
        end
    end
})

-- =============================================
-- AXION UI — SETTINGS TAB
-- =============================================

local SettingsSection = SettingsTab:CreateSection("Interface")

local themeDropdown = SettingsSection:CreateDropdown({
    Name          = "Theme",
    Options       = {"Default", "Dark", "Light", "Ocean", "Midnight", "Emerald", "Crimson", "Galaxy", "Sunset", "Cyberpunk"},
    CurrentOption = "Default",
    Flag          = "Theme",
    Callback      = function(value)
        Window:SetTheme(value)
    end
})

local resetButton = SettingsSection:CreateButton({
    Name     = "Reset All Settings",
    Callback = function()
        speedToggle:Set(false)
        walkSpeedSlider:Set(16)
        hitboxToggle:Set(false)
        hitboxSizeSlider:Set(10)
        hitboxTransparencySlider:Set(100)
        hitboxESPToggle:Set(false)
        autoSkillToggle:Set(true)
        fullbrightToggle:Set(true)
        espColorPicker:Set(Color3.fromRGB(255, 50, 50))
    end
})

local destroyButton = SettingsSection:CreateButton({
    Name     = "Destroy UI",
    Callback = function()
        Window:Destroy()
    end
})

local KeybindSection = SettingsTab:CreateSection("Keybinds")

local toggleKeybind = KeybindSection:CreateKeybind({
    Name           = "Toggle UI",
    CurrentKeybind = "RightShift",
    Flag           = "ToggleKey",
    Callback       = function()
        Window:Toggle()
    end
})

local InfoSection = SettingsTab:CreateSection("Information")
InfoSection:CreateLabel("Yutzz HUB — Axion UI Edition")
InfoSection:CreateLabel("Player: " .. LocalPlayer.Name)

-- =============================================
-- CONNECTIONS
-- =============================================

workspace.ChildAdded:Connect(function(c)
    if c.Name == "Map" then
        task.wait(1)
        LastFullESPRefresh = 0
        RefreshESP()
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    if HeartbeatConnection  then HeartbeatConnection:Disconnect()  end
    if VisibilityConnection then VisibilityConnection:Disconnect() end
    SetupGui()
    RemoveAllHitboxESPBoxes()
    task.wait(1)
    InitializeAutobuy()
    onCharacterAddedSpeed(char)
    OriginalHitboxSizes = {}
end)

Players.PlayerRemoving:Connect(function(player)
    OriginalHitboxSizes[player] = nil
    RemoveHitboxESPBox(player)
    if not IndicatorGui then return end
    for _, n in ipairs({player.Name.."_Chased", player.Name.."_Killer", player.Name}) do
        local obj = IndicatorGui:FindFirstChild(n) if obj then obj:Destroy() end
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Config.HITBOX_ESP and ESPDrawingEnabled then
            CreateHitboxESPBox(player)
        end
    end)
    player.CharacterRemoving:Connect(function()
        RemoveHitboxESPBox(player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Config.HITBOX_ESP and ESPDrawingEnabled then CreateHitboxESPBox(player) end
        end)
        player.CharacterRemoving:Connect(function() RemoveHitboxESPBox(player) end)
    end
end

-- =============================================
-- MAIN HEARTBEAT LOOP
-- =============================================

RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - LastUpdateTick < 0.05 then return end
    LastUpdateTick = now

    if fullbrightEnabled then
        Lighting.Ambient        = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness     = 2
        Lighting.ClockTime      = 14
        Lighting.GlobalShadows  = false
        Lighting.FogEnd         = 9e9
    end

    if now - LastFullESPRefresh > 3 then
        LastFullESPRefresh = now
        RefreshESP()
    end

    updateNextKillerDisplay()
    UpdateHitboxes()

    local myChar   = LocalPlayer.Character
    local myRoot   = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local killerNearby = false

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            updatePlayerNametag(p)
            local pTeam = p.Team and p.Team.Name:lower() or ""
            if pTeam:find("killer") and myRoot and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if (p.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude < 99 then
                    killerNearby = true
                end
            end
        end
    end

    if Config.HITBOX_ESP and ESPDrawingEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then UpdateHitboxESPBox(p) end
        end
    end

    if myRoot then
        local warn = myRoot:FindFirstChild("KillerWarn")
        if killerNearby then
            if not warn then
                warn = CreateBillboardTag("!", Color3.fromRGB(255, 0, 0), UDim2.new(0, 50, 0, 50), 40)
                warn.Name        = "KillerWarn"
                warn.StudsOffset = Vector3.new(0, 4, 0)
                warn.Adornee     = myRoot
                warn.Parent      = myRoot
            end
        elseif warn then
            warn:Destroy()
        end
    end

    for i = #ActiveGenerators, 1, -1 do
        local g = ActiveGenerators[i]
        if g and g.Parent then
            if updateGeneratorProgress(g) then table.remove(ActiveGenerators, i) end
        else
            table.remove(ActiveGenerators, i)
        end
    end
end)

-- =============================================
-- INIT
-- =============================================

SetupGui()
RefreshESP()
InitializeAutobuy()

if LocalPlayer.Character then onCharacterAddedSpeed(LocalPlayer.Character) end
