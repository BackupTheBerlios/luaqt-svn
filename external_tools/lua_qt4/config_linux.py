## The lua libraries. On debian, they are called '...lua5.1'
lua_libs = ['lua5.1'] # we don't link with lua, the symbols should be exported by the host program

## The tolua++ libraries, default is ['tolua++5.1']
#tolua_libs = ['tolua++5.1']


## On debian, the lua headers are on lua50/
extra_cxx_flags = ['-I/usr/include/lua5.1']
