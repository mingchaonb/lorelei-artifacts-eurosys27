# System Vulkan loader validation

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe uses the installed Ubuntu 24.04 Vulkan loader and ICDs. The `vulkan-loader` overlay port does not build or copy the loader. Its CMake project generates and installs the thunk pack, native and x86_64 validation programs, `ThunkDB.json`, and TLC audit output into the vcpkg package tree. The evaluation script only installs that port, runs the packaged programs, and collects evidence.

The test creates an instance and device, resolves instance and device procedures, allocates and maps device memory, writes through the shared mapping, and destroys every created object.

The initial supported callback policy is explicit. Null `VkAllocationCallbacks` works. Applications that provide allocators or callback-bearing `pNext` nodes require lifetime-aware host callback trampolines and must not silently fall through as raw guest addresses.
