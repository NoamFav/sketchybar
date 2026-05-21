local settings = require("settings")
local colors = require("colors")

sbar.add("item", { position = "right", width = settings.group_paddings })

local cal = sbar.add("item", {
  icon = {
    color = colors.white,
    padding_left = 8,
    font = {
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
  },
  label = {
    color = colors.white,
    padding_right = 8,
    width = 49,
    align = "right",
    font = { family = settings.font.numbers },
  },
  position = "right",
  update_freq = 30,
  padding_left = 1,
  padding_right = 1,
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  },
  click_script = "open -a 'Calendar'"
})

sbar.add("item", { position = "right", width = settings.group_paddings })

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set({ icon = os.date("%a. %d %b."), label = os.date("%H:%M") })
end)
