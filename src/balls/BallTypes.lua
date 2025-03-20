-- BallTypes.lua - Defines the different types of golf balls

local BallTypes = {
    -- Basic ball types
    STANDARD = 1,
    EXPLOSIVE = 2,
    STICKY = 3,
    MINING = 4
}

-- Ball type properties
local properties = {
    [BallTypes.STANDARD] = {
        name = "Standard",
        description = "A regular golf ball with balanced physics",
        mass = 1.0,
        radius = 4,
        bounceFactor = 0.7,
        friction = 0.98,
        color = {1, 1, 1, 1}
    },
    [BallTypes.EXPLOSIVE] = {
        name = "Explosive",
        description = "Explodes on impact or when activated, destroying terrain",
        mass = 1.2,
        radius = 4,
        bounceFactor = 0.8,
        friction = 0.97,
        color = {1, 0.2, 0.2, 1},
        ability = "Explode"
    },
    [BallTypes.STICKY] = {
        name = "Sticky",
        description = "Sticks to surfaces and can create platforms",
        mass = 0.8,
        radius = 4,
        bounceFactor = 0.3,
        friction = 0.99,
        color = {0.2, 1, 0.2, 1},
        ability = "Create Platform"
    },
    [BallTypes.MINING] = {
        name = "Mining",
        description = "Can dig through terrain when activated",
        mass = 1.5,
        radius = 4,
        bounceFactor = 0.6,
        friction = 0.96,
        color = {0.8, 0.8, 0.2, 1},
        ability = "Dig"
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
    return properties[ballType] and properties[ballType].radius or 4
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
    return properties[ballType] and properties[ballType].ability or "None"
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
    if currentType == BallTypes.STANDARD then
        return BallTypes.EXPLOSIVE
    elseif currentType == BallTypes.EXPLOSIVE then
        return BallTypes.STICKY
    elseif currentType == BallTypes.STICKY then
        return BallTypes.MINING
    else
        return BallTypes.STANDARD
    end
end

return BallTypes
