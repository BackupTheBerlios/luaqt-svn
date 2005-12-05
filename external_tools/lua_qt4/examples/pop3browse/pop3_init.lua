if not LuaQt then
	
	package.cpath = "./lib?.so;"..package.cpath

	require "lua_qt_Core"
	require "lua_qt_Gui"
	require "lua_qt_3Support"
end

q_app = QApplication:new(LuaQt.argc, LuaQt.argv)

require "pop3_browse"

return QApplication:exec()
