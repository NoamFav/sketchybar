local colors = require("colors")
local settings = require("settings")

local TOOL_PREFIX = "widgets.git"
local SCAN_SCRIPT = os.getenv("HOME") .. "/.config/sketchybar/helpers/git_toolkit/iskra_scan.sh"
local SCAN_CMD = '/bin/bash -l "' .. SCAN_SCRIPT .. '"'

-- CHIP
local chip = sbar.add("item", TOOL_PREFIX .. ".chip", {
	position = "right",
	icon = { string = "󰊤 ", font = { size = 14 } },
	label = { string = "git", font = { style = settings.font.style_map["Bold"], size = 12 } },
	padding_left = 6,
	padding_right = 6,
	update_freq = 180,
})

-- BRACKET with popup
local bracket = sbar.add("bracket", TOOL_PREFIX .. ".bracket", { chip.name }, {
	background = { color = colors.bg1 },
	popup = {
		align = "center",
		drawing = "off",
		horizontal = false,
	},
})

-- STATE
local state = {
	rows = {},
	rows_index = {},
	repo_items = {},
	scan_in_flight = false,
	records = nil, -- cached last scan results
}

-- UTILS
local function split_lines(s)
	local t = {}
	for line in string.gmatch(s or "", "[^\r\n]+") do
		t[#t + 1] = line
	end
	return t
end

local function escape_quotes(s)
	return (s or ""):gsub('"', '\\"')
end

local function track(name)
	if not state.rows_index[name] then
		state.rows_index[name] = true
		table.insert(state.rows, name)
	end
end

local function clear_rows()
	for _, name in ipairs(state.rows) do
		sbar.remove(name)
	end
	state.rows, state.rows_index, state.repo_items = {}, {}, {}
end

-- Parse pipe-delimited line: name|path|branch|staged|uncommitted|untracked|ahead|behind|slug
local function parse(line)
	local n, p, b, st, uc, ut, a, be, sl = line:match("^(.-)|(.-)|(.-)|(.-)|(.-)|(.-)|(.-)|(.-)|(.-)")
	if not n or n == "" then return nil end
	return {
		name = n, path = p, branch = b,
		staged = tonumber(st) or 0,
		uncommitted = tonumber(uc) or 0,
		untracked = tonumber(ut) or 0,
		ahead = tonumber(a) or 0,
		behind = tonumber(be) or 0,
		slug = sl,
	}
end

local function status_string(r)
	local bits = {}
	if r.ahead > 0   then bits[#bits+1] = "↑" .. r.ahead end
	if r.behind > 0  then bits[#bits+1] = "↓" .. r.behind end
	if r.staged > 0  then bits[#bits+1] = "+" .. r.staged end
	if r.uncommitted > 0 then bits[#bits+1] = "~" .. r.uncommitted end
	if r.untracked > 0   then bits[#bits+1] = "?" .. r.untracked end
	if #bits == 0 then return "clean" end
	return table.concat(bits, "  ")
end

local function is_dirty(r)
	return r.staged > 0 or r.uncommitted > 0 or r.untracked > 0 or r.ahead > 0 or r.behind > 0
end

-- Open repo in iTerm
local function open_in_terminal(path)
	local osa = ([[tell application "iTerm"
  activate
  if (count of windows) = 0 then create window with default profile
  tell current window
    create tab with default profile
    tell current session to write text "cd %s && clear"
  end tell
end tell]]):format(escape_quotes(path))
	sbar.exec('/usr/bin/osascript -e "' .. escape_quotes(osa) .. '"')
end

-- POPUP ROW
local function add_repo_row(r)
	local key = r.name
	local row_name = ("%s.row.%s"):format(TOOL_PREFIX, key)
	if state.rows_index[row_name] then
		return state.repo_items[key]
	end

	local dirty = is_dirty(r)
	local row = sbar.add("item", row_name, {
		position = "popup." .. bracket.name,
		icon = {
			string = r.branch,
			align = "left",
			width = 120,
			color = dirty and colors.orange or colors.grey,
			font = { family = settings.font.numbers, style = settings.font.style_map["Regular"], size = 11 },
		},
		label = {
			string = r.name .. "   " .. status_string(r),
			align = "left",
			width = 340,
			color = (r.ahead > 0 or r.behind > 0) and colors.yellow
				or dirty and colors.orange
				or colors.grey,
			font = { style = settings.font.style_map["Regular"], size = 12 },
		},
		width = 460,
		padding_left = 8,
		padding_right = 8,
		background = { color = colors.bg1 },
	})
	track(row_name)

	row:subscribe("mouse.clicked", function(env)
		if env.BUTTON == "left" then
			open_in_terminal(r.path)
		end
	end)

	state.repo_items[key] = row
	return row
end

-- SCAN
local function do_scan(on_done)
	if state.scan_in_flight then return end
	state.scan_in_flight = true

	sbar.exec(SCAN_CMD, function(out, exit_code)
		state.scan_in_flight = false

		local records = {}
		if out and out ~= "" and exit_code == 0 then
			for _, line in ipairs(split_lines(out)) do
				local r = parse(line)
				if r then records[#records+1] = r end
			end
		end
		state.records = records
		on_done(records)
	end)
end

-- UPDATE CHIP
local function refresh_chip()
	do_scan(function(records)
		local total = #records
		local dirty_cnt = 0
		for _, r in ipairs(records) do
			if is_dirty(r) then dirty_cnt = dirty_cnt + 1 end
		end

		chip:set({
			label = {
				string = dirty_cnt > 0 and (dirty_cnt .. "/" .. total) or (total .. " repos"),
			},
			icon = { color = dirty_cnt > 0 and colors.yellow or colors.white },
		})
	end)
end

-- BUILD POPUP
local function refresh_popup()
	do_scan(function(records)
		clear_rows()

		if #records == 0 then
			local empty = TOOL_PREFIX .. ".row.empty"
			sbar.add("item", empty, {
				position = "popup." .. bracket.name,
				icon = { drawing = false },
				label = { string = "No repos found", align = "center" },
				width = 460,
			})
			track(empty)
			return
		end

		-- Sort: dirty repos first
		table.sort(records, function(a, b)
			return (is_dirty(a) and 1 or 0) > (is_dirty(b) and 1 or 0)
		end)

		for _, r in ipairs(records) do
			add_repo_row(r)
		end

		local pad = TOOL_PREFIX .. ".pad"
		sbar.add("item", pad, {
			position = "popup." .. bracket.name,
			width = 1,
			background = { color = colors.transparent, height = 6 },
		})
		track(pad)
	end)
end

-- CLICK
chip:subscribe("mouse.clicked", function(env)
	if env.BUTTON ~= "left" then return end

	local q = sbar.query(bracket.name)
	if q and q.popup and q.popup.drawing == "on" then
		sbar.set(bracket.name, { popup = { drawing = "off" } })
		clear_rows()
	else
		sbar.set(bracket.name, { popup = { drawing = "on" } })
		sbar.delay(0.1, refresh_popup)
	end
end)

-- PERIODIC
chip:subscribe({ "routine", "system_woke" }, refresh_chip)

-- Spacing
sbar.add("item", { position = "right", width = settings.group_paddings })

-- Initial
refresh_chip()
