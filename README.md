# 中国象棋 GUI 应用程序

一个使用 Harbour 语言开发的跨平台中国象棋 GUI 应用程序，支持 AI 对弈、棋谱分析等功能。

## 许可证

本项目的主代码（作者原创部分）已发布为 **Public Domain (CC0 1.0 Universal)**。

### CC0 许可证摘要

这意味着：
- ✅ **任何人都可以**：复制、修改、分发、使用（包括商业用途）
- ✅ **无需归属**：不需要注明作者
- ✅ **可以闭源**：派生作品可以保持私有
- ✅ **无限制**：没有任何法律限制

完整许可证文本见项目根目录的 `LICENSE` 文件。

## 第三方代码许可证

项目包含以下第三方代码，各自遵循不同的许可证：

### 1. ElephantEye 引擎（eleeye_hb/）
- **许可证**：GNU Lesser General Public License v2.1 (LGPL v2.1)
- **重要例外**：ucci.h/ucci.cpp 部分不在 LGPL 下，可以无限制使用
- **详细信息**：参见 `eleeye_hb/README.md` 和 `eleeye_hb/LICENSE.ELEPHANTEYE`

### 2. Harbour 编译器
- **许可证**：Harbour 许可证
- **位置**：`harbour-source/LICENSE.txt`

### 3. HwGUI 库
- **许可证**：Harbour 许可证
- **位置**：`hwgui-source/`

### 4. xqengine 库
- **许可证**：Public Domain (CC0 1.0 Universal)
- **位置**：`xqengine.prg/LICENSE`

## 许可证兼容性

**Public Domain (CC0) 与 LGPL v2.1 完全兼容**，项目许可证无冲突。

## 注意事项

虽然主代码是 Public Domain，但：
1. ElephantEye 引擎部分仍受 LGPL v2.1 约束
2. 使用 ElephantEye 引擎时需遵守 LGPL v2.1 的要求
3. 分发包含 ElephantEye 引擎的可执行文件时，需提供 ElephantEye 引擎的源代码

## 项目特性

- 🎮 完整的中国象棋规则实现
- 🤖 集成 AI 引擎（ElephantEye）
- 📝 棋谱记录和分析
- 🌍 国际化支持（中英文）
- 🖥️ 跨平台支持（Linux/Windows）

## 快速开始

### Linux

```bash
# 编译
/opt/harbour/bin/hbmk2 xq.hbp

# 运行
./xq
```

### Windows

```bash
# 使用构建脚本
./build.sh gui windows

# 运行
./xq.exe
```

## AI 引擎配置

**注意**：AI 引擎文件不包含在发布包中，需要用户自行下载和配置。

### ElephantEye 引擎
- **下载地址**：https://www.xqbase.com/
- **许可证**：LGPL v2.1
- **配置方法**：
  1. 下载引擎文件
  2. 将引擎文件放置在 `engines/eleeye/` 目录
  3. 在程序中配置引擎路径

### Pikafish 引擎
- **下载地址**：https://github.com/official-pikafish/Pikafish
- **许可证**：GPL v3
- **配置方法**：
  1. 下载引擎文件
  2. 将引擎文件放置在 `engines/pikafish/` 目录
  3. 在程序中配置引擎路径

详细的引擎配置说明请参见程序内的设置菜单。

## 文档

详细文档请参见：
- `中国象棋-设计.md` - 完整的设计文档
- `AGENTS.md` - AI 上下文指南
- `BUILD_HBMK2.md` - 编译说明

## 许可证历史

- **2026-03-15**：从 CC BY-NC-SA 4.0 更改为 CC0 1.0 Universal
- **原因**：解决与 ElephantEye 引擎 LGPL v2.1 许可证的冲突