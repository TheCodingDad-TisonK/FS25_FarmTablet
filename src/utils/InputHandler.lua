-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- Central tablet interface for farm management mods
-- =========================================================
-- Author: TisonK
-- =========================================================
---@class InputHandler
InputHandler = {}
local InputHandler_mt = Class(InputHandler)

function InputHandler.new(tabletManager)
    local self = setmetatable({}, InputHandler_mt)
    self.tabletManager = tabletManager
    self.lastKeyState = {}
    self.keyConstant = nil
    return self
end

function InputHandler:registerKeyBinding()
    local keybind = self.tabletManager.settings.tabletKeybind or "T"
    self.keyConstant = self:getKeyConstant(keybind)
    
    if self.keyConstant then
        self.tabletManager:log("Tablet keybind configured: %s (Key: %d)", keybind, self.keyConstant)
    else
        self.tabletManager:log("Warning: Invalid keybind '%s', defaulting to 'T'", keybind)
        self.keyConstant = Input.KEY_t
    end
    
    -- FS25 uses direct key checking in update loop
    self.tabletManager:log("Using direct key checking for tablet toggle")
end

function InputHandler:update(dt)
    if not self.keyConstant or not self.tabletManager then
        return
    end
    
    -- Check if our key was pressed
    local isPressed = Input.isKeyPressed(self.keyConstant)
    local wasPressed = self.lastKeyState[self.keyConstant] or false
    
    -- Detect new key press (not hold)
    if isPressed and not wasPressed then
        self.tabletManager:toggleTablet()
    end
    
    -- Store current state for next frame
    self.lastKeyState[self.keyConstant] = isPressed
end

function InputHandler:getKeyConstant(keyString)
    -- FS25 Key constants mapping
    local keyMap = {
        ["T"] = Input.KEY_t,
        ["I"] = Input.KEY_i,
        ["P"] = Input.KEY_p,
        ["B"] = Input.KEY_b,
        ["M"] = Input.KEY_m,
        ["N"] = Input.KEY_n,
        ["F1"] = Input.KEY_f1,
        ["F2"] = Input.KEY_f2,
        ["F3"] = Input.KEY_f3,
        ["F4"] = Input.KEY_f4,
        ["F5"] = Input.KEY_f5,
        ["F6"] = Input.KEY_f6,
        ["F7"] = Input.KEY_f7,
        ["F8"] = Input.KEY_f8,
        ["F9"] = Input.KEY_f9,
        ["F10"] = Input.KEY_f10,
        ["F11"] = Input.KEY_f11,
        ["F12"] = Input.KEY_f12,
        ["`"] = Input.KEY_grave,
        ["~"] = Input.KEY_grave,
        ["TAB"] = Input.KEY_tab,
        ["CAPS"] = Input.KEY_capslock,
        ["LSHIFT"] = Input.KEY_lshift,
        ["LCTRL"] = Input.KEY_lcontrol,
        ["LALT"] = Input.KEY_lmenu,
        ["SPACE"] = Input.KEY_space,
        ["ENTER"] = Input.KEY_return,
        ["BACKSPACE"] = Input.KEY_back,
        ["DELETE"] = Input.KEY_delete,
        ["HOME"] = Input.KEY_home,
        ["END"] = Input.KEY_end,
        ["PAGEUP"] = Input.KEY_pageup,
        ["PAGEDOWN"] = Input.KEY_pagedown,
        ["INSERT"] = Input.KEY_insert,
        ["ESC"] = Input.KEY_escape,
        ["LEFT"] = Input.KEY_left,
        ["RIGHT"] = Input.KEY_right,
        ["UP"] = Input.KEY_up,
        ["DOWN"] = Input.KEY_down,
        ["NUM0"] = Input.KEY_numpad0,
        ["NUM1"] = Input.KEY_numpad1,
        ["NUM2"] = Input.KEY_numpad2,
        ["NUM3"] = Input.KEY_numpad3,
        ["NUM4"] = Input.KEY_numpad4,
        ["NUM5"] = Input.KEY_numpad5,
        ["NUM6"] = Input.KEY_numpad6,
        ["NUM7"] = Input.KEY_numpad7,
        ["NUM8"] = Input.KEY_numpad8,
        ["NUM9"] = Input.KEY_numpad9,
        ["NUMMULT"] = Input.KEY_multiply,
        ["NUMADD"] = Input.KEY_add,
        ["NUMSUB"] = Input.KEY_subtract,
        ["NUMDEC"] = Input.KEY_decimal,
        ["NUMDIV"] = Input.KEY_divide,
    }
    
    return keyMap[keyString:upper()]
end

function InputHandler:unregisterKeyBinding()
    -- Nothing to unregister with direct key checking
    self.lastKeyState = {}
    self.keyConstant = nil
    self.tabletManager:log("Input handler cleaned up")
end