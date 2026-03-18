-- =========================================================
-- FarmTablet v2 – FunctionHooks  (legacy utility)
-- General-purpose function hook helpers (prepend/append/
-- overwrite). Retained for third-party companion mods that
-- may depend on it. The v2 core uses Utils.appendedFunction
-- and Utils.prependedFunction directly instead.
-- =========================================================

FunctionHooks = {}

--- Prepend a function (new function runs BEFORE original)
--- @param oldTarget table The table containing the original function
--- @param oldFunc string The name of the original function
--- @param newTarget table The table containing the new function
--- @param newFunc string The name of the new function
function FunctionHooks.prependFunction(oldTarget, oldFunc, newTarget, newFunc)
    if oldTarget == nil or oldFunc == nil or newTarget == nil or newFunc == nil then
        Logging.warning("[FunctionHooks] Missing parameters for prependFunction")
        return false
    end
    
    local superFunc = oldTarget[oldFunc]
    
    if superFunc == nil then
        Logging.warning(string.format("[FunctionHooks] Function %s does not exist",
            tostring(oldFunc)))
        return false
    end
    
    oldTarget[oldFunc] = function(...)
        newTarget[newFunc](newTarget, ...)
        return superFunc(...)
    end
    
    return true
end

--- Append a function (new function runs AFTER original)
--- @param oldTarget table The table containing the original function
--- @param oldFunc string The name of the original function
--- @param newTarget table The table containing the new function
--- @param newFunc string The name of the new function
function FunctionHooks.appendFunction(oldTarget, oldFunc, newTarget, newFunc)
    if oldTarget == nil or oldFunc == nil or newTarget == nil or newFunc == nil then
        Logging.warning("[FunctionHooks] Missing parameters for appendFunction")
        return false
    end
    
    local superFunc = oldTarget[oldFunc]
    
    if superFunc == nil then
        Logging.warning(string.format("[FunctionHooks] Function %s does not exist",
            tostring(oldFunc)))
        return false
    end
    
    oldTarget[oldFunc] = function(...)
        local results = {superFunc(...)}
        newTarget[newFunc](newTarget, ...)
        return unpack(results)
    end
    
    return true
end

--- Overwrite a function (replace original with new function)
--- @param oldTarget table The table containing the original function
--- @param oldFunc string The name of the original function
--- @param newTarget table The table containing the new function
--- @param newFunc string The name of the new function
--- @param isStatic boolean Whether the function is static (no self parameter)
function FunctionHooks.overwriteFunction(oldTarget, oldFunc, newTarget, newFunc, isStatic)
    if oldTarget == nil or oldFunc == nil or newTarget == nil or newFunc == nil then
        Logging.warning("[FunctionHooks] Missing parameters for overwriteFunction")
        return false
    end
    
    local superFunc = oldTarget[oldFunc]
    
    if isStatic then
        oldTarget[oldFunc] = function(...)
            return newTarget[newFunc](newTarget, superFunc, ...)
        end
    else
        oldTarget[oldFunc] = function(self, ...)
            return newTarget[newFunc](newTarget, self, superFunc, ...)
        end
    end
    
    return true
end

--- Safe hook function (with error handling)
--- @param hookType string "prepend", "append", or "overwrite"
--- @param oldTarget table The table containing the original function
--- @param oldFunc string The name of the original function
--- @param newTarget table The table containing the new function
--- @param newFunc string The name of the new function
--- @param isStatic boolean Whether the function is static (for overwrite only)
function FunctionHooks.safeHook(hookType, oldTarget, oldFunc, newTarget, newFunc, isStatic)
    local success, errorMsg = pcall(function()
        if hookType == "prepend" then
            return FunctionHooks.prependFunction(oldTarget, oldFunc, newTarget, newFunc)
        elseif hookType == "append" then
            return FunctionHooks.appendFunction(oldTarget, oldFunc, newTarget, newFunc)
        elseif hookType == "overwrite" then
            return FunctionHooks.overwriteFunction(oldTarget, oldFunc, newTarget, newFunc, isStatic or false)
        else
            error("Invalid hook type: " .. tostring(hookType))
        end
    end)
    
    if not success then
        Logging.error(string.format("[FunctionHooks] Failed to hook %s: %s",
            tostring(oldFunc), errorMsg))
        return false
    end
    
    return success
end

--- Check if a function exists
--- @param target table The table to check
--- @param funcName string The function name to check
--- @return boolean True if function exists
function FunctionHooks.functionExists(target, funcName)
    if target == nil or funcName == nil then
        return false
    end
    
    return target[funcName] ~= nil and type(target[funcName]) == "function"
end

--- Create a hook for a class method
--- @param className string The class name
--- @param methodName string The method name
--- @param hookType string "prepend", "append", or "overwrite"
--- @param hookTarget table The table containing the hook function
--- @param hookFunc string The hook function name
function FunctionHooks.hookClassMethod(className, methodName, hookType, hookTarget, hookFunc)
    local class = _G[className]
    if class == nil then
        Logging.warning(string.format("[FunctionHooks] Class '%s' not found", className))
        return false
    end
    
    return FunctionHooks.safeHook(hookType, class, methodName, hookTarget, hookFunc)
end

--- Remove a hook (restore original function)
--- Note: This only works if you stored the original function
--- @param oldTarget table The table containing the hooked function
--- @param oldFunc string The name of the hooked function
--- @param originalFunc function The original function to restore
function FunctionHooks.removeHook(oldTarget, oldFunc, originalFunc)
    if oldTarget == nil or oldFunc == nil or originalFunc == nil then
        Logging.warning("[FunctionHooks] Missing parameters for removeHook")
        return false
    end
    
    oldTarget[oldFunc] = originalFunc
    return true
end

-- Make it globally available (optional)
if g_functionHooks == nil then
    g_functionHooks = FunctionHooks
end

Logging.info("[FunctionHooks] Utility loaded")