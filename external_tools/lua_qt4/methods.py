def make_targets(self, object_list, source_list=[], debug=0):

	import glob
	import string
	import re

	if source_list == []:
		dir = self.Dir('.').abspath
		if self.build_dir:

			## strip build_dir from cwd for glob
			edir = '^' + re.escape(self.Dir('#').abspath) + r'[/\\]' + re.escape(self.build_dir)

			dir = re.sub(edir, '', dir)
			dir = self.Dir('#').abspath + dir

			stmp = glob.glob(dir + "/*.cpp")

			## add build_dir to cwd for Object
			sources = []
			for src in stmp:
				obj = re.search(r'[/\\]([^/\\]*)$', src)
				file = self.Dir('.').abspath + obj.group(0)
				sources.append(file)
		else:
			sources = glob.glob(dir + "/*.cpp")

	else:
		sources = []
		for src in source_list:
			sources.append(self.Dir('.').abspath + '/' + src)

	for file in sources:

		sobject = file[:-4] + self['OBJSUFFIX']
		if sobject in object_list:
			continue

		if (self.make_so):
			self.SharedObject(file[:-4], file)
		else:
			self.Object(file[:-4], file)

		object_list.append(sobject)


import re
pkg_re = re.compile("^[\t\w]*\$[cplih]file\s*\"([^\"]+)\"", re.M)

def pkg_scan_func(node, env, path):
	if str(node)[-4:] != ".pkg":
		return []
	dep_list = pkg_re.findall(node.get_contents())
	i=0
	while i<len(dep_list):
		if dep_list[i][:1] != '/':
			dep_list[i] = '#'+dep_list[i]
		i = i+1
	#print("list for "+str(node)+" is "+str(dep_list))
	return dep_list



def pkg_scan_dep(self, target, source):

	import re

	## TODO: detectar si el archivo existe antes de abrirlo asi nomas
	try:
		pkg = open(source, "rt")
	except:
		return
#	print "SOURCES: " + source

	for linea in pkg.xreadlines():
		#print "LINEA: " + linea
		#dep = re.search("^[\t\w]*\$[{<]([^}>]+)[}>]", linea)
		dep = re.search("^[\t\w]*\$[cpl]file\s*\"([^\"]+)\"", linea)
		if dep:
			self.Depends(target, "#" + dep.groups()[0]);
#			print "DEPENDENCIA: " + dep.groups()[0];

			if dep.groups()[0][-4:] == '.pkg':
				# recursividad
				self.pkg_scan_dep(target, dep.groups()[0])

def make_tolua_code(self, target, source, pkgname, list = None, custom_script = None, export_header = True):

	dir = self.Dir('.').path

	ptarget = dir + '/' + target
	psource = dir + '/' + source
	header = target[:-4] + '.h'
	pheader = dir + '/' + header

	custom = ""
	if custom_script:
		custom = " -L "+custom_script

	if 'msvc' in self['TOOLS']:
		sep = '\\'
	else:
		sep = '/'

	comando = '$TOLUAPP'
	if export_header:
		comando = comando + ' -H ' + pheader
	
	comando = comando + ' -o ' + ptarget + ' -n ' + pkgname + custom + ' ' + psource

	tfile = self.File('#'+ptarget)
	#tfile.target_scanner = self.pkgscan

	com = self.Command(tfile, '#' + psource, comando)

	self.Depends(com, source)
	if custom_script:
		if custom_script[0] == '/':
			self.Depends(com, custom_script)
		else:
			self.Depends(com, "#"+custom_script)

	if export_header:
		self.SideEffect('#' + pheader, '#' + ptarget)

	#self.pkg_scan_dep('#' + ptarget, psource)

	if list:
		self.make_targets(list, [target])
	return com

def moc_builder(self, source):

	outname = ""
	dir = self.Dir('.').path

	if source[-3:] == "cpp":
		outname = source[:-3]+"moc"
	else:
		outname = "moc_"+source

	return self.Command(outname, source, 'moc -o '+dir + '/' + outname+' '+dir + '/' + source)


def replace_pkg(target, source, env):

	pkg_in = open(str(source[0]), "rt").read()
	import re
	pkg_in = re.sub("\$QTDIR", env['QTDIR'], pkg_in)
	out = open(str(target[0]), "w")
	out.write(pkg_in)
	out.close()
