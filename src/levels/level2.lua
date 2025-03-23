-- level2.lua - Material behavior debug level

local CellTypes = require("src.cells.CellTypes")
local BallTypes = require("src.balls.BallTypes")

local level = {}

-- Level properties
level.name = "Material Debug"
level.description = "Test different material behaviors"
level.par = 0  -- No par for debug level

-- Starting position and ball type
level.startPosition = {x = 50, y = 20}
level.ballType = BallTypes.BALL
level.initialVelocity = {x = 0, y = 0}  -- Start with zero velocity

-- Hole position (off-screen)
level.holePosition = {x = -10, y = -10}

-- Cell data for the level
level.cells = {}

-- Create a container with walls
for x = 10, 90 do
    -- Bottom wall
    table.insert(level.cells, {
        x = x,
        y = 65,
        type = CellTypes.STONE,
        color = {0.5, 0.5, 0.5, 1}
    })
    
    -- Top wall
    if x < 30 or x > 70 then
        table.insert(level.cells, {
            x = x,
            y = 10,
            type = CellTypes.STONE,
            color = {0.5, 0.5, 0.5, 1}
        })
    end
end

-- Add some sand to test physics with subtle color variations
for i = 1, 200 do
    local x = 40 + math.random(-5, 5)
    local y = 30 + math.random(-5, 5)
    
    -- Subtle sand color variations (shades of tan)
    local sandBase = 0.85  -- Base brightness
    local variation = 0.15  -- Subtle variation
    local shade = sandBase - variation/2 + math.random() * variation
    local sandColor = {
        shade + 0.1,  -- Red (slightly more)
        shade,        -- Green (base)
        shade - 0.4,  -- Blue (much less)
        1
    }
    
    table.insert(level.cells, {
        x = x,
        y = y,
        type = CellTypes.SAND,
        color = sandColor
    })
end

-- Add some water to test physics with subtle color variations
for i = 1, 200 do
    local x = 70 + math.random(-5, 5)
    local y = 30 + math.random(-5, 5)
    
    -- Subtle water color variations (shades of blue)
    local waterBase = 0.7  -- Base brightness
    local variation = 0.2  -- Subtle variation
    local shade = waterBase - variation/2 + math.random() * variation
    local waterColor = {
        0.0,          -- Red (none)
        shade - 0.3,  -- Green (some)
        shade,        -- Blue (base)
        0.8 + math.random() * 0.2  -- Alpha (slight variation)
    }
    
    table.insert(level.cells, {
        x = x,
        y = y,
        type = CellTypes.WATER,
        color = waterColor
    })
end

for y = 10, 65 do
    -- Left wall
    table.insert(level.cells, {
        x = 10,
        y = y,
        type = CellTypes.STONE,
        color = {0.5, 0.5, 0.5, 1}
    })
    
    -- Right wall
    table.insert(level.cells, {
        x = 90,
        y = y,
        type = CellTypes.STONE,
        color = {0.5, 0.5, 0.5, 1}
    })
    
    -- Middle divider
    if y > 30 then
        table.insert(level.cells, {
            x = 50,
            y = y,
            type = CellTypes.STONE,
            color = {0.5, 0.5, 0.5, 1}
        })
    end
end

-- Create platforms for different materials
-- Left side: Solid materials
for x = 15, 25 do
    -- Stone platform
    table.insert(level.cells, {
        x = x,
        y = 40,
        type = CellTypes.STONE,
        color = {0.5, 0.5, 0.5, 1}
    })
    
    -- Dirt platform
    table.insert(level.cells, {
        x = x + 20,
        y = 40,
        type = CellTypes.DIRT,
        color = {0.6, 0.4, 0.2, 1}
    })
end

-- Right side: Particle materials
for x = 55, 65 do
    -- Sand platform
    table.insert(level.cells, {
        x = x,
        y = 40,
        type = CellTypes.STONE,
        color = {0.5, 0.5, 0.5, 1}
    })
    
    -- Water platform
    table.insert(level.cells, {
        x = x + 20,
        y = 40,
        type = CellTypes.STONE,
        color = {0.5, 0.5, 0.5, 1}
    })
end

-- Add material samples
-- Sand pile with subtle color variations
for i = 1, 100 do
    local x = 60 + math.random(-3, 3)
    local y = 35 + math.random(-3, 3)
    
    -- Subtle sand color variations (shades of tan)
    local sandBase = 0.85  -- Base brightness
    local variation = 0.15  -- Subtle variation
    local shade = sandBase - variation/2 + math.random() * variation
    local sandColor = {
        shade + 0.1,  -- Red (slightly more)
        shade,        -- Green (base)
        shade - 0.4,  -- Blue (much less)
        1
    }
    
    table.insert(level.cells, {
        x = x,
        y = y,
        type = CellTypes.SAND,
        color = sandColor
    })
end

-- Water pool with subtle color variations
for i = 1, 100 do
    local x = 80 + math.random(-3, 3)
    local y = 35 + math.random(-3, 3)
    
    -- Subtle water color variations (shades of blue)
    local waterBase = 0.7  -- Base brightness
    local variation = 0.2  -- Subtle variation
    local shade = waterBase - variation/2 + math.random() * variation
    local waterColor = {
        0.0,          -- Red (none)
        shade - 0.3,  -- Green (some)
        shade,        -- Blue (base)
        0.8 + math.random() * 0.2  -- Alpha (slight variation)
    }
    
    table.insert(level.cells, {
        x = x,
        y = y,
        type = CellTypes.WATER,
        color = waterColor
    })
end

-- Add labels
local function addTextLabel(text, x, y, color)
    -- This is just for visualization in the level editor
    -- Actual text will be drawn by the UI
    local labelData = {
        text = text,
        x = x,
        y = y,
        color = color or {1, 1, 1, 1}
    }
    
    -- Store label data in level metadata
    if not level.labels then
        level.labels = {}
    end
    table.insert(level.labels, labelData)
end

addTextLabel("STONE", 20, 45, {0.7, 0.7, 0.7, 1})
addTextLabel("DIRT", 40, 45, {0.6, 0.4, 0.2, 1})
addTextLabel("SAND", 60, 45, {0.9, 0.8, 0.6, 1})
addTextLabel("WATER", 80, 45, {0.2, 0.4, 0.8, 1})

return level
