
local plr = owner
--plr.Character.Humanoid.WalkSpeed = 0; plr.Character.Humanoid.JumpPower = 0

local screen = Instance.new("Part", script)
screen.Anchored = true
screen.Size = Vector3.new(256, 120)*4 / (30*4)
screen.CFrame = plr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 6, -4) * CFrame.Angles(0, math.rad(180), 0)
screen.CanCollide = false
screen.Transparency = 1

local surface = Instance.new("SurfaceGui", screen)
surface.LightInfluence = 0
surface.ClipsDescendants = true
surface.CanvasSize = Vector2.new(256, 120)*4

-- tbh just legacy stuff lol --

local bg = Instance.new("Frame", surface)
bg.BackgroundColor3 = Color3.new(.1, .1, .1)
bg.BorderSizePixel = 0
bg.Size = UDim2.new(1, 0, 1, 0)

-------------------------------

local TweenS = game:service("TweenService")
--------------------------------------------------------------------
-- Utils
local Utils = {}
function Utils:Create(InstData, Props)
	local Obj = Instance.new(InstData[1], InstData[2])
	for k, v in pairs (Props) do
		Obj[k] = v
	end; if Obj:IsA("ImageLabel") or Obj:IsA("ImageButton") then
		Obj.ResampleMode = "Pixelated"
	end
	return Obj
end
--------------------------------------------------------------------
-- DECIDING STUFF FOR LANGUAGE:
-- float, string, userd, any will all replace "local"
-- (not sure yet) "global" might replace not using local

-- "0f" is the number 0
-- fromenv will run a lua function
--

local ymscript = {}

ymscript.instructs = {
	fromenv = function(self, code)
		local func = string.split(code, "(")
		
		local funct = self.env[func[1]]
		if not funct and string.find(func[1], "%.") then -- it's trying to index a table
			local indexs = string.split(func[1], ".")
			local indexing = self.env[indexs[1]]
			if not indexing then error("Trying to call something that doesnt exist (Line " ..tostring(self.online) ..")") end
			for i,v in indexs do
				if i > 1 then
					if typeof(indexing) == "table" and indexing[v] then
						indexing = indexing[v]
					end
				end
			end
			funct = indexing
		end
		
		if funct then
			-- get args
			local arglist = func[2]
			if not arglist then error("Invalid input for fromenv (Line " ..tostring(self.online) ..")") end
			local args = string.split(arglist, ",") -- arglist:gsub("%s+", "")
			args[#args] = args[#args]:sub(1, #args[#args]-1)
			
			for i,v in args do
				v = self:noWhitespace(v)
				
				if self:isString(v) then
					-- fine
				elseif self:isInt(v) then
					-- get rid of the f
					args[i] = v:sub(1, #v-1)
				elseif self:isBool(v) then
					args[i] = v == "true"
				else
					-- check from venv
					if self.CENV[v] then
						args[i] = v
						--print(typeof(v), typeof(self.CENV[v]))
						if type(self.CENV[v]) ~= "userdata" then
							args[i] = self.CENV[v]
						end
						--if not self.outenv[v] then self.outenv[v] = self.CENV[v] end
					end
				end
			end
			
			local f = loadstring("return " ..func[1] .."(" ..table.concat(args, ",") ..")")
			setfenv(f, self.outenv)
			--print(self.CENV, self.CENV.envreturn, f())
			local funced = f()
			self.CENV.envreturn = funced
			self.outenv.envreturn = funced
		end
	end,
	["function"] = function(self, code)
		code = code:gsub(" ", "")
		
		local brack = string.find(code, "%(")
		if brack and code:sub(#code-1, #code-1) == ")" then
			
			local arglist = code:sub(brack+1, #code-2)
			local args = string.split(arglist, ",") -- arglist:gsub("%s+", "")
			
			--local args = string.split(arglist, ",") -- arglist:gsub("%s+", "")
			--args[#args] = args[#args]:sub(1, #args[#args]-1)
			
			self.infunc = code:sub(1, brack-1)
			self.CENV[self.infunc] = {code = {}, args = args, line = self.online}
		else
			error("Expected '()' after function name, got <eof> (Line " ..tostring(self.online) ..")")
		end
	end
}

-- detecting types --
function ymscript:stringChar(a)
	return a == '"' or a == "'" or a == "[[" or a == "]]" or a == "[==[" or a == "]==]"
end
function ymscript:isString(part)
	return (self:stringChar(part:sub(1, 1)) or self:stringChar(part:sub(1, 2))) and (self:stringChar(#part, #part) or self:stringChar(#part-1, #part))
end
function ymscript:isInt(part)
	return part:sub(#part, #part) == "f" and tonumber(part:sub(1, #part-1))
end
function ymscript:isBool(part)
	return part == "true" or part == "false"
end
---------------------
-- args stuff --
function ymscript:noWhitespace(v)
	local instr = false
	local new = ""
	for i = 1,#v do
		local l = v:sub(i, i)
		if self:stringChar(l) then
			instr = not instr
		end
		if not string.match(l, "%s+") or instr then new ..= l end
	end
	
	return new
end
----------------

function ymscript:format(str) -- get rid of whitespace
	local lines = string.gsub(str, "[\n\r]", ";"):gsub("[\n\t]", ""):gsub("; ", ";"):split(";")
	return lines
end

ymscript.infunc = false
function ymscript:interpline(src, env) -- interprets a single line
	local split = src:split(" ")
	
	env = env or self.CENV
	if self.infunc then
		if src == "}" then -- end of func
			self.infunc = nil
		else -- add to func
			table.insert(env[self.infunc].code, src)
		end
	else
		if src:sub(1, 2) == "//" then return end -- check if its a comment
		-- check if instruct
		local instruct = self.instructs[split[1]]
		if instruct then
			instruct(self, src:sub(#split[1]+2))
		else
			-- check if running func
			local brack = string.find(src, "%(")
			if string.find(src, "=") then -- making a new variable?
				src = string.gsub(src, " ", "")
				local equalat = string.find(src, "=")
				local varname = src:sub(1, equalat-1)
				local setTo = src:sub(equalat+1)
				
				if self:isInt(setTo) then
					setTo = tonumber(setTo:sub(1, #setTo-1))
				elseif self:isString(setTo) then
					setTo = setTo:sub(2, #setTo-1)
				elseif self:isBool(setTo) then
					setTo = setTo == "true"
				elseif self.CENV[setTo] then
					setTo = self.CENV[setTo]
				else -- my code here is a poop. idk what i was doing. its meant to work with stuff like vector3.new (SETS VARIABLES)
					local funct = self.CENV[setTo]
					local functname = ""
					if string.match(setTo, "%.") then
						--print(setTo, string.match(setTo, "%."))
						local indexs = string.split(setTo, ".")
						funct = self.CENV[indexs[1]]
						functname = setTo
						if #indexs > 1 then
							functname = ""
							for i,v in indexs do
								if i then
									local brack = string.find(v, "%(")
									if brack then
										--print(brack, #v, v:sub(1, brack-1), funct, indexs[1])
										local v = v:sub(1, brack-1)
										functname ..= v ..(i < #indexs and "." or "")
										if funct[v] then funct = funct[v] end
									else
										functname ..= v .."."
										if funct[v:sub(1)] then funct = funct[v:sub(1)] end
									end;
								end
							end
						end
					end
					if funct and typeof(funct) == "function" then
						local brack = string.find(src, "%(")
						local args
						if not brack then -- not trying to call
						if string.match(varname, "%.") then
							local indexs = string.split(varname, ".")
							funct = self.CENV[indexs[1]]
							for i,v in indexs do
								if i > 1 then
									local brack = string.find(v, "%(")
									if brack then
										--print(brack, #v, v:sub(1, brack-1), funct, indexs[1])
										local v = v:sub(1, brack-1)
										if funct[v] then funct = funct[v] end
									else
										if i == #indexs then
											if funct[v] then funct[v] = setTo end
										else
											if funct[v] then funct = funct[v:sub(1)] end
										end
									end
								end
							end
							return
						end
						return
						else
						local arglist = src:sub(brack+1, #src-1)
						args = string.split(arglist, ",")
						
						--local mess = string.find(arglist, "")
						
						for i,v in args do -- add the args
							v = self:noWhitespace(v)
							args[i] = v
							if self:isString(v) then
								-- fine
							elseif self:isInt(v) then
								-- get rid of the f
								args[i] = v:sub(1, #v-1)
							elseif self:isBool(v) then
								v = v == "true"
							else
								-- check from venv
								if self.CENV[v] then
									args[i] = v
									--print(typeof(v), typeof(self.CENV[v]))
									if type(self.CENV[v]) ~= "userdata" then
										args[i] = self.CENV[v]
									end
									--if not self.outenv[v] then self.outenv[v] = self.CENV[v] end
								end
							end
						end
						end
						
						local f = loadstring("return " ..functname .."(" ..table.concat(args, ",") ..")")
						setfenv(f, self.outenv)
						setTo = f()
						if string.match(varname, "%.") then
							local indexs = string.split(varname, ".")
							funct = self.CENV[indexs[1]]
							for i,v in indexs do
								if i > 1 then
									local brack = string.find(v, "%(")
									if brack then
										--print(brack, #v, v:sub(1, brack-1), funct, indexs[1])
										local v = v:sub(1, brack-1)
										if funct[v] then funct = funct[v] end
									else
										if i == #indexs then
											if funct[v] then funct[v] = setTo end
										else
											if funct[v] then funct = funct[v:sub(1)] end
										end
									end
								end
							end
							return
						end
					end
					if not funct then
						error("Invalid type when trying to set variable (Line " ..tostring(self.online) ..")")
					end
				end
				
				self.CENV[varname] = setTo
				self.outenv[varname] = setTo
			elseif src:sub(#src, #src) == ")" and brack then -- calling a function woohoo woohoo
				local funct = self.CENV[src:sub(1, brack-1)]
				if funct then
					local arglist = src:sub(brack+1, #src-1)
					local args = string.split(arglist, ",")
					
					local scope = {}
					for i,v in self.CENV do
						scope[i] = v
					end
					for i,v in funct.args do -- add the args
						v = self:noWhitespace(v)
						if not self:isString(v) and not self:isInt(v) and not self:isBool(v) then
							-- check from venv
							if self.CENV[v] then
								args[i] = v
								--print(typeof(v), typeof(self.CENV[v]))
								if type(self.CENV[v]) ~= "userdata" then
									args[i] = self.CENV[v]
								end
								--if not self.outenv[v] then self.outenv[v] = self.CENV[v] end
							end
						end
						scope[v] = args[i]
					end
					
					local outenv = self.CENV
					self.CENV = scope
					-- run all the lines in the func (and change line for debugging)
					local wasline = self.online
					self.online = funct.line
					for i,v in funct.code do
						self:interpline(v, scope)
					end; self.CENV = outenv
					self.online = wasline
					--print(self.CENV.Instance)
				else
					error("Attempted to call a function that doesn't exist (Line " ..tostring(self.online) ..")")
				end
			end
		end
	end
end

function ymscript:loadstring(source, env, keepenv)
	local lines = self:format(source)
	if not self.env or not keepenv then
	local env = env or getfenv()
	self.env = env
	self.online = 0 -- line of error (for debugging)
	
	self.venv = {["workspace"] = workspace, ["game"] = game, Vector3 = Vector3, CFrame = CFrame, UDim2 = UDim2, UDim = UDim, Vector2 = Vector2, Color3 = Color3, BrickColor = BrickColor} -- virtual env
	self.CENV = self.venv -- current env

	self.outenv = getfenv(0) -- environment for output stuff (so you can change stuff like print, warn and error)
	for i,v in self.outenv do
		self.venv[i] = v
	end
	end
	if self.setoutenv then self:setoutenv() end
	
	for i,v in lines do
		ymscript:interpline(v)
		self.online += 1
	end
end

--[==[
print(ymscript:format([[
print("yo")
function whatup()
	return "mydudes"
end
]]))]==]

--[==[
ymscript:loadstring([[
	function cool() {
		fromenv print("que guay!")
	}
	
	fromenv loadstring("print(1 + 1)")
	fromenv print("i", "said", "hey", "whats", "going", "on", 0f)
	function OMGTHISWILLERROR {
		
	}
]]) -- this code should do the "print" function from the env
]==]
local code = [[
	function amazeballs(hi) {
		fromenv print(hi)
	}
	
	amazeballs("and i say heyayayayayaya")
	fromenv wait(1f)
	amazeballs("i think it work")
]]

code = [[
	fromenv task.wait(1f)
	fromenv print("yo")
	
	function gaming(a, b) {
		fromenv print(a, b)
		fromenv task.wait(.5f)
		//gaming(a, b) <-- would create a loop
	}
	
	c = 0f
	fromenv print(c)
	
	fromenv Instance.new("Part", script)
	//fromenv print(envreturn)
	//fromenv wait(1f)
	envreturn.Size = Vector3.new(1f, 1f, 1f)
	vec = Vector3
	envreturn.Position = vec.new(0, 20f, 0)
]]

local main = Utils:Create({"TextBox", bg}, {
	TextEditable = false,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	TextSize = 30,
	Font = "RobotoMono",
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = "Left",
	TextYAlignment = "Top",
	Text = code
})

--[[
local prins = 0
ymscript.outenv.print = function(a)
	if prins > 5 then
		main:ClearAllChildren(); prins = 0
	end
	Utils:Create({"TextBox", main}, {
		TextEditable = false,
		Size = UDim2.new(1, 0, 0, 25),
		BackgroundTransparency = 1,
		TextSize = 15,
		Font = "RobotoMono",
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = "Left",
		Text = a,
		Position = UDim2.new(0, 0, 1, prins * 25)
	})
	prins += 1
end
]]

ymscript:loadstring(code)
