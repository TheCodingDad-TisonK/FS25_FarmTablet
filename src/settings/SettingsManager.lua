-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
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
---@class SettingsManager
SettingsManager = {}
local SettingsManager_mt = Class(SettingsManager)

SettingsManager.MOD_NAME = g_currentModName
SettingsManager.XMLTAG = "FarmTablet"

SettingsManager.defaultConfig = {
    enabled = true,
    tabletKeybind = "T",
    showTabletNotifications = true,
    startupApp = 1, -- Dashboard
    vibrationFeedback = true,
    soundEffects = true,
    debugMode = false
}

function SettingsManager.new()
    return setmetatable({}, SettingsManager_mt)
end

function SettingsManager:getSavegameXmlFilePath()
    if g_currentMission.missionInfo and g_currentMission.missionInfo.savegameDirectory then
        return ("%s/%s.xml"):format(g_currentMission.missionInfo.savegameDirectory, SettingsManager.MOD_NAME)
    end
    return nil
end

function SettingsManager:loadSettings(settingsObject)
    local xmlPath = self:getSavegameXmlFilePath()
    if xmlPath and fileExists(xmlPath) then
        local xml = XMLFile.load("ft_Config", xmlPath)
        if xml then
            settingsObject.enabled = xml:getBool(self.XMLTAG..".enabled", self.defaultConfig.enabled)
            settingsObject.tabletKeybind = xml:getString(self.XMLTAG..".tabletKeybind", self.defaultConfig.tabletKeybind)
            settingsObject.showTabletNotifications = xml:getBool(self.XMLTAG..".showTabletNotifications", self.defaultConfig.showTabletNotifications)
            settingsObject.startupApp = xml:getInt(self.XMLTAG..".startupApp", self.defaultConfig.startupApp)
            settingsObject.vibrationFeedback = xml:getBool(self.XMLTAG..".vibrationFeedback", self.defaultConfig.vibrationFeedback)
            settingsObject.soundEffects = xml:getBool(self.XMLTAG..".soundEffects", self.defaultConfig.soundEffects)
            settingsObject.debugMode = xml:getBool(self.XMLTAG..".debugMode", self.defaultConfig.debugMode)
            
            xml:delete()
            return
        end
    end
    settingsObject.enabled = self.defaultConfig.enabled
    settingsObject.tabletKeybind = self.defaultConfig.tabletKeybind
    settingsObject.showTabletNotifications = self.defaultConfig.showTabletNotifications
    settingsObject.startupApp = self.defaultConfig.startupApp
    settingsObject.vibrationFeedback = self.defaultConfig.vibrationFeedback
    settingsObject.soundEffects = self.defaultConfig.soundEffects
    settingsObject.debugMode = self.defaultConfig.debugMode
end

function SettingsManager:saveSettings(settingsObject)
    local xmlPath = self:getSavegameXmlFilePath()
    if not xmlPath then return end
    
    local xml = XMLFile.create("ft_Config", xmlPath, self.XMLTAG)
    if xml then
        xml:setBool(self.XMLTAG..".enabled", settingsObject.enabled)
        xml:setString(self.XMLTAG..".tabletKeybind", settingsObject.tabletKeybind)
        xml:setBool(self.XMLTAG..".showTabletNotifications", settingsObject.showTabletNotifications)
        xml:setInt(self.XMLTAG..".startupApp", settingsObject.startupApp)
        xml:setBool(self.XMLTAG..".vibrationFeedback", settingsObject.vibrationFeedback)
        xml:setBool(self.XMLTAG..".soundEffects", settingsObject.soundEffects)
        xml:setBool(self.XMLTAG..".debugMode", settingsObject.debugMode)
        
        xml:save()
        xml:delete()
    end
end