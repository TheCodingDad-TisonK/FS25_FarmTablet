-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.0)
-- =========================================================
-- Central tablet interface for farm management mods
-- =========================================================
-- Author: TisonK
-- =========================================================
-- COPYRIGHT NOTICE:
-- All rights reserved. Unauthorized redistribution, copying,
-- or claiming this code as your own is strictly prohibited.
-- Original author: TisonK
-- =========================================================
---@class FarmTabletUI
FarmTabletUI = {}
local FarmTabletUI_mt = Class(FarmTabletUI)

function FarmTabletUI.new(settings, tabletSystem)
    local self = setmetatable({}, FarmTabletUI_mt)
    self.settings = settings
    self.tabletSystem = tabletSystem
    
    -- UI state
    self.isTabletOpen = false
    self.currentApp = "financial_dashboard"
    
    -- UI elements
    self.ui = {
        overlays = {},
        texts = {},
        appButtons = {},
        contentOverlays = {}
    }
    
    -- UI constants
    self.UI_CONSTANTS = {
        WIDTH = 800,
        HEIGHT = 600,
        NAV_BAR_HEIGHT = 40,
        PADDING = 20,
        BACKGROUND_COLOR = {0.1, 0.1, 0.1, 0.95},
        NAV_BAR_COLOR = {0.2, 0.2, 0.2, 0.98},
        APP_BUTTON_SIZE = 40,
        BUTTON_HOVER_COLOR = {0.3, 0.6, 0.3, 0.8},
        BUTTON_NORMAL_COLOR = {0.25, 0.25, 0.25, 0.9},
        TEXT_COLOR = {1, 1, 1, 1},
        BORDER_COLOR = {0.4, 0.7, 0.4, 1},
        CONTENT_BG_COLOR = {0.15, 0.15, 0.15, 0.7}
    }
    
    return self
end

-- Add to FarmTabletUI class (after new function)
function FarmTabletUI:getModPath()
    local modsDirectory = g_modsDirectory or ""
    return modsDirectory .. "/FS25_FarmTablet/"
end

function FarmTabletUI:openTablet()
    if not self.settings.enabled or self.isTabletOpen then
        return
    end

    self.isTabletOpen = true
    self.tabletSystem.isTabletOpen = true
    
    self:log("Opening farm tablet")
    self:createTabletUI()

    if g_currentMission ~= nil then
        g_currentMission:addDrawable(self)
    end

    if g_inputBinding ~= nil then
        g_inputBinding:setShowMouseCursor(true)
        
        -- Register mouse event handler for FS25
        self.oldMouseEventFunc = g_currentMission.mouseEvent
        g_currentMission.mouseEvent = function(mission, posX, posY, isDown, isUp, button)
            -- First let the tablet handle the event
            if self:mouseEvent(posX, posY, isDown, isUp, button) then
                return true  -- Tablet handled it, stop propagation
            end
            
            -- Then call original handler if needed
            if self.oldMouseEventFunc then
                return self.oldMouseEventFunc(mission, posX, posY, isDown, isUp, button)
            end
            return false
        end
    end
end

function FarmTabletUI:closeTablet()
    if not self.isTabletOpen then
        return
    end

    self.isTabletOpen = false
    self.tabletSystem.isTabletOpen = false
    self:log("Closing farm tablet")

    self:destroyTabletUI()

    if g_currentMission ~= nil then
        g_currentMission:removeDrawable(self)
        
        -- Restore original mouse event handler
        if self.oldMouseEventFunc then
            g_currentMission.mouseEvent = self.oldMouseEventFunc
            self.oldMouseEventFunc = nil
        end
    end

    if g_inputBinding ~= nil then
        g_inputBinding:setShowMouseCursor(false)
    end
end

function FarmTabletUI:toggleTablet()
    if self.isTabletOpen then
        self:closeTablet()
    else
        self:openTablet()
    end
end

function FarmTabletUI:createTabletUI()
    self.ui = {}
    self.ui.overlays = {}
    self.ui.texts = {}
    self.ui.appButtons = {}
    self.ui.contentOverlays = {}
    self.ui.appTexts = {}

    -- Calculate screen position
    local tabletWidth, tabletHeight = getNormalizedScreenValues(800, 600)
    
    self.ui.backgroundX = 0.5 - tabletWidth / 2
    self.ui.backgroundY = 0.5 - tabletHeight / 2

    self.UI_CONSTANTS.WIDTH = tabletWidth
    self.UI_CONSTANTS.HEIGHT = tabletHeight

    self.ui.scaleX = tabletWidth / 500
    self.ui.scaleY = tabletHeight / 375

    -- FIXED: Use proper mod path for background
    local bgPath = self:getModPath() .. "hud/backScreen_2.dds"
    
    self:log("Loading background from: " .. bgPath)
    
    -- Try to load the background image
    local success, background = pcall(function()
        return self:createBlankOverlay(
            self.ui.backgroundX,
            self.ui.backgroundY,
            tabletWidth,
            tabletHeight,
            {1, 1, 1, 1},
            bgPath
        )
    end)
    
    if success and background then
        self.ui.background = background
        self:log("Background image loaded successfully")
    else
        -- Fallback to solid color
        self.ui.background = self:createBlankOverlay(
            self.ui.backgroundX,
            self.ui.backgroundY,
            tabletWidth,
            tabletHeight,
            self.UI_CONSTANTS.BACKGROUND_COLOR
        )
        self:log("Could not load background image, using solid color")
    end

    if self.ui.background then
        self.ui.background:setVisible(true)
        table.insert(self.ui.overlays, self.ui.background)
    else
        self:log("ERROR: Failed to create background overlay")
        return
    end

    self:createTabletElements()
end

function FarmTabletUI:createTabletElements()
    local bgX = self.ui.backgroundX
    local bgY = self.ui.backgroundY
    local bgWidth = self.UI_CONSTANTS.WIDTH
    local bgHeight = self.UI_CONSTANTS.HEIGHT

    -- Navigation bar
    local navPadX = self:px(15)
    local navPadY = self:py(15)
    local navHeight = self:py(35)
    local navWidth = bgWidth - (navPadX * 2)
    
    local navBarX = bgX + navPadX
    local navBarY = bgY + bgHeight - navPadY - navHeight

    local navBar = self:createBlankOverlay(
        navBarX,
        navBarY,
        navWidth,
        navHeight,
        self.UI_CONSTANTS.NAV_BAR_COLOR
    )
    navBar:setVisible(true)
    self.ui.navBar = navBar
    table.insert(self.ui.overlays, navBar)

    -- Close button
    local closeSize = self:px(25)
    local closeBtnX = navBarX + navWidth - navPadX - closeSize
    local closeBtnY = navBarY + (navHeight - closeSize) / 2

    local closeButton = self:createBlankOverlay(
        closeBtnX,
        closeBtnY,
        closeSize,
        closeSize,
        {0.8, 0.2, 0.2, 0.9}
    )
    closeButton:setVisible(true)

    self.ui.closeButton = {
        overlay = closeButton,
        x = closeBtnX,
        y = closeBtnY,
        width = closeSize,
        height = closeSize
    }
    table.insert(self.ui.overlays, closeButton)

    -- Title text
    table.insert(self.ui.texts, {
        text = "Farm Tablet v1.1.0.0",
        x = navBarX + navPadX,
        y = navBarY + navHeight / 2 - 0.004,
        size = 0.014,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    -- Close button text
    table.insert(self.ui.texts, {
        text = "X",
        x = closeBtnX + closeSize / 2,
        y = closeBtnY + closeSize / 2 - 0.003,
        size = 0.012,
        align = RenderText.ALIGN_CENTER,
        color = {1, 1, 1, 1}
    })

    -- Create content area
    self:createAppContentArea()
    
    -- Create app navigation buttons
    self:createAppNavigationButtons()
end

function FarmTabletUI:createAppContentArea()
    local pad = self:px(20)
    local headerHeight = self:py(40)
    local y = self.ui.backgroundY + pad + headerHeight
    
    local appButtonsHeight = self:py(40)
    local navBarHeight = self:py(35)
    local bottomPadding = self:py(20)
    
    local availableHeight = self.UI_CONSTANTS.HEIGHT - (y - self.ui.backgroundY) - 
                           appButtonsHeight - navBarHeight - bottomPadding

    local x = self.ui.backgroundX + pad
    local w = self.UI_CONSTANTS.WIDTH - pad * 2
    local h = math.max(availableHeight, self:py(200))

    -- Content background
    local bg = self:createBlankOverlay(
        x,
        y,
        w,
        h,
        self.UI_CONSTANTS.CONTENT_BG_COLOR
    )
    bg:setVisible(true)

    table.insert(self.ui.overlays, bg)
    table.insert(self.ui.contentOverlays, bg)

    self.ui.appContentArea = {
        x = x,
        y = y,
        width = w,
        height = h
    }

    -- Load the current app
    self:loadCurrentApp()
end

-- =========================================================
-- Default App (when no specific app is found)
-- =========================================================
function FarmTabletUI:loadDefaultApp()
    self.ui.appTexts = {}
    
    local content = self.ui.appContentArea
    if not content then return end
    
    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03
    
    -- Title
    table.insert(self.ui.appTexts, {
        text = "Farm Tablet",
        x = content.x + padX,
        y = titleY,
        size = 0.020,
        align = RenderText.ALIGN_LEFT,
        color = {0.4, 0.8, 0.4, 1}
    })
    
    local startY = titleY - 0.035
    local lineHeight = 0.022
    
    local lines = {
        "Welcome to Farm Tablet v1.1.0.0",
        "Central interface for farm management",
        "",
        "Select an app from the navigation bar",
        "",
        "TABLET DOES NOT WORK CORRECTLY AT THIS MOMENT",
        "This will be fixed (hopefully) in the upcoming updates!"
    }
    
    for i, line in ipairs(lines) do
        table.insert(self.ui.appTexts, {
            text = line,
            x = content.x + padX,
            y = startY - ((i - 1) * lineHeight),
            size = 0.014,
            align = RenderText.ALIGN_LEFT,
            color = {0.8, 0.8, 0.8, 1}
        })
    end
    
    self:log("Loaded default app")
end

function FarmTabletUI:loadCurrentApp()
    self.ui.appTexts = {}
    
    local appId = self.tabletSystem.currentApp
    
    if appId == "financial_dashboard" then
        self:loadDashboardApp()
    elseif appId == "app_store" then
        self:loadAppStoreApp()
    elseif appId == "settings" then
        self:loadSettingsApp()
    elseif appId == "updates" then
        self:loadUpdatesApp()
    elseif appId == "weather" then
        self:loadWeatherApp()
    elseif appId == "workshop" then
        self:loadWorkshopApp()
    elseif appId == "digging" then
        self:loadDiggingApp()
    elseif appId == "bucket_tracker" then
        self:loadBucketTrackerApp()
    elseif appId == "income_mod" then
        self:loadIncomeApp()
    elseif appId == "tax_mod" then
        self:loadTaxApp()
    else
        self:loadDefaultApp()
    end
end

function FarmTabletUI:createAppNavigationButtons()
    local navBar = self.ui.navBar
    if navBar == nil then return end

    local navX = navBar.x
    local navY = navBar.y
    local navH = navBar.height
    local navW = navBar.width

    self.ui.appButtons = {}

    local btnSize = self:px(26)
    local spacing = self:px(6)
    local startY = navY - btnSize - self:py(10)
    local leftPadding = self:px(15)
    local rightPadding = self:px(120)
    local startX = navX + leftPadding
    local maxX = navX + navW - rightPadding

    local enabledApps = {}
    for _, app in ipairs(self.tabletSystem.registeredApps) do
        if app.enabled then
            table.insert(enabledApps, app)
        end
    end

    for i, app in ipairs(enabledApps) do
        local x = startX + (i - 1) * (btnSize + spacing)

        if x + btnSize > maxX then
            break
        end

        local overlay = self:createBlankOverlay(
            x,
            startY,
            btnSize,
            btnSize,
            app.id == self.tabletSystem.currentApp and
                self.UI_CONSTANTS.BUTTON_HOVER_COLOR or
                self.UI_CONSTANTS.BUTTON_NORMAL_COLOR
        )
        overlay:setVisible(true)
        table.insert(self.ui.overlays, overlay)

        table.insert(self.ui.appButtons, {
            overlay = overlay,
            x = x,
            y = startY,
            width = btnSize,
            height = btnSize,
            appId = app.id
        })

        -- App button letter
        local appName = g_i18n:getText(app.name) or app.name
        table.insert(self.ui.texts, {
            text = string.sub(appName, 1, 1),
            x = x + btnSize / 2,
            y = startY + btnSize / 2 - 0.005,
            size = 0.011,
            align = RenderText.ALIGN_CENTER,
            color = self.UI_CONSTANTS.TEXT_COLOR
        })
    end
end

function FarmTabletUI:switchApp(appId)
    local appFound = false
    for _, app in ipairs(self.tabletSystem.registeredApps) do
        if app.id == appId and app.enabled then
            appFound = true
            break
        end
    end
    
    if not appFound then
        self:log("App not found or disabled: " .. appId)
        return false
    end

    self.tabletSystem.currentApp = appId
    self.currentApp = appId
    
    self:log("Switched to app: " .. appId)

    if self.settings.soundEffects and g_soundManager then
        g_soundManager:playSample(g_soundManager.samples.GUI_CLICK)
    end

    if self.isTabletOpen then
        -- Update button colors
        for _, buttonInfo in ipairs(self.ui.appButtons) do
            buttonInfo.overlay:setColor(unpack(
                buttonInfo.appId == appId and
                self.UI_CONSTANTS.BUTTON_HOVER_COLOR or
                self.UI_CONSTANTS.BUTTON_NORMAL_COLOR
            ))
        end
        
        -- Reload content
        self.ui.appTexts = {}
        self:loadCurrentApp()
    end

    return true
end

-- Utility functions
function FarmTabletUI:px(x)
    return x * (self.ui.scaleX or 1)
end

function FarmTabletUI:py(y)
    return y * (self.ui.scaleY or 1)
end

function FarmTabletUI:createBlankOverlay(x, y, width, height, color, texturePath)
    local overlay

    if texturePath then
        overlay = Overlay.new(texturePath, x, y, width, height)
    else
        overlay = Overlay.new(nil, x, y, width, height)
    end

    if color then
        overlay:setColor(unpack(color))
    end

    return overlay
end

function FarmTabletUI:log(msg)
    if self.settings.debugMode then
        print("[Farm Tablet UI] " .. tostring(msg))
    end
end

function FarmTabletUI:destroyTabletUI()
    if self.ui.overlays then
        for _, overlay in ipairs(self.ui.overlays) do
            if overlay ~= nil then
                overlay:delete()
            end
        end
    end
    
    self.ui = {
        background = nil,
        backgroundX = 0,
        backgroundY = 0,
        overlays = {},
        appButtons = {},
        contentOverlays = {},
        texts = {},
        appTexts = {},
        navBar = nil,
        appContentArea = nil,
        closeButton = nil
    }
end

function FarmTabletUI:update(dt)
    if not self.isTabletOpen then
        return
    end
    
    -- Update live data if needed
    if self.tabletSystem.currentApp == "financial_dashboard" then
        -- Could add live updates here
    end

    if self.tabletSystem.currentApp == "workshop" then
        self:updateWorkshopApp(dt)
    end


end

function FarmTabletUI:draw()
    if not self.isTabletOpen then
        return
    end

    -- Render overlays
    for _, overlay in ipairs(self.ui.overlays or {}) do
        if overlay ~= nil and overlay.render then
            overlay:render()
        end
    end

    -- Render texts
    for _, t in ipairs(self.ui.texts or {}) do
        setTextAlignment(t.align)
        setTextColor(unpack(t.color))
        renderText(t.x, t.y, t.size, t.text)
    end
    
    -- Render app texts
    for _, t in ipairs(self.ui.appTexts or {}) do
        setTextAlignment(t.align)
        setTextColor(unpack(t.color))
        renderText(t.x, t.y, t.size, t.text)
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
end

function FarmTabletUI:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isTabletOpen or not isDown then
        return false
    end
    
    -- DEBUG: Print mouse coordinates (already normalized in FS25)
    if self.settings.debugMode then
        print(string.format("[Farm Tablet] Mouse click: X=%.4f, Y=%.4f", posX, posY))
    end
    
    -- Close button check (NO conversion needed - FS25 uses normalized coordinates)
    if self.ui.closeButton then
        local btn = self.ui.closeButton
        if self.settings.debugMode then
            print(string.format("[Farm Tablet] Close button area: X=%.4f-%.4f, Y=%.4f-%.4f", 
                btn.x, btn.x + btn.width, btn.y, btn.y + btn.height))
        end
        
        if posX >= btn.x and posX <= btn.x + btn.width and
           posY >= btn.y and posY <= btn.y + btn.height then
            self:log("Close button clicked")
            self:closeTablet()
            return true
        end
    end
    
    -- App buttons check (NO conversion needed)
    for i, buttonInfo in ipairs(self.ui.appButtons or {}) do
        if self.settings.debugMode then
            print(string.format("[Farm Tablet] App button %d (%s): X=%.4f-%.4f, Y=%.4f-%.4f", 
                i, buttonInfo.appId, 
                buttonInfo.x, buttonInfo.x + buttonInfo.width,
                buttonInfo.y, buttonInfo.y + buttonInfo.height))
        end
        
        if posX >= buttonInfo.x and posX <= buttonInfo.x + buttonInfo.width and
           posY >= buttonInfo.y and posY <= buttonInfo.y + buttonInfo.height then
            self:log("App button clicked: " .. buttonInfo.appId)
            self:switchApp(buttonInfo.appId)
            return true
        end
    end
    
    -- Check for app-specific buttons (NO conversion needed)
    local appId = self.tabletSystem.currentApp
    
    if appId == "workshop" then
        if self:handleWorkshopMouseEvent(posX, posY) then
            return true
        end
    elseif appId == "bucket_tracker" then
        if self:handleBucketTrackerMouseEvent(posX, posY) then
            return true
        end
    elseif appId == "income_mod" then
        if self:handleIncomeModMouseEvent(posX, posY) then
            return true
        end
    elseif appId == "tax_mod" then
        if self:handleTaxModMouseEvent(posX, posY) then
            return true
        end
    end
    
    return false
end

-- Workshop app mouse events
function FarmTabletUI:handleWorkshopMouseEvent(posX, posY)
    if self.ui.workshopButton then
        local b = self.ui.workshopButton
        if posX >= b.x and posX <= b.x + b.width and
           posY >= b.y and posY <= b.y + b.height then
            self:openWorkshopForNearestVehicle(15)
            return true
        end
    end
    return false
end

-- Bucket tracker app mouse events
function FarmTabletUI:handleBucketTrackerMouseEvent(posX, posY)
    if self.ui.resetBucketButton then
        local b = self.ui.resetBucketButton
        if posX >= b.x and posX <= b.x + b.width and
           posY >= b.y and posY <= b.y + b.height then
            if self.tabletSystem.resetBucketTracker then
                self.tabletSystem:resetBucketTracker()
                self:switchApp("bucket_tracker") -- Refresh display
            end
            return true
        end
    end
    return false
end

-- Income Mod app mouse events
function FarmTabletUI:handleIncomeModMouseEvent(posX, posY)
    -- Enable button
    if self.ui.enableIncomeButton then
        local b = self.ui.enableIncomeButton
        if posX >= b.x and posX <= b.x + b.width and
           posY >= b.y and posY <= b.y + b.height then
            local incomeInstance = g_IncomeManager or _G["Income"]
            if incomeInstance and incomeInstance.settings then
                incomeInstance.settings.enabled = true
                if incomeInstance.settings.save then
                    incomeInstance.settings:save()
                end
                self:switchApp("income_mod") -- Refresh
            end
            return true
        end
    end
    
    -- Disable button
    if self.ui.disableIncomeButton then
        local b = self.ui.disableIncomeButton
        if posX >= b.x and posX <= b.x + b.width and
           posY >= b.y and posY <= b.y + b.height then
            local incomeInstance = g_IncomeManager or _G["Income"]
            if incomeInstance and incomeInstance.settings then
                incomeInstance.settings.enabled = false
                if incomeInstance.settings.save then
                    incomeInstance.settings:save()
                end
                self:switchApp("income_mod") -- Refresh
            end
            return true
        end
    end
    
    return false
end

-- Tax Mod app mouse events
function FarmTabletUI:handleTaxModMouseEvent(posX, posY)
    -- Enable Tax button
    if self.ui.enableTaxButton then
        local b = self.ui.enableTaxButton
        if posX >= b.x and posX <= b.x + b.width and
           posY >= b.y and posY <= b.y + b.height then
            local taxInstance = g_TaxManager or _G["TaxMod"]
            if taxInstance and taxInstance.settings then
                taxInstance.settings.enabled = true
                if taxInstance.settings.save then
                    taxInstance.settings:save()
                end
                self:switchApp("tax_mod") -- Refresh
            end
            return true
        end
    end
    
    -- Disable Tax button
    if self.ui.disableTaxButton then
        local b = self.ui.disableTaxButton
        if posX >= b.x and posX <= b.x + b.width and
           posY >= b.y and posY <= b.y + b.height then
            local taxInstance = g_TaxManager or _G["TaxMod"]
            if taxInstance and taxInstance.settings then
                taxInstance.settings.enabled = false
                if taxInstance.settings.save then
                    taxInstance.settings:save()
                end
                self:switchApp("tax_mod") -- Refresh
            end
            return true
        end
    end
    
    return false
end

-- Utility function to check if a file exists
function FarmTabletUI:fileExists(path)
    if not path then return false end
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Delete function
function FarmTabletUI:delete()
    self:destroyTabletUI()
end
