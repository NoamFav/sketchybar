-- Git Streak Toolkit - Fixed with proper popup pattern
local colors = require("colors")
local settings = require("settings")

local TOOL_PREFIX = "widgets.git"
local SCAN_SCRIPT = os.getenv("HOME") .. "/.config/sketchybar/helpers/git_toolkit/git_scan.sh"
local MAX_GRAPH = tonumber(os.getenv("GIT_WIDGET_GRAPH_LINES") or "6")

-- DEBUG: Add logging function
local function log(msg)
	local logfile = os.getenv("HOME") .. "/.config/sketchybar/git_debug.log"
	local f = io.open(logfile, "a")
	if f then
		f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
		f:close()
	end
	print("[GIT DEBUG] " .. tostring(msg))
end

-- DEBUG: Check if script exists
local function file_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

log("=== Git Widget Starting ===")
log("Script path: " .. SCAN_SCRIPT)
log("Script exists: " .. tostring(file_exists(SCAN_SCRIPT)))

-- CHIP (main widget)
local chip = sbar.add("item", TOOL_PREFIX .. ".chip", {
	position = "right",
	icon = { string = "󰊤 ", font = { size = 14 } },
	label = { string = "Git", font = { style = settings.font.style_map["Bold"], size = 12 } },
	padding_left = 6,
	padding_right = 6,
	update_freq = 180,
})

-- BRACKET with popup - Fix: Set popup properties directly on bracket creation
local bracket = sbar.add("bracket", TOOL_PREFIX .. ".bracket", { chip.name }, {
	background = { color = colors.bg1 },
	popup = {
		align = "center",
		drawing = "off", -- Explicitly set initial state
		horizontal = false,
	},
})

log("Chip and bracket created")

-- STATE
local state = {
	rows = {},
	rows_index = {},
	repo_items = {},
	scan_in_flight = false,
}

-- UTILS
local function split_lines(s)
	local t = {}
	for line in string.gmatch(s or "", "[^\r\n]+") do
		t[#t + 1] = line
	end
	return t
end

local function escape_for_bash_double(s)
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

-- Open in iTerm
local function open_in_terminal(path)
	log("Opening terminal for path: " .. (path or "nil"))
	local osa = ([[tell application "iTerm"
  activate
  if (count of windows) = 0 then create window with default profile
  tell current window
    create tab with default profile
    tell current session to write text "cd %s && clear"
  end tell
end tell]]):format(escape_for_bash_double(path))

	local cmd = '/usr/bin/osascript -e "' .. escape_for_bash_double(osa) .. '"'
	log("Executing AppleScript command")
	sbar.exec(cmd, function(out, exit_code)
		log("AppleScript result - exit_code: " .. tostring(exit_code))
	end)
end

-- DETAIL POPUP
local function build_detail_popup(key, rec)
	log("Building detail popup for: " .. key)
	local detail_name = ("%s.detail.%s"):format(TOOL_PREFIX, key)
	sbar.remove(detail_name)

	local detail = sbar.add("item", detail_name, {
		position = "popup." .. bracket.name, -- Use bracket.name consistently
		icon = { drawing = false },
		label = { string = "Loading…", align = "left", font = "SF Mono:Regular:11.0", max_chars = 999 },
		width = 500,
	})
	track(detail_name)

	-- Simplified command for debugging
	local cmd = ([=[cd "%s" 2>/dev/null && echo "Path: %s" && echo "Branch: %s" && git status --short]=]):format(
		escape_for_bash_double(rec.path or ""),
		escape_for_bash_double(rec.path or ""),
		escape_for_bash_double(rec.branch or "")
	)

	log("Detail command: " .. cmd)
	sbar.exec(cmd, function(out, exit_code)
		log("Detail result - exit_code: " .. tostring(exit_code))
		detail:set({ label = { string = out or "(no details)" } })
	end)
end

-- Helper: add a popup row
local function add_repo_row(key, rec)
	local row_name = ("%s.row.%s"):format(TOOL_PREFIX, key)
	if state.rows_index[row_name] then
		return state.repo_items[key].row
	end

	log("Creating row for: " .. key)

	local row = sbar.add("item", row_name, {
		position = "popup." .. bracket.name,
		icon = { string = rec.branch, align = "left", width = 140, color = colors.white },
		label = { string = "—", align = "right", width = 320, font = { style = settings.font.style_map["Regular"] } },
		width = 460,
		padding_left = 6,
		padding_right = 6,
		background = { color = colors.bg1 },
	})
	track(row_name)

	row:subscribe("mouse.clicked", function(env)
		log("Row clicked - Button: " .. tostring(env.BUTTON) .. ", Key: " .. key)
		if env.BUTTON == "right" then
			local dn = row_name .. ".detail"
			local q = sbar.query(dn)
			if q and q.drawing == "on" then
				sbar.set(dn, { drawing = "off" })
			else
				sbar.remove(dn)
				build_detail_popup(key, rec)
			end
		else
			open_in_terminal(rec.path)
		end
	end)

	state.repo_items[key] = { row = row }
	return row
end

local function update_repo_row(rec)
	local key = rec.name
	local row = state.repo_items[key] and state.repo_items[key].row
	if not row then
		return
	end

	local dirty = rec.dirty == "1"
	local ahead = tonumber(rec.ahead or "0") or 0
	local behind = tonumber(rec.behind or "0") or 0

	local bits = {}
	if dirty then
		table.insert(bits, "● dirty")
	end
	if ahead > 0 then
		table.insert(bits, "↑" .. ahead)
	end
	if behind > 0 then
		table.insert(bits, "↓" .. behind)
	end
	table.insert(bits, rec.last)
	local status = table.concat(bits, "  ·  ")

	row:set({
		icon = { string = rec.branch, color = dirty and colors.orange or colors.white },
		label = {
			string = rec.name .. "  —  " .. status,
			color = (ahead > 0 or behind > 0) and colors.yellow or (dirty and colors.orange or colors.grey),
		},
	})
end

-- SCAN FUNCTIONS
local function parse(line)
	local n, p, b, d, a, be, la, sl = line:match("^(.-)|(.-)|(.-)|(.-)|(.-)|(.-)|(.-)|(.-)$")
	if not n or n == "" then
		return nil
	end
	return { name = n, path = p, branch = b, dirty = d, ahead = a, behind = be, last = la, slug = sl }
end

local function refresh_popup()
	if state.scan_in_flight then
		log("Scan already in flight, skipping")
		return
	end

	log("Starting popup refresh...")
	state.scan_in_flight = true

	-- Test if script is executable first
	if not file_exists(SCAN_SCRIPT) then
		log("ERROR: Scan script does not exist!")
		chip:set({ label = { string = "No Script" }, icon = { color = colors.red } })
		state.scan_in_flight = false
		return
	end

	local cmd = "/bin/bash -lc 'export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin; \""
		.. escape_for_bash_double(SCAN_SCRIPT)
		.. "\"'"

	log("Executing command: " .. cmd)

	sbar.exec(cmd, function(out, exit_code)
		log("Scan completed - exit_code: " .. tostring(exit_code))
		log("Scan output length: " .. tostring(out and #out or 0))

		state.scan_in_flight = false
		clear_rows()

		if not out or out == "" then
			log("No output from scan script")
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

		local records = {}
		for _, line in ipairs(split_lines(out)) do
			local r = parse(line)
			if r then
				table.insert(records, r)
				log("Parsed repo: " .. r.name)
			end
		end

		log("Total parsed records: " .. #records)

		-- Create rows for each repo
		for _, r in ipairs(records) do
			add_repo_row(r.name, r)
			update_repo_row(r)
		end

		-- Add separator at bottom
		local pad = TOOL_PREFIX .. ".pad"
		sbar.add("item", pad, {
			position = "popup." .. bracket.name,
			width = 1,
			background = { color = colors.transparent, height = 6 },
		})
		track(pad)
	end)
end

local function refresh_chip()
	if state.scan_in_flight then
		log("Scan already in flight, skipping chip refresh")
		return
	end

	log("Starting chip refresh...")
	state.scan_in_flight = true

	local cmd = "/bin/bash -lc 'export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin; \""
		.. escape_for_bash_double(SCAN_SCRIPT)
		.. "\"'"

	sbar.exec(cmd, function(out, exit_code)
		log("Chip scan completed - exit_code: " .. tostring(exit_code))
		state.scan_in_flight = false

		if not out or out == "" then
			chip:set({ label = { string = "git" }, icon = { color = colors.white } })
			return
		end

		local cnt = 0
		local dirty_cnt = 0
		for _, line in ipairs(split_lines(out)) do
			local r = parse(line)
			if r then
				cnt = cnt + 1
				if r.dirty == "1" or (tonumber(r.ahead or "0") or 0) > 0 or (tonumber(r.behind or "0") or 0) > 0 then
					dirty_cnt = dirty_cnt + 1
				end
			end
		end

		log("Found " .. cnt .. " repos, " .. dirty_cnt .. " dirty/diverged")

		chip:set({
			label = { string = (cnt > 0 and (cnt .. " repos") or "git") },
			icon = { color = (dirty_cnt > 0) and colors.yellow or colors.white },
		})
	end)
end

-- === Click behavior - FIXED ===
chip:subscribe("mouse.clicked", function(env)
	log("Chip clicked - Button: " .. tostring(env.BUTTON))
	if env.BUTTON == "right" then
		log("Right click - could add special action here")
	else
		log("Left click - toggling popup")

		-- First check current state
		local query_result = sbar.query(bracket.name)
		log("Pre-toggle query result: " .. (query_result and "exists" or "nil"))

		if query_result and query_result.popup then
			log("Current popup drawing state: " .. tostring(query_result.popup.drawing))

			-- Toggle popup state
			if query_result.popup.drawing == "on" then
				log("Closing popup")
				sbar.set(bracket.name, { popup = { drawing = "off" } })
				clear_rows()
			else
				log("Opening popup")
				sbar.set(bracket.name, { popup = { drawing = "on" } })
				-- Small delay to ensure popup is open before populating
				sbar.delay(0.1, function()
					refresh_popup()
				end)
			end
		else
			log("No popup found in query result - attempting to open")
			sbar.set(bracket.name, { popup = { drawing = "on" } })
			sbar.delay(0.1, function()
				refresh_popup()
			end)
		end
	end
end)

-- PERIODIC (only update chip when popup closed)
chip:subscribe({ "routine", "system_woke" }, function()
	log("Periodic update triggered")
	refresh_chip()
end)

-- spacing after widget
sbar.add("item", { position = "right", width = settings.group_paddings })

log("=== Git Widget Setup Complete ===")

-- Initial refresh
refresh_chip()
