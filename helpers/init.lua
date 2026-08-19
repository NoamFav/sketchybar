-- so core/init.lua's require("sketchybar") can find the compiled lib
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

os.execute("(cd helpers && make)")
