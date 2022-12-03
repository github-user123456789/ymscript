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
						if not self:isString(v) and not self:isInt(v) then
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

function ymscript:loadstring(source, env)
	local lines = self:format(source)
	local env = env or getfenv()
	self.env = env
	self.online = 0 -- line of error (for debugging)
	
	self.venv = {["workspace"] = workspace, ["game"] = game, Vector3 = Vector3, CFrame = CFrame, UDim2 = UDim2, UDim = UDim, Vector2 = Vector2, Color3 = Color3, BrickColor = BrickColor} -- virtual env
	self.CENV = self.venv -- current env

	self.outenv = getfenv(0) -- environment for output stuff (so you can change stuff like print, warn and error)
	for i,v in self.outenv do
		self.venv[i] = v
	end
	if self.setoutenv then self:setoutenv() end
	
	for i,v in lines do
		ymscript:interpline(v)
		self.online += 1
	end
end

return ymscript
