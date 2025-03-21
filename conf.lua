function love.conf(t)
    t.identity = "cellular-golf"           -- The name of the save directory
    t.version = "11.4"                     -- The LÖVE version this game was made for
    t.console = true                       -- Attach a console for debug output
    
    t.window.title = "Cellular Golf"       -- The window title
    t.window.width = 1280                  -- The window width
    t.window.height = 720                  -- The window height
    t.window.resizable = true              -- Let the window be user-resizable
    t.window.minwidth = 800                -- Minimum window width
    t.window.minheight = 600               -- Minimum window height
    t.window.vsync = 0                     -- Vertical sync mode (1 = VSync, 0 = No VSync)
    
    t.modules.audio = true                 -- Enable the audio module
    t.modules.data = true                  -- Enable the data module
    t.modules.event = true                 -- Enable the event module
    t.modules.font = true                  -- Enable the font module
    t.modules.graphics = true              -- Enable the graphics module
    t.modules.image = true                 -- Enable the image module
    t.modules.joystick = true              -- Enable the joystick module
    t.modules.keyboard = true              -- Enable the keyboard module
    t.modules.math = true                  -- Enable the math module
    t.modules.mouse = true                 -- Enable the mouse module
    t.modules.physics = false              -- Disable the physics module (we'll use our own)
    t.modules.sound = true                 -- Enable the sound module
    t.modules.system = true                -- Enable the system module
    t.modules.thread = true                -- Enable the thread module
    t.modules.timer = true                 -- Enable the timer module
    t.modules.touch = true                 -- Enable the touch module
    t.modules.video = false                -- Disable the video module
    t.modules.window = true                -- Enable the window module
end
