.PHONY: rust swift project clean all

all: rust project

# Build Rust core library
rust:
	cd memcrunch-core && cargo build --release

# Generate Xcode project
project:
	cd MemCrunch && xcodegen generate

# Build Swift app via xcodebuild
swift: rust project
	cd MemCrunch && xcodebuild -project MemCrunch.xcodeproj -scheme MemCrunch -configuration Release build

# Clean everything
clean:
	cd memcrunch-core && cargo clean
	rm -rf MemCrunch/MemCrunch.xcodeproj
	rm -rf MemCrunch/build
