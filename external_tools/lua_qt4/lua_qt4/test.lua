function load_module(mod)

	print("Loading module "..mod)
	local f, oe, ce = loadlib("./liblua_qt_"..mod..".so", "tolua_lua_qt_"..mod.."_open")
	--local f, oe, ce = loadlib("./lua_qt_"..mod..".dll", "tolua_lua_qt_"..mod.."_open")
	if not f then
		error(oe)
	end

	f()
end


load_module("Core")
load_module("Gui")
load_module("3Support")
load_module("Xml")
load_module("Sql")
load_module("OpenGL")
load_module("Network")
load_module("Designer")

require "calculator.lua"

app = QApplication:new(LuaQt.argc, LuaQt.argv)

--require "lua_qt_helpers.lua"

class "Main"

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

	self:connect(self.button, "clicked()", self, self.button_pressed)
	self.counter = 0

	--self:connect(self, "destroyed(QObject*)", self, self.__delete__)

	self:connect(self.self_destruct, "destroyed(QObject*)", self, self.button_pressed)
	self:connect(self.self_destruct, "clicked()", self.self_destruct, QObject.deleteLater)

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
