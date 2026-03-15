# 中国象棋 GUI 发布说明

## 版本 {VERSION}

发布日期：{DATE}

## 下载

### Linux 版本
- **文件名**：`cchess-{VERSION}-linux-x86_64.tar.gz`
- **大小**：约 2MB（不含引擎）
- **平台**：Linux x86_64
- **运行要求**：
  - Linux x86_64 系统
  - GTK+ 2.0 库
  - 无需额外依赖
- **包含**：
  - 可执行文件
  - 皮肤资源
  - 声音文件
  - 配置文件
  - 文档
- **不包含**：
  - AI 引擎文件（需自行下载）

### Windows 版本
- **文件名**：`cchess-{VERSION}-windows-x86_64.zip`
- **大小**：约 2MB（不含引擎）
- **平台**：Windows x86_64
- **运行要求**：
  - Windows 10/11 x64
  - 无需额外依赖（静态链接）
- **包含**：
  - GUI 可执行文件
  - 控制台可执行文件
  - 皮肤资源
  - 声音文件
  - 配置文件
  - 文档
- **不包含**：
  - AI 引擎文件（需自行下载）

### 源代码
- **文件名**：`cchess-{VERSION}-source.tar.gz`
- **大小**：{SOURCE_SIZE}
- **平台**：所有平台
- **编译要求**：
  - Harbour 编译器
  - GCC (Linux) 或 MinGW64 (Windows)
  - HwGUI 库
  - ElephantEye 引擎

## 安装说明

### Linux
1. 下载 `cchess-{VERSION}-linux-x86_64.tar.gz`
2. 解压缩：
   ```bash
   tar xzf cchess-{VERSION}-linux-x86_64.tar.gz
   cd cchess-{VERSION}-linux-x86_64
   ```
3. 运行程序：
   ```bash
   ./xq
   ```

### Windows
1. 下载 `cchess-{VERSION}-windows-x86_64.zip`
2. 解压缩到任意目录
3. 双击 `xq.exe` 运行
4. 或使用控制台版本 `xq_con.exe`

## 包含的 AI 引擎

**重要提示**：AI 引擎文件不包含在发布包中，需要用户自行下载和配置。

### ElephantEye 引擎
- **版本**：3.3
- **许可证**：LGPL v2.1（重要：ucci.h/ucci.cpp 例外，可无限制使用）
- **下载地址**：https://www.xqbase.com/
- **特性**：
  - 内置开局库（BOOK.DAT）
  - 支持 UCCI 协议
  - 搜索深度可调
  - 支持多线程
- **配置方法**：将下载的引擎文件放置在 `engines/eleeye/` 目录

### Pikafish 引擎
- **下载地址**：https://github.com/official-pikafish/Pikafish
- **许可证**：GPL v3
- **特性**：
  - NNUE 神经网络评估
  - 高性能搜索
  - 支持 UCI 协议
- **配置方法**：将下载的引擎文件放置在 `engines/pikafish/` 目录

详细的引擎配置说明请参见程序内的设置菜单。

## 新功能

- ✅ 完整的中国象棋规则实现
- ✅ 集成 AI 引擎支持
- ✅ 棋谱记录和分析
- ✅ 国际化支持（中英文）
- ✅ 多种皮肤样式
- ✅ 声音效果
- ✅ 统一日志系统
- ✅ 跨平台支持（Linux/Windows）

## 许可证

### 主项目
- **许可证**：Public Domain (CC0 1.0 Universal)
- **说明**：主代码（作者原创部分）已发布为 Public Domain
- **权利**：任何人都可以自由使用、修改、分发（包括商业用途）

### 第三方代码
- **ElephantEye 引擎**：LGPL v2.1（含重要例外）
- **Pikafish 引擎**：GPL v3
- **Harbour 编译器**：Harbour 许可证
- **HwGUI 库**：Harbour 许可证

完整的许可证信息请参见各发布包中的 LICENSE 文件。

## 技术信息

### 编译信息
- **编译器**：Harbour 3.2.0dev
- **GUI 库**：HwGUI
- **C 编译器**：
  - Linux: GCC 14.2.0
  - Windows: MinGW64 ucrt64 (GCC 14)
- **静态链接**：包含所有必需的库文件

### 系统要求
- **Linux**：
  - GTK+ 2.0
  - glibc 2.17+
- **Windows**：
  - Windows 10/11 x64
  - 无需运行时库

## 已知问题

无

## 更新日志

### 版本 {VERSION}
- 🎉 首次发布
- ✅ 完整的 GUI 功能
- ✅ AI 引擎集成
- ✅ 跨平台支持
- ✅ 许可证问题解决（CC0）

## 支持

### 文档
- 项目 README
- 代码注释
- 设计文档

### 问题反馈
请在 GitHub Issues 中报告问题。

## 致谢

- **ElephantEye 引擎**：感谢 www.xqbase.com 提供的象棋引擎
- **Harbour 项目**：感谢 Harbour 社区
- **HwGUI 项目**：感谢 HwGUI 社区
- **Pikafish 引擎**：感谢 Stockfish 团队

## 许可证冲突解决

### 问题
原许可证（CC BY-NC-SA 4.0）与 ElephantEye 引擎的 LGPL v2.1 许可证冲突：
- CC BY-NC-SA：禁止商业用途，要求相同方式共享
- LGPL v2.1：允许商业用途，允许闭源

### 解决方案
将主项目许可证更改为 **Public Domain (CC0 1.0 Universal)**：
- ✅ 与 LGPL v2.1 完全兼容
- ✅ 给予用户最大自由
- ✅ 无任何许可证冲突

### 影响
- 用户可以自由使用（包括商业用途）
- 无需归属
- 可以闭源
- 无任何法律限制

## 源代码

完整的源代码可在 GitHub 仓库中找到：
- 主分支：master
- 所有源代码包含在源代码包中

## 许可证声明

本项目使用以下开源软件：

### ElephantEye 引擎
- **版权**：Copyright (C) 2004-2012 www.xqbase.com
- **许可证**：GNU Lesser General Public License v2.1
- **重要例外**：ucci.h/ucci.cpp 不在 LGPL 下，可无限制使用
- **官网**：https://www.xqbase.com/

### Harbour 编译器
- **许可证**：Harbour License
- **官网**：https://harbour.github.io/

### HwGUI 库
- **许可证**：Harbour License
- **官网**：https://github.com/hwgui/hwgui

## 免责声明

本软件按"原样"提供，不提供任何明示或暗示的保证，包括但不限于适销性、适用性或非侵权性的保证。在任何情况下，作者或版权持有人都不对任何索赔、损害或其他责任负责。

---

**享受游戏！🎮**