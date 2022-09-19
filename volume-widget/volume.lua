-------------------------------------------------
-- The Ultimate Volume Widget for Awesome Window Manager
-- More details could be found here:
-- https://github.com/streetturtle/awesome-wm-widgets/tree/master/volume-widget

-- @author Pavel Makhov
-- @copyright 2020 Pavel Makhov
-------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local spawn = require("awful.spawn")
local gears = require("gears")
local beautiful = require("beautiful")
local watch = require("awful.widget.watch")
local utils = require("awesome-wm-widgets.volume-widget.utils")
local naughty = require("naughty")


local LIST_DEVICES_CMD = [[sh -c "pacmd list-sinks; pacmd list-sources"]]
local function GET_VOLUME_CMD(device) return 'amixer -D ' .. device .. ' sget Master' end
local function SET_VOLUME_CMD(device,value) return 'amixer -D ' .. device .. ' sset Master ' .. value .. '%' end
local function INC_VOLUME_CMD(device, step) return 'amixer -D ' .. device .. ' sset Master ' .. step .. '%+' end
local function DEC_VOLUME_CMD(device, step) return 'amixer -D ' .. device .. ' sset Master ' .. step .. '%-' end
local function TOG_VOLUME_CMD(device) return 'amixer -D ' .. device .. ' sset Master toggle' end


local widget_types = {
    icon_and_text = require("awesome-wm-widgets.volume-widget.widgets.icon-and-text-widget"),
    icon = require("awesome-wm-widgets.volume-widget.widgets.icon-widget"),
    arc = require("awesome-wm-widgets.volume-widget.widgets.arc-widget"),
    horizontal_bar = require("awesome-wm-widgets.volume-widget.widgets.horizontal-bar-widget"),
    vertical_bar = require("awesome-wm-widgets.volume-widget.widgets.vertical-bar-widget")
}
local volume = {}

local rows  = { layout = wibox.layout.fixed.vertical }

volume.widget = wibox.widget {
    maximum_width = 400,
    bg = beautiful.bg_normal,
    widget =  wibox.container.background,
    border_color = beautiful.bg_focus,
    border_width = 1
}

local function build_main_line(device)
    if device.active_port ~= nil and device.ports[device.active_port] ~= nil then
        return device.properties.device_description .. ' · ' .. device.ports[device.active_port]
    else
        return device.properties.device_description
    end
end

local function build_rows(devices, on_checkbox_click, device_type)
    local device_rows  = { layout = wibox.layout.fixed.vertical }
    for _, device in pairs(devices) do

        local checkbox = wibox.widget {
            checked = device.is_default,
            color = beautiful.bg_normal,
            paddings = 2,
            shape = gears.shape.circle,
            forced_width = 20,
            forced_height = 20,
            check_color = beautiful.blue,
            widget = wibox.widget.checkbox
        }

        checkbox:connect_signal("button::press", function()
            spawn.easy_async(string.format([[sh -c 'pacmd set-default-%s "%s"']], device_type, device.name), function()
                on_checkbox_click()
            end)
        end)

        local row = wibox.widget {
            {
                {
                    {
                        checkbox,
                        valign = 'center',
                        layout = wibox.container.place,
                    },
                    {
                        {
                            text = build_main_line(device),
                            align = 'left',
                            widget = wibox.widget.textbox
                        },
                        left = 10,
                        layout = wibox.container.margin
                    },
                    spacing = 8,
                    layout = wibox.layout.align.horizontal
                },
                margins = 4,
                layout = wibox.container.margin
            },
            bg = beautiful.bg_normal,
            widget = wibox.container.background
        }

        row:connect_signal("mouse::enter", function(c) c:set_bg(beautiful.bg_focus) end)
        row:connect_signal("mouse::leave", function(c) c:set_bg(beautiful.bg_normal) end)

        local old_cursor, old_wibox
        row:connect_signal("mouse::enter", function()
            local wb = mouse.current_wibox
            old_cursor, old_wibox = wb.cursor, wb
            wb.cursor = "hand1"
        end)
        row:connect_signal("mouse::leave", function()
            if old_wibox then
                old_wibox.cursor = old_cursor
                old_wibox = nil
            end
        end)

        row:connect_signal("button::press", function()
            spawn.easy_async(string.format([[sh -c 'pacmd set-default-%s "%s"']], device_type, device.name), function()
                on_checkbox_click()
            end)
        end)

        table.insert(device_rows, row)
    end

    return device_rows
end

local function build_header_row(text)
    return wibox.widget{
        {
            markup = "<b>" .. text .. "</b>",
            align = 'center',
            widget = wibox.widget.textbox
        },
        bg = beautiful.bg_normal,
        widget = wibox.container.background
    }
end

local function build_slider(on_value_change,value)
  local slider = wibox.widget {
    bar_height = 5,
    handle_color = beautiful.blue or beautiful.fg_normal,
    handle_shape = gears.shape.losange,
    handle_width = 15,
    bar_shape    = gears.shape.rounded_rect,
    handle_border_color = beautiful.border_color,
    value = value,
    minimum = 0,
    maximum = 100,
    widget = wibox.widget.slider,
    forced_height = 25,
    forced_width = 100,
    opacity = 0.9
  }

  slider:connect_signal("property::value", function()
    on_value_change(slider.value)
  end)

  slider:connect_signal("mouse::enter",function()
    slider.opacity = 1
  end)

  slider:connect_signal("mouse::leave",function()
    slider.opacity = 0.9
  end)


  return slider
end


local function worker(user_args)

    local args = user_args or {}

    local parent = args.parent or {}
    local mixer_cmd = args.mixer_cmd or 'pavucontrol'
    local widget_type = args.widget_type
    local refresh_rate = args.refresh_rate or 2
    local step = args.step or 5
    local device = args.device or 'pulse'

    function rebuild_widget(widget)
        spawn.easy_async(LIST_DEVICES_CMD, function(stdout)

            local sinks, sources = utils.extract_sinks_and_sources(stdout)

            for i = 0, #rows do rows[i]=nil end

            table.insert(rows, build_header_row("SINKS"))
            table.insert(rows, build_rows(sinks, function() rebuild_widget(widget) end, "sink"))
            table.insert(rows, build_header_row("SOURCES"))
            table.insert(rows, build_rows(sources, function() rebuild_widget(widget) end, "source"))
            table.insert(rows, build_header_row("VOLUME: " .. volume.value .. "%"))
            table.insert(rows, build_slider(function(val) 
              spawn(SET_VOLUME_CMD(device,val)) 
              volume.value = val
            end, volume.value))

            widget:setup(rows)
        end)
    end

    function rebuild_widget_callback(widget,stdout)
        volume.value = string.match(stdout, "(%d?%d?%d)%%")
        if parent.visible then
          rebuild_widget(widget)
        end
    end

    function volume:inc(s)
        INC_VOLUME_CMD(device, s or step)
    end

    function volume:dec(s)
        DEC_VOLUME_CMD(device, s or step)    
    end

    function volume:toggle()
        TOG_VOLUME_CMD(device)
    end

    function volume:mixer()
        if mixer_cmd then
            spawn.easy_async(mixer_cmd)
        end
    end
    
    watch(GET_VOLUME_CMD(device), refresh_rate, rebuild_widget_callback,volume.widget)

    return volume.widget
end

return setmetatable(volume, { __call = function(_, ...) return worker(...) end })
