# CfxLua CLI Toolchain

[![Release](https://img.shields.io/github/v/release/VIRUXE/cfxlua-cli?include_prereleases)](https://github.com/VIRUXE/cfxlua-cli/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**CfxLua CLI** is a standalone verification and static analysis tool for FiveM Lua scripts. 

Standard Lua checkers (like `luac`) fail when encountering FiveM's specific Lua flavour—which includes custom power patches (like `each` iterators and safe navigation) and first-class vector/matrix types. This toolchain solves that by providing a server-independent environment powered by the same specialized **LuaGLM 5.4** VM used by CitizenFX.

## 🌟 Key Features

-   **Native FiveM Support**: Full support for CitizenFX Lua 5.4 features, including `each` iterators, `defer`, safe navigation (`?.`), and callable vectors/quaternions.
-   **MagicMock System**: Automatically handles missing globals (e.g., `lib`, `ox_inventory`, or client-only natives) by returning intelligent, indexable/callable stubs instead of crashing.
-   **Lazy Resource Discovery**: Dynamically scans your `resources/` folder to discover and mock exports from other resources, enabling cross-resource static analysis.
-   **Execution Safety**: Integrated timeout protection (default 5s) prevents verification hangs on scripts containing infinite loops (like `while true do Wait(0) end`).
-   **Powered by LuaGLM**: High-performance mathematics support with first-class vector, matrix, and quaternion types.

---

## 🚀 Installation

### Quick Install (Pre-compiled Binaries)

Download the latest package for your platform from the [Releases](https://github.com/VIRUXE/cfxlua-cli/releases) page.

#### Linux
1. Extract the `.tar.gz` archive.
2. Run the installer:
   ```bash
   sudo ./install.sh
   ```

#### Windows
1. Extract the `.zip` archive.
2. Run `install.bat` as Administrator (to ensure PATH is updated).
3. Restart your terminal.

### Build from Source

Requirements: `build-essential`, `cmake`, and `mingw-w64` (for Windows cross-compilation).

```bash
git clone https://github.com/VIRUXE/cfxlua-cli.git
cd cfxlua-cli
make -j$(nproc)
sudo ./install.sh
```

---

## 📖 Usage

To verify a script, simply pass the file path to the `cfxlua` command:

```bash
cfxlua path/to/your/resource/server.lua
```

### Environment Variables

-   **`CFXLUA_TIMEOUT`**: Execution timeout in milliseconds (default: `5000`).
-   **`CFXLUA_VM`**: Path to a custom Lua VM binary.
-   **`CFXLUA_RUNTIME`**: Path to a custom runtime mock directory.

---

## 🛠️ Advanced Configuration

### Lazy Resource Discovery
The tool attempts to resolve unknown exports by searching for an `fxmanifest.lua` in sibling directories. If an export like `exports.qbx_core:Notify()` is encountered, it will find the `qbx_core` resource and automatically stub the requested function.

### MagicMocks
If your script relies on external libraries (like `ox_lib`) that aren't present in the standalone environment, the MagicMock system ensures that calls to `lib.*` or undefined natives return `nil` or dummy objects gracefully, allowing the syntax check to continue.

---

## 🧬 Technical Background (LuaGLM)

This toolchain is built upon **LuaGLM**, a Lua 5.4.4 runtime providing complete bindings to the [GLM](https://github.com/g-truc/glm) C++ mathematics library.

### Vectors & Quaternions
Vectors are first-class, immutable types. You can use standard GLSL swizzling and arithmetic:
```lua
local v = vec(1.0, 2.0, 3.0)
print(v.xyz) -- vec3(1.0, 2.0, 3.0)
print(#v)    -- 3.74165 (Magnitude)
```

### Power Patches
- **Compound Operators**: `+=`, `-=`, `*=`, `/=`, etc.
- **Safe Navigation**: `t?.x?.y` returns `nil` if `t` or `x` are missing.
- **In Unpacking**: `local a, b in t` (Unpacks keys from table `t`).
- **Each Iteration**: `for k, v in each(t) do ... end`.

---

## 🤝 Contributing

Contributions to improve mocks, add support for more FiveM-specific patterns, or enhance the resource discovery logic are welcome!

1. Fork the repository.
2. Create your feature branch (`git checkout -b feat/amazing-mock`).
3. Commit your changes.
4. Push to the branch and open a Pull Request.

## 📜 Credits

-   **VIRUXE**: Advanced Mocks and CLI Toolchain.
-   **Cfx.re**: Original LuaGLM 5.4 runtime and FiveM integration patches.
-   **Polaris Naz**: Performance patches and execution safety logic.
-   **Lua Team**: The base Lua language.

## ⚖️ License
This project is licensed under the **MIT License**. See `lua.h` for the original Lua copyright notice.
