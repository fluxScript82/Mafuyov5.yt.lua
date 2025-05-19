-- Load the Mafuyo UI Library
local Mafuyo = loadstring(game:HttpGet("https://raw.githubusercontent.com/fluxScript82/Mafuyov5.yt.lua/refs/heads/main/Mafuyov5%20source.lua"))()

-- Create a key system (optional)
local success, key = MafuyoLibrary:CreateKeySystem(
    "Mafuyo Premium", 
    "Please enter your key to access premium features",
    {
        ["PREMIUM-KEY-123"] = {
            Type = "Premium",
            ExpiryDate = "Never",
            HWID_Locked = true,
            AllowedHWIDs = {},
            Owner = "Premium User"
        }
    },
    "https://discord.com/api/webhooks/your-webhook-url"
)

if success then
    -- Create the UI with the verified key
    local UI = MafuyoLibrary:Create("My Mafuyo UI", "rbxassetid://YOUR_LOGO_ID", key)
    
    -- Create tabs with icons
    local mainTab = UI:CreateTab("Main", "rbxassetid://3926305904")
    local settingsTab = UI:CreateTab("Settings", "rbxassetid://3926307971")
    
    -- Add notification
    UI:Notify("Welcome", "Thanks for using Mafuyo UI Library!", "Success", 5)
    
    -- Add elements to tabs
    local button = mainTab:AddButton("Click Me", function()
        UI:Notify("Button Clicked", "You clicked the button!", "Info", 3)
    end)
    
    -- Add tooltip to button
    mainTab:AddTooltip(button, "This is a sample button that shows a notification when clicked")
    
    -- Add toggle with tooltip
    local toggle = mainTab:AddToggle("Toggle Feature", false, function(value)
        print("Toggle:", value)
    end)
    
    -- Add keybind
    mainTab:AddKeybind("Toggle UI", Enum.KeyCode.RightControl, function(key)
        print("UI toggled with key:", key.Name)
    end)
    
    -- Add slider
    settingsTab:AddSlider("Speed", 0, 100, 50, function(value)
        print("Speed:", value)
    end)
    
    -- Add color picker
    settingsTab:AddColorPicker("UI Color", Color3.fromRGB(255, 75, 75), function(color)
        print("Color selected:", color)
    end)
end
