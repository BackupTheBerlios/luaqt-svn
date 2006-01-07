dofile "lua_qt4/hooks.lua"

-- support for QString
_basic['QString'] = 'qtstring'
_basic_ctype.qtstring = 'const char*'

-- suppor for weird flag things
_basic['LuaQtGenericFlags'] = 'qtflags'
_basic_ctype.qtflags = 'int'

-- support for weird QBool object
_basic['QBool'] = 'boolean'

-- support for QVariant
_basic['QVariant'] = 'QVariant'
_basic_ctype.QVariant = 'QVariant'
_basic_raw_push.QVariant = 'tolua_pushQVariant__raw'

signals = {count=0}
sigc_signals = {count=0}
qt_signal_headers = {}
sigc_slots = {}
sigc_headers = {}
qt_classname = nil

--extra_qt_code = (extra_qt_code or "").. [[
--
--]]


function default_include_hook(...)
	include_hook_list.qt(unpack(arg))
end
include_hook_list = include_hook_list or {default = default_include_hook}

function include_file_hook(p, filename, ...)

	local f = include_hook_list[arg[1]] or include_hook_list.default
	if f then
		f(p, filename, unpack(arg))
	end
end

function include_hook_list.template(p, filename, type, ...)

	local sep = ""
	local list = ""
	for k,v in ipairs(arg) do
		list = list..sep..v
		sep = ","
	end

	p.code = string.gsub(p.code, "%$TYPE_LIST", list)
end

function include_hook_list.qns(p, filename, ftype)

	p.code = string.gsub(p.code, "Q_DECLARE_FLAGS%s*%(([^,]*),([^%)]*)%)%s*;?", "typedef %2 %1;\n")
end

function include_hook_list.qt(p, filename, ftype)

	p.code = string.gsub(p.code, "char%s*%*%*argv", "arg_list* argv")
	p.code = string.gsub(p.code, "int%s*&%s*argc", "arg_count& argc")
	p.code = string.gsub(p.code, "Qt::HANDLE%s+handle%s*%(%)%s+const;", "")

	local code = ""

	if string.find(filename, "%.h$")then
		code = '$#include "'..filename..'"\n\n'
	end

	p.code = code.. parse_block(p.code, filename, ftype=='qt')

	if string.find(p.code, "SigC::Signal") then
		sigc_headers[filename] = true
	end
end

function parse_block(p_code, filename, keep_code)

	local code = ""

	local block
	local b=0
	local e=-1
	repeat

		b,e,line = string.find(p_code, "([^\n]+\n)", e+1)
		if b then
			if string.find(line, "^%s*class") then
				if string.find(line, ";") then -- forward declaration
					if not string.find(line, "QString") then
						code = code .. line
					end
				else -- an actual class
					local classb,classe,block = string.find(p_code, "(class[^{;]*%b{};)", b)
					if classb then
						code = code .. parse_class(block, filename);
						e = classe
					end
				end
			elseif keep_code then
				-- anything else goes
				code = code..line
			end
			--[[ -- not for now
			if string.find(line, "^%s*namespace") then
				local nsb, nse, block = string.find(p_code, "namespace%s*(%b{});", b)
				if nsb then
					code = code .. line
					if not string.find(line, "{") then
						code = code .. "{"
					end
					code = code..parse_block(block, filename)
					e = nse
					code = code .. "};\n"
				end
			end
			--]]
		end

		--b,e,block = string.find(p.code, "(class[^{;]*%b{};)", e+1)
		--if b then
		--	code = code .. parse_class(block);
		--end
	until not b

	return code
end

function preprocess_hook(p)

end


function preparse_hook(p)

	p.code = string.gsub(p.code, "%s*BRIDGE_COPY_VALUE%s*%b()%s*;?", "")

	string.gsub(p.code, "SigC::Signal[^<]+%b<>",
				function (s)
					local strip = string.gsub(s, "%s*,%s", ",")
					strip = string.gsub(strip, "%s*([&%*])%s*", "%1")
					strip = string.gsub(strip, "%s*([<>])%s*", "%1")
					strip = string.gsub(strip, ">>", "> >")
					sigc_signals[strip] = strip
					sigc_signals.count = sigc_signals.count + 1
					return s
				end
			)
	--print("******************************* preparse code\n"..p.code.."\n***************************** end preparse code\n")

	sigc_classname = "LuaSignalHandler__"..p.name
	sigc_basename = "lua_signal_handler_"..p.name
	if sigc_signals.count > 0 then
		p.code = string.gsub(p.code, "\n%s*SigC::Signal", "\ntolua_readonly SigC::Signal")
		local line = "LuaSignalHandler* new_"..sigc_classname.."();\n"
		p.code = p.code .. line
		Verbatim("extern "..line)
	end

	if signals.count > 0 then

		qt_classname = "QtSignalHandler__"..p.name
		local line = "QtSignalHandler* new_"..qt_classname.."();\n"
		p.code = p.code..line
		Verbatim("extern "..line)

		lua_code = "\n\1\nLuaQt.register_signal_handler(new_"..qt_classname.."())\n\2"
		p.code = p.code..lua_code
	end

end

function post_output_hook(p)

	output_sigc_signal_handler(p)
	output_qt_signal_handlers(p)
end

function output_qt_signal_handlers(package)

	if signals.count == 0 then return nil end

	local outpath = "."
	if flags['o'] then
		b = string.find(flags.o, "[^/]*$")
		outpath = string.sub(flags.o, 1, b-1)
		if outpath == "" then outpath = "." end
	end

	local basename = "qt_signal_handlers_"..package.name
	local filename = outpath.."/"..basename..".cpp"
	print("* opening filename "..filename)
	local file,e
	file,e = io.open(filename, "wb")
	if not file then
		error("#unable to open file "..filename.." for QT signal handlers: "..e)
	end

	file:write('#include "lua_qobject.h"\n\n')
	file:write("class QColorGroup; // fucking bug in qt3support\n")

	for header,b in pairs(qt_signal_headers) do
		file:write('#include <'..header..'>\n')
	end
	file:write('\n')

	if extra_qt_code then
		file:write(extra_qt_code)
	end

	local qt_object_list = {}
	local i = 1

	for k,v in pairs(signals) do
		if k~='count' then
			local sigvarname = string.gsub(k, "[%s,%(%)%*&:]", "_")
			local classname = "LuaQObject__"..sigvarname
			file:write("class "..classname.." : public LuaQObject {\n\n")

			file:write("\tQ_OBJECT;\n\n")
			file:write("public slots:\n")

			output_qt_slot(file, classname, v, k)

			file:write("public:\n")
			file:write("\t"..classname.."(QObject* p_parent) : LuaQObject(p_parent) {};\n")
			file:write("};\n\n")
			qt_object_list[i] = {k, classname}
			i=i+1
		end
	end
	output_qt_object_list(file, qt_object_list)

	file:write('#include "'..basename..'.moc"\n');

	file:close()
end

function output_qt_object_list(file, list)

	file:write("class "..qt_classname.." : public QtSignalHandler {\n\n")
	file:write("public:\n")
	file:write("\tvoid init_signal_list();\n")
	file:write("\tLuaQObject* get_q_object(QString p_parameters, QObject* p_parent);\n")

	file:write("\t"..qt_classname.."() {\n")
	file:write("\t\tinit_signal_list();\n")
	file:write("\t};\n")

	file:write("};\n\n")

	file:write("void "..qt_classname.."::init_signal_list() {\n")

	for k,v in ipairs(list) do

		file:write("\tsignal_list[\""..v[1].."\"] = "..k..";\n")
	end
	file:write("};\n\n")

	file:write("LuaQObject* "..qt_classname.."::get_q_object(QString p_parameters, QObject* p_parent) {\n\n")
	file:write("\tif (signal_list.find(p_parameters) == signal_list.end()) return NULL;\n\n");
	file:write("\tswitch(signal_list[p_parameters]) {\n\n")
	for k,v in ipairs(list) do
		file:write("\t\tcase "..k..": return new "..v[2].."(p_parent);\n")
	end
	file:write("\n\t\tdefault: return NULL;\n")
	file:write("\t};\n")
	file:write("\treturn NULL;\n")
	file:write("};\n\n")

	file:write("QtSignalHandler* new_"..qt_classname.."() {\n")
	file:write("\treturn new "..qt_classname..";\n")
	file:write("};\n\n")
end

function output_qt_slot(file, class_name, signal, pars)

	local pars_strip = string.gsub(pars, "^%s*%(%s*", "")
	pars_strip = string.gsub(pars_strip, "%s*%)%s*$", "")
	output_slot(file, class_name, "slot", "void", pars_strip, false, true)
end

function find_type(t)

	local st = string.gsub(t, "[%*&]", "")
	_,_,st = string.find(st, "([^%s]*)%s*$")

	if not _global_types_hash[st] then

		for i=_global_types.n,1,-1 do

			if string.find(_global_types[i], "::"..st.."$") then
				return _global_types[i]
			end
		end
	end

	return t
end

function output_slot(file, class_name, method_name, return_value, arguments, ref, in_header, use_p_slot)

	local sep = "."
	if ref then sep = "->" end

	local vars = {}
	local var_args = ""
	local types = {}
	if arguments ~= "" then
		types = split(arguments, ",")
		for i=1,table.getn(types) do
			types[i] = find_type(types[i])
			vars[i] = "var"..i
			var_args = var_args..types[i].." "..vars[i]..","
		end
		var_args = string.gsub(var_args, ",$", "")
	end

	local retn
	if return_value == 'void' then
		retn = 0
	else
		retn = 1
	end

	local p_slot = ""
	if use_p_slot then
		p_slot = "LuaSlot lua_slot"
		if var_args ~= "" then
			p_slot = ","..p_slot
		end
	end

	if in_header then
		file:write("\t"..return_value.." "..method_name.."("..var_args..p_slot..") {\n\n")
	else
		file:write("\t"..return_value.." "..class_name.."::"..method_name.."("..var_args..p_slot..") {\n\n")
	end

	--file:write("\t\tif (!lua_slot"..sep.."is_empty() {\n\n")

	file:write("\t\t\tlua_slot"..sep.."push_call();\n")
	for k,v in ipairs(types) do
		local st = string.gsub(v, "[%*&]", "")
		_,_,st = string.find(st, "([^%s]*)%s*$")
		local t,ct = isbasic(st)
		if t then
			file:write("\t\t\ttolua_push"..t.."(lua_slot"..sep.."ls, ("..ct..")"..vars[k]..");\n");
		else
			local strip = string.gsub(v, "[%*&]", "")
			local f,_,m = string.find(v, "([%*&])")
			if f then
				if m == "*" then m = "" end
				file:write("\t\t\ttolua_pushusertype(lua_slot"..sep.."ls, (void*)"..m..vars[k]..", \""..strip.."\");\n")
			else
				local new_t = string.gsub(strip, "const%s+", "")
	 			file:write("\t\t\tvoid* tolua_obj = new "..new_t.."("..vars[k]..");\n")
				file:write('\t\t\ttolua_pushusertype_and_takeownership(lua_slot'..sep..'ls, tolua_obj, "'..strip..'");\n')
			end
		end
	end
	file:write("\t\t\tlua_dbcall(lua_slot"..sep.."ls, "..tostring(table.getn(types))..", "..retn..");\n")

	--file:write("\t\t};\n") -- is_empty

	if retn > 0 then -- return value not supported yet
		file:write("\t\treturn "..return_value.."(); // Warning!! unitialized value.\n")
	end
	file:write("\t};\n\n")
end

function output_sigc_signal_handler(package)

	if sigc_signals.count == 0 then return end

	local outpath = "."
	if flags['o'] then
		b = string.find(flags.o, "[^/]*$")
		outpath = string.sub(flags.o, 1, b-1)
		if outpath == "" then outpath = "." end
	end
	local basename = sigc_basename
	local filename = outpath.."/"..basename..".cpp"
	local file, e
	print("* opening filename "..filename)
	file,e = io.open(filename, "wb")
	if not file then
		error("#unable to open file for sigc signal handler: "..e)
	end

	local classname = "LuaSignalHandler__"..package.name

	file:write([[
#include "lua_signal_handler.h"

#include "defines/string_hash.h"

#include "bridge_helpers.h"
]])

	for header,v in pairs(sigc_headers) do
		file:write('#include "'..header..'"\n')
	end

	file:write([[

class ]]..classname..[[ : public LuaSignalHandler {

	static hash_map<string,int,String_Hash> signal_list;
	static bool list_init;

]])

	local sigc_list = {}
	local i=0
	for k,v in pairs(sigc_signals) do
		if k ~= 'count' then
			local slotname = "slot_"..string.gsub(v, "[:, <>%*&]", "_")
			sigc_list[i] = {k, slotname}

			output_sigc_slot(file, classname, slotname, v)
			i=i+1
		end
	end

	file:write([[
	SigC::Connection connect_signal_internal(void* p_signal, string p_parameters, LuaSlot &slot) {

		if (!list_init) init_signal_list();
		if (signal_list.find(p_parameters) == signal_list.end()) return SigC::Connection();

		switch (signal_list[p_parameters]) {

]])

	for k,v in pairs(sigc_list) do
		file:write("\t\tcase "..k..": {\n")
		file:write("\t\t\t"..v[1].."* signal = ("..v[1].."*)p_signal;\n")
		file:write("\t\t\treturn signal->connect(SigC::bind(SigC::slot(*this, &"..classname.."::"..v[2].."), slot));\n\n")
		file:write("\t\t}; break;\n")
	end

	file:write([[

		default: return SigC::Connection();
		};
	};

	void init_signal_list() {

]])

	for k,v in pairs(sigc_list) do
		file:write('\t\tsignal_list["'..v[1]..'"] = '..k..';\n')
	end


	file:write([[
	};
]])


	file:write([[

public:
	]]..classname..[[() {};
};

bool ]]..classname..[[::list_init = false;
hash_map<string,int,String_Hash> ]]..classname..[[::signal_list;

LuaSignalHandler* new_]]..classname..[[() {
	return new ]]..classname..[[;
};

]])

	file:close()
end

function output_sigc_slot(file, classname, slotname, signame)

	local _,_,params = string.find(signame, "(%b<>)")
	params = string.sub(params, 2, -2)
	local list = split_c_tokens(params, ",")
	params = ""
	if table.getn(list) > 1 then
		for i=2,table.getn(list) do
			params = params..","..list[i]
		end
		params = string.sub(params, 2)
	end

	output_slot(file, classname, slotname, list[1], params, true, false, true)

end

function parse_class(body, filename)

	body = body .. "\n"
	local b,e,code = string.find(body, "^(class[^{;]*{)")
	code = code.."\n"

	local _,_,class_name = string.find(body, "^class%s+([^%s:]+)%s")

	local status = {public = false, signals = false, object = false}
	if string.find(body, "Q_OBJECT") then
		status.object = true
		body = string.gsub(body, "Q_OBJECT%s*;?", "")
	end

	repeat
		--b,e,line = string.find(body, "(.-\n)", e+1)
		b,e,line = string.find(body, "([^\n]+\n)", e+1)
		if b then
			if string.find(line, "operator%s*=[^=]") then line = "#" end
			if string.find(line, "operator%s*%+%+") then line = "#" end
			if string.find(line, "operator%s*%-%-") then line = "#" end
			if string.find(line, "operator%s*%-=") then line = "#" end
			if string.find(line, "operator%s*%!=") then line = "#" end

			if string.find(line, "operator%s*%+=") then line = "#" end
			if string.find(line, "operator%s*%*=") then line = "#" end
			if string.find(line, "operator%s*%/=") then line = "#" end
			if string.find(line, "operator%s*[<>]") then line = "#" end

			if string.find(line, "operator%s*|") then line = "#" end
			if string.find(line, "operator%s*&") then line = "#" end

			if string.find(line, "friend[%s%t]") then line = "#" end

			if not string.find(line, "^%s*#") then
				local is_code = true
				if string.find(line, ":%s*$") then
					is_code = false
					if string.find(line, "public") then
						status.public = true
					elseif string.find(line, "private") or string.find(line, "protected") then
						status.public = false
					end
					status.signals = string.find(line, "signals")
					if status.signals then
						status.public = false
					end
					if string.find(line, "[%(%)]") then is_code = true end
				end
				if is_code then
					if string.find(line, "class%s") then
						if string.find(line, ";") then -- forward declaration

							code = code..line
						else
							local subb,sube,class = string.find(body,"(class[^{;]*%b{};)", b)
							if subb then
								if status.public then
									code = code..parse_class(class, filename)
								end
								e = sube
							end
						end
					elseif status.public then
						code = code..line
					end
					if status.object and status.signals then
						add_signal(line)
						--qt_signal_headers[filename]=true
						qt_signal_headers[class_name]=true
					end
				end
			end
		end
	until not b

	if not status.public then
		code = code .. "};\n"
	end
	return code
end

function add_signal(s)

	local par
	_,_,par = string.find(s, "(%b())")
	if not par then return nil end
	par = remove_vars(par)
	par = string.gsub(par, "%s*,%s*", ",")
	par = string.gsub(par, "%s*%)", "%)")
	par = string.gsub(par, "%(%s*", "%(")
	signals[par] = s
	signals.count = signals.count +1
	--signals[table.getn(signals)+1] = s
end

-- a list of reserved words for variable types
reserved = {
	const = 1,
	unsigned = 1,
	signed = 1,
}

function remove_vars(s)

	local t = string.sub(s, 2, -2)
	local types = split_c_tokens(t, ",")

	local slot = ""

	for k,v in pairs(types) do

		if type(v) ~= 'number' then
			v = string.gsub(v, "%s*=.*$", "")
			local var_ofs = 1
			local words = split(v, " ")

			while var_ofs <= words.n and reserved[words[var_ofs]] do
				var_ofs = var_ofs + 1
			end
			if var_ofs >= words.n then
				slot = slot..v..","
			else
				local t = concat(words, 1, var_ofs)
				local m
				_,_,m = string.find(v, "([%*&])")
				if m then
					if not string.find(t, "([%*&])") then
						t = t..m
					end
				end
				slot = slot..t..","
			end
		end
	end
	slot = string.gsub(slot, ",$", "")

	return '('..slot..')'
end

function add_headers(p)
	local code = ""
	string.gsub(p.code, '#include%s+("[^"]*")',
				function (c)
					code = code .. '$#include '..c..'\n'
				end
				)
	return code
end
