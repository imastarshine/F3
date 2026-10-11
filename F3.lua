--!strict

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

--================ TYPES ================--

export type CornerName = "LeftTop" | "RightTop" | "LeftBottom" | "RightBottom"

export type TextArgs = {
	Text: string?,
	Color: Color3?,
	Font: Font?,
	Size: number?,
	Wrap: boolean?,
}

export type ContainerArgs = {
	Spacing: number?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	VerticalAlignment: Enum.VerticalAlignment?,
}

export type Theme = {
	Font: Font?,
	TextSize: number?,
	TextColor: Color3?,
	StrokeColor: Color3?,
	StrokeTransparency: number?,
	BackgroundColor: Color3?,
	BackgroundTransparency: number?,
	CornerRadius: number?,
	CornerWidth: number?,
	Spacing: number?,
}

export type F3Args = {
	ScreenGui: ScreenGui,
	ToggleKey: Enum.KeyCode?,
	Visible: boolean?,
	Theme: Theme?,
}

export type TextControl = {
	Text: string,
	Color: Color3,
	Font: Font,
	Size: number,
	Wrap: boolean,
	Instance: TextLabel,
	Destroy: (self: TextControl) -> (),
}

export type ContainerControl = {
	Spacing: number,
	HorizontalAlignment: Enum.HorizontalAlignment,
	VerticalAlignment: Enum.VerticalAlignment,
	Theme: Theme,
	Instance: GuiObject,
	Children: {any},
	Text: (self: ContainerControl, Args: TextArgs?) -> TextControl,
	Row: (self: ContainerControl, Args: ContainerArgs?) -> ContainerControl,
	Column: (self: ContainerControl, Args: ContainerArgs?) -> ContainerControl,
	Clear: (self: ContainerControl) -> (),
	Destroy: (self: ContainerControl) -> (),
}

export type F3 = {
	LeftTop: ContainerControl,
	RightTop: ContainerControl,
	LeftBottom: ContainerControl,
	RightBottom: ContainerControl,
	ScreenGui: ScreenGui,
	Visible: boolean,
	Destroy: (self: F3) -> (),
}

--================ CONSTANTS ================--

type FilledTheme = {
	Font: Font,
	TextSize: number,
	TextColor: Color3,
	StrokeColor: Color3,
	StrokeTransparency: number,
	BackgroundColor: Color3,
	BackgroundTransparency: number,
	CornerRadius: number,
	CornerWidth: number,
	Spacing: number,
}

type CornerConfig = {
	AnchorPoint: Vector2,
	Position: UDim2,
	HorizontalAlignment: Enum.HorizontalAlignment,
	VerticalAlignment: Enum.VerticalAlignment,
}

local DEFAULT_FONT = Font.new("rbxasset://fonts/families/Ubuntu.json")
local FADE_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)

local CORNERS = {
	LeftTop = {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 10, 0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	},
	RightTop = {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	},
	LeftBottom = {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	},
	RightBottom = {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	},
} :: { [CornerName]: CornerConfig }

--================ HELPERS ================--

local function ValueOr<T>(value: T?, default: T): T
	if value ~= nil then
		return value
	end
	return default
end

local function GetRaw<T>(slf: T): T
	local raw = (slf :: any)._gettable
	if not raw then
		error("F3: failed to find raw data")
	end
	return raw :: T
end

local function CreateProxy(
	raw: any,
	methods: { [string]: any },
	onWrite: (raw: any, key: string, value: any) -> ()
): any
	local mt = {
		_gettable = raw,
		__index = function(_: any, key: string)
			if key == "_gettable" then return raw end
			local value = raw[key]
			if value ~= nil then return value end
			return methods[key]
		end,
		__newindex = function(_: any, key: string, value: any)
			if key == "Instance" then
				error("F3: property 'Instance' is read-only")
			end
			local old = raw[key]
			raw[key] = value
			if old ~= value then
				onWrite(raw, key, value)
			end
		end,
	}
	return setmetatable({}, mt)
end

local function MergeTheme(theme: Theme?): FilledTheme
	local merged = {
		Font = DEFAULT_FONT,
		TextSize = 14,
		TextColor = Color3.new(1, 1, 1),
		StrokeColor = Color3.new(0, 0, 0),
		StrokeTransparency = 0.5,
		BackgroundColor = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		CornerRadius = 6,
		CornerWidth = 0.3,
		Spacing = 2,
	} :: FilledTheme
	if theme then
		for key: string, value: any in pairs((theme :: any)) do
			(merged :: any)[key] = value
		end
	end
	return merged
end

local CurrentlyDragging: GuiObject? = nil

local function DragGUI(gui: GuiObject)
	local dragging = false
	local dragInput: InputObject?
	local dragStart: Vector3
	local startPos: UDim2

	local function update(input: InputObject)
		local delta = input.Position - dragStart
		local newPos = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
		TweenService:Create(gui, TweenInfo.new(0.05), { Position = newPos }):Play()
	end

	gui.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch)
			and CurrentlyDragging == nil
		then
			dragging = true
			CurrentlyDragging = gui

			dragStart = input.Position
			startPos = gui.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					CurrentlyDragging = nil
				end
			end)
		end
	end)

	gui.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and CurrentlyDragging == gui and input == dragInput then
			update(input)
		end
	end)
end

--================ TEXT ================--

local TextMethods = {} :: any
TextMethods.__index = TextMethods

function TextMethods:Destroy()
	local raw = (self :: any)._gettable
	if not raw then return end

	if raw.Instance then
		raw.Instance:Destroy()
	end

	for k: any, v: any in pairs((raw :: any)) do
		raw[k] = nil
	end

	setmetatable(self, nil)
end

local function CreateText(
	parent: GuiObject,
	args: TextArgs?,
	theme: FilledTheme,
	alignment: Enum.HorizontalAlignment,
	fixedWidth: boolean
): TextControl
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.RichText = true
	label.FontFace = ValueOr(args and args.Font, theme.Font)
	label.TextSize = ValueOr(args and args.Size, theme.TextSize)
	label.TextColor3 = ValueOr(args and args.Color, theme.TextColor)
	label.TextWrapped = ValueOr(args and args.Wrap, false)
	label.TextXAlignment = if alignment == Enum.HorizontalAlignment.Right
		then Enum.TextXAlignment.Right
		else Enum.TextXAlignment.Left
	label.Text = ValueOr(args and args.Text, "")
	label.Parent = parent

	if fixedWidth then
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, 0, 0, 0)
	else
		label.AutomaticSize = Enum.AutomaticSize.XY
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "UIStroke"
	stroke.Thickness = 1
	stroke.Color = theme.StrokeColor
	stroke.Transparency = theme.StrokeTransparency
	stroke.Parent = label

	local data = {
		Text = label.Text,
		Color = label.TextColor3,
		Font = label.FontFace,
		Size = label.TextSize,
		Wrap = label.TextWrapped,
		Instance = label,
	} :: TextControl

	return CreateProxy(data, TextMethods, function(_: any, key: string, value: any)
		if key == "Text" then label.Text = value
		elseif key == "Color" then label.TextColor3 = value
		elseif key == "Font" then label.FontFace = value
		elseif key == "Size" then label.TextSize = value
		elseif key == "Wrap" then label.TextWrapped = value
		end
	end) :: TextControl
end

--================ CONTAINERS ================--

local ContainerMethods = {} :: any
ContainerMethods.__index = ContainerMethods

local function CreateContainer(
	parent: Instance,
	name: string,
	args: ContainerArgs?,
	theme: FilledTheme,
	corner: CornerConfig?
): ContainerControl
	local frame = Instance.new(if corner ~= nil then "CanvasGroup" else "Frame") :: GuiObject
	frame.Name = name
	if corner ~= nil then
		frame.Size = UDim2.new(theme.CornerWidth, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
	else
		frame.Size = UDim2.new()
		frame.AutomaticSize = Enum.AutomaticSize.XY
	end
	frame.BackgroundColor3 = theme.BackgroundColor
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = if corner ~= nil then theme.BackgroundTransparency else 1
	frame.Parent = parent

	if corner ~= nil then
		frame.AnchorPoint = corner.AnchorPoint
		frame.Position = corner.Position
	end

	local isRow = name == "Row"
	local horizontal = if corner ~= nil
		then corner.HorizontalAlignment
		else ValueOr(args and args.HorizontalAlignment, Enum.HorizontalAlignment.Left)
	local vertical = if corner ~= nil
		then corner.VerticalAlignment
		else ValueOr(args and args.VerticalAlignment, Enum.VerticalAlignment.Top)
	local spacing = ValueOr(args and args.Spacing, theme.Spacing)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, spacing)
	layout.FillDirection = if isRow then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.HorizontalAlignment = horizontal
	layout.VerticalAlignment = vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	if corner ~= nil then
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = frame

		local uicorner = Instance.new("UICorner")
		uicorner.CornerRadius = UDim.new(0, theme.CornerRadius)
		uicorner.Parent = frame
	end

	local control = {
		Name = name,
		FixedWidth = corner ~= nil,
		Spacing = spacing,
		HorizontalAlignment = horizontal,
		VerticalAlignment = vertical,
		Theme = theme,
		Instance = frame,
		Children = {},
	} :: any

	return setmetatable(control, ContainerMethods) :: any
end

function ContainerMethods:Text(Args: TextArgs?): TextControl
	local raw = (self :: any)
	local control = CreateText(
		raw.Instance,
		Args,
		raw.Theme,
		raw.HorizontalAlignment,
		raw.FixedWidth == true
	)
	table.insert(raw.Children, control)
	return control
end

function ContainerMethods:Row(Args: ContainerArgs?): ContainerControl
	local raw = (self :: any)
	local control = CreateContainer(raw.Instance, "Row", Args, raw.Theme, nil)
	table.insert(raw.Children, control)
	return control
end

function ContainerMethods:Column(Args: ContainerArgs?): ContainerControl
	local raw = (self :: any)
	local control = CreateContainer(raw.Instance, "Column", Args, raw.Theme, nil)
	table.insert(raw.Children, control)
	return control
end

function ContainerMethods:Clear()
	local raw = (self :: any)
	for _, child in raw.Children do
		child:Destroy()
	end
	raw.Children = {}
end

function ContainerMethods:Destroy()
	local raw = (self :: any)
	self:Clear()
	if raw.Instance then
		raw.Instance:Destroy()
	end
	setmetatable(self, nil)
end

--================ ROOT ================--

local F3Methods = {
	Destroy = function(self: F3)
		local raw = GetRaw(self) :: any
		if not raw then return end

		if raw.InputConnection then
			raw.InputConnection:Disconnect()
		end
		if raw.Button then
			raw.Button:Destroy()
		end
		for _, corner in raw.Corners do
			corner:Destroy()
		end

		for k: any, v: any in pairs((raw :: any)) do
			raw[k] = nil
		end

		setmetatable(self, nil)
	end,
}

local function FadeMenu(raw: any, visible: boolean)
	for _, corner in raw.Corners do
		local group = corner.Instance :: CanvasGroup
		local theme = corner.Theme

		if visible then
			group.Visible = true
		end

		local tween = TweenService:Create(group, FADE_TWEEN, {
			GroupTransparency = if visible then 0 else 1,
		})
		tween:Play()

		if not visible then
			tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
				if playbackState == Enum.PlaybackState.Completed and raw.Visible == false then
					group.Visible = false
				end
			end)
		end

		for _, text in group:QueryDescendants("TextLabel, TextButton, TextBox") do
			TweenService:Create(text, FADE_TWEEN, {
				TextTransparency = if visible then 0 else 1,
			}):Play()
		end

		for _, stroke in group:QueryDescendants("UIStroke") do
			TweenService:Create(stroke, FADE_TWEEN, {
				Transparency = if visible then theme.StrokeTransparency else 1,
			}):Play()
		end
	end
end

local function BuildRoot(raw: any): F3
	return CreateProxy(raw, F3Methods, function(_: any, key: string, value: any)
		if key == "Visible" then
			FadeMenu(raw, value)
		end
	end) :: F3
end

--================ F3 ================--

local F3 = {}

function F3.Color(color3: Color3, text: string): string
	return `<font color = \"#{color3:ToHex()}\">{text}</font>`
end

function F3.new(Args: F3Args): F3
	local theme = MergeTheme(Args.Theme)
	local screenGui = Args.ScreenGui

	local raw = {
		ScreenGui = screenGui,
		Visible = ValueOr(Args.Visible, true),
		Theme = theme,
		Corners = {},
	} :: any

	for name: CornerName, config: CornerConfig in CORNERS do
		local corner = CreateContainer(screenGui, name, nil, theme, config)
		table.insert(raw.Corners, corner)
		raw[name] = corner
	end

	if not raw.Visible then
		for _, corner in raw.Corners do
			local group = corner.Instance :: CanvasGroup
			group.GroupTransparency = 1
			group.Visible = false
		end
	end

	local button = Instance.new("TextButton")
	button.Name = "F3Button"
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.fromOffset(0, 0)
	button.Size = UDim2.fromOffset(30, 30)
	button.BackgroundColor3 = theme.BackgroundColor
	button.BackgroundTransparency = 0.4
	button.BorderSizePixel = 0
	button.Text = "F3"
	button.TextColor3 = theme.TextColor
	button.TextSize = 11
	button.FontFace = theme.Font
	button.Parent = screenGui

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(1, 0)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Name = "UIStroke"
	buttonStroke.Color = theme.StrokeColor
	buttonStroke.Transparency = 0.5
	buttonStroke.Parent = button

	DragGUI(button)

	button.MouseButton1Click:Connect(function()
		raw.Visible = not raw.Visible
		FadeMenu(raw, raw.Visible)
	end)
	raw.Button = button

	local toggleKey = ValueOr(Args.ToggleKey, Enum.KeyCode.F3)
	raw.InputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == toggleKey then
			raw.Visible = not raw.Visible
			FadeMenu(raw, raw.Visible)
		end
	end)

	return BuildRoot(raw)
end

return F3
