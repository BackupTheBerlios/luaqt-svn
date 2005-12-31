require "class_list"
require "exclude_list"

global_modules = {}

function add_class(fname, module)

	local file = io.open("doc/"..fname, "r")

	if not file then return end

	f = file:read("*a")
	file:close()

	local class = {}

	_,_,class.name = string.find(f, "([^%s]+) Class Reference") -- templates excluded
	if not class.name or class.name == "" or exclude_class(class.name) then

		return
	end
	local _,_,inherits = string.find(f, "Inherits (.-)\n")
	if inherits then
		inherits = string.gsub(inherits, " and ", "")
		inherits = string.gsub(inherits, "%.", "")
		inherits = string.gsub(inherits, "%s*,%s*", ",")

		inherits = split_c_tokens(inherits, ",")
		class.inherits = inherits
	end

	--_,_,class.include = string.find(f, "(#include[^\n]*)\n")
	--class.include = class.include.."\n\n"
	class.include = "#include <"..class.name..">\n\n"

	local mod = create_module(module)

	class.code = "class "..class.name
	if class.inherits then

		local sep = " : "
		for k,v in ipairs(class.inherits) do

			class.code = class.code..sep.."public "..v
			sep = " , "
		end
	end

	class.code = class.code.." {\nQ_OBJECT\nsignals:\n"

	local tmp = {code=f}
	class.code = class.code..get_section(tmp, class, "Signals")

	class.code = class.code.."public:\n"
	class.code = class.code..get_section(tmp, class, "Public Types")
	class.code = class.code..get_section(tmp, class, "Classes")

	local func = "\n"..get_section(tmp, class, "Public Member Functions")
	local slots = get_section(tmp, class, "Public Slots")

	--if string.find(func, "=0;\n") or string.find(slots, "=0;\n") then

	--	func = string.gsub(func, "\n%s*"..class.name.."%s*%b()%s*;", "")
		--table.insert(exclude_method_list, class.name)
	--end


	class.code = class.code..func
	class.code = class.code..slots

	class.code = class.code..get_section(tmp, class, "Protected Member Functions", "", filter_virtual)

	class.code = class.code..get_section(tmp, class, "Static Public Member Functions")
	class.code = class.code..get_section(tmp, class, "Public Attributes")

	--class.code = string.gsub(class.code, "operator%s+%w[^;]*;", "") -- for now
	class.code = string.gsub(class.code, "String%s*([&%*]?)%s*string%s*([%)=,])", "String%1 %2")

	class.code = string.gsub(class.code, "QT_STATIC_CONST", "static const")

	class.code = string.gsub(class.code, "\n[^\n]*xpm%[%][^\n]*\n", "\n\n");


	class.code = class.code.."\n};\n"

	mod.classes[class.name] = class
end

function filter_virtual(line)

	if string.find(line, "%s*virtual%s+") then

		return "protected "..line
	end

	return ""
end

function get_section(file, class, sname, prep, slot)

	prep = prep or ""

	local ret = ""

	local b,e,sec = string.find(file.code, sname.."[\n\t%s]*(%*%s*[^%d].-)\n\n")
	if not b then
		return ret
	end
	sec = sec.."\n\n"

	e = 0
	local ac
	function flush_ac()
		if ac then
			ac = string.gsub(ac, "^%s*%*", "")
			ac = string.gsub(ac, "%s*\n$", "")
			ac = string.gsub(ac, "[\n]", "")
			local line = prep..ac..";\n"
			if slot then line = slot(line) end
			ret = ret.."\t"..line
		end
	end

	repeat
		b,e,line = string.find(sec, "([^\n]+\n)", e+1)
		if b then
			if string.find(line, "^%s*%*") then

				flush_ac()

				if exclude_method(string.gsub(line, "%b()", "")) then
					ac = nil
				else
					ac = line
					if string.find(line,"typedef") then
						local _,_,name = string.find(line, "(%b())")
						if name and name ~= '' then
							-- function typedefs became subclasses for now
							name = string.gsub(name, "[%*%&%(%)]", "")
							ac = "class "..name
						end
					end
				end
			else
				if not string.find(line, "_____") then
					ac = (ac or "")..line
				end
			end
		else

			flush_ac()
		end
	until not b

	return ret
end

function create_module(modname)

	if not global_modules[modname] then
		global_modules[modname] = {name = modname, classes = {}}
	end

	return global_modules[modname]
end

function output_module(mod)

	local fname = mod.."_headers.pkg"

	local file = io.open(fname, "wb")

	sort_inheritance(global_modules[mod])

	local clist = global_modules[mod].classes
	for k,v in pairs(global_modules[mod].inheritance) do

		if clist[v].include then
			file:write("$"..clist[v].include)
		end
		file:write(clist[v].code)
	end

	file:close()
end

function sort_inheritance(mod)

	mod.inheritance = {}

	for k,v in pairs(mod.classes) do

		table.insert(mod.inheritance, k)
		v.inheritance_rating = get_rating(mod.classes, k)
	end

	table.sort(mod.inheritance, function (a,b)

		return get_rating(mod.classes, a) < get_rating(mod.classes, b)

	end)
end

function get_rating(clist, class)
	return (not clist[class] and 0) or clist[class].inheritance_rating or
		(clist[class].inherits and get_rating(clist, clist[class].inherits[1]) + 10) or 0
end

function split (s,t)
 local l = {n=0}
 local f = function (s)
  l.n = l.n + 1
  l[l.n] = s
 end
 local p = "%s*(.-)%s*"..t.."%s*"
 s = string.gsub(s,"^%s+","")
 s = string.gsub(s,"%s+$","")
 s = string.gsub(s,p,f)
 l.n = l.n + 1
 l[l.n] = string.gsub(s,"(%s%s*)$","")
 return l
end

-- splits a string using a pattern, considering the spacial cases of C code (templates, function parameters, etc)
-- pattern can't contain the '^' (as used to identify the begining of the line)
-- also strips whitespace
function split_c_tokens(s, pat)

	s = string.gsub(s, "^%s*", "")
	s = string.gsub(s, "%s*$", "")

	local token_begin = 1
	local token_end = 1
	local ofs = 1
	local ret = {n=0}

	function add_token(ofs)

		local t = string.sub(s, token_begin, ofs)
		t = string.gsub(t, "^%s*", "")
		t = string.gsub(t, "%s*$", "")
		ret.n = ret.n + 1
		ret[ret.n] = t
	end

	while ofs <= string.len(s) do

		local sub = string.sub(s, ofs, -1)
		local b,e = string.find(sub, "^"..pat)
		if b then
			add_token(ofs-1)
			ofs = ofs+e
			token_begin = ofs
		else
			local char = string.sub(s, ofs, ofs)
			if char == "(" or char == "<" then

				local block
				if char == "(" then block = "^%b()" end
				if char == "<" then block = "^%b<>" end

				b,e = string.find(sub, block)
				if not b then
					-- unterminated block?
					ofs = ofs+1
				else
					ofs = ofs + e
				end

			else
				ofs = ofs+1
			end
		end

	end
	add_token(ofs)
	--if ret.n == 0 then

	--	ret.n=1
	--	ret[1] = ""
	--end

	return ret

end


function exclude_method(m)

	for k,v in ipairs(exclude_method_list) do

		if string.find(m, v) then
			return true
		end
	end

	return false
end

function exclude_class(c)

	for k,v in ipairs(exclude_class_list) do

		if c == v then
			return true
		end
	end

	return false
end

-- main loop

for k,v in pairs(class_list) do

	local module
	for mk,mv in ipairs(module_list) do

		if not module and files_set[mv.."/"..v] then
			module = mv
		end
	end

	if module then
		local fname = "class"..v..".html"

		add_class(fname,module)
	else

		print("module not found for class "..v)
	end
end

for k,v in pairs(global_modules) do
	output_module(k)
end

