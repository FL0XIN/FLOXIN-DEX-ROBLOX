import base64, os, time, hashlib

# ============ MINIFIER ============
def strip_comments(src):
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        # long bracket string
        if c == '[':
            j = i + 1
            eq = 0
            while j < n and src[j] == '=':
                eq += 1
                j += 1
            if j < n and src[j] == '[':
                close = ']' + '='*eq + ']'
                end = src.find(close, j + 1)
                if end == -1:
                    out.append(src[i:])
                    break
                out.append(src[i:end+len(close)])
                i = end + len(close)
                continue
            out.append(c)
            i += 1
            continue

        # string literal
        if c == '"' or c == "'":
            q = c
            out.append(c)
            i += 1
            while i < n:
                ch = src[i]
                out.append(ch)
                if ch == '\\' and i+1 < n:
                    out.append(src[i+1])
                    i += 2
                    continue
                if ch == q:
                    i += 1
                    break
                if ch == '\n':
                    i += 1
                    break
                i += 1
            continue

        # comment
        if c == '-' and i+1 < n and src[i+1] == '-':
            j = i + 2
            if j < n and src[j] == '[':
                k = j + 1
                eq = 0
                while k < n and src[k] == '=':
                    eq += 1
                    k += 1
                if k < n and src[k] == '[':
                    close = ']' + '='*eq + ']'
                    end = src.find(close, k + 1)
                    if end == -1:
                        i = n
                        continue
                    i = end + len(close)
                    out.append('\n')
                    continue
            end = src.find('\n', i)
            if end == -1:
                i = n
            else:
                out.append('\n')
                i = end + 1
            continue

        out.append(c)
        i += 1
    return ''.join(out)

# ============ READ + MINIFY ============
with open('dex.source.lua', 'r', encoding='utf-8') as f:
    src_text = f.read()

print("[1] original:", len(src_text))
minified = strip_comments(src_text)
print("[2] minified:", len(minified))

if len(minified) > 500000:
    print("[!] still too big, applying more aggressive...")
    # collapse multiple blank lines and trailing spaces
    import re
    minified = re.sub(r'\n\s*\n+', '\n', minified)
    minified = re.sub(r'[ \t]+', ' ', minified)
    print("[2b] after whitespace:", len(minified))

src = minified.encode('utf-8')

# ============ ENCODE ============
KEY = b'FLOXIN_FLAUX_2026_SECRET_KEY_v1'
xored = bytes(b ^ KEY[i % len(KEY)] for i, b in enumerate(src))
print("[3] xored:", len(xored))

b64 = base64.b64encode(xored).decode('ascii')
print("[4] b64:", len(b64))

CHUNK = 30000
parts = [b64[i:i+CHUNK] for i in range(0, len(b64), CHUNK)]
print("[5] chunks:", len(parts))

STAMP = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
BUILD = hashlib.sha256((b64[:500] + STAMP).encode()).hexdigest()[:12].upper()

CHUNK_BLOCK = "local _P = {\n"
for p in parts:
    CHUNK_BLOCK += "[==[" + p + "]==],\n"
CHUNK_BLOCK += "}\n"

SIG = f'''--[==[
    DEX V FLOXIN
    Owner    : FLOXIN
    Architect: FLAUX
    Build    : {BUILD}
    Stamp    : {STAMP}
    License  : Proprietary · (c) 2026 FLOXIN & FLAUX
]==]
'''

FOOTER = r'''
local _K = "FLOXIN_FLAUX_2026_SECRET_KEY_v1"

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

local out = {}
local kl = #_K
for i = 1, #xored do
    out[i] = string.char(bit32.bxor(xored:byte(i), _K:byte(((i - 1) % kl) + 1)))
end
xored = nil
local src = table.concat(out)
out = nil

local fn, err = loadstring(src, "@FLOXIN")
src = nil
if not fn then
    warn("[FLOXIN] load: " .. tostring(err):sub(1,150))
    return
end

local ok, rerr = pcall(fn)
if not ok then
    warn("[FLOXIN] run: " .. tostring(rerr):sub(1,150))
end
'''

with open('dex.lua', 'w', encoding='utf-8') as f:
    f.write(SIG)
    f.write(CHUNK_BLOCK)
    f.write(FOOTER)

print("[6] FINAL:", os.path.getsize('dex.lua'))
print("SUCCESS")
