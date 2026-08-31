# libxcb 1.15 验证

[English](README.md)

`tests/TestXcb.c` 是针对 Ubuntu 24.04 libxcb core port 的定向 native 与 Hecate smoke workload。它连接真实 X server，读取 setup record，分配 XID，创建并映射 window，执行 checked request，取得 reply 后销毁 window。

运行 `./evaluations/1-libs/libxcb/run.sh`。package、vcpkg buildtree、生成 thunk 与测试程序位于 `.work/evaluations/libxcb`。runner 默认继承当前环境的 `DISPLAY` 与 `XAUTHORITY`。需要覆盖当前图形会话时，可通过 `GUI_ENV` 指定一个同时包含这两个变量的文件。

workload 还通过 `xcb_take_socket` 转移 socket ownership，下一次请求迫使 libxcb 通过 guest callback 返还 socket。callback closure counter 与 guest-global callback counter 都必须为 1。第一次 Spark smoke run 使用 `DISPLAY=:1` 与 `/run/user/1004/gdm/Xauthority`，两条 lane 均输出 `xcb:11:0:1:1:3` 并以状态 0 退出。正式运行会在 `results` 或 `reference-results` 记录自身环境与汇总。
