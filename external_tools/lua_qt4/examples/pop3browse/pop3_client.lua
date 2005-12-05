require "lua_qt_Network"

class "POP3Client"

debug_flag = general.debug or false

function POP3Client:connect(host, port)

	self.port = port or self.port
	self.host = host or self.host

	self.sockfd = QTcpSocket:new_local()
	self:connect_signal(self.sockfd, "error(QAbstractSocket::SocketError)", self, self.socket_error)
	--self.sockfd:settimeout(2) -- 2 seconds

	local ret
	self.sockfd:connectToHost(self.host, self.port)
	if not self.sockfd:waitForConnected() then
		self.error(self.sockfd:errorString())
		return nil,self.sockfd:errorString()
	end

	ret, self.last_error = self:read_line()
	if ret then
		if string.sub(ret, 1, 1) ~= "+" then
			self.last_error = ret
			ret = nil
		end
	end

	if not ret then self.error(err) end

	return ret, self.last_error
end

function POP3Client:read_line()

	while not self.sockfd:canReadLine() do
	
		self.blocking()
		if not self.sockfd:waitForReadyRead(100) then
		
			if self.sockfd:state() == QAbstractSocket.UnconnectedState then
				return nil, self.sockfd:errorString()
			end
		end
	end
	-- can read line
	return self.sockfd:readLine():constData()
end

function POP3Client:socket_error(err)
print("calling error with "..self.sockfd:errorString())
print(debug.traceback())
	self.error(self.sockfd:errorString())
end

function POP3Client:connected()
	--if not self.sockfd or not self.sockfd:getpeername() then
	if not self.sockfd or self.sockfd:state() == QAbstractSocket.UnconnectedState then

		self:clear()
		self:connect()
	end
	return self.sockfd and self.sockfd:state() ~= QAbstractSocket.UnconnectedState
end

function POP3Client:login(user,pass)

	user = user or self.user
	pass = pass or self.pass

	if not user or not pass then return nil end

	if not self:connected() then
		return nil, self.CONNECTION_ERROR, "Unable to connect to server."
	end


	self.logged_in = false

	local res,err = self:send("USER "..user)
	if not res then
		return nil, self.ERROR, err
	end

	res,err = self:send("PASS "..pass)
	if not res then
		--self:send("QUIT")
		self:disconnect()
		return nil, self.ERROR, err
	end

	self.logged_in = true
	self.user = user
	self.pass = pass

	return true
end

function POP3Client:disconnect()

	if self.sockfd then
		self:send("QUIT")
		self.sockfd:close()
		self.sockfd = nil
	end

	self:clear()

	return
end

function POP3Client:delete_list(list)

	for k,v in list do

		self:delete_message(v)
	end
end

function POP3Client:delete_message(msg)

	if self:send("DELE "..msg) then

		self.message_deleted(msg)
		self.deleted_list[msg] = true
	end
end

function POP3Client:load_list(lite)

	--if not self.logged_in then
	--	return nil
	--end

	local res,err,msg = self:send("STAT")
	if not res then return res,err,msg end

	self:clear_list()

	_,_,self.nmsgs = string.find(res, "^%+OK (%d+)%s")
	self.nmsgs = tonumber(self.nmsgs)
	if not self.nmsgs then return nil end
	if not lite then

		local i=1
		local todo = self.nmsgs
		while todo > 0 do

			if not self.deleted_list[i] then

				local header = self.header_cache[i] and self.header_cache[i].header
				local size = header and self.header_cache[i].size

				if not header then
					res,err,msg = self:send("LIST "..i)
					if res then
						_,_,size = string.find(res, "OK%s+%d+%s+(%d+)$")
						size = tonumber(size)
					else
						return nil, err, msg
					end

					res,err,msg = self:send("TOP "..i.." 0", true)
					if res then
						--return res,err,msg
						header = res
					else

						return nil,err,msg
					end
				end

				todo = todo - 1
				self:load_item_full(i, header, size)
			end

			i = i+1
		end
	else
		res,err,msg = self:send("LIST", LuaSlot:new(self, self.load_item))
		return res,err,msg
	end
end

function POP3Client:preview_item(n, lines)

	lines = lines or general.preview_lines or 10

	return self:send("TOP "..n.." "..lines, true)
end

function POP3Client:clear()

	self.logged_in = false
	self.deleted_list = {}
	self.header_cache = {}
	self:clear_list()
end

function POP3Client:clear_list()

	self.mbox_list = {}
	self.item_updated:emit(0)
end

function POP3Client:load_item(item)

	local n,s
	_,_,n,s = string.find(item, "^(%d+)%s+(%d+)")

	local i = {
		size = s,
	}

	self.mbox_list[n] = i
	self.item_updated:emit(n)
end

function POP3Client:load_item_full(n, item, size)

	local field
	local i = {}

	--_,_,i.size = string.find(item, "^%+OK%s+(%d+)%s+")
	i.size = i.size or size
	_,_,i.subject = string.find(item, "Subject: ([^\n]*)\n")
	_,_,i.from = string.find(item, "From: ([^\n]*)\n")
	_,_,i.date = string.find(item, "Date: ([^\n]*)\n")

	self.mbox_list[n] = i

	self.header_cache[n] = {header = item, size = size}

	self.item_updated(n)
end

function POP3Client:get_item(n)

	return self.mbox_list[n]
end

function POP3Client:send_data(data)

	self.sockfd:write(data, string.len(data))
	self.sockfd:waitForBytesWritten(-1)
end

function POP3Client:send(command, act)

	-- not for now
	-- if not self:connected() then
	--	return nil, self.CONNECTION_ERROR, "Unable to connect to server."
	-- end

	if string.sub(command, -1) ~= "\n" then
		command = command.."\n"
	end

	self:send_data(command)

	local r, err = self:read_line()
	if debug_flag then print(tostring(r)) end

	if not r then

		self.error(err)
		return nil, self.CONNECTION_ERROR, ("Error while receiving data: connection "..err)
	end

	local status = string.sub(r, 1, 1)
	if status ~= "+" then
		if r ~= "" then
			self.error(r)
		end
		return nil, self.ERROR, r
	end

	if not act then
		return r
	end

	local ret = r.."\n"

	while r ~= '.' and not err do

		r, err = self:read_line()
		if debug_flag then
			print(r)
		end

		if type(act) == 'boolean' then

			ret = ret..r.."\n"
		else

			act(r)
		end
	end

	if err then
		self.error(err)
		return ret, self.CONNECTION_ERROR, err
	end

	return ret
end

function POP3Client:__init__(port, host)

	self.CONNECTION_ERROR = 500
	self.ERROR = 501
	self.WARNING = 502

	self.item_updated = LuaSignal:new(1)
	self.message_deleted = LuaSignal:new(1)
	self.error = LuaSignal:new(1)
	self.blocking = LuaSignal:new(0)

	self.port = port or 110
	self.host = host or 'localhost'

	self:clear()

	--self:connect(port, host)
end

return POP3Client
