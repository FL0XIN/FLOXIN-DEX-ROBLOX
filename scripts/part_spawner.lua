-- Part Spawner · 10 parts around you
local plr = game:GetService("Players").LocalPlayer
local char = plr.Character
if not char then print("no char") return end
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hrp then print("no hrp") return end
for i = 1, 10 do
    local angle = (i / 10) * math.pi * 2
    local p = Instance.new("Part")
    p.Size = Vector3.new(2, 2, 2)
    p.Position = hrp.Position + Vector3.new(math.cos(angle)*8, 2, math.sin(angle)*8)
    p.Anchored = true
    p.Color = Color3.fromHSV(i/10, 0.7, 0.9)
    p.Material = Enum.Material.Neon
    p.Name = "FLOXIN_Spawn_" .. i
    p.Parent = workspace
end
print("spawned 10 parts")
