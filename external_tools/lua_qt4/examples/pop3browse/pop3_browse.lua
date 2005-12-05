--require "lua_qt_helpers.lua"
package.path = os.getenv("HOME").."/.?;"..package.path
require "pop3_config"

require "pop3_client"

class "POP3Browse"

function POP3Browse:item_updated(num)

	if num == 0 then

		self.list:clear()
	else

		local lit = self.list:findItem(num, 0)
		if lit then
			self.list:takeItem(lit)
		end

		local pop_item = self.pop:get_item(num)

		local size
		if pop_item.size then
			size = string.format("%.2f", pop_item.size/1024).."k"
		end

		lit = Q3ListViewItem:new(self.list, num, size, pop_item.date, pop_item.from, pop_item.subject)
	end

	--QApplication:flush()
end

function POP3Browse:message_deleted(msg)

	print("deleted message "..msg)
end

function POP3Browse:start_connection(acct)
	self.pop:connect(acct.host, acct.port)

	if not self.pop:login(acct.username, acct.password) then

		self.stack:setCurrentIndex(self.LOGIN_PAGE)
		return
	end

	self.pop:load_list()
end

function POP3Browse:load_preview(qitem, qpoint, col)

	if not qitem then return end
	local msgid = tonumber(qitem:text(0))

	local preview = self.pop:preview_item(msgid)

	if preview then
		self:show_preview(preview)
	end
end

function POP3Browse:show_preview(text)

	local w = {}

	local gui = {
		type = Q3VBox,

		init = {
			{ "resize", self.last_preview_width or 500, self.last_preview_height or 400 },
		},

		{ type = QTextEdit,
			name = "text",
			init = {
				{"setReadOnly", true},
			},
		},

		{ type = Q3HBox,

			{ type = QPushButton,
				name="close",
				init = {
					{"setText", "Close"},
				},
			},
			{ type = QCheckBox,

				name = "check",
				init = {
					{"setText", "As HTML"},
				},
			},
		},
	}

	local root = LuaQt.init_tree(nil, gui, w)

	self:connect(w.close, "clicked()", root, QObject.deleteLater)
	self:connect(root, "destroyed(QObject*)", self, self.close_preview, root)

	w.text:setPlainText(text)

	self:connect(w.check, "stateChanged(int)", self, self.load_text, w, text)

	root:show()
end

function POP3Browse:close_preview(widget)
print("destroy them!!")
	self.last_preview_width = widget:width()
	self.last_preview_height = widget:height()

	widget:close()
end

function POP3Browse:load_text(state, window, text)

	if window.check:isChecked() then

		local _,_,header,body = string.find(text, "^(.-)\r?\n\r?\n(.*)$")

		window.text:clear()
		window.text:append(header)
		window.text:insertHtml(body)
	else

		window.text:setPlainText(text)
	end
end

function POP3Browse:delete_pressed()

	local delete_list = {}
	local it = self.list:firstChild()
	while it do

		if self.list:isSelected(it) then

			table.insert(delete_list, tonumber(it:text(0)))
		end

		it = it:nextSibling()
	end

	local res = QMessageBox:question(self.root, "Are you sure", "Delete "..table.getn(delete_list).." selected messages?",
						"Yes", "No", nil)

	if res ~= 0 then return end

	msg = self.pop:delete_list(delete_list)
	msg = self.pop:load_list()
end

function POP3Browse:error_report(msg)

	QMessageBox:critical(self.root, "Error!", msg);

end

function POP3Browse:disconnect_pressed()

	self.pop:disconnect()
	self.stack:setCurrentIndex(self.LOGIN_PAGE)
end

function POP3Browse:connect_pressed()

	local it = self.accounts:currentText()
	if not accounts[it] then

		QMessageBox:critical(self.root, "Error!", "Please select an account.");
		return
	end

	if not accounts[it].password and self.password:text() == "" then

		QMessageBox:critical(self.root, "Error!", "Please enter a password.");
		return
	end

	if self.password:text() ~= "" then
		accounts[it].password = self.password:text()
	end

	self.stack:setCurrentIndex(self.LIST_PAGE)
	self:start_connection(accounts[it])
end

function POP3Browse:quit()

	self.pop:disconnect()

	QCoreApplication:quit()
end

POP3Browse.LOGIN_PAGE = 0
POP3Browse.LIST_PAGE = 1

function POP3Browse:__init__(parent)

	local gui = {

		type = QMainWindow,

		name = "main_window",
		init = {

			{"setWindowTitle", "POP3 Browser"},
		},

		{ type = QStackedWidget,
			name = "stack",

			init = {

				{ QMainWindow.setCentralWidget },
			},

			{ type = Q3VBox,

				{ type = QShortcut,

					name = "shortcut",
					init = {
						{ "setKey", QKeySequence(Qt.Key_Return) },
					},
				},

				"Account:",
				{ type = QComboBox,

					name = "accounts",
				},
				"Password:",
				{ type = QLineEdit,

					name = "password",
					init = {

						{"setEchoMode", QLineEdit.Password},
					},
				},

				{ type = QPushButton,

					name = "connect_button",
					init = {

						{"setText", "Connect"},
					},
				},

				init = {

					{QStackedWidget.addWidget }, --, self.LOGIN_PAGE,
				},
			},

			{ type = Q3VBox,

				{ type = Q3ListView,

					name = "list",
					init = {
						{"addColumn", "#", 30},
						{"addColumn", "Size", 50},
						{"addColumn", "Date", 160},
						{"addColumn", "From", 180},
						{"addColumn", "Subject", 320},
						{"setSelectionMode", Q3ListView.Multi},
						{"setAllColumnsShowFocus", true},
						{"setSorting", 50},
					},
				},

				{ type = Q3HBox,

					{ type = QPushButton,

						name="disconnect",
						init = {

							{"setText", "<< Disconnect"},
						},
					},
					{ type = QPushButton,

						name="all",
						init = {

							{"setText", "Select all"},
						},
					},
					{ type = QPushButton,

						name="clear",
						init = {

							{"setText", "Clear selection"},
						},
					},
					{ type = QPushButton,

						name="invert",
						init = {

							{"setText", "Invert selection"},
						},
					},

					{ type = QPushButton,

						name="delete",
						init = {

							{"setText", "Delete selected messages"},
						},
					},

				},

				init = {

					{QStackedWidget.addWidget }, --, self.LIST_PAGE,
				},
			},
		},
	}

	self.pop = POP3Client:new()
	self.pop.item_updated:connect(LuaSlot:new(self, self.item_updated))
	self.pop.message_deleted:connect(LuaSlot:new(self, self.message_deleted))
	self.pop.error:connect(LuaSlot:new(self, self.error_report))

	self.root = LuaQt.init_tree(parent, gui, self)
	self.root:show()

	for k,v in pairs(accounts) do

		self.accounts:insertItem(-1, k)
	end

	self:connect(self.connect_button, "clicked()", self, self.connect_pressed)
	self:connect(self.shortcut, "activated()", self, self.connect_pressed)

	self:connect(self.disconnect, "clicked()", self, self.disconnect_pressed)
	self:connect(self.all, "clicked()", self.list, self.list.selectAll, true)
	self:connect(self.clear, "clicked()", self.list, self.list.clearSelection)
	self:connect(self.invert, "clicked()", self.list, "invertSelection()")
	self:connect(self.delete, "clicked()", self, self.delete_pressed)

	self:connect(self.list, "doubleClicked(Q3ListViewItem*,const QPoint&, int)", self, self.load_preview)

	self:connect(self.main_window, "destroyed(QObject*)", self, self.quit)
	self:connect(q_app, "lastWindowClosed()", self, self.quit)

	--self:start_connection(accounts.pop3)
end

POP3Browse:new(nil)

--return POP3Browse
