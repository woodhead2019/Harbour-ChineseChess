# 中国象棋项目 - hbmk2 构建指南

## 概述

**快速参考**: 查看快速参考卡 [QUICK_REFERENCE.txt](./QUICK_REFERENCE.txt) 获取常用命令速查。

本项目现在支持使用 Harbour 官方构建工具 `hbmk2` 进行构建，这是 Harbour 项目的标准构建工具，功能强大且跨平台。

## 快速开始

### 使用构建脚本（推荐）

```bash
# 构建 Linux GUI 版本（默认）
./build.sh

# 构建 Linux 控制台版本
./build.sh console

# 构建 Linux 所有版本
./build.sh all linux

# 构建 Windows 所有版本（交叉编译）
./build.sh windows

# 清理构建文件
./build.sh clean
```

### 直接使用 hbmk2

#### Linux 版本

```bash
# 构建 GUI 版本
/opt/harbour/bin/hbmk2 xiangqi.hbp

# 构建控制台版本
/opt/harbour/bin/hbmk2 xiangqi_console.hbp
```

#### Windows 版本（Mingw64 交叉编译）

```bash
# 设置环境变量
export PATH=$PATH:/opt/mingw64/bin
export HB_TARGET=x86_64-windows-gnu
export HB_CPU=x86_64
export HB_HOST_BIN=/opt/harbour/bin
export HB_PLATFORM=win
export HB_COMPILER=mingw64

# 构建 GUI 版本
/opt/harbour/bin/hbmk2 -plat=win -comp=mingw64 xq.hbp

# 构建控制台版本
/opt/harbour/bin/hbmk2 -plat=win -comp=mingw64 xq_con.hbp
```

## 文件说明

### 项目配置文件

#### Linux 配置

- **xiangqi.hbp** - Linux GUI 版本构建配置
- **xiangqi_console.hbp** - Linux 控制台版本构建配置
- **hwgui_local.hbc** - Linux HwGUI 库配置

#### Windows 配置（Mingw64 编译器）

- **xq.hbp** - Windows GUI 版本构建配置（通过环境变量）
- **xq_con.hbp** - Windows 控制台版本构建配置（通过环境变量）
- **xq.hbc** - HwGUI 配置

### 辅助文件

- **build.sh** - 构建脚本（简化构建过程）

### 输出文件

#### Linux 版本

- **xiangqiw** - Linux GUI 版本可执行文件
- **xiangqi** - Linux 控制台版本可执行文件

#### Windows 版本

- **xiangqiw.exe** - Windows GUI 版本可执行文件（约 2.4MB）
- **xiangqi.exe** - Windows 控制台版本可执行文件（约 1.7MB）

## hbmk2 常用命令

### 基本构建

```bash
# 标准构建
hbmk2 xiangqi.hbp

# 清理构建文件
hbmk2 -clean xiangqi.hbp

# 增量构建（只编译修改过的文件）
hbmk2 -inc xiangqi.hbp
```

### 调试和优化

```bash
# 显示详细编译信息
hbmk2 -trace xiangqi.hbp

# 只显示命令，不执行
hbmk2 -traceonly xiangqi.hbp

# 添加调试信息
hbmk2 -debug xiangqi.hbp

# 禁用优化
hbmk2 -optim- xiangqi.hbp
```

### 编译器选项

```bash
# 静态链接
hbmk2 -static xiangqi.hbp

# 指定输出文件名
hbmk2 -ooutput xiangqi.hbp
```

### 交叉编译选项

```bash
# Windows 平台（Mingw64 交叉编译）
hbmk2 -plat=win -comp=mingw64 xq.hbp

# 指定 CPU 架构
hbmk2 -cpu=x86_64 xiangqi.hbp

# Windows UNICODE 模式
hbmk2 -winuni xiangqi_windows_zig.hbp
```

## .hbp 文件语法

### 基本结构

```
# 注释以 # 开头

# 输出文件名
-oxiangqiw

# GUI/控制台应用程序
-gui    # GUI 应用
-std    # 控制台应用

# Windows UNICODE 模式
-winuni

# 包含库配置
hwgui_local.hbc

# 源文件列表
xiangqiw.prg
xq_funcs.prg
...
```

### Windows 交叉编译示例

```
# Windows GUI 版本（Mingw64 交叉编译）
-oxiangqiw
-gui
-winuni
-L/opt/harbour/lib/win/mingw64
-L/opt/hwgui/lib/win/mingw64
hwgui_windows.hbc
xiangqiw.prg
xq_funcs.prg
...
```

### 常用选项

| 选项 | 说明 |
|------|------|
| `-o<name>` | 输出文件名 |
| `-gui` | 创建 GUI 应用程序 |
| `-std` | 创建控制台应用程序 |
| `-winuni` | Windows UNICODE 模式 |
| `-plat=<platform>` | 目标平台（win, linux 等） |
| `-comp=<compiler>` | 编译器（zig, gcc, mingw64 等） |
| `-cpu=<arch>` | CPU 架构（x86_64, x86 等） |
| `-static` | 静态链接 |
| `-debug` | 添加调试信息 |
| `-inc` | 增量构建模式 |
| `-clean` | 清理构建文件 |
| `-trace` | 显示详细编译信息 |
| `-mt` | 多线程模式 |
| `-shared` | 动态链接 |
| `-L<dir>` | 添加库搜索路径 |

### .hbc 文件语法

```
# 包含路径
incpaths=include

# 库路径
libpaths=lib

# 库文件
libs=hwgui procmisc hbxml

# C 编译器标志
CFLAGS=-DHWG_USE_POINTER_ITEM

# Harbour 编译器标志
PRGFLAGS=-q -m -n -es2

# 链接器标志
ldflags=-lgtk-x11-2.0 -lgdk-x11-2.0
```

### Windows .hbc 示例

```
# Windows HwGUI 配置（Mingw64 编译器）
incpaths=/home/woodhead/cchess/hwgui-source/include

libpaths=/opt/hwgui/lib/win/mingw64
libpaths+=/opt/harbour/lib/win/mingw64

libs=hwgui procmisc hbxml

gt=gtgui

PRGFLAGS=-q -m -n -es2 -DUNICODE

CFLAGS=-DUNICODE -DHWG_USE_POINTER_ITEM

ldflags=-luser32 -lgdi32 -lcomctl32 -lcomdlg32 -lshell32 -lwinmm -lgdiplus
```

## 与 hwbc 的区别

### hbmk2 优势

1. **官方支持**：Harbour 项目的标准构建工具
2. **功能强大**：支持更多特性和编译器选项
3. **跨平台**：统一的构建配置，支持多个平台
4. **增量编译**：自动检测修改，只编译必要的文件
5. **更好的错误报告**：更清晰的错误信息
6. **交叉编译支持**：内置支持多种交叉编译器

### 迁移要点

1. **配置文件**：从 .hwprj 改为 .hbp 格式
2. **语法更简洁**：.hbp 语法更直观
3. **库引用**：使用 .hbc 文件包含库配置
4. **编译器标志**：统一的编译选项格式
5. **平台分离**：使用不同的 .hbp 文件支持不同平台

## 系统要求

### 必需

- Harbour 编译器（3.2.0dev 或更高版本）
- HwGUI 库
- GTK+ 2.0 开发库（仅 Linux GUI 版本）
- Mingw64 编译器（仅 Windows 交叉编译）

### 安装 GTK+ 2.0（Debian/Ubuntu）

```bash
sudo apt-get install libgtk2.0-dev
```

### 安装 GTK+ 2.0（Fedora/RHEL）

```bash
sudo dnf install gtk2-devel
```

### Mingw64 编译器（Windows 交叉编译）

Mingw64 编译器应该安装在 `/opt/mingw64`。

### 库路径配置

- **Harbour Mingw64 库**: `/opt/harbour/lib/win/mingw64`
- **HwGUI Mingw64 库**: `/opt/hwgui/lib/win/mingw64`

## GT 库声明

GUI 程序必须正确声明 GT 库：

```harbour
// xiangqiw.prg
REQUEST HB_CODEPAGE_UTF8
REQUEST HB_GT_GUI
REQUEST HB_GT_GUI_DEFAULT
```

**重要**：不要使用 `HB_GT_HWGUI`，已改为 `HB_GT_GUI`。

## 故障排除

### 找不到 hbmk2

```bash
# 检查 hbmk2 路径
ls /opt/harbour/bin/hbmk2

# 或修改 build.sh 中的路径
```

### 找不到 HwGUI 库

```bash
# 检查 Linux 库文件
ls /opt/hwgui/lib/linux/gcc/

# 检查 Windows 库文件
ls /opt/hwgui/lib/win/mingw64/

# 确认 .hbc 文件中的路径正确
```

### GTK+ 2.0 未安装

```bash
# Debian/Ubuntu
sudo apt-get install libgtk2.0-dev

# 验证安装
pkg-config --libs gtk+-2.0
```

### Mingw64 编译器未找到

```bash
# 检查 Mingw64 安装
ls /opt/mingw64/bin/x86_64-w64-mingw32-gcc

# 检查环境变量
echo $PATH
```

### HB_GT_HWGUI 符号未定义

检查 `xiangqiw.prg` 中的 REQUEST 语句：

```harbour
// 正确
REQUEST HB_GT_GUI
REQUEST HB_GT_GUI_DEFAULT

// 错误
// REQUEST HB_GT_HWGUI
// REQUEST HB_GT_HWGUI_DEFAULT
```

## 参考资源

- [hbmk2 官方文档](https://harbour.github.io/doc/hbmk2/)
- [HwGUI 官方文档](https://github.com/alkresin/hwgui)
- [Harbour 编程手册](https://harbour.github.io/doc/)



---

**版本**: v1.0.0  
**最后更新**: 2026-03-08