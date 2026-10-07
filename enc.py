import base64, os, time, hashlib

with open('dex.source.lua', 'rb') as f:
    src = f.read()

# نتأكد من الملف
print("source:", len(src))
print("NUL count:", src.count(b'\x00'))
print("first 20:", src[:20])

KEY = b'FLOXIN_FLAUX_2026_SECRET_KEY_v1'
xored = bytes(b ^ KEY[i % len(KEY)] for i, b in enumerate(src))
b64 = base64.b64encode(xored).decode('ascii')

CHUNK = 30000
parts = [b64[i:i+CHUNK] for i in range(0, len(b64), CHUNK)]
print("chunks:", len(parts))

CHUNK_BLOCK = "local _P = {\n"
for p in parts:
    CHUNK_BLOCK += "[==[" + p + "]==],\n"
CHUNK_BLOCK += "}\n"

STAMP = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
BUILD = hashlib.sha256((b64[:500] + STAMP).encode()).hexdigest()[:12].upper()

SIG = f'''--[==[
    DEX V FLOXIN
    Owner    : FLOXIN
    Architect: FLAUX
    Build    : {BUILD}
    Stamp    : {STAMP}
]==]
'''

FOOTER = r'''
local _K = "FLOXIN_FLAUX_2026_SECRET_KEY_v1"

-- join + decode
local _b64 = table.concat(_P)
_P = nil

local m = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local l = {}
for i = 1, 64 do l[m:byte(i)] = i - 1 end
_b64 = _b64:gsub("[^" .. m .. "=]", ""):gsub("=", "")
local o, a, n = {}, 0, 0
for i = 1, #_b64 do
    local c = l[_b64:byte(i)]
    if c then
        a = a * 64 + c
        n = n + 6
        if n >= 8 then
            n = n - 8
            table.insert(o, string.char(math.floor(a / 2^n) % 256))
        end
    end
end
local xored = table.concat(o)
_b64 = nil

-- xor
local out = {}
local kl = #_K
for i = 1, #xored do
    out[i] = string.char(bit32.bxor(xored:byte(i), _K:byte(((i - 1) % kl) + 1)))
end
xored = nil
local src = table.concat(out)
out = nil

-- WRITE TO FILE + LOADFILE
local function tryRun(code)
    -- method 1: writefile + loadfile
    if writefile and loadfile then
        local ok = pcall(writefile, "floxin_runtime.lua", code)
        if ok then
            local fn = loadfile("floxin_runtime.lua")
            if fn then
                local rok, rerr = pcall(fn)
                if rok then return true end
                warn("[FLOXIN] loadfile run: " .. tostring(rerr):sub(1,120))
            end
        end
    end
    -- method 2: loadstring fallback
    local fn, err = loadstring(code, "@FLOXIN")
    if not fn then
        warn("[FLOXIN] loadstring: " .. tostring(err):sub(1,150))
        return false
    end
    local rok, rerr = pcall(fn)
    if not rok then
        warn("[FLOXIN] run: " .. tostring(rerr):sub(1,150))
        return false
    end
    return true
end

tryRun(src)
src = nil
'''

with open('dex.lua', 'w', encoding='utf-8') as f:
    f.write(SIG)
    f.write(CHUNK_BLOCK)
    f.write(FOOTER)

print("FINAL:", os.path.getsize('dex.lua'))
print("SUCCESS")
