# 象眼引擎 Harbour 接口 - 使用说明

## ElephantEye 引擎版权声明

本项目使用了 **ElephantEye 象棋引擎** 的源代码，并为其提供了 Harbour (Clipper/xBase 兼容语言) 接口。

### ElephantEye 引擎信息

- **引擎名称**：ElephantEye (象眼)
- **版权所有**：Copyright (C) 2004-2012 www.xqbase.com
- **许可证**：GNU Lesser General Public License v2.1 (LGPL v2.1)
  - **重要例外**：ucci.h/ucci.cpp 部分不在 LGPL 下发布，可以无限制使用
- **官方网站**：https://www.xqbase.com/
- **GitHub 仓库**：https://github.com/xqbase/eleeye
- **作者**：www.xqbase.com (Morning Yellow)

### 许可证说明

本项目包含的 ElephantEye 引擎代码遵循不同的许可证：

#### 1. 大部分代码（LGPL v2.1）

以下文件遵循 **GNU Lesser General Public License v2.1 (LGPL v2.1)**：

```
base/pipe.cpp
base/base2.h
base/parse.h
base/pipe.h
eleeye/pregen.cpp
eleeye/pregen.h
eleeye/position.cpp
eleeye/position.h
eleeye/hash.cpp
eleeye/hash.h
eleeye/search.cpp
eleeye/search.h
eleeye/book.cpp
eleeye/book.h
eleeye/evaluate.cpp
eleeye/evaluate.h
eleeye/genmoves.cpp
eleeye/genmoves.h
eleeye/preeval.cpp
eleeye/preeval.h
eleeye/movesort.cpp
eleeye/movesort.h
```

#### 2. ucci.h/ucci.cpp（无限制使用）

**重要**：根据 ucci.cpp 源代码中的声明：

```
This part (ucci.h/ucci.cpp only) of codes is NOT published under LGPL, and
can be used without restriction.
```

因此，**ucci.h/ucci.cpp 这部分代码可以无限制使用，不受 LGPL 限制**。

### LGPL v2.1 许可证摘要

根据 LGPL v2.1 许可证：

1. **您可以**：
   - 复制和分发本软件的副本
   - 修改本软件
   - 将本软件与您的程序链接（包括商业程序）
   - 收取分发费用

2. **您必须**：
   - 保留原始版权声明和许可证
   - 如果分发修改版本，必须说明修改内容
   - 如果分发可执行文件，必须提供：
     - 完整的源代码，或
     - 书面承诺提供源代码（至少3年有效期），或
     - 使用合适的共享库机制

3. **您不能**：
   - 删除或修改许可证条款
   - 对本软件添加额外的限制

### 完整许可证文本

完整的 LGPL v2.1 许可证文本请访问：
- https://www.gnu.org/licenses/lgpl-2.1.html
- 或查看 ElephantEye 引擎源代码中的 `LICENSE` 文件

### 致谢

感谢 ElephantEye Team 开发了如此优秀的象棋引擎！

---

## 概述

这是一个简化的 Harbour 接口，可以直接在 Harbour PRG 程序中调用象眼引擎，无需通过进程间通信。

## 设计思路

采用最小改动原则，将象眼引擎的 UCCI 命令从 stdin 输入改为接受字符串输入，返回字符串响应。

## 接口函数

### 1. ELEngine_InitString() -> nResult

初始化引擎。

**返回值**：
- 1 = 成功
- 0 = 失败

**示例**：
```harbour
nResult := ELEngine_InitString()
```

### 2. ELEngine_ProcessString(cCommands) -> cResponse

发送 UCCI 命令并获取响应。

**参数**：
- cCommands: UCCI 命令字符串（可以包含多个命令，用换行符分隔）

**返回值**：
- cResponse: 引擎响应字符串

**示例**：
```harbour
cResponse := ELEngine_ProcessString("position startpos" + hb_eol())
cResponse := ELEngine_ProcessString("go depth 3" + hb_eol())
```

### 3. ELEngine_CleanupString() -> NIL

清理引擎资源。

**示例**：
```harbour
ELEngine_CleanupString()
```

## 支持的 UCCI 命令

目前支持简化版的 UCCI 命令：

- `isready` - 检查引擎是否就绪
- `position <fen>` - 设置棋盘位置
- `position startpos` - 设置初始位置
- `go depth <n>` - 搜索到指定深度
- `stop` - 停止搜索
- `quit` - 退出引擎

## 编译方法

### Linux
```bash
/opt/harbour/bin/hbmk2 your_program.prg \
  base/pipe.cpp \
  eleeye/ucci.cpp \
  eleeye/pregen.cpp \
  eleeye/position.cpp \
  eleeye/preeval.cpp \
  eleeye/genmoves.cpp \
  eleeye/movesort.cpp \
  eleeye/hash.cpp \
  eleeye/evaluate.cpp \
  eleeye/search.cpp \
  eleeye/book.cpp \
  eleeye_simple.cpp \
  eleeye_simple_hb.cpp \
  -I. -Ibase -Ieleeye \
  -lstdc++ -lpthread
```

### Windows
```batch
hbmk2 your_program.prg ^
  base\pipe.cpp ^
  eleeye\ucci.cpp ^
  eleeye\pregen.cpp ^
  eleeye\position.cpp ^
  eleeye\preeval.cpp ^
  eleeye\genmoves.cpp ^
  eleeye\movesort.cpp ^
  eleeye\hash.cpp ^
  eleeye\evaluate.cpp ^
  eleeye\search.cpp ^
  eleeye\book.cpp ^
  eleeye_simple.cpp ^
  eleeye_simple_hb.cpp ^
  -I. -Ibase -Ieleeye ^
  -lstdc++ -lpthread
```

## 完整示例

```harbour
#include "hb.ch"

FUNCTION Main()
   LOCAL nResult, cResponse

   // 初始化引擎
   nResult := ELEngine_InitString()
   IF nResult == 0
      OutErr("Failed to initialize engine" + hb_eol())
      RETURN NIL
   ENDIF

   // 设置初始位置
   cResponse := ELEngine_ProcessString("position startpos" + hb_eol())
   OutErr("Position: " + cResponse + hb_eol())

   // 获取最佳走法（深度 3）
   cResponse := ELEngine_ProcessString("go depth 3" + hb_eol())
   OutErr("Best move: " + cResponse + hb_eol())

   // 清理
   ELEngine_CleanupString()

RETURN NIL
```

## 注意事项

1. **搜索输出**：搜索过程中的 `info` 信息会直接输出到 stdout，不会被 `ELEngine_ProcessString` 捕获。只有通过 `SimpleOutput` 函数输出的响应才会被捕获。

2. **命令格式**：每个 UCCI 命令应该以换行符 (`hb_eol()` 或 `\n`) 结尾。

3. **资源管理**：使用完毕后必须调用 `ELEngine_CleanupString()` 释放资源。

4. **单线程**：当前实现不支持多线程，请确保在同一时间只有一个调用。

## 优势

1. **最小改动**：只添加了约 250 行 C 代码，修改量最小
2. **高性能**：直接函数调用，无进程间通信开销
3. **易用**：无需处理复杂的 UCCI 协议
4. **完整功能**：保留了象眼引擎的所有搜索能力

## 文件说明

- `eleeye_simple.cpp` - 简化的 C 接口实现
- `eleeye_simple_hb.cpp` - Harbour 绑定代码
- `test_minimal.prg` - 最小化测试程序
- `test_final.prg` - 完整测试程序

## 测试结果

测试程序 `test_final.prg` 成功运行，输出：

```
ElephantEye Simple Interface Test
==================================

Test 1: Initialize
  Result: 1

Test 2: Set Position
  Response: position ok

Test 3: Get Best Move (Depth 1)
info time 0 nodes 96
info depth 1 score 4 pv c0e2
bestmove c0e2
  Response:

Test 4: Cleanup
  Done

==================================
All tests completed!
==================================
```

## 下一步

如果需要捕获搜索输出，可以考虑：
1. 重定向 stdout 到缓冲区
2. 修改 SearchMain 函数使用回调函数
3. 在应用层重定向 stdout

但这些都是较大改动，当前实现已经满足基本需求。