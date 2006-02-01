local class = class or {} -- the module

class._global_objects = {}

local BaseClass = class.BaseClass or {[".classname"] = "BaseClass"}
BaseClass.__index = BaseClass

local function get_arg(...)

	return {n=select("#", ...), ...}
end

function class.create(self, obj, base)

	local o = _G[obj] or {}
	o['.classname'] = obj
	o.__index = o
	if type(base) == 'string' then
		base = class._global_objects[base]
	end

	if string.find(tolua.type(base), "^class ") then
		o['.tolua_base'] = base
		base = nil
		o.__alloc__ = class.alloc_tolua_base
	end

	base = base or BaseClass

	setmetatable(o, base)

	_G[obj] = o
	class._global_objects[obj] = o
end

function class.alloc_tolua_base(self, ...)

	return self['.tolua_base']:new(...)
end

function class.instance_from_script(p_script, page)
	local obj = require(p_script)
	local n = obj:new(page)

	return n
end

function BaseClass.new(self, ...)

	local o, t

	--[[
-- 	if self.__alloc__ then
-- 		o = self:__alloc__(...)
-- 		if type(o) == 'table' then
-- 			t = o
-- 		else
-- 			t = {}
-- 			tolua.setpeer(o, t)
-- 			if o.tolua__set_instance then
-- 				o:tolua__set_instance(o)
-- 			end
-- 		end
-- 	else
	--]]
		t = {}
		o = t
	--end

	setmetatable(t, self)

	local arg = get_arg(...)
	o = class.init_object(self, o, arg) or o
	--o:__init__(unpack(arg))

	return o
end

function class.base__index(self, key)

	local v = rawget(self, key)
	if v ~= nil then
		return v
	end
	v = getmetatable(self)[key]
	if v ~= nil then
		return v
	end
	v = rawget(self, ".c_instance")
	if v ~= nil then
		return v[key]
	end
end

function BaseClass:set_c_instance(ins)

	if ins.tolua__set_instance then

		ins:tolua__set_instance(self)
	end

	--self[".c_instance"] = ins
	tolua.inherit(self, ins)

	getmetatable(self).__index = class.base__index
end

function class.init_object(mt, obj, arg)

	local parg = arg
	local pa = rawget(mt, "__parent_args__")
	if pa then
		parg = get_arg( pa(obj, unpack(arg, 1, arg.n)) )
	end

	local ip = rawget(mt, "__init_parent__")
	if ip then
		ip(obj, parg, mt)
	else
		ip = rawget(BaseClass, "__init_parent__")
		obj = ip(obj, parg, mt) or obj
	end

	local init = rawget(mt, "__init__")

	if init then
		init(obj, unpack(arg, 1, arg.n))
	end

	return obj
end

function BaseClass:__init_parent__(arg, mt)

	local t = getmetatable(mt)
	if t then
		if t == BaseClass then
			if self.__alloc__ then
				local o = self:__alloc__(unpack(arg, 1, arg.n))
				if type(o) ~= 'table' then
					tolua.setpeer(o, self)
					if o.tolua__set_instance then
						o:tolua__set_instance(o)
					end
				end
				self = o
			end
		else
			self = class.init_object(t, self, arg)
		end
	end
	return self
end

function BaseClass:__init__()

end

class.BaseClass = BaseClass
setmetatable(class, {__call = class.create})

_G.class = class

return class
