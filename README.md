# MPV Blur Edges Script

A fork of [occivink/mpv-scripts](https://github.com/occivink/mpv-scripts) with enhanced features for blurring black bars in MPV. Thanks to **occivink** for the original implementation!

## Features

- **Blur black bars** - Replace black letterbox/pillarbox bars with blurred video content
- **Mirror effect** - Horizontally/vertically flip edges for seamless continuation
- **Scaling control** - Choose between scaled or cropped blur content
- **Mode selection** - Apply blur to horizontal bars, vertical bars, or both
- **Customizable blur intensity** - Adjust blur radius and power
- **Fullscreen/windowed support** - Works in both modes

## Installation

1. Copy `blur-edges.lua` to your MPV scripts directory:
   ```
   %APPDATA%\mpv\scripts\
   ```

2. Copy `blur_edges.conf` to your MPV script-opts directory:
   ```
   %APPDATA%\mpv\script-opts\
   ```

3. Add key binding to your `input.conf`:
   ```
   b script-message-to blur_edges toggle-blur
   ```

## Usage

### Basic Controls

- **Press `b`** - Toggle blur effect on/off
- The script automatically detects black bars and applies blur accordingly

### Configuration Options

Edit `script-opts/blur_edges.conf` to customize:

```properties
# Enable/disable script by default
active=yes

# Which black bars to blur: "all", "horizontal", or "vertical"
mode=all

# Blur intensity (0-50)
blur_radius=5
blur_power=5

# Minimum black bar size to apply effect (pixels)
minimum_black_bar_size=3

# Scale blurred content to fit black bars
scale=no

# Mirror edges for seamless effect
mirror=yes

# Only apply in fullscreen mode
only_fullscreen=no

# Delay before reapplying after aspect change
reapply_delay=0.3
```

## Configuration Details

### Mode Options
- **`all`** - Blur both horizontal and vertical black bars
- **`horizontal`** - Only blur left/right black bars (pillarboxing)  
- **`vertical`** - Only blur top/bottom black bars (letterboxing)

### Blur Settings
- **`blur_radius`** - Controls blur spread (1-50, higher = more blurred)
- **`blur_power`** - Controls blur intensity (1-50, higher = stronger blur)

### Scaling Options
- **`scale=yes`** - Stretches cropped edges to fill black bar area
- **`scale=no`** - Uses cropped edges at original size

### Mirror Effect
- **`mirror=yes`** - Flips edges horizontally/vertically for seamless look
- **`mirror=no`** - Uses direct cropped content without flipping