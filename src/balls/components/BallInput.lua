-- BallInput.lua - Input handling functions for the ball

local BallInput = {}

-- Start aiming a shot
function BallInput.startAiming(ball, mouseX, mouseY)
    if not ball.active then 
        if ball.debug then
            print("[AIM] Cannot start aiming - ball inactive (active=" .. tostring(ball.active) .. ")")
        end
        return 
    end
    
    if ball.inHole then
        if ball.debug then
            print("[AIM] Cannot start aiming - ball in hole")
        end
        return
    end
    
    -- Don't allow aiming if the ball is sinking in water
    if ball.sinkingInWater then
        if ball.debug then
            print("[AIM] Cannot start aiming - ball is sinking in water")
        end
        return
    end
    
    ball.isAiming = true
    ball.clickPosition = {x = mouseX, y = mouseY}
    ball.currentMousePosition = {x = mouseX, y = mouseY}
    
    if ball.debug then
        print("[AIM] Started aiming at: " .. mouseX .. ", " .. mouseY)
        print("[AIM] Ball position: " .. ball.position.x .. ", " .. ball.position.y)
        print("[AIM] Ball active: " .. tostring(ball.active))
        print("[AIM] Ball in hole: " .. tostring(ball.inHole))
        print("[AIM] Ball can be shot: " .. tostring(ball:canShoot()))
        if not ball:canShoot() then
            print("[AIM] Ball is moving: " .. tostring(ball:isMoving()))
            print("[AIM] Ball velocity: " .. ball.velocity.x .. ", " .. ball.velocity.y)
        end
    end
end

-- Update the aim parameters
function BallInput.updateAim(ball, mouseX, mouseY)
    if not ball.isAiming then 
        if ball.debug then
            print("[AIM] Cannot update aim - not currently aiming")
        end
        return 
    end
    
    ball.currentMousePosition = {x = mouseX, y = mouseY}
    
    -- Calculate drag distance for debugging
    local dx = ball.currentMousePosition.x - ball.clickPosition.x
    local dy = ball.currentMousePosition.y - ball.clickPosition.y
    local distance = math.sqrt(dx*dx + dy*dy)
    
    if ball.debug then
        print("[AIM] Updated aim - drag distance: " .. distance)
    end
end

-- Execute the shot
function BallInput.shoot(ball)
    if not ball.isAiming then
        if ball.debug then
            print("[SHOT] Cannot shoot - not aiming")
        end
        return false 
    end
    
    if not ball.active then
        if ball.debug then
            print("[SHOT] Cannot shoot - ball inactive (active=" .. tostring(ball.active) .. ")")
        end
        return false
    end
    
    if ball.inHole then
        if ball.debug then
            print("[SHOT] Cannot shoot - ball in hole")
        end
        return false
    end
    
    -- Don't allow shooting if the ball is sinking in water
    if ball.sinkingInWater then
        if ball.debug then
            print("[SHOT] Cannot shoot - ball is sinking in water")
        end
        return false
    end
    
    -- Only apply force if the ball can actually be shot
    -- TEMPORARILY ALWAYS RETURN TRUE FOR TESTING
    -- if ball:canShoot() then
    if true then  -- Force to true for testing
        -- Calculate the force vector from the click position to the current mouse position
        local dx = ball.clickPosition.x - ball.currentMousePosition.x
        local dy = ball.clickPosition.y - ball.currentMousePosition.y
        
        -- Convert screen coordinates to world coordinates
        local cellSize = ball.cellWorld.cellSize
        dx = dx / cellSize
        dy = dy / cellSize
        
        -- Apply the force to the ball with a multiplier
        ball.velocity.x = dx * ball.powerMultiplier
        ball.velocity.y = dy * ball.powerMultiplier
        
        -- If the ball is in sand, reduce the initial velocity
        if ball.inSand then
            ball.velocity.x = ball.velocity.x * 0.5
            ball.velocity.y = ball.velocity.y * 0.5
            
            -- Reset the sand crater flag
            ball.craterCreated = false
            
            if ball.debug then
                print("[SHOT] Shot power reduced due to sand")
            end
        end
        
        if ball.debug then
            print("[SHOT] Executed with velocity: " .. ball.velocity.x .. ", " .. ball.velocity.y)
        end
    else
        if ball.debug then
            print("[SHOT] Cannot shoot - ball cannot be shot right now")
            print("[SHOT] Ball is moving: " .. tostring(ball:isMoving()))
            print("[SHOT] Ball velocity: " .. ball.velocity.x .. ", " .. ball.velocity.y)
            print("[SHOT] Ball position: " .. ball.position.x .. ", " .. ball.position.y)
            print("[SHOT] Ball active: " .. tostring(ball.active))
            print("[SHOT] Ball in hole: " .. tostring(ball.inHole))
        end
    end
    
    -- Reset aiming state
    ball.isAiming = false
    
    return true
end

-- Cancel the current shot
function BallInput.cancelShot(ball)
    ball.isAiming = false
    
    if ball.debug then
        print("[AIM] Cancelled aiming")
    end
end

-- Get the current ball position
function BallInput.getCurrentBall(ball)
    -- Return the ball position as a table with x and y coordinates
    return {
        x = ball.position.x,
        y = ball.position.y
    }
end

-- Get the current ball type
function BallInput.getCurrentBallType(ball)
    -- Return the ball type as a string
    if ball.type == ball.BallTypes.BALL then
        return "Ball"
    else
        return "Unknown"
    end
end

-- Check if the ball is in a hole
function BallInput.isInHole(ball)
    return ball.inHole
end

return BallInput
