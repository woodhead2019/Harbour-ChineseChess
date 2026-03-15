# ElephantEye Harbour 绑定

本项目为 **ElephantEye 象棋引擎** 提供了 Harbour (Clipper/xBase 兼容语言) 绑定接口，允许 Harbour 程序直接调用 ElephantEye 引擎功能。

## ElephantEye 引擎版权声明

本项目使用的 **ElephantEye 引擎** 遵循 **GNU Lesser General Public License v2.1 (LGPL v2.1)** 许可证。

### 引擎信息

- **引擎名称**：ElephantEye (象眼)
- **版权所有**：Copyright (C) 2004-2012 www.xqbase.com
- **许可证**：GNU Lesser General Public License v2.1 (LGPL v2.1)
  - **重要例外**：ucci.h/ucci.cpp 部分不在 LGPL 下发布，可以无限制使用
- **官方网站**：https://www.xqbase.com/
- **GitHub 仓库**：https://github.com/xqbase/eleeye
- **作者**：www.xqbase.com (Morning Yellow)

### 包含的 ElephantEye 代码

本项目的 `base/` 和 `eleeye/` 目录包含以下 ElephantEye 引擎源代码：

```
base/
  ├── base2.h
  ├── base.h
  ├── parse.h
  ├── pipe.h
  └── pipe.cpp

eleeye/
  ├── ucci.cpp, ucci.h (NOT under LGPL, can be used without restriction)
  ├── pregen.cpp, pregen.h
  ├── position.cpp, position.h
  ├── hash.cpp, hash.h
  ├── search.cpp, search.h
  ├── book.cpp, book.h
  ├── evaluate.cpp, evaluate.h
  ├── genmoves.cpp, genmoves.h
  ├── preeval.cpp, preeval.h
  ├── movesort.cpp, movesort.h
  └── eleeye_hb.cpp (Harbour 接口)
```

**重要说明**：根据 ucci.cpp 源代码中的声明，ucci.h/ucci.cpp 部分不在 LGPL 下发布，可以无限制使用。其他文件遵循 LGPL v2.1。

### 许可证文件

完整的 LGPL v2.1 许可证文本请参见：
- 本项目中的 `LICENSE.ELEPHANTEYE` 文件
- 或访问：https://www.gnu.org/licenses/lgpl-2.1.html

## 项目结构

```
eleeye_hb/
├── base/                   # ElephantEye 基础代码
├── eleeye/                 # ElephantEye 引擎核心代码
│   └── eleeye_hb.cpp       # Harbour 接口实现
├── lib/
│   ├── linux/gcc/libeleeye.a     # Linux 静态库
│   └── win/mingw64/libeleeye.a   # Windows 静态库
├── obj/
│   ├── linux/                    # Linux 对象文件
│   └── win/                      # Windows 对象文件
├── Makefile.libhb          # Linux 编译脚本
├── Makefile.libhb.win      # Windows 编译脚本
├── test.prg                # 测试程序
├── test.hbp                # Linux 测试配置
├── test.win.hbp            # Windows 测试配置
├── eleeye_hb_readme.md     # 详细使用说明
└── LICENSE.ELEPHANTEYE     # ElephantEye 许可证
```

## 编译说明

### Linux 版本

```bash
cd eleeye_hb
make -f Makefile.libhb
```

生成的静态库：`lib/linux/gcc/libeleeye.a`

### Windows 版本

```bash
cd eleeye_hb
make -f Makefile.libhb.win
```

生成的静态库：`lib/win/mingw64/libeleeye.a`

## 使用示例

### Harbour 程序示例

```harbour
#include "hb.ch"

FUNCTION Main()
   LOCAL nResult, cResponse

   // 初始化引擎
   nResult := ELEngine_InitString()
   IF nResult == 0
      OutErr("引擎初始化失败！" + hb_eol())
      RETURN NIL
   ENDIF

   // 设置初始位置
   cResponse := ELEngine_ProcessString("position startpos" + hb_eol())
   
   // 获取最佳走法（深度 3）
   cResponse := ELEngine_ProcessString("go depth 3" + hb_eol())
   OutErr("最佳走法: " + cResponse + hb_eol())

   // 清理
   ELEngine_CleanupString()

RETURN NIL
```

### 编译 Harbour 程序

```bash
cd eleeye_hb
hbmk2 test.hbp
```

## LGPL v2.1 权利和义务

### 您的权利

1. 可以复制和分发本软件的副本
2. 可以修改本软件
3. 可以将本软件与您的程序链接（包括商业程序）
4. 可以收取分发费用

### 您的义务

1. 必须保留原始版权声明和许可证
2. 如果分发修改版本，必须说明修改内容
3. 如果分发可执行文件，必须提供：
   - 完整的源代码，或
   - 书面承诺提供源代码（至少3年有效期），或
   - 使用合适的共享库机制

## 致谢

感谢 **ElephantEye Team** 开发了如此优秀的象棋引擎！

## 技术支持

- ElephantEye 官方网站：https://www.xqbase.com/
- ElephantEye GitHub：https://github.com/xqbase/eleeye
- UCCI 协议文档：参见 ElephantEye 官方网站

## 版本信息

- **当前版本**：1.0
- **最后更新**：2026-03-15
- **Harbour 版本**：3.2.0dev
- **ElephantEye 版本**：基于官方最新版本