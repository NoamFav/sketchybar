sbar = require("sketchybar")

-- begin_config/end_config batches everything below into one message to sketchybar
sbar.begin_config()
require("core.bar")
require("core.default")
require("items")
sbar.end_config()

sbar.event_loop()
