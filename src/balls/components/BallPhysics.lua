-- BallPhysics.lua - Physics-related functions for the ball

local BallPhysics = {}

-- Update the ball rotation based on movement
function BallPhysics.updateBallRotation(ball, dt)
    -- Only update if we have a valid last position
    if ball.lastPosition.x ~= 0 or ball.lastPosition.y ~= 0 then
        -- Calculate movement since last frame
        local movement = {
            x = ball.position.x - ball.lastPosition.x,
            y = ball.position.y - ball.lastPosition.y
        }
        
        -- Update rotation based on horizontal movement
        local rollFactor = 8.0  -- Controls how fast the ball rotates
        
        -- Calculate rotation amount based on horizontal movement
        local rotationAmount = movement.x * rollFactor / (ball.radius * 8.0)
        
        -- Adjust rotation based on speed (faster = more rotation)
        ball.rotation = ball.rotation + rotationAmount
        
        -- Keep rotation within 0 to 2π
        if ball.rotation > 2 * math.pi then
            ball.rotation = ball.rotation - 2 * math.pi
        elseif ball.rotation < 0 then
            ball.rotation = ball.rotation + 2 * math.pi
        end
    end
    
    -- Store current position for next frame
    ball.lastPosition = {x = ball.position.x, y = ball.position.y}
end

-- Update the ball physics
function BallPhysics.update(ball, dt)
    if not ball.active or ball.inHole then return end
    
    -- If aiming, don't update physics
    if ball.isAiming then return end
    
    -- Check the current cell type the ball is in
    local cellX = math.floor(ball.position.x)
    local cellY = math.floor(ball.position.y)
    local currentCellType = ball.cellWorld:getCell(cellX, cellY)
    
    -- Handle special material interactions
    ball:handleMaterialInteractions(currentCellType, dt)
    
    -- If the ball is sinking in water, handle that separately
    if ball.sinkingInWater then
        ball:handleWaterSinking(dt)
        return
    end
    
    -- Apply gravity (reduced in water)
    local gravityModifier = 1.0
    if ball.inWater then
        -- Apply buoyancy in water
        gravityModifier = 0.3  -- 70% reduction in gravity due to buoyancy
    end
    
    -- Debug gravity application
    if ball.debug then
        print("[PHYSICS] Applying gravity: " .. ball.gravity .. " * " .. gravityModifier .. " * " .. dt)
        print("[PHYSICS] Current velocity before gravity: " .. ball.velocity.x .. ", " .. ball.velocity.y)
    end
    
    -- Make sure gravity is applied with a significant value
    ball.velocity.y = ball.velocity.y + ball.gravity * gravityModifier * dt
    
    if ball.debug then
        print("[PHYSICS] Velocity after gravity: " .. ball.velocity.x .. ", " .. ball.velocity.y)
    end
    
    -- Cap velocity
    local speed = math.sqrt(ball.velocity.x^2 + ball.velocity.y^2)
    if speed > ball.maxVelocity then
        ball.velocity.x = ball.velocity.x * (ball.maxVelocity / speed)
        ball.velocity.y = ball.velocity.y * (ball.maxVelocity / speed)
    end
    
    -- Store old position for collision detection
    local oldX = ball.position.x
    local oldY = ball.position.y
    
    -- Update position
    ball.position.x = ball.position.x + ball.velocity.x * dt
    ball.position.y = ball.position.y + ball.velocity.y * dt
    
    -- Update ball rotation based on movement
    BallPhysics.updateBallRotation(ball, dt)
    
    -- Check for collisions
    ball:handleCollisions(oldX, oldY, dt)
    
    -- Apply friction based on material
    local frictionFactor = ball.friction  -- Default air friction
    
    if ball.inSand then
        frictionFactor = 0.9  -- High friction in sand
    elseif ball.inWater then
        frictionFactor = 0.95  -- Medium friction in water
    end
    
    ball.velocity.x = ball.velocity.x * frictionFactor
    ball.velocity.y = ball.velocity.y * frictionFactor
    
    -- Check if ball is almost stopped
    if speed < ball.restThreshold then
        ball.velocity.x = 0
        ball.velocity.y = 0
        
        -- If the ball stops in sand, create a small depression
        if currentCellType == ball.CellTypes.SAND and not ball.craterCreated then
            ball:createSandDepression()
        end
    end
    
    -- Check if ball is in a hole
    if ball:checkHole() then
        ball.inHole = true
        ball.active = false
        
        if ball.debug then
            print("[BALL] Ball in hole!")
        end
    end
end

-- Handle collisions with solid cells and boundaries
function BallPhysics.handleCollisions(ball, oldX, oldY, dt)
    -- Check for collisions with solid cells
    local newCellX = math.floor(ball.position.x)
    local newCellY = math.floor(ball.position.y)
    
    -- Get the cell type at the new position
    local cellType = ball.cellWorld:getCell(newCellX, newCellY)
    
    -- Check if the new position would be inside a solid cell
    if cellType == ball.CellTypes.STONE or cellType == ball.CellTypes.DIRT or cellType == ball.CellTypes.BOUNDARY then
        -- Find which direction to bounce
        local oldCellX = math.floor(oldX)
        local oldCellY = math.floor(oldY)
        
        -- Get the old cell type
        local oldCellType = ball.cellWorld:getCell(oldCellX, oldCellY)
        
        -- Calculate impact force for potential crater formation
        local speed = math.sqrt(ball.velocity.x^2 + ball.velocity.y^2)
        local impactForce = speed * 0.5  -- Simple impact force calculation
        
        -- Horizontal collision
        if oldCellX ~= newCellX then
            local sideCell = ball.cellWorld:getCell(newCellX, oldCellY)
            if sideCell == ball.CellTypes.STONE or sideCell == ball.CellTypes.DIRT or sideCell == ball.CellTypes.BOUNDARY then
                -- Bounce with appropriate factor based on material
                local bounceFactor = ball:getMaterialBounceFactor(sideCell)
                ball.velocity.x = -ball.velocity.x * bounceFactor
                ball.position.x = oldX  -- Revert to old position
                
                -- Create impact effect if hitting with enough force
                if impactForce > 3.0 then
                    ball:createImpactEffect(newCellX, oldCellY, sideCell, impactForce)
                end
                
                if ball.debug then
                    print("[COLLISION] Horizontal collision with " .. ball:getMaterialName(sideCell))
                end
            end
        end
        
        -- Vertical collision
        if oldCellY ~= newCellY then
            local floorCell = ball.cellWorld:getCell(oldCellX, newCellY)
            if floorCell == ball.CellTypes.STONE or floorCell == ball.CellTypes.DIRT or floorCell == ball.CellTypes.BOUNDARY then
                -- Bounce with appropriate factor based on material
                local bounceFactor = ball:getMaterialBounceFactor(floorCell)
                ball.velocity.y = -ball.velocity.y * bounceFactor
                ball.position.y = oldY  -- Revert to old position
                
                -- Create impact effect if hitting with enough force
                if impactForce > 3.0 then
                    ball:createImpactEffect(oldCellX, newCellY, floorCell, impactForce)
                end
                
                if ball.debug then
                    print("[COLLISION] Vertical collision with " .. ball:getMaterialName(floorCell))
                end
            end
        end
        
        -- Diagonal collision
        if oldCellX ~= newCellX and oldCellY ~= newCellY then
            -- Bounce with appropriate factor based on material
            local bounceFactor = ball:getMaterialBounceFactor(cellType)
            ball.velocity.x = -ball.velocity.x * bounceFactor
            ball.velocity.y = -ball.velocity.y * bounceFactor
            ball.position.x = oldX  -- Revert to old position
            ball.position.y = oldY  -- Revert to old position
            
            -- Create impact effect if hitting with enough force
            if impactForce > 3.0 then
                ball:createImpactEffect(newCellX, newCellY, cellType, impactForce)
            end
            
            if ball.debug then
                print("[COLLISION] Diagonal collision with " .. ball:getMaterialName(cellType))
            end
        end
    end
    
    -- Check for liquid effects
    if ball.cellWorld:isLiquid(newCellX, newCellY) then
        -- Standard liquid physics
        ball.velocity.x = ball.velocity.x * 0.95
        ball.velocity.y = ball.velocity.y * 0.95
        
        -- Buoyancy effect
        ball.velocity.y = ball.velocity.y - 0.1
    end
    
    -- Boundary checking
    local worldWidth = ball.cellWorld.width
    local worldHeight = ball.cellWorld.height
    
    if ball.position.x < 1 then
        ball.position.x = 1
        ball.velocity.x = -ball.velocity.x * ball.bounceFactor
        
        if ball.debug then
            print("[COLLISION] Hit left boundary")
        end
    elseif ball.position.x > worldWidth - 1 then
        ball.position.x = worldWidth - 1
        ball.velocity.x = -ball.velocity.x * ball.bounceFactor
        
        if ball.debug then
            print("[COLLISION] Hit right boundary")
        end
    end
    
    if ball.position.y < 1 then
        ball.position.y = 1
        ball.velocity.y = -ball.velocity.y * ball.bounceFactor
        
        if ball.debug then
            print("[COLLISION] Hit top boundary")
        end
    elseif ball.position.y > worldHeight - 1 then
        ball.position.y = worldHeight - 1
        ball.velocity.y = -ball.velocity.y * ball.bounceFactor
        
        if ball.debug then
            print("[COLLISION] Hit bottom boundary")
        end
    end
end

-- Check if the ball is moving
function BallPhysics.isMoving(ball)
    -- Calculate the ball's speed
    local speed = math.sqrt(ball.velocity.x^2 + ball.velocity.y^2)
    
    -- Ball is considered moving if its speed is above the rest threshold
    return speed > ball.restThreshold
end

-- Check if the ball can be shot
function BallPhysics.canShoot(ball)
    -- Ball can be shot if it's active, not in a hole, not moving, and not sinking in water
    return ball.active and not ball.inHole and not BallPhysics.isMoving(ball) and not ball.sinkingInWater
end

-- Check if the ball is in a hole
function BallPhysics.checkHole(ball)
    -- Check if the current cell is a hole
    local cellX = math.floor(ball.position.x)
    local cellY = math.floor(ball.position.y)
    
    local cellType = ball.cellWorld:getCell(cellX, cellY)
    return cellType == ball.CellTypes.HOLE  -- Hole cell type
end

return BallPhysics
