-- CellTypes.lua - Defines all cell types and their properties

local CellTypes = {
    -- Basic types
    EMPTY = 0,
    BOUNDARY = 1,
    
    -- Solid materials
    STONE = 10,
    DIRT = 11,
    GRASS = 12,  -- Grass (appears on top of dirt)
    MUD = 13,
    WOOD = 14,
    METAL = 15,
    
    -- Particle solids
    SAND = 20,
    GRAVEL = 21,
    ASH = 22,
    
    -- Liquids
    WATER = 30,
    OIL = 31,
    LAVA = 32,
    
    -- Energy/Special
    FIRE = 40,
    STEAM = 41,
    SMOKE = 42,
    
    -- Game objects
    HOLE = 90,  -- Golf hole
    FLAG = 91,  -- Flag marker
}

-- Cell type properties
local properties = {
    [CellTypes.EMPTY] = {
        solid = false,
        liquid = false,
        particle = false,
        flammable = false,
        destructible = false,
        density = 0,
        defaultColor = {0, 0, 0, 0}
    },
    [CellTypes.BOUNDARY] = {
        solid = true,
        liquid = false,
        particle = false,
        flammable = false,
        destructible = false,
        density = 999,
        defaultColor = {0.2, 0.2, 0.2, 1}
    },
    
    -- Solid materials
    [CellTypes.STONE] = {
        solid = true,
        liquid = false,
        particle = false,
        flammable = false,
        destructible = true,
        density = 5,
        defaultColor = {0.5, 0.5, 0.5, 1}
    },
    [CellTypes.DIRT] = {
        solid = true,
        liquid = false,
        particle = false,
        flammable = false,
        destructible = true,
        density = 3,
        defaultColor = {0.6, 0.4, 0.2, 1}
    },
    [CellTypes.GRASS] = {
        solid = true,
        liquid = false,
        particle = false,
        flammable = true,
        destructible = true,
        density = 3,
        defaultColor = {0.3, 0.7, 0.2, 1}  -- Green color for grass
    },
    [CellTypes.MUD] = {
        solid = true,
        liquid = false,
        particle = true,  -- Can behave like a particle when disturbed
        flammable = false,
        destructible = true,
        density = 3.5,
        defaultColor = {0.5, 0.3, 0.1, 1}
    },
    [CellTypes.WOOD] = {
        solid = true,
        liquid = false,
        particle = false,
        flammable = true,
        destructible = true,
        density = 2,
        defaultColor = {0.7, 0.5, 0.3, 1}
    },
    [CellTypes.METAL] = {
        solid = true,
        liquid = false,
        particle = false,
        flammable = false,
        destructible = false,  -- Metal is indestructible
        density = 7,
        defaultColor = {0.7, 0.7, 0.8, 1}
    },
    
    -- Particle solids
    [CellTypes.SAND] = {
        solid = false,
        liquid = false,
        particle = true,
        flammable = false,
        destructible = true,
        density = 4,
        defaultColor = {0.9, 0.8, 0.5, 1}
    },
    [CellTypes.GRAVEL] = {
        solid = false,
        liquid = false,
        particle = true,
        flammable = false,
        destructible = true,
        density = 4.5,
        defaultColor = {0.6, 0.6, 0.6, 1}
    },
    [CellTypes.ASH] = {
        solid = false,
        liquid = false,
        particle = true,
        flammable = false,
        destructible = true,
        density = 2,
        defaultColor = {0.3, 0.3, 0.3, 1}
    },
    
    -- Liquids
    [CellTypes.WATER] = {
        solid = false,
        liquid = true,
        particle = false,
        flammable = false,
        destructible = true,
        density = 3,
        defaultColor = {0.2, 0.4, 0.8, 0.8}
    },
    [CellTypes.OIL] = {
        solid = false,
        liquid = true,
        particle = false,
        flammable = true,
        destructible = true,
        density = 2,
        defaultColor = {0.4, 0.3, 0.1, 0.8}
    },
    [CellTypes.LAVA] = {
        solid = false,
        liquid = true,
        particle = false,
        flammable = false,
        destructible = true,
        density = 5,
        defaultColor = {0.9, 0.3, 0.1, 0.9}
    },
    
    -- Energy/Special
    [CellTypes.FIRE] = {
        solid = false,
        liquid = false,
        particle = false,
        flammable = false,
        destructible = true,
        density = 0.5,
        defaultColor = {1, 0.5, 0, 0.9}
    },
    [CellTypes.STEAM] = {
        solid = false,
        liquid = false,
        particle = true,
        flammable = false,
        destructible = true,
        density = 0.2,
        defaultColor = {0.8, 0.8, 0.8, 0.5}
    },
    [CellTypes.SMOKE] = {
        solid = false,
        liquid = false,
        particle = true,
        flammable = false,
        destructible = true,
        density = 0.1,
        defaultColor = {0.3, 0.3, 0.3, 0.5}
    },
    
    -- Game objects
    [CellTypes.HOLE] = {
        solid = false,
        liquid = false,
        particle = false,
        flammable = false,
        destructible = false,
        density = 0,
        defaultColor = {0, 0, 0, 1}
    },
    [CellTypes.FLAG] = {
        solid = false,
        liquid = false,
        particle = false,
        flammable = false,
        destructible = false,
        density = 0,
        defaultColor = {1, 0, 0, 1}
    },
}

-- Helper functions to check cell properties
function CellTypes.isSolid(cellType)
    return properties[cellType] and properties[cellType].solid or false
end

function CellTypes.isLiquid(cellType)
    return properties[cellType] and properties[cellType].liquid or false
end

function CellTypes.isParticle(cellType)
    return properties[cellType] and properties[cellType].particle or false
end

function CellTypes.isFlammable(cellType)
    return properties[cellType] and properties[cellType].flammable or false
end

function CellTypes.isDestructible(cellType)
    return properties[cellType] and properties[cellType].destructible or false
end

function CellTypes.isIndestructible(cellType)
    return properties[cellType] and not properties[cellType].destructible or false
end

function CellTypes.getDensity(cellType)
    return properties[cellType] and properties[cellType].density or 0
end

function CellTypes.getDefaultColor(cellType)
    return properties[cellType] and properties[cellType].defaultColor or {1, 1, 1, 1}
end

-- Get a random variation of a color
function CellTypes.getRandomColorVariation(baseColor, variance)
    variance = variance or 0.1
    local r = math.max(0, math.min(1, baseColor[1] + (math.random() - 0.5) * variance))
    local g = math.max(0, math.min(1, baseColor[2] + (math.random() - 0.5) * variance))
    local b = math.max(0, math.min(1, baseColor[3] + (math.random() - 0.5) * variance))
    local a = baseColor[4] or 1
    
    return {r, g, b, a}
end

-- Get all cell types as a list
function CellTypes.getAllTypes()
    local types = {}
    for k, v in pairs(CellTypes) do
        if type(v) == "number" then
            table.insert(types, {name = k, id = v})
        end
    end
    return types
end

return CellTypes
