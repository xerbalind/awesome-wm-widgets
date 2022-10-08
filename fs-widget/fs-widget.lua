local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local naughty = require("naughty")

local widget = {}

--- Table with widget configuration, consists of three sections:
---  - general - general configuration
---  - widget - configuration of the widget displayed on the wibar
---  - popup - configuration of the popup
local config = {}

-- general
config.mounts = { '/' }

-- wibar widget
config.widget_width = 40
config.widget_bar_color = '#aaaaaa'
config.widget_onclick_bg = '#ff0000'
config.widget_border_color = '#535d6c66'
config.widget_background_color = '#22222233'

config.bg = '#22222233'
config.border_width = 1
config.border_color = '#535d6c66'
config.bar_color = '#aaaaaa'
config.bar_background_color = '#22222233'
config.bar_border_color = '#535d6c66'

local function worker(user_args)
    local args = user_args or {}
    local parent = args.parent or {}
    local timeout = args.timeout or 1
    local width = args.width or 50

    -- Setup config for the widget instance.
    -- The `_config` table will keep the first existing value after checking
    -- in this order: user parameter > beautiful > module default.
    local _config = {}
    for prop, value in pairs(config) do
        _config[prop] = args[prop] or beautiful[prop] or value
    end

    widget = wibox.widget {
        shape = gears.shape.rounded_rect,
        widget = wibox.container.margin,
        forced_width = width,
    }

    local disk_rows = {
        { widget = wibox.widget.textbox },
        spacing = 4,
        layout = wibox.layout.fixed.vertical,
    }

    local disk_header = wibox.widget {
        {
            markup = '<b>Mount</b>',
            forced_width = 150,
            align = 'left',
            widget = wibox.widget.textbox,
        },
        {
            markup = '<b>Used</b>',
            align = 'left',
            widget = wibox.widget.textbox,
        },
        layout = wibox.layout.ratio.horizontal
    }
    disk_header:ajust_ratio(1, 0, 0.3, 0.7)

    --[[ local popup = awful.popup { ]]
    --[[     bg = _config.popup_bg, ]]
    --[[     ontop = true, ]]
    --[[     visible = false, ]]
    --[[     shape = gears.shape.rounded_rect, ]]
    --[[     border_width = _config.popup_border_width, ]]
    --[[     border_color = _config.popup_border_color, ]]
    --[[     maximum_width = 400, ]]
    --[[     offset = { y = 5 }, ]]
    --[[     widget = {} ]]
    --[[ } ]]

    --[[ storage_bar_widget:buttons( ]]
    --[[         awful.util.table.join( ]]
    --[[                 awful.button({}, 1, function() ]]
    --[[                     if popup.visible then ]]
    --[[                         popup.visible = not popup.visible ]]
    --[[                         storage_bar_widget:set_bg('#00000000') ]]
    --[[                     else ]]
    --[[                         storage_bar_widget:set_bg(_config.widget_background_color) ]]
    --[[                         popup:move_next_to(mouse.current_widget_geometry) ]]
    --[[                     end ]]
    --[[                 end) ]]
    --[[         ) ]]
    --[[ ) ]]

    local widget_timer = gears.timer {
      timeout = timeout
    }

   parent:connect_signal("show",
      function()
        widget_timer:start()
        widget_timer:emit_signal("timeout")
    end)

    parent:connect_signal("hide",
      function()
        widget_timer:stop()
    end)


    local disks = {}
    widget_timer:connect_signal("timeout",function ()
      awful.spawn.easy_async([[bash -c "df | tail -n +2"]],
            function(stdout,_,_,_)
                for line in stdout:gmatch("[^\r\n$]+") do
                    local filesystem, size, used, avail, perc, mount =
                        line:match('([%p%w]+)%s+([%d%w]+)%s+([%d%w]+)%s+([%d%w]+)%s+([%d]+)%%%s+([%p%w]+)')

                    disks[mount] = {}
                    disks[mount].filesystem = filesystem
                    disks[mount].size = size
                    disks[mount].used = used
                    disks[mount].avail = avail
                    disks[mount].perc = perc
                    disks[mount].mount = mount

                    --[[ if disks[mount].mount == _config.mounts[1] then ]]
                    --[[     widget:set_value(tonumber(disks[mount].perc)) ]]
                    --[[ end ]]
                end


                for k, v in ipairs(_config.mounts) do

                    local row = wibox.widget {
                        {
                            text = disks[v].mount,
                            forced_width = 150,
                            widget = wibox.widget.textbox
                        },
                        {
                            color = _config.bar_color,
                            max_value = 100,
                            value = tonumber(disks[v].perc),
                            forced_height = 20,
                            paddings = 1,
                            margins = 4,
                            border_width = 1,
                            border_color = _config.bar_border_color,
                            background_color = _config.bar_background_color,
                            bar_border_width = 1,
                            bar_border_color = _config.bar_border_color,
                            widget = wibox.widget.progressbar,
                        },
                        {
                            text = math.floor(disks[v].used / 1024 / 1024)
                                    .. '/'
                                    .. math.floor(disks[v].size / 1024 / 1024) .. 'GB('
                                    .. math.floor(disks[v].perc) .. '%)',
                            widget = wibox.widget.textbox
                        },
                        layout = wibox.layout.ratio.horizontal,
                        spacing = 15,
                    }
                    row:ajust_ratio(2, 0.3, 0.3, 0.4)

                    disk_rows[k] = row
                end
                widget:setup {
                    {
                        disk_header,
                        disk_rows,
                        layout = wibox.layout.fixed.vertical,
                    },
                    margins = 8,
                    widget = wibox.container.margin
                }
            end
    )end)


    return widget
end

return setmetatable(widget, { __call = function(_, ...)
    return worker(...)
end })
