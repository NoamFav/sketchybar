-- Require the sketchybar module
sbar = require("sketchybar")

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()
require("core.bar")
require("core.default")
require("items")
sbar.end_config()

sbar.event_loop()
