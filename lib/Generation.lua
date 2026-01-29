local Generation = {}

type table = {
	[any]: any
}

--// Libraries (loaded in Init)
local ParserModule = nil

--// Modules
local Config
local Hook

local ThisScript = script

function Generation:LoadParser()
	if ParserModule then return true end
	
	local Success, Result = pcall(function()
		local Content = game:HttpGet('https://raw.githubusercontent.com/depthso/Roblox-parser/refs/heads/main/main.lua')
		return loadstring(Content)()
	end)
	
	if not Success then
		warn("[DigmaSpy] Failed to load Parser: " .. tostring(Result))
		return false
	end
	
	ParserModule = Result
	
	--// Parser setup
	function ParserModule:Import(Name: string)
		local Url = `{self.ImportUrl}/{Name}.lua`
		return loadstring(game:HttpGet(Url))()
	end
	ParserModule:Load()
	
	return true
end

function Generation:Init(Configuration: table)
    local Modules = Configuration.Modules

	--// Modules
	Config = Modules.Config
	Hook = Modules.Hook
	
	--// Load Parser Module
	self:LoadParser()
end

function Generation:SetSwapsCallback(Callback: (Interface: table) -> ())
	self.SwapsCallback = Callback
end

function Generation:GetBase(Module): string
	local Code = "-- Generated with DigmaSpy BOIIIIIIIII (+9999999 AURA)\n\n"

	--// Generate variables code
	Code ..= Module.Parser:MakeVariableCode({
		"Services", "Variables", "Remote"
	})

	return Code
end

function Generation:GetSwaps()
	local Func = self.SwapsCallback
	local Swaps = {}

	local Interface = {}
	function Interface:AddSwap(Object: Instance, Data: table)
		if not Object then return end
		Swaps[Object] = Data
	end

	--// Invoke GetSwaps function
	Func(Interface)

	return Swaps
end

function Generation:PickVariableName()
	local Names = Config.VariableNames
	return Names[math.random(1, #Names)]
end

function Generation:NewParser()
	--// Check if parser loaded
	if not self:LoadParser() then
		warn("[DigmaSpy] Parser module not loaded!")
		return nil
	end
	
	local VariableName = self:PickVariableName()

	--// Swaps
	local Swaps = self:GetSwaps()

	--// Load parser module
	local Success, Module = pcall(function()
		return ParserModule:New({
			VariableBase = VariableName,
			Swaps = Swaps,
			IndexFunc = function(...)
				return Hook:Index(...)
			end,
		})
	end)
	
	if not Success then
		warn("[DigmaSpy] Failed to create parser: " .. tostring(Module))
		return nil
	end

	return Module
end

type RemoteScript = {
	Remote: Instance,
	IsReceive: boolean?,
	Args: table,
	Method: string
}
function Generation:RemoteScript(Module, Data: RemoteScript): string
	local Success, Result = pcall(function()
		local Remote = Data.Remote
		local IsReceive = Data.IsReceive
		local Args = Data.Args
		local Method = Data.Method

		local ClassName = Hook:Index(Remote, "ClassName")
		local IsNilParent = Hook:Index(Remote, "Parent") == nil
		
		local Variables = Module.Variables
		local Formatter = Module.Formatter
		local Parser = Module.Parser
		
		--// Pre-render variables
		Variables:PrerenderVariables(Args, {"Instance"})

		--// Parse arguments
		local ParsedArgs, ItemsCount = Parser:ParseTableIntoString({
			NoBrackets = true,
			Table = Args
		})

		--// Create remote variable
		local RemoteVariable = Variables:MakeVariable({
			Value = Formatter:Format(Remote, {
				NoVariableCreate = true
			}),
			Comment = IsNilParent and "Remote parent is nil" or ClassName,
			Lookup = Remote,
			Name = Formatter:MakeName(Remote), --ClassName,
			Class = "Remote"
		})

		--// Make code
		local Code = self:GetBase(Module)
		
		--// Firesignal script for client recieves
		if IsReceive then
			local Second = ItemsCount == 0 and "" or `, {ParsedArgs}`
			local Signal = `{RemoteVariable}.{Method}`

			Code ..= `\n-- This data was received from the server`
			Code ..= `\nfiresignal({Signal}{Second})`
			return Code
		end
		
		--// Remote invoke script
		Code ..= `\n{RemoteVariable}:{Method}({ParsedArgs})`
		return Code
	end)
	
	if not Success then
		warn("[DigmaSpy RemoteScript Error] " .. tostring(Result))
		return "-- Error generating script (-9999999 AURA)"
	end
	
	return Result
end

function Generation:ConnectionsTable(Signal: RBXScriptSignal): table
	local Success, Result = pcall(function()
		local Connections = getconnections(Signal)
		local DataArray = {}

		for _, Connection in next, Connections do
			local Function = Connection.Function
			local Script = rawget(getfenv(Function), "script")

			--// Skip if self
			if Script == ThisScript then continue end

			--// Connection data
			local Data = {
				Function = Function,
				State = Connection.State,
				Script = Script
			}

			table.insert(DataArray, Data)
		end

		return DataArray
	end)
	
	if not Success then
		warn("[DigmaSpy ConnectionsTable Error] " .. tostring(Result))
		return {}
	end
	
	return Result
end

function Generation:TableScript(Table: table)
	local Success, Result = pcall(function()
		local Module = self:NewParser()
		
		--// Check if parser created
		if not Module then
			return "-- Parser failed to load (-9999999 AURA)"
		end

		--// Pre-render variables
		Module.Variables:PrerenderVariables(Table, {"Instance"})

		--// Parse arguments
		local ParsedTable = Module.Parser:ParseTableIntoString({
			Table = Table
		})

		--// Generate script
		local Code = self:GetBase(Module)
		Code ..= `\nreturn {ParsedTable}`

		return Code
	end)
	
	if not Success then
		warn("[DigmaSpy TableScript Error] " .. tostring(Result))
		return "-- Error generating table script (-9999999 AURA)"
	end
	
	return Result
end

return Generation
