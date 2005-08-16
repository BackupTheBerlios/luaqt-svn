## The lua libraries. On debian, they are called '...lua50'
lua_libs = ['lua50', 'lualib50']

## On debian, the lua headers are on lua50/
extra_cxx_flags = ['-I/usr/include/lua50']
