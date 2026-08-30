# libmaxminddb 1.13.3 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方为 AArch64 与 x86-64 构建固定版本共享库，为上游 26 项 CTest suite 使用的 API 生成 thunk，再在 native 与 Hecate lane 运行。`MMDB_get_value` 使用以 null 结尾的定制 variadic path extractor。`MMDB_vget_value` 在跨 ABI boundary 前将 guest `va_list` 转换为 array-form API。private `data-pool-t` 程序额外提供 4 个导出测试 symbol。

数据库输入固定为 MaxMind-DB commit `819f226fbf8290c2b171ac077e6e050618dd3574`，GitHub archive SHA-512 为 `0d3bf40b95e6921f0d868a747dceca43ea52dac4759470756e67f8af6191900859f3bb2108b494d52a83b5a12d252469ffffd37dd349afa4f8dc5e2d2ab1cf13`。libtap 固定为 commit `b53e4ef5257f80e881762b6143834d8aae29da1a`，archive SHA-512 为 `4e8da92858fab7a3c04d86b3a62581301e520c907ee5284b7cc55e32affb4582f94f9c4326054462e361cda95ee4004083e2d52d3accdb2e03d062c1365c79c3`。CLI 工具和不支持的 API 排除，不加载 HLR extension。

运行 `./evaluations/1-libs/libmaxminddb/run.sh` 安装两个架构、生成 TLC thunk，并运行全部 26 项配置测试。测试程序和固定数据库输入安装到 `tools/libmaxminddb/upstream-tests`。`--install-only` 在 package 安装和 thunk 生成后停止。

26 项测试在 native 与 Hecate 均通过。negative-indent 测试只写 `/dev/null`，其 guest 入口返回文档规定的成功结果，不把 guest `FILE *` 传给 host glibc。该 workload 特定处理不声明支持任意 cross-ABI stream。
