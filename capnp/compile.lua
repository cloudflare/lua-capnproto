-----------------------------------------------------------------
-- lua-capnproto compiler
-- @copyright 2013-2016 Jiale Zhi (vipcalio@gmail.com)
-----------------------------------------------------------------

local cjson = require("cjson")
local encode = cjson.encode
local util = require "capnp.util"

local insert = table.insert
local concat = table.concat
local format = string.format
local lower  = string.lower
local gsub   = string.gsub
local sub    = string.sub

local debug = false
local NOT_UNION = 65535

local _M = {}

local missing_enums = {}

local config = {
    default_naming_func = util.lower_underscore_naming,
    default_enum_naming_func = util.upper_underscore_naming,
}


function _M.set_debug(_debug)
    debug = _debug
end

function dbg(...)
    if not debug then
        return
    end
    print(...)
end

function dbgf(...)
    if not debug then
        return
    end
    print(format(...))
end

function get_schema_text(file)
    local f = io.open(file)
    if not f then
        return nil, "Can't open file: " .. tostring(file)
    end

    local s = f:read("*a")
    f:close()

    s = string.gsub(s, "%(", "{")
    s = string.gsub(s, "%)", "}")
    s = string.gsub(s, "%[", "{")
    s = string.gsub(s, "%]", "}")
    s = string.gsub(s, "%<", "\"")
    s = string.gsub(s, "%>", "\"")
    s = string.gsub(s, "id = (%d+)", "id = \"%1\"")
    s = string.gsub(s, "typeId = (%d+)", "typeId = \"%1\"")
    s = string.gsub(s, "void", "\"void\"")
    return "return " .. s
end

function comp_header(res, nodes)
    dbg("compile_headers")
    insert(res, format([[
-- Generated by lua-capnproto %s on %s
-- https://github.com/cloudflare/lua-capnproto.git


]], config.version, os.date()))
    insert(res, format([[
local ffi = require "ffi"
local capnp = require "capnp"
local bit = require "bit"

local ceil              = math.ceil
local write_struct_field= capnp.write_struct_field
local read_struct_field = capnp.read_struct_field
local read_text         = capnp.read_text
local write_text        = capnp.write_text
local get_enum_val      = capnp.get_enum_val
local get_enum_name     = capnp.get_enum_name
local get_data_off      = capnp.get_data_off
local write_listp_buf   = capnp.write_listp_buf
local write_structp_buf = capnp.write_structp_buf
local write_structp     = capnp.write_structp
local read_struct_buf   = capnp.read_struct_buf
local read_listp_struct = capnp.read_listp_struct
local read_list_data    = capnp.read_list_data
local write_list        = capnp.write_list
local write_list_data   = capnp.write_list_data
local ffi_new           = ffi.new
local ffi_string        = ffi.string
local ffi_cast          = ffi.cast
local ffi_copy          = ffi.copy
local ffi_fill          = ffi.fill
local ffi_typeof        = ffi.typeof
local band, bor, bxor = bit.band, bit.bor, bit.bxor

local pint8    = ffi_typeof("int8_t *")
local pint16   = ffi_typeof("int16_t *")
local pint32   = ffi_typeof("int32_t *")
local pint64   = ffi_typeof("int64_t *")
local puint8   = ffi_typeof("uint8_t *")
local puint16  = ffi_typeof("uint16_t *")
local puint32  = ffi_typeof("uint32_t *")
local puint64  = ffi_typeof("uint64_t *")
local pbool    = ffi_typeof("uint8_t *")
local pfloat32 = ffi_typeof("float *")
local pfloat64 = ffi_typeof("double *")


local ok, new_tab = pcall(require, "table.new")

if not ok then
    new_tab = function (narr, nrec) return {} end
end

local round8 = function(size)
    return ceil(size / 8) * 8
end

local str_buf
local default_segment_size = 4096

local function get_str_buf(size)
    if size > default_segment_size then
        return ffi_new("char[?]", size)
    end

    if not str_buf then
        str_buf = ffi_new("char[?]", default_segment_size)
    end
    return str_buf
end

-- Estimated from #nodes, not accurate
local _M = new_tab(0, %d)

]], #nodes))
end

function get_name(display_name)
    local n = string.find(display_name, ":")
    return string.sub(display_name, n + 1)
end

--- @see http://kentonv.github.io/_Mroto/encoding.html#lists
local list_size_map = {
    [0] = 0,
    [1] = 0.125,
    [2] = 1,
    [3] = 2,
    [4] = 4,
    [5] = 8,
    [6] = 8,
    -- 7 = ?,
}

local size_map = {
    void    = 0,
    bool    = 1,
    int8    = 8,
    int16   = 16,
    int32   = 32,
    int64   = 64,
    uint8   = 8,
    uint16  = 16,
    uint32  = 32,
    uint64  = 64,
    float32 = 32,
    float64 = 64,
    text    = "2", -- list(uint8)
    data    = "2",
    list    = 2, -- size: list item size id, not actual size
    struct  = 8,  -- struct pointer
    enum    = 16,
    object  = 8, -- FIXME object is a pointer ?
    anyPointer = 8, -- FIXME object is a pointer ?
    group   = 0, -- TODO
}

local check_type = {
    struct = 'type(value) == "table"',
    group = 'type(value) == "table"',
    enum = 'type(value) == "string" or type(value) == "number"',
    list = 'type(value) == "table"',
    text = 'type(value) == "string"',
    data = 'type(value) == "string"',
}


function get_size(type_name)
    local size = size_map[type_name]
    if not size then
        error("Unknown type_name:" .. type_name)
    end

    return size
end

function _set_field_default(nodes, field, slot)
    local default
    if slot.defaultValue
            and field.type_name ~= "object"
            and field.type_name ~= "anyPointer"
    then

        for k, v in pairs(slot.defaultValue) do
            if field.type_name == "bool" then
                field.print_default_value = v and 1 or 0
                field.default_value = field.print_default_value
            elseif field.type_name == "text" or field.type_name == "data" then
                field.print_default_value = '"' .. v .. '"'
                field.default_value = field.print_default_value
            elseif field.type_name == "struct" or field.type_name == "list"
                    or field.type_name == "object"
                    or field.type_name == "anyPointer"
            then
                field.print_default_value = '"' .. v .. '"'
            elseif field.type_name == "void" then
                field.print_default_value = "\"Void\""
                field.default_value = field.print_default_value
            elseif field.type_name == "enum" then
                local enum = assert(nodes[slot["type"].enum.typeId].enum)
                field.print_default_value = '"' .. enum.enumerants[v + 1].name
                        .. '"'

                field.default_value = v
            else
                field.print_default_value = v
                field.default_value = field.print_default_value
            end
            break
        end
        dbgf("[%s] %s.print_default_value=%s", field.type_name, field.name,
                field.print_default_value)
    end
    if not field.default_value then
        field.default_value = "Nil"
    end
    if not field.print_default_value then
        field.print_default_value = "Nil"
    end
end

function _get_type(type_field)
    local type_name
    for k, v in pairs(type_field) do
        type_name = k
        break
    end
    return type_name
end

function _set_field_type(field, slot, nodes)
    local type_name
    if field.group then
        field.type_name = "group"
        field.type_display_name = get_name(
                nodes[field.group.typeId].displayName)
    else
        for k, v in pairs(slot["type"]) do
            type_name   = k
            if type_name == "struct" then
                field.type_display_name = get_name(nodes[v.typeId].displayName)
            elseif type_name == "enum" then
                field.enum_id = v.typeId
                field.type_display_name = get_name(nodes[v.typeId].displayName)
            elseif type_name == "list" then
                local list_type
                for k, v in pairs(field.slot["type"].list.elementType) do
                    list_type = k
                    if list_type == "struct" then
                        field.type_display_name = get_name(
                                nodes[v.typeId].displayName)
                    end
                    break
                end
                field.element_type = list_type
            else
                -- default     = v
            end

            field.type_name = type_name
            --field.default   = default

            break
        end
    end
    dbgf("field %s.type_name = %s", field.name, field.type_name)
    assert(field.type_name)
end

function comp_field(res, nodes, field)
    dbg("comp_field")
    local slot = field.slot
    if not slot then
        slot = {}
        field.slot = slot
    end
    if not slot.offset then
        slot.offset = 0
    end

    field.name = config.default_naming_func(field.name)

    _set_field_type(field, slot, nodes)
    _set_field_default(nodes, field, slot)

    -- print("default:", field.name, field.default_value)
    if not field.type_name then
        field.type_name = "void"
        field.size = 0
    else
        field.size      = get_size(field.type_name)
    end
end

local function process_list_type(list_type, nodes)
    -- first one is not element type, so remove it
    --table.remove(list_type, 1)
    if list_type[#list_type - 1] == "struct" then
        local id = list_type[#list_type]
        local struct_name = get_name(nodes[id].displayName)
        for i=1, #list_type - 1 do
            list_type[i] = '"' .. list_type[i] .. '"'
        end
        list_type[#list_type] = "_M." .. struct_name
    else
        for i, v in ipairs(list_type) do
            list_type[i] = '"' .. v .. '"'
        end
    end
end

function comp_parse_struct_data(res, nodes, struct, fields, size, name)
    insert(res, format([[

    parse_struct_data = function(p32, data_word_count, pointer_count, header,
            tab)

        local s = tab
]], size))

    if struct.discriminantCount and struct.discriminantCount > 0 then
        insert(res, format([[

        local dscrm = _M.%s.which(p32, %d)]], name, struct.discriminantOffset))
    end

    for i, field in ipairs(fields) do
        if field.discriminantValue and field.discriminantValue ~= NOT_UNION then
            insert(res, format([[

        -- union
        if dscrm == %d then
]],field.discriminantValue))

        end
        if field.group then
            insert(res, format([[

        -- group
        if not s["%s"] then
            s["%s"] = new_tab(0, 4)
        end
        _M.%s["%s"].parse_struct_data(p32, _M.%s.dataWordCount,
                _M.%s.pointerCount, header, s["%s"])
]], field.name, field.name, name, field.name, name, name, field.name))

        elseif field.type_name == "enum" then
            insert(res, format([[

        -- enum
        local val = read_struct_field(p32, "uint16", %d, %d)
        s["%s"] = get_enum_name(val, %d, _M.%sStr)
]], field.size, field.slot.offset, field.name, field.default_value,
                field.type_display_name))

        elseif field.type_name == "list" then
            local off = field.slot.offset
            local list_type = util.get_field_type(field)
            table.remove(list_type, 1)
            process_list_type(list_type, nodes)

            local types = concat(list_type, ", ")

            insert(res, format([[

        -- list
        local off, size, num = read_listp_struct(p32, header, _M.%s, %d)
        if off and num then
            -- dataWordCount + offset + pointerSize + off
            s["%s"] = read_list_data(p32 + (%d + %d + 1 + off) * 2, header,
                    num, %s)
        else
            s["%s"] = nil
        end
]], name, off, field.name, struct.dataWordCount, off, types, field.name))

        elseif field.type_name == "struct" then
            local off = field.slot.offset

            insert(res, format([[

        -- struct
        local p = p32 + (%d + %d) * 2 -- p32, dataWordCount, offset
        local off, dw, pw = read_struct_buf(p, header)
        if off and dw and pw then
            if not s["%s"] then
                s["%s"] = new_tab(0, 2)
            end
            _M.%s.parse_struct_data(p + 2 + off * 2, dw, pw, header, s["%s"])
        else
            s["%s"] = nil
        end
]], struct.dataWordCount, off, field.name, field.name, field.type_display_name,
            field.name, field.name))

        elseif field.type_name == "text" then
            local off = field.slot.offset
            insert(res, format([[

        -- text
        local off, size, num = read_listp_struct(p32, header, _M.%s, %d)
        if off and num then
            -- dataWordCount + offset + pointerSize + off
            local p8 = ffi_cast(pint8, p32 + (%d + %d + 1 + off) * 2)
            s["%s"] = ffi_string(p8, num - 1)
        else
            s["%s"] = nil
        end
]], name, off, struct.dataWordCount, off, field.name, field.name))

        elseif field.type_name == "data" then
            local off = field.slot.offset
            insert(res, format([[

        -- data
        local off, size, num = read_listp_struct(p32, header, _M.%s, %d)
        if off and num then
            -- dataWordCount + offset + pointerSize + off
            local p8 = ffi_cast(pint8, p32 + (%d + %d + 1 + off) * 2)
            s["%s"] = ffi_string(p8, num)
        else
            s["%s"] = nil
        end
]], name, off, struct.dataWordCount, off, field.name, field.name))

        elseif field.type_name == "anyPointer" then
            -- TODO support anyPointer
        elseif field.type_name == "void" then
            insert(res, format([[

        s["%s"] = "Void"]], field.name))
        else
            local default = field.default_value and field.default_value or "nil"
            insert(res, format([[

        s["%s"] = read_struct_field(p32, "%s", %d, %d, %s)
]], field.name, field.type_name, field.size, field.slot.offset, default))

        end

        if field.discriminantValue and field.discriminantValue ~= NOT_UNION then
            insert(res, format([[

        else
            s["%s"] = nil
        end
]],field.name))
        end
    end

    insert(res, [[

        return s
    end,
]])
end

function comp_parse(res, name)
    insert(res, format([[

    parse = function(bin, tab)
        if #bin < 16 then
            return nil, "message too short"
        end

        local header = new_tab(0, 4)
        local p32 = ffi_cast(puint32, bin)
        header.base = p32

        local nsegs = p32[0] + 1
        header.seg_sizes = {}
        for i=1, nsegs do
            header.seg_sizes[i] = p32[i]
        end
        local pos = round8(4 + nsegs * 4)
        header.header_size = pos / 8
        p32 = p32 + pos / 4

        if not tab then
            tab = new_tab(0, 8)
        end
        local off, dw, pw = read_struct_buf(p32, header)
        if off and dw and pw then
            return _M.%s.parse_struct_data(p32 + 2 + off * 2, dw, pw,
                    header, tab)
        else
            return nil
        end
    end,
]], name))
end

function comp_serialize(res, name)
    insert(res, format([[

    -- Serialize and return pointer to char[] and size
    serialize_cdata = function(data, p8, size)
        if p8 == nil then
            size = _M.%s.calc_size(data)

            p8 = get_str_buf(size)
        end
        ffi_fill(p8, size)
        local p32 = ffi_cast(puint32, p8)

        -- Because needed size has been calculated, only 1 segment is needed
        p32[0] = 0
        p32[1] = (size - 8) / 8

        -- skip header
        write_structp(p32 + 2, _M.%s, 0)

        -- skip header & struct pointer
        _M.%s.flat_serialize(data, p32 + 4)

        return p8, size
    end,

    serialize = function(data, p8, size)
        p8, size = _M.%s.serialize_cdata(data, p8, size)
        return ffi_string(p8, size)
    end,
]], name, name, name, name))
end

function comp_flat_serialize(res, nodes, struct, fields, size, name)
    dbgf("comp_flat_serialize")
    insert(res, format([[

    flat_serialize = function(data, p32, pos)
        pos = pos and pos or %d -- struct size in bytes
        local start = pos
        local dscrm]], size))

    insert(res, [[

        local value]])

    for i, field in ipairs(fields) do
        insert(res, format([=[


        value = data["%s"]]=], field.name))
        --print("comp_field", field.name)
        -- union
        if field.discriminantValue and field.discriminantValue ~= NOT_UNION then
            dbgf("field %s: union", field.name)
            insert(res, format([[

        if value then
            dscrm = %d
        end
]], field.discriminantValue))
        end
        if field.group then
            dbgf("field %s: group", field.name)
            -- group size is the same as the struct, so we can use "size" to
            -- represent group size

            insert(res, format([[

        if ]] .. check_type["group"] .. [[ then
            -- groups are just namespaces, field offsets are set within parent
            -- structs
            pos = pos + _M.%s.%s.flat_serialize(value, p32, pos) - %d
        end
]], name, field.name, size))

        elseif field.type_name == "enum" then
            dbgf("field %s: enum", field.name)
            insert(res, format([[

        if ]] .. check_type["enum"] .. [[ then
            local val = get_enum_val(value, %d, _M.%s, "%s.%s")
            write_struct_field(p32, val, "uint16", %d, %d)
        end]], field.default_value, field.type_display_name, name,
                    field.name, field.size, field.slot.offset))

        elseif field.type_name == "list" then
            dbgf("field %s: list", field.name)
            local off = field.slot.offset
            local list_type = util.get_field_type(field)
            -- nested list
            if #list_type > 1 then
                -- composite
                if list_type[#list_type -1] == "struct" then
                    field.size = 7
                else
                    -- pointer
                    field.size = 6
                end
            end
            process_list_type(list_type, nodes)

            local types = concat(list_type, ", ")

            insert(res, format([[

        if ]] .. check_type["list"] .. [[ then
            local data_off = get_data_off(_M.%s, %d, pos)
            pos = pos + write_list(p32 + _M.%s.dataWordCount * 2 + %d * 2,
                    value, (data_off + 1) * 8, %s)
        end]], name, off, name, off, types))

        elseif field.type_name == "struct" then
            dbgf("field %s: struct", field.name)
            local off = field.slot.offset
            insert(res, format([[

        if ]] .. check_type["struct"] .. [[ then
            local data_off = get_data_off(_M.%s, %d, pos)
            write_structp_buf(p32, _M.%s, _M.%s, %d, data_off)
            local size = _M.%s.flat_serialize(value, p32 + pos / 4)
            pos = pos + size
        end]], name, off, name, field.type_display_name,
                    off, field.type_display_name))

        elseif field.type_name == "text" then
            dbgf("field %s: text", field.name)
            local off = field.slot.offset
            insert(res, format([[

        if ]] .. check_type["text"] .. [[ then
            local data_off = get_data_off(_M.%s, %d, pos)

            local len = #value + 1
            write_listp_buf(p32, _M.%s, %d, %d, len, data_off)

            ffi_copy(p32 + pos / 4, value)
            pos = pos + round8(len)
        end]], name, off, name, off, 2))

        elseif field.type_name == "data" then
            dbgf("field %s: data", field.name)
            local off = field.slot.offset
            insert(res, format([[

        if ]] .. check_type["data"] .. [[ then
            local data_off = get_data_off(_M.%s, %d, pos)

            local len = #value
            write_listp_buf(p32, _M.%s, %d, %d, len, data_off)

            -- prevent copying trailing '\0'
            ffi_copy(p32 + pos / 4, value, len)
            pos = pos + round8(len)
        end]], name, off, name, off, 2))

        else
            dbgf("field %s: %s", field.name, field.type_name)
            local default = field.default_value and field.default_value or "nil"
            local cdata_condition = ""
            if field.type_name == "uint64" or field.type_name == "int64" then
                cdata_condition = 'or data_type == "cdata"'
            end
            if field.type_name ~= "void" then
                insert(res, format([[

        local data_type = type(value)
        if (data_type == "number"
                or data_type == "boolean" %s) then

            write_struct_field(p32, value, "%s", %d, %d, %s)
        end]], cdata_condition, field.type_name, field.size,
                    field.slot.offset, default))
            end
        end

    end

    if struct.discriminantCount and struct.discriminantCount ~= 0 then
        insert(res, format([[

        if dscrm then
            --buf, discriminantOffset, discriminantValue
            _M.%s.which(p32, %d, dscrm)
        end
]],  name, struct.discriminantOffset))
    end

    insert(res, format([[

        return pos - start + %d
    end,
]], size))
end

-- insert a list with indent level
function insertlt(res, level, data_table)
    for i, v in ipairs(data_table) do
        insertl(res, level, v)
    end
end

-- insert with indent level
function insertl(res, level, data)
    for i=1, level * 4 do
        insert(res, " ")
    end
    insert(res, data)
end

function _M.comp_calc_list_size(res, field, nodes, name, level, elm_type, ...)
    if not elm_type then
        return
    end

    insertl(res, level, format("if %s and " ..
            "type(%s) == \"table\" then\n", name, name))

    if elm_type == "object" or elm_type == "anyPointer"
        or elm_type == "group" then

        error("List of object/anyPointer/group type is not supported yet.")
    end

    if elm_type ~= "struct" and elm_type ~= "list" and elm_type ~= "data"
            and elm_type ~= "text" then

        -- elm_type is a plain type.
        local elm_size = get_size(elm_type) / 8
        insertlt(res, level + 1, {
            "-- num * acutal size\n",
            format("size = size + round8(#%s * %d)\n",
                name, elm_size)
            })
    else
        -- struct tag
        if elm_type == "struct" then
            insertl(res, level + 1, format("size = size + 8\n"))
        end

        local new_name = name .. "[i" .. level .. "]"
        -- calculate body size
        insertl(res, level + 1, format("local num%d = #%s\n",
                level, name))
        insertl(res, level + 1, format("for %s=1, num%d do\n",
                "i" .. level, level))

        if elm_type == "list" then
            insertl(res, level + 2, format("size = size + 8\n"))
            _M.comp_calc_list_size(res, field, nodes, new_name, level + 2, ...)
        elseif elm_type == "text" then
            insertl(res, level + 2, format("size = size + 8\n"))
            insertlt(res, level + 2, {
                " -- num * acutal size\n",
                format("size = size + round8(#%s * 1 + 1)\n", new_name)
            })
        elseif elm_type == "data" then
            insertl(res, level + 2, format("size = size + 8\n"))
            insertlt(res, level + 2, {
                " -- num * acutal size\n",
                format("size = size + round8(#%s * 1)\n", new_name)
            })
        elseif elm_type == "struct" then
            local id = ...
            local struct_name = get_name(nodes[id].displayName)
            insertl(res, level + 2, format(
                    "size = size + _M.%s.calc_size_struct(%s)\n",
                    struct_name, new_name))
        end
        insertl(res, level + 1, "end\n")
    end
    insertl(res, level, "end")
end

function comp_calc_size(res, fields, size, name, nodes, is_group)
    dbgf("comp_calc_size")
    if is_group then
        size = 0
    end
    insert(res, format([[

    calc_size_struct = function(data)
        local size = %d]], size))

    insert(res, [[

        local value]])

    for i, field in ipairs(fields) do
        dbgf("field %s is %s", field.name, field.type_name)

        if field.type_name == "list" then
            local list_type = util.get_field_type(field)

            insert(res, "\n")
            -- list_type[1] must be "list" and should be skipped because is
            -- is not element type
            insert(res, "        -- list\n")
            _M.comp_calc_list_size(res, field, nodes,
                    format("data[\"%s\"]", field.name), 2,
                    select(2, unpack(list_type)))
        elseif field.type_name == "struct" or field.type_name == "group" then
            insert(res, format([[

        -- struct
        value = data["%s"]
        if ]] .. check_type["struct"] .. [[ then
            size = size + _M.%s.calc_size_struct(value)
        end]], field.name, field.type_display_name))

        elseif field.type_name == "text" then
            insert(res, format([[

        -- text
        value = data["%s"]
        if ]] .. check_type["text"] .. [[ then
            -- size 1, including trailing NULL
            size = size + round8(#value + 1)
        end]], field.name))

        elseif field.type_name == "data" then
            insert(res, format([[

        -- data
        value = data["%s"]
        if ]] .. check_type["data"] .. [[ then
            size = size + round8(#value)
        end]], field.name))

        end

    end

    insert(res, format([[

        return size
    end,

    calc_size = function(data)
        local size = 16 -- header + root struct pointer
        return size + _M.%s.calc_size_struct(data)
    end,
]], name))
end

function comp_which(res)
    insert(res, [[

    which = function(buf, offset, n)
        if n then
            -- set value
            write_struct_field(buf, n, "uint16", 16, offset)
        else
            -- get value
            return read_struct_field(buf, "uint16", 16, offset)
        end
    end,
]])
end

function comp_fields(res, nodes, node, struct)
    insert(res, [[

    fields = {
]])
    for i, field in ipairs(struct.fields) do
        comp_field(res, nodes, field)
        if field.group then
            if not node.nestedNodes then
                node.nestedNodes = {}
            end
            insert(node.nestedNodes,
                    { name = field.name, id = field.group.typeId })
        end
        insert(res, format([[
        { name = "%s", default = %s, ["type"] = "%s" },
]], field.name, field.print_default_value, field.type_name))
    end
    dbg("struct:", name)
    insert(res, format([[
    },
]]))
end

function comp_struct(res, nodes, node, struct, name)

    if not struct.dataWordCount then
        struct.dataWordCount = 0
    end
    if not struct.pointerCount then
        struct.pointerCount = 0
    end

    insert(res, "    dataWordCount = ")
    insert(res, struct.dataWordCount)
    insert(res, ",\n")

    insert(res, "    pointerCount = ")
    insert(res, struct.pointerCount)
    insert(res, ",\n")

    if struct.discriminantCount then
        insert(res, "    discriminantCount = ")
        insert(res, struct.discriminantCount)
        insert(res, ",\n")
    end
    if struct.discriminantOffset then
        insert(res, "    discriminantOffset = ")
        insert(res, struct.discriminantOffset)
        insert(res, ",\n")
    end
    if struct.isGroup then
        insert(res, "    isGroup = true,\n")
    end

    struct.size = struct.dataWordCount * 8 + struct.pointerCount * 8

    if struct.fields then
        insert(res, "    field_count = ")
        insert(res, #struct.fields)
        insert(res, ",\n")

        comp_fields(res, nodes, node, struct)
        --if not struct.isGroup then

        --end
        comp_calc_size(res, struct.fields, struct.size,
                struct.type_name, nodes, struct.isGroup)
        comp_flat_serialize(res, nodes, struct, struct.fields, struct.size,
                struct.type_name)
        if not struct.isGroup then
            comp_serialize(res, struct.type_name)
        end
        if struct.discriminantCount and struct.discriminantCount > 0 then
            comp_which(res)
        end
        comp_parse_struct_data(res, nodes, struct, struct.fields,
                struct.size, struct.type_name)
        if not struct.isGroup then
            comp_parse(res, struct.type_name)
        end
    end
end

function comp_enum(res, nodes, enum, name, enum_naming_func)
    if not enum_naming_func then
        enum_naming_func = config.default_enum_naming_func
    end

    -- string to enum
    insert(res, format([[

_M.%s = {
]], name))

    for i, v in ipairs(enum.enumerants) do
        -- inherent parent naming function
        v.naming_func = enum_naming_func

        if not v.codeOrder then
            v.codeOrder = 0
        end

        if v.annotations then
            local anno_res = {}
            dbgf("%s annotations: %s", name, cjson.encode(v.annotations))
            process_annotations(v.annotations, nodes)

            for i, anno in ipairs(v.annotations) do
                if anno.name == "naming" then
                    v.naming_func = get_naming_func(anno.value)
                    dbgf("Naming function: %s", anno.value)
                    if not v.naming_func then
                        error("Unknown naming annotation: " .. anno.value)
                    end
                elseif anno.name == "literal" then
                    dbgf("enumerant literal: %s", anno.value)
                    v.literal = anno.value
                end
            end
        end

        -- literal has higher priority
        if v.literal then
            insert(res, format("    [\"%s\"] = %s,\n",
                v.literal, v.codeOrder))
        else
            insert(res, format("    [\"%s\"] = %s,\n",
                v.naming_func(v.name), v.codeOrder))
        end
    end
    insert(res, "\n}\n")

    -- enum to string
    insert(res, format([[

_M.%sStr = {
]], name))

    for i, v in ipairs(enum.enumerants) do
        if not v.codeOrder then
            v.codeOrder = 0
        end
        if v.literal then
            insert(res, format("    [%s] = \"%s\",\n",
                     v.codeOrder, v.literal))
        else
            insert(res, format("    [%s] = \"%s\",\n",
                     v.codeOrder, v.naming_func(v.name)))
        end
    end
    insert(res, "\n}\n")
end

_M.naming_funcs = {
    upper_dash       = util.upper_dash_naming,
    lower_underscore = util.lower_underscore_naming,
    upper_underscore = util.upper_underscore_naming,
    camel            = util.camel_naming,
    lower_space      = util.lower_space_naming,
}

function process_annotations(annos, nodes)
    dbg("process_annotations:" .. encode(annos))
    for i, anno in ipairs(annos) do
        local id = anno.id
        anno.name = get_name(nodes[id].displayName)
        anno.value_saved = anno.value
        assert(type(anno.value_saved) == "table", 'expected "table" but got "'
            .. type(anno.value_saved) .. "\": " .. tostring(anno.value_saved))

        for k, v in pairs(anno.value_saved) do
            anno["type"] = k
            anno["value"] = v
            break
        end
        anno.value_saved = nil
    end
end

function get_naming_func(name)
    local func =  _M.naming_funcs[name]
    if not func then
        error("unknown naming: " .. tostring(name))
    end

    return func
end

function comp_node(res, nodes, node, name)
    dbgf("comp_node: %s, %s", name, node.id)
    if not node then
        print("Ignore node: ", name)
        return
    end

    if node.annotation then
        -- do not need to generation any code for annotations
        return
    end

    node.name = name
    node.type_name = get_name(node.displayName)

    local s = node.struct
    if s then

    insert(res, format([[

_M.%s = {
]], name))
        s.type_name = node.type_name
        insert(res, format([[
    id = "%s",
    displayName = "%s",
]], node.id, node.displayName))
        comp_struct(res, nodes, node, s, name)
    insert(res, "\n}\n")
    end

    local e = node.enum
    if e then
        local anno_res = {}
        if node.annotations then
            process_annotations(node.annotations, nodes)
        end

        local naming_func
        if node.annotations then
            for i, anno in ipairs(node.annotations) do
                if anno.name == "naming" then
                    naming_func = get_naming_func(anno.value)
                end
                break
            end
        end
        comp_enum(res, nodes, e, name, naming_func)
    end

    if node.const then
        dbgf("compile const: %s", name)
        local const = node.const
        local const_type = _get_type(const["type"])

        if const_type == "text" or const_type == "data" or const_type == "void"
           or const_type == "list" or const_type == "struct"
           or const_type == "enum" or const_type == "group"
           or const_type == "anyPointer"
        then
            insert(res, format([[

_M.%s = "%s"
]], name, const.value[const_type]))
        else
            insert(res, format([[

_M.%s = %s
]], name, const.value[const_type]))

        end
    end

    if node.nestedNodes then
        for i, child in ipairs(node.nestedNodes) do
            comp_node(res, nodes, nodes[child.id], name .. "." .. child.name)
        end
    end
end

function comp_body(res, schema)
    dbg("comp_body")
    local nodes = schema.nodes
    for i, v in ipairs(nodes) do
        nodes[v.id] = v
    end

    local files = schema.requestedFiles

    for i, file in ipairs(files) do
        comp_file(res, nodes, file)

        local imports = file.imports
        for i, import in ipairs(imports) do
            --import node are compiled later by comp_file
            --comp_import(res, nodes, import)
            check_import(files, import)
        end
    end

    for k, v in pairs(missing_enums) do
        insert(res, k .. ".enum_schema = _M." ..
                get_name(nodes[v].displayName .. "\n"))
    end

    insert(res, "\nreturn _M\n")
end

function check_import(files, import)
    local id = import.id
    local name = import.name

    for i, file in ipairs(files) do
        if file.id == id then
            return true
        end
    end

    error('imported file "' .. name .. '" is missing, compile it together with'
        .. ' other Cap\'n Proto files')
end

function comp_import(res, nodes, import)
    local id = import.id

    dbgf("comp_import: %s", id)

    local import_node = nodes[id]
    for i, node in ipairs(import_node.nestedNodes) do
        comp_node(res, nodes, nodes[node.id], node.name)
    end
end

function comp_file(res, nodes, file)
    dbg("comp_file")
    local id = file.id

    local file_node = nodes[id]
    for i, node in ipairs(file_node.nestedNodes) do
        comp_node(res, nodes, nodes[node.id], node.name)
    end
end

function comp_dg_node(res, nodes, node)
    if not node.struct then
        return
    end

    local name = gsub(lower(node.name), "%.", "_")
    insert(res, format([[
function gen_%s()
    if rand.random_nil() then
        return nil
    end

]], name))

    if node.nestedNodes then
        for i, child in ipairs(node.nestedNodes) do
            comp_dg_node(res, nodes, nodes[child.id])
        end
    end

    insert(res, format("    local %s  = {}\n", name))
    for i, field in ipairs(node.struct.fields) do
        if field.group then
            -- TODO group stuffs
        elseif field.type_name == "struct" then
            insert(res, format("    %s.%s = gen_%s()\n", name,
                    field.name,
                    gsub(lower(field.type_display_name), "%.", "_")))

        elseif field.type_name == "enum" then
        elseif field.type_name == "list" then
            local list_type = field.element_type
            insert(res, format([[
    %s["%s"] = rand.%s(rand.uint8(), rand.%s)]], name,
                    field.name, field.type_name, list_type))

        else
            insert(res, format('    %s["%s"] = rand.%s()\n', name,
                    field.name, field.type_name))
        end
    end


    insert(res, format([[
    return %s
end

]], name))
end

function _M.compile_data_generator(schema)
    local res = {}
    insert(res, [[

local rand = require("random")
local cjson = require("cjson")
local pairs = pairs

local ok, new_tab = pcall(require, "table.new")

if not ok then
    new_tab = function (narr, nrec) return {} end
end

module(...)
]])

    local files = schema.requestedFiles
    local nodes = schema.nodes

    for i, file in ipairs(files) do
        local file_node = nodes[file.id]

        for i, node in ipairs(file_node.nestedNodes) do
            comp_dg_node(res, nodes, nodes[node.id])
        end
    end

    return table.concat(res)
end

function _M.compile(schema)
    local res = {}

    comp_header(res, schema.nodes)
    comp_body(res, schema)

    return table.concat(res)
end

function _M.init(user_conf)
    dbg("set config init")
    for k, v in pairs(user_conf) do
        --if not config[k] then
        --    print(format("Unknown user config: %s, ignored.", k))
        --end
        config[k] = v
        dbg("set config " .. k)
    end
end

return _M
