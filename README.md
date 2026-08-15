<div align="center">

# 🎨 SketchyBar Configuration

**A Tokyo Night-inspired SketchyBar setup for macOS with Aerospace integration**

[![macOS](https://img.shields.io/badge/macOS-12%2B-000000?style=for-the-badge&logo=apple)](https://www.apple.com/macos/)
[![SketchyBar](https://img.shields.io/badge/SketchyBar-Latest-4285F4?style=for-the-badge)](https://github.com/FelixKratz/SketchyBar)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](https://www.gnu.org/licenses/gpl-3.0)

</div>

---

## 🔍 Overview

A personal **SketchyBar** configuration for **macOS**, designed to work seamlessly with **Aerospace** window manager. Built on Felix Kratz's excellent SbarLua framework, this configuration extends the original with Tokyo Night theming, custom widgets, and multi-monitor workspace integration.

<div align="center">

### ✨ Key Features

| Feature                          | Description                                               |
| -------------------------------- | --------------------------------------------------------- |
| 🌙 **Tokyo Night Theme**         | Beautiful dark colorscheme matching Neovim setup          |
| 🖥️ **Multi-Monitor Support**     | Native Aerospace workspace indicators across displays     |
| 📊 **Rich Widgets**              | WiFi, battery, CPU, media player, and weather integration |
| 🎯 **Smart Workspaces**          | Auto-hiding empty workspaces with app icons               |
| 🎨 **Custom Icons**              | Extended app icon font for beautiful visual indicators    |
| ✈️ **Aerospace Config Included** | Pre-configured `.aerospace.toml` for seamless integration |

</div>

## 📋 Table of Contents

- [What the Installer Does](#-what-the-installer-does)
- [Installation](#-installation)
- [Required Customization](#-required-customization)
- [Configuration Structure](#-configuration-structure)
- [Verification & Troubleshooting](#-verification--troubleshooting)
- [Customization Tips](#-customization-tips)
- [Credits](#-credits--acknowledgments)
- [Roadmap](#-roadmap)

## 🤖 What the Installer Does

The provided `install.sh` script automates the complete setup process through 5 stages:

<details open>
<summary><b>Stage 1: Homebrew Dependencies</b></summary>
<br>

Installs all required packages:

- `lua` - Core language for SbarLua framework
- `switchaudio-osx` - Audio device switching functionality
- `nowplaying-cli` - Media player integration
- `pnpm` - Package manager for building app font
- `sketchybar` - The main status bar application

</details>

<details open>
<summary><b>Stage 2: Fonts Installation</b></summary>
<br>

Downloads and installs essential fonts:

- Apple SF Symbols, SF Mono, and SF Pro fonts
- Victor Mono Nerd Font for coding elements
- Custom `sketchybar-app-font` with app icons (builds from source)

</details>

<details open>
<summary><b>Stage 3: SbarLua Framework</b></summary>
<br>

Installs Felix's Lua framework that powers this configuration

</details>

<details open>
<summary><b>Stage 4: Configuration Setup</b></summary>
<br>

- Backs up existing configuration
- Clones this repository to the correct location
- Sets up proper file permissions

</details>

<details open>
<summary><b>Stage 5: Service Initialization</b></summary>
<br>

Restarts SketchyBar with the new configuration and validates installation

</details>

## 🔧 Installation

### Prerequisites

<details open>
<summary>Required software</summary>
<br>

- **macOS 12+**: Required for SketchyBar compatibility
- **Homebrew**: Package manager for installing dependencies
- **Aerospace**: Window manager for workspace integration
- **Git**: For cloning the configuration repository

</details>

### Quick Installation

<details open>
<summary><b>One-Command Setup</b></summary>
<br>

```bash
# Clone the repository
git clone https://github.com/NoamFav/sketchybar.git
cd sketchybar

# Make installer executable and run
chmod +x install.sh
./install.sh
```

The installer handles everything automatically. After completion, your status bar will restart with the new configuration.

</details>

## ⚙️ Required Customization

> **⚠️ Early Stage Notice:**  
> This configuration is still under active development.  
> Some widgets and integrations are unfinished, experimental, or tailored to my setup.  
> Expect changes, and feel free to tweak for your own workflow.
> The git integrations is still under development and far from finished (and working for that matter)

<details open>
<summary><b>🖥️ Multi-Monitor Setup (CRITICAL)</b></summary>
<br>

The Aerospace workspace configuration in `~/.config/sketchybar/items/aerospace_workspaces.lua` is set up for my specific 3-monitor layout:

```lua
local WORKSPACE_LAYOUT = {
	{ display = 3, workspaces = { "1", "2", "3", "4", "5", "6", "7", "8", "9" } }, -- left monitor
	{ display = 1, workspaces = { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" } }, -- middle monitor
	{ display = 2, workspaces = { "A", "S", "D", "F", "G", "Z", "X", "C", "V", "B" } }, -- right monitor
}
```

**You MUST modify this:**

- Update display numbers to match your monitor arrangement
- Change workspace names to match your Aerospace configuration
- For single monitor setups, use `display = "active"` and combine all workspaces

</details>

<details open>
<summary><b>🛜 WiFi Interface Configuration</b></summary>
<br>

The WiFi widget requires your specific network interface:

1. **Find your interface:**

   ```bash
   networksetup -listallhardwareports
   ```

2. **Look for "Wi-Fi"** and note the "Device" name (usually `en0`, `en1`, etc.)

3. **Update `items/wifi.lua`** with your interface name (currently set to `en8`)

</details>

<details>
<summary><b>🌤️ Weather Location</b></summary>
<br>

Update the weather widget location in `items/weather.lua` on line 67 (an easier way will be added later)

</details>

<details>
<summary><b>🎵 Media Player Integration</b></summary>
<br>

The media widget (`items/media.lua`) uses **osascript** for **Apple Music**. For other players:

- **Spotify**: Replace osascript commands with Spotify equivalents
- **Universal**: Use `nowplaying-cli` for broader player support (already installed)

</details>

<details>
<summary><b>✈️ Aerospace Integration</b></summary>
<br>

This configuration includes a pre-configured `.aerospace.toml` that matches the SketchyBar workspace layout. Features include:

- **Multi-monitor workspace assignment** - Workspaces distributed across displays
- **Seamless integration** - SketchyBar automatically detects and displays workspace status
- **Click interactions** - Left-click to switch, right-click to move windows
- **Auto-hiding workspaces** - Empty workspaces hide automatically (except focused)

**Setup Instructions:**

1. Copy the included `.aerospace.toml` to `~/.aerospace.toml`
2. Restart Aerospace: `aerospace reload-config`
3. The SketchyBar will automatically sync with your workspace layout as long as it matches with your monitor layout.

If not using the included Aerospace config, you'll need to modify the `WORKSPACE_LAYOUT` in `aerospace_workspaces.lua` to match your setup.

</details>

## 📁 Configuration Structure

```
~/.config/sketchybar/
├── 📄 sketchybarrc           # Main configuration entry point
├── 📁 core/                  # Bar setup, defaults, colors, settings, icons
│   ├── 📄 init.lua           # Loads bar/default/items into one config message
│   ├── 📄 bar.lua            # Bar shape/appearance
│   ├── 📄 default.lua        # Default item styling
│   ├── 📄 colors.lua         # Tokyo Night color scheme (falls back from colors_generated)
│   ├── 📄 colors_generated.lua/.sh  # Wallpaper-derived palette (regenerated, gitignored)
│   ├── 📄 settings.lua       # Global settings and styling
│   └── 📄 icons.lua          # Icon glyph tables
├── 📁 items/                 # Individual widget configurations
│   ├── 📄 aerospace_workspaces.lua  # Multi-monitor workspace indicators
│   ├── 📄 media.lua          # Now playing widget
│   └── 📁 widgets/           # wifi, battery, cpu, weather, volume, brew, music, git_toolkit
├── 📁 helpers/               # Utility functions and native event providers
│   ├── 📄 app_icons.lua      # App name to icon mappings
│   └── 📄 ...                # Other helper functions
└── 📁 theme/                 # Wallpaper-adaptive theme generator (theme/generate.sh)
```

## 🔍 Verification & Troubleshooting

### App Font Test

<details open>
<summary><b>Verify Icon Font Installation</b></summary>
<br>

```bash
# Test the app icons font
sketchybar --add item icon.test right
sketchybar --set icon.test label.font="sketchybar-app-font:Regular:18.0" label="figma"
```

You should see the Figma icon. If not:

```bash
# Restart the font daemon
sudo killall -9 fontd
fc-cache -f
```

</details>

### Common Issues

<details>
<summary><b>Troubleshooting Guide</b></summary>
<br>

| Issue                      | Solution                                          |
| -------------------------- | ------------------------------------------------- |
| **Workspaces not showing** | Check Aerospace config matches `WORKSPACE_LAYOUT` |
| **WiFi widget broken**     | Update network interface in `wifi.lua`            |
| **Font issues**            | Run `fc-cache -f` and restart SketchyBar          |
| **Permission errors**      | Ensure SketchyBar has accessibility permissions   |
| **Colors incorrect**       | Verify Tokyo Night theme files are loaded         |

</details>

## 🎨 Customization Tips

<div align="center">

| Customization        | Location              | Description                                  |
| -------------------- | --------------------- | -------------------------------------------- |
| **Colors**           | `core/colors.lua`     | Tokyo Night theme modifications              |
| **Fonts**            | `core/settings.lua`   | Font families and sizes                      |
| **Widget Position**  | Individual item files | Left, center, or right positioning           |
| **Update Frequency** | Widget files          | Refresh intervals for dynamic content        |
| **New Widgets**      | `items/` directory    | Create new files following existing patterns |

</div>

<details>
<summary><b>Advanced Customization Examples</b></summary>
<br>

```lua
-- Change update frequency for CPU widget
cpu:subscribe("cpu_update", function()
    -- Custom logic here
end)

-- Modify color scheme
local colors = require("colors")
colors.primary = "#your_color_here"

-- Add custom widget
local custom_widget = sbar.add("item", "custom", {
    position = "right",
    -- Additional properties
})
```

</details>

## 🙏 Credits & Acknowledgments

<div align="center">

### 🌟 Primary Credits

</div>

<details open>
<summary><b>🎯 FelixKratz</b></summary>
<br>

The foundation of this entire configuration:

- **[SketchyBar](https://github.com/FelixKratz/SketchyBar)** - The revolutionary status bar application
- **[SbarLua](https://github.com/FelixKratz/SbarLua)** - Elegant Lua framework for modern configs
- **[Original Dotfiles](https://github.com/FelixKratz/dotfiles)** - Inspiration and structural foundation
- **Ongoing Development** - Continuous improvements to the ecosystem

_Without Felix's groundbreaking work, none of this would exist._

</details>

<details>
<summary><b>🎨 Additional Contributors</b></summary>
<br>

- **[kvndrsslr](https://github.com/kvndrsslr/sketchybar-app-font)** - Beautiful app icons font
- **[Tokyo Night](https://github.com/folke/tokyonight.nvim)** - Stunning color scheme inspiration
- **[Aerospace Team](https://github.com/nikitabobko/AeroSpace)** - Excellent tiling window manager

</details>

## 🚀 Roadmap

<details open>
<summary><b>🚧 Currently Working On</b></summary>
<br>

- [ ] **Centralized Settings** - Move hardcoded values to unified configuration
- [ ] **Improved Error Handling** - Better dependency validation and error messages
- [ ] **Single-Monitor Documentation** - Comprehensive guide for single-display setups
- [ ] **Automatic Interface Detection** - Smart WiFi interface discovery
- [ ] **Multi-Player Media Support** - Spotify, YouTube Music, and other services

</details>

<details>
<summary><b>🎯 Planned Features</b></summary>
<br>

- [ ] **Configuration Wizard** - Interactive setup for easy customization
- [ ] **Display Auto-Detection** - Automatic workspace layout generation
- [ ] **Theme Variants** - Multiple colorscheme options beyond Tokyo Night
- [ ] **Window Manager Agnostic** - Support for yabai and other managers
- [ ] **Plugin System** - Modular widget architecture for extensibility

</details>

<details>
<summary><b>🐛 Known Issues</b></summary>
<br>

- Workspace indicators may flicker during rapid workspace switching
- Font installation can be inconsistent on some macOS versions
- Media widget limited to Apple Music (osascript dependency)
- Weather widget hardcoded to Maastricht location
- WiFi widget requires manual interface configuration

</details>

## 📜 License

This project is licensed under the **GNU GPL v3** - see [LICENSE](LICENSE) file for details.

This preserves the open-source nature of Felix's original work while allowing free use and modification.

## 💡 Contributing

Since this is a personal configuration, contributions are welcome for:

- 🐛 **Bug Reports** - Compatibility issues and fixes
- 💡 **Feature Suggestions** - Improvements for common use cases
- 🔧 **Modifications** - Share your customizations and forks

For major changes, please open an issue first to discuss your proposed modifications.

<div align="center">

---

**Built with ❤️ on macOS using Felix's excellent SketchyBar and SbarLua**

_Inspired by Tokyo Night • Powered by Aerospace • Enhanced for productivity_

</div>
