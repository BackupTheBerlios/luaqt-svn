print(package.path)
print(package.cpath)

if not string.find(package.cpath, "dll") then
	package.cpath = "./lib?.so;"..package.cpath
end

print "1"
require "lua_qt_Core"
print "2"
require "lua_qt_Gui"
print "3"
require "lua_qt_3Support"
print "4"

--require "lua_qt_helpers"
--require "class"

require "calculator"

app = QApplication:new(LuaQt.argc, LuaQt.argv)

class("Main", QMainWindow)

function Main:button_pressed(bind)

	self.counter = self.counter +1
	self.label:setText(self.counter)
end

function Main:__delete__()

	print "destroyed"
end

function Main:__init__(parent)

	print("*********** parent on main is "..tostring(parent))

	--self:set_c_instance(QMainWindow:new())

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

	self:connect(self.button, "clicked()", self, self.button_pressed, "BIND")
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
bleh:setProperty("windowTitle", "Title (property)")
local recto = QRect(0, 0, 400, 400)
print(recto['.QVariant'])
local var = QVariant()
bleh:setProperty("geometry", recto)

local var2 = bleh:property("geometry")
print("type is "..tolua.type(var2))
print("title is "..bleh:property("windowTitle"))

--local calc = Calculator:new(nil)
--calc:setWindowTitle("Calculator!")



return QApplication:exec()
