-- Minimise, which Hyprland lacks: a minimised window waits on a hidden special
-- workspace, tagged with the workspace it came from, and comes back there,
-- focused, when restored. Super+M, the Floating layout's title bars and the
-- shell's dock all end here; the dock asks through wlr-foreign-toplevel,
-- which Hyprland reports as window.minimize. Focusing a minimised window any
-- other way (the overview, a notification) restores it too.
--
-- An app's own minimise button reaches window.minimize only through our
-- minimize-requests plugin (install.sh plugins): Hyprland 0.57 drops
-- xdg_toplevel.set_minimized without telling anyone.

local hidden = "special:minimized"
local prefix = "hyprmonk-from-"

local function minimised(window)
    return window.workspace ~= nil and window.workspace.name == hidden
end

-- The workspace a minimised window came from, from its tag.
local function origin(window)
    for _, tag in ipairs(window.tags) do
        local id = tag:match("^" .. prefix:gsub("%-", "%%-") .. "(%d+)%*?$")
        if id then return id end
    end
end

-- The active window, or the one `selector` names ("address:0x...").
function hyprmonk_minimise(selector)
    local window = selector and hl.get_window(selector) or hl.get_active_window()
    if not window or not window.workspace or minimised(window) then return end
    local target = "address:" .. window.address
    -- From a special workspace (the scratchpad) it comes back to wherever
    -- the user is when restoring.
    if window.workspace.id > 0 then
        hl.dispatch(hl.dsp.window.tag({ tag = "+" .. prefix .. window.workspace.id, window = target }))
    end
    hl.dispatch(hl.dsp.window.move({ workspace = hidden, follow = false, window = target }))
end

function hyprmonk_restore(selector)
    local window = hl.get_window(selector)
    if not window then return end
    local target = "address:" .. window.address
    local from = origin(window)
    if minimised(window) then
        local to = from or tostring(hl.get_active_workspace().id)
        hl.dispatch(hl.dsp.window.move({ workspace = to, follow = false, window = target }))
    end
    if from then hl.dispatch(hl.dsp.window.tag({ tag = "-" .. prefix .. from, window = target })) end
    hl.dispatch(hl.dsp.focus({ window = target }))
end

-- The window minimised last: of the minimised ones, the one focused last.
function hyprmonk_restore_last()
    local last
    for _, window in ipairs(hl.get_windows()) do
        if minimised(window) and (not last or window.focus_history_id < last.focus_history_id) then
            last = window
        end
    end
    if last then hyprmonk_restore("address:" .. last.address) end
end

hl.on("window.minimize", function(window, minimise)
    if not window then return end
    if minimise then hyprmonk_minimise("address:" .. window.address)
    else hyprmonk_restore("address:" .. window.address) end
end)

hl.on("window.active", function(window)
    if window and minimised(window) then hyprmonk_restore("address:" .. window.address) end
end)
