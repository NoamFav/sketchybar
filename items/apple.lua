local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

sbar.add("item", { width = settings.paddings })

local apple = sbar.add("item", {
  icon = {
    font = { size = 15.0 },
    string = icons.apple,
    padding_right = 8,
    padding_left = 8,
  },
  label = { drawing = false },
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  },
  padding_left = 1,
  padding_right = 1,
  click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0"
})

sbar.add("item", { width = settings.paddings })
