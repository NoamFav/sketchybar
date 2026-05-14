local colors = require("colors")

sbar.bar({
  height = 40,
  color = colors.bar.bg,
  padding_right = 2,
  padding_left = 2,
})

-- Per-display bar tint from wallpaper theme (no-op when colors_generated.lua absent)
if colors.display then
  for i = 1, 3 do
    local dc = colors.display[i]
    if dc and dc.bar_bg then
      sbar.bar({ display = i, color = dc.bar_bg })
    end
  end
end
