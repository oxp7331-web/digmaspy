--[[
	DigmaSpy UI Module
	Using Orion Library
	https://github.com/shlexware/Orion
]]

local Ui = {
	DefaultEditorContent = "-- Welcome to DigmaSpy\n-- Select a remote to view generated code",
	Logs = setmetatable({}, {__mode = "k"}),
	LogQueue = setmetatable({}, {__mode = "v"}),
	Window = nil,
	OrionLib = nil,
	MainWindow = nil,
	ActiveTab = "Logs",
}

type table = {
	[any]: any
}

type Log = {
	Remote: Instance,
	Method: string,
	Args: table,
	IsReceive: boolean?,
	MetaMethod: string?,
	OrignalFunc: ((...any) -> ...any)?,
	CallingScript: Instance?,
	CallingFunction: ((...any) -> ...any)?,
	ClassData: table?,
	ReturnValues: table?,
	RemoteData: table?,
	Id: string,
}

--// Compatibility
local SetClipboard = setclipboard or toclipboard or set_clipboard

--// Libraries
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()

--// Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

--// Modules
local Flags
local Generation
local Process
local Hook 
local Config

--// UI State
local ActiveData = nil
local RemotesCount = 0
local LogElements = {}
local EditorText = ""
local CurrentRemoteId = nil

--// Theme Colors
local Theme = {
	Primary = Color3.fromRGB(25, 25, 35),
	Secondary = Color3.fromRGB(35, 35, 50),
	Accent = Color3.fromRGB(100, 50, 200),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(180, 180, 180),
	Success = Color3.fromRGB(50, 200, 100),
	Error = Color3.fromRGB(200, 50, 50),
	Warning = Color3.fromRGB(200, 150, 50),
	MethodColors = {
		fireServer = Color3.fromRGB(100, 150, 255),
		invokeServer = Color3.fromRGB(255, 100, 150),
		onClientEvent = Color3.fromRGB(100, 255, 150),
		onClientInvoke = Color3.fromRGB(255, 200, 100),
	}
}

function Ui:SetClipboard(Content: string)
	if SetClipboard then
		SetClipboard(Content)
		self:Notify("Copied to clipboard!", 2)
	end
end

function Ui:Notify(Text: string, Time: number?)
	OrionLib:MakeNotification({
		Name = "DigmaSpy",
		Content = Text,
		Image = "rbxassetid://4483345998",
		Time = Time or 3
	})
end

function Ui:Init(Data)
	local Modules = Data.Modules
	
	--// Modules
	Flags = Modules.Flags
	Generation = Modules.Generation
	Process = Modules.Process
	Hook = Modules.Hook
	Config = Modules.Config
	
	self.OrionLib = OrionLib
end

function Ui:CreateWindow()
	--// Create main window
	local Window = OrionLib:MakeWindow({
		Name = "DigmaSpy | +999999 AURA",
		HidePremium = true,
		SaveConfig = false,
		ConfigFolder = "DigmaSpy",
		IntroEnabled = true,
		IntroText = "DigmaSpy",
		IntroIcon = "rbxassetid://4483345998",
	})
	
	self.MainWindow = Window
	
	--// UIVisible flag callback
	Flags:SetFlagCallback("UiVisible", function(self, Visible)
		-- Toggle window visibility
	end)
	
	--// Create all tabs
	self:CreateLogsTab(Window)
	self:CreateEditorTab(Window)
	self:CreateOptionsTab(Window)
	
	return Window
end

function Ui:CreateLogsTab(Window)
	local LogsTab = Window:MakeTab({
		Name = "Logs",
		Icon = "rbxassetid://4483345998",
		PremiumOnly = false
	})
	
	--// Search/Filter section
	LogsTab:AddTextbox({
		Name = "Search Remotes",
		Default = "",
		TextDisappear = false,
		Callback = function(Value)
			self:FilterLogs(Value)
		end
	})
	
	--// Control buttons
	LogsTab:AddButton({
		Name = "Clear All Logs",
		Callback = function()
			self:ClearLogs()
			self:Notify("All logs cleared!")
		end
	})
	
	--// Stats section
	LogsTab:AddLabel("Total Remotes: 0")
	self.StatsLabel = LogsTab
	
	--// Logs container section
	LogsTab:AddSection({Name = "Remote Logs"})
	
	self.LogsTab = LogsTab
	self.LogButtons = {}
end

function Ui:CreateEditorTab(Window)
	local EditorTab = Window:MakeTab({
		Name = "Editor",
		Icon = "rbxassetid://4483345998",
		PremiumOnly = false
	})
	
	--// Current remote info
	self.RemoteInfoLabel = EditorTab:AddLabel("No remote selected")
	
	EditorTab:AddSection({Name = "Generated Script"})
	
	--// Code display (using textbox as readonly editor)
	self.CodeBox = EditorTab:AddTextbox({
		Name = "Script",
		Default = self.DefaultEditorContent,
		TextDisappear = false,
		Callback = function() end
	})
	
	--// Action buttons
	EditorTab:AddButton({
		Name = "Copy to Clipboard",
		Callback = function()
			if EditorText and EditorText ~= "" then
				self:SetClipboard(EditorText)
			else
				self:Notify("No code to copy!")
			end
		end
	})
	
	EditorTab:AddButton({
		Name = "Repeat Call",
		Callback = function()
			if ActiveData then
				self:RepeatCall(ActiveData)
			else
				self:Notify("No remote selected!")
			end
		end
	})
	
	EditorTab:AddButton({
		Name = "Get Return Values",
		Callback = function()
			if ActiveData then
				self:GetReturnValues(ActiveData)
			else
				self:Notify("No remote selected!")
			end
		end
	})
	
	EditorTab:AddButton({
		Name = "Generate Info",
		Callback = function()
			if ActiveData then
				self:GenerateInfo(ActiveData)
			else
				self:Notify("No remote selected!")
			end
		end
	})
	
	EditorTab:AddButton({
		Name = "Decompile Script",
		Callback = function()
			if ActiveData then
				self:DecompileScript(ActiveData)
			else
				self:Notify("No remote selected!")
			end
		end
	})
	
	self.EditorTab = EditorTab
end

function Ui:CreateOptionsTab(Window)
	local OptionsTab = Window:MakeTab({
		Name = "Options",
		Icon = "rbxassetid://4483345998",
		PremiumOnly = false
	})
	
	--// Main toggles
	OptionsTab:AddSection({Name = "Main Settings"})
	
	OptionsTab:AddToggle({
		Name = "Log Receives",
		Default = true,
		Callback = function(Value)
			Flags:SetFlagValue("LogRecives", Value)
		end
	})
	
	OptionsTab:AddToggle({
		Name = "Ignore Nil Parents",
		Default = true,
		Callback = function(Value)
			Flags:SetFlagValue("IgnoreNil", Value)
		end
	})
	
	OptionsTab:AddToggle({
		Name = "Ignore Exploit Calls",
		Default = false,
		Callback = function(Value)
			Flags:SetFlagValue("CheckCaller", Value)
		end
	})
	
	OptionsTab:AddToggle({
		Name = "No Grouping (Flat List)",
		Default = false,
		Callback = function(Value)
			Flags:SetFlagValue("NoTreeNodes", Value)
		end
	})
	
	OptionsTab:AddToggle({
		Name = "Find String for Name",
		Default = true,
		Callback = function(Value)
			Flags:SetFlagValue("FindStringForName", Value)
		end
	})
	
	--// Keybinds section
	OptionsTab:AddSection({Name = "Keybinds"})
	
	OptionsTab:AddToggle({
		Name = "Keybinds Enabled",
		Default = true,
		Callback = function(Value)
			Flags:SetFlagValue("KeybindsEnabled", Value)
		end
	})
	
	--// Actions section
	OptionsTab:AddSection({Name = "Actions"})
	
	OptionsTab:AddButton({
		Name = "Clear All Blocks",
		Callback = function()
			Process:UpdateAllRemoteData("Blocked", false)
			self:Notify("All blocks cleared!")
		end
	})
	
	OptionsTab:AddButton({
		Name = "Clear All Excludes",
		Callback = function()
			Process:UpdateAllRemoteData("Excluded", false)
			self:Notify("All excludes cleared!")
		end
	})
	
	--// Info section
	OptionsTab:AddSection({Name = "About"})
	
	OptionsTab:AddLabel("DigmaSpy - Created by oxp7331-web!")
	OptionsTab:AddLabel("Orion UI Library")
	OptionsTab:AddLabel("Boiiiiii what did you say about DigmaSpy 💀💀")
	
	self.OptionsTab = OptionsTab
end

function Ui:ShowModal(Text: string)
	self:Notify(Text, 5)
end

function Ui:ShowUnsupported(FuncName: string)
	OrionLib:MakeNotification({
		Name = "DigmaSpy - Not Supported",
		Content = "Missing function: " .. FuncName,
		Image = "rbxassetid://4483345998",
		Time = 10
	})
end

--// Log management
function Ui:QueueLog(Data)
	table.insert(self.LogQueue, Data)
end

function Ui:ProcessLogQueue()
	local Queue = self.LogQueue
	if #Queue <= 0 then return end
	
	for Index, Data in next, Queue do
		self:CreateLog(Data)
		table.remove(Queue, Index)
	end
end

function Ui:BeginLogService()
	task.spawn(function()
		while true do
			self:ProcessLogQueue()
			task.wait(0.1)
		end
	end)
end

function Ui:CreateLog(Data: Log)
	local Remote = Data.Remote
	local Method = Data.Method
	local IsReceive = Data.IsReceive
	local Id = Data.Id
	
	--// Checks
	local Paused = Flags:GetFlagValue("Paused")
	if Paused then return end
	
	local CheckCaller = Flags:GetFlagValue("CheckCaller")
	if CheckCaller and not checkcaller() then return end
	
	local IgnoreNil = Flags:GetFlagValue("IgnoreNil")
	if IgnoreNil and Hook:Index(Remote, "Parent") == nil then return end
	
	local LogRecives = Flags:GetFlagValue("LogRecives")
	if not LogRecives and IsReceive then return end
	
	local RemoteData = Process:GetRemoteData(Id)
	if RemoteData.Excluded then return end
	
	--// Create log entry
	RemotesCount += 1
	
	local Color = Theme.MethodColors[Method:lower()] or Theme.Text
	local DisplayText = `{Remote.Name} | {Method}`
	
	--// Find string for name
	local FindString = Flags:GetFlagValue("FindStringForName")
	if FindString then
		for _, Arg in next, Data.Args do
			if typeof(Arg) == "string" then
				DisplayText = `{Arg:sub(1,15)} | {DisplayText}`
				break
			end
		end
	end
	
	--// Store log data
	self.Logs[Id] = Data
	
	--// Add button for this log
	if self.LogsTab then
		local Button = self.LogsTab:AddButton({
			Name = DisplayText,
			Callback = function()
				self:SetFocusedRemote(Data)
			end
		})
		table.insert(self.LogButtons, {
			Button = Button,
			Text = DisplayText,
			Remote = Remote
		})
	end
	
	--// Update stats
	if self.StatsLabel then
		self.StatsLabel:AddLabel("Total Remotes: " .. RemotesCount)
	end
end

function Ui:ClearLogs()
	RemotesCount = 0
	table.clear(self.Logs)
	table.clear(self.LogQueue)
	
	--// Clear UI elements
	for _, Entry in next, self.LogButtons do
		if Entry.Button then
			-- Remove button (Orion doesn't have direct remove, we recreate tab)
		end
	end
	table.clear(self.LogButtons)
	
	--// Recreate logs tab
	if self.MainWindow then
		self:CreateLogsTab(self.MainWindow)
	end
end

function Ui:FilterLogs(SearchText: string)
	if SearchText == "" then
		for _, Entry in next, self.LogButtons do
			-- Show all
		end
		return
	end
	
	SearchText = SearchText:lower()
	for _, Entry in next, self.LogButtons do
		local Visible = Entry.Text:lower():find(SearchText) ~= nil
		-- Toggle visibility based on Orion capabilities
	end
end

--// Remote focus and editor functions
function Ui:SetFocusedRemote(Data: Log)
	ActiveData = Data
	CurrentRemoteId = Data.Id
	
	local Remote = Data.Remote
	local Method = Data.Method
	local Args = Data.Args
	local IsReceive = Data.IsReceive
	
	--// Update info label
	if self.RemoteInfoLabel then
		self.RemoteInfoLabel:Set("Remote: " .. tostring(Remote) .. " | Method: " .. Method)
	end
	
	--// Generate initial script
	local Module = Generation:NewParser()
	local Parsed = Generation:RemoteScript(Module, Data)
	
	self:SetEditorText(Parsed)
	
	--// Switch to editor tab
	if self.MainWindow then
		-- Switch to editor tab if possible
	end
end

function Ui:SetEditorText(Text: string)
	EditorText = Text
	if self.CodeBox then
		self.CodeBox:Set(Text)
	end
end

function Ui:RepeatCall(Data)
	local Remote = Data.Remote
	local Method = Data.Method
	local Args = Data.Args
	local IsReceive = Data.IsReceive
	
	local Signal = Hook:Index(Remote, Method)
	if IsReceive then
		if firesignal then
			firesignal(Signal, unpack(Args))
			self:Notify("Fired signal!")
		else
			self:Notify("firesignal not supported!")
		end
	else
		Signal(Remote, unpack(Args))
		self:Notify("Repeated call!")
	end
end

function Ui:GetReturnValues(Data)
	local ReturnValues = Data.ReturnValues
	local ClassData = Data.ClassData
	
	if not ClassData or not ClassData.IsRemoteFunction then
		self:SetEditorText("-- Remote is not a function bozo (-9999999 AURA)")
		return
	end
	
	if not ReturnValues then
		self:SetEditorText("-- No return values (-9999999 AURA)")
		return
	end
	
	local Script = Generation:TableScript(ReturnValues)
	self:SetEditorText(Script)
end

function Ui:GenerateInfo(Data)
	local IsReceive = Data.IsReceive
	local Function = Data.CallingFunction
	local Remote = Data.Remote
	local Method = Data.Method
	local Id = Data.Id
	local ClassData = Data.ClassData
	
	if IsReceive then
		local Script = "-- Boiiiii what did you say about IsReceive (-9999999 AURA)\n"
		Script ..= "\n-- Voice message: ▶ .ılıılıılıılıılıılı. 0:69\n"
		self:SetEditorText(Script)
		return
	end
	
	local Connections = {}
	local SourceScript = rawget(getfenv(Function), "script")
	
	local FunctionInfo = {
		["Script"] = {
			["SourceScript"] = SourceScript,
			["CallingScript"] = Data.CallingScript
		},
		["Remote"] = {
			["Remote"] = Remote,
			["RemoteID"] = Id,
			["Method"] = Method
		},
		["MetaMethod"] = Data.MetaMethod,
		["IsActor"] = Data.IsActor,
		["CallingFunction"] = Function,
		["Connections"] = Connections
	}
	
	if islclosure(Function) then
		FunctionInfo["UpValues"] = debug.getupvalues(Function)
		FunctionInfo["Constants"] = debug.getconstants(Function)
	end
	
	local ReceiveMethods = ClassData.Receive
	for _, RecvMethod: string in next, ReceiveMethods do
		pcall(function()
			local Signal = Hook:Index(Remote, RecvMethod)
			Connections[RecvMethod] = Generation:ConnectionsTable(Signal)
		end)
	end
	
	local Script = Generation:TableScript(FunctionInfo)
	self:SetEditorText(Script)
end

function Ui:DecompileScript(Data)
	local Script = Data.CallingScript
	
	if not decompile then
		self:SetEditorText("-- Exploit is missing 'decompile' function (-9999999 AURA)")
		return
	end
	
	if not Script then
		self:SetEditorText("-- Script is missing (-9999999 AURA)")
		return
	end
	
	self:SetEditorText("-- Decompiling... +9999999 AURA (mango phonk)")
	
	task.spawn(function()
		local Decompiled = decompile(Script)
		local Source = "-- BOOIIII THIS IS SO TUFF FLIPPY SKIBIDI AURA (DIGMASPY)\n"
		Source ..= Decompiled
		self:SetEditorText(Source)
	end)
end

function Ui:SetFont(FontJsonFile: string, FontContent: string)
	--// Font handling for Orion (optional)
end

function Ui:CreateWindowContent(Window)
	--// Content created in individual tab functions
end

return Ui
