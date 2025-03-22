-- BallTypes.lua - Defines the ball type for the game

local BallTypes = {
    -- Only one ball type - a simple cell in the grid
    BALL = 99
}

-- Ball type properties
local properties = {
    [BallTypes.BALL] = {
        name = "Ball Cell",
        description = "Simple ball represented as a single cell in the grid",
        mass = 1.0,
        radius = 1,
        bounceFactor = 0.7,
        friction = 0.98,
        color = {1, 1, 1, 1}  -- White color
    }
}

-- Helper functions to get ball properties
function BallTypes.getName(ballType)
    return properties[ballType] and properties[ballType].name or "Unknown"
end

function BallTypes.getDescription(ballType)
    return properties[ballType] and properties[ballType].description or ""
end

function BallTypes.getMass(ballType)
    return properties[ballType] and properties[ballType].mass or 1.0
end

function BallTypes.getRadius(ballType)
    return properties[ballType] and properties[ballType].radius or 1
end

function BallTypes.getBounceFactor(ballType)
    return properties[ballType] and properties[ballType].bounceFactor or 0.7
end

function BallTypes.getFriction(ballType)
    return properties[ballType] and properties[ballType].friction or 0.98
end

function BallTypes.getColor(ballType)
    return properties[ballType] and properties[ballType].color or {1, 1, 1, 1}
end

function BallTypes.getAbilityName(ballType)
    return "None"
end

-- Get all ball types as a list
function BallTypes.getAllTypes()
    local types = {}
    for k, v in pairs(BallTypes) do
        if type(v) == "number" then
            table.insert(types, {
                id = v,
                name = k,
                displayName = properties[v].name,
                description = properties[v].description
            })
        end
    end
    return types
end

-- Get the next ball type in sequence (for cycling through ball types)
function BallTypes.getNextType(currentType)
    return BallTypes.BALL
end

return BallTypes
