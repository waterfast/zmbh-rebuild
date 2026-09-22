# AGENTS.md

## 项目背景

这是用 Godot 编写的《造梦西游》开源重构项目。

`oldproject/` 里是老版本代码。老版本代码质量很差，只作为功能行为和资源迁移时的参考，不要在重构中模仿它的写法和耦合方式，也不要修改 `oldproject/` 里的任何文件。

## 重构目标

用更解耦的架构重构：各功能模块相互独立、职责单一，模块之间通过明确的接口和信号通信，避免全局单例式的隐式依赖。改动新代码时保持这个方向：新增功能放进独立的模块，而不是把逻辑继续堆进现有大类。

## 目录约定

- `Script/`、`Scene/`：新版代码主体（actors / app / content / core / systems / ui / world / tests 等子目录）。
- `docs/`：架构总览、系统实现逻辑、重构要求与验收标准等文档。
- `oldproject/`：旧版代码，仅供参考，禁止修改。
- `assets/`、`content/`、`presentation/`：资源与表现层资产。

## 验证方式

在仓库根目录运行（`godot` 不在 PATH 时用 Godot 可执行文件绝对路径）：

```text
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://Script/tests/run_tests.gd
```

改动后跑一遍测试，保证现有功能不被破坏。
