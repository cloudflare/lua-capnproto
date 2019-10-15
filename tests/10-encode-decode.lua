local ffi = require "ffi"
local lunit = require "lunitx"
local capnp = require "capnp"
local util = require "capnp.util"

hw_capnp = require "example_capnp"
--local format = string.format

local tdiff = util.table_diff


if _VERSION >= 'Lua 5.2' then
    _ENV = lunit.module('simple','seeall')
else
    module( "simple", package.seeall, lunit.testcase )
end

local copy = {}

function assert_equalf(expected, actual)
    assert_true(math.abs(expected - actual) < 0.000001)
end

function test_basic_value()
    local data = {
        i0 = 32,
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(data.i0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
end

function test_basic_value1()
    local data = {
        b0 = true,
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(true, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
end

function test_basic_value2()
    local data = {
        i2 = -8,
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(-8, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
end

function test_basic_value3()
    local data = {
        s0 = {},
    }

    assert_equal(136 + 24, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_not_nil(copy.s0)
    assert_equal(0, copy.s0.f0)
    assert_equal(0, copy.s0.f1)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
end

function test_basic_value4()
    local data = {
        s0 = {
            f0 = 3.14,
            f1 = 3.1415926535
        },
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_not_nil(copy.s0)
    assert_equalf(3.1400001049042, copy.s0.f0)
    assert_equal(3.1415926535, copy.s0.f1)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
end

function test_basic_value4()
    local data = {
        l0 = { 1, -1, 127 }
    }

    assert_equal(136 + 8, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_equal(3, #copy.l0)
    assert_equal(1, copy.l0[1])
    assert_equal(-1, copy.l0[2])
    assert_equal(127, copy.l0[3])
    assert_nil(copy.t0)
end

function test_basic_value5()
    local data = {
        t0 = "1234567890~!#$%^&*()-=_+[]{};':|,.<>/?"
    }

    assert_equal(136 + 40, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_equal(38, #copy.t0)
    assert_equal("1234567890~!#$%^&*()-=_+[]{};':|,.<>/?", copy.t0)
end

function test_basic_value6()
    local data = {
        i0 = 32,
        i1 = 16,
        i2 = 127,
        b0 = true,
        b1 = true,
        i3 = 65536,
        e0 = "enum3",
        s0 = {
            f0 = 3.14,
            f1 = 3.14159265358979,
        },
        l0 = { 28, 29 },
        t0 = "hello",
        e1 = "enum7",
    }

    -- header + T1.size + T2.size + l0 + t0
    assert_equal(16 + 120 + 24 + 8 + 8, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    util.write_file("dump", bin)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(32, copy.i0)
    assert_equal(16, copy.i1)
    assert_equal(127, copy.i2)
    assert_equal(true, copy.b0)
    assert_equal(true, copy.b1)
    assert_equal(65536, copy.i3)
    assert_equal("enum3", copy.e0)
    assert_equal("enum7", copy.e1)
    assert_not_nil(copy.s0)
    assert_equalf(3.14, copy.s0.f0)
    assert_equal(3.14159265358979, copy.s0.f1)
    assert_not_nil(copy.l0)
    assert_equal(2, #copy.l0)
    assert_equal(28, copy.l0[1])
    assert_equal(29, copy.l0[2])
    assert_equal(5, #copy.t0)
    assert_equal("hello", copy.t0)
end
function test_union_value()
    local data = {
        ui1 = 32,
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(data.ui1, copy.ui1)
    assert_nil(copy.ui0)
    assert_nil(copy.uv0)
end

function test_union_value()
    local data = {
        uv0 = "Void",
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_nil(copy.ui1)
    assert_nil(copy.ui0)
    assert_equal(data.uv0, copy.uv0)
end

function test_union_value()
    local data = {
        g0 = {
            ui2 = 48,
        },
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(data.g0.ui2, copy.g0.ui2)
end

function test_union_group()
    local data = {
        u0 = {
            ui3 = 48,
        },
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_equal(data.u0.ui3, copy.u0.ui3)
    assert_nil(copy.u0.uv1)
    assert_nil(copy.u0.ug0)
    assert_nil(copy.ls0)
end

function test_union_group1()
    local data = {
        u0 = {
            uv1 = "Void",
        },
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_nil(copy.u0.ui3)
    assert_equal("Void", copy.u0.uv1)
    assert_nil(copy.u0.ug0)
    assert_nil(copy.ls0)
end

function test_union_group2()
    local data = {
        u0 = {
            ug0 = {
                ugv0 = "Void",
            },
        },
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_nil(copy.u0.ui3)
    assert_nil(copy.u0.uv1)
    assert_equal("Void", copy.u0.ug0.ugv0)
    assert_equal(0, copy.u0.ug0.ugu0)
    assert_nil(copy.ls0)
end

function test_struct_list()
    local data = {
        ls0 = {
            {
                f0 = 3.14,
                f1 = 3.141592653589,
            },
            {
                f0 = 3.14,
                f1 = 3.141592653589,
            },
        },
    }

    assert_equal(136 + 8 + 24 * 2, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_equal(0, copy.u0.ui3)
    assert_nil(copy.u0.uv1)
    assert_nil(copy.u0.ug0)
    assert_not_nil(copy.ls0[1])
    assert_equalf(data.ls0[1].f0, copy.ls0[1].f0)
    assert_equal(data.ls0[1].f1, copy.ls0[1].f1)
    assert_equalf(data.ls0[2].f0, copy.ls0[2].f0)
    assert_equal(data.ls0[2].f1, copy.ls0[2].f1)
end

function test_default_value()
    local data = {
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_equal(0, copy.u0.ui3)
    assert_nil(copy.u0.uv1)
    assert_nil(copy.u0.ug0)
    assert_nil(copy.ls0)
    assert_equal(65535, copy.du0) -- default = 65535
end

function test_default_value1()
    local data = {
        du0 = 630,
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_equal(0, copy.u0.ui3)
    assert_nil(copy.u0.uv1)
    assert_nil(copy.u0.ug0)
    assert_nil(copy.ls0)
    assert_equal(630, copy.du0) -- default = 65535
end
function test_default_value2()
    local data = {
        db0 = true
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_equal(0, copy.u0.ui3)
    assert_nil(copy.u0.uv1)
    assert_nil(copy.u0.ug0)
    assert_nil(copy.ls0)
    assert_equal(65535, copy.du0) -- default = 65535
    assert_equal(true, copy.db0) -- default = true
end
function test_reserved_word()
    local data = {
        ["end"] = true
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_equal(0, copy.u0.ui3)
    assert_nil(copy.u0.uv1)
    assert_nil(copy.u0.ug0)
    assert_nil(copy.ls0)
    assert_equal(65535, copy.du0) -- default = 65535
    assert_equal(true, copy.db0) -- default = true
    assert_equal(true, copy["end"])
end

function test_list_of_text()
    local data = {
        lt0 = {
            "Bach", "Mozart", "Beethoven", "Tchaikovsky",
        }
    }

    assert_equal(136 + 4 * 8 + 8 + 8 + 16 + 16, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
    assert_equal(0, copy.ui0) -- ui0 is set by default
    assert_nil(copy.ui1)
    assert_nil(copy.uv0)
    assert_equal(0, copy.g0.ui2)
    assert_equal(0, copy.u0.ui3)
    assert_nil(copy.u0.uv1)
    assert_nil(copy.u0.ug0)
    assert_nil(copy.ls0)
    assert_equal(65535, copy.du0) -- default = 65535
    assert_equal(true, copy.db0) -- default = true
    assert_equal(false, copy["end"])
    assert_not_nil(copy.lt0)
    assert_equal(4, #copy.lt0)
    assert_not_nil(copy.lt0[1])
    assert_not_nil(copy.lt0[2])
    assert_not_nil(copy.lt0[3])
    assert_not_nil(copy.lt0[4])
    assert_equal(data.lt0[1], copy.lt0[1])
    assert_equal(data.lt0[2], copy.lt0[2])
    assert_equal(data.lt0[3], copy.lt0[3])
    assert_equal(data.lt0[4], copy.lt0[4])
end

function test_list_of_data()
    local data = {
        ld0 = {
            "B\x0A\x0Ch", "M\x00z\x0Art", "B\xEEthoven", "Tch\x0Aik\x00vsky",
        }
    }

    assert_equal(128 + 4 * 8 + 8 + 8 + 16 + 16, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_not_nil(copy.ld0)
    assert_equal(4, #copy.ld0)
    assert_not_nil(copy.ld0[1])
    assert_not_nil(copy.ld0[2])
    assert_not_nil(copy.ld0[3])
    assert_not_nil(copy.ld0[4])
    assert_equal(data.ld0[1], copy.ld0[1])
    assert_equal(data.ld0[2], copy.ld0[2])
    assert_equal(data.ld0[3], copy.ld0[3])
    assert_equal(data.ld0[4], copy.ld0[4])
end


function test_const()
    assert_equal(3.14159, hw_capnp.pi)
    assert_equal("Hello", hw_capnp.T1.welcomeText)
end

function test_enum_literal()
    assert_equal(0, hw_capnp.T1.EnumType1["enum1"])
    assert_equal("enum1", hw_capnp.T1.EnumType1Str[0])

    assert_equal(3, hw_capnp.T1.EnumType1["wEirdENum4"])
    assert_equal("wEirdENum4", hw_capnp.T1.EnumType1Str[3])

    assert_equal(4, hw_capnp.T1.EnumType1["UPPER-DASH"])
    assert_equal("UPPER-DASH", hw_capnp.T1.EnumType1Str[4])
end

function test_imported_constant()
    assert_equal(1, hw_capnp.S1.flag1)
    assert_equal(2, hw_capnp.S1.flag2)
    assert_equal("Hello", hw_capnp.S1.flag3)
end

function test_uint64()
    local uint64p = ffi.new("uint64_t[?]", 1)
    local uint32p = ffi.cast("uint32_t *", uint64p)
    uint32p[0] = 1
    uint32p[1] = 2

    local data = {
        u64 = uint64p[0],
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)

    assert_equal("cdata", type(copy.u64))
    assert_equal("8589934593ULL", tostring(copy.u64))

end

function test_lower_space_naming()
    local data = {
        e1 = "lower space"
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal("lower space", copy.e1)
end

function test_type_check_when_calc_size()
    -- data type should be checked when calculating size
    local data = {
        s0 = "I should be a lua table, not a string",
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal(0, copy.i0)
    assert_equal(0, copy.i1)
    assert_equal(0, copy.i2)
    assert_equal(false, copy.b0)
    assert_equal(false, copy.b1)
    assert_equal(0, copy.i3)
    assert_equal("enum1", copy.e0)
    assert_equal("none", copy.e1)
    assert_nil(copy.s0)
    assert_nil(copy.l0)
    assert_nil(copy.t0)
end

function test_get_enum_from_number()
    local data = {
        e1 = 7, -- "lower space"
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal("lower space", copy.e1)
end

function test_unknown_enum_value()
    local data = {
        e1 = "I AM AN UNKNOWN ENUM",
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal("none", copy.e1)
end

function test_empty_enum_value()
    local data = {
        e1 = "",
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    copy  = hw_capnp.T1.parse(bin, copy)
    assert_equal("none", copy.e1)
end

function test_list_uint16_size()
    local data = { ls_u16 = {1, 2, 3, 4, 5, 6, 7, 8, 9} }
    -- header (and root struct pointer) + 6 list pointers + round8(2 * 9)
    assert_equal(16 + 8 * 6 + 24, hw_capnp.T3.calc_size(data))

    local data = { ls_u32 = {1, 2, 3, 4, 5, 6, 7, 8, 9} }
    -- header (and root struct pointer) + 6 list pointers + round8(4 * 9)
    assert_equal(16 + 8 * 6 + 40, hw_capnp.T3.calc_size(data))

    local data = { ls_u64 = {1, 2, 3, 4, 5, 6, 7, 8, 9} }
    -- header (and root struct pointer) + 6 list pointers + round8(8 * 9)
    assert_equal(16 + 8 * 6 + 72, hw_capnp.T3.calc_size(data))

    local data = { ls_i16 = {1, 2, 3, 4, 5, 6, 7, 8, 9} }
    -- header (and root struct pointer) + 6 list pointers + round8(2 * 9)
    assert_equal(16 + 8 * 6 + 24, hw_capnp.T3.calc_size(data))

    local data = { ls_i32 = {1, 2, 3, 4, 5, 6, 7, 8, 9} }
    -- header (and root struct pointer) + 6 list pointers + round8(4 * 9)
    assert_equal(16 + 8 * 6 + 40, hw_capnp.T3.calc_size(data))

    local data = { ls_i64 = {1, 2, 3, 4, 5, 6, 7, 8, 9} }
    -- header (and root struct pointer) + 6 list pointers + round8(8 * 9)
    assert_equal(16 + 8 * 6 + 72, hw_capnp.T3.calc_size(data))
end

function test_serialize_cdata()
    local data = {
        i0 = 32,
    }

    assert_equal(136, hw_capnp.T1.calc_size(data))
    local bin   = hw_capnp.T1.serialize(data)
    local arr, len = hw_capnp.T1.serialize_cdata(data)
    assert_equal(#bin, len)
    assert_equal(bin, ffi.string(arr, len))
end

function test_list_of_list_of_text()
    local data = {
        llt0 = {
            {"a"},
            {"b", "c"},
        }
    }

    assert_equal(16 + 2 * 8 + 2 * 8 + 3 * 16, hw_capnp.T5.calc_size(data))
    local bin   = hw_capnp.T5.serialize(data)
    copy  = hw_capnp.T5.parse(bin, copy)
    assert_not_nil(copy.llt0)
    assert_equal(2, #copy.llt0)
    assert_not_nil(copy.llt0[1])
    assert_not_nil(copy.llt0[2])

    assert_equal(1, #copy.llt0[1])
    assert_not_nil(copy.llt0[1][1])
    assert_equal(data.llt0[1][1], copy.llt0[1][1])

    assert_equal(2, #copy.llt0[2])
    assert_not_nil(copy.llt0[2][1])
    assert_not_nil(copy.llt0[2][2])
    assert_equal(data.llt0[2][1], copy.llt0[2][1])
    assert_equal(data.llt0[2][2], copy.llt0[2][2])
end

function test_list_of_list_of_list_text()
    local data = {
        lllt0 = {
            {
              {"a"},
            },
            {
              {"b"},
              {"c", "d"},
            },
        }
    }

    assert_equal(16 + 2 * 8 + 2 * 8 + 3 * 8 + 4 * 16, hw_capnp.T5.calc_size(data))
    local bin   = hw_capnp.T5.serialize(data)
    copy  = hw_capnp.T5.parse(bin, copy)
    assert_not_nil(copy.lllt0)
    assert_equal(2, #copy.lllt0)
    assert_not_nil(copy.lllt0[1])

    assert_equal(1, #copy.lllt0[1])
    assert_not_nil(copy.lllt0[1][1])

    assert_equal(1, #copy.lllt0[1][1])
    assert_not_nil(copy.lllt0[1][1][1])
    assert_equal(data.lllt0[1][1][1], copy.lllt0[1][1][1])

    assert_equal(2, #copy.lllt0[2])
    assert_not_nil(copy.lllt0[2][1])

    assert_equal(1, #copy.lllt0[2][1])
    assert_not_nil(copy.lllt0[2][1][1])
    assert_equal(data.lllt0[2][1][1], copy.lllt0[2][1][1])

    assert_equal(2, #copy.lllt0[2][2])
    assert_not_nil(copy.lllt0[2][2][1])
    assert_equal(data.lllt0[2][2][1], copy.lllt0[2][2][1])
    assert_equal(data.lllt0[2][2][2], copy.lllt0[2][2][2])
end

return _G
