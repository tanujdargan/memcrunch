# MemCrunch for Windows

Native WPF (.NET 8) app calling the same Rust core via C FFI (P/Invoke).

## Prerequisites

- Windows 10/11
- .NET 8 SDK
- Rust toolchain (for building memcrunch-core)
- Visual Studio 2022 (optional, for IDE)

## Building

```powershell
# 1. Build the Rust core DLL
cd ..\memcrunch-core
cargo build --release --target x86_64-pc-windows-msvc

# 2. Copy the DLL to the C# project
copy target\x86_64-pc-windows-msvc\release\memcrunch_core.dll ..\memcrunch-windows\MemCrunch\

# 3. Build the C# app
cd ..\memcrunch-windows
dotnet build -c Release
```

## Running

```powershell
dotnet run --project MemCrunch -c Release
```

The app loads `memcrunch_core.dll` at runtime via P/Invoke. Make sure the DLL is in the same directory as the executable.
