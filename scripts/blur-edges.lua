local options = require 'mp.options'

local opts = {
    blur_radius = 10,
    blur_power = 10,
    minimum_black_bar_size = 3,
    mode = "all",
    active = true,
    reapply_delay = 0.5,
    watch_later_fix = false,
    only_fullscreen = true,
    scale = true,
    mirror = true,
}
options.read_options(opts)

local active = opts.active
local applied = false

function set_lavfi_complex(filter)
    if not filter and mp.get_property("lavfi-complex") == "" then return end
    local force_window = mp.get_property("force-window")
    local sub = mp.get_property("sub")
    mp.set_property("force-window", "yes")
    if not filter then
        mp.set_property("lavfi-complex", "")
        -- Properly restore video track
        mp.commandv("set", "vid", "auto")
    else
        if not opts.watch_later_fix then
            mp.set_property("vid", "no")
        end
        mp.set_property("lavfi-complex", filter)
    end
    mp.set_property("sub", "no")
    mp.set_property("force-window", force_window)
    mp.set_property("sub", sub)
end

function set_blur()
    if applied then return end
    if not mp.get_property("video-out-params") then 
        return 
    end
    if opts.only_fullscreen and not mp.get_property_bool("fullscreen") then 
        return 
    end
    local video_aspect = mp.get_property_number("video-aspect-override") or mp.get_property_number("video-params/aspect")
    -- If aspect is invalid, calculate it manually from video dimensions
    if not video_aspect or video_aspect <= 0 then
        local par = mp.get_property_number("video-params/par") or 1
        local height = mp.get_property_number("video-params/h")
        local width = mp.get_property_number("video-params/w")
        if width and height and width > 0 and height > 0 then
            video_aspect = (width * par) / height
        else
            mp.msg.error("Could not determine video aspect ratio")
            return
        end
    end
    local ww, wh = mp.get_osd_size()
    if math.abs(ww/wh - video_aspect) < 0.05 then 
        return 
    end
    if opts.mode == "horizontal" and ww/wh < video_aspect then 
        return 
    end
    if opts.mode == "vertical" and ww/wh < video_aspect then 
        return 
    end
    local par = mp.get_property_number("video-params/par") or 1
    local height = mp.get_property_number("video-params/h")
    local width = mp.get_property_number("video-params/w")

    local split = "[vid1] split=3 [a] [v] [b]"
    local crop_format = "crop=%s:%s:%s:%s"
    local scale_format = "scale=width=%s:height=%s:flags=neighbor"

    local stack_direction, cropped_scaled_1, cropped_scaled_2, blur_size

    if ww/wh > video_aspect then
        blur_size = math.floor((ww/wh)*height/par-width)
        local nudge = blur_size % 2
        blur_size = blur_size / 2

        if opts.scale then
            local height_with_maximized_width = height / width * ww
            local visible_height = math.floor(height * par * wh / height_with_maximized_width)
            local visible_width = math.floor(blur_size * wh / height_with_maximized_width)

            local cropped_1 = string.format(crop_format, visible_width, visible_height, "0", (height - visible_height)/2)
            local scaled_1 = string.format(scale_format, blur_size + nudge, height)
            if opts.mirror then
                -- Left edge: crop from left and flip horizontally
                cropped_scaled_1 = cropped_1 .. "," .. scaled_1 .. ",hflip"
            else
                cropped_scaled_1 = cropped_1 .. "," .. scaled_1
            end

            local cropped_2 = string.format(crop_format, visible_width, visible_height, width - visible_width, (height - visible_height)/2)
            local scaled_2 = string.format(scale_format, blur_size, height)
            if opts.mirror then
                -- Right edge: crop from right and flip horizontally
                cropped_scaled_2 = cropped_2 .. "," .. scaled_2 .. ",hflip"
            else
                cropped_scaled_2 = cropped_2 .. "," .. scaled_2
            end
        else
            -- No scaling - just crop the edges
            if opts.mirror then
                -- Left edge: crop from left of video and flip horizontally
                local left_crop = string.format(crop_format, blur_size + nudge, height, "0", "0")
                cropped_scaled_1 = left_crop .. ",hflip"
                -- Right edge: crop from right of video and flip horizontally
                local right_crop = string.format(crop_format, blur_size, height, width - blur_size, "0")
                cropped_scaled_2 = right_crop .. ",hflip"
            else
                local cropped_1 = string.format(crop_format, blur_size + nudge, height, "0", "0")
                cropped_scaled_1 = cropped_1
                local cropped_2 = string.format(crop_format, blur_size, height, width - blur_size, "0")
                cropped_scaled_2 = cropped_2
            end
        end
        stack_direction = "h"
    else
        blur_size = math.floor((wh/ww)*width*par-height)
        local nudge = blur_size % 2
        blur_size = blur_size / 2

        if opts.scale then
            local width_with_maximized_height = width / height * wh
            local visible_width = math.floor(width * ww / width_with_maximized_height)
            local visible_height = math.floor(blur_size * ww / width_with_maximized_height)

            local cropped_1 = string.format(crop_format, visible_width, visible_height, (width - visible_width)/2, "0")
            local scaled_1 = string.format(scale_format, width, blur_size + nudge)
            if opts.mirror then
                -- Top edge: crop from top and flip vertically
                cropped_scaled_1 = cropped_1 .. "," .. scaled_1 .. ",vflip"
            else
                cropped_scaled_1 = cropped_1 .. "," .. scaled_1
            end

            local cropped_2 = string.format(crop_format, visible_width, visible_height, (width - visible_width)/2, height - visible_height)
            local scaled_2 = string.format(scale_format, width, blur_size)
            if opts.mirror then
                -- Bottom edge: crop from bottom and flip vertically
                cropped_scaled_2 = cropped_2 .. "," .. scaled_2 .. ",vflip"
            else
                cropped_scaled_2 = cropped_2 .. "," .. scaled_2
            end
        else
            -- No scaling - just crop the edges
            local cropped_1 = string.format(crop_format, width, blur_size + nudge, "0", "0")
            if opts.mirror then
                -- Top edge: crop from top of video and flip vertically
                local top_crop = string.format(crop_format, width, blur_size + nudge, "0", "0")
                cropped_scaled_1 = top_crop .. ",vflip"
            else
                cropped_scaled_1 = cropped_1
            end

            local cropped_2 = string.format(crop_format, width, blur_size, "0", height - blur_size)
            if opts.mirror then
                -- Bottom edge: crop from bottom of video and flip vertically  
                local bottom_crop = string.format(crop_format, width, blur_size, "0", height - blur_size)
                cropped_scaled_2 = bottom_crop .. ",vflip"
            else
                cropped_scaled_2 = cropped_2
            end
        end
        stack_direction = "v"
    end

    if blur_size < math.max(1, opts.minimum_black_bar_size) then 
        return 
    end
    local lr = math.min(opts.blur_radius, math.floor(blur_size/2)-1)
    local cr = math.min(opts.blur_radius, math.floor(blur_size/4)-1)
    local blur = string.format("boxblur=lr=%i:lp=%i:cr=%i:cp=%i",
        lr, opts.blur_power, cr, opts.blur_power)

    zone_1 = string.format("[a] %s,%s [a_fin]", cropped_scaled_1, blur)
    zone_2 = string.format("[b] %s,%s [b_fin]", cropped_scaled_2, blur)

    local par_fix = "setsar=ratio=" .. tostring(par) .. ":max=10000"

    stack = string.format("[a_fin] [v] [b_fin] %sstack=3,%s [vo]", stack_direction, par_fix)
    filter = string.format("%s;%s;%s;%s", split, zone_1, zone_2, stack)
    set_lavfi_complex(filter)
    applied = true
end

function unset_blur()
    set_lavfi_complex()
    applied = false
end

local reapplication_timer = mp.add_timeout(opts.reapply_delay, set_blur)
reapplication_timer:kill()

function reset_blur(k,v)
    unset_blur()
    reapplication_timer:kill()
    reapplication_timer:resume()
end

function toggle()
    if active then
        active = false
        unset_blur()
        mp.unobserve_property(reset_blur)
    else
        active = true
        set_blur()
        local properties = { "osd-width", "osd-height", "path", "fullscreen" }
        for _, p in ipairs(properties) do
            mp.observe_property(p, "native", reset_blur)
        end
    end
end

if active then
    active = false
    toggle()
end

mp.add_key_binding(nil, "toggle-blur", toggle)
mp.add_key_binding(nil, "set-blur", set_blur)
mp.add_key_binding(nil, "unset-blur", unset_blur)
