# 许可证说明

## CC0-1.0 公共领域声明

对于本项目中的 XQEngine 核心库，作者已根据 CC0-1.0 放弃所有版权。

**适用范围：**
- `xqengine/` 目录下的所有源代码文件（.prg, .ch）
- `demo.prg` 演示程序
- `demo.hbp` 构建配置
- `build_info.ch` 和 `vcs_info.ch` 自动生成文件

**您的权利：**
您可以自由地：
- 商业使用
- 修改
- 分发
- 私有化使用
- ...以及任何其他目的

无需署名，无需保留许可证声明。

## GPL-3.0 第三方组件

本项目包含以下 GPL-3.0 组件：

### Pikafish 引擎
- **许可证**: GPL-3.0
- **版本**: dev-20260301-981613de
- **文件**: `xqengine/pikafish`
- **来源**: https://github.com/official-pikafish/Pikafish
- **版权**: Copyright (C) 2015-2024 Stockfish developers (see AUTHORS file)

### Pikafish NNUE 权重文件
- **许可证**: GPL-3.0
- **文件**: `xqengine/pikafish.nnue`
- **来源**: https://github.com/official-pikafish/Pikafish

**GPL-3.0 要求：**
- 保留版权声明
- 如果修改，必须开源修改后的代码
- 分发时必须提供 GPL-3.0 许可证副本
- 不能移除或修改许可证声明

## 许可证兼容性说明

### 架构说明
XQEngine 通过进程间通信（IPC）与 Pikafish 交互：

```
XQEngine (CC0-1.0)
     ↓ stdin/stdout 管道
Pikafish 进程 (GPL-3.0)
```

### 法律判断
- XQEngine 和 Pikafish 是独立的可执行文件
- 通过标准输入/输出管道通信
- 不涉及代码链接（静态或动态）
- 根据 GPL 定义，IPC 不构成衍生作品

### 结论
因此，这种混合使用是合法的：
- ✅ XQEngine 可以使用 CC0-1.0
- ✅ Pikafish 保持 GPL-3.0
- ✅ 两者可以一起分发
- ✅ 用户可以修改 XQEngine 并闭源（CC0 允许）
- ❌ 用户不能修改 Pikafish 后闭源（GPL 不允许）

## 使用建议

### 对于开发者
- 您可以自由使用 XQEngine 代码，无需遵守任何许可证限制
- 如果您修改 XQEngine，可以闭源或开源
- Pikafish 引擎必须保持 GPL-3.0 许可证

### 对于用户
- 您可以商业使用本项目
- 您可以修改 XQEngine 代码并私有化
- 如果您修改 Pikafish，必须开源修改后的代码
- 您不能移除 Pikafish 的版权声明

## 完整许可证文本

### CC0-1.0 许可证
请参见项目根目录的 `LICENSE` 文件。

### GPL-3.0 许可证
请参见 Pikafish 项目：
https://github.com/official-pikafish/Pikafish/blob/master/COPYING

## 联系方式

如有许可证相关问题，请：
1. 查看 CC0-1.0 官方文档：https://creativecommons.org/publicdomain/zero/1.0/
2. 查看 GPL-3.0 官方文档：https://www.gnu.org/licenses/gpl-3.0.html
3. 咨询专业法律顾问

---

**最后更新：** 2026-03-11
**项目版本：** v2.2.0
