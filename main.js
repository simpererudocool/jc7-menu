-- // jc7 - FF2 menu wiring \\
-- Paste this where the Ocean block was. Every callback assigns the same locals
-- the feature code above already reads, so nothing else has to change.
-- The library is pulled from LIBRARY_URL, so edits pushed to the repo go live on reload.

---@module Main

-- Luraph globals with development fallbacks.
if not getfenv().LPH_NO_VIRTUALIZE then
	getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end
	getfenv().PP_SCRAMBLE_NUM = function(...) return ... end
	getfenv().PP_SCRAMBLE_STR = function(...) return ... end
end

-- Canonical library source; the menu always runs whatever is on main.
local LIBRARY_URL = "https://raw.githubusercontent.com/simpererudocool/jc7-menu/refs/heads/main/jc7.lua"

---Fetch and install the library when it is not already resident.
local function loadLibrary()
	if getgenv().jc7 then
		return
	end

	local fetched, source = pcall(function()
		return game:HttpGet(LIBRARY_URL)
	end)
	if not fetched or type(source) ~= "string" or #source < 256 then
		error("jc7 library fetch failed: " .. tostring(source), 0)
	end

	local compiled, factory = pcall(function()
		return loadstring(source, "@jc7/library")
	end)
	if not compiled or type(factory) ~= "function" then
		error("jc7 library did not compile: " .. tostring(factory), 0)
	end

	factory()

	if not getgenv().jc7 then
		error("jc7 library loaded but did not register getgenv().jc7", 0)
	end
end

-- Profiler handoff: use Lycoris' instance when it is present.
local profiler = shared.Profiler
if type(profiler) ~= "table" or type(profiler.run) ~= "function" then
	profiler = { run = function(_, callback) return callback() end }
end

---@param error string
local function onInitializeError(error)
	warn("jc7 failed to initialize.")
	warn(error)
	warn(debug.traceback())
	if getgenv().jc7Menu then
		pcall(function()
			getgenv().jc7Menu:Destroy()
		end)
	end
end

---Build the window, the tabs and every control.
local function initializeScript()
	loadLibrary()
	local JC7 = getgenv().jc7

	-- Loaded from a URL there is no FF2 chunk above this one, so every binding it
	-- expects has to degrade instead of throwing. Inline, these pick up the real values.
	local Data = Data or {}
	local onToggle = type(onToggle) == "function" and onToggle or function() end
	local onToggle2 = type(onToggle2) == "function" and onToggle2 or function() end

	---Fire the catch input. Touch has no mouse button, which is why the mobile button exists.
	---If the game exposes its own catch function, put it first in this chain.
	local function catchBall()
		if type(CatchBall) == "function" then
			return CatchBall()
		end
		if type(mouse1click) == "function" then
			return mouse1click()
		end
		pcall(function()
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
			game:GetService("VirtualUser"):ClickButton1(viewport * 0.5)
		end)
	end

	local window = JC7.new({
		Title = "jc7",
		Subtitle = "ff2 - place " .. tostring(game.PlaceId),
		Accent = Color3.fromRGB(87, 123, 255),
		-- The Player tab owns the menu keybind, so the library's own is off.
		Keybind = false,
	})

	local qb = window:Tab("QB", 10723426986)
	local qbConfigs = window:Tab("QB Configs", 10723426986)
	local catching = window:Tab("Catching", 10723426986)
	local automatics = window:Tab("Automatics", 10723426986)
	local kicker = window:Tab("Kicker", 10723426986)
	local visuals = window:Tab("Visuals", 10723426986)
	local player = window:Tab("Player", 10723424505)

	-- QB.
	qb:Section("Targeting")
	qb:Toggle{
		Text = "QB Aimbot",
		Description = "Solves the throw and fires on click",
		Default = state,
		Callback = function(value)
			state = value
		end,
	}
	qb:Toggle{
		Text = "Auto Select WR",
		Description = "Most isolated receiver inside the radius",
		Default = autoswr,
		Callback = function(value)
			autoswr = value
		end,
	}
	qb:Slider{
		Text = "Auto WR Radius",
		Min = 5,
		Max = 60,
		Default = dradius,
		Callback = function(value)
			dradius = value
		end,
	}

	qb:Section("Solver")
	qb:Toggle{
		Text = "Auto Angle",
		Default = AutoAngie,
		Callback = function(value)
			AutoAngie = value
		end,
	}
	qb:Toggle{
		Text = "Auto Power",
		Default = AutoPowa,
		Callback = function(value)
			AutoPowa = value
		end,
	}
	qb:Toggle{
		Text = "High Power Mode",
		Default = Highestpwrmode,
		Callback = function(value)
			Highestpwrmode = value
		end,
	}
	qb:Toggle{
		Text = "Auto Mode Selection",
		Default = autopmode,
		Callback = function(value)
			autopmode = value
		end,
	}
	qb:Paragraph{
		Text = "R / F angle   |   Z / X power   |   C throw mode   |   Q lock target",
	}

	-- QB Configs.
	qbConfigs:Section("Trajectory")
	qbConfigs:Toggle{
		Text = "Full Beam Length",
		Default = customBeam,
		Callback = function(value)
			customBeam = value
		end,
	}
	qbConfigs:Toggle{
		Text = "Remove Beam End Part",
		Default = endPartOfBeam,
		Callback = function(value)
			endPartOfBeam = value
		end,
	}
	qbConfigs:Toggle{
		Text = "Custom Lead",
		Description = "Overrides the per-mode lead coefficients",
		Default = customLeads,
		Callback = function(value)
			customLeads = value
		end,
	}
	qbConfigs:Slider{
		Text = "Lead Distance",
		Min = 15,
		Max = 20,
		Decimals = 1,
		Default = customLead,
		Callback = function(value)
			customLead = value
		end,
	}

	qbConfigs:Section("Manual Values")
	qbConfigs:Slider{
		Text = "Power",
		Min = 40,
		Max = 95,
		Default = Data.NormalPower,
		Callback = function(value)
			Data.NormalPower = value
		end,
	}
	qbConfigs:Slider{
		Text = "Angle",
		Min = 10,
		Max = 55,
		Default = Data.Angle,
		Callback = function(value)
			Data.Angle = value
		end,
	}
	qbConfigs:Slider{
		Text = "Bullet Angle",
		Min = 5,
		Max = 20,
		Default = Data.BulletModeAngle,
		Callback = function(value)
			Data.BulletModeAngle = value
		end,
	}
	qbConfigs:Slider{
		Text = "Fade Angle",
		Min = 55,
		Max = 75,
		Default = Data.FadeModeAngle,
		Callback = function(value)
			Data.FadeModeAngle = value
		end,
	}

	-- Catching.
	catching:Section("Magnets")
	catching:Dropdown{
		Text = "Version",
		Default = "Magnets V1",
		Options = { "Magnets V1", "Magnets V2" },
		Callback = function(value)
			msVersion = value
		end,
	}
	catching:Toggle{
		Text = "Magnets",
		Default = on,
		Callback = function(value)
			on = value
			window:Notify({
				Title = "Magnets",
				Text = value and ("Enabled - " .. tostring(magType)) or "Disabled",
			})
		end,
	}
	catching:Dropdown{
		Text = "Profile",
		Default = "Regular",
		Options = { "Legit", "Regular", "Blatant", "Leauge" },
		Callback = function(value)
			magType = value
		end,
	}
	catching:Slider{
		Text = "Legit Range",
		Min = 5,
		Max = 10,
		Default = legmagdist,
		Callback = function(value)
			legmagdist = value
		end,
	}
	catching:Slider{
		Text = "Regular Range",
		Min = 15,
		Max = 25,
		Default = regdist,
		Callback = function(value)
			regdist = value
		end,
	}
	catching:Slider{
		Text = "Blatant Range",
		Min = 20,
		Max = 30,
		Default = bldist,
		Callback = function(value)
			bldist = value
		end,
	}
	catching:Slider{
		Text = "League Range",
		Min = 0,
		Max = 5,
		Default = leaugdist,
		Callback = function(value)
			leaugdist = value
		end,
	}
	catching:Slider{
		Text = "V2 Hitbox Size",
		Min = 0,
		Max = 30,
		Default = msSecondVerRange,
		Callback = function(value)
			msSecondVerRange = value
		end,
	}

	catching:Section("Pull Vector")
	catching:Toggle{
		Text = "Pull Vector",
		Default = pvon,
		Callback = function(value)
			pvon = value
		end,
	}
	catching:Slider{
		Text = "Pull Strength",
		Min = 1,
		Max = 30,
		Default = pvstrength,
		Callback = function(value)
			pvstrength = value
		end,
	}
	catching:Slider{
		Text = "Pull Distance",
		Min = 1,
		Max = 30,
		Default = pvdist,
		Callback = function(value)
			pvdist = value
		end,
	}

	catching:Section("Touch")
	catching:Paragraph{
		Text = "Auto Catch taps for you. Use the floating CATCH button for a manual grab.",
	}
	local catchButton = window:ActionButton({
		Text = "CATCH",
		Callback = catchBall,
	})
	if not catchButton then
		catching:Button{
			Text = "Catch Ball",
			Callback = catchBall,
		}
	end

	-- Automatics.
	automatics:Section("Ball")
	automatics:Toggle{
		Text = "Auto Catch",
		Default = autoCatchOn,
		Callback = function(value)
			autoCatchOn = value
		end,
	}
	automatics:Slider{
		Text = "Catch Distance",
		Min = 10,
		Max = 20,
		Default = _G.dist or 17,
		Callback = function(value)
			_G.dist = value
		end,
	}
	automatics:Toggle{
		Text = "Auto Jump",
		Default = autoJumpOn,
		Callback = function(value)
			autoJumpOn = value
		end,
	}
	automatics:Slider{
		Text = "Jump Distance",
		Min = 10,
		Max = 20,
		Default = disttt or 17,
		Callback = function(value)
			disttt = value
		end,
	}
	automatics:Toggle{
		Text = "Auto Swat",
		Default = autoSwatOn,
		Callback = function(value)
			autoSwatOn = value
		end,
	}
	automatics:Slider{
		Text = "Swat Distance",
		Min = 10,
		Max = 20,
		Default = distttt or 17,
		Callback = function(value)
			distttt = value
		end,
	}

	automatics:Section("Off Ball")
	automatics:Toggle{
		Text = "Auto Rush",
		Description = "Shadows the ball carrier",
		Default = aRushOn,
		Callback = function(value)
			aRushOn = value
		end,
	}
	automatics:Slider{
		Text = "Rush Distance",
		Min = 0,
		Max = 30,
		Default = agDist,
		Callback = function(value)
			agDist = value
		end,
	}
	automatics:Toggle{
		Text = "Auto Captain",
		Default = autoCapOn,
		Callback = function(value)
			autoCapOn = value
		end,
	}

	-- Kicker.
	kicker:Section("Kicking")
	kicker:Toggle{
		Text = "Perfect Kicker Aimbot",
		Description = "Two-stop cursor timing on the KickerGui",
		Default = kickOn,
		Callback = function(value)
			kickOn = value
			window:Notify({
				Title = "Kicker",
				Text = value and "Perfect timing armed" or "Disarmed",
			})
		end,
	}

	-- Visuals.
	visuals:Section("Debug")
	visuals:Toggle{
		Text = "Magnet Hitbox Visualizer",
		Default = on3,
		Callback = function(value)
			on3 = value
		end,
	}
	visuals:Toggle{
		Text = "Ball Trajectory Beam",
		Default = BeOn,
		Callback = function(value)
			BeOn = value
		end,
	}

	-- Player.
	player:Section("Movement")
	player:Toggle{
		Text = "Jump Power",
		Default = false,
		Callback = function(value)
			onToggle(value)
		end,
	}
	player:Slider{
		Text = "Jump Power Strength",
		Min = 50,
		Max = 70,
		Default = jps,
		Callback = function(value)
			jps = value
		end,
	}
	player:Toggle{
		Text = "Angle Enhancer",
		Description = "Do not stack with Jump Power",
		Default = false,
		Callback = function(value)
			onToggle2(value)
		end,
	}
	player:Toggle{
		Text = "Speed Boost",
		Description = "F steps along the look vector",
		Default = LookVectorSpeed,
		Callback = function(value)
			LookVectorSpeed = value
		end,
	}
	player:Slider{
		Text = "Speed Boost Strength",
		Min = 0,
		Max = 5,
		Default = Speedboostnum,
		Callback = function(value)
			Speedboostnum = value
		end,
	}

	player:Section("Defence")
	player:Toggle{
		Text = "Anti Jam",
		Default = antiJamOn,
		Callback = function(value)
			antiJamOn = value
		end,
	}
	player:Toggle{
		Text = "Anti Block",
		Default = antiBlockOn,
		Callback = function(value)
			antiBlockOn = value
		end,
	}

	player:Section("Interface")
	player:Keybind{
		Text = "Menu Keybind",
		Default = Enum.KeyCode.RightShift,
		Callback = function(pressed)
			if pressed then
				window:Toggle()
			end
		end,
	}
	player:Button{
		Text = "Unload Menu",
		Callback = function()
			window:Destroy()
		end,
	}

	getgenv().jc7Menu = window

	-- One line of proof: how much got built, and which parent accepted the ScreenGui.
	print(string.format("jc7: %d tabs built under %s", #window.tabs, tostring(window.gui.Parent)))

	return window
end

-- A foreign shared.Profiler can throw here, or swallow the callback and return clean.
-- Both leave you with no window and no warning, so prove the entry point actually ran.
local entered = false

local function entry()
	entered = true
	return xpcall(initializeScript, onInitializeError)
end

local scheduled = pcall(function()
	profiler.run("jc7_InitializeScript", entry)
end)

if not scheduled or not entered then
	entry()
end
