pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "Destroy" and self.Name == "ZTrongz_ESP" then
            return nil
        end
        return oldNamecall(self, ...)
    end)
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    esp_enabled       = true,
    esp_color         = Color3.fromRGB(255, 60, 60),
    fov_enabled       = true,
    fov_radius        = 150,
    fov_color         = Color3.fromRGB(255, 255, 255),
    aimbot_enabled    = true,
    aim_key           = Enum.UserInputType.MouseButton2,
    aim_part          = "Head",
    aim_max_distance  = 1500,
    team_check        = true,
    wall_check        = false,
    auto_shoot        = false,
}

local aim_target = nil
local aiming = false

local function is_alive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function is_enemy(plr)
    if plr == LocalPlayer then return false end
    if not CONFIG.team_check then return is_alive(plr) end
    local my_team = LocalPlayer.Team
    return plr.Team ~= my_team and is_alive(plr)
end

local function get_aim_part(plr)
    local char = plr.Character
    if not char then return nil end
    return char:FindFirstChild(CONFIG.aim_part)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
end

local function world_to_screen(pos)
    local sp, on_screen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), on_screen and sp.Z > 0
end

local esp_cache = {}

local function create_esp(plr)
    if esp_cache[plr] then return end
    local hl = Instance.new("Highlight")
    hl.Name = "ZTrongz_ESP"
    hl.FillColor = CONFIG.esp_color
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = plr.Character or plr
    esp_cache[plr] = hl
end

local function remove_esp(plr)
    if esp_cache[plr] then
        esp_cache[plr]:Destroy()
        esp_cache[plr] = nil
    end
end

local fov_circle
if CONFIG.fov_enabled and Drawing then
    fov_circle = Drawing.new("Circle")
    fov_circle.Thickness = 1
    fov_circle.NumSides = 64
    fov_circle.Radius = CONFIG.fov_radius
    fov_circle.Filled = false
    fov_circle.Color = CONFIG.fov_color
    fov_circle.Transparency = 0.8
    fov_circle.Visible = true
end

local function get_closest_target()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, best_dist = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if not is_enemy(plr) then continue end
        local part = get_aim_part(plr)
        if not part then continue end
        if (Camera.CFrame.Position - part.Position).Magnitude > CONFIG.aim_max_distance then continue end

        local screen_pos, visible = world_to_screen(part.Position)
        if not visible then continue end

        if CONFIG.wall_check then
            local ray = Ray.new(Camera.CFrame.Position, part.Position - Camera.CFrame.Position)
            local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, part.Parent})
            if hit then continue end
        end

        local dist = (screen_pos - center).Magnitude
        if dist <= CONFIG.fov_radius and dist < best_dist then
            best, best_dist = plr, dist
        end
    end
    return best
end

local oldIndex
oldIndex = hookmetamethod(game, "__index", function(self, key)
    if not checkcaller() and aim_target and aiming then
        local target_part = get_aim_part(aim_target)
        if target_part then
            if (key == "Velocity" or key == "UnitRay" or key == "LookVector") then
                if self == Workspace.CurrentCamera or self:IsA("Tool") or self:IsA("BasePart") then
                    if key == "LookVector" then
                        return (target_part.Position - self.Position).Unit
                    end
                end
            end
        end
    end
    return oldIndex(self, key)
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == CONFIG.aim_key then
        aiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == CONFIG.aim_key then
        aiming = false
    end
end)

RunService.RenderStepped:Connect(function()
    if fov_circle then
        fov_circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end

    if CONFIG.esp_enabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if is_enemy(plr) then
                create_esp(plr)
            else
                remove_esp(plr)
            end
        end
    else
        for plr in pairs(esp_cache) do remove_esp(plr) end
    end

    if CONFIG.aimbot_enabled then
        aim_target = get_closest_target()
        if aim_target and CONFIG.auto_shoot then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
            if tool then
                tool:Activate()
            end
        end
    end
end)

Players.PlayerRemoving:Connect(remove_esp)