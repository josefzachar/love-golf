-- BallInteractions.lua - Material interactions and special effects for the ball

local BallInteractions = {}

-- Handle material-specific interactions
function BallInteractions.handleMaterialInteractions(ball, cellType, dt)
    -- Update material flags
    ball.inSand = (cellType == ball.CellTypes.SAND)
    ball.inWater = (cellType == ball.CellTypes.WATER)
    
    -- Handle water interaction
    if ball.inWater and not ball.sinkingInWater then
        -- Start sinking if the ball is moving slowly
        local speed = math.sqrt(ball.velocity.x^2 + ball.velocity.y^2)
        if speed < 3.0 then
            ball.sinkingInWater = true
            ball.sinkTimer = 0
            
            if ball.debug then
                print("[BALL] Ball started sinking in water")
            end
        end
    end
    
    -- Apply material-specific effects
    if cellType == ball.CellTypes.WATER then
        -- Apply water resistance and buoyancy
        BallInteractions.applyWaterPhysics(ball, dt)
    elseif cellType == ball.CellTypes.SAND then
        -- Apply sand physics
        BallInteractions.applySandPhysics(ball, dt)
    end
end

-- Apply water physics effects
function BallInteractions.applyWaterPhysics(ball, dt)
    -- Apply water resistance (based on velocity)
    local speed = math.sqrt(ball.velocity.x^2 + ball.velocity.y^2)
    local resistanceFactor = 0.95 - (speed * 0.01)  -- More resistance at higher speeds
    resistanceFactor = math.max(0.8, resistanceFactor)  -- Cap minimum resistance
    
    ball.velocity.x = ball.velocity.x * resistanceFactor
    ball.velocity.y = ball.velocity.y * resistanceFactor
    
    -- Apply buoyancy effect (upward force)
    local buoyancyForce = 0.2
    ball.velocity.y = ball.velocity.y - buoyancyForce * dt
    
    -- Create ripple effect for fast-moving ball
    if speed > 5.0 and math.random() < 0.1 then
        -- TODO: Add visual ripple effect
    end
end

-- Apply sand physics effects
function BallInteractions.applySandPhysics(ball, dt)
    -- Apply increased friction in sand
    local frictionFactor = 0.9
    ball.velocity.x = ball.velocity.x * frictionFactor
    ball.velocity.y = ball.velocity.y * frictionFactor
    
    -- Slow down vertical movement more in sand
    ball.velocity.y = ball.velocity.y * 0.95
    
    -- Create small sand displacement effects for fast-moving ball
    local speed = math.sqrt(ball.velocity.x^2 + ball.velocity.y^2)
    if speed > 5.0 and math.random() < 0.1 then
        -- TODO: Add visual sand displacement effect
    end
end

-- Handle the ball sinking in water
function BallInteractions.handleWaterSinking(ball, dt)
    -- Increment the sink timer
    ball.sinkTimer = ball.sinkTimer + dt
    
    -- Gradually sink the ball
    local sinkDuration = 3.0  -- Time in seconds to fully sink
    local sinkProgress = math.min(ball.sinkTimer / sinkDuration, 1.0)
    
    -- Apply a small random movement to simulate water ripples
    local rippleStrength = 0.01 * (1.0 - sinkProgress)
    ball.position.x = ball.position.x + (math.random() * 2 - 1) * rippleStrength
    ball.position.y = ball.position.y + (math.random() * 2 - 1) * rippleStrength
    
    -- If the ball has fully sunk, deactivate it
    if sinkProgress >= 1.0 then
        ball.active = false
        
        if ball.debug then
            print("[BALL] Ball has fully sunk in water")
        end
    end
end

-- Create a depression in sand when the ball stops
function BallInteractions.createSandDepression(ball)
    local cellX = math.floor(ball.position.x)
    local cellY = math.floor(ball.position.y)
    
    -- Check if we're actually on sand
    if ball.cellWorld:getCell(cellX, cellY) == ball.CellTypes.SAND then
        -- Mark that we're now in a sand depression
        ball.inSand = true
        ball.craterCreated = true
        
        -- TODO: Add visual sand depression effect
        -- For now, we'll just mark it with a flag
        
        if ball.debug then
            print("[BALL] Created depression in sand at: " .. cellX .. ", " .. cellY)
        end
    end
end

-- Get the bounce factor for a specific material
function BallInteractions.getMaterialBounceFactor(ball, cellType)
    local materialProps = ball.materialProperties[cellType]
    if materialProps and materialProps.bounceFactor then
        return materialProps.bounceFactor
    end
    
    -- Default bounce factors for common materials
    if cellType == ball.CellTypes.STONE then
        return 0.8  -- Stone is more bouncy
    elseif cellType == ball.CellTypes.DIRT then
        return 0.5  -- Dirt absorbs more energy
    elseif cellType == ball.CellTypes.BOUNDARY then
        return 0.7  -- Default bounce factor
    else
        return ball.bounceFactor
    end
end

-- Get a human-readable name for a material
function BallInteractions.getMaterialName(ball, cellType)
    if cellType == ball.CellTypes.STONE then
        return "Stone"
    elseif cellType == ball.CellTypes.DIRT then
        return "Dirt"
    elseif cellType == ball.CellTypes.SAND then
        return "Sand"
    elseif cellType == ball.CellTypes.WATER then
        return "Water"
    elseif cellType == ball.CellTypes.BOUNDARY then
        return "Boundary"
    else
        return "Unknown (" .. cellType .. ")"
    end
end

return BallInteractions
