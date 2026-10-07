import base64, os, hashlib, time

with open('dex.source.lua', 'rb') as f:
    src = f.read()
print("[1] source:", len(src))

# XOR key
KEY = b'FLOXIN_FLAUX_2026_SECRET_KEY_v1'
xored = bytes(b ^ KEY[i % len(KEY)] for i, b in enumerate(src))
print("[2] xored:", len(xored))

# Base64
b64 = base64.b64encode(xored).decode('ascii')
print("[3] b64:", len(b64))

# chunks صغيرة — 30KB
CHUNK = 30000
parts = [b64[i:i+CHUNK] for i in range(0, len(b64), CHUNK)]
print("[4] chunks:", len(parts))

STAMP = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
BUILD = hashlib.sha256((b64[:500] + STAMP).encode()).hexdigest()[:12].upper()

CHUNK_BLOCK = "local _P = {\n"
for p in parts:
    CHUNK_BLOCK += "[==[" + p + "]==],\n"
CHUNK_BLOCK += "}\n"

SIG = f'''--[==[
    DEX V FLOXIN
    ─────────────────────────────
    Owner    : FLOXIN
    Architect: FLAUX
    Build    : {BUILD}
    Stamp    : {STAMP}
    License  : Proprietary
    (c) 2026 FLOXIN & FLAUX
]==]
'''

FOOTER = r'''
local _K = "FLOXIN_FLAUX_2026_SECRET_KEY_v1"

-- join chunks
local _b64 = table.concat(_P)
_P = nil

-- base64 decode
local function _unb64(s)
    local m = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local l = {}
    for i = 1, 64 do l[m:byte(i)] = i - 1 end
    s = s:gsub("[^" .. m .. "=]", ""):gsub("=", "")
    local o, a, n = {}, 0, 0
    for i = 1, #s do
        local c = l[s:byte(i)]
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

local _xored = _unb64(_b64)
_b64 = nil

-- xor
local out = {}
local kl = #_K
for i = 1, #_xored do
    out[i] = string.char(bit32.bxor(_xored:byte(i), _K:byte(((i - 1) % kl) + 1)))
end
_xored = nil

local src = table.concat(out)
out = nil

local fn, err = loadstring(src, "@FLOXIN")
src = nil
if not fn then
    warn("[FLOXIN] load error: " .. tostring(err))
    return
end

local ok, runErr = pcall(fn)
if not ok then
    warn("[FLOXIN] run error: " .. tostring(runErr))
end
'''

with open('dex.lua', 'w', encoding='utf-8') as f:
    f.write(SIG)
    f.write(CHUNK_BLOCK)
    f.write(FOOTER)

print("[5] FINAL:", os.path.getsize('dex.lua'))
print("BUILD:", BUILD)
print("SUCCESS")
