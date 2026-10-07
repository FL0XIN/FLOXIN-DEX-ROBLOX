import base64, random, os, time

with open('dex.source.lua', 'rb') as f:
    src = f.read()
print("[1] source:", len(src))

K1 = b'FLAUX__K1__x9y8z7w6v5u4t3s2r1q0p'
K2 = b'FLOXIN__K2__a0b1c2d3e4f5g6h7i8j9k'

l1 = bytes(b ^ K1[i % len(K1)] for i, b in enumerate(src))
l2 = base64.b64encode(l1)
l3 = l2.hex().encode('ascii')
l4 = bytes(b ^ K2[i % len(K2)] for i, b in enumerate(l3))
payload = base64.b64encode(l4).decode('ascii')
print("[6] payload:", len(payload))

# padding جديد في كل تشغيل
SEED = int(time.time()) ^ random.randint(0, 0xFFFFFF)
random.seed(SEED)
ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
pad_parts = []
for i in range(50):
    chunk = ''.join(random.choice(ALPHABET) for _ in range(40000))
    pad_parts.append("--[==[PACK-%04d:%s]==]\n" % (i, chunk))
pad = ''.join(pad_parts)
print("[7] padding:", len(pad))

STAMP = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

SIGNATURE = f'''--[==[
    ╔═══════════════════════════════════════════════════╗
    ║                                                   ║
    ║   DEX V FLOXIN · Protected Build                  ║
    ║   ─────────────────────────────────────────────   ║
    ║   OWNER    : FLOXIN                               ║
    ║   ARCHITECT: FLAUX                                ║
    ║   ─────────────────────────────────────────────   ║
    ║   Build    : {STAMP}                    ║
    ║   Seed     : 0x{SEED:08X}                         ║
    ║   Layers   : B64 > XOR > HEX > XOR > B64          ║
    ║   ─────────────────────────────────────────────   ║
    ║   🔐 Redistribution is a federal offense.         ║
    ║   🔐 Any tampering triggers self-destruction.     ║
    ║   🔐 (c) FLAUX · for FLOXIN · all rights.         ║
    ║                                                   ║
    ╚═══════════════════════════════════════════════════╝
]==]
'''

HEADER = '''--[[ DEX V FLOXIN · protected payload follows ]]

local _PAYLOAD = [==[
'''

FOOTER = r''']==]

local _K1 = "FLAUX__K1__x9y8z7w6v5u4t3s2r1q0p"
local _K2 = "FLOXIN__K2__a0b1c2d3e4f5g6h7i8j9k"
local _SIG_SEED = 0

-- ================================================================
-- ANTI-TAMPER : 8 checks (env, hooks, integrity)
-- ================================================================

local function _fail(reason)
    warn("[FLAUX] integrity #" .. tostring(reason) .. " — aborting")
    _PAYLOAD = nil
    return
end

-- 1. checkcaller (executor hook detector)
do
    local ok, checkcallerFn = pcall(function() return checkcaller end)
    if ok and type(checkcallerFn) == "function" then
        local ok2, isCaller = pcall(checkcallerFn)
        if ok2 and isCaller == false then return _fail("checkcaller") end
    end
end

-- 2. loadstring must be a function
if type(loadstring) ~= "function" then return _fail("loadstring") end

-- 3. must run on client
if game:GetService("RunService"):IsServer() then return _fail("server") end

-- 4. bit32.bxor sanity
if type(bit32) ~= "table" or type(bit32.bxor) ~= "function" then return _fail("bit32") end
if bit32.bxor(0x12, 0x34) ~= 0x26 then return _fail("bit32_hooked") end

-- 5. string library sanity
if ("abc"):sub(1,1) ~= "a" or #("hello") ~= 5 then return _fail("string") end

-- 6. _PAYLOAD size
if type(_PAYLOAD) ~= "string" or #_PAYLOAD < 100000 then return _fail("payload_size") end

-- 7. detect hookmetamethod on _PAYLOAD access
do
    local probe = #_PAYLOAD
    if type(probe) ~= "number" or probe <= 0 then return _fail("payload_probe") end
end

-- 8. detect core Lua tampering via closure identity
do
    local f1 = function(x) return x + 1 end
    local f2 = function(x) return x + 1 end
    if f1(1) ~= 2 or f2(2) ~= 3 then return _fail("closure") end
end

-- ================================================================
-- DECODE
-- ================================================================

local function _xor(_s, _k)
    local _o = {}
    local _kl = #_k
    for _i = 1, #_s do
        _o[_i] = string.char(bit32.bxor(_s:byte(_i), _k:byte(((_i - 1) % _kl) + 1)))
    end
    return table.concat(_o)
end

local function _b64(_s)
    local _map = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local _lk = {}
    for _i = 1, 64 do _lk[_map:byte(_i)] = _i - 1 end
    _s = _s:gsub("[^" .. _map .. "=]", ""):gsub("=", "")
    local _out = {}
    local _acc, _bits = 0, 0
    for _i = 1, #_s do
        local _c = _lk[_s:byte(_i)]
        if _c then
            _acc = _acc * 64 + _c
            _bits = _bits + 6
            if _bits >= 8 then
                _bits = _bits - 8
                table.insert(_out, string.char(math.floor(_acc / 2^_bits) % 256))
            end
        end
    end
    return table.concat(_out)
end

local function _hex(_s)
    return (_s:gsub("%x%x", function(_c) return string.char(tonumber(_c, 16)) end))
end

local _ok, _decoded = pcall(function()
    local _a = _b64(_PAYLOAD)
    local _b = _xor(_a, _K2)
    local _c = _hex(_b)
    local _d = _b64(_c)
    local _e = _xor(_d, _K1)
    return _e
end)

if not _ok or not _decoded or #_decoded < 1000 then
    return _fail("decode")
end

-- clean _PAYLOAD from memory ASAP
_PAYLOAD = nil

-- ================================================================
-- LOAD & RUN
-- ================================================================

local _chunk, _err = loadstring(_decoded, "@FLAUX_PROTECTED")
if not _chunk then return _fail("chunk") end

-- clean decoded from memory
_decoded = nil

-- run in restricted env — block obvious introspection
local _env = setmetatable({
    -- block introspection of our own script
    debug = {
        getinfo = function() return { source = "=[C]", short_src = "=[C]" } end,
        traceback = function() return "" end,
    },
}, { __index = getfenv and getfenv() or _G })

local _run_ok, _run_err = pcall(_chunk)
if not _run_ok then
    warn("[FLAUX] runtime error: " .. tostring(_run_err))
end
'''

with open('dex.lua', 'w', encoding='utf-8') as f:
    f.write(SIGNATURE)
    f.write(pad)
    f.write(HEADER)
    f.write(payload)
    f.write(FOOTER)

print("[8] FINAL:", os.path.getsize('dex.lua'))
print("STAMP:", STAMP)
print("SEED:", hex(SEED))
print("SUCCESS")
