local colors = require("core.colors")
local settings = require("core.settings")
local app_icons = require("helpers.app_icons")

-- AeroSpace emits this on workspace changes; we subscribe to it below
sbar.add("event", "aerospace_workspace_change")

local minimal = os.getenv("SKETCHYBAR_MINIMAL") == "1"

-- ── Configuration ────────────────────────────────────────────────────────────

-- Display mapping: 3 = left monitor, 1 = middle monitor, 2 = right monitor,
-- each workspace only shows on its designated monitor's bar
local WORKSPACE_LAYOUT = minimal
		and {
			{ display = 1, workspaces = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" } },
		}
	or {
		{ display = 2, workspaces = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" } },
		{ display = 1, workspaces = { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" } },
		{ display = 3, workspaces = { "A", "S", "D", "F", "G", "Z", "X", "C", "V", "B" } },
	}

-- per-display styling, uses wallpaper-derived accent/bg if colors_generated.lua exists
local function make_style(display_num)
	local dc = colors.display and colors.display[display_num]
	return {
		chip_bg = (dc and dc.bg1) or colors.bg1,
		chip_border = colors.black,
		chip_height = 26,
		bracket_border = (dc and dc.bg2) or colors.bg2,
		active_icon_highlight = (dc and dc.accent) or colors.blue,
		active_label_highlight = colors.white,
		inactive_icon_color = colors.white,
		inactive_label_color = colors.grey,
	}
end

local DISPLAY_STYLES = {}
for _, group in ipairs(WORKSPACE_LAYOUT) do
	if not DISPLAY_STYLES[group.display] then
		DISPLAY_STYLES[group.display] = make_style(group.display)
	end
end
local STYLE = DISPLAY_STYLES[1] or make_style(1)

-- ── State ────────────────────────────────────────────────────────────────────

local workspace_items = {} -- workspace -> { item, bracket, display }
local padding_items = {} -- workspace -> padding item name
local separator_items = {} -- display -> separator item name

-- workspace -> display, built once so lookups don't walk WORKSPACE_LAYOUT every time
local workspace_to_display = {}
for _, group in ipairs(WORKSPACE_LAYOUT) do
	for _, ws in ipairs(group.workspaces) do
		workspace_to_display[ws] = group.display
	end
end

-- ── Item creation ────────────────────────────────────────────────────────────

local function create_workspace_item(ws, style)
	style = style or STYLE
	local display = workspace_to_display[ws] or "active"

	local item = sbar.add("item", "aws." .. ws, {
		position = "left",
		display = display,
		icon = {
			font = { family = settings.font.numbers },
			string = ws,
			padding_left = 15,
			padding_right = 8,
			color = STYLE.inactive_icon_color,
			highlight_color = STYLE.active_icon_highlight,
		},
		label = {
			padding_right = 20,
			color = STYLE.inactive_label_color,
			highlight_color = STYLE.active_label_highlight,
			font = "sketchybar-app-font:Regular:16.0",
			y_offset = -1,
		},
		padding_right = 1,
		padding_left = 1,
		background = {
			color = STYLE.chip_bg,
			border_width = 1,
			height = STYLE.chip_height,
			border_color = STYLE.chip_border,
		},
		click_script = "aerospace workspace " .. ws,
		drawing = "off",
	})

	-- kept for drawing/visibility management; stays transparent, the chip carries the look
	local bracket = sbar.add("bracket", { item.name }, {
		display = display,
		background = {
			color = colors.transparent,
			border_color = colors.transparent,
			height = STYLE.chip_height + 2,
			border_width = 0,
		},
		drawing = "off",
	})

	item:subscribe("mouse.clicked", function(env)
		if env.BUTTON == "right" then
			sbar.exec("aerospace move-node-to-workspace " .. ws)
		end
	end)

	return item, bracket
end

local function create_padding_item(ws, display)
	return sbar.add("item", "aws.pad." .. ws, {
		position = "left",
		display = display,
		width = settings.group_paddings,
		drawing = "off",
	})
end

local function ensure_workspace_exists(ws)
	if workspace_items[ws] then
		return workspace_items[ws]
	end

	local display = workspace_to_display[ws] or "active"
	local style = DISPLAY_STYLES[display] or STYLE
	local item, bracket = create_workspace_item(ws, style)
	local pad = create_padding_item(ws, display)

	workspace_items[ws] = { item = item, bracket = bracket, display = display, style = style }
	padding_items[ws] = pad.name

	return workspace_items[ws]
end

local function create_separators()
	for _, group in ipairs(WORKSPACE_LAYOUT) do
		local display = group.display
		if not separator_items[display] then
			local sep = sbar.add("item", string.format("aws.sep.%d", display), {
				position = "left",
				display = display,
				width = settings.group_paddings * 2,
				drawing = "off",
			})
			separator_items[display] = sep.name
		end
	end
end

-- ── Visibility and styling ───────────────────────────────────────────────────

local function set_workspace_visibility(ws, visible)
	local workspace = ensure_workspace_exists(ws)
	local drawing_state = visible and "on" or "off"

	workspace.item:set({ drawing = drawing_state })
	workspace.bracket:set({ drawing = drawing_state })
	sbar.set(padding_items[ws], { drawing = drawing_state })
end

local function update_workspace_appearance(ws, focused_workspace)
	local workspace = workspace_items[ws]
	if not workspace then
		return
	end

	local is_focused = (ws == focused_workspace)
	local style = workspace.style or STYLE

	sbar.exec(string.format('aerospace list-windows --workspace %s --format "%%{app-name}"', ws), function(output)
		local seen_apps = {}
		local app_icons_string = ""

		for app_name in string.gmatch(output or "", "[^\r\n]+") do
			app_name = app_name:gsub("^%s+", ""):gsub("%s+$", "")

			-- skip dupes so a workspace with 5 terminal windows doesn't show 5 terminal icons
			if app_name ~= "" and not seen_apps[app_name] then
				seen_apps[app_name] = true
				local icon = app_icons[app_name] or app_icons["Default"] or "·"
				app_icons_string = app_icons_string .. icon
			end
		end

		if app_icons_string == "" then
			app_icons_string = " —"
		end

		workspace.item:set({
			icon = { highlight = is_focused },
			label = { string = app_icons_string, highlight = is_focused },
			background = {
				color = is_focused and colors.with_alpha(style.active_icon_highlight, 0.18) or style.chip_bg,
				border_color = is_focused and style.active_icon_highlight or style.bracket_border,
			},
		})

		-- bracket stays invisible, chip carries all the visual weight
		workspace.bracket:set({
			background = { border_color = colors.transparent },
		})
	end)
end

-- ── Separators ───────────────────────────────────────────────────────────────

local function update_separators()
	for i = 1, (#WORKSPACE_LAYOUT - 1) do
		local left_workspaces = WORKSPACE_LAYOUT[i].workspaces
		local right_workspaces = WORKSPACE_LAYOUT[i + 1].workspaces

		local left_has_visible = false
		local right_has_visible = false

		for _, ws in ipairs(left_workspaces) do
			if workspace_items[ws] and workspace_items[ws].item:query().geometry.drawing == "on" then
				left_has_visible = true
				break
			end
		end

		for _, ws in ipairs(right_workspaces) do
			if workspace_items[ws] and workspace_items[ws].item:query().geometry.drawing == "on" then
				right_has_visible = true
				break
			end
		end

		-- only show the separator when both neighboring groups actually have something to separate
		local sep_name = separator_items[i]
		if sep_name then
			sbar.set(sep_name, {
				drawing = (left_has_visible and right_has_visible) and "on" or "off",
			})
		end
	end
end

-- ── Main update loop ─────────────────────────────────────────────────────────

local function update_all_workspaces()
	sbar.exec("aerospace list-workspaces --focused", function(focused_output)
		local focused_workspace = (focused_output or ""):gsub("%s+", "")

		-- tracks pending async sbar.exec calls so update_separators only runs once everything settles
		local pending_groups = #WORKSPACE_LAYOUT

		local function finalize_update()
			update_separators()
		end

		for _, group in ipairs(WORKSPACE_LAYOUT) do
			local workspaces_list = group.workspaces
			local pending_workspaces = #workspaces_list

			if pending_workspaces == 0 then
				pending_groups = pending_groups - 1
				if pending_groups == 0 then
					finalize_update()
				end
			else
				for _, ws in ipairs(workspaces_list) do
					ensure_workspace_exists(ws)

					sbar.exec("aerospace list-windows --workspace " .. ws, function(windows_output)
						local has_windows = (windows_output and windows_output:match("%S")) ~= nil
						local should_show = (ws == focused_workspace) or has_windows

						set_workspace_visibility(ws, should_show)

						if should_show then
							update_workspace_appearance(ws, focused_workspace)
						end

						pending_workspaces = pending_workspaces - 1
						if pending_workspaces == 0 then
							pending_groups = pending_groups - 1
							if pending_groups == 0 then
								finalize_update()
							end
						end
					end)
				end
			end
		end
	end)
end

-- ── Init ─────────────────────────────────────────────────────────────────────

for _, group in ipairs(WORKSPACE_LAYOUT) do
	for _, ws in ipairs(group.workspaces) do
		ensure_workspace_exists(ws)
	end
end

create_separators()

sbar.add("item", "aws.observer", { drawing = "off", updates = true })
	:subscribe("aerospace_workspace_change", function(_)
		update_all_workspaces()
	end)

-- AeroSpace doesn't emit an event for windows opening/closing within a workspace,
-- so poll every 5s to catch those too
local function periodic_refresh()
	update_all_workspaces()
	sbar.delay(5, periodic_refresh)
end

update_all_workspaces()
periodic_refresh()
