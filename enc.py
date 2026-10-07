import base64, random, os, time

with open('dex.source.lua', 'rb') as f:
    src = f.read()
print("[1]", len(src))

# keys داخلية — بتتشوّه عند التخزين
K1 = b'FLAUX__K1__x9y8z7w6v5u4t3s2r1q0p'
K2 = b'FLOXIN__K2__a0b1c2d3e4f5g6h7i8j9k'

# طبقات
l1 = bytes(b ^ K1[i % len(K1)] for i, b in enumerate(src))
l2 = base64.b64encode(l1)
l3 = l2.hex().encode('ascii')
l4 = bytes(b ^ K2[i % len(K2)] for i, b in enumerate(l3))
payload = base64.b64encode(l4).decode('ascii')

# ============ تشويه المفاتيح ============
def mask_bytes(bs):
    return [(b ^ ((i * 7 + 13) & 0xFF)) for i, b in enumerate(bs)]

def nums(arr):
    return ",".join(str(x) for x in arr)

m1 = nums(mask_bytes(K1))
m2 = nums(mask_bytes(K2))

# ============ padding بمحتوى وهمي "زي كود عادي" ============
SEED = int(time.time()) ^ random.randint(0, 0xFFFFFF)
random.seed(SEED)
ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
pad_parts = []
for i in range(50):
    chunk = ''.join(random.choice(ALPHABET) for _ in range(40000))
    pad_parts.append("--[==[" + chunk + "]==]\n")
pad = ''.join(pad_parts)

STAMP = time.strftime("%Y-%m-%d", time.gmtime())

# ============ التوقيع ============
SIG = '''--[[
    DEX V FLOXIN
    ─────────────
    Owner : FLOXIN
    Author: FLAUX
    Protected build. Redistribution prohibited.
    (c) FLAUX
]]
'''

HEADER = '\nlocal _P = [==[\n'
FOOTER = r''']==]

-- =========================================================
-- internal
-- =========================================================

local _0xA_ = {''' + m1 + r'''}
local _0xB_ = {''' + m2 + r'''}

local function _k(arr)
    local o = {}
    for i, v in ipairs(arr) do
        o[i] = string.char(bit32.bxor(v, ((i - 1) * 7 + 13) % 256))
    end
    return table.concat(o)
end

local _KA = _k(_0xA_)
local _KB = _k(_0xB_)
_0xA_ = nil
_0xB_ = nil

-- =========================================================
-- integrity
-- =========================================================

local function _stop(n)
    if _G.warn then _G.warn("0x" .. tostring(n)) end
    _P = nil
    return nil
end

if type(_P) ~= "string" or #_P < 100000 then return _stop(0x11) end
if type(loadstring) ~= "function" then return _stop(0x12) end
if type(bit32) ~= "table" or bit32.bxor(0x12, 0x34) ~= 0x26 then return _stop(0x13) end
if type(game) ~= "userdata" then return _stop(0x14) end

pcall(function()
    if game:GetService("RunService"):IsServer() then _stop(0x15) end
end)

-- =========================================================
-- decode pipeline (single blob)
-- =========================================================

local function _D(x)
    -- stage a
    local _m = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local _l = {}
    for _i = 1, 64 do _l[_m:byte(_i)] = _i - 1 end
    local function _b(s)
        s = s:gsub("[^" .. _m .. "=]", ""):gsub("=", "")
        local o, a, n = {}, 0, 0
        for i = 1, #s do
            local c = _l[s:byte(i)]
            if c then
                a = a * 64 + c
                n = n + 6
                if n >= 8 then
                    n = n - 8
                    table.insert(o, string.char(math.floor(a / 2^n) % 256))
                end
            end
        end
        return table.concat(o)
    end

    -- stage b
    local function _x(s, k)
        local o, kl = {}, #k
        for i = 1, #s do
            o[i] = string.char(bit32.bxor(s:byte(i), k:byte(((i - 1) % kl) + 1)))
        end
        return table.concat(o)
    end

    -- stage c
    local function _h(s)
        return (s:gsub("%x%x", function(c) return string.char(tonumber(c, 16)) end))
    end

    -- pipeline (order hidden in sequence)
    local a = _b(x)
    a = _x(a, _KB)
    a = _h(a)
    a = _b(a)
    a = _x(a, _KA)
    return a
end

local _ok, _r = pcall(_D, _P)
_P = nil
_KA = nil
_KB = nil

if not _ok or type(_r) ~= "string" or #_r < 1000 then return _stop(0x16) end

local _c, _e = loadstring(_r, "@x")
_r = nil

if not _c then return _stop(0x17) end

local _rok, _rerr = pcall(_c)
if not _rok then
    if _G.warn then _G.warn("0x18") end
end
'''

with open('dex.lua', 'w', encoding='utf-8') as f:
    f.write(SIG)
    f.write(pad)
    f.write(HEADER)
    f.write(payload)
    f.write(FOOTER)

print("[8] FINAL:", os.path.getsize('dex.lua'))
print("SUCCESS")
