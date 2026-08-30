# libyaml 0.2.5 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方运行固定上游 CMake 配置启用的 2 项测试，验证版本报告与 parser buffer 处理。native 与 Hecate CTest lane 都必须成功。

上游 reader 测试使用内部 `yaml_parser_update_buffer`，因此将其声明加入分析。工具、examples 与测试外 API 排除，不使用 HLR。运行 `./evaluations/1-libs/libyaml/run.sh` 安装两个架构、生成 TLC thunk，并运行两项测试。port 将它们安装到 `tools/libyaml/upstream-tests`，`--install-only` 在安装和 thunk 生成后停止。
