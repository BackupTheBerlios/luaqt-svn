LuaSlot = {}

function print_traceback(s)
	print(debug.traceback(s))
end

--------------------------------------------- misc stuff ---------------------------------------------

LuaQt = LuaQt or {}

if arg then
	LuaQt:init_args(arg)
end

function LuaQt.global_connect(self, sender_instance, signal, rcv_instance, method, ...)

	if not signal then
		print(debug.traceback("** invalid signal"))
		return
	end
	if type(method) == 'string' then
		-- qt slot
		QObject:connect(sender_instance, "2"..signal, rcv_instance, "1"..method) -- no bind
		return nil
	else
		local ret
		local slot = LuaSlot:new(rcv_instance, method, ...)
		if type(signal) == 'string' then
			-- qt signal, lua slot
			local signal_pars = LuaQt.normalize_signal(signal)
			if not signal_pars then return nil end
			local obj = LuaQt.get_q_object(signal_pars, sender_instance)
			ret = obj:connect_signal(sender_instance, signal, slot, signal_pars)
			slot.connection = ret
			slot:set_connection_collector(ConnectionCollector_LuaQConnection_(ret))
		else
			-- sigc signal, lua slot
			local handler = (rcv_instance and rcv_instance.signal_handler) or self.signal_handler or global_signal_handler
			ret = handler:connect_signal(signal, tolua.type(signal), slot)
			slot.connection = connection
		end
		return ret
	end
end

class.BaseClass.connect = LuaQt.global_connect
class.BaseClass.connect_signal = LuaQt.global_connect

local function copy_args(args)

	-- used to avoid modifying the arg list
	if not args then return nil end

	local r = {}
	for k,v in pairs(args) do
		r[k] = v
	end

	return r
end

function LuaQt.init_tree(parent, tree, container, debug)

	parent_widget = (parent and parent.__main_widget) or parent

	local widget
	if type(tree) == 'string' or ((not tree.type) and (not tree.widget)) then
		tree = LuaQt.get_default_widget(tree)
	end

	if tree.widget then
		widget = LuaQt.init_tree(parent, tree.widget, container, debug)
	else
		if type(tree.type) == 'string' then
			tree.type = _G[tree.type]
		end
		local args = copy_args(tree.args) or {}
		local parent_pos = args.parent_pos or 1
		table.insert(args, parent_pos, parent_widget)
		widget = tree.type:new(unpack(args))
	end

	if debug then
		print("tree: "..tolua.type(widget)..": "..tostring(tree.name))
	end

	if tree.name and container then
		if container[tree.name] then
			if container[tree.name]['.classname'] or (type(container[tree.name]) ~= 'table') then
				container[tree.name] = {container[tree.name]}
			end
			table.insert(container[tree.name], widget)
		else
			container[tree.name] = widget
		end
	end

	if tree.init then
		for k,v in pairs(tree.init) do
			local obj = v[1]
			local args = v.args
			if not args then
				--table.remove(v, 1)
				args = copy_args(v)
				table.remove(args, 1)
			end
			if type(obj) == 'string' then
				if table.getn(args) > 0 then
					widget[obj](widget, unpack(args))
				else
					widget[obj](widget)
				end
			else
				if table.getn(args) > 0 then
					obj(parent, widget, unpack(args))
				else
					obj(parent, widget)
				end
			end
		end
	end

	local child_list = tree.childs or tree
	for k,v in ipairs(child_list) do
		LuaQt.init_tree((widget and widget.__main_widget) or widget, v, container, debug)
	end

	return widget
end

function LuaQt.default__get_default_widget(tree)

	if type(tree) == "string" then
		return {type = QLabel, args={tree, parent_pos=2}}
	end
end

function LuaQt.set_default_widget_func(func)

	LuaQt.get_default_widget = func or LuaQt.default__get_default_widget
end

LuaQt.set_default_widget_func(LuaQt.get_default_widget or nil)

function LuaQt.normalize_signal(signal)

	_,_,signal = string.find(signal, "(%b())")
	if not signal then return nil end
	signal = string.gsub(signal, "%s*,%s*", ",")
	signal = string.gsub(signal, "%s*([%(%)])%s*", "%1")

	return signal
end

local signal_handlers

function LuaQt.register_signal_handler(handler)

	signal_handlers = signal_handlers or {}
	table.insert(signal_handlers, handler)
end

function LuaQt.get_q_object(parameters, parent)
	
	if not signal_handlers then
		return nil
	end

	local obj
	for k,v in ipairs(signal_handlers) do

		obj = v:get_q_object(parameters, parent)
		if obj then
			return obj
		end
	end

	return nil
end

function LuaQt.bw_and(...)
	return LuaQt:and_list(arg)
end

function LuaQt.bw_or(...)
	return LuaQt:or_list(arg)
end

--------------------------------------------- the lua slot ---------------------------------------------

local function get_arg(...)

	return {n=select("#", ...), ...}
end

local function join_tables(t1, t2)

	-- first table needs to have 'n'
	for i=1,t2.n do
		t1[t1.n+i] = v
	end
	t1.n = t1.n + t2.n
end

class "LuaSlot"

function LuaSlot:__call(...)

	local arg = get_arg(...)
	if self.bind.n > 0 then
		join_tables(arg, self.bind)
	end

	if self.static then
		if not self.method then
			return nil
		end
		return self.method(unpack(arg, 1, arg.n))
	else
		local inst = self.instance.p
		if inst then
			return self.instance.m(inst, unpack(arg, 1, arg.n))
		else
			if self.connection then
				self.connection:disconnect()
				return nil
			end
		end
	end
end

function LuaSlot:set_connection_collector(col)

	if self.static then
		return
	end

	local client = self.instance.p
	if not client then return end

	self.collector = {[client] = col}
	setmetatable(self.collector, weak_key_mt)
end

LuaSlot.call = LuaSlot.__call
weak_val_mt = {__mode = 'v'}
weak_key_mt = {__mode = 'k'}

function LuaSlot:__init__(rcv_instance, method, ...)
	self.bind = get_arg(...)
	if rcv_instance then
		self.instance = {p = rcv_instance, m = method}
		setmetatable(self.instance, weak_val_mt)
	else
		self.method = method
		self.static = true
	end
end

--------------------------------------------- the lua signal ---------------------------------------------

class "LuaSignal"

function LuaSignal:__call(...)
	local arg = get_arg(...)
	if self.args == -1 or arg.n == self.args then
		self:call_internal(arg)
	else
		arg.n = self.args
		self:call_internal(arg)
	end
end

LuaSignal.emit = LuaSignal.__call

function LuaSignal:call_internal(arg_list)

	if arg_list.n > 0 then
		for k,v in pairs(self.slot_list) do
			for i=1,v.rep do
				k(unpack(arg_list, 1, arg_list.n))
			end
		end
	else
		for k,v in pairs(self.slot_list) do
			for i=1,v.rep do
				k()
			end
		end
	end
end

function LuaSignal:connect(p_slot)

	if not p_slot then return end

	local key
	if p_slot.static then
		key = self
	else
		key = p_slot.instance.p
	end
	if not key then return end

	local cl = self.client_list[key]
	if not cl then
		cl = {}
		self.client_list[key] = cl
	end
	cl[p_slot] = true

	local st = self.slot_list[p_slot] or {rep=0, slot = p_slot}
	st.rep = st.rep +1
	self.slot_list[p_slot] = st

	return LuaConnection:new(self, p_slot)
end

function LuaSignal:remove(slot)

	if not slot_list[slot] then return end

	local st = slot_list[slot]
	st.rep = st.rep -1

	if st.rep <= 0 then
		slot_list[slot] = nil

		local key = (slot.static and self) or slot.instance.p
		local client = self.client_list[key]
		if client then
			client[slot] = nil
			if not next(client) then
				self.client_list[key] = nil
			end
		end
	end
end

function LuaSignal:__init__(args)
	-- nothing?
	self.args = args or -1
	if self.args < -1 then self.args = -1 end

	self.slot_list = {}
	setmetatable(self.slot_list, weak_val_mt)

	self.client_list = {}
	setmetatable(self.client_list, weak_key_mt)
end

--------------------------------------------- the connection ---------------------------------------------

class "LuaConnection"

function LuaConnection:empty()

	return self.data.signal and self.data.slot
end

function LuaConnection:disconnect()

	if self:empty() then return end

	self.data.signal:remove(self.data.slot)

	self.data.signal, self.data.slot = nil, nil
end

function LuaConnection:__init__(signal, slot)

	self.data = {}
	setmetatable(self.data, weak_val_mt)

	self.data.signal = signal
	self.data.slot = slot
end

