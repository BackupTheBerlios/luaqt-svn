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
	else
		local slot = LuaSlot:new(rcv_instance, method, unpack(arg))
		if type(signal) == 'string' then
			-- qt signal, lua slot
			local signal_pars = LuaQt.normalize_signal(signal)
			if not signal_pars then return nil end
			local obj = LuaQt.get_q_object(signal_pars, sender_instance)
			slot.connection = obj:connect_signal(sender_instance, signal, slot, signal_pars)
		else
			-- sigc signal, lua slot
			local handler = (rcv_instance and rcv_instance.signal_handler) or self.signal_handler or global_signal_handler
			local connection = handler:connect_signal(signal, tolua.type(signal), slot)
			slot.connection = connection
		end
		return slot.connection
	end
end

class.BaseClass.connect = LuaQt.global_connect
class.BaseClass.connect_signal = LuaQt.global_connect

function LuaQt.copy_args(args)

	-- used to avoid modifying the arg list
	if not args then return nil end

	local r = {}
	for k,v in args do
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
		local args = LuaQt.copy_args(tree.args) or {}
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
				args = LuaQt.copy_args(v)
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

function LuaQt.register_signal_handler(handler)

	LuaQt.signal_handlers = LuaQt.signal_handlers or {}
	table.insert(LuaQt.signal_handlers, handler)
end

function LuaQt.get_q_object(parameters, parent)

	if not LuaQt.signal_handlers then
		return nil
	end

	local obj
	for k,v in ipairs(LuaQt.signal_handlers) do

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

function join_tables(t1, t2)

	for k,v in ipairs(t2) do
		table.insert(t1, v)
	end
end

class "LuaSlot"

function LuaSlot:__call(...)

	if self.bindn > 0 then
		join_tables(arg, self.bind)
	end

	if self.static then
		if not self.method then
			return nil
		end
		return self.method(unpack(arg))
	else
		local inst = self.instance.p
		if inst then
			return self.instance.m(inst, unpack(arg))
		else
			if self.connection then
				self.connection:disconnect()
				return nil
			end
		end
	end
end

LuaSlot.call = LuaSlot.__call
weak_val_mt = {__mode = 'v'}

function LuaSlot:__init__(rcv_instance, method, ...)
	self.bind = arg
	self.bindn = table.getn(arg)
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
	if self.args == -1 or arg.n == self.args then
		self:call_internal(arg)
	else
		local list
		for i=1,self.args do
			list[i] = arg[i]
		end
		self:call_internal(list)
	end
end

LuaSignal.emit = LuaSignal.__call

function LuaSignal:call_internal(arg_list)

	if arg_list.n > 0 then
		for k,v in self.slot_list do
			if v.rep > 1 then
				for i=1,v.rep do
					v.slot(unpack(arg_list))
				end
			else
				v.slot(unpack(arg_list))
			end
		end
	else
		for k,v in self.slot_list do
			if v.rep > 1 then
				for i=1,v.rep do
					v.slot()
				end
			else
				v.slot()
			end
		end
	end
end

function LuaSignal:connect(p_slot)

	if not p_slot then return end

	local st = self.slot_list[p_slot] or {rep=0, slot = p_slot}
	st.rep = st.rep +1
	self.slot_list[p_slot] = st

	return LuaConnection:new(self, p_slot)
end

function LuaSignal:remove(slot)

	if not slot_list[slot] then return end

	local st = slot_list[slot]
	st.rep = st.rep -1
	if st.rep <= 0 then slot_list[slot] = nil end
end

function LuaSignal:__init__(args)
	-- nothing?
	self.args = args or -1
	if self.args < -1 then self.args = -1 end
	self.slot_list = {}
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

