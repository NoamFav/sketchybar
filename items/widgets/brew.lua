local colors = require("core.colors")
local settings = require("core.settings")

local TOOL_PREFIX = "widgets.brew"
local SCAN_SCRIPT = os.getenv("HOME") .. "/.config/sketchybar/helpers/brew_toolkit/brew_scan.sh"
local SCAN_CMD = '/bin/bash -l "' .. SCAN_SCRIPT .. '"'

-- Default bar font (SF Pro) has no glyphs for these Nerd Font PUA codepoints;
-- macOS doesn't fall back to an installed Nerd Font for them automatically,
-- so the family has to be set explicitly.
local NERD_FONT = "VictorMono NFM"
local ICON_BEER = " "
local ICON_BOX = " "
local ICON_UPGRADE = " "
local ICON_CLEANUP = " "
local ICON_DOCTOR = " "

local PAGE_SIZE = 10

-- Chip
local chip = sbar.add("item", TOOL_PREFIX .. ".chip", {
	position = "right",
	icon = { string = ICON_BEER, font = { family = NERD_FONT, size = 16 } },
	label = { string = "…", font = { style = settings.font.style_map["Bold"], size = 12 } },
	padding_left = 6,
	padding_right = 6,
	update_freq = 10800, -- 3h; brew outdated is relatively expensive, no need for tighter polling
})

-- Bracket, with popup
local bracket = sbar.add("bracket", TOOL_PREFIX .. ".bracket", { chip.name }, {
	background = { color = colors.bg1 },
	popup = {
		align = "center",
		drawing = "off",
		horizontal = false,
	},
})

-- State
local state = {
	rows = {}, -- header / action buttons / separator / entries (torn down on every full refresh)
	rows_index = {},
	scan_in_flight = false,
}

-- Utils
local function split_lines(s)
	local t = {}
	for line in string.gmatch(s or "", "[^\r\n]+") do
		t[#t + 1] = line
	end
	return t
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
	state.rows, state.rows_index = {}, {}
end

-- Parse a single scan line into a record
local function parse(line)
	if line:sub(1, 8) == "SUMMARY|" then
		local fc, cc, ver, fi, ci = line:match("^SUMMARY|(%-?%d+)|(%-?%d+)|(.-)|(%-?%d+)|(%-?%d+)$")
		return {
			kind = "summary",
			formula_count = tonumber(fc) or 0,
			cask_count = tonumber(cc) or 0,
			version = ver or "?",
			formula_installed = tonumber(fi) or 0,
			cask_installed = tonumber(ci) or 0,
		}
	end
	local kind, name, installed, current = line:match("^(%a+)%|(.-)%|(.-)%|(.-)$")
	if not kind then
		return nil
	end
	return { kind = kind, name = name, installed = installed, current = current }
end

-- Run a brew command in a new Ghostty window; it closes itself on exit
-- (wait-after-command defaults to false, so no extra teardown needed).
-- Ghostty's -e wants the command and args as separate argv entries, so
-- this must NOT be quoted as a single string.
local function run_in_terminal(cmd)
	sbar.exec("open -na /Applications/Ghostty.app --args -e " .. cmd)
end

-- Scan
local function do_scan(on_done)
	if state.scan_in_flight then
		return
	end
	state.scan_in_flight = true

	sbar.exec(SCAN_CMD, function(out, exit_code)
		state.scan_in_flight = false

		local summary = nil
		local entries = {}
		if out and out ~= "" and exit_code == 0 then
			for _, line in ipairs(split_lines(out)) do
				local r = parse(line)
				if r and r.kind == "summary" then
					summary = r
				elseif r then
					entries[#entries + 1] = r
				end
			end
		end
		on_done(summary, entries)
	end)
end

-- Update chip
local function refresh_chip()
	do_scan(function(summary)
		if not summary then
			chip:set({ label = { string = "?" } })
			return
		end
		local outdated = summary.formula_count + summary.cask_count
		local installed = summary.formula_installed + summary.cask_installed
		chip:set({
			label = { string = outdated .. "/" .. installed },
			icon = { color = outdated > 0 and colors.yellow or colors.white },
		})
	end)
end

-- Render the first PAGE_SIZE entries; if there are more, a trailing row opens
-- the full `brew outdated` listing in a terminal instead of trying to scroll
-- (sketchybar popup items don't scroll reliably).
local function render_entries(entries)
	if #entries == 0 then
		local clean = TOOL_PREFIX .. ".row.clean"
		sbar.add("item", clean, {
			position = "popup." .. bracket.name,
			icon = { drawing = false },
			label = { string = "Everything up to date", align = "center", color = colors.grey },
			width = 320,
		})
		track(clean)
		return
	end

	local shown = math.min(#entries, PAGE_SIZE)
	for i = 1, shown do
		local e = entries[i]
		local row_name = TOOL_PREFIX .. ".entry." .. i
		sbar.add("item", row_name, {
			position = "popup." .. bracket.name,
			icon = {
				string = ICON_BOX,
				align = "left",
				width = 20,
				color = e.kind == "cask" and colors.magenta or colors.blue,
				font = { family = NERD_FONT, size = 12 },
			},
			label = {
				string = e.name .. "  " .. e.installed .. " → " .. e.current,
				align = "left",
				width = 290,
				color = colors.white,
				font = { size = 11 },
			},
			width = 320,
		})
		track(row_name)
	end

	if #entries > PAGE_SIZE then
		local more_name = TOOL_PREFIX .. ".row.more"
		local more = sbar.add("item", more_name, {
			position = "popup." .. bracket.name,
			icon = { drawing = false },
			label = {
				string = "+ " .. (#entries - PAGE_SIZE) .. " more — click to see full list",
				align = "center",
				width = 320,
				color = colors.grey,
				font = { size = 11 },
			},
			width = 320,
		})
		more:subscribe("mouse.clicked", function()
			run_in_terminal("brew outdated")
			sbar.set(bracket.name, { popup = { drawing = "off" } })
			clear_rows()
		end)
		track(more_name)
	end
end

local function add_action_row(id, icon_char, label_text, color, cmd)
	local row_name = TOOL_PREFIX .. ".action." .. id
	local row = sbar.add("item", row_name, {
		position = "popup." .. bracket.name,
		icon = {
			string = icon_char,
			align = "left",
			width = 20,
			color = color,
			font = { family = NERD_FONT, size = 12 },
		},
		label = { string = label_text, align = "left", width = 290, color = colors.white, font = { size = 12 } },
		width = 320,
		background = { color = colors.bg2, corner_radius = 4, height = 22 },
	})
	row:subscribe("mouse.clicked", function()
		run_in_terminal(cmd)
		sbar.set(bracket.name, { popup = { drawing = "off" } })
		clear_rows()
	end)
	track(row_name)
end

-- Build popup: header, dashboard actions, then the first PAGE_SIZE entries
local function refresh_popup()
	do_scan(function(summary, entries)
		clear_rows()

		if not summary then
			local err = TOOL_PREFIX .. ".row.err"
			sbar.add("item", err, {
				position = "popup." .. bracket.name,
				icon = { drawing = false },
				label = { string = "brew scan failed", align = "center" },
				width = 320,
			})
			track(err)
			return
		end

		local outdated = summary.formula_count + summary.cask_count
		local installed = summary.formula_installed + summary.cask_installed

		local header = TOOL_PREFIX .. ".row.header"
		sbar.add("item", header, {
			position = "popup." .. bracket.name,
			icon = {
				string = outdated .. " outdated \194\183 " .. installed .. " installed",
				align = "left",
				width = 220,
			},
			label = { string = "brew " .. summary.version, align = "right", width = 100, color = colors.grey },
			width = 320,
		})
		track(header)

		add_action_row("upgrade", ICON_UPGRADE, "Upgrade All", colors.green, "brew upgrade")
		add_action_row("cleanup", ICON_CLEANUP, "Cleanup", colors.yellow, "brew cleanup")
		add_action_row("doctor", ICON_DOCTOR, "Doctor", colors.blue, "brew doctor")

		sbar.add("item", TOOL_PREFIX .. ".row.sep", {
			position = "popup." .. bracket.name,
			background = { height = 1, color = colors.bg2 },
			width = 320,
		})
		track(TOOL_PREFIX .. ".row.sep")

		table.sort(entries, function(a, b)
			if a.kind ~= b.kind then
				return a.kind == "formula"
			end
			return a.name < b.name
		end)

		render_entries(entries)
	end)
end

-- Click
chip:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		run_in_terminal("brew upgrade")
		return
	end

	local q = sbar.query(bracket.name)
	if q and q.popup and q.popup.drawing == "on" then
		sbar.set(bracket.name, { popup = { drawing = "off" } })
		clear_rows()
	else
		sbar.set(bracket.name, { popup = { drawing = "on" } })
		sbar.delay(0.1, refresh_popup)
	end
end)

-- Periodic
chip:subscribe({ "routine", "system_woke" }, refresh_chip)

sbar.add("item", { position = "right", width = settings.group_paddings })

refresh_chip()
