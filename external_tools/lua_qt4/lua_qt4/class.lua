local class = {} -- the module

class._global_objects = {}

local BaseClass = {[".classname"] = "BaseClass"}
BaseClass.__index = BaseClass

function class.create(self, obj, base)

	local o = _G[obj] or {}
	o['.classname'] = obj
	o.__index = o
	if type(base) == 'string' then
		base = class._global_objects[base]
	end

	base = base or BaseClass

	setmetatable(o, base)

	_G[obj] = o
	class._global_objects[obj] = o
end

function class.instance_from_script(p_script, page)
	local obj = require(p_script)
	local n = obj:new(page)

	return n
end

function BaseClass:new(...)
	local o = {}
	setmetatable(o, self)

	class.init_object(self, o, arg)
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

	mt.__init_parent__(obj, arg, mt)
	mt.__init__(obj, unpack(arg))
end

function BaseClass:__init_parent__(arg, mt)

	local t = getmetatable(mt)
	if t then

		if t ~= BaseClass then

			init_object(t, self, arg)
		end
	end

end

function BaseClass:__init__()

end

class.BaseClass = BaseClass
setmetatable(class, {__call = class.create})

_G.class = class

return class
