function load_module(mod)

	print("Loading module "..mod)
	local f, oe, ce = package.loadlib("./liblua_qt_"..mod..".so", "tolua_lua_qt_"..mod.."_open")
	--local f, oe, ce = loadlib("./lua_qt_"..mod..".dll", "tolua_lua_qt_"..mod.."_open")
	if not f then
		error(oe)
	end

	f()
	print"done"
end

print(package.path)
print(package.cpath)
package.cpath = "./lib?.so;"..package.cpath
--load_module("Core")
require "lua_qt_Core"

print("lua_qt handlers is "..tostring(LuaQt.signal_handlers))

local nsg = {}
if not LuaQt.signal_handlers then
	print("new signal_handlers is "..tostring(nsg))
	LuaQt.signal_handlers = nsg
end
table.insert(LuaQt.signal_handlers, new_QtSignalHandler__lua_qt_Core())
print("lua_qt handlers is "..tostring(LuaQt.signal_handlers))

load_module("Gui")

load_module("3Support")
--load_module("Xml")
--load_module("Sql")
--load_module("OpenGL")
--load_module("Network")
--load_module("Designer")
print"1"
require "calculator"
print"2"

app = QApplication:new(LuaQt.argc, LuaQt.argv)
print"3"

--require "lua_qt_helpers.lua"
print"4"

class "Main"
print"5"

function Main:button_pressed()

	self.counter = self.counter +1
	self.label:setText(self.counter)
end

function Main:__delete__()

	print "destroyed"
end

function Main:__init__(parent)

	print("*********** parent on main is "..tostring(parent))

	self:set_c_instance(QMainWindow:new())

	local gui = {

		type = Q3VBox,

		init = {

			{ QMainWindow.setCentralWidget },
		},

		{ type = Q3HBox,

			{ type = QLabel,
				init = {
					{ "setText", "press button!" },
				},
				name = "label",
			},
			{ type = QPushButton,
				name = "button",
				init = {
					{ "setText", "press me! *_*"},
				},
			},

		},
		{ type = QPushButton,

			name = "self_destruct",
			init = {

				{ "setText", "Self-destruct button" },
			},
		},
	}

	LuaQt.init_tree(self, gui, self)

	--self:connect(self.button, "clicked()", self, self.button_pressed)
	self.counter = 0

	--self:connect(self, "destroyed(QObject*)", self, self.__delete__)

	--self:connect(self.self_destruct, "destroyed(QObject*)", self, self.button_pressed)
	--self:connect(self.self_destruct, "clicked()", self.self_destruct, QObject.deleteLater)

	self:setWindowTitle("Qt4")

	self:show()
end

class("Bleh", Main)

function Bleh:__parent_args__(...)

	return "LOL PARENT"
end

function Bleh:__init__()

	print "bleh constructor!"

end

--Main:new()
bleh = Bleh:new()
bleh:setWindowTitle("Qt4 (NOT FROM MAIN)")

--local calc = Calculator:new(nil)
--calc:setWindowTitle("Calculator!")



return QApplication:exec()
