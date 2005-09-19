--if flags.n == 'lua_qt_Gui' then
--	do_nothing = true
--end

function parser_hook(s)

	local ret = nil

	local protected
	local b,e = string.find(s, "^%s*protected%s+")
	if b then
		protected = true
		s = string.sub(s, e+1)
		-- at least remove 'protected'

		if do_nothing then

			-- remove protected stuff
			s = string.gsub(s, "^[^;]*", "")
		end

		ret = s
	end

	if do_nothing then

		return ret
	end

	local b,e,decl,arg = string.find(s, "^%s*virtual%s+([^%({~]*)(%b())")
	local const
	if b then
		local ret = string.sub(s, e+1)
		if string.find(ret, "^%s*const") then
			const = "const"
			ret = string.gsub(ret, "^%s*const", "")
		end
		local purev = false
		if string.find(ret, "^%s*=%s*0") then
			purev = true
			ret = string.gsub(ret, "^%s*=%s*0", "")
		end
		ret = string.gsub(ret, "^%s*%b{}", "")

		local func = Function(decl, arg, const)
		func.pure_virtual = purev
		func.protected = protected
		func.original_sig = decl

		local curflags = classContainer.curr.flags
		if not curflags.virtual_class then

			curflags.virtual_class = VirtualClass()
		end
		curflags.virtual_class:add(func)
		curflags.pure_virtual = curflags.pure_virtual or purev

		return ret
	end

	return ret
end


-- override the functions 'supcode' and 'register' from 'classFunction'
local old_supcode = classFunction.supcode

function classFunction:supcode(lc)

	if self.protected then
		-- do nothing
		return
	end

	old_supcode(self, lc)
end

local old_register = classFunction.register

function classFunction:register()

	if self.protected then

		-- do nothing
		return
	end

	old_register(self)
end

-- class VirtualClass
classVirtualClass = {
 classtype = 'class',
 name = '',
 base = '',
 type = '',
 btype = '',
 ctype = '',
}
classVirtualClass.__index = classVirtualClass
setmetatable(classVirtualClass,classClass)

function classVirtualClass:add(f)

	local parent = classContainer.curr
	pop()

	table.insert(self.methods, {f=f})

	local name,sig

	if f.name == 'new' and not self.flags.parent_object.flags.pure_virtual then

		name = self.name
	elseif f.name == 'delete' then
		name = '~'..self.name
	else
		if f.protected and (not f.pure_virtual) then
			name = f.mod.." "..f.type..f.ptr.." "..self.flags.parent_object.lname.."__"..f.name
		end
	end

	if name then
		sig = name..self:get_arg_list(f, true)..";\n"
		push(self)
		sig = preprocess(sig)
		self:parse(sig)
		pop()
	end

	push(parent)
end

function preprocess(sig)

	sig = gsub(sig,"([^%w_])void%s*%*","%1_userdata ") -- substitute 'void*'
	sig = gsub(sig,"([^%w_])void%s*%*","%1_userdata ") -- substitute 'void*'
	sig = gsub(sig,"([^%w_])char%s*%*","%1_cstring ")  -- substitute 'char*'
	sig = gsub(sig,"([^%w_])lua_State%s*%*","%1_lstate ")  -- substitute 'lua_State*'

	return sig
end

function classVirtualClass:get_arg_list(f, decl)

	local ret = ""
	local sep = ""
	local i=1
	while f.args[i] do

		local arg = f.args[i]
		if decl then
			local ptr
			if arg.ret ~= '' then
				ptr = arg.ret
			else
				ptr = arg.ptr
			end
			local def = ""
			if arg.def and arg.def ~= "" then

				def = " = "..arg.def
			end
			ret = ret..sep..arg.mod.." "..arg.type..ptr.." "..arg.name..def
		else
			ret = ret..sep..arg.name
		end

		sep = ","
		i = i+1
	end

	return "("..ret..")"
end

function classVirtualClass:supcode()

	-- no pure virtual classes for now
	if self.flags.parent_object.flags.pure_virtual then
		output('#if (__GNUC__ == 4) || (__GNUC__ > 4 ) // I hope this works on Microsoft Visual studio .net server 2003 XP Compiler\n')
	end

	output("class "..self.name.." : public "..self.btype..", public ToluaBase {")

	output("public:\n")

	local i=1
	while self.flags.parent_object[i] do

		local v = self.flags.parent_object[i]
		if getmetatable(v) == classFunction and (v.name == 'new' or v.name == 'delete') then

			self:add(v)
		end

		i = i+1
	end

	self:output_methods(self.btype)
	self:output_parent_methods()

	-- no constructor for pure virtual classes
	if not self.flags.parent_object.flags.pure_virtual then

		self:output_contructors()
	end

	output("};\n\n")

	classClass.supcode(self)

	if self.flags.parent_object.flags.pure_virtual then
		output('#endif // __GNUC__ >= 4\n')
	end
end

function classVirtualClass:register()

	-- no pure virtual classes for now
	if self.flags.parent_object.flags.pure_virtual then
		output('#if (__GNUC__ == 4) || (__GNUC__ > 4 )\n')
	end

	classClass.register(self)

	if self.flags.parent_object.flags.pure_virtual then
		output('#endif // __GNUC__ >= 4\n')
	end
end


--function classVirtualClass:requirecollection(_c)
--	if self.flags.parent_object.flags.pure_virtual then
--		return false
--	end
--	return classClass.requirecollection(self, _c)
--end

function classVirtualClass:output_parent_methods()

	for k,v in ipairs(self.methods) do

		if v.f.protected and (not v.f.pure_virtual) and v.f.name ~= 'new' and v.f.name ~= 'delete' then

			local rettype = v.f.mod.." "..v.f.type..v.f.ptr.." "
			local parent_name = rettype..self.btype.."__"..v.f.name

			local par_list = self:get_arg_list(v.f, true)
			local var_list = self:get_arg_list(v.f, false)

			-- the parent's virtual function
			output("\t"..parent_name..par_list.." {")

			output("\t\treturn (",rettype,")"..self.btype.."::"..v.f.name..var_list..";")
			output("\t};")
		end
	end
end

function classVirtualClass:output_methods(btype)

	for k,v in ipairs(self.methods) do

		if v.f.name ~= 'new' and v.f.name ~= 'delete' then

			self:output_method(v.f, btype)
		end
	end
	output("\n")
end

function classVirtualClass:output_contructors()

	for k,v in ipairs(self.methods) do

		if v.f.name == 'new' then

			local par_list = self:get_arg_list(v.f, true)
			local var_list = self:get_arg_list(v.f, false)

			output("\t",self.name,par_list,":",self.btype,var_list,"{};")
		end
	end
end

function classVirtualClass:output_method(f, btype)

	local ptr
	if f.ret ~= '' then
		ptr = f.ret
	else
		ptr = f.ptr
	end

	local rettype = f.mod.." "..f.type..f.ptr.." "
	local par_list = self:get_arg_list(f, true)
	local var_list = self:get_arg_list(f, false)

	if string.find(rettype, "%s*LuaQtGenericFlags%s*") then

		_,_,rettype = string.find(f.original_sig, "^%s*([^%s]+)%s+")
	end

	-- the caller of the lua method
	output("\t"..rettype.." "..f.name..par_list..f.const.." {")
	local fn = f.cname
	if f.protected then
		fn = "NULL"
	end
	output('\t\tif (push_method("',f.lname,'", ',fn,')) {')

	if f.type ~= 'void' then
		output("\t\t\tint top = lua_gettop(lua_state)-2;")
	end

	-- push the parameters
	local argn = 0
	for i,arg in ipairs(f.args) do
		if arg.type ~= 'void' then
			local t,ct = isbasic(arg.type)
			if t and t ~= '' then
				if arg.ret == "*" then
					t = 'userdata'
					ct = 'void*'
				end
				output("\t\t\ttolua_push"..t.."(lua_state, ("..ct..")"..arg.name..");");
			else
				local m = arg.ptr
				if m and m~= "" then
					if m == "*" then m = "" end
					output("\t\t\ttolua_pushusertype(lua_state, (void*)"..m..arg.name..", \""..arg.type.."\");")
				else
					output("\t\t\tvoid* tolua_obj = (void*)new "..arg.type.."("..arg.name..");\n")
					output('\t\t\ttolua_pushusertype_and_takeownership(lua_state, tolua_obj, "'..arg.type..'");\n')
				end
			end
			argn = argn+1
		end
	end

	-- call the function
	output("\t\t\tToluaBase::dbcall(lua_state, ",argn+1,", ")

	-- return value
	if f.type ~= 'void' then
		output("1);")

		local t,ct = isbasic(f.type)
		if t and t ~= '' then
			output("\t\t\treturn ("..rettype..")tolua_to"..t.."(lua_state, top, 0);")
		else

			local mod = ""
			if f.ptr ~= "*" then
				mod = "*("..f.type.."*)"
			end

			output("\t\t\treturn ("..rettype..")"..mod.."tolua_tousertype(lua_state, top, 0);")
		end
	else
		output("0);")
	end

	-- handle non-implemeted function
	output("\t\t} else {")

	if f.pure_virtual then

		output('\t\t\tif (lua_state)')
		output('\t\t\t\ttolua_error(lua_state, "pure-virtual method '..btype.."::"..f.name..' not implemented.", NULL);')
		output('\t\t\telse {')
		output('\t\t\t\tfprintf(stderr, "pure-virtual method '..btype.."::"..f.name..' called with no lua_state. Aborting");')
		output('\t\t\t\t::abort();')
		output('\t\t\t};')
	else

		output('\t\t\treturn (',rettype,')',btype,'::',f.name,var_list,';')
	end

	output("\t\t};")

	output("\t};")
end

function VirtualClass()

	local parent = classContainer.curr
	pop()

	local name = "Lua__"..parent.name

	local c = _Class(_Container{name=name, base=parent.name, extra_bases=nil})
	setmetatable(c, classVirtualClass)

	local ft = getnamespace(c.parent)..c.original_name
	append_global_type(ft, c)

	push(parent)

	c.flags.parent_object = parent
	c.methods = {}

	push(c)
	c:parse("\nvoid tolua__set_instance(_lstate L, lua_Object lo);\n")
	pop()

	return c
end





