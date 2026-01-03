# ztup

ztup is a command-line tool written in Zig that keeps the Zig compiler and ZLS (Zig Language Server) synchronized with the latest master versions. It automatically downloads and installs the newest releases while providing intelligent caching to minimize redundant downloads.

## Features

ztup offers a streamlined approach to managing Zig toolchain updates, combining simplicity with robust functionality. The tool automatically detects whether the latest version is already installed locally, and if not, it retrieves the appropriate package from available sources. Its intelligent caching mechanism stores downloaded archives in a central location, allowing subsequent installations to complete instantly by extracting from cache rather than fetching files again.

The community mirror system represents a significant reliability enhancement, automatically selecting from multiple download sources to avoid single-point-of-failures and regional network issues. When downloading Zig, the tool queries a community-maintained mirror list and randomly selects a mirror for each operation, distributing load across the network and providing fallback options when individual mirrors experience problems.

Built entirely in Zig, ztup demonstrates modern Zig programming practices including comptime reflection, error handling patterns, and memory management strategies that leverage the language's safety guarantees. The implementation uses Zig's standard library extensively, particularly the HTTP client, file system utilities, and process management facilities.

## Installation

Building ztup requires Zig 0.14.0 or later, which can be obtained from the official Zig website or through your system's package manager. Once Zig is installed, compile the project using the standard Zig build command, which produces a standalone executable without external runtime dependencies.

```bash
git clone https://github.com/yourusername/ztup.git
cd ztup
zig build -Doptimize=ReleaseFast
```

## Usage

ztup accepts a mode argument specifying which tool to update, with optional flags for controlling behavior. The command syntax follows a straightforward pattern: the mode argument determines the target, and the optional `-f` flag forces re-download even when the current version appears installed.

```bash
ztup <mode> [-f]
```

The available modes correspond to the two primary components of the Zig toolchain. Running `ztup zig` updates the Zig compiler itself to the latest master build, while `ztup zls` updates the Zig Language Server to maintain compatibility with your compiler version. Keeping both components synchronized ensures optimal IDE integration and language server functionality.

The `-f` flag bypasses installation and cache checks, forcing a fresh download and extraction regardless of existing files. This proves useful when troubleshooting installation issues or when you need to verify the complete download process. Standard usage without flags checks for existing installations first, extracting from cache when available and downloading only when necessary.

### Examples

Update Zig to the latest master version:

```bash
ztup zig
```

Update ZLS to the latest master version:

```bash
ztup zls
```

Force re-download and installation (skip cache and installation checks):

```bash
ztup zig -f
```

Display help information:

```bash
ztup -h
```

## How It Works

ztup operates through a carefully orchestrated sequence of checks and operations designed to minimize network usage while ensuring you always have the latest version. The workflow begins by determining the current master version from Ziglang's official index, then proceeds through a series of increasingly expensive operations only as needed.

The version detection mechanism queries the official Zig download index, which JSON-formatted data lists current master version strings. To reduce network traffic, ztup caches this index locally alongside the installation directory, allowing subsequent runs to read version information from disk rather than performing HTTP requests. The tool compares cached and remote versions automatically, fetching fresh data only when necessary.

Following version detection, ztup checks whether the requested version already exists in three possible locations. First, it examines the installation directory for extracted archives matching the expected directory structure. If found, the tool exits immediately, confirming that the latest version is ready to use. When not directly installed, the cache directory becomes the next check target. Pre-downloaded archives residing in the cache allow instant extraction without network involvement, dramatically speeding subsequent installations.

Only when neither installation nor cache contain the requested version does ztup initiate a download operation. For Zig downloads, the tool retrieves a community-maintained mirror list containing multiple download sources, randomly selects one mirror from the list, and uses wget to fetch the archive. This mirror selection process distributes load across the network while providing resilience against individual mirror failures or regional connectivity issues. ZLS downloads proceed directly from the official builds server at builds.zigtools.org.

After successful download, ztup extracts the archive using tar into the specified installation directory. The cache retains the compressed archive for future use, while the installation directory contains the extracted binaries ready for immediate use. Subsequent invocations with the same version skip the download step entirely, extracting from cache instead.

## Configuration

ztup requires minimal configuration, with most behavior determined automatically from the execution environment. The tool stores cached downloads in `$HOME/.cache/ztup`, creating this directory on first use. Installation targets the directory containing the ztup executable itself, allowing flexible installation anywhere in your file system.

The installation directory behavior stems from how ztup determines the target path. When invoked, the tool extracts the directory containing the executable from the command used to run it. Placing ztup in a dedicated bin directory and adding that directory to your PATH therefore establishes a predictable installation target.

For advanced configurations, consider creating a dedicated directory for Zig toolchains and placing the ztup executable within a PATH-accessible location. This separation keeps different toolchain versions organized and allows multiple independent installations if needed.

## Requirements

Running ztup requires several external dependencies beyond the Zig compiler itself. The tool relies on wget for downloading archives, making it a required dependency on all platforms. The tar utility handles archive extraction on Unix-like systems, while a compatible alternative handles this task on Windows.

```bash
# Debian/Ubuntu
sudo apt install wget tar

# Fedora/RHEL
sudo dnf install wget tar

# macOS (via Homebrew)
brew install wget

# macOS tar is pre-installed
```

The Zig compiler version must match or exceed version 0.14.0 to compile ztup from source. Using an older Zig version produces compilation errors due to API differences in the standard library.

## Architecture

ztup's modular architecture separates concerns into distinct modules, each handling a specific aspect of the tool's functionality. Understanding this structure proves valuable for extending the tool or troubleshooting issues.

The entry point module, `main.zig`, orchestrates the overall workflow, coordinating version detection, cache management, and download operations. It imports and utilizes functionality from other modules while handling the primary execution path. This module also defines constants for URL prefixes, file naming patterns, and archive extensions used throughout the tool.

Command-line parsing resides in `Cli.zig`, which processes runtime arguments and converts them into structured data. This module defines the `Mode` enumeration distinguishing between Zig and ZLS operations, parses positional arguments, and handles the help flag. The module produces a `Self` struct containing the target mode, installation directory, and force flag.

Utility functions populate `simple.zig`, providing HTTP request capabilities, file reading operations, and subprocess execution. The `tinyGet` function performs HTTP GET requests with automatic decompression, while `readAll` efficiently reads entire files into memory. The `execProcess` wrapper launches external commands like wget and tar, capturing their exit status for error detection.

Version index management happens in `index.zig`, which fetches and parses the official Zig version index. This module caches the index locally, checks for updates, and extracts version strings for both display and archive naming. The caching strategy here mirrors that used for binary downloads, reducing network overhead for frequently-run checks.

The mirror selection system lives in `mirrors.zig`, handling community mirror list retrieval and random selection. This module fetches the mirror list from Ziglang's infrastructure, caches it locally, parses the line-separated mirror URLs, and randomly selects one for use. The local caching ensures the selection process remains fast even without network connectivity.

## Contributing

Contributions welcome! Areas for improvement include additional platform support, particularly Windows where path handling and process execution differ from Unix conventions. Enhanced mirror selection algorithms, geographic-aware selection for example, would provide value to users in different regions. Package manager integration for popular systems would streamline installation for new users.

Bug reports and feature suggestions should be submitted through the project's issue tracker with clear reproduction steps for bugs and rationale for new features. Pull requests should follow Zig's style conventions and include tests where applicable.

## License

ztup is distributed under the MIT License, permitting free use, modification, and distribution including commercial applications. The full license text accompanies the source code in the repository.