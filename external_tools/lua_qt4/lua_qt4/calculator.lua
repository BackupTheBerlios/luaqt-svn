-- run with lua_qt -n calculator.lua

class "Calculator"

function Calculator:append_digit(d)

	local t = string.gsub(self.display:text()..d, "^0*", "")
	if t == "" then t = "0" end
	self.display:setText(t)
end

function Calculator:__init__(parent)

	-- we can create a table that defines the GUI structure:
	local button_row = {
			type = Q3HBox,
				{ type = QPushButton, name="digit"},
				{ type = QPushButton, name="digit"},
				{ type = QPushButton, name="digit"},
			}


	local gui = {

		type = Q3VBox,

		childs = {

			{ type = QLabel,
				args={"0", parent_pos=2}, -- constructor arguments, default parent_pos is 1
				name="display",
			},
			button_row,
			button_row,
			button_row,
			{ type = Q3HBox,
				{ type = QPushButton, name="digit"},
				{ type = QPushButton, name="clear"}, -- the 'C' button
			},

		},

	}

	local root_widget = LuaQt.init_tree(parent, gui, self) -- parent widget, gui definition, container (for the objects that have a 'name' field)

	-- sets 'root_widget' as the instance from which our object inherts. Now we can use 'self' as a widget
	self:set_c_instance(root_widget)

	for i=1,table.getn(self.digit) do -- when more than 1 objects have the same name, they become an array

		local bdigit = math.mod(i, 10)
		self.digit[i]:setText(bdigit)
		self:connect(self.digit[i], "clicked()", self, Calculator.append_digit, bdigit)
	end

	self.clear:setText("C")
	self:connect(self.clear, "clicked()", self.display, QLabel.setText, "0")

	root_widget:show()
end

return Calculator
