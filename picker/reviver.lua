-------------------------------------------------------------------------------
--[[Reviver]] -- Revives the selected entity
-------------------------------------------------------------------------------
local Area = require("stdlib.area.area")
local Player = require("stdlib.event.player")
local lib = require("picker.lib")

--as of 08/30 this is mostly incorporated into base.
--Modules are still not revived,
--items on ground are not picked up
--tile proxys are not selected  Should be added to pippette to put in hand

local function revive_it(event)
    local placed = event.created_entity
    if not lib.ghosts[placed.name] and Area(placed.selection_box):size() > 0 then
        local player = Player.get(event.player_index)
        lib.satisfy_requests(player, placed)
    end
end
Event.register(defines.events.on_built_entity, revive_it)

local function picker_revive_selected(event)
    local player = game.players[event.player_index]
    if player.selected and player.controller_type ~= defines.controllers.ghost then
        if player.selected.name == "item-on-ground" then --and not player.cursor_stack.valid_for_read then
            return player.clean_cursor() and player.cursor_stack.swap_stack(player.selected.stack)
        elseif player.selected.name == "item-request-proxy" and not player.cursor_stack.valid_for_read then
            lib.satisfy_requests(player, player.selected)
        end
    end
end
Event.register("picker-select", picker_revive_selected)

return picker_revive_selected
