-- utils.lua - Utility functions for the game

local utils = {}

-- Clamp a value between min and max
function utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Linear interpolation between a and b
function utils.lerp(a, b, t)
    return a + (b - a) * t
end

-- Distance between two points
function utils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Check if a point is inside a rectangle
function utils.pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Check if two rectangles overlap
function utils.rectOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

-- Check if a point is inside a circle
function utils.pointInCircle(px, py, cx, cy, radius)
    local dx = px - cx
    local dy = py - cy
    return dx * dx + dy * dy <= radius * radius
end

-- Check if two circles overlap
function utils.circleOverlap(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distSq = dx * dx + dy * dy
    local sumRadii = r1 + r2
    return distSq <= sumRadii * sumRadii
end

-- Get a random color with optional base color and variance
function utils.randomColor(baseColor, variance)
    baseColor = baseColor or {1, 1, 1, 1}
    variance = variance or 0.1
    
    local r = utils.clamp(baseColor[1] + (math.random() - 0.5) * variance, 0, 1)
    local g = utils.clamp(baseColor[2] + (math.random() - 0.5) * variance, 0, 1)
    local b = utils.clamp(baseColor[3] + (math.random() - 0.5) * variance, 0, 1)
    local a = baseColor[4] or 1
    
    return {r, g, b, a}
end

-- Get a random position within a rectangle
function utils.randomPosition(x, y, width, height)
    return {
        x = x + math.random() * width,
        y = y + math.random() * height
    }
end

-- Get a random integer between min and max (inclusive)
function utils.randomInt(min, max)
    return math.floor(math.random() * (max - min + 1)) + min
end

-- Get a random element from a table
function utils.randomChoice(t)
    if #t == 0 then return nil end
    return t[math.random(#t)]
end

-- Shuffle a table in-place
function utils.shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- Deep copy a table
function utils.deepCopy(original)
    local copy
    if type(original) == "table" then
        copy = {}
        for k, v in pairs(original) do
            copy[k] = utils.deepCopy(v)
        end
    else
        copy = original
    end
    return copy
end

-- Merge two tables
function utils.mergeTables(t1, t2)
    local result = utils.deepCopy(t1)
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

-- Format time in seconds to MM:SS format
function utils.formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

-- Check if a file exists
function utils.fileExists(filename)
    local file = io.open(filename, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Save a table to a file as JSON
function utils.saveToFile(filename, data)
    local success, result = pcall(function()
        local json = require("json") -- Assuming a JSON library is available
        local content = json.encode(data)
        local file = io.open(filename, "w")
        if file then
            file:write(content)
            file:close()
            return true
        end
        return false
    end)
    
    return success and result
end

-- Load a table from a JSON file
function utils.loadFromFile(filename)
    if not utils.fileExists(filename) then
        return nil
    end
    
    local success, result = pcall(function()
        local json = require("json") -- Assuming a JSON library is available
        local file = io.open(filename, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return json.decode(content)
        end
        return nil
    end)
    
    return success and result
end

-- Create a simple easing function (ease in-out)
function utils.easeInOut(t)
    return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
end

-- Create a simple easing function (ease out)
function utils.easeOut(t)
    return 1 - (1 - t) * (1 - t)
end

-- Create a simple easing function (ease in)
function utils.easeIn(t)
    return t * t
end

-- Convert HSV to RGB
function utils.hsvToRgb(h, s, v)
    local r, g, b
    
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    
    i = i % 6
    
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    
    return r, g, b
end

-- Get a color gradient between two colors
function utils.colorGradient(color1, color2, t)
    t = utils.clamp(t, 0, 1)
    return {
        utils.lerp(color1[1], color2[1], t),
        utils.lerp(color1[2], color2[2], t),
        utils.lerp(color1[3], color2[3], t),
        utils.lerp(color1[4] or 1, color2[4] or 1, t)
    }
end

-- Generate a perlin noise value (simplified version)
function utils.perlinNoise(x, y, seed)
    seed = seed or 0
    x = x + seed * 100
    y = y + seed * 100
    
    local function fade(t)
        return t * t * t * (t * (t * 6 - 15) + 10)
    end
    
    local function grad(hash, x, y)
        local h = hash % 4
        local u = h < 2 and x or y
        local v = h < 2 and y or x
        return ((h % 2) == 0 and u or -u) + ((h % 2) == 0 and v or -v)
    end
    
    local function noise(x, y)
        local X = math.floor(x) % 256
        local Y = math.floor(y) % 256
        x = x - math.floor(x)
        y = y - math.floor(y)
        local u = fade(x)
        local v = fade(y)
        
        local A = (X + Y) % 256
        local B = (X + Y + 1) % 256
        
        return utils.lerp(
            utils.lerp(grad(A, x, y), grad(B, x-1, y), u),
            utils.lerp(grad(A, x, y-1), grad(B, x-1, y-1), u),
            v
        )
    end
    
    return noise(x, y)
end

return utils
