import base64, random, os, time, hashlib

with open('dex.source.lua', 'rb') as f:
    src = f.read()

K1 = b'FLAUX__K1__x9y8z7w6v5u4t3s2r1q0p'
K2 = b'FLOXIN__K2__a0b1c2d3e4f5g6h7i8j9k'

l1 = bytes(b ^ K1[i % len(K1)] for i, b in enumerate(src))
l2 = base64.b64encode(l1)
l3 = l2.hex().encode('ascii')
l4 = bytes(b ^ K2[i % len(K2)] for i, b in enumerate(l3))
payload = base64.b64encode(l4).decode('ascii')

def mask(bs):
    return [(b ^ ((i * 7 + 13) & 0xFF)) for i, b in enumerate(bs)]
def nums(a): return ",".join(str(x) for x in a)
m1, m2 = nums(mask(K1)), nums(mask(K2))

# padding متخفي — يبان زي حقوق نشر متكررة
SEED = int(time.time()) ^ random.randint(0, 0xFFFFFF)
random.seed(SEED)
ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
pad_parts = []
for i in range(50):
    chunk = ''.join(random.choice(ALPHABET) for _ in range(40000))
    pad_parts.append("--[==[ (c)2026 FLAUX · protected · " + chunk + " ]==]\n")
pad = ''.join(pad_parts)

STAMP = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
BUILD = hashlib.sha256((payload[:1000] + STAMP).encode()).hexdigest()[:16].upper()

# =========================================================
# التوقيع الفخم
# =========================================================
SIG = f'''--[==[
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║     ██████╗ ███████╗██╗  ██╗    ██╗   ██╗                            ║
║     ██╔══██╗██╔════╝╚██╗██╔╝    ██║   ██║                            ║
║     ██║  ██║█████╗   ╚███╔╝     ██║   ██║                            ║
║     ██║  ██║██╔══╝   ██╔██╗     ╚██╗ ██╔╝                            ║
║     ██████╔╝███████╗██╔╝ ██╗     ╚████╔╝                             ║
║     ╚═════╝ ╚══════╝╚═╝  ╚═╝      ╚═══╝                              ║
║                                                                      ║
║               ×  F  L  A  U  X  ×                                    ║
║                                                                      ║
║   ┌──────────────────────────────────────────────────────────────┐   ║
║   │                                                              │   ║
║   │   OWNER       :  FLOXIN                                      │   ║
║   │   ARCHITECT   :  FLAUX                                       │   ║
║   │   BUILD ID    :  {BUILD}                              │   ║
║   │   TIMESTAMP   :  {STAMP}                             │   ║
║   │   LICENSE     :  Proprietary · All Rights Reserved          │   ║
║   │                                                              │   ║
║   ├──────────────────────────────────────────────────────────────┤   ║
║   │                                                              │   ║
║   │   ⚠  WARNING                                                  │   ║
║   │                                                              │   ║
║   │   This software is the exclusive intellectual property of    │   ║
║   │   FLOXIN and FLAUX. Unauthorized copying, redistribution,    │   ║
║   │   modification, reverse-engineering, or resale — in whole    │   ║
║   │   or in part — constitutes a violation of international      │   ║
║   │   copyright law and will be prosecuted to the fullest        │   ║
║   │   extent permitted.                                          │   ║
║   │                                                              │   ║
║   │   All sessions are cryptographically fingerprinted. Any      │   ║
║   │   attempt to lift, rebrand, or re-sign this payload will     │   ║
║   │   be traced back to its origin.                              │   ║
║   │                                                              │   ║
║   │   © 2026 FLOXIN & FLAUX. All rights reserved worldwide.      │   ║
║   │                                                              │   ║
║   └──────────────────────────────────────────────────────────────┘   ║
║                                                                      ║
║              "Built in silence. Wielded in fire."                    ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
]==]
'''

HEADER = '\nlocal _P = [==[\n'

FOOTER = r''']==]

-- ─────────────────────────────────────────────────
--  DEX V FLOXIN · runtime core
-- ─────────────────────────────────────────────────

local _0xA_ = {''' + m1 + r'''}
local _0xB_ = {''' + m2 + r'''}

local function _k(arr)
    local o = {}
    for i = 1, #arr do
        o[i] = string.char(bit32.bxor(arr[i], ((i - 1) * 7 + 13) % 256))
    end
    return table.concat(o)
end

local _KA, _KB = _k(_0xA_), _k(_0xB_)
_0xA_, _0xB_ = nil, nil

local _FP = (function()
    local parts = {}
    local ok, id = pcall(function() return game.JobId end)
    table.insert(parts, ok and tostring(id) or "?")
    table.insert(parts, tostring(tick()):sub(1, 10))
    pcall(function() table.insert(parts, tostring(game.PlaceId)) end)
    pcall(function() table.insert(parts, tostring(game:GetService("Players").LocalPlayer.UserId)) end)
    return table.concat(parts, ":")
end)()

local function _halt(tag)
    pcall(function()
        if _G.warn then _G.warn("[FLOXIN] " .. tag) end
    end)
    _P = nil
    return nil
end

-- integrity gates
if type(_P) ~= "string" or #_P < 100000 then return _halt("i01") end
if type(loadstring) ~= "function" then return _halt("i02") end
if type(bit32) ~= "table" or bit32.bxor(0x5A, 0x1F) ~= 0x45 then return _halt("i03") end
if type(game) ~= "userdata" then return _halt("i04") end

pcall(function()
    if game:GetService("RunService"):IsServer() then _halt("i05") end
end)

-- decode (streamed)
local function _D(x)
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

    local function _x(s, k)
        local o, kl = {}, #k
        for i = 1, #s do
            o[i] = string.char(bit32.bxor(s:byte(i), k:byte(((i - 1) % kl) + 1)))
        end
        return table.concat(o)
    end

    local function _h(s)
        return (s:gsub("%x%x", function(c) return string.char(tonumber(c, 16)) end))
    end

    local a = _b(x)
    a = _x(a, _KB)
    a = _h(a)
    a = _b(a)
    a = _x(a, _KA)
    return a
end

local _ok, _r = pcall(_D, _P)
_P = nil
_KA, _KB = nil, nil

if not _ok or type(_r) ~= "string" or #_r < 1000 then return _halt("i06") end

local _c, _e = loadstring(_r, "@FLOXIN")
_r = nil
if not _c then return _halt("i07") end

local _rok, _rerr = pcall(_c)
if not _rok then
    pcall(function() if _G.warn then _G.warn("[FLOXIN] i08: " .. tostring(_rerr)) end end)
end
'''

with open('dex.lua', 'w', encoding='utf-8') as f:
    f.write(SIG)
    f.write(pad)
    f.write(HEADER)
    f.write(payload)
    f.write(FOOTER)

print("Build:", BUILD)
print("FINAL:", os.path.getsize('dex.lua'))
print("SUCCESS")
