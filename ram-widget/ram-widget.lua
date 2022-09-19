local awful = require("awful")
local gears = require("gears")
local watch = require("awful.widget.watch")
local wibox = require("wibox")
local beautiful = require("beautiful")


local ramgraph_widget = {}

local function worker(user_args)
    local args = user_args or {}
    local parent = args.parent or {}
    local timeout = args.timeout or 10
    local color_used = args.color_used or beautiful.bg_urgent
    local color_free = args.color_free or beautiful.fg_normal
    local color_buf  = args.color_buf  or beautiful.border_color_active
    local widget_height = args.widget_height or 200
    local widget_width = args.widget_width or 400


    ramgraph_widget = wibox.widget {
      forced_height = widget_height,
      forced_width = widget_width,
      border_width = 1,
      colors = {
        color_used,
        color_free,
        color_buf,
      },
      widget = wibox.widget.piechart,
    }

    --luacheck:ignore 231
    local total, used, free, shared, buff_cache, available, total_swap, used_swap, free_swap

    local function getPercentage(value)
        return math.floor(value / (total+total_swap) * 100 + 0.5) .. '%'
    end

    local function updateData()
     ramgraph_widget.data_list = {
        {'used ' .. getPercentage(used + used_swap), used + used_swap},
        {'free ' .. getPercentage(free + free_swap), free + free_swap},
        {'buff_cache ' .. getPercentage(buff_cache), buff_cache}
      } 
    end

    watch('bash -c "LANGUAGE=en_US.UTF-8 free | grep -z Mem.*Swap.*"', timeout,
        function(widget, stdout)
            total, used, free, shared, buff_cache, available, total_swap, used_swap, free_swap =
                stdout:match('(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*Swap:%s*(%d+)%s*(%d+)%s*(%d+)')

            if parent.visible then
              updateData()
            end

        end,
        ramgraph_widget
    )

    parent:connect_signal("show",updateData)

    return ramgraph_widget
end


return setmetatable(ramgraph_widget, { __call = function(_, ...)
    return worker(...)
end })
