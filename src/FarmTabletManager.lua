-- =========================================================
-- FarmTablet v2 – FarmTabletManager
-- Top-level coordinator
-- =========================================================
---@class FarmTabletManager
FarmTabletManager = {}
local FarmTabletManager_mt = Class(FarmTabletManager)

function FarmTabletManager.new(mission, modDirectory, modName)
    local self = setmetatable({}, FarmTabletManager_mt)

    self.mission      = mission
    self.modDirectory = modDirectory
    self.modName      = modName

    -- Settings subsystem
    self.settingsManager = SettingsManager.new()
    self.settings        = Settings.new(self.settingsManager)
    self.settings:load()

    -- Core systems — FarmTabletSystem is safe on all contexts (pure data).
    -- FarmTabletUI and InputHandler are client-only (rendering + keyboard input).
    self.system = FarmTabletSystem.new(self.settings)
    if mission:getIsClient() then
        self.ui           = FarmTabletUI.new(self.settings, self.system, modDirectory)
        self.inputHandler = InputHandler.new(self)
    end

    -- Settings UI (pause menu injection) — client only
    if mission:getIsClient() and g_gui then
        self.settingsUI = SettingsUI.new(self.settings)
        InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(
            InGameMenuSettingsFrame.onFrameOpen,
            function() self.settingsUI:inject() end
        )
        InGameMenuSettingsFrame.updateButtons = Utils.appendedFunction(
            InGameMenuSettingsFrame.updateButtons,
            function(frame) self.settingsUI:ensureResetButton(frame) end
        )

        -- Help panel sound: play paging sound when the in-game help section opens or closes
        -- InGameMenuHelpFrame is the help/manual page inside the pause menu
        if InGameMenuHelpFrame then
            InGameMenuHelpFrame.onFrameOpen = Utils.appendedFunction(
                InGameMenuHelpFrame.onFrameOpen,
                function()
                    local s = self.settings
                    if s and s.soundEffects and s.soundOnHelpOpen then
                        pcall(function()
                            if g_gui and g_gui.guiSoundPlayer then
                                g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.PAGING)
                            end
                        end)
                    end
                end
            )
            InGameMenuHelpFrame.onFrameClose = Utils.appendedFunction(
                InGameMenuHelpFrame.onFrameClose,
                function()
                    local s = self.settings
                    if s and s.soundEffects and s.soundOnHelpOpen then
                        pcall(function()
                            if g_gui and g_gui.guiSoundPlayer then
                                g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.PAGING)
                            end
                        end)
                    end
                end
            )
        end
    end

    -- Console commands — only register on the local client, not on a remote/server peer.
    -- On a listen-server (host who also plays) getIsClient() is true, so commands appear.
    -- On a pure dedicated server the g_dedicatedServer guard in main.lua prevents us from
    -- ever reaching this constructor, so this check is a secondary safety net.
    if mission:getIsClient() then
        self.settingsGUI = SettingsGUI.new()
        self.settingsGUI:registerConsoleCommands()
    end

    return self
end

function FarmTabletManager:onMissionLoaded()
    self.system:initialize()

    -- inputHandler and UI only exist on clients (see constructor)
    if self.inputHandler then
        self.inputHandler:registerKeyBinding()
    end

    -- Welcome notification: client-only (HUD does not exist on server peers)
    if self.mission:getIsClient() and self.settings.enabled and self.settings.showTabletNotifications then
        local title = (g_i18n and g_i18n:getText("ft_ui_welcome_title")) or "Farm Tablet v2"
        local msg   = string.format(
            (g_i18n and g_i18n:getText("ft_ui_welcome_message")) or "Press %s to open",
            self.settings.tabletKeybind
        )
        self:showNotification(title, msg)
    end
end

function FarmTabletManager:update(dt)
    if not self.settings.enabled then return end
    if self.inputHandler then self.inputHandler:update(dt) end
    if self.system       then self.system:update(dt)      end
    if self.ui           then self.ui:update(dt)          end
end

function FarmTabletManager:openTablet()
    if self.ui then self.ui:openTablet() end
end

function FarmTabletManager:closeTablet()
    if self.ui then self.ui:closeTablet() end
end

function FarmTabletManager:toggleTablet()
    if self.ui then self.ui:toggleTablet() end
end

function FarmTabletManager:switchApp(appId)
    if self.ui then return self.ui:switchApp(appId) end
    return false
end

function FarmTabletManager:showNotification(title, message)
    if not self.mission or not self.settings.showTabletNotifications then return end
    -- HUD only exists on client peers; skip silently on listen-server-only context
    if not self.mission:getIsClient() then return end
    if self.mission.hud and self.mission.hud.showBlinkingWarning then
        self.mission.hud:showBlinkingWarning(title .. ": " .. message, 4000)
    end
end

function FarmTabletManager:delete()
    if self.settings then self.settings:save() end
    if self.inputHandler then self.inputHandler:unregisterKeyBinding() end
    if self.ui then self.ui:delete() end
    Logging.info("[FarmTablet v2] Shutdown complete.")
end

function FarmTabletManager:log(msg, ...)
    if self.settings and self.settings.debugMode then
        Logging.info("[FarmTablet] " .. string.format(msg, ...))
    end
end
