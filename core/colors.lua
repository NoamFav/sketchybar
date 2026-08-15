-- Try wallpaper-generated theme first, fall back to Tokyo Night
local ok, generated = pcall(require, "colors_generated")
if ok and generated then
	return generated
end

-- Tokyo Night fallback
return {
	-- Core
	black = 0xff1a1b26, -- TN night bg
	white = 0xffc0caf5, -- TN white (ui/variables)
	red = 0xfff7768e,
	green = 0xff9ece6a,
	blue = 0xff7aa2f7,
	yellow = 0xffe0af68,
	orange = 0xffff9e64,
	magenta = 0xffbb9af7,
	grey = 0xff565f89, -- comments/disabled
	transparent = 0x00000000,

	-- Bar / popups / backgrounds
	bar = {
		bg = 0x001a1b26,
		border = 0xff292e42,
	},
	popup = {
		bg = 0xc01f2335,
		border = 0xff565f89,
	},

	-- Extra background shades (useful for chips/brackets)
	bg1 = 0xff1f2335,
	bg2 = 0xff24283b,

	with_alpha = function(color, alpha)
		if alpha > 1.0 or alpha < 0.0 then
			return color
		end
		return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
	end,
}
