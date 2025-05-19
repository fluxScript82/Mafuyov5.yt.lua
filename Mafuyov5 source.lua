-- Mafuyo UI Library (Enhanced Version)
-- A powerful draggable UI library for Roblox with key system

local MafuyoLibrary = {}
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- UI Settings
local settings = {
    MainColor = Color3.fromRGB(40, 40, 40),
    AccentColor = Color3.fromRGB(255, 75, 75),
    TextColor = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamSemibold,
    ToggleKey = Enum.KeyCode.RightControl,
    DefaultOpen = true,
    NotificationDuration = 5,
    NotificationSound = true,
    AnimationsEnabled = true,
    RainbowThemeEnabled = false,
    BlurEffect = true,
    RoundedCorners = true,
    CornerRadius = UDim.new(0, 6),
    Transparency = 0.95,
    Version = "2.0"
}

-- Key System
local keySystem = {
    Enabled = true,
    Keys = {
        ["MAFUYO-PREMIUM-KEY"] = {
            Type = "Premium",
            ExpiryDate = "Never",
            HWID_Locked = false,
            AllowedHWIDs = {},
            Owner = "Admin"
        },
        ["MAFUYO-TRIAL-7DAYS"] = {
            Type = "Trial",
            ExpiryDate = os.time() + (7 * 24 * 60 * 60), -- 7 days from now
            HWID_Locked = true,
            AllowedHWIDs = {},
            Owner = "Trial User"
        }
    },
    Whitelist = {
        Enabled = false,
        Users = {"Player1", "Player2", "Admin"}
    },
    DiscordWebhook = "", -- For logging
    ServerKey = "MAFUYO-SERVER-VERIFICATION-KEY", -- For server verification
    EncryptionKey = "MAFUYO-ENCRYPTION-KEY", -- For local encryption
    LastVerification = 0
}

-- Utility Functions
local utils = {}

-- Generate HWID (Hardware ID)
function utils.GetHWID()
    local hwid = ""
    local placeid = game.PlaceId
    local jobid = game.JobId
    local userid = Player.UserId
    
    -- Create a unique identifier based on available data
    hwid = HttpService:GenerateGUID(false)
    
    -- Add some player-specific data to make it more unique
    local seed = tostring(placeid) .. tostring(userid) .. tostring(jobid)
    
    -- Simple hash function
    local hash = 0
    for i = 1, #seed do
        hash = ((hash << 5) - hash) + string.byte(seed, i)
        hash = hash & hash -- Convert to 32bit integer
    end
    
    return hwid .. "-" .. tostring(hash)
end

-- Simple encryption (for demonstration purposes)
function utils.Encrypt(data, key)
    if type(data) ~= "string" then
        data = HttpService:JSONEncode(data)
    end
    
    local encrypted = ""
    local keyLength = #key
    
    for i = 1, #data do
        local charByte = string.byte(data, i)
        local keyByte = string.byte(key, (i % keyLength) + 1)
        encrypted = encrypted .. string.char(bit32.bxor(charByte, keyByte))
    end
    
    return encrypted
end

-- Simple decryption
function utils.Decrypt(data, key)
    -- Decryption is the same as encryption with XOR
    return utils.Encrypt(data, key)
end

-- Save data to file
function utils.SaveToFile(name, data)
    local success, err = pcall(function()
        writefile("mafuyo_" .. name .. ".dat", utils.Encrypt(data, keySystem.EncryptionKey))
    end)
    return success
end

-- Load data from file
function utils.LoadFromFile(name)
    local success, content = pcall(function()
        return utils.Decrypt(readfile("mafuyo_" .. name .. ".dat"), keySystem.EncryptionKey)
    end)
    
    if success then
        local success2, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if success2 then
            return data
        end
    end
    return nil
end

-- Check if key is valid
function utils.ValidateKey(key)
    if not keySystem.Enabled then return true end
    
    -- Check if key exists
    local keyData = keySystem.Keys[key]
    if not keyData then return false, "Invalid key" end
    
    -- Check if key is expired
    if keyData.ExpiryDate ~= "Never" then
        if os.time() > keyData.ExpiryDate then
            return false, "Key expired"
        end
    end
    
    -- Check HWID lock
    if keyData.HWID_Locked then
        local hwid = utils.GetHWID()
        if #keyData.AllowedHWIDs > 0 then
            local hwid_allowed = false
            for _, allowed_hwid in ipairs(keyData.AllowedHWIDs) do
                if allowed_hwid == hwid then
                    hwid_allowed = true
                    break
                end
            end
            if not hwid_allowed then
                return false, "HWID not authorized"
            end
        else
            -- First time using this key, register HWID
            table.insert(keyData.AllowedHWIDs, hwid)
        end
    end
    
    -- Check whitelist
    if keySystem.Whitelist.Enabled then
        local playerName = Player.Name
        local whitelisted = false
        for _, name in ipairs(keySystem.Whitelist.Users) do
            if name == playerName then
                whitelisted = true
                break
            end
        end
        if not whitelisted then
            return false, "User not whitelisted"
        end
    end
    
    -- Update last verification time
    keySystem.LastVerification = os.time()
    
    return true, keyData.Type
end

-- Log key usage
function utils.LogKeyUsage(key, status, message)
    if keySystem.DiscordWebhook == "" then return end
    
    local data = {
        content = nil,
        embeds = {
            {
                title = "Mafuyo Key System Log",
                description = "Key usage detected",
                color = status and 65280 or 16711680, -- Green if valid, red if invalid
                fields = {
                    {name = "Player", value = Player.Name, inline = true},
                    {name = "Player ID", value = Player.UserId, inline = true},
                    {name = "Key", value = key, inline = false},
                    {name = "Status", value = status and "Valid" or "Invalid", inline = true},
                    {name = "Message", value = message or "N/A", inline = true},
                    {name = "HWID", value = utils.GetHWID(), inline = false},
                    {name = "Time", value = os.date("%Y-%m-%d %H:%M:%S"), inline = false}
                },
                footer = {
                    text = "Mafuyo UI Library v" .. settings.Version
                }
            }
        }
    }
    
    local headers = {
        ["Content-Type"] = "application/json"
    }
    
    spawn(function()
        pcall(function()
            HttpService:PostAsync(keySystem.DiscordWebhook, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson, false, headers)
        end)
    end)
end

-- Register a new key
function MafuyoLibrary:RegisterKey(key, keyData)
    if not keySystem.Keys[key] then
        keySystem.Keys[key] = keyData
        return true
    end
    return false
end

-- Verify key
function MafuyoLibrary:VerifyKey(key)
    local success, message = utils.ValidateKey(key)
    utils.LogKeyUsage(key, success, message)
    return success, message
end

-- Main UI Creation
function MafuyoLibrary:Create(title, logoImageId, key)
    -- Verify key if key system is enabled
    if keySystem.Enabled and key then
        local success, message = self:VerifyKey(key)
        if not success then
            -- Create a simple error UI
            local errorGui = Instance.new("ScreenGui")
            errorGui.Name = "MafuyoError"
            errorGui.ResetOnSpawn = false
            
            local errorFrame = Instance.new("Frame")
            errorFrame.Size = UDim2.new(0, 300, 0, 150)
            errorFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
            errorFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            errorFrame.BorderSizePixel = 0
            errorFrame.Parent = errorGui
            
            local errorCorner = Instance.new("UICorner")
            errorCorner.CornerRadius = UDim.new(0, 6)
            errorCorner.Parent = errorFrame
            
            local errorTitle = Instance.new("TextLabel")
            errorTitle.Size = UDim2.new(1, 0, 0, 30)
            errorTitle.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
            errorTitle.BorderSizePixel = 0
            errorTitle.Text = "Authentication Error"
            errorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            errorTitle.Font = Enum.Font.GothamBold
            errorTitle.TextSize = 16
            errorTitle.Parent = errorFrame
            
            local errorTitleCorner = Instance.new("UICorner")
            errorTitleCorner.CornerRadius = UDim.new(0, 6)
            errorTitleCorner.Parent = errorTitle
            
            local errorTitleFix = Instance.new("Frame")
            errorTitleFix.Size = UDim2.new(1, 0, 0.5, 0)
            errorTitleFix.Position = UDim2.new(0, 0, 0.5, 0)
            errorTitleFix.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
            errorTitleFix.BorderSizePixel = 0
            errorTitleFix.Parent = errorTitle
            
            local errorMessage = Instance.new("TextLabel")
            errorMessage.Size = UDim2.new(1, -20, 1, -40)
            errorMessage.Position = UDim2.new(0, 10, 0, 35)
            errorMessage.BackgroundTransparency = 1
            errorMessage.Text = "Key verification failed: " .. message .. "\n\nPlease contact the developer for assistance."
            errorMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
            errorMessage.Font = Enum.Font.Gotham
            errorMessage.TextSize = 14
            errorMessage.TextWrapped = true
            errorMessage.Parent = errorFrame
            
            errorGui.Parent = Player.PlayerGui
            
            return nil
        end
    end
    
    -- Create ScreenGui
    local MafuyoGui = Instance.new("ScreenGui")
    MafuyoGui.Name = "MafuyoLibrary"
    MafuyoGui.ResetOnSpawn = false
    MafuyoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Add blur effect if enabled
    if settings.BlurEffect then
        local blurEffect = Instance.new("BlurEffect")
        blurEffect.Size = 0
        blurEffect.Name = "MafuyoBlur"
        blurEffect.Parent = game:GetService("Lighting")
        
        -- Animate blur in
        TweenService:Create(blurEffect, TweenInfo.new(0.5), {Size = 10}):Play()
        
        -- Store reference to remove later
        MafuyoGui:SetAttribute("BlurEffect", true)
    end
    
    -- Create main container
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 500, 0, 350)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
    MainFrame.BackgroundColor3 = settings.MainColor
    MainFrame.BackgroundTransparency = 1 - settings.Transparency
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Active = true
    MainFrame.Visible = settings.DefaultOpen
    MainFrame.Parent = MafuyoGui
    
    -- Round corners if enabled
    if settings.RoundedCorners then
        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = settings.CornerRadius
        UICorner.Parent = MainFrame
    end
    
    -- Create top bar
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 30)
    TopBar.BackgroundColor3 = settings.AccentColor
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame
    
    if settings.RoundedCorners then
        local TopBarCorner = Instance.new("UICorner")
        TopBarCorner.CornerRadius = settings.CornerRadius
        TopBarCorner.Parent = TopBar
        
        local TopBarFix = Instance.new("Frame")
        TopBarFix.Name = "TopBarFix"
        TopBarFix.Size = UDim2.new(1, 0, 0.5, 0)
        TopBarFix.Position = UDim2.new(0, 0, 0.5, 0)
        TopBarFix.BackgroundColor3 = settings.AccentColor
        TopBarFix.BorderSizePixel = 0
        TopBarFix.Parent = TopBar
    end
    
    -- Title
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Size = UDim2.new(1, -120, 1, 0)
    TitleLabel.Position = UDim2.new(0, 30, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = title or "mafuyo UI Library"
    TitleLabel.TextColor3 = settings.TextColor
    TitleLabel.Font = settings.Font
    TitleLabel.TextSize = 16
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TopBar
    
    -- Version label
    local VersionLabel = Instance.new("TextLabel")
    VersionLabel.Name = "Version"
    VersionLabel.Size = UDim2.new(0, 50, 1, 0)
    VersionLabel.Position = UDim2.new(0, TitleLabel.Position.X.Offset + 5 + TitleLabel.TextBounds.X, 0, 0)
    VersionLabel.BackgroundTransparency = 1
    VersionLabel.Text = "v" .. settings.Version
    VersionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    VersionLabel.Font = settings.Font
    VersionLabel.TextSize = 12
    VersionLabel.TextXAlignment = Enum.TextXAlignment.Left
    VersionLabel.Parent = TopBar
    
    -- Logo
    local Logo = Instance.new("ImageLabel")
    Logo.Name = "Logo"
    Logo.Size = UDim2.new(0, 20, 0, 20)
    Logo.Position = UDim2.new(0, 5, 0, 5)
    Logo.BackgroundTransparency = 1
    Logo.Image = logoImageId or "rbxassetid://6031280882" -- Default logo if none provided
    Logo.Parent = TopBar
    
    -- Close button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -30, 0, 0)
    CloseButton.BackgroundTransparency = 1
    CloseButton.Text = "×"
    CloseButton.TextColor3 = settings.TextColor
    CloseButton.Font = settings.Font
    CloseButton.TextSize = 24
    CloseButton.Parent = TopBar
    
    -- Mini button (for minimizing to small UI)
    local MiniButton = Instance.new("TextButton")
    MiniButton.Name = "MiniButton"
    MiniButton.Size = UDim2.new(0, 30, 0, 30)
    MiniButton.Position = UDim2.new(1, -60, 0, 0)
    MiniButton.BackgroundTransparency = 1
    MiniButton.Text = "−"
    MiniButton.TextColor3 = settings.TextColor
    MiniButton.Font = settings.Font
    MiniButton.TextSize = 24
    MiniButton.Parent = TopBar
    
    -- Settings button
    local SettingsButton = Instance.new("TextButton")
    SettingsButton.Name = "SettingsButton"
    SettingsButton.Size = UDim2.new(0, 30, 0, 30)
    SettingsButton.Position = UDim2.new(1, -90, 0, 0)
    SettingsButton.BackgroundTransparency = 1
    SettingsButton.Text = "⚙"
    SettingsButton.TextColor3 = settings.TextColor
    SettingsButton.Font = settings.Font
    SettingsButton.TextSize = 18
    SettingsButton.Parent = TopBar
    
    -- Content container
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, 0, 1, -30)
    ContentFrame.Position = UDim2.new(0, 0, 0, 30)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame
    
    -- Tab container
    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(0, 120, 1, 0)
    TabContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    TabContainer.BackgroundTransparency = 1 - settings.Transparency
    TabContainer.BorderSizePixel = 0
    TabContainer.Parent = ContentFrame
    
    if settings.RoundedCorners then
        local TabContainerCorner = Instance.new("UICorner")
        TabContainerCorner.CornerRadius = settings.CornerRadius
        TabContainerCorner.Parent = TabContainer
        
        local TabContainerFix = Instance.new("Frame")
        TabContainerFix.Name = "TabContainerFix"
        TabContainerFix.Size = UDim2.new(0.5, 0, 1, 0)
        TabContainerFix.Position = UDim2.new(0.5, 0, 0, 0)
        TabContainerFix.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        TabContainerFix.BackgroundTransparency = 1 - settings.Transparency
        TabContainerFix.BorderSizePixel = 0
        TabContainerFix.Parent = TabContainer
    end
    
    -- Search bar for tabs
    local SearchBar = Instance.new("TextBox")
    SearchBar.Name = "SearchBar"
    SearchBar.Size = UDim2.new(1, -10, 0, 25)
    SearchBar.Position = UDim2.new(0, 5, 0, 5)
    SearchBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    SearchBar.BackgroundTransparency = 0.2
    SearchBar.BorderSizePixel = 0
    SearchBar.PlaceholderText = "Search..."
    SearchBar.Text = ""
    SearchBar.TextColor3 = settings.TextColor
    SearchBar.PlaceholderColor3 = Color3.fromRGB(180, 180, 180)
    SearchBar.Font = settings.Font
    SearchBar.TextSize = 14
    SearchBar.Parent = TabContainer
    
    if settings.RoundedCorners then
        local SearchBarCorner = Instance.new("UICorner")
        SearchBarCorner.CornerRadius = UDim.new(0, 4)
        SearchBarCorner.Parent = SearchBar
    end

    local TabList = Instance.new("ScrollingFrame")
    TabList.Name = "TabList"
    TabList.Size = UDim2.new(1, 0, 1, -35)
    TabList.Position = UDim2.new(0, 0, 0, 35)
    TabList.BackgroundTransparency = 1
    TabList.BorderSizePixel = 0
    TabList.ScrollBarThickness = 2
    TabList.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabList.Parent = TabContainer
    
    local TabListLayout = Instance.new("UIListLayout")
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabListLayout.Padding = UDim.new(0, 5)
    TabListLayout.Parent = TabList
    
    local TabListPadding = Instance.new("UIPadding")
    TabListPadding.PaddingTop = UDim.new(0, 5)
    TabListPadding.PaddingLeft = UDim.new(0, 5)
    TabListPadding.PaddingRight = UDim.new(0, 5)
    TabListPadding.Parent = TabList
    
    -- Tab content container
    local TabContent = Instance.new("Frame")
    TabContent.Name = "TabContent"
    TabContent.Size = UDim2.new(1, -120, 1, 0)
    TabContent.Position = UDim2.new(0, 120, 0, 0)
    TabContent.BackgroundTransparency = 1
    TabContent.Parent = ContentFrame
    
    -- Settings panel
    local SettingsPanel = Instance.new("Frame")
    SettingsPanel.Name = "SettingsPanel"
    SettingsPanel.Size = UDim2.new(1, -120, 1, 0)
    SettingsPanel.Position = UDim2.new(0, 120, 0, 0)
    SettingsPanel.BackgroundTransparency = 1
    SettingsPanel.Visible = false
    SettingsPanel.Parent = ContentFrame
    
    local SettingsScroll = Instance.new("ScrollingFrame")
    SettingsScroll.Name = "SettingsScroll"
    SettingsScroll.Size = UDim2.new(1, -20, 1, -20)
    SettingsScroll.Position = UDim2.new(0, 10, 0, 10)
    SettingsScroll.BackgroundTransparency = 1
    SettingsScroll.BorderSizePixel = 0
    SettingsScroll.ScrollBarThickness = 2
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SettingsScroll.Parent = SettingsPanel
    
    local SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsLayout.Padding = UDim.new(0, 10)
    SettingsLayout.Parent = SettingsScroll
    
    local SettingsPadding = Instance.new("UIPadding")
    SettingsPadding.PaddingTop = UDim.new(0, 10)
    SettingsPadding.PaddingLeft = UDim.new(0, 10)
    SettingsPadding.PaddingRight = UDim.new(0, 10)
    SettingsPadding.Parent = SettingsScroll
    
    -- Settings title
    local SettingsTitle = Instance.new("TextLabel")
    SettingsTitle.Name = "SettingsTitle"
    SettingsTitle.Size = UDim2.new(1, 0, 0, 30)
    SettingsTitle.BackgroundTransparency = 1
    SettingsTitle.Text = "Settings"
    SettingsTitle.TextColor3 = settings.TextColor
    SettingsTitle.Font = Enum.Font.GothamBold
    SettingsTitle.TextSize = 18
    SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    SettingsTitle.Parent = SettingsScroll
    
    -- Create settings options
    local function createToggleSetting(name, description, default, callback)
        local SettingFrame = Instance.new("Frame")
        SettingFrame.Name = name .. "Setting"
        SettingFrame.Size = UDim2.new(1, 0, 0, 50)
        SettingFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        SettingFrame.BackgroundTransparency = 0.5
        SettingFrame.BorderSizePixel = 0
        SettingFrame.Parent = SettingsScroll
        
        if settings.RoundedCorners then
            local SettingCorner = Instance.new("UICorner")
            SettingCorner.CornerRadius = UDim.new(0, 4)
            SettingCorner.Parent = SettingFrame
        end
        
        local SettingTitle = Instance.new("TextLabel")
        SettingTitle.Name = "Title"
        SettingTitle.Size = UDim2.new(1, -60, 0, 20)
        SettingTitle.Position = UDim2.new(0, 10, 0, 5)
        SettingTitle.BackgroundTransparency = 1
        SettingTitle.Text = name
        SettingTitle.TextColor3 = settings.TextColor
        SettingTitle.Font = settings.Font
        SettingTitle.TextSize = 14
        SettingTitle.TextXAlignment = Enum.TextXAlignment.Left
        SettingTitle.Parent = SettingFrame
        
        local SettingDescription = Instance.new("TextLabel")
        SettingDescription.Name = "Description"
        SettingDescription.Size = UDim2.new(1, -60, 0, 20)
        SettingDescription.Position = UDim2.new(0, 10, 0, 25)
        SettingDescription.BackgroundTransparency = 1
        SettingDescription.Text = description
        SettingDescription.TextColor3 = Color3.fromRGB(180, 180, 180)
        SettingDescription.Font = Enum.Font.Gotham
        SettingDescription.TextSize = 12
        SettingDescription.TextXAlignment = Enum.TextXAlignment.Left
        SettingDescription.Parent = SettingFrame
        
        local ToggleButton = Instance.new("Frame")
        ToggleButton.Name = "ToggleButton"
        ToggleButton.Size = UDim2.new(0, 40, 0, 20)
        ToggleButton.Position = UDim2.new(1, -50, 0.5, -10)
        ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        ToggleButton.BorderSizePixel = 0
        ToggleButton.Parent = SettingFrame
        
        if settings.RoundedCorners then
            local ToggleButtonCorner = Instance.new("UICorner")
            ToggleButtonCorner.CornerRadius = UDim.new(1, 0)
            ToggleButtonCorner.Parent = ToggleButton
        end
        
        local ToggleCircle = Instance.new("Frame")
        ToggleCircle.Name = "Circle"
        ToggleCircle.Size = UDim2.new(0, 16, 0, 16)
        ToggleCircle.Position = UDim2.new(0, 2, 0.5, -8)
        ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ToggleCircle.BorderSizePixel = 0
        ToggleCircle.Parent = ToggleButton
        
        if settings.RoundedCorners then
            local ToggleCircleCorner = Instance.new("UICorner")
            ToggleCircleCorner.CornerRadius = UDim.new(1, 0)
            ToggleCircleCorner.Parent = ToggleCircle
        end
        
        local toggled = default
        
        local function updateToggle()
            if toggled then
                TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = settings.AccentColor}):Play()
                TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 22, 0.5, -8)}):Play()
            else
                TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
                TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -8)}):Play()
            end
            callback(toggled)
        end
        
        SettingFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                toggled = not toggled
                updateToggle()
            end
        end)
        
        -- Initialize with default value
        if default then
            updateToggle()
        end
        
        return {
            Frame = SettingFrame,
            Set = function(value)
                toggled = value
                updateToggle()
            end
        }
    end
    
    -- Add settings
    local themeToggle = createToggleSetting(
        "Rainbow Theme", 
        "Enable rainbow color effect for accent elements",
        settings.RainbowThemeEnabled,
        function(value)
            settings.RainbowThemeEnabled = value
        end
    )
    
    local blurToggle = createToggleSetting(
        "Background Blur", 
        "Add blur effect to the game background",
        settings.BlurEffect,
        function(value)
            settings.BlurEffect = value
            local lighting = game:GetService("Lighting")
            local blur = lighting:FindFirstChild("MafuyoBlur")
            
            if value then
                if not blur then
                    blur = Instance.new("BlurEffect")
                    blur.Size = 10
                    blur.Name = "MafuyoBlur"
                    blur.Parent = lighting
                end
            else
                if blur then
                    blur:Destroy()
                end
            end
        end
    )
    
    local animationsToggle = createToggleSetting(
        "Animations", 
        "Enable UI animations and transitions",
        settings.AnimationsEnabled,
        function(value)
            settings.AnimationsEnabled = value
        end
    )
    
    local soundToggle = createToggleSetting(
        "Notification Sounds", 
        "Play sounds when notifications appear",
        settings.NotificationSound,
        function(value)
            settings.NotificationSound = value
        end
    )
    
    -- Mini UI (when minimized)
    local MiniUI = Instance.new("Frame")
    MiniUI.Name = "MiniUI"
    MiniUI.Size = UDim2.new(0, 50, 0, 50)
    MiniUI.Position = UDim2.new(0, 20, 0, 20)
    MiniUI.BackgroundColor3 = settings.MainColor
    MiniUI.BackgroundTransparency = 1 - settings.Transparency
    MiniUI.BorderSizePixel = 0
    MiniUI.Visible = not settings.DefaultOpen
    MiniUI.Active = true
    MiniUI.Parent = MafuyoGui
    
    if settings.RoundedCorners then
        local MiniUICorner = Instance.new("UICorner")
        MiniUICorner.CornerRadius = UDim.new(1, 0)
        MiniUICorner.Parent = MiniUI
    end
    
    local MiniLogo = Instance.new("ImageLabel")
    MiniLogo.Name = "MiniLogo"
    MiniLogo.Size = UDim2.new(0, 30, 0, 30)
    MiniLogo.Position = UDim2.new(0.5, -15, 0.5, -15)
    MiniLogo.BackgroundTransparency = 1
    MiniLogo.Image = logoImageId or "rbxassetid://6031280882"
    MiniLogo.Parent = MiniUI
    
    -- Notification system
    local NotificationFrame = Instance.new("Frame")
    NotificationFrame.Name = "NotificationFrame"
    NotificationFrame.Size = UDim2.new(0, 250, 1, 0)
    NotificationFrame.Position = UDim2.new(1, -250, 0, 0)
    NotificationFrame.BackgroundTransparency = 1
    NotificationFrame.Parent = MafuyoGui
    
    local NotificationList = Instance.new("Frame")
    NotificationList.Name = "NotificationList"
    NotificationList.Size = UDim2.new(1, 0, 1, 0)
    NotificationList.BackgroundTransparency = 1
    NotificationList.Parent = NotificationFrame
    
    local NotificationLayout = Instance.new("UIListLayout")
    NotificationLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NotificationLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotificationLayout.Padding = UDim.new(0, 5)
    NotificationLayout.Parent = NotificationList
    
    -- Make UI draggable
    local function makeDraggable(frame)
        local dragToggle = nil
        local dragSpeed = 0.25
        local dragStart = nil
        local startPos = nil
        
        local function updateInput(input)
            local delta = input.Position - dragStart
            local position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            TweenService:Create(frame, TweenInfo.new(dragSpeed), {Position = position}):Play()
        end
        
        frame.InputBegan:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragToggle = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragToggle = false
                    end
                end)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                if dragToggle then
                    updateInput(input)
                end
            end
        end)
    end
    
    makeDraggable(MainFrame)
    makeDraggable(MiniUI)
    
    -- Toggle UI with keybind
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == settings.ToggleKey then
            MainFrame.Visible = not MainFrame.Visible
            MiniUI.Visible = not MiniUI.Visible
        end
    end)
    
    -- Close button functionality
    CloseButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        MiniUI.Visible = true
    end)
    
    -- Mini button functionality
    MiniButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        MiniUI.Visible = true
    end)
    
    -- Settings button functionality
    SettingsButton.MouseButton1Click:Connect(function()
        SettingsPanel.Visible = not SettingsPanel.Visible
        TabContent.Visible = not SettingsPanel.Visible
    end)
    
    -- Mini UI click to open
    MiniUI.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            MainFrame.Visible = true
            MiniUI.Visible = false
        end
    end)
    
    -- Search functionality
    SearchBar.Changed:Connect(function(prop)
        if prop == "Text" then
            local searchText = string.lower(SearchBar.Text)
            for _, child in pairs(TabList:GetChildren()) do
                if child:IsA("TextButton") then
                    if searchText == "" then
                        child.Visible = true
                    else
                        local buttonText = string.lower(child.Text)
                        child.Visible = string.find(buttonText, searchText) ~= nil
                    end
                end
            end
        end
    end)
    
    -- Rainbow theme effect
    if settings.RainbowThemeEnabled then
        spawn(function()
            local hue = 0
            while true do
                if settings.RainbowThemeEnabled then
                    hue = (hue + 1) % 360
                    local color = Color3.fromHSV(hue/360, 0.8, 1)
                    TweenService:Create(TopBar, TweenInfo.new(1), {BackgroundColor3 = color}):Play()
                    if TopBar:FindFirstChild("TopBarFix") then
                        TweenService:Create(TopBar.TopBarFix, TweenInfo.new(1), {BackgroundColor3 = color}):Play()
                    end
                end
                wait(0.05)
            end
        end)
    end
    
    -- Library functions
    local library = {}
    local tabs = {}
    local currentTab = nil
    
    -- Create a notification
    function library:Notify(title, message, notifType, duration)
        notifType = notifType or "Info" -- Info, Success, Warning, Error
        duration = duration or settings.NotificationDuration
        
        local typeColors = {
            Info = Color3.fromRGB(0, 120, 255),
            Success = Color3.fromRGB(0, 200, 0),
            Warning = Color3.fromRGB(255, 150, 0),
            Error = Color3.fromRGB(255, 50, 50)
        }
        
        local NotifFrame = Instance.new("Frame")
        NotifFrame.Name = "Notification"
        NotifFrame.Size = UDim2.new(1, -10, 0, 80)
        NotifFrame.Position = UDim2.new(1, 0, 0, 0)
        NotifFrame.BackgroundColor3 = settings.MainColor
        NotifFrame.BackgroundTransparency = 0.1
        NotifFrame.BorderSizePixel = 0
        NotifFrame.Parent = NotificationList
        
        if settings.RoundedCorners then
            local NotifCorner = Instance.new("UICorner")
            NotifCorner.CornerRadius = UDim.new(0, 6)
            NotifCorner.Parent = NotifFrame
        end
        
        local NotifBar = Instance.new("Frame")
        NotifBar.Name = "Bar"
        NotifBar.Size = UDim2.new(0, 5, 1, 0)
        NotifBar.BackgroundColor3 = typeColors[notifType]
        NotifBar.BorderSizePixel = 0
        NotifBar.Parent = NotifFrame
        
        if settings.RoundedCorners then
            local NotifBarCorner = Instance.new("UICorner")
            NotifBarCorner.CornerRadius = UDim.new(0, 6)
            NotifBarCorner.Parent = NotifBar
            
            local NotifBarFix = Instance.new("Frame")
            NotifBarFix.Size = UDim2.new(0.5, 0, 1, 0)
            NotifBarFix.Position = UDim2.new(0.5, 0, 0, 0)
            NotifBarFix.BackgroundColor3 = typeColors[notifType]
            NotifBarFix.BorderSizePixel = 0
            NotifBarFix.Parent = NotifBar
        end
        
        local NotifTitle = Instance.new("TextLabel")
        NotifTitle.Name = "Title"
        NotifTitle.Size = UDim2.new(1, -20, 0, 25)
        NotifTitle.Position = UDim2.new(0, 15, 0, 5)
        NotifTitle.BackgroundTransparency = 1
        NotifTitle.Text = title
        NotifTitle.TextColor3 = settings.TextColor
        NotifTitle.Font = Enum.Font.GothamBold
        NotifTitle.TextSize = 14
        NotifTitle.TextXAlignment = Enum.TextXAlignment.Left
        NotifTitle.Parent = NotifFrame
        
        local NotifMessage = Instance.new("TextLabel")
        NotifMessage.Name = "Message"
        NotifMessage.Size = UDim2.new(1, -20, 1, -35)
        NotifMessage.Position = UDim2.new(0, 15, 0, 30)
        NotifMessage.BackgroundTransparency = 1
        NotifMessage.Text = message
        NotifMessage.TextColor3 = Color3.fromRGB(200, 200, 200)
        NotifMessage.Font = Enum.Font.Gotham
        NotifMessage.TextSize = 14
        NotifMessage.TextWrapped = true
        NotifMessage.TextXAlignment = Enum.TextXAlignment.Left
        NotifMessage.Parent = NotifFrame
        
        local NotifClose = Instance.new("TextButton")
        NotifClose.Name = "Close"
        NotifClose.Size = UDim2.new(0, 20, 0, 20)
        NotifClose.Position = UDim2.new(1, -25, 0, 5)
        NotifClose.BackgroundTransparency = 1
        NotifClose.Text = "×"
        NotifClose.TextColor3 = settings.TextColor
        NotifClose.Font = settings.Font
        NotifClose.TextSize = 20
        NotifClose.Parent = NotifFrame
        
        -- Progress bar
        local ProgressBar = Instance.new("Frame")
        ProgressBar.Name = "Progress"
        ProgressBar.Size = UDim2.new(1, 0, 0, 2)
        ProgressBar.Position = UDim2.new(0, 0, 1, -2)
        ProgressBar.BackgroundColor3 = typeColors[notifType]
        ProgressBar.BorderSizePixel = 0
        ProgressBar.Parent = NotifFrame
        
        -- Play sound if enabled
        if settings.NotificationSound then
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://6518811702" -- Default notification sound
            sound.Volume = 0.5
            sound.Parent = NotifFrame
            sound:Play()
            
            -- Auto destroy sound after playing
            sound.Ended:Connect(function()
                sound:Destroy()
            end)
        end
        
        -- Animate in
        TweenService:Create(NotifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, 0)}):Play()
        
        -- Progress bar animation
        TweenService:Create(ProgressBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)}):Play()
        
        -- Close button functionality
        NotifClose.MouseButton1Click:Connect(function()
            TweenService:Create(NotifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(1, 0, 0, 0)}):Play()
            wait(0.5)
            NotifFrame:Destroy()
        end)

                -- Auto close after duration
        spawn(function()
            wait(duration)
            if NotifFrame and NotifFrame.Parent then
                TweenService:Create(NotifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(1, 0, 0, 0)}):Play()
                wait(0.5)
                if NotifFrame and NotifFrame.Parent then
                    NotifFrame:Destroy()
                end
            end
        end)
        
        return NotifFrame
    end
    
    -- Create a new tab
    function library:CreateTab(name, icon)
        local tab = {}
        
        -- Tab button
        local TabButton = Instance.new("TextButton")
        TabButton.Name = name.."Tab"
        TabButton.Size = UDim2.new(1, 0, 0, 30)
        TabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        TabButton.BackgroundTransparency = 0.5
        TabButton.BorderSizePixel = 0
        TabButton.Text = name
        TabButton.TextColor3 = settings.TextColor
        TabButton.Font = settings.Font
        TabButton.TextSize = 14
        TabButton.Parent = TabList
        
        if settings.RoundedCorners then
            local TabButtonCorner = Instance.new("UICorner")
            TabButtonCorner.CornerRadius = UDim.new(0, 4)
            TabButtonCorner.Parent = TabButton
        end
        
        -- Tab icon
        if icon then
            local TabIcon = Instance.new("ImageLabel")
            TabIcon.Name = "Icon"
            TabIcon.Size = UDim2.new(0, 16, 0, 16)
            TabIcon.Position = UDim2.new(0, 5, 0.5, -8)
            TabIcon.BackgroundTransparency = 1
            TabIcon.Image = icon
            TabIcon.Parent = TabButton
            
            -- Adjust text position
            TabButton.TextXAlignment = Enum.TextXAlignment.Right
            TabButton.Text = "  " .. name
        end
        
        -- Tab content
        local TabFrame = Instance.new("ScrollingFrame")
        TabFrame.Name = name.."Content"
        TabFrame.Size = UDim2.new(1, 0, 1, 0)
        TabFrame.BackgroundTransparency = 1
        TabFrame.BorderSizePixel = 0
        TabFrame.ScrollBarThickness = 2
        TabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        TabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        TabFrame.Visible = false
        TabFrame.Parent = TabContent
        
        local TabFrameLayout = Instance.new("UIListLayout")
        TabFrameLayout.SortOrder = Enum.SortOrder.LayoutOrder
        TabFrameLayout.Padding = UDim.new(0, 10)
        TabFrameLayout.Parent = TabFrame
        
        local TabFramePadding = Instance.new("UIPadding")
        TabFramePadding.PaddingTop = UDim.new(0, 10)
        TabFramePadding.PaddingLeft = UDim.new(0, 10)
        TabFramePadding.PaddingRight = UDim.new(0, 10)
        TabFramePadding.Parent = TabFrame
        
        -- Select tab function
        local function selectTab()
            for _, t in pairs(tabs) do
                t.Frame.Visible = false
                t.Button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            end
            TabFrame.Visible = true
            TabButton.BackgroundColor3 = settings.AccentColor
            currentTab = tab
            
            -- Hide settings panel
            SettingsPanel.Visible = false
        end
        
        TabButton.MouseButton1Click:Connect(selectTab)
        
        -- Add to tabs table
        tab.Frame = TabFrame
        tab.Button = TabButton
        tab.Name = name
        table.insert(tabs, tab)
        
        -- If this is the first tab, select it
        if #tabs == 1 then
            selectTab()
        end
        
        -- Tab elements
        function tab:AddButton(text, callback)
            local Button = Instance.new("TextButton")
            Button.Name = text.."Button"
            Button.Size = UDim2.new(1, -20, 0, 30)
            Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            Button.BackgroundTransparency = 0.5
            Button.BorderSizePixel = 0
            Button.Text = text
            Button.TextColor3 = settings.TextColor
            Button.Font = settings.Font
            Button.TextSize = 14
            Button.Parent = TabFrame
            
            if settings.RoundedCorners then
                local ButtonCorner = Instance.new("UICorner")
                ButtonCorner.CornerRadius = UDim.new(0, 4)
                ButtonCorner.Parent = Button
            end
            
            -- Ripple effect
            local function createRipple(x, y)
                local Ripple = Instance.new("Frame")
                Ripple.Name = "Ripple"
                Ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Ripple.BackgroundTransparency = 0.7
                Ripple.BorderSizePixel = 0
                Ripple.Position = UDim2.new(0, x - 5, 0, y - 5)
                Ripple.Size = UDim2.new(0, 10, 0, 10)
                Ripple.Parent = Button
                
                if settings.RoundedCorners then
                    local RippleCorner = Instance.new("UICorner")
                    RippleCorner.CornerRadius = UDim.new(1, 0)
                    RippleCorner.Parent = Ripple
                end
                
                local targetSize = UDim2.new(0, Button.AbsoluteSize.X * 2, 0, Button.AbsoluteSize.X * 2)
                local targetPos = UDim2.new(0.5, -Button.AbsoluteSize.X, 0.5, -Button.AbsoluteSize.X)
                
                TweenService:Create(Ripple, TweenInfo.new(0.5), {
                    Size = targetSize,
                    Position = targetPos,
                    BackgroundTransparency = 1
                }):Play()
                
                wait(0.5)
                Ripple:Destroy()
            end
            
            Button.MouseButton1Down:Connect(function()
                local x, y = Mouse.X - Button.AbsolutePosition.X, Mouse.Y - Button.AbsolutePosition.Y
                createRipple(x, y)
                callback()
            end)
            
            -- Hover effect
            Button.MouseEnter:Connect(function()
                TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(70, 70, 70)}):Play()
            end)
            
            Button.MouseLeave:Connect(function()
                TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
            end)
            
            return Button
        end
        
        function tab:AddToggle(text, default, callback)
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Name = text.."Toggle"
            ToggleFrame.Size = UDim2.new(1, -20, 0, 30)
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            ToggleFrame.BackgroundTransparency = 0.5
            ToggleFrame.BorderSizePixel = 0
            ToggleFrame.Parent = TabFrame
            
            if settings.RoundedCorners then
                local ToggleCorner = Instance.new("UICorner")
                ToggleCorner.CornerRadius = UDim.new(0, 4)
                ToggleCorner.Parent = ToggleFrame
            end
            
            local ToggleLabel = Instance.new("TextLabel")
            ToggleLabel.Name = "Label"
            ToggleLabel.Size = UDim2.new(1, -50, 1, 0)
            ToggleLabel.BackgroundTransparency = 1
            ToggleLabel.Text = text
            ToggleLabel.TextColor3 = settings.TextColor
            ToggleLabel.Font = settings.Font
            ToggleLabel.TextSize = 14
            ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
            ToggleLabel.Parent = ToggleFrame
            
            local TogglePadding = Instance.new("UIPadding")
            TogglePadding.PaddingLeft = UDim.new(0, 10)
            TogglePadding.Parent = ToggleLabel
            
            local ToggleButton = Instance.new("Frame")
            ToggleButton.Name = "ToggleButton"
            ToggleButton.Size = UDim2.new(0, 40, 0, 20)
            ToggleButton.Position = UDim2.new(1, -45, 0.5, -10)
            ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            ToggleButton.BorderSizePixel = 0
            ToggleButton.Parent = ToggleFrame
            
            if settings.RoundedCorners then
                local ToggleButtonCorner = Instance.new("UICorner")
                ToggleButtonCorner.CornerRadius = UDim.new(1, 0)
                ToggleButtonCorner.Parent = ToggleButton
            end
            
            local ToggleCircle = Instance.new("Frame")
            ToggleCircle.Name = "Circle"
            ToggleCircle.Size = UDim2.new(0, 16, 0, 16)
            ToggleCircle.Position = UDim2.new(0, 2, 0.5, -8)
            ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            ToggleCircle.BorderSizePixel = 0
            ToggleCircle.Parent = ToggleButton
            
            if settings.RoundedCorners then
                local ToggleCircleCorner = Instance.new("UICorner")
                ToggleCircleCorner.CornerRadius = UDim.new(1, 0)
                ToggleCircleCorner.Parent = ToggleCircle
            end
            
            local toggled = default or false
            
            local function updateToggle()
                if toggled then
                    TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = settings.AccentColor}):Play()
                    TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 22, 0.5, -8)}):Play()
                else
                    TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
                    TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -8)}):Play()
                end
                callback(toggled)
            end
            
            ToggleFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    toggled = not toggled
                    updateToggle()
                end
            end)
            
            -- Initialize with default value
            if default then
                updateToggle()
            end
            
            local toggle = {}
            
            function toggle:Set(value)
                toggled = value
                updateToggle()
            end
            
            return toggle
        end
        
        function tab:AddSlider(text, min, max, default, callback)
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Name = text.."Slider"
            SliderFrame.Size = UDim2.new(1, -20, 0, 50)
            SliderFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            SliderFrame.BackgroundTransparency = 0.5
            SliderFrame.BorderSizePixel = 0
            SliderFrame.Parent = TabFrame
            
            if settings.RoundedCorners then
                local SliderCorner = Instance.new("UICorner")
                SliderCorner.CornerRadius = UDim.new(0, 4)
                SliderCorner.Parent = SliderFrame
            end
            
            local SliderLabel = Instance.new("TextLabel")
            SliderLabel.Name = "Label"
            SliderLabel.Size = UDim2.new(1, 0, 0, 20)
            SliderLabel.BackgroundTransparency = 1
            SliderLabel.Text = text
            SliderLabel.TextColor3 = settings.TextColor
            SliderLabel.Font = settings.Font
            SliderLabel.TextSize = 14
            SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
            SliderLabel.Parent = SliderFrame
            
            local SliderPadding = Instance.new("UIPadding")
            SliderPadding.PaddingLeft = UDim.new(0, 10)
            SliderPadding.PaddingRight = UDim.new(0, 10)
            SliderPadding.Parent = SliderFrame
            
            local SliderValue = Instance.new("TextLabel")
            SliderValue.Name = "Value"
            SliderValue.Size = UDim2.new(0, 30, 0, 20)
            SliderValue.Position = UDim2.new(1, -30, 0, 0)
            SliderValue.BackgroundTransparency = 1
            SliderValue.Text = tostring(default or min)
            SliderValue.TextColor3 = settings.TextColor
            SliderValue.Font = settings.Font
            SliderValue.TextSize = 14
            SliderValue.TextXAlignment = Enum.TextXAlignment.Right
            SliderValue.Parent = SliderFrame
            
            local SliderBG = Instance.new("Frame")
            SliderBG.Name = "Background"
            SliderBG.Size = UDim2.new(1, 0, 0, 10)
            SliderBG.Position = UDim2.new(0, 0, 0.5, 5)
            SliderBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            SliderBG.BorderSizePixel = 0
            SliderBG.Parent = SliderFrame
            
            if settings.RoundedCorners then
                local SliderBGCorner = Instance.new("UICorner")
                SliderBGCorner.CornerRadius = UDim.new(1, 0)
                SliderBGCorner.Parent = SliderBG
            end
            
            local SliderFill = Instance.new("Frame")
            SliderFill.Name = "Fill"
            SliderFill.Size = UDim2.new(0, 0, 1, 0)
            SliderFill.BackgroundColor3 = settings.AccentColor
            SliderFill.BorderSizePixel = 0
            SliderFill.Parent = SliderBG
            
            if settings.RoundedCorners then
                local SliderFillCorner = Instance.new("UICorner")
                SliderFillCorner.CornerRadius = UDim.new(1, 0)
                SliderFillCorner.Parent = SliderFill
            end
            
            local SliderCircle = Instance.new("Frame")
            SliderCircle.Name = "Circle"
            SliderCircle.Size = UDim2.new(0, 16, 0, 16)
            SliderCircle.Position = UDim2.new(0, -8, 0.5, -8)
            SliderCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SliderCircle.BorderSizePixel = 0
            
            if settings.RoundedCorners then
                local SliderCircleCorner = Instance.new("UICorner")
                SliderCircleCorner.CornerRadius = UDim.new(1, 0)
                SliderCircleCorner.Parent = SliderCircle
            end
            
            local value = default or min
            local dragging = false
            
            local function updateSlider(input)
                local sizeX = math.clamp((input.Position.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X, 0, 1)
                value = math.floor(min + ((max - min) * sizeX))
                SliderValue.Text = tostring(value)
                TweenService:Create(SliderFill, TweenInfo.new(0.1), {Size = UDim2.new(sizeX, 0, 1, 0)}):Play()
                callback(value)
            end
            
            SliderBG.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    updateSlider(input)
                end
            end)
            
            SliderBG.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)
            
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateSlider(input)
                end
            end)
            
            -- Initialize with default value
            local defaultRatio = (default - min) / (max - min)
            SliderFill.Size = UDim2.new(defaultRatio, 0, 1, 0)
            
            local slider = {}
            
            function slider:Set(newValue)
                value = math.clamp(newValue, min, max)
                local sizeX = (value - min) / (max - min)
                SliderValue.Text = tostring(value)
                SliderFill.Size = UDim2.new(sizeX, 0, 1, 0)
                callback(value)
            end
            
            return slider
        end
        
        function tab:AddDropdown(text, options, default, callback)
            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Name = text.."Dropdown"
            DropdownFrame.Size = UDim2.new(1, -20, 0, 30)
            DropdownFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            DropdownFrame.BackgroundTransparency = 0.5
            DropdownFrame.BorderSizePixel = 0
            DropdownFrame.Parent = TabFrame
            
            if settings.RoundedCorners then
                local DropdownCorner = Instance.new("UICorner")
                DropdownCorner.CornerRadius = UDim.new(0, 4)
                DropdownCorner.Parent = DropdownFrame
            end
            
            local DropdownLabel = Instance.new("TextLabel")
            DropdownLabel.Name = "Label"
            DropdownLabel.Size = UDim2.new(0.5, 0, 1, 0)
            DropdownLabel.BackgroundTransparency = 1
            DropdownLabel.Text = text
            DropdownLabel.TextColor3 = settings.TextColor
            DropdownLabel.Font = settings.Font
            DropdownLabel.TextSize = 14
            DropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
            DropdownLabel.Parent = DropdownFrame
            
            local DropdownPadding = Instance.new("UIPadding")
            DropdownPadding.PaddingLeft = UDim.new(0, 10)
            DropdownPadding.Parent = DropdownLabel
            
            local DropdownButton = Instance.new("TextButton")
            DropdownButton.Name = "Button"
            DropdownButton.Size = UDim2.new(0.5, -10, 1, -6)
            DropdownButton.Position = UDim2.new(0.5, 5, 0, 3)
            DropdownButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            DropdownButton.BorderSizePixel = 0
            DropdownButton.Text = default or options[1] or "Select"
            DropdownButton.TextColor3 = settings.TextColor
            DropdownButton.Font = settings.Font
            DropdownButton.TextSize = 14
            DropdownButton.Parent = DropdownFrame
            
            if settings.RoundedCorners then
                local DropdownButtonCorner = Instance.new("UICorner")
                DropdownButtonCorner.CornerRadius = UDim.new(0, 4)
                DropdownButtonCorner.Parent = DropdownButton
            end
            
            local DropdownMenu = Instance.new("Frame")
            DropdownMenu.Name = "Menu"
            DropdownMenu.Size = UDim2.new(0.5, -10, 0, 0)
            DropdownMenu.Position = UDim2.new(0.5, 5, 1, 0)
            DropdownMenu.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            DropdownMenu.BorderSizePixel = 0
            DropdownMenu.ClipsDescendants = true
            DropdownMenu.Visible = false
            DropdownMenu.ZIndex = 10
            DropdownMenu.Parent = DropdownFrame
            
            if settings.RoundedCorners then
                local DropdownMenuCorner = Instance.new("UICorner")
                DropdownMenuCorner.CornerRadius = UDim.new(0, 4)
                DropdownMenuCorner.Parent = DropdownMenu
            end
            
            local DropdownMenuLayout = Instance.new("UIListLayout")
            DropdownMenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
            DropdownMenuLayout.Parent = DropdownMenu
            
            local menuOpen = false
            local selected = default or options[1] or "Select"
            
            local function toggleMenu()
                menuOpen = not menuOpen
                if menuOpen then
                    DropdownMenu.Visible = true
                    TweenService:Create(DropdownMenu, TweenInfo.new(0.2), {Size = UDim2.new(0.5, -10, 0, #options * 30)}):Play()
                else
                    TweenService:Create(DropdownMenu, TweenInfo.new(0.2), {Size = UDim2.new(0.5, -10, 0, 0)}):Play()
                    wait(0.2)
                    DropdownMenu.Visible = false
                end
            end
            
            DropdownButton.MouseButton1Click:Connect(toggleMenu)
            
            -- Create option buttons
            for i, option in ipairs(options) do
                local OptionButton = Instance.new("TextButton")
                OptionButton.Name = option.."Option"
                OptionButton.Size = UDim2.new(1, 0, 0, 30)
                OptionButton.BackgroundTransparency = 1
                OptionButton.Text = option
                OptionButton.TextColor3 = settings.TextColor
                OptionButton.Font = settings.Font
                OptionButton.TextSize = 14
                OptionButton.ZIndex = 10
                OptionButton.Parent = DropdownMenu
                
                OptionButton.MouseButton1Click:Connect(function()
                    selected = option
                    DropdownButton.Text = selected
                    toggleMenu()
                    callback(selected)
                end)
            end
            
            local dropdown = {}
            
            function dropdown:Set(option)
                if table.find(options, option) then
                    selected = option
                    DropdownButton.Text = selected
                    callback(selected)
                end
            end
            
            return dropdown
        end
        
        function tab:AddColorPicker(text, default, callback)
            local ColorPickerFrame = Instance.new("Frame")
            ColorPickerFrame.Name = text.."ColorPicker"
            ColorPickerFrame.Size = UDim2.new(1, -20, 0, 30)
            ColorPickerFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            ColorPickerFrame.BackgroundTransparency = 0.5
            ColorPickerFrame.BorderSizePixel = 0
            ColorPickerFrame.Parent = TabFrame
            
            if settings.RoundedCorners then
                local ColorPickerCorner = Instance.new("UICorner")
                ColorPickerCorner.CornerRadius = UDim.new(0, 4)
                ColorPickerCorner.Parent = ColorPickerFrame
            end
            
            local ColorPickerLabel = Instance.new("TextLabel")
            ColorPickerLabel.Name = "Label"
            ColorPickerLabel.Size = UDim2.new(1, -50, 1, 0)
            ColorPickerLabel.BackgroundTransparency = 1
            ColorPickerLabel.Text = text
            ColorPickerLabel.TextColor3 = settings.TextColor
            ColorPickerLabel.Font = settings.Font
            ColorPickerLabel.TextSize = 14
            ColorPickerLabel.TextXAlignment = Enum.TextXAlignment.Left
            ColorPickerLabel.Parent = ColorPickerFrame
            
            local ColorPickerPadding = Instance.new("UIPadding")
            ColorPickerPadding.PaddingLeft = UDim.new(0, 10)
            ColorPickerPadding.Parent = ColorPickerLabel
            
            local ColorDisplay = Instance.new("Frame")
            ColorDisplay.Name = "ColorDisplay"
            ColorDisplay.Size = UDim2.new(0, 30, 0, 20)
            ColorDisplay.Position = UDim2.new(1, -40, 0.5, -10)
            ColorDisplay.BackgroundColor3 = default or Color3.fromRGB(255, 255, 255)
            ColorDisplay.BorderSizePixel = 0
            ColorDisplay.Parent = ColorPickerFrame
            
            if settings.RoundedCorners then
                local ColorDisplayCorner = Instance.new("UICorner")
                ColorDisplayCorner.CornerRadius = UDim.new(0, 4)
                ColorDisplayCorner.Parent = ColorDisplay
            end
            
            -- Advanced color picker with HSV
            local ColorPickerMenu = Instance.new("Frame")
            ColorPickerMenu.Name = "ColorPickerMenu"
            ColorPickerMenu.Size = UDim2.new(0, 200, 0, 220)
            ColorPickerMenu.Position = UDim2.new(1, -200, 1, 10)
            ColorPickerMenu.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            ColorPickerMenu.BorderSizePixel = 0
            ColorPickerMenu.Visible = false
            ColorPickerMenu.ZIndex = 10
            ColorPickerMenu.Parent = ColorPickerFrame
            
            if settings.RoundedCorners then
                local ColorPickerMenuCorner = Instance.new("UICorner")
                ColorPickerMenuCorner.CornerRadius = UDim.new(0, 4)
                ColorPickerMenuCorner.Parent = ColorPickerMenu
            end
            
            -- Color palette
            local ColorPalette = Instance.new("ImageLabel")
            ColorPalette.Name = "ColorPalette"
            ColorPalette.Size = UDim2.new(0, 180, 0, 180)
            ColorPalette.Position = UDim2.new(0, 10, 0, 10)
            ColorPalette.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            ColorPalette.BorderSizePixel = 0
            ColorPalette.Image = "rbxassetid://3157191308"
            ColorPalette.ZIndex = 10
            ColorPalette.Parent = ColorPickerMenu
            
            if settings.RoundedCorners then
                local ColorPaletteCorner = Instance.new("UICorner")
                ColorPaletteCorner.CornerRadius = UDim.new(0, 4)
                ColorPaletteCorner.Parent = ColorPalette
            end
            
            -- Color selector
            local ColorSelector = Instance.new("Frame")
            ColorSelector.Name = "ColorSelector"
            ColorSelector.Size = UDim2.new(0, 10, 0, 10)
            ColorSelector.Position = UDim2.new(0, 0, 0, 0)
            ColorSelector.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            ColorSelector.BorderSizePixel = 0
            ColorSelector.ZIndex = 11
            ColorSelector.Parent = ColorPalette
            
            if settings.RoundedCorners then
                local ColorSelectorCorner = Instance.new("UICorner")
                ColorSelectorCorner.CornerRadius = UDim.new(1, 0)
                ColorSelectorCorner.Parent = ColorSelector
            end
            
            -- Hue slider
            local HueSlider = Instance.new("Frame")
            HueSlider.Name = "HueSlider"
            HueSlider.Size = UDim2.new(0, 180, 0, 20)
            HueSlider.Position = UDim2.new(0, 10, 0, 195)
            HueSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            HueSlider.BorderSizePixel = 0
            HueSlider.ZIndex = 10
            HueSlider.Parent = ColorPickerMenu
            
            if settings.RoundedCorners then
                local HueSliderCorner = Instance.new("UICorner")
                HueSliderCorner.CornerRadius = UDim.new(0, 4)
                HueSliderCorner.Parent = HueSlider
            end
            
            -- Hue gradient
            local HueGradient = Instance.new("UIGradient")
            HueGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
            })
            HueGradient.Parent = HueSlider
            
            -- Hue selector
            local HueSelector = Instance.new("Frame")
            HueSelector.Name = "HueSelector"
            HueSelector.Size = UDim2.new(0, 5, 1, 0)
            HueSelector.Position = UDim2.new(0, 0, 0, 0)
            HueSelector.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            HueSelector.BorderSizePixel = 0
            HueSelector.ZIndex = 11
            HueSelector.Parent = HueSlider
            
            local menuOpen = false
            local selectedColor = default or Color3.fromRGB(255, 255, 255)
            local hue, saturation, value = 0, 0, 1
            
            local function updateColor()
                local hsv = Color3.fromHSV(hue, saturation, value)
                ColorDisplay.BackgroundColor3 = hsv
                ColorPalette.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
                selectedColor = hsv
                callback(selectedColor)
            end
            
            local function toggleMenu()
                menuOpen = not menuOpen
                ColorPickerMenu.Visible = menuOpen
            end
            
            ColorDisplay.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    toggleMenu()
                end
            end)
            
            -- Color palette interaction
            local draggingPalette = false
            
            ColorPalette.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingPalette = true
                    local x = math.clamp((input.Position.X - ColorPalette.AbsolutePosition.X) / ColorPalette.AbsoluteSize.X, 0, 1)
                    local y = math.clamp((input.Position.Y - ColorPalette.AbsolutePosition.Y) / ColorPalette.AbsoluteSize.Y, 0, 1)
                    saturation = x
                    value = 1 - y
                    ColorSelector.Position = UDim2.new(x, -5, y, -5)
                    updateColor()
                end
            end)
            
            ColorPalette.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingPalette = false
                end
            end)
            
            -- Hue slider interaction
            local draggingHue = false
            
            HueSlider.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingHue = true
                    local x = math.clamp((input.Position.X - HueSlider.AbsolutePosition.X) / HueSlider.AbsoluteSize.X, 0, 1)
                    hue = x
                    HueSelector.Position = UDim2.new(x, -2, 0, 0)
                    updateColor()
                end
            end)
            
            HueSlider.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingHue = false
                end
            end)
            
            UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    if draggingPalette then
                        local x = math.clamp((input.Position.X - ColorPalette.AbsolutePosition.X) / ColorPalette.AbsoluteSize.X, 0, 1)
                        local y = math.clamp((input.Position.Y - ColorPalette.AbsolutePosition.Y) / ColorPalette.AbsoluteSize.Y, 0, 1)
                        saturation = x
                        value = 1 - y
                        ColorSelector.Position = UDim2.new(x, -5, y, -5)
                        updateColor()
                    elseif draggingHue then
                        local x = math.clamp((input.Position.X - HueSlider.AbsolutePosition.X) / HueSlider.AbsoluteSize.X, 0, 1)
                        hue = x
                        HueSelector.Position = UDim2.new(x, -2, 0, 0)
                        updateColor()
                    end
                end
            end)
            
            local colorPicker = {}
            
            function colorPicker:Set(color)
                selectedColor = color
                ColorDisplay.BackgroundColor3 = selectedColor
                callback(selectedColor)
            end
            
            return colorPicker
        end
        
        function tab:AddTextbox(text, placeholder, default, callback)
            local TextboxFrame = Instance.new("Frame")
            TextboxFrame.Name = text.."Textbox"
            TextboxFrame.Size = UDim2.new(1, -20, 0, 30)
            TextboxFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            TextboxFrame.BackgroundTransparency = 0.5
            TextboxFrame.BorderSizePixel = 0
            TextboxFrame.Parent = TabFrame
            
            if settings.RoundedCorners then
                local TextboxCorner = Instance.new("UICorner")
                TextboxCorner.CornerRadius = UDim.new(0, 4)
                TextboxCorner.Parent = TextboxFrame
            end

            local TextboxLabel = Instance.new("TextLabel")
            TextboxLabel.Name = "Label"
            TextboxLabel.Size = UDim2.new(0.4, 0, 1, 0)
            TextboxLabel.BackgroundTransparency = 1
            TextboxLabel.Text = text
            TextboxLabel.TextColor3 = settings.TextColor
            TextboxLabel.Font = settings.Font
            TextboxLabel.TextSize = 14
            TextboxLabel.TextXAlignment = Enum.TextXAlignment.Left
            TextboxLabel.Parent = TextboxFrame
            
            local TextboxPadding = Instance.new("UIPadding")
            TextboxPadding.PaddingLeft = UDim.new(0, 10)
            TextboxPadding.Parent = TextboxLabel
            
            local Textbox = Instance.new("TextBox")
            Textbox.Name = "Input"
            Textbox.Size = UDim2.new(0.6, -10, 1, -6)
            Textbox.Position = UDim2.new(0.4, 5, 0, 3)
            Textbox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            Textbox.BorderSizePixel = 0
            Textbox.Text = default or ""
            Textbox.PlaceholderText = placeholder or ""
            Textbox.TextColor3 = settings.TextColor
            Textbox.PlaceholderColor3 = Color3.fromRGB(180, 180, 180)
            Textbox.Font = settings.Font
            Textbox.TextSize = 14
            Textbox.Parent = TextboxFrame
            
            if settings.RoundedCorners then
                local TextboxInputCorner = Instance.new("UICorner")
                TextboxInputCorner.CornerRadius = UDim.new(0, 4)
                TextboxInputCorner.Parent = Textbox
            end
            
            Textbox.FocusLost:Connect(function(enterPressed)
                callback(Textbox.Text)
            end)
            
            local textbox = {}
            
            function textbox:Set(value)
                Textbox.Text = value
                callback(value)
            end
            
            return textbox
        end
        
        function tab:AddLabel(text)
            local Label = Instance.new("TextLabel")
            Label.Name = "Label"
            Label.Size = UDim2.new(1, -20, 0, 30)
            Label.BackgroundTransparency = 1
            Label.Text = text
            Label.TextColor3 = settings.TextColor
            Label.Font = settings.Font
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = TabFrame
            
            local LabelPadding = Instance.new("UIPadding")
            LabelPadding.PaddingLeft = UDim.new(0, 10)
            LabelPadding.Parent = Label
            
            local label = {}
            
            function label:Set(newText)
                Label.Text = newText
            end
            
            return label
        end
        
        function tab:AddDivider()
            local Divider = Instance.new("Frame")
            Divider.Name = "Divider"
            Divider.Size = UDim2.new(1, -20, 0, 1)
            Divider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            Divider.BorderSizePixel = 0
            Divider.Parent = TabFrame
            
            return Divider
        end
        
        -- Add tooltip functionality
        function tab:AddTooltip(element, text)
            local Tooltip = Instance.new("Frame")
            Tooltip.Name = "Tooltip"
            Tooltip.Size = UDim2.new(0, 200, 0, 30)
            Tooltip.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            Tooltip.BackgroundTransparency = 0.1
            Tooltip.BorderSizePixel = 0
            Tooltip.Visible = false
            Tooltip.ZIndex = 100
            Tooltip.Parent = MafuyoGui
            
            if settings.RoundedCorners then
                local TooltipCorner = Instance.new("UICorner")
                TooltipCorner.CornerRadius = UDim.new(0, 4)
                TooltipCorner.Parent = Tooltip
            end
            
            local TooltipText = Instance.new("TextLabel")
            TooltipText.Name = "Text"
            TooltipText.Size = UDim2.new(1, -10, 1, 0)
            TooltipText.Position = UDim2.new(0, 5, 0, 0)
            TooltipText.BackgroundTransparency = 1
            TooltipText.Text = text
            TooltipText.TextColor3 = settings.TextColor
            TooltipText.Font = settings.Font
            TooltipText.TextSize = 14
            TooltipText.TextWrapped = true
            TooltipText.ZIndex = 100
            TooltipText.Parent = Tooltip
            
            element.MouseEnter:Connect(function()
                Tooltip.Position = UDim2.new(0, Mouse.X + 15, 0, Mouse.Y + 15)
                Tooltip.Visible = true
            end)
            
            element.MouseLeave:Connect(function()
                Tooltip.Visible = false
            end)
            
            UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement and Tooltip.Visible then
                    Tooltip.Position = UDim2.new(0, Mouse.X + 15, 0, Mouse.Y + 15)
                end
            end)
        end
        
        -- Add key bind functionality
        function tab:AddKeybind(text, default, callback)
            local KeybindFrame = Instance.new("Frame")
            KeybindFrame.Name = text.."Keybind"
            KeybindFrame.Size = UDim2.new(1, -20, 0, 30)
            KeybindFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            KeybindFrame.BackgroundTransparency = 0.5
            KeybindFrame.BorderSizePixel = 0
            KeybindFrame.Parent = TabFrame
            
            if settings.RoundedCorners then
                local KeybindCorner = Instance.new("UICorner")
                KeybindCorner.CornerRadius = UDim.new(0, 4)
                KeybindCorner.Parent = KeybindFrame
            end
            
            local KeybindLabel = Instance.new("TextLabel")
            KeybindLabel.Name = "Label"
            KeybindLabel.Size = UDim2.new(1, -80, 1, 0)
            KeybindLabel.BackgroundTransparency = 1
            KeybindLabel.Text = text
            KeybindLabel.TextColor3 = settings.TextColor
            KeybindLabel.Font = settings.Font
            KeybindLabel.TextSize = 14
            KeybindLabel.TextXAlignment = Enum.TextXAlignment.Left
            KeybindLabel.Parent = KeybindFrame
            
            local KeybindPadding = Instance.new("UIPadding")
            KeybindPadding.PaddingLeft = UDim.new(0, 10)
            KeybindPadding.Parent = KeybindLabel
            
            local KeybindButton = Instance.new("TextButton")
            KeybindButton.Name = "Button"
            KeybindButton.Size = UDim2.new(0, 70, 0, 24)
            KeybindButton.Position = UDim2.new(1, -75, 0.5, -12)
            KeybindButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            KeybindButton.BorderSizePixel = 0
            KeybindButton.Text = default and default.Name or "None"
            KeybindButton.TextColor3 = settings.TextColor
            KeybindButton.Font = settings.Font
            KeybindButton.TextSize = 14
            KeybindButton.Parent = KeybindFrame
            
            if settings.RoundedCorners then
                local KeybindButtonCorner = Instance.new("UICorner")
                KeybindButtonCorner.CornerRadius = UDim.new(0, 4)
                KeybindButtonCorner.Parent = KeybindButton
            end
            
            local currentKey = default
            local waitingForInput = false
            
            KeybindButton.MouseButton1Click:Connect(function()
                waitingForInput = true
                KeybindButton.Text = "..."
            end)
            
            UserInputService.InputBegan:Connect(function(input)
                if waitingForInput and input.UserInputType == Enum.UserInputType.Keyboard then
                    waitingForInput = false
                    currentKey = input.KeyCode
                    KeybindButton.Text = currentKey.Name
                    callback(currentKey)
                elseif not waitingForInput and currentKey and input.KeyCode == currentKey then
                    callback(currentKey)
                end
            end)
            
            local keybind = {}
            
            function keybind:Set(key)
                currentKey = key
                KeybindButton.Text = key and key.Name or "None"
                callback(key)
            end
            
            return keybind
        end
        
        return tab
    end
    
    -- Key system functions
    function library:SetKey(key)
        if keySystem.Enabled then
            local success, message = self:VerifyKey(key)
            return success, message
        end
        return true, "Key system disabled"
    end
    
    function library:AddKeyToWhitelist(key, keyData)
        if keySystem.Enabled then
            keySystem.Keys[key] = keyData
            return true
        end
        return false
    end
    
    function library:AddUserToWhitelist(username)
        if keySystem.Enabled and keySystem.Whitelist.Enabled then
            table.insert(keySystem.Whitelist.Users, username)
            return true
        end
        return false
    end
    
    function library:SetDiscordWebhook(webhook)
        keySystem.DiscordWebhook = webhook
        return true
    end
    
    -- Parent the ScreenGui
    MafuyoGui.Parent = Player.PlayerGui
    
    -- Clean up when destroyed
    MafuyoGui.Destroying:Connect(function()
        local lighting = game:GetService("Lighting")
        local blur = lighting:FindFirstChild("MafuyoBlur")
        if blur then
            blur:Destroy()
        end
    end)
    
    return library
end

-- Set custom settings
function MafuyoLibrary:SetSettings(newSettings)
    for key, value in pairs(newSettings) do
        settings[key] = value
    end
end

-- Key verification system
function MafuyoLibrary:CreateKeySystem(title, description, keys, webhook)
    local KeySystemGui = Instance.new("ScreenGui")
    KeySystemGui.Name = "MafuyoKeySystem"
    KeySystemGui.ResetOnSpawn = false
    KeySystemGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local KeyFrame = Instance.new("Frame")
    KeyFrame.Name = "KeyFrame"
    KeyFrame.Size = UDim2.new(0, 300, 0, 200)
    KeyFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
    KeyFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    KeyFrame.BorderSizePixel = 0
    KeyFrame.Parent = KeySystemGui
    
    local KeyCorner = Instance.new("UICorner")
    KeyCorner.CornerRadius = UDim.new(0, 6)
    KeyCorner.Parent = KeyFrame
    
    local KeyTitle = Instance.new("TextLabel")
    KeyTitle.Name = "Title"
    KeyTitle.Size = UDim2.new(1, 0, 0, 30)
    KeyTitle.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
    KeyTitle.BorderSizePixel = 0
    KeyTitle.Text = title or "Key Verification"
    KeyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyTitle.Font = Enum.Font.GothamBold
    KeyTitle.TextSize = 16
    KeyTitle.Parent = KeyFrame
    
    local KeyTitleCorner = Instance.new("UICorner")
    KeyTitleCorner.CornerRadius = UDim.new(0, 6)
    KeyTitleCorner.Parent = KeyTitle
    
    local KeyTitleFix = Instance.new("Frame")
    KeyTitleFix.Size = UDim2.new(1, 0, 0.5, 0)
    KeyTitleFix.Position = UDim2.new(0, 0, 0.5, 0)
    KeyTitleFix.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
    KeyTitleFix.BorderSizePixel = 0
    KeyTitleFix.Parent = KeyTitle
    
    local KeyDescription = Instance.new("TextLabel")
    KeyDescription.Name = "Description"
    KeyDescription.Size = UDim2.new(1, -20, 0, 40)
    KeyDescription.Position = UDim2.new(0, 10, 0, 40)
    KeyDescription.BackgroundTransparency = 1
    KeyDescription.Text = description or "Please enter your key to continue."
    KeyDescription.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyDescription.Font = Enum.Font.Gotham
    KeyDescription.TextSize = 14
    KeyDescription.TextWrapped = true
    KeyDescription.Parent = KeyFrame
    
    local KeyInput = Instance.new("TextBox")
    KeyInput.Name = "Input"
    KeyInput.Size = UDim2.new(1, -20, 0, 30)
    KeyInput.Position = UDim2.new(0, 10, 0, 90)
    KeyInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    KeyInput.BorderSizePixel = 0
    KeyInput.Text = ""
    KeyInput.PlaceholderText = "Enter key here..."
    KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyInput.Font = Enum.Font.Gotham
    KeyInput.TextSize = 14
    KeyInput.Parent = KeyFrame
    
    local KeyInputCorner = Instance.new("UICorner")
    KeyInputCorner.CornerRadius = UDim.new(0, 4)
    KeyInputCorner.Parent = KeyInput
    
    local VerifyButton = Instance.new("TextButton")
    VerifyButton.Name = "Verify"
    VerifyButton.Size = UDim2.new(1, -20, 0, 30)
    VerifyButton.Position = UDim2.new(0, 10, 0, 130)
    VerifyButton.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
    VerifyButton.BorderSizePixel = 0
    VerifyButton.Text = "Verify Key"
    VerifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    VerifyButton.Font = Enum.Font.GothamBold
    VerifyButton.TextSize = 14
    VerifyButton.Parent = KeyFrame
    
    local VerifyButtonCorner = Instance.new("UICorner")
    VerifyButtonCorner.CornerRadius = UDim.new(0, 4)
    VerifyButtonCorner.Parent = VerifyButton
    
    local GetKeyButton = Instance.new("TextButton")
    GetKeyButton.Name = "GetKey"
    GetKeyButton.Size = UDim2.new(1, -20, 0, 20)
    GetKeyButton.Position = UDim2.new(0, 10, 0, 170)
    GetKeyButton.BackgroundTransparency = 1
    GetKeyButton.Text = "Get Key"
    GetKeyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    GetKeyButton.Font = Enum.Font.Gotham
    GetKeyButton.TextSize = 12
    GetKeyButton.Parent = KeyFrame
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "Status"
    StatusLabel.Size = UDim2.new(1, -20, 0, 20)
    StatusLabel.Position = UDim2.new(0, 10, 0, 200)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = ""
    StatusLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextSize = 12
    StatusLabel.Parent = KeyFrame
    
    -- Set up key system
    if keys then
        for key, data in pairs(keys) do
            keySystem.Keys[key] = data
        end
    end
    
    if webhook then
        keySystem.DiscordWebhook = webhook
    end
    
    -- Verify button functionality
    local verifySuccess = false
    local verifiedKey = ""
    
    VerifyButton.MouseButton1Click:Connect(function()
        local key = KeyInput.Text
        local success, message = MafuyoLibrary:VerifyKey(key)
        
        if success then
            StatusLabel.Text = "Key verified successfully!"
            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            verifySuccess = true
            verifiedKey = key
            
            -- Animate success
            TweenService:Create(KeyFrame, TweenInfo.new(0.5), {BackgroundColor3 = Color3.fromRGB(40, 100, 40)}):Play()
            wait(1)
            KeySystemGui:Destroy()
        else
            StatusLabel.Text = "Invalid key: " .. message
            StatusLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
            
            -- Shake animation for error
            local originalPosition = KeyFrame.Position
            for i = 1, 5 do
                KeyFrame.Position = originalPosition + UDim2.new(0, math.random(-5, 5), 0, math.random(-5, 5))
                wait(0.05)
            end
            KeyFrame.Position = originalPosition
        end
    end)
    
    -- Get key button functionality
    GetKeyButton.MouseButton1Click:Connect(function()
        -- This would typically open a link to get a key
        -- For this example, we'll just show a message
        StatusLabel.Text = "Visit our Discord to get a key!"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 150, 255)
    end)
    
    KeySystemGui.Parent = Player.PlayerGui
    
    -- Wait for verification
    while KeySystemGui.Parent do
        wait(0.1)
    end
    
    return verifySuccess, verifiedKey
end

return MafuyoLibrary
