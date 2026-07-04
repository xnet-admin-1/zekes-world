# Zeek's World

A kid-friendly creative voxel game built on [Luanti](https://luanti.org). Explore your real neighborhood as blocks with Oliver, your AI cat companion.

## Features

- **Creative mode only** — no damage, no death, no pressure
- **Oliver** — an AI-powered orange tabby cat that follows you and talks
- **Real-world neighborhood** — generated from OpenStreetMap data at your location
- **Simple block palette** — curated colors a 5-year-old can choose from
- **Big, clear HUD** — designed for small hands on a touchscreen

## Architecture

This is a Luanti "game" (total conversion). It runs on the Luanti engine but provides its own mods, textures, and configuration.

```
zekes-world/
├── game.conf              # Game metadata
├── minetest.conf          # Default engine settings
├── settingtypes.txt       # Configurable settings
├── mods/
│   ├── zw_blocks/         # Curated block palette
│   ├── zw_oliver/         # AI cat companion
│   ├── zw_mapgen/         # OSM-based world generation
│   └── zw_hud/            # Kid-friendly HUD
├── menu/                  # Custom main menu assets
└── textures/              # Block and entity textures
```

## Requirements

- Luanti engine (fork: xnet-admin-1/luanti)
- LLM API endpoint for Oliver (default: inf.xnet.ngo)

## License

LGPL 2.1+ (same as Luanti)
