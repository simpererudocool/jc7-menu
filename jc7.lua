-- // jc7 - menu library \\
-- Paste above the menu block, or load with loadstring(readfile("jc7/JC7.lua"))().
-- Both paths leave the module on getgenv().jc7.

---@module JC7
getgenv().jc7 = (function()
	-- Wrapped so the library's locals never touch the caller's local budget when pasted inline.

	-- Check for table that is shared between executions.
	if not shared then
		return warn("No shared, no script.")
	end

	-- Luraph globals with development fallbacks.
	if not getfenv().LPH_NO_VIRTUALIZE then
		getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end
		getfenv().PP_SCRAMBLE_NUM = function(...) return ... end
		getfenv().PP_SCRAMBLE_STR = function(...) return ... end
	end

	-- Module table.
	local JC7 = {}
	JC7.__index = JC7

	-- Services.
	local playersService = game:GetService("Players")
	local tweenService = game:GetService("TweenService")
	local userInputService = game:GetService("UserInputService")

	-- Constants.
	-- Touch means no cursor and no keyboard, so the layout grows and the geometry adapts.
	local isMobile = userInputService.TouchEnabled and not userInputService.MouseEnabled
	local VERSION = "1.1.0"
	local HEADER_HEIGHT = isMobile and 50 or 46
	local SIDEBAR_WIDTH = isMobile and 116 or 150
	local FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
	local FONT_REGULAR = Font.new(FONT_FAMILY, Enum.FontWeight.Regular)
	local FONT_MEDIUM = Font.new(FONT_FAMILY, Enum.FontWeight.Medium)
	local FONT_BOLD = Font.new(FONT_FAMILY, Enum.FontWeight.Bold)
	local COLORS = {
		Base = Color3.fromRGB(9, 10, 14),
		Sidebar = Color3.fromRGB(12, 13, 18),
		Card = Color3.fromRGB(18, 20, 27),
		CardHover = Color3.fromRGB(24, 27, 36),
		Stroke = Color3.fromRGB(34, 38, 48),
		Text = Color3.fromRGB(232, 234, 241),
		Muted = Color3.fromRGB(128, 134, 148),
		Knob = Color3.fromRGB(200, 203, 214),
	}
	local DEFAULT_ACCENT = Color3.fromRGB(87, 123, 255)
	local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local TWEEN_MEDIUM = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	-- Fingertips need roughly 44pt of travel; a mouse needs about half that.
	local METRICS = {
		Row = isMobile and 48 or 38,
		RowTall = isMobile and 62 or 52,
		RowButton = isMobile and 44 or 34,
		RowDescription = isMobile and 62 or 52,
		Tab = isMobile and 42 or 34,
		Text = isMobile and 14 or 13,
		TextSmall = isMobile and 13 or 12,
		TextTiny = isMobile and 11 or 10,
	}

	-- Utility.
	---Create an instance and apply every property in one pass.
	---@param className string
	---@param properties table
	---@return Instance
	local function create(className, properties)
		local instance = Instance.new(className)
		for key, value in pairs(properties) do
			instance[key] = value
		end
		return instance
	end

	---Play a tween and hand it back.
	---@return Tween
	local function tween(instance, info, goal)
		local animation = tweenService:Create(instance, info, goal)
		animation:Play()
		return animation
	end

	---Build a text label that carries the library's text defaults.
	---@param parent Instance
	---@param properties table
	---@return TextLabel
	local function createLabel(parent, properties)
		local config = {
			BackgroundTransparency = 1,
			FontFace = FONT_MEDIUM,
			TextColor3 = COLORS.Text,
			TextSize = METRICS.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			RichText = true,
		}
		for key, value in pairs(properties) do
			config[key] = value
		end
		config.Parent = parent
		return create("TextLabel", config)
	end

	---Resolve the first ScreenGui parent the executor will accept.
	---@return Instance
	local function resolveGuiParent()
		if gethui then
			local ok, result = pcall(gethui)
			if ok and result then
				return result
			end
		end
		local ok, playerGui = pcall(function()
			return playersService.LocalPlayer:WaitForChild("PlayerGui")
		end)
		if ok and playerGui then
			return playerGui
		end
		return game:GetService("CoreGui")
	end

	---Turn a Color3 into a RichText hex string.
	---@param color Color3
	---@return string
	local function toHex(color)
		return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end

	---Format a number at a fixed decimal count.
	---@param value number
	---@param decimals number
	---@return string
	local function formatNumber(value, decimals)
		return string.format("%." .. tostring(math.max(math.floor(decimals), 0)) .. "f", value)
	end

	---Draw a downward chevron from two rotated bars, no asset ids involved.
	---@param parent Instance
	---@param color Color3
	---@return Frame
	local function createChevron(parent, color)
		local holder = create("Frame", {
			Name = "Chevron",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		local offsets = { -2, 2 }
		local rotations = { -45, 45 }
		for index = 1, 2 do
			create("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, offsets[index], 0.5, 0),
				Size = UDim2.fromOffset(1.5, 5),
				Rotation = rotations[index],
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Parent = holder,
			})
		end
		return holder
	end

	---@module Utility.Maid
	local Maid = {}
	Maid.__index = Maid

	---Create an empty cleanup container.
	function Maid.new()
		return setmetatable({ tasks = {} }, Maid)
	end

	---Track a connection, instance or function for cleanup.
	---@param task any
	---@return any
	function Maid:Give(task)
		table.insert(self.tasks, task)
		return task
	end

	---Run every tracked cleanup exactly once.
	function Maid:Clean()
		for index = #self.tasks, 1, -1 do
			local task = self.tasks[index]
			self.tasks[index] = nil
			if typeof(task) == "RBXScriptConnection" then
				task:Disconnect()
			elseif typeof(task) == "Instance" then
				task:Destroy()
			elseif type(task) == "function" then
				task()
			end
		end
	end

	---@module Features.Menu.Objects.Tab
	local Tab = {}
	Tab.__index = Tab

	---Add a row card to this tab's canvas.
	---@param height number
	---@param className string?
	---@return Frame
	function Tab:card(height, className)
		self.elementOrder = self.elementOrder + 1
		local properties = {
			Name = "Card",
			Size = UDim2.new(1, -28, 0, height),
			BackgroundColor3 = COLORS.Card,
			BorderSizePixel = 0,
			LayoutOrder = self.elementOrder,
			ClipsDescendants = true,
			Parent = self.canvas,
		}
		if className == "ImageButton" then
			properties.AutoButtonColor = false
		end
		local card = create(className or "Frame", properties)
		create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
		create("UIStroke", { Color = COLORS.Stroke, Thickness = 1, Transparency = 0.35, Parent = card })
		return card
	end

	---Attach the standard hover treatment to an interactive card.
	---@param card Instance
	function Tab:hover(card)
		self.maid:Give(card.MouseEnter:Connect(function()
			tween(card, TWEEN_FAST, { BackgroundColor3 = COLORS.CardHover })
		end))
		self.maid:Give(card.MouseLeave:Connect(function()
			tween(card, TWEEN_FAST, { BackgroundColor3 = COLORS.Card })
		end))
	end

	---Add a toggle row.
	---@param settings table
	---@return table
	function Tab:Toggle(settings)
		local options = {
			Text = settings.Text or "Toggle",
			Description = settings.Description,
			Default = settings.Default == true,
			Callback = settings.Callback or function() end,
		}

		local card = self:card(options.Description and METRICS.RowDescription or METRICS.Row, "ImageButton")
		self:hover(card)

		local toggle = {
			Value = options.Default,
			Element = card,
		}

		createLabel(card, {
			Text = options.Text,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -72, 0, options.Description and 30 or METRICS.Row),
			TextSize = METRICS.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		if options.Description then
			createLabel(card, {
				Text = options.Description,
				Position = UDim2.fromOffset(12, 28),
				Size = UDim2.new(1, -72, 0, 16),
				TextSize = METRICS.TextTiny,
				TextColor3 = COLORS.Muted,
				FontFace = FONT_REGULAR,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end

		local rail = create("Frame", {
			Name = "Rail",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(34, 18),
			BackgroundColor3 = COLORS.Stroke,
			BorderSizePixel = 0,
			Parent = card,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rail })

		local knob = create("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = COLORS.Knob,
			BorderSizePixel = 0,
			Parent = rail,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

		local function render()
			if toggle.Value then
				tween(rail, TWEEN_FAST, { BackgroundColor3 = self.window.accent })
				tween(knob, TWEEN_FAST, { Position = UDim2.new(1, -15, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1) })
			else
				tween(rail, TWEEN_FAST, { BackgroundColor3 = COLORS.Stroke })
				tween(knob, TWEEN_FAST, { Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = COLORS.Knob })
			end
		end

		---Set the toggle; silent skips the callback.
		---@param value boolean
		---@param silent boolean?
		function toggle:Set(value, silent)
			self.Value = value == true
			render()
			if not silent then
				options.Callback(self.Value)
			end
		end

		self.maid:Give(card.MouseButton1Click:Connect(function()
			toggle:Set(not toggle.Value)
		end))

		render()
		options.Callback(toggle.Value)
		return toggle
	end

	---Add a slider row with drag, click and typed entry.
	---@param settings table
	---@return table
	function Tab:Slider(settings)
		local options = {
			Text = settings.Text or "Slider",
			Min = settings.Min or 0,
			Max = settings.Max or 100,
			Decimals = settings.Decimals or 0,
			Suffix = settings.Suffix or "",
			Callback = settings.Callback or function() end,
		}
		options.Default = settings.Default or options.Min
		local span = math.max(options.Max - options.Min, 0.000001)

		local card = self:card(METRICS.RowTall)
		local slider = { Value = options.Default }

		createLabel(card, {
			Text = options.Text,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -104, 0, 18),
			TextSize = METRICS.TextSmall,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local valueBox = create("TextBox", {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 5),
			Size = UDim2.fromOffset(72, 20),
			BackgroundTransparency = 1,
			FontFace = FONT_BOLD,
			Text = "",
			TextColor3 = self.window.accent,
			TextSize = METRICS.TextSmall,
			TextXAlignment = Enum.TextXAlignment.Right,
			ClearTextOnFocus = false,
			ZIndex = 3,
			Parent = card,
		})

		local hit = create("ImageButton", {
			Name = "Track",
			Position = UDim2.fromOffset(6, METRICS.RowTall - 28),
			Size = UDim2.new(1, -12, 0, 28),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Parent = card,
		})

		local rail = create("Frame", {
			Name = "Rail",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.new(1, -12, 0, 4),
			BackgroundColor3 = COLORS.Stroke,
			BorderSizePixel = 0,
			Parent = hit,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rail })

		local fill = create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = self.window.accent,
			BorderSizePixel = 0,
			Parent = rail,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })

		local knob = create("Frame", {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = rail,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

		local function apply(value, fireCallback)
			local numeric = tonumber(value)
			if not numeric then
				return
			end
			local step = 10 ^ -options.Decimals
			local clamped = math.floor(numeric / step + 0.5) * step
			clamped = math.clamp(clamped, options.Min, options.Max)
			slider.Value = clamped
			local percent = math.clamp((clamped - options.Min) / span, 0, 1)
			fill.Size = UDim2.fromScale(percent, 1)
			knob.Position = UDim2.new(percent, 0, 0.5, 0)
			valueBox.Text = formatNumber(clamped, options.Decimals) .. options.Suffix
			if fireCallback then
				options.Callback(clamped)
			end
		end

		---Set the slider value; silent skips the callback.
		---@param value number
		---@param silent boolean?
		function slider:Set(value, silent)
			apply(tonumber(value) or self.Value, not silent)
		end

		local dragging = false
		local function updateFromInput(input)
			local percent = math.clamp((input.Position.X - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
			apply(options.Min + span * percent, true)
		end

		self.maid:Give(hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				-- Touch drags scroll the canvas by default and would steal the slider.
				self.canvas.ScrollingEnabled = false
				updateFromInput(input)
			end
		end))

		self.maid:Give(userInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				updateFromInput(input)
			end
		end))

		self.maid:Give(userInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				self.canvas.ScrollingEnabled = true
			end
		end))

		self.maid:Give(valueBox.FocusLost:Connect(function()
			apply(tonumber(valueBox.Text) or slider.Value, true)
		end))

		apply(options.Default, true)
		return slider
	end

	---Add a dropdown row. Multi mode hands back a keyed table of booleans.
	---@param settings table
	---@return table
	function Tab:Dropdown(settings)
		local options = {
			Text = settings.Text or "Dropdown",
			Options = settings.Options or {},
			Multi = settings.Multi == true,
			Callback = settings.Callback or function() end,
		}

		local card = self:card(METRICS.Row, "ImageButton")
		self:hover(card)

		local dropdown = {
			Value = options.Multi and {} or (settings.Default or "None"),
			Element = card,
		}

		createLabel(card, {
			Text = options.Text,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -150, 1, 0),
			TextSize = METRICS.TextSmall,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local valueLabel = createLabel(card, {
			Text = "None",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -28, 0.5, 0),
			Size = UDim2.fromOffset(112, 16),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = METRICS.TextTiny,
			TextColor3 = COLORS.Muted,
			FontFace = FONT_REGULAR,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local chevron = createChevron(card, COLORS.Muted)
		local popup
		local scrim

		local function describe()
			if options.Multi then
				local selected = {}
				for _, option in ipairs(options.Options) do
					if dropdown.Value[option] then
						table.insert(selected, option)
					end
				end
				valueLabel.Text = #selected > 0 and table.concat(selected, ", ") or "None"
			else
				valueLabel.Text = tostring(dropdown.Value)
			end
		end

		local function closePopup()
			if scrim then
				scrim:Destroy()
				scrim = nil
			end
			if popup then
				popup:Destroy()
				popup = nil
			end
			tween(chevron, TWEEN_FAST, { Rotation = 0 })
		end

		local function openPopup()
			if popup then
				return closePopup()
			end

			local entryHeight = isMobile and 34 or 25
			local height = math.min(#options.Options * (entryHeight + 2) + 8, isMobile and 210 or 168)
			-- AbsolutePosition is post-scale, the popup lives in root-local space: undo the scale.
			local factor = self.window.scale.Value
			local rootPosition = self.window.root.AbsolutePosition
			local offsetX = (card.AbsolutePosition.X - rootPosition.X) / factor
			local offsetY = (card.AbsolutePosition.Y - rootPosition.Y) / factor + card.AbsoluteSize.Y / factor + 4
			if offsetY + height > self.window.root.AbsoluteSize.Y / factor - 6 then
				offsetY = math.max((card.AbsolutePosition.Y - rootPosition.Y) / factor - height - 4, 6)
			end

			-- Scrim instead of mouse coordinates: touch input has no cursor to test against.
			scrim = create("ImageButton", {
				Name = "Scrim",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				ZIndex = 199,
				Parent = self.window.root,
			})
			scrim.Activated:Connect(function()
				closePopup()
			end)

			-- Parented to the root, not the canvas: the canvas clips its descendants.
			popup = create("Frame", {
				Name = "Options",
				Position = UDim2.fromOffset(offsetX, offsetY),
				Size = UDim2.fromOffset(card.AbsoluteSize.X / factor, height),
				BackgroundColor3 = COLORS.CardHover,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				ZIndex = 200,
				Parent = self.window.root,
			})
			create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = popup })
			create("UIStroke", { Color = COLORS.Stroke, Parent = popup })

			local list = create("ScrollingFrame", {
				Name = "List",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = COLORS.Stroke,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromOffset(0, 0),
				ZIndex = 201,
				Parent = popup,
			})
			create("UIListLayout", {
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Parent = list,
			})
			create("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				Parent = list,
			})

			for index, option in ipairs(options.Options) do
				local selected = options.Multi and dropdown.Value[option] == true or dropdown.Value == option
				local entry = create("TextButton", {
					Name = "Option",
					Size = UDim2.new(1, -8, 0, entryHeight),
					BackgroundColor3 = COLORS.Card,
					BackgroundTransparency = selected and 0.75 or 1,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
					LayoutOrder = index,
					ZIndex = 202,
					Parent = list,
				})
				create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = entry })
				createLabel(entry, {
					Text = option,
					Position = UDim2.fromOffset(8, 0),
					Size = UDim2.new(1, -16, 1, 0),
					TextSize = METRICS.TextTiny,
					TextColor3 = selected and self.window.accent or COLORS.Text,
					FontFace = selected and FONT_BOLD or FONT_REGULAR,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})

				entry.MouseEnter:Connect(function()
					if not selected then
						tween(entry, TWEEN_FAST, { BackgroundTransparency = 0 })
					end
				end)
				entry.MouseLeave:Connect(function()
					if not selected then
						tween(entry, TWEEN_FAST, { BackgroundTransparency = 1 })
					end
				end)
				entry.MouseButton1Click:Connect(function()
					if options.Multi then
						dropdown.Value[option] = not dropdown.Value[option]
						describe()
						options.Callback(dropdown.Value)
						closePopup()
						openPopup()
					else
						dropdown.Value = option
						describe()
						options.Callback(option)
						closePopup()
					end
				end)
			end

			tween(chevron, TWEEN_FAST, { Rotation = 180 })
		end

		---Set the dropdown value; silent skips the callback.
		---@param value any
		---@param silent boolean?
		function dropdown:Set(value, silent)
			if options.Multi then
				self.Value = type(value) == "table" and value or {}
			else
				self.Value = value
			end
			describe()
			if not silent then
				options.Callback(self.Value)
			end
		end

		self.maid:Give(card.MouseButton1Click:Connect(function()
			openPopup()
		end))

		table.insert(self.closers, closePopup)
		describe()
		options.Callback(dropdown.Value)
		return dropdown
	end

	---Add a push button row.
	---@param settings table
	---@return Instance
	function Tab:Button(settings)
		local options = {
			Text = settings.Text or "Button",
			Callback = settings.Callback or function() end,
		}

		local card = self:card(METRICS.RowButton, "ImageButton")
		self:hover(card)
		createLabel(card, {
			Text = options.Text,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = METRICS.TextSmall,
			TextColor3 = self.window.accent,
		})

		self.maid:Give(card.MouseButton1Click:Connect(function()
			options.Callback()
		end))
		return card
	end

	---Add a keybind row. Callback receives pressed on down and false on up.
	---@param settings table
	---@return table
	function Tab:Keybind(settings)
		local options = {
			Text = settings.Text or "Keybind",
			Callback = settings.Callback or function() end,
			Listening = false,
		}

		local card = self:card(METRICS.Row, "ImageButton")
		self:hover(card)

		local keybind = {
			Value = settings.Default or Enum.KeyCode.RightShift,
			Element = card,
		}

		createLabel(card, {
			Text = options.Text,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -110, 1, 0),
			TextSize = METRICS.TextSmall,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local pill = create("Frame", {
			Name = "Pill",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(isMobile and 84 or 78, isMobile and 28 or 22),
			BackgroundColor3 = COLORS.Base,
			BorderSizePixel = 0,
			Parent = card,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = pill })
		create("UIStroke", { Color = COLORS.Stroke, Parent = pill })

		local pillText = createLabel(pill, {
			Text = keybind.Value.Name,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = METRICS.TextTiny,
		})

		local function stopListening()
			options.Listening = false
			pillText.Text = keybind.Value.Name
		end

		---Set the bound key without firing the callback.
		---@param key Enum.KeyCode
		function keybind:Set(key)
			self.Value = key
			stopListening()
		end

		-- Rebind capture needs a keyboard; on touch the row stays a read-only display.
		if not isMobile then
			self.maid:Give(card.MouseButton1Click:Connect(function()
				if options.Listening then
					stopListening()
					return
				end
				options.Listening = true
				pillText.Text = "..."
			end))
		end

		self.maid:Give(userInputService.InputBegan:Connect(function(input, gameProcessed)
			if options.Listening then
				if input.KeyCode == Enum.KeyCode.Unknown then
					return
				end
				if input.KeyCode == Enum.KeyCode.Escape then
					stopListening()
				else
					keybind.Value = input.KeyCode
					stopListening()
				end
				return
			end
			if not gameProcessed and input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == keybind.Value then
				options.Callback(true)
			end
		end))

		self.maid:Give(userInputService.InputEnded:Connect(function(input)
			if not options.Listening and input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == keybind.Value then
				options.Callback(false)
			end
		end))

		return keybind
	end

	---Add a text field row.
	---@param settings table
	---@return table
	function Tab:Input(settings)
		local options = {
			Text = settings.Text or "Input",
			Default = tostring(settings.Default or ""),
			Placeholder = settings.Placeholder or "",
			Callback = settings.Callback or function() end,
		}

		local card = self:card(isMobile and 66 or 54)
		local input = { Value = options.Default }

		createLabel(card, {
			Text = options.Text,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 16),
			TextSize = METRICS.TextSmall,
		})

		local box = create("TextBox", {
			Name = "Box",
			Position = UDim2.fromOffset(12, isMobile and 34 or 26),
			Size = UDim2.new(1, -24, 0, isMobile and 26 or 20),
			BackgroundColor3 = COLORS.Base,
			BorderSizePixel = 0,
			Text = options.Default,
			PlaceholderText = options.Placeholder,
			PlaceholderColor3 = COLORS.Muted,
			FontFace = FONT_REGULAR,
			TextColor3 = COLORS.Text,
			TextSize = METRICS.TextTiny,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			Parent = card,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = box })
		create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box })

		---Set the field text without firing the callback.
		---@param value string
		function input:Set(value)
			self.Value = tostring(value)
			box.Text = self.Value
		end

		self.maid:Give(box.FocusLost:Connect(function(entered)
			input.Value = box.Text
			options.Callback(input.Value, entered)
		end))

		return input
	end

	---Add a section header.
	---@param title string
	function Tab:Section(title)
		self.elementOrder = self.elementOrder + 1
		local holder = create("Frame", {
			Name = "Section",
			Size = UDim2.new(1, -28, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = self.elementOrder,
			Parent = self.canvas,
		})
		createLabel(holder, {
			Text = string.upper(title),
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -4, 0, 20),
			TextSize = METRICS.TextTiny,
			FontFace = FONT_BOLD,
			TextColor3 = self.window.accent,
		})
		create("Frame", {
			Name = "Rule",
			Position = UDim2.new(0, 2, 1, -4),
			Size = UDim2.new(1, -4, 0, 1),
			BackgroundColor3 = COLORS.Stroke,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Parent = holder,
		})
	end

	---Add a wrapped helper line.
	---@param settings table
	---@return TextLabel
	function Tab:Paragraph(settings)
		self.elementOrder = self.elementOrder + 1
		local paragraph = createLabel(self.canvas, {
			Name = "Paragraph",
			Text = settings.Text or "",
			Size = UDim2.new(1, -28, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = METRICS.TextTiny,
			TextColor3 = COLORS.Muted,
			FontFace = FONT_REGULAR,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = self.elementOrder,
		})
		create("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6), Parent = paragraph })
		return paragraph
	end

	---@module Features.Menu.Objects.Window
	---Create the window.
	---@param config table?
	---@return table
	function JC7.new(config)
		local settings = config or {}
		local self = setmetatable({}, JC7)

		self.title = settings.Title or "jc7"
		self.subtitle = settings.Subtitle or ("v" .. VERSION)
		self.accent = settings.Accent or DEFAULT_ACCENT
		self.tabs = {}
		self.order = 0
		self.visible = true
		self.minimized = false
		self.expandedSize = settings.Size or (isMobile and UDim2.fromOffset(560, 430) or UDim2.fromOffset(612, 396))
		self.maid = Maid.new()

		self.gui = create("ScreenGui", {
			Name = "jc7",
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 999,
		})
		self.maid:Give(self.gui)

		local parentOk = pcall(function()
			self.gui.Parent = resolveGuiParent()
		end)
		if not parentOk then
			self.gui.Parent = playersService.LocalPlayer:WaitForChild("PlayerGui")
		end

		self.root = create("Frame", {
			Name = "Root",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = settings.Position or UDim2.fromScale(0.5, 0.5),
			Size = self.expandedSize,
			BackgroundColor3 = COLORS.Base,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
			Parent = self.gui,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = self.root })
		create("UIStroke", { Color = COLORS.Stroke, Thickness = 1, Transparency = 0.25, Parent = self.root })

		self.scale = create("UIScale", { Scale = 1, Parent = self.root })

		self.header = create("Frame", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			BackgroundTransparency = 1,
			Active = true,
			Parent = self.root,
		})

		local mark = create("Frame", {
			Name = "Mark",
			Position = UDim2.fromOffset(14, 12),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = self.accent,
			BorderSizePixel = 0,
			Parent = self.header,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = mark })
		createLabel(mark, {
			Text = "7",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 13,
			FontFace = FONT_BOLD,
			TextColor3 = Color3.new(1, 1, 1),
		})

		createLabel(self.header, {
			Text = self.title,
			Position = UDim2.fromOffset(46, 7),
			Size = UDim2.new(1, -170, 0, 17),
			TextSize = 13,
			FontFace = FONT_BOLD,
		})
		createLabel(self.header, {
			Text = self.subtitle,
			Position = UDim2.fromOffset(46, 24),
			Size = UDim2.new(1, -170, 0, 14),
			TextSize = 10,
			TextColor3 = COLORS.Muted,
			FontFace = FONT_REGULAR,
		})

		local function headerButton(text, offset, onClick)
			local button = create("ImageButton", {
				Name = "HeaderButton",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, offset, 0.5, 0),
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = COLORS.Card,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Parent = self.header,
			})
			create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })
			createLabel(button, {
				Text = text,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 12,
				TextColor3 = COLORS.Muted,
			})
			self.maid:Give(button.MouseEnter:Connect(function()
				tween(button, TWEEN_FAST, { BackgroundTransparency = 0 })
			end))
			self.maid:Give(button.MouseLeave:Connect(function()
				tween(button, TWEEN_FAST, { BackgroundTransparency = 1 })
			end))
			self.maid:Give(button.MouseButton1Click:Connect(onClick))
			return button
		end

		headerButton("-", -12, function()
			self:SetMinimized(not self.minimized)
		end)
		headerButton("X", -42, function()
			self:SetVisible(false)
		end)

		create("Frame", {
			Name = "HeaderRule",
			Position = UDim2.fromOffset(0, HEADER_HEIGHT),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = COLORS.Stroke,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Parent = self.root,
		})

		self.body = create("Frame", {
			Name = "Body",
			Position = UDim2.fromOffset(0, HEADER_HEIGHT + 1),
			Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 1)),
			BackgroundTransparency = 1,
			Parent = self.root,
		})

		local sidebar = create("Frame", {
			Name = "Sidebar",
			Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
			BackgroundColor3 = COLORS.Sidebar,
			BorderSizePixel = 0,
			Parent = self.body,
		})

		self.tabHolder = create("ScrollingFrame", {
			Name = "TabHolder",
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 1, -50),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromOffset(0, 0),
			Parent = sidebar,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = self.tabHolder,
		})

		createLabel(sidebar, {
			Name = "User",
			Text = tostring(playersService.LocalPlayer),
			Position = UDim2.new(0, 14, 1, -34),
			Size = UDim2.new(1, -28, 0, 14),
			TextSize = METRICS.TextTiny,
			TextColor3 = COLORS.Text,
			FontFace = FONT_MEDIUM,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		createLabel(sidebar, {
			Name = "Version",
			Text = "jc7 " .. VERSION,
			Position = UDim2.new(0, 14, 1, -20),
			Size = UDim2.new(1, -28, 0, 14),
			TextSize = METRICS.TextTiny,
			TextColor3 = COLORS.Muted,
			FontFace = FONT_REGULAR,
		})

		self.content = create("Frame", {
			Name = "Content",
			Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0),
			Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			Parent = self.body,
		})

		self.path = createLabel(self.content, {
			Name = "Path",
			Text = "jc7",
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -32, 0, 40),
			TextSize = METRICS.TextSmall,
			TextColor3 = COLORS.Muted,
		})

		self.toastHolder = create("Frame", {
			Name = "Toasts",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, HEADER_HEIGHT + 12),
			Size = UDim2.fromOffset(206, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 60,
			Parent = self.root,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = self.toastHolder,
		})

		-- Header drag.
		local dragging = false
		local dragStart
		local startPosition
		self.maid:Give(self.header.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPosition = self.root.Position
			end
		end))
		self.maid:Give(userInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - dragStart
				self.root.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
			end
		end))
		self.maid:Give(userInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if dragging then
					dragging = false
					self:ClampToViewport()
				end
			end
		end))

		-- Optional window keybind; pass Keybind = false to let a menu element own it.
		if settings.Keybind ~= false then
			local key = settings.Keybind or Enum.KeyCode.RightShift
			self.maid:Give(userInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then
					return
				end
				if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == key then
					self:SetVisible(not self.visible)
				end
			end))
		end

		-- Touch has no keyboard, so a hidden window needs a screen affordance to come back.
		if isMobile then
			self:ApplyScale()
			task.defer(function()
				self:ApplyScale()
			end)
			self.maid:Give(self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				self:ApplyScale()
			end))

			local orb = create("ImageButton", {
				Name = "Orb",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -14, 1, -14),
				Size = UDim2.fromOffset(46, 46),
				BackgroundColor3 = self.accent,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				ZIndex = 1,
				Parent = self.gui,
			})
			create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = orb })
			createLabel(orb, {
				Text = "7",
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 20,
				FontFace = FONT_BOLD,
				TextColor3 = Color3.new(1, 1, 1),
			})
			self.orb = orb
			self.maid:Give(orb)

			local orbDragging = false
			local orbStart
			local orbOrigin
			local orbTravel = 0

			self.maid:Give(orb.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					orbDragging = true
					orbStart = input.Position
					orbOrigin = orb.Position
					orbTravel = 0
				end
			end))

			self.maid:Give(userInputService.InputChanged:Connect(function(input)
				if not orbDragging then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then
					return
				end
				local delta = input.Position - orbStart
				orbTravel = math.max(orbTravel, delta.Magnitude)
				orb.Position = UDim2.new(orbOrigin.X.Scale, orbOrigin.X.Offset + delta.X, orbOrigin.Y.Scale, orbOrigin.Y.Offset + delta.Y)
			end))

			self.maid:Give(userInputService.InputEnded:Connect(function(input)
				if not orbDragging then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return
				end
				orbDragging = false
				if orbTravel < 8 then
					self:SetVisible(not self.visible)
				end
			end))
		end

		-- Re-execution replaces the previous build instead of stacking windows.
		if shared.jc7 and type(shared.jc7.Destroy) == "function" then
			pcall(function()
				shared.jc7:Destroy()
			end)
		end
		shared.jc7 = self

		return self
	end

	---Shrink the window until it fits the viewport; never scales above 1:1.
	function JC7:ApplyScale()
		local viewport = self.gui.AbsoluteSize
		if viewport.X < 1 or viewport.Y < 1 then
			return
		end
		local width = self.expandedSize.X.Scale * viewport.X + self.expandedSize.X.Offset
		local height = self.expandedSize.Y.Scale * viewport.Y + self.expandedSize.Y.Offset
		local factor = math.min(1, (viewport.X - 16) / width, (viewport.Y - 16) / height)
		self.scale.Scale = math.clamp(factor, 0.45, 1)
		self:ClampToViewport()
	end

	---Pull the window back inside the screen when a drag leaves it hanging.
	function JC7:ClampToViewport()
		local viewport = self.gui.AbsoluteSize
		if viewport.X < 1 or viewport.Y < 1 then
			return
		end
		local absolute = self.root.AbsolutePosition
		local size = self.root.AbsoluteSize
		local shiftX = 0
		local shiftY = 0
		if absolute.X < 0 then
			shiftX = -absolute.X
		elseif absolute.X + size.X > viewport.X then
			shiftX = viewport.X - (absolute.X + size.X)
		end
		if absolute.Y < 0 then
			shiftY = -absolute.Y
		elseif absolute.Y + size.Y > viewport.Y then
			shiftY = viewport.Y - (absolute.Y + size.Y)
		end
		if shiftX == 0 and shiftY == 0 then
			return
		end
		-- Absolute values are post-scale, Position is pre-scale.
		local factor = self.scale and self.scale.Scale or 1
		local position = self.root.Position
		self.root.Position = UDim2.new(position.X.Scale, position.X.Offset + shiftX / factor, position.Y.Scale, position.Y.Offset + shiftY / factor)
	end

	---Show or hide the window.
	---@param visible boolean
	function JC7:SetVisible(visible)
		self.visible = visible == true
		self.root.Visible = self.visible
	end

	---Flip visibility.
	function JC7:Toggle()
		self:SetVisible(not self.visible)
	end

	---Collapse the window down to its header.
	---@param minimized boolean
	function JC7:SetMinimized(minimized)
		self.minimized = minimized == true
		self.body.Visible = not self.minimized
		local goal = self.minimized and UDim2.new(self.expandedSize.X.Scale, self.expandedSize.X.Offset, 0, HEADER_HEIGHT) or self.expandedSize
		tween(self.root, TWEEN_MEDIUM, { Size = goal })
	end

	---Add a tab and its sidebar entry.
	---@param name string
	---@param icon string? bare asset id
	---@return table
	function JC7:Tab(name, icon)
		self.order = self.order + 1
		local tab = setmetatable({
			window = self,
			name = name,
			order = self.order,
			maid = Maid.new(),
			elementOrder = 0,
			closers = {},
		}, Tab)

		local button = create("ImageButton", {
			Name = "TabButton",
			Size = UDim2.new(1, -16, 0, METRICS.Tab),
			BackgroundColor3 = COLORS.Card,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			LayoutOrder = tab.order,
			Parent = self.tabHolder,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })

		local indicator = create("Frame", {
			Name = "Indicator",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(2, 14),
			BackgroundColor3 = self.accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = button,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = indicator })

		local textX = 12
		if icon then
			tab.iconLabel = create("ImageLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Image = "rbxassetid://" .. tostring(icon),
				ImageColor3 = COLORS.Muted,
				Parent = button,
			})
			textX = 34
		end

		tab.label = createLabel(button, {
			Text = name,
			Position = UDim2.fromOffset(textX, 0),
			Size = UDim2.new(1, -(textX + 8), 1, 0),
			TextSize = METRICS.TextSmall,
			TextColor3 = COLORS.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		tab.canvas = create("ScrollingFrame", {
			Name = "Canvas",
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 1, -40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = COLORS.Stroke,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromOffset(0, 0),
			Visible = false,
			Parent = self.content,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = tab.canvas,
		})
		create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 12),
			Parent = tab.canvas,
		})

		tab.button = button
		tab.indicator = indicator

		---Make this tab the visible one.
		function tab:Activate()
			local window = self.window
			if window.currentTab and window.currentTab ~= self then
				window.currentTab:Deactivate()
			end
			window.currentTab = self

			self.canvas.Visible = true
			window.path.Text = string.format('jc7 <font color="%s">/</font> %s', toHex(window.accent), self.name)
			tween(self.button, TWEEN_FAST, { BackgroundTransparency = 0 })
			tween(self.indicator, TWEEN_FAST, { BackgroundTransparency = 0 })
			tween(self.label, TWEEN_FAST, { TextColor3 = COLORS.Text })
			if self.iconLabel then
				tween(self.iconLabel, TWEEN_FAST, { ImageColor3 = window.accent })
			end
		end

		---Hide this tab and drop anything it left floating.
		function tab:Deactivate()
			self.canvas.Visible = false
			for _, close in ipairs(self.closers) do
				close()
			end
			tween(self.button, TWEEN_FAST, { BackgroundTransparency = 1 })
			tween(self.indicator, TWEEN_FAST, { BackgroundTransparency = 1 })
			tween(self.label, TWEEN_FAST, { TextColor3 = COLORS.Muted })
			if self.iconLabel then
				tween(self.iconLabel, TWEEN_FAST, { ImageColor3 = COLORS.Muted })
			end
		end

		self.maid:Give(button.MouseButton1Click:Connect(function()
			tab:Activate()
		end))

		table.insert(self.tabs, tab)
		if not self.currentTab then
			tab:Activate()
		end
		return tab
	end

	---Push a toast into the top-right stack.
	---@param settings table
	---@return CanvasGroup
	function JC7:Notify(settings)
		local config = settings or {}
		local toast = create("CanvasGroup", {
			Name = "Toast",
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = COLORS.Card,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			GroupTransparency = 1,
			Parent = self.toastHolder,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = toast })
		create("UIStroke", { Color = COLORS.Stroke, Transparency = 0.2, Parent = toast })
		create("Frame", {
			Name = "Accent",
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(0, 2, 0, 30),
			BackgroundColor3 = self.accent,
			BorderSizePixel = 0,
			Parent = toast,
		})
		createLabel(toast, {
			Text = config.Title or "jc7",
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 16),
			TextSize = 11,
			FontFace = FONT_BOLD,
		})
		createLabel(toast, {
			Text = config.Text or "",
			Position = UDim2.fromOffset(12, 22),
			Size = UDim2.new(1, -24, 0, 16),
			TextSize = 10,
			TextColor3 = COLORS.Muted,
			FontFace = FONT_REGULAR,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		tween(toast, TWEEN_MEDIUM, { GroupTransparency = 0 })

		task.delay(config.Duration or 3, function()
			if not toast.Parent then
				return
			end
			tween(toast, TWEEN_MEDIUM, { GroupTransparency = 1 })
			task.delay(0.24, function()
				if toast.Parent then
					toast:Destroy()
				end
			end)
		end)

		return toast
	end

	---Tear the whole window and every connection down.
	function JC7:Destroy()
		for _, tab in ipairs(self.tabs) do
			tab.maid:Clean()
		end
		self.maid:Clean()
		if self.gui then
			self.gui:Destroy()
		end
	end

	return JC7
end)()
