-----------------------------------------------------------
-- lua-capnproto runtime module.
-- @copyright 2013-2014 Jiale Zhi (vipcalio@gmail.com)
-----------------------------------------------------------

local ffi = require "ffi"
local bit = require "bit"

local arshift           = bit.arshift
local lshift, rshift    = bit.lshift, bit.rshift
local band, bor, bxor   = bit.band, bit.bor, bit.bxor

local typeof    = ffi.typeof
local cast      = ffi.cast
local ffistr    = ffi.string
local copy      = ffi.copy
local ceil      = math.ceil
local floor     = math.floor
local type      = type
local error     = error

-- Only works with Little Endian for now
assert(ffi.abi("le") == true)
assert(ffi.sizeof("float") == 4)
assert(ffi.sizeof("double") == 8)


local bfloat32 = ffi.new('float[?]', 2)
local bfloat64 = ffi.new('double[?]', 3)
local bint32   = ffi.new('int[?]', 2)
local buint64  = ffi.new('uint64_t[?]', 2)

local round8 = function(size)
    return ceil(size / 8) * 8
end


-- table.new(narr, nrec)
local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function () return {} end
end


local _M = new_tab(0, 32)


local pint32   = typeof("int32_t *")
local puint32  = typeof("uint32_t *")
local puint64  = typeof("uint64_t *")
local pfloat32 = typeof("float *")
local pfloat64 = typeof("double *")

local pointer_map = {
    int8    = typeof("int8_t *"),
    int16   = typeof("int16_t *"),
    int32   = typeof("int32_t *"),
    int64   = typeof("int64_t *"),
    uint8   = typeof("uint8_t *"),
    uint16  = typeof("uint16_t *"),
    uint32  = typeof("uint32_t *"),
    uint64  = typeof("uint64_t *"),
    bool    = typeof("uint8_t *"),
    float32 = typeof("float *"),
    float64 = typeof("double *"),
}

--- Calculate offset within size
-- @param bit_off       offset in bits
-- @param size          size in bits
-- @return              n: number of size-long space
-- @return              s: offset within a size-long space
local function get_bit_offset(bit_off, size)
    local n, s
    n = floor(bit_off / size)
    s = bit_off % size

    return n, s
end

--- Get a pointer cdata from a int32 pointer and a Cap'n Proto type
-- @param p32           int32 pointer
-- @param field_type    Cap'n Proto type string
-- @return              pointer cdata
local function get_pointer_from_type(p32, field_type)
    local t = pointer_map[field_type]
    if not t then
        error("not supported type: " .. field_type)
    end

    return cast(t, p32)
end

--- Use LuaJIT FFI to calculate xor for float number
-- @param val       input float32 number
-- @param default   its default value
-- @return          xor'ed value
function _M.fix_float32_default(val, default)
    local float
    bfloat32[0] = default
    bfloat32[1] = val

    -- default float value
    local uint_def = cast(puint32, bfloat32)
    local uint_val = cast(puint32, bfloat32 + 1)
    val = bxor(uint_val[0], uint_def[0])
    bint32[0] = val
    float = cast(pfloat32, bint32)
    return float[0]
end

--- Use LuaJIT FFI to calculate xor for float number
-- @param val       input float64 number
-- @param default   its default value
-- @return          xor'ed value
function _M.fix_float64_default(val, default)
    local float
    bfloat64[0] = default
    bfloat64[1] = val
    local uint_def = cast(puint64, bfloat64)
    local uint_val = cast(puint64, bfloat64 + 1)
    val = bxor(uint_val[0], uint_def[0])
    buint64[0] = val
    float = cast(pfloat64, buint64)
    return float[0]
end

--- Read a structure field
-- @param p32           a int32 pointer points to the start of a struct
-- @param field_type    struct field type
-- @param size          field size in bits
-- @param off           field offset (from parsed schema)
-- @param default       field default value
-- @return              parsed field
function _M.read_struct_field(p32, field_type, size, off, default)
    if field_type == "void" then
        return "Void"
    end

    local p = get_pointer_from_type(p32, field_type)

    local val
    if size >= 8 then
        local n, s = get_bit_offset(size * off, size)
        val = p[n]
    else
        local n, s = get_bit_offset(size * off, 8)
        local mask = 2^size - 1
        mask = lshift(mask, s)
        val = rshift(band(mask, p[n]), s)
    end

    if default then
        if field_type == "float32" then
            val = _M.fix_float32_default(val, default)
        elseif field_type == "float64" then
            val = _M.fix_float64_default(val, default)
        else
            val = bxor(val, default)
        end
    end

    if field_type == "bool" then
        if val and val ~= 0 then
            return true
        else
            return false
        end
    end

    if field_type == "int64" or field_type == "uint64" then
        return val
    elseif field_type == "uint32" then
        -- uint32 is treated as signed int32 by bit operations
        if val < 0 then
            val = 2^32 + val
        end
        return val
    else
        return val
    end
end

--- Write a bit (boolean value)
function _M.write_bit(p8, val, bit_off, default)
    if type(val) == "boolean" then
        val = val and 1 or 0
    end
    if default then
        val = bxor(val, default)
    end
    p8[0] = bor(p8[0], lshift(val, bit_off))
end

--- Write a number
function _M.write_num(p, val, field_type, default)
    if default then
        if field_type == "float32" then
            val = _M.fix_float32_default(val, default)
        elseif field_type == "float64" then
            val = _M.fix_float64_default(val, default)
        else
            if default ~= 0 then
                val = bxor(val, default)
            end
        end
    end
    p[0] = val
end

--- Write a structure field
-- @param p32           a int32 pointer points to the start of a struct
-- @param val           field value
-- @param field_type    struct field type
-- @param size          field size in bits
-- @param off           field offset (from parsed schema)
-- @param default       field default value
function _M.write_struct_field(p32, val, field_type, size, off, default)
    --local p = get_pointer_from_val(p32, size, val)
    local p = get_pointer_from_type(p32, field_type)
    if type(val) == "boolean" then
        val = val and 1 or 0
    end

    if size >= 8 then
        local n, s = get_bit_offset(size * off, size)
        _M.write_num(p + n, val, field_type, default)
        --p[n] = val
    else
        local n, s = get_bit_offset(size * off, 8)
        _M.write_bit(p + n, val, s, default)
        --p[n] = bor(p[n], lshift(val, s))
    end
end

--- Read text (not including list pointer) starting from buf, works for both
-- "text" type and "data" type
function _M.read_text_data(buf, num)
    return ffistr(buf, num) -- dataWordCount + offset + pointerSize + data_off
end

--- Write text (not including list pointer) starting from buf
-- @param buf       free space that text data will be written to
-- @text            text to be written
-- @is_binary       if writes "data", is_binary is true, otherwise false.
function _M.write_text_data(buf, text, is_binary)
    local len = #text
    copy(buf, text, len)
    if is_binary then
        return round8(len)
    else
        return round8(len + 1)
    end
end

function _M.read_text(buf, header, T, offset, default)
    local res
    local data_off, size, num = _M.read_listp_struct(buf, header, T, 2)
    if data_off and num then
        res = ffistr(buf + (T.dataWordCount + offset + 1 + data_off) * 2,
                num - 1) -- dataWordCount + offset + pointerSize + data_off
    else
        res = default
    end
    return res
end

--- Write text
-- @param p32
-- @param text
-- @param data_off          words between the end of list pointer and the first
--                          byte of text data
function _M.write_text(p32, text, data_off, is_binary)
    local len = #text
    if not is_binary then
        len = len + 1
    end
    _M.write_listp(p32, 2, len, data_off)
    return _M.write_text_data(p32 + data_off * 2 + 2, text, is_binary)
    --copy(p32 + data_off*2 + 2, text)
    --return round8(len)
end

function _M.get_data_off(T, offset, pos)
    return (pos - T.dataWordCount * 8 - offset * 8 - 8) / 8
end

function _M.read_composite_tag(buf)
    local p = cast(pint32, buf)
    local val = p[0]
    local sig = band(val, 0x03)
    if sig ~= 0 then
        error("corrupt data, expected struct signature(composite list tag) " ..
                "0 but have " .. sig)
    end

    -- pointer offset (B) instead indicates the number of elements in the list
    local num = rshift(val, 2)
    val = p[1]
    local dt = band(val, 0xffff)
    local pt = rshift(val, 16)
    --p[1] = lshift(T.pointerCount, 16) + T.dataWordCount
    return num, dt, pt
end

function _M.write_composite_tag(p32, T, num)
    --local p = ffi.cast("int32_t *", buf)
    local p = p32
    -- pointer offset (B) instead indicates the number of elements in the list
    p[0] = lshift(num, 2)
    p[1] = lshift(T.pointerCount, 16) + T.dataWordCount
end

function _M.read_struct_pointer(p)
    local offset = arshift(p[0], 2)
    local data_word_count = band(p[1], 0xffff)
    local pointer_count = rshift(p[1], 16)

    return offset, data_word_count, pointer_count
end

function _M.write_structp(p32, T, data_off)
    p32 = cast(pint32, p32)
    p32[0] = lshift(data_off, 2)
    p32[1] = lshift(T.pointerCount, 16) + T.dataWordCount
end

function _M.write_structp_buf(p32, T, TSub, offset, data_off)
    p32 = cast(pint32, p32)
    local base = T.dataWordCount * 2 + offset * 2
    p32[base] = lshift(data_off, 2)
    p32[base + 1] = lshift(TSub.pointerCount, 16) + TSub.dataWordCount
end


function _M.get_enum_name(v, default, enum_schema, name)
    v = bxor(v, default) -- starts from 0
    local r = enum_schema[v]
    if not r then
        error((name or "") .. " Unknown enum val:" .. v .. ", out of range")
    end
    return r
end

function _M.get_enum_val(v, default, enum_schema, name)
    local t = type(v)

    if t == "number" then
        -- we don't check upper boundary here because max enum value may
        -- increase in later schema
        if v >= 0 then
            return v
        end
        return default
    end

    if t ~= "string" or v == "" then
        return default
    end

    local r = enum_schema[v]
    if not r then
        print(name, " Unknown enum val: " .. v)
        --error("Unknown enum val:" .. v)
        return default
    end
    return r
end

function _M.read_listp(p32, header)
    local val0 = p32[0]
    local val1 = p32[1]

    if val0 == 0 and val1 == 0 then
        return
    end

    local sig = band(val0, 0x03)
    if sig == 1 then
        local offset = arshift(val0, 2)

        local size_type = band(val1, 0x07)
        local num = rshift(val1, 3)

        return offset, size_type, num
        -- return read_list_pointer(p32)
    elseif sig == 2 then
        --print("single far pointer")
        return _M.read_far_pointer(p32, header, _M.read_listp)
    else
        error("corrupt data, expected list signature 1 or far pointer 2, " ..
                "but have " .. sig)
    end
end

-- write list pointer to a pointed memory
-- @param p32         32 bit pointer
-- @param size_type   element size type
-- @param num         number of elements
-- @param data_off    data offset of this list pointer
function _M.write_listp(p32, size_type, num, data_off)
    p32[0] = lshift(data_off, 2) + 1
    p32[1] = lshift(num, 3) + size_type
end

function _M.write_listp_buf(p32, T, offset, size_type, num, data_off)
    p32 = cast(pint32, p32)
    local base = T.dataWordCount * 2 + offset * 2

    p32[base] = lshift(data_off, 2) + 1
    p32[base + 1] = lshift(num, 3) + size_type
end

--- map size type to its size
-- @see http://kentonv.github.io/_Mroto/encoding.html#lists
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

local type_to_size_type = {
    int8    = 2,
    int16   = 3,
    int32   = 4,
    int64   = 5,
    uint8   = 2,
    uint16  = 3,
    uint32  = 4,
    uint64  = 5,
    bool    = 1,
    float32 = 4,
    float64 = 5,
    list    = 6,
    text    = 6,
    data    = 6,
    struct  = 7, -- composite
}

--- Write list data (not including list pointer)
-- @param p32       write list data to this position
-- @return          space consumed in bytes
-- space is allocated by itself
function _M.write_list_data(p32, data, pos, elm_type, ...)
    local start = pos
    if not elm_type then
        return 0
    end
    local len = #data
    if elm_type == "list" then
        pos = pos + len * 8
        for i = 1, len do
            pos = pos + _M.write_list(p32 + (i - 1) * 2, data[i], pos -
                    8 * (i - 1), elm_type, ...)
        end
    elseif elm_type == "text" then
        pos = pos + 8 * len
        for i = 1, len do

            local data_off = (pos - i * 8) / 8 -- pos is in bytes
            pos = pos + _M.write_text(p32 + (i - 1) * 2, data[i], data_off,
                    false)
        end
    elseif elm_type == "data" then
        pos = pos + 8 * len
        for i = 1, len do
            local data_off = (pos - i * 8) / 8 -- pos is in bytes
            local data_len = #data[i]
            _M.write_listp(p32 + (i - 1) * 2, 2, data_len, data_off)
            pos = pos + _M.write_text_data(p32 + pos / 4, data[i], true)
        end
    elseif elm_type == "struct" then
        local T = ...

        _M.write_composite_tag(p32 + pos / 4, T, len)
        pos = pos + 8
        local offset = pos

        local struct_size = (T.dataWordCount + T.pointerCount) * 8
        pos = pos + struct_size * len
        for i = 1, len do
             local sp32 = p32 + offset / 4
             local new_pos = pos - offset-- - offset

             local ssize = T.flat_serialize(data[i], sp32, new_pos)

             pos = pos + ssize - struct_size
             offset = offset + struct_size
        end
    elseif elm_type == "bool" then
        local p = get_pointer_from_type(p32, elm_type)
        for i = 1, len do
            local n, s = get_bit_offset(i - 1, 8)
            _M.write_bit(p + n, data[i], s)
        end
        return round8(len / 8)
    else
        local p = get_pointer_from_type(p32, elm_type)
        for i = 1, len do
            -- No default value available from AST, so no need to pass
            -- default value
            _M.write_num(p + i - 1, data[i], elm_type)
        end
        local size = assert(list_size_map[type_to_size_type[elm_type]])
        return round8(size * len)
    end
    return pos - start
end

--- Write a list (including list pointer and list data)
-- space for list pointer is allocated from outside
-- @param p32
-- @param pos     free space offset from p32
function _M.write_list(p32, data, pos, typ, ...)
    local size
    local data_off = (pos - 8) / 8 --get_data_off(parentT, offset, pos)

    local elm_type, T  = ...
    local size_type = type_to_size_type[elm_type]
    if not size_type then
        error("unknown eml_type: " .. elm_type)
    end

    local num = #data

    local dp32 = p32 + pos / 4
    --size = size + len * 8
    size = _M.write_list_data(dp32, data, 0, ...)

    if elm_type == "struct" then
        -- When size_type = 7, section (D) of the list pointer – which normally
        -- would store this element count – instead stores the total number of
        -- words in the list (not counting the tag word).
        num = (T.dataWordCount + T.pointerCount) * num
    end
    --write_listp_buf(p32, parentT, offset, size_type, len, data_off)
    _M.write_listp(p32, size_type, num, data_off)
    --print("write list done")
    return size
end

--- read data part of a list
-- @param p           start of data buffer
-- @param header      stream header, see http://kentonv.github.io/capnproto/encoding.html#serialization_over_a_stream
-- @param num         number of elements in this list
-- @param elm_type    elememt type: "int32", "data", "list", etc.
function _M.read_list_data(p32, header, num, elm_type, ...)
    p32 = cast(puint32, p32)
    if not elm_type then
        return
    end

    local t = new_tab(num, 0)

    if elm_type == "list" then
        -- print("list data: list")
        for i = 1, num do
            local off, child_size, child_num = _M.read_listp_list(p32,
                    header, i)
            if off and child_num then
                t[i] = _M.read_list_data(p32 + (i + off) * 2, header,
                        child_num, ...)
            end
        end

    elseif elm_type == "text" then
        -- print("list data: text: ", num)
        for i = 1, num do
            local off, child_size, child_num = _M.read_listp_list(p32,
                    header, i)
            --print(off, child_size, child_num)
            if off and child_num then
                t[i] = _M.read_text_data(p32 + (i + off) * 2, child_num - 1)
            end
        end
    elseif elm_type == "data" then
        -- print("list data: data")
        for i = 1, num do
            local off, child_size, child_num = _M.read_listp_list(p32,
                    header, i)
            if off and child_num then
                t[i] = _M.read_text_data(p32 + (i + off) * 2, child_num)
            end
        end
    elseif elm_type == "struct" then
        -- the number of struct elements in a list stores in tag value
        -- and num (from list pointer, normally would be element count) is total
        -- number of words in the list (not including the tag word)
        local real_num, dt, pt = _M.read_composite_tag(p32)
        local T = ...
        local struct_size = (dt + pt) * 8
        for i = 1, real_num do
            -- TODO reuse table
            t[i] = new_tab(0, 8)
            T.parse_struct_data(p32 + 2 + (i - 1) * struct_size / 4, dt,
                    pt, header, assert(t[i]))
        end
    else
        --[[
        local size = list_size_map[size_type]
        if not size then
            error("corrupt data, unknown size type: " .. size_type)
        end

        size = size * 8
        ]]
        p32 = get_pointer_from_type(p32, elm_type)

        for i = 1, num do
            t[i] = p32[i - 1]
        end

    end
    return t
end

-- @index: start from 1
function _M.read_listp_list(p32, header, index)
    return _M.read_listp(p32 + (index - 1) * 2, header)
end

function _M.read_listp_struct(buf, header, T, offset)
    local p = cast(pint32, buf)
    local base = T.dataWordCount * 2 + offset * 2

    return _M.read_listp(p + base, header)
end

function _M.read_far_pointer(buf, header, parser)
    local p = buf

    local landing = rshift(band(p[0], 0x04), 2)

    assert(landing == 0, "double far pointer not supported yet")
    local offset = rshift(p[0], 3)
    local seg_id = tonumber(p[1])
    --print("landing, offset, seg_id:", landing, offset, seg_id)

    -- object pointer offset
    local op_offset = header.header_size
    for i=1, seg_id do
        op_offset = op_offset + header.seg_sizes[i]
    end
    op_offset = op_offset + offset  -- offset is in words
    local pp = header.base + op_offset * 2 -- header.base is uint32_t *

    local p_offset, r1, r2 = parser(pp, header)
    p_offset = p_offset + (pp - p) / 2 -- p and pp are uint32_t *

    return p_offset, r1, r2
end

function _M.read_struct_buf(p32, header)
    local p = p32
    if p[0] == 0 and p[1] == 0 then
        -- not set
        return
    end

    local sig = band(p[0], 0x03)

    if sig == 0 then
        return _M.read_struct_pointer(p)
    elseif sig == 2 then
        return _M.read_far_pointer(p, header, _M.read_struct_pointer)
    else
        error("corrupt data, expected struct signature 0 or far pointer 2, " ..
                "but have " .. sig)
    end
end


return _M
