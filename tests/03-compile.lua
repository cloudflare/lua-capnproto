local util = require "capnp.util"
local lunit = require "lunitx"
local compile = require "capnp.compile"

if _VERSION >= 'Lua 5.2' then
    _ENV = lunit.module('simple','seeall')
else
    module( "simple", package.seeall, lunit.testcase )
end

function test_comp_calc_list_size()
    local res = {}
    local field = {
        name = "lt0",
        codeOrder = 22,
        discriminantValue = 65535,
        slot = {
          offset = 6,
          ["type"] = {
            list = {
              elementType = {text = "void"} } },
          defaultValue = {list = 'opaque pointer'},
          hadExplicitDefault = false },
        ordinal = {explicit = 25} }
    local name = string.format("data[\"%s\"]", field.name)
    local list_type = util.get_field_type(field)

    compile.comp_calc_list_size(res, field, {}, name, 1, select(2, unpack(list_type)))
    print(table.concat(res))
end
