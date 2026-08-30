# 系统 Vulkan loader 验证

[English](README.md)

本配方使用 Ubuntu 24.04 已安装的 Vulkan loader 与 ICD。`vulkan-loader` overlay port 不构建或复制 loader，其 CMake project 在 vcpkg package tree 中生成并安装 thunk pack、native 与 x86_64 验证程序、`ThunkDB.json` 和 TLC audit 输出。evaluation 脚本只安装该 port、运行打包程序并收集证据。

测试创建 instance 与 device，解析 instance 和 device procedure，分配并 map device memory，经共享 mapping 写入，最后销毁全部 object。

初始 callback 支持策略是明确的。null `VkAllocationCallbacks` 可用。提供 allocator 或含 callback 的 `pNext` node 的应用需要具备 lifetime 管理的 host callback trampoline，不能让原始 guest 地址静默穿透。
