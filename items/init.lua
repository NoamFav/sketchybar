local minimal = os.getenv("SKETCHYBAR_MINIMAL") == "1"

if minimal then
	require("items.apple")
	require("items.menus")
	require("items.aerospace_workspaces")
	require("items.calendar")
	require("items.widgets.battery")
	require("items.widgets.wifi")
	require("items.widgets.git_toolkit")
	require("items.widgets.music")
else
	require("items.apple")
	require("items.menus")
	require("items.aerospace_workspaces")
	require("items.front_app")
	require("items.calendar")
	require("items.widgets")
	-- require("items.media") deprecated rn
end
