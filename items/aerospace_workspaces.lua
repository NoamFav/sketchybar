-- ~/.config/sketchybar/items/aerospace_workspaces.lua
--
-- AeroSpace Workspace Integration for SketchyBar
-- Creates workspace indicators that show on their respective monitors,
-- display app icons for windows in each workspace, and handle click interactions

local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- Register the custom event that AeroSpace will emit
sbar.add("event", "aerospace_workspace_change")

local minimal = os.getenv("SKETCHYBAR_MINIMAL") == "1"

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Workspace layout configuration
-- Display mapping: 3 = left monitor, 1 = middle monitor, 2 = right monitor
-- Each workspace will only appear on its designated monitor's bar
local WORKSPACE_LAYOUT = minimal
		and {
			{ display = 1, workspaces = { "1", "2", "3", "4", "5", "6", "7", "8", "9" } },
		}
	or {
		{ display = 3, workspaces = { "1", "2", "3", "4", "5", "6", "7", "8", "9" } },
		{ display = 1, workspaces = { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" } },
		{ display = 2, workspaces = { "A", "S", "D", "F", "G", "Z", "X", "C", "V", "B" } },
	}

-- Visual styling constants
local STYLE = {
	chip_bg = colors.bg1, -- Background color for workspace chips
	chip_border = colors.black, -- Border color for workspace chips
	chip_height = 26, -- Height of workspace chips
	bracket_border = colors.bg2, -- Border color for workspace brackets
	active_icon_highlight = colors.red, -- Highlight color for active workspace icon
	active_label_highlight = colors.white, -- Highlight color for active workspace label
	inactive_icon_color = colors.white, -- Color for inactive workspace icons
	inactive_label_color = colors.grey, -- Color for inactive workspace labels
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

-- Storage for workspace items and their associated elements
local workspace_items = {} -- workspace -> { item, bracket, display }
local padding_items = {} -- workspace -> padding item name
local separator_items = {} -- display -> separator item name

-- Build workspace -> display mapping for fast lookups
-- This allows us to quickly determine which monitor a workspace belongs to
local workspace_to_display = {}
for _, group in ipairs(WORKSPACE_LAYOUT) do
	for _, ws in ipairs(group.workspaces) do
		workspace_to_display[ws] = group.display
	end
end

-- ============================================================================
-- ITEM CREATION FUNCTIONS
-- ============================================================================

-- Creates a workspace item (the clickable chip that shows the workspace)
local function create_workspace_item(ws)
	local display = workspace_to_display[ws] or "active"

	local item = sbar.add("item", "aws." .. ws, {
		position = "left",
		display = display, -- Pin this chip to its designated monitor
		icon = {
			font = { family = settings.font.numbers },
			string = ws, -- Display the workspace name/letter
			padding_left = 15,
			padding_right = 8,
			color = STYLE.inactive_icon_color,
			highlight_color = STYLE.active_icon_highlight,
		},
		label = {
			padding_right = 20,
			color = STYLE.inactive_label_color,
			highlight_color = STYLE.active_label_highlight,
			font = "sketchybar-app-font:Regular:16.0", -- Use app font for icons
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
		click_script = "aerospace workspace " .. ws, -- Left click switches to workspace
		drawing = "off", -- Initially hidden
	})

	-- Create a bracket around the workspace item for visual grouping
	local bracket = sbar.add("bracket", { item.name }, {
		display = display, -- Bracket appears on same monitor as the item
		background = {
			color = colors.transparent,
			border_color = STYLE.bracket_border,
			height = STYLE.chip_height + 2,
			border_width = 2,
		},
		drawing = "off", -- Initially hidden
	})

	-- Handle right-click to move focused window to this workspace
	item:subscribe("mouse.clicked", function(env)
		if env.BUTTON == "right" then
			sbar.exec("aerospace move-node-to-workspace " .. ws)
		end
	end)

	return item, bracket
end

-- Creates a padding item for spacing between workspace groups
local function create_padding_item(ws, display)
	return sbar.add("item", "aws.pad." .. ws, {
		position = "left",
		display = display,
		width = settings.group_paddings,
		drawing = "off", -- Initially hidden
	})
end

-- Ensures a workspace item exists, creating it if necessary
local function ensure_workspace_exists(ws)
	if workspace_items[ws] then
		return workspace_items[ws]
	end

	local display = workspace_to_display[ws] or "active"
	local item, bracket = create_workspace_item(ws)
	local pad = create_padding_item(ws, display)

	-- Store references to all created items
	workspace_items[ws] = { item = item, bracket = bracket, display = display }
	padding_items[ws] = pad.name

	return workspace_items[ws]
end

-- Creates separator items between monitor groups
local function create_separators()
	for _, group in ipairs(WORKSPACE_LAYOUT) do
		local display = group.display
		if not separator_items[display] then
			local sep = sbar.add("item", string.format("aws.sep.%d", display), {
				position = "left",
				display = display,
				width = settings.group_paddings * 2, -- Double width for visual separation
				drawing = "off", -- Initially hidden
			})
			separator_items[display] = sep.name
		end
	end
end

-- ============================================================================
-- VISIBILITY AND STYLING FUNCTIONS
-- ============================================================================

-- Shows or hides a workspace and its associated elements
local function set_workspace_visibility(ws, visible)
	local workspace = ensure_workspace_exists(ws)
	local drawing_state = visible and "on" or "off"

	-- Show/hide the main workspace item, bracket, and padding
	workspace.item:set({ drawing = drawing_state })
	workspace.bracket:set({ drawing = drawing_state })
	sbar.set(padding_items[ws], { drawing = drawing_state })
end

-- Updates the visual appearance of a workspace based on its state and contents
local function update_workspace_appearance(ws, focused_workspace)
	local workspace = workspace_items[ws]
	if not workspace then
		return
	end

	local is_focused = (ws == focused_workspace)

	-- Get list of applications running in this workspace
	sbar.exec(string.format('aerospace list-windows --workspace %s --format "%%{app-name}"', ws), function(output)
		local seen_apps = {}
		local app_icons_string = ""

		-- Parse application names and build icon string
		for app_name in string.gmatch(output or "", "[^\r\n]+") do
			app_name = app_name:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace

			-- Only add unique apps to avoid duplicate icons
			if app_name ~= "" and not seen_apps[app_name] then
				seen_apps[app_name] = true
				local icon = app_icons[app_name] or app_icons["Default"] or "·"
				app_icons_string = app_icons_string .. icon
			end
		end

		-- Show placeholder when workspace is empty
		if app_icons_string == "" then
			app_icons_string = " —"
		end

		-- Update workspace visual state with proper highlighting
		workspace.item:set({
			icon = { highlight = is_focused },
			label = { string = app_icons_string, highlight = is_focused },
			background = {
				border_color = is_focused and STYLE.chip_border or STYLE.bracket_border,
			},
		})

		-- Update bracket styling with focus indication
		workspace.bracket:set({
			background = {
				border_color = is_focused and colors.grey or STYLE.bracket_border,
			},
		})
	end)
end

-- ============================================================================
-- SEPARATOR MANAGEMENT
-- ============================================================================

-- Updates visibility of separators between workspace groups
local function update_separators()
	-- Check each pair of adjacent monitor groups
	for i = 1, (#WORKSPACE_LAYOUT - 1) do
		local left_workspaces = WORKSPACE_LAYOUT[i].workspaces
		local right_workspaces = WORKSPACE_LAYOUT[i + 1].workspaces

		local left_has_visible = false
		local right_has_visible = false

		-- Check if left group has any visible workspaces
		for _, ws in ipairs(left_workspaces) do
			if workspace_items[ws] and workspace_items[ws].item:query().geometry.drawing == "on" then
				left_has_visible = true
				break
			end
		end

		-- Check if right group has any visible workspaces
		for _, ws in ipairs(right_workspaces) do
			if workspace_items[ws] and workspace_items[ws].item:query().geometry.drawing == "on" then
				right_has_visible = true
				break
			end
		end

		-- Show separator only if both adjacent groups have visible workspaces
		local sep_name = separator_items[i]
		if sep_name then
			sbar.set(sep_name, {
				drawing = (left_has_visible and right_has_visible) and "on" or "off",
			})
		end
	end
end

-- ============================================================================
-- MAIN UPDATE LOGIC
-- ============================================================================

-- Main function that updates all workspace visibility and styling
local function update_all_workspaces()
	-- Get the currently focused workspace from AeroSpace
	sbar.exec("aerospace list-workspaces --focused", function(focused_output)
		local focused_workspace = (focused_output or ""):gsub("%s+", "")

		-- Track async operations to know when all updates are complete
		local pending_groups = #WORKSPACE_LAYOUT

		-- Function called when all workspace updates are complete
		local function finalize_update()
			update_separators()
		end

		-- Process each monitor group
		for _, group in ipairs(WORKSPACE_LAYOUT) do
			local workspaces_list = group.workspaces
			local pending_workspaces = #workspaces_list

			-- Handle empty groups
			if pending_workspaces == 0 then
				pending_groups = pending_groups - 1
				if pending_groups == 0 then
					finalize_update()
				end
			else
				-- Process each workspace in the group
				for _, ws in ipairs(workspaces_list) do
					ensure_workspace_exists(ws)

					-- Check if workspace has any windows
					sbar.exec("aerospace list-windows --workspace " .. ws, function(windows_output)
						local has_windows = (windows_output and windows_output:match("%S")) ~= nil
						local should_show = (ws == focused_workspace) or has_windows

						-- Update workspace visibility
						set_workspace_visibility(ws, should_show)

						-- Update workspace appearance if it's visible
						if should_show then
							update_workspace_appearance(ws, focused_workspace)
						end

						-- Track completion of async operations
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

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Create all workspace items upfront
for _, group in ipairs(WORKSPACE_LAYOUT) do
	for _, ws in ipairs(group.workspaces) do
		ensure_workspace_exists(ws)
	end
end

-- Create separator items
create_separators()

-- Set up event observer for AeroSpace workspace changes
sbar.add("item", "aws.observer", { drawing = "off", updates = true })
	:subscribe("aerospace_workspace_change", function(_)
		update_all_workspaces()
	end)

-- Set up periodic refresh to catch window open/close events
-- that don't trigger workspace changes
local function periodic_refresh()
	update_all_workspaces()
	sbar.delay(5, periodic_refresh) -- Refresh every 5 seconds
end

-- Perform initial update and start periodic refresh
update_all_workspaces()
periodic_refresh()
