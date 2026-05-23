# CfxLua CLI Toolchain

A standalone verification toolchain for FiveM Lua scripts, powered by the Polaris-patched **LuaGLM 5.4** VM.

## Features

- **Polaris Patches**: Custom optimizations and fixes for FiveM script verification.
- **MagicMock System**: Automatically handles missing globals (like `lib`, `ox_inventory`, or client-only natives) by returning indexable/callable stubs instead of crashing.
- **Lazy Resource Discovery**: Dynamically scans your `resources/` folder to discover exports from other resources, allowing for deep static analysis across resource boundaries.
- **Infinite Loop Protection**: Integrated execution timeout (default 5s) to prevent CI/CD pipelines from hanging on infinite `Wait(0)` loops.
- **Full Lua 5.4 Support**: Supports all CitizenFX Lua 5.4 features including `each` iterators, `defer`, and callable vectors.

## Installation

### 🚀 Quick Install (Download Release)

Download the latest package for your platform from the [Releases](https://github.com/USER/cfxlua-cli/releases) page.

#### Linux
1. Extract the `.tar.gz`.
2. Run `sudo ./install.sh`.

#### Windows
1. Extract the `.zip`.
2. Run `install.bat` (Admin may be required to update PATH).

### 🛠️ Build from Source

```bash
git clone https://github.com/USER/cfxlua-cli.git
cd cfxlua-cli
make -j$(nproc)
sudo ./install.sh
```

## Usage

Verify any Lua script:

```bash
cfxlua path/to/script.lua
```

### Environment Variables

- `CFXLUA_TIMEOUT`: Execution timeout in milliseconds (default: `5000`).
- `CFXLUA_VM`: Path to a custom Lua VM binary.
- `CFXLUA_RUNTIME`: Path to the runtime mock directory.

## Contributing

This tool is based on the [citizenfx/lua](https://github.com/citizenfx/lua) VM but adds a standalone verification layer. Contributions to mocks and resource discovery logic are welcome!

## Credits

- **Polaris Naz**: Patches, Advanced Mocks, and CLI logic.
- **Cfx.re**: Original LuaGLM 5.4 runtime.
