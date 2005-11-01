local f,oe,ce = loadlib("luasocket.dll", "luaopen_lsocket")

if not f then
	print("Error opening luasocket: "..oe)
	exit(1)
end
f()


function load_module(mod)

	print("Loading module "..mod)
	--local f, oe, ce = loadlib("./liblua_qt_"..mod..".so", "tolua_lua_qt_"..mod.."_open")
	local f, oe, ce = loadlib("./lua_qt_"..mod..".dll", "tolua_lua_qt_"..mod.."_open")
	if not f then
		error(oe)
	end

	f()
end


if not LuaQt then
	load_module("Core")
	load_module("Gui")
	load_module("3Support")
end

print(tolua.type(tolua))

win32 = true

q_app = QApplication:new(LuaQt.argc, LuaQt.argv)

require "pop3_browse.lua"

return QApplication:exec()


