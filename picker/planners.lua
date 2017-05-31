-------------------------------------------------------------------------------
--[[Planners]]--
-------------------------------------------------------------------------------
local Player = require("stdlib.player")
local lib = require("picker.lib")

-------------------------------------------------------------------------------
--[[Planner Menu]]--
-------------------------------------------------------------------------------
local function is_creative(player, item)
    return (item.name:find('creative%-mode') and (player.admin or player.cheat_mode) and remote.call('creative-mode', 'is_enabled'))
end

local function planner_enabled(player, item)
    local recipe = player.force.recipes[item.name]
    return not recipe or (recipe and recipe.enabled) or is_creative(player, item)
end

local function get_or_create_planner_flow(player, destroy)
    local pdata = global.players[player.index]
    local flow = player.gui.center["picker_planner_flow"]
    if flow and destroy then
        return flow.destroy()
    elseif not flow then
        local planners = global.planners
        pdata.planners = {}

        flow = player.gui.center.add{type = "flow", name = "picker_planner_flow", direction = 'vertical'}
        local frame = flow.add{type = 'frame', name = 'picker_planner_frame', direction = 'vertical', caption = {'planner-menu.header'}}
        local scroll = frame.add{type = 'scroll-pane', name = 'picker_planner_scroll'}
        scroll.horizontal_scroll_policy = 'never'
        scroll.style.maximal_height = 110
        local table = scroll.add{type = 'table', name = 'picker_planner_table', colspan = 6}
        for planner in pairs(planners) do
            table.add{
                type = 'sprite-button',
                name = 'picker_planner_table_sprite_'..planner,
                sprite = 'item/'..planner,
                style = 'picker_buttons_med',
                tooltip = {'planner-menu.button', {'item-name.'..planner}}
            }
            pdata.planners[planner] = true
        end
    end
    return flow
end

local function planner_clicked(event)
    local player, pdata = Player.get(event.player_index)
    local item = game.item_prototypes[event.match]

    if item then
        if event.button == defines.mouse_button_type.left then
            if planner_enabled(player, item) and player.clean_cursor() then
                player.cursor_stack.set_stack(event.match)
                event.element.parent.parent.parent.parent.style.visible = false
            else
                player.print({'planner-menu.not-enabled'})
            end
        elseif event.button == defines.mouse_button_type.right then
            event.element.style = event.element.style.name == "picker_buttons_med" and "picker_buttons_med_off" or "picker_buttons_med"
            pdata.planners[item.name] = event.element.style.name == "picker_buttons_med"
        end
    end
end
Gui.on_click('picker_planner_table_sprite_(.*)', planner_clicked)

local function open_or_close_planner_menu(event)
    local player = game.players[event.player_index]
    local flow = get_or_create_planner_flow(player)
    flow.style.visible = not flow.style.visible
end
Event.register("picker-planner-menu", open_or_close_planner_menu)

-------------------------------------------------------------------------------
--[[Next Planner]]--
-------------------------------------------------------------------------------

local function get_next_planner(player, last_planner)
    local stack = player.cursor_stack
    local pdata = global.players[player.index]
    local fail = 0
    get_or_create_planner_flow(player).style.visible = false

    if (not stack.valid_for_read ) then
        local planner
        if player.mod_settings["picker-remember-planner"].value and pdata.planners[last_planner] then
            planner = last_planner
        else
            repeat
                planner = next(pdata.planners, planner)
                fail = fail + 1
            until pdata.planners[planner] and game.item_prototypes[planner] and planner_enabled(player, game.item_prototypes[planner]) or fail == 100
        end
        return planner and pdata.planners[planner] and player.clean_cursor() and lib.get_planner(player, planner)
    elseif stack.valid_for_read then
        local name = stack.name
        if pdata.planners[name] then
            repeat
                name = next(pdata.planners, name)
                fail = fail + 1
            until name and pdata.planners[name] and game.item_prototypes[name] and planner_enabled(player, game.item_prototypes[name]) or fail == 100
            return name and pdata.planners[name] and player.clean_cursor() and lib.get_planner(player, name)
        end
    end
end

-------------------------------------------------------------------------------
--[[Open held item inventory]]--
-------------------------------------------------------------------------------
local function open_held_item_inventory(event)
    local player = game.players[event.player_index]
    if player.cursor_stack.valid_for_read then
        player.opened = player.cursor_stack
    end
end
script.on_event("picker-inventory-editor", open_held_item_inventory)

local function cycle_planners(event)
    local player, pdata = Player.get(event.player_index)
    if player.controller_type ~= defines.controllers.ghost then
        if not pdata.new_simple or not player.cursor_stack.valid_for_read then
            pdata.last_planner = get_next_planner(player, pdata.last_planner) and player.cursor_stack.name
        end
        pdata.new_simple = false
    end
end
script.on_event("picker-next-planner", cycle_planners)

local function planners_changed()
    global.planners = global.planners or {}
    for _, item in pairs(game.item_prototypes) do
        if item.type == "blueprint" or item.type == "deconstruction-item" or item.type == "selection-tool" or item.name == "resource-monitor" then
            if not item.name:find("dummy") then
                global.planners[item.name] = true
            end
        end
    end
    for _, player in pairs(game.players) do
        local gui = player.gui.center["picker_planner_flow"]
        if gui then
            for _, child in pairs(gui["picker_planner_frame"]["picker_planner_scroll"]["picker_planner_table"].children) do
                local match = child.name:match('^picker_planner_table_sprite_(.*)')
                if match and not game.item_prototypes[match] then
                    child.destroy()
                end
            end
        end
    end
end
Event.register(Event.core_events.configuration_changed, planners_changed)
Event.register(Event.core_events.init, planners_changed)