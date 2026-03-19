local minimal = os.getenv("SKETCHYBAR_MINIMAL") == "1"

if minimal then
	require("items.apple")
	require("items.menus")
	require("items.aerospace_workspaces")
	require("items.calendar")
else
	require("items.apple")
	require("items.menus")
	require("items.aerospace_workspaces")
	require("items.front_app")
	require("items.calendar")
	require("items.widgets")
	require("items.media")
end
