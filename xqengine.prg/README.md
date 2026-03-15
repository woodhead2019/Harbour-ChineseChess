# XQEngine - 中国象棋引擎管理器

## 项目概述

XQEngine 是一个使用 Harbour 编程语言开发的中国象棋引擎封装库，提供了统一的接口来管理和调用中国象棋引擎。项目支持 UCCI（中国象棋引擎协议）和 UCI（通用棋类引擎协议）两种协议，并实现了协议自动检测功能。

**项目信息：**
- 项目名称：XQEngine（中国象棋引擎管理器）
- 编程语言：Harbour 3.2.0dev
- 许可证：CC0-1.0（公共领域）
- 测试引擎：Pikafish dev-20260301-981613de
- 测试环境：Termux on Android、Linux 桌面

**核心功能：**
- 引擎生命周期管理（启动/停止/重启）
- UCCI 和 UCI 协议支持
- 协议自动检测（先尝试 UCI，失败后回退到 UCCI）
- 同步和异步非阻塞调用
- 引擎状态监控
- 完整的错误处理系统
- 引擎配置管理
- 特殊局面处理（将死、困毙检测）
- 超时处理和自动停止
- 完整的 Pikafish 功能支持（100%）

**主要特性：**
- MultiPV 模式（1-128 候选着法）
- Ponder 思考模式
- WDL 概率估计
- NNUE 神经网络评估
- 精确时间控制（棋钟支持）
- 杀棋搜索（mate 参数）
- 节点数限制
- 深度限制
- 无限搜索模式

## 目录

- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [核心模块说明](#核心模块说明)
- [技术方案](#技术方案)
- [功能支持度](#功能支持度)
- [开发指南](#开发指南)
- [使用示例](#使用示例)
- [API 参考](#api-参考)
- [常见问题](#常见问题)
- [版本历史](#版本历史)
- [贡献指南](#贡献指南)

## 项目结构

```
xqengine/
├── xqengine/                        # 核心源代码目录
│   ├── xqengine_core.prg            # 核心引擎管理类
│   ├── xqengine_engineconfig.prg    # 引擎配置类
│   ├── xqengine_enginestate.prg     # 引擎状态类
│   ├── xqengine_ucci_protocol.prg   # UCCI 协议处理
│   ├── xqengine_uci_protocol.prg    # UCI 协议处理
│   ├── xqengine_goparams.prg        # Go 命令参数类
│   ├── xqengine_utils.prg           # 工具函数
│   ├── xqengine_errsys.prg          # 错误处理系统
│   ├── xqengine_constants.ch        # 常量定义
│   ├── xqengine_common.ch           # 公共头文件
│   ├── xqengine.hbp                 # 核心库构建配置
│   ├── pikafish                     # Pikafish 引擎可执行文件
│   └── pikafish.nnue                # 神经网络权重文件
├── demo.prg                         # 综合演示程序
├── demo.hbp                         # 综合演示构建配置
├── CHANGELOG.md                     # 更新日志
├── README.md                        # 本文件
└── pikafish支持度分析.md            # Pikafish 功能支持度分析
```

## 快速开始

### 环境要求

- Harbour 编译器 3.2.0dev 或更高版本
- hbmk2 构建工具
- Termux/Android 或 Linux 环境
- Pikafish 引擎（已包含在项目中）

### 构建和运行

```bash
# 构建演示程序
hbmk2 demo.hbp

# 运行演示程序
./demo
```

构建后生成的文件：
- `demo` - 演示程序可执行文件
- `build_info.ch` - 构建信息头文件（自动生成）
- `vcs_info.ch` - 版本控制信息头文件（自动生成）

### 基本使用

```harbour
#include "hbclass.ch"
#include "xqengine_constants.ch"

PROCEDURE Main()
   LOCAL oEngine
   LOCAL cBestMove

   // 创建引擎实例
   oEngine := XQEngine():New()

   // 初始化引擎
   oEngine:Initialize( "./pikafish" )

   // 启动引擎
   IF oEngine:Start()
      // 等待引擎初始化
      hb_idleSleep( 2.0 )

      // 分析开局局面
      cBestMove := oEngine:Analyze( "startpos", 3000, 0 )
      ? "最佳走法:", cBestMove

      // 停止引擎
      oEngine:Close()
   ENDIF

   RETURN
```

## 核心模块说明

### xqengine_core.prg

核心引擎管理类 `XQEngine`，提供以下功能：
- 引擎生命周期管理
- UCCI/UCI 协议通信
- 进程 I/O 管理
- 异步思考支持
- 协议自动检测

**重要提示：**
- 使用 `hb_processOpen()` 时必须使用正确的参数顺序：
  - ✅ 正确：`hb_processOpen( cCommand, @hStdIn, @hStdOut, @hStdErr )`
  - ❌ 错误：`hb_processOpen( cCommand, , @hStdOut, @hStdErr )`
- stdin 句柄必须通过第二个参数获取，不能使用 `hStdIn := hProc`

### xqengine_engineconfig.prg

引擎配置类 `EngineConfig`，管理引擎参数：
- 引擎基本信息（名称、路径、版本、作者）
- 引擎参数（Hash 大小、线程数、开局库、残局库）
- 搜索参数（默认深度、默认时间、最大节点数）
- 调试选项（调试模式、详细输出）

### xqengine_enginestate.prg

引擎状态类，跟踪引擎运行状态：
- 引擎状态（停止/启动/运行/思考/错误）
- 命令和响应统计
- 错误计数
- 运行时间统计

### xqengine_ucci_protocol.prg

UCCI 协议处理类，实现 UCCI 协议：
- 初始化序列（`ucci` 命令）
- 状态检查（`isready` 命令）
- 局面设置（`position` 命令）
- 思考控制（`go`/`stop` 命令）
- 退出（`quit` 命令）

### xqengine_uci_protocol.prg

UCI 协议处理类，实现 UCI 协议：
- 初始化序列（`uci` 命令）
- 状态检查（`isready` 命令）
- 局面设置（`position` 命令）
- 思考控制（`go`/`stop` 命令）
- 退出（`quit` 命令）

### xqengine_goparams.prg

Go 命令参数类，封装所有 go 命令参数：
- 搜索参数（depth, movetime, nodes）
- 棋钟参数（wtime, btime, winc, binc, movestogo）
- 特殊模式（infinite, mate）

### xqengine_utils.prg

工具函数模块，提供通用功能：
- 字符串处理
- 数据验证
- 格式转换

### xqengine_errsys.prg

错误处理系统，提供：
- 结构化错误报告
- JSON 格式错误输出
- 调用堆栈跟踪
- 错误日志记录
- AI 友好的错误信息

## 技术方案

### 不阻塞调用架构

XQEngine 采用多线程 + 异步进程管理的架构，确保主程序在引擎思考过程中不被阻塞：

```
┌─────────────────────────────────────────────────────────────┐
│                     Harbour 主程序                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              用户界面层 (GUI/CLI)                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              引擎管理器 (Engine Manager)               │  │
│  │  - 引擎生命周期管理                                     │  │
│  │  - 状态监控                                            │  │
│  │  - 任务队列                                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              消息队列 (Message Queue)                  │  │
│  │  - 使用 hb_mutexNotify/Subscribe 实现                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                  │
│  ┌──────────────┬──────────────┬──────────────┐          │
│  │  引擎线程 1   │  引擎线程 2   │  引擎线程 N   │          │
│  │  (Worker)    │  (Worker)    │  (Worker)    │          │
│  └──────────────┴──────────────┴──────────────┘          │
│           ↓                  ↓                  ↓         │
│  ┌──────────────┬──────────────┬──────────────┐          │
│  │  Pikafish    │  Pikafish    │  其他引擎     │          │
│  │  进程 1      │  进程 2      │  进程 N       │          │
│  └──────────────┴──────────────┴──────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### 协议支持

#### UCCI 协议

UCCI (Universal Chinese Chess Interface) 是专为中国象棋设计的协议。

**核心命令：**

1. **初始化序列**
```
界面 → 引擎: ucci
引擎 → 界面: id name Pikafish 2025-06-27
引擎 → 界面: id copyright GPL-3.0
引擎 → 界面: id author Official Pikafish Team
引擎 → 界面: option usemillisec type check default true
引擎 → 界面: option hashsize type spin min 0 max 65536 default 64
引擎 → 界面: option threads type spin min 1 max 1024 default 1
引擎 → 界面: ucciok
```

2. **状态检查**
```
界面 → 引擎: isready
引擎 → 界面: readyok
```

3. **设置局面**
```
界面 → 引擎: position fen rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1
或
界面 → 引擎: position startpos moves h2e2 h7e7
```

4. **开始思考**
```
界面 → 引擎: go time 5000
引擎 → 界面: info depth 10 score 120 pv h2e2 h9e7
引擎 → 界面: info depth 12 score 150 pv h2e2 h9e7 c3e3
引擎 → 界面: bestmove h2e2 ponder h9e7
```

5. **停止思考**
```
界面 → 引擎: stop
引擎 → 界面: bestmove h2e2
```

6. **退出**
```
界面 → 引擎: quit
引擎 → 界面: bye
```

#### UCI 协议

UCI (Universal Chess Interface) 是国际象棋引擎的通用接口协议，也被许多中国象棋引擎采用。

**核心命令：**

1. **初始化序列**
```
界面 → 引擎: uci
引擎 → 界面: id name Pikafish dev-20260301-981613de
引擎 → 界面: id author the Pikafish developers
引擎 → 界面: option name Debug Log File type string default <empty>
引擎 → 界面: option name Threads type spin default 1 min 1 max 1024
引擎 → 界面: option name Hash type spin default 16 min 1 max 33554432
引擎 → 界面: uciok
```

2. **状态检查**
```
界面 → 引擎: isready
引擎 → 界面: readyok
```

3. **设置局面**
```
界面 → 引擎: position fen rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1
或
界面 → 引擎: position startpos
```

4. **开始思考**
```
界面 → 引擎: go time 3000
引擎 → 界面: info depth 10 score cp 120 nodes 1000000 nps 1000000
引擎 → 界面: info depth 12 score cp 150 nodes 2000000 nps 1000000 pv h2e2 h9e7
引擎 → 界面: bestmove h2e2 ponder h9e7
```

5. **停止思考**
```
界面 → 引擎: stop
引擎 → 界面: bestmove h2e2
```

6. **退出**
```
界面 → 引擎: quit
```

**UCCI vs UCI 对比：**

| 特性 | UCCI | UCI |
|------|------|-----|
| 适用棋种 | 专为中国象棋设计 | 国际象棋（但中国象棋也支持） |
| 初始化命令 | `ucci` | `uci` |
| 局面格式 | 中国象棋 FEN | 标准 FEN 格式 |
| 命令复杂性 | 较复杂 | 较简单 |
| 引擎支持 | 旋风、部分中国象棋引擎 | Pikafish、Stockfish 等通用引擎 |
| 通用性 | 中国象棋专用 | 通用性强 |

#### 协议自动检测

系统支持 UCI 和 UCCI 协议的自动检测：

1. 先发送 `uci` 命令
2. 检查是否收到 `uciok` 响应
3. 如果收到 `uciok`，则使用 UCI 协议
4. 否则尝试 `ucci` 命令

这种设计确保了与 Pikafish（支持 UCI）和旋风（支持 UCCI）等不同引擎的兼容性。

### 异步非阻塞调用

通过以下方式实现异步非阻塞调用：
- 使用 `hb_processOpen` 而非 `hb_processRun`
- 在单独的线程中读取引擎输出
- 使用消息队列进行线程间通信
- 提供回调函数机制处理异步结果

## 功能支持度

### Pikafish 功能支持度

XQEngine 实现了对 Pikafish 的 100% 功能支持：

#### 已完全支持的 UCI 命令

| 命令 | 接口方法 | 说明 |
|------|---------|------|
| `uci` | `UCCI_Init()` | 自动发送并解析引擎信息 |
| `isready` | `UCCI_IsReady()` | 检查引擎就绪状态 |
| `position` | `UCCI_SetPosition()` | 支持 FEN 和 startpos |
| `go` | `UCCI_Go()` | 支持所有参数 |
| `stop` | `UCCI_Stop()` | 停止当前搜索 |
| `setoption` | `SetOption()` | 动态设置引擎参数 |
| `ucinewgame` | `NewGame()` | 开始新游戏 |
| `ponderhit` | `PonderHit()` | Ponder 模式支持 |
| `quit` | `Quit()` | 退出引擎 |

#### 已支持的 Go 命令参数

| 参数 | 说明 |
|------|------|
| `depth` | 深度限制 |
| `movetime` | 时间限制 |
| `nodes` | 节点数限制 |
| `wtime` | 白方剩余时间 |
| `btime` | 黑方剩余时间 |
| `winc` | 白方时间增量 |
| `binc` | 黑方时间增量 |
| `movestogo` | 距离时间控制回合数 |
| `infinite` | 无限搜索 |
| `mate` | 杀棋搜索 |

#### 已支持的 Pikafish 选项

| 选项 | 类型 | 说明 |
|------|------|------|
| DebugLogFile | string | 调试日志文件 |
| NumaPolicy | string | NUMA 策略 |
| Threads | spin | 线程数 |
| Hash | spin | 哈希表大小 |
| ClearHash | button | 清除哈希表 |
| Ponder | check | 思考模式 |
| MultiPV | spin | 多 PV 模式 |
| MoveOverhead | spin | 移动时间开销 |
| NodeTime | spin | 节点时间 |
| UCI_ShowWDL | check | 显示 WDL 概率 |
| EvalFile | string | 神经网络评估文件 |

#### 已实现的高级功能

| 功能 | 接口方法 | 说明 |
|------|---------|------|
| 同步分析 | `Analyze()` | 阻塞式分析 |
| 异步分析 | `AnalyzeAsync()` | 非阻塞式分析 |
| 协议自动检测 | 自动 | UCI/UCCI 自动检测 |
| MultiPV 模式 | `SetMultiPV()`, `GetMultiPV()` | 获取多个候选着法 |
| Ponder 模式 | `SetPonder()`, `GetPonderMove()` | 思考模式 |
| 棋钟控制 | `AnalyzeWithParams()` | 精确的时间控制 |
| WDL 概率 | `GetWDL()` | 胜/平/负概率 |
| NNUE 评估 | `GetNNUEInfo()` | 神经网络评估信息 |
| 回调机制 | `Set*Callback()` | 信息、完成、错误回调 |
| 统计信息 | `GetStatistics()` | 引擎运行统计 |
| 状态监控 | `GetState()` | 引擎状态查询 |
| 特殊局面 | `GetMate()`, `IsStalemate()` | 将死、困毙检测 |

## 开发指南

### 编码约定

#### 命名规范

- **类名**：PascalCase (`XQEngine`, `EngineConfig`, `GoParams`)
- **方法名**：PascalCase (`Initialize`, `Start`, `Analyze`)
- **变量名**：camelCase (`oEngine`, `cBestMove`, `nTimeLimit`)
- **常量**：UPPER_SNAKE_CASE (`ENGINE_STATE_RUNNING`, `UCI_CMD_GO`)
- **文件命名**：`xqengine_<classname>.prg` 用于类文件

#### 代码风格

- 使用面向对象编程（OOP）
- 类和方法使用清晰的注释
- 重要提示使用 `重要提示:` 标记
- 使用 UTF-8 编码

#### 构建配置

- 源文件按依赖顺序排列
- `.hbp` 文件中 `-o` 和 `-i` 参数后不加空格
- 使用 `-gtstd` 指定标准 GUI 终端
- 使用 `-debug` 和 `-optim` 进行调试和优化

### 关键实现细节

#### hb_processOpen 参数顺序（关键）

stdin 句柄必须通过第二个参数获取：

```harbour
// 正确的参数顺序
hProc := hb_processOpen( cCommand, @hStdIn, @hStdOut, @hStdErr )

// 获取 stdin 句柄
hStdIn := hb_processGetStdIn( hProc )

// 向引擎发送命令
FWrite( hStdIn, "uci" + hb_eol() )
```

**注意事项：**
- stdin 句柄必须通过 `hb_processOpen` 的第二个参数获取
- 不能使用 `hStdIn := hProc`，这样不会得到有效的 stdin 句柄
- 在 Termux/Android 环境下需要特别注意参数顺序

#### 协议自动检测实现

```harbour
// 先尝试 UCI
FWrite( hStdIn, "uci" + hb_eol() )

// 等待响应
hb_idleSleep( 0.5 )

// 检查是否收到 uciok
IF "uciok" $ cResponse
   ::nProtocol := PROTOCOL_UCI
ELSE
   // 回退到 UCCI
   FWrite( hStdIn, "ucci" + hb_eol() )
   hb_idleSleep( 0.5 )
   ::nProtocol := PROTOCOL_UCCI
ENDIF
```

### 错误处理

错误处理系统提供三种模式：

```harbour
// 设置错误处理模式
xq_SetErrorMode( ERROR_MODE_RECOVER )  // 默认模式
xq_SetErrorMode( ERROR_MODE_QUIT )     // 传统模式
xq_SetErrorMode( ERROR_MODE_CALLBACK ) // 回调模式

// 设置自定义回调
xq_SetErrorCallback( {| cError | ? "Error:", cError } )

// 安全执行代码块
xq_SafeExec( {|| oEngine:Analyze( cFEN, 3000, 0 ) } )

// 检查错误
IF xq_HasError()
   ? "Last error:", xq_GetLastError()
ENDIF
```

所有错误输出 JSON 格式，便于 AI 分析。

### 常见模式

#### 基本分析

```harbour
oEngine := XQEngine():New()
oEngine:Initialize( "./pikafish" )
IF oEngine:Start()
   hb_idleSleep( 2.0 )  // 等待引擎初始化
   cBestMove := oEngine:Analyze( "startpos", 3000, 0 )  // 3秒时间限制
   oEngine:Close()  // 显式关闭（推荐）
ENDIF
```

#### MultiPV 分析

```harbour
oEngine:SetMultiPV( 3 )  // 获取3个候选着法
cBestMove := oEngine:Analyze( cFEN, 5000, 0 )
aMoves := oEngine:GetMultiPV()  // 返回哈希表，包含走法、评分、PV
```

#### 异步分析

```harbour
// 方法1：轮询进度
oEngine:AnalyzeAsync( cFEN, 5000, 0 )
DO WHILE oEngine:IsAsyncRunning()
   ? "Progress:", oEngine:GetAsyncProgress(), "%"
   ? "Info:", oEngine:GetAsyncInfo()
   hb_idleSleep( 0.1 )
ENDDO
cResult := oEngine:GetAsyncResult()

// 方法2：等待超时（更简单）
oEngine:AnalyzeAsync( cFEN, 5000, 0 )
cResult := oEngine:WaitAsync( 10000 )  // 等待最多10秒
```

## 使用示例

### 高级使用示例

```harbour
// 创建引擎配置
LOCAL oConfig := EngineConfig():New()
oConfig:SetEnginePath( "./pikafish" )
oConfig:SetHashSize( 256 )
oConfig:SetThreads( 4 )
oConfig:SetUseBook( .T. )
oConfig:SetUseEGTB( .T. )

// 创建引擎实例并设置配置
LOCAL oEngine := XQEngine():New()
oEngine:Initialize( "./pikafish" )
oEngine:SetConfig( oConfig )

// 设置回调函数
oEngine:SetInfoCallback( {| cInfo | ? "Info:", cInfo } )
oEngine:SetBestMoveCallback( {| cMove | ? "Best Move:", cMove } )

// 启动引擎
IF oEngine:Start()
   // 分析指定局面
   LOCAL cFEN := "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
   LOCAL cBestMove := oEngine:Analyze( cFEN, 5000, 12 )

   // 获取统计信息
   LOCAL oStats := oEngine:GetStatistics()
   ? "状态:", oStats["state"]
   ? "命令数:", oStats["commandCount"]
   ? "响应数:", oStats["responseCount"]

   // 停止引擎
   oEngine:Close()
ENDIF
```

### 对弈程序示例

```harbour
PROCEDURE ChessGame_Main()
   LOCAL nEngineID, cFEN, cMove, cPlayerMove
   LOCAL lRedTurn := .T.

   // 初始化
   oEngine := XQEngine():New()
   oEngine:Initialize( "./pikafish" )
   oEngine:Start()
   hb_idleSleep( 2 )

   // 初始局面
   cFEN := "startpos"

   DO WHILE .T.
      ? ""
      ? "================================"
      ? "当前局面:", cFEN
      ? ""

      IF lRedTurn
         ? "红方走棋（玩家）"
         ? "请输入着法（ICCS格式，如 h2e2）："
         ACCEPT ">>>" TO cPlayerMove

         IF Lower( cPlayerMove ) == "quit"  // ESC 退出
            EXIT
         ENDIF

         ? "玩家着法:", cPlayerMove
         // 更新局面
      ELSE
         ? "黑方走棋（引擎）"
         ? "正在思考..."

         cMove := oEngine:Analyze( cFEN, 5000, 0 )
         ? "引擎着法:", cMove
         // 更新局面
      ENDIF

      lRedTurn := ! lRedTurn
   ENDDO

   // 清理
   oEngine:Close()

   RETURN
```

## API 参考

### XQEngine 类

#### 引擎生命周期

```harbour
// 初始化引擎
METHOD Initialize( cEnginePath ) -> LOGICAL

// 启动引擎
METHOD Start() -> LOGICAL

// 停止引擎
METHOD Stop() -> LOGICAL

// 重启引擎
METHOD Restart() -> LOGICAL

// 关闭引擎
METHOD Close() -> NIL

// 检查是否已关闭
METHOD IsClosed() -> LOGICAL

// 检查是否运行中
METHOD IsRunning() -> LOGICAL
```

#### 分析功能

```harbour
// 同步分析（推荐使用 Close() 而非 Stop()）
METHOD Analyze( cFEN, nTimeLimit, nDepthLimit ) -> CHARACTER

// 异步分析
METHOD AnalyzeAsync( cFEN, nTimeLimit, nDepthLimit ) -> LOGICAL

// 使用参数对象分析
METHOD AnalyzeWithParams( cFEN, oParams ) -> CHARACTER

// 等待异步操作完成
METHOD WaitAsync( nTimeout ) -> CHARACTER
```

#### 异步控制

```harbour
// 检查异步操作是否运行中
METHOD IsAsyncRunning() -> LOGICAL

// 获取异步结果
METHOD GetAsyncResult() -> CHARACTER

// 取消异步操作
METHOD CancelAsyncOperation() -> LOGICAL

// 设置异步超时
METHOD SetAsyncTimeout( nTimeout ) -> NIL

// 检查异步进度
METHOD CheckAsyncProgress() -> CHARACTER

// 获取异步信息
METHOD GetAsyncInfo() -> CHARACTER

// 设置异步完成回调
METHOD SetAsyncCompleteCallback( bCallback ) -> NIL

// 设置异步错误回调
METHOD SetAsyncErrorCallback( bCallback ) -> NIL
```

#### 配置管理

```harbour
// 设置单个选项
METHOD SetOption( cName, cValue ) -> LOGICAL

// 应用完整配置
METHOD ApplyConfig() -> LOGICAL

// 设置 MultiPV
METHOD SetMultiPV( nPV ) -> LOGICAL

// 设置 Ponder
METHOD SetPonder( lEnable ) -> LOGICAL

// 清除哈希表
METHOD ClearHash() -> LOGICAL

// 开始新游戏
METHOD NewGame() -> LOGICAL
```

#### 状态查询

```harbour
// 获取将死状态
METHOD GetMate() -> HASH

// 检查困毙状态
METHOD IsStalemate() -> LOGICAL

// 获取 MultiPV
METHOD GetMultiPV() -> HASH

// 获取 WDL 概率
METHOD GetWDL() -> HASH

// 获取 NNUE 信息
METHOD GetNNUEInfo() -> HASH

// 获取 Ponder 着法
METHOD GetPonderMove() -> CHARACTER

// 获取统计信息
METHOD GetStatistics() -> HASH

// 获取引擎信息
METHOD GetEngineInfo() -> HASH

// 获取引擎状态
METHOD GetState() -> CHARACTER

// 获取最后一个错误
METHOD GetLastError() -> CHARACTER
```

### EngineConfig 类

```harbour
// 基本配置
METHOD SetEnginePath( cPath ) -> NIL
METHOD SetHashSize( nSize ) -> NIL
METHOD SetThreads( nThreads ) -> NIL
METHOD SetUseBook( lUse ) -> NIL
METHOD SetUseEGTB( lUse ) -> NIL

// 高级配置
METHOD SetMultiPV( nPV ) -> NIL
METHOD SetPonder( lEnable ) -> NIL
METHOD SetShowWDL( lShow ) -> NIL
METHOD SetEvalFile( cFile ) -> NIL
METHOD SetMoveOverhead( nOverhead ) -> NIL

// 验证配置
METHOD Validate() -> LOGICAL
```

### GoParams 类

```harbour
// 搜索参数
METHOD SetDepth( nDepth ) -> NIL
METHOD SetMovetime( nTime ) -> NIL
METHOD SetNodes( nNodes ) -> NIL

// 棋钟参数
METHOD SetWtime( nTime ) -> NIL
METHOD SetBtime( nTime ) -> NIL
METHOD SetWinc( nInc ) -> NIL
METHOD SetBinc( nInc ) -> NIL
METHOD SetMovestogo( nMoves ) -> NIL

// 特殊模式
METHOD SetInfinite( lInfinite ) -> NIL
METHOD SetMate( nMate ) -> NIL
```

## 常见问题

### Q: 如何在不同引擎之间切换？

A: XQEngine 支持协议自动检测。只需调用 `Initialize()` 并指定引擎路径，系统会自动检测并使用正确的协议（UCI 或 UCCI）。

### Q: 异步分析如何处理超时？

A: 使用 `SetAsyncTimeout()` 设置超时时间，或使用 `WaitAsync( nTimeout )` 等待最多指定时间。

### Q: 如何获取多个候选着法？

A: 使用 `SetMultiPV( nPV )` 设置候选着法数量，然后调用 `GetMultiPV()` 获取结果。

### Q: Ponder 模式如何使用？

A: 使用 `SetPonder( .T. )` 启用 Ponder 模式，然后通过 `GetPonderMove()` 获取猜测着法。

### Q: 如何处理将死和困毙？

A: 使用 `GetMate()` 检查将死状态，使用 `IsStalemate()` 检查困毙状态。

### Q: 在 Termux/Android 环境下有什么注意事项？

A: 必须使用正确的 `hb_processOpen` 参数顺序，确保 stdin 句柄通过第二个参数获取。

## 兼容性

### 支持的平台

- ✅ Linux（桌面）
- ✅ Termux/Android
- ✅ 支持 UCI 协议引擎（Pikafish、Stockfish 等）
- ✅ 支持 UCCI 协议引擎（旋风等）

### 已知限制

- 需要正确使用 `hb_processOpen` 参数顺序
- 在 Termux 环境下需要确保文件权限正确
- 引擎路径需要是绝对路径或相对于工作目录的路径

## 版本历史

### v2.2.0 (2026-03-11)

**重大更新 - 整合为单一综合demo：**
- 将 demo.prg, demo_full.prg, demo_async.prg, test_special.prg 整合为单一综合演示程序
- 提供统一的菜单界面，包含所有功能演示
- 改进用户体验和代码可维护性

### v2.1.0 (2026-03-10)

**新增功能：**
- 添加特殊局面处理（将死、困毙检测）
- 实现异步接口（AnalyzeAsync, CheckAsyncProgress, CancelAsyncOperation）
- 改进超时处理机制（自动发送stop命令）
- 创建完整演示程序 demo_full.prg（展示9个主要功能集）
- 创建异步演示程序 demo_async.prg
- 创建特殊局面测试程序 test_special.prg

**新增方法：**
- EngineState: SetMate(), GetMate(), SetStalemate(), IsStalemate()
- XQEngine: GetMate(), IsStalemate(), AnalyzeAsync(), IsAsyncRunning(), GetAsyncResult(), CancelAsyncOperation(), CheckAsyncProgress()

**重要改进：**
- ParseInfoLine() 方法添加 score mate 信息解析
- UCCI_Go() 方法添加超时检测和自动stop命令
- 所有 demo 程序改进错误信息显示

**验证状态：**
- ✅ 特殊局面处理功能正常
- ✅ 超时处理正常工作
- ✅ 异步接口运行正常
- ✅ 所有编译通过

### v2.0.0 (2026-03-10)

**重大更新 - 完整支持 Pikafish 所有功能：**
- 实现100%功能支持度
- 添加25个新方法
- 创建GoParams类
- 支持MultiPV、Ponder、WDL、NNUE等高级功能
- 支持所有go命令参数和UCI选项

**验证状态：**
- ✅ 所有功能测试通过
- ✅ 编译无错误
- ✅ 运行正常

### v1.1.0 (2026-03-09)

**新增功能：**
- 添加 UCI 协议支持
- 实现协议自动检测（UCI/UCCI）
- 创建 `xqengine_uci_protocol.prg` 协议处理类
- 集成错误处理系统（`xqengine_errsys.prg`）

**重要修复：**
- 修复 `hb_processOpen` 参数顺序错误
- 修复 stdin 句柄获取错误
- 修复在 Termux 环境下无法向引擎发送命令的问题

**验证状态：**
- ✅ 在 Termux/Android 环境下测试通过
- ✅ Pikafish 引擎通信正常
- ✅ UCI 协议初始化成功
- ✅ 局面分析功能正常

### v1.0.0 (2025-03-09)

**初始版本：**
- UCCI 协议基础实现
- 进程间通信框架
- 基础引擎管理功能
- 基本错误处理

## 贡献指南

### 代码提交

- 确保代码符合项目编码规范
- 添加必要的注释和文档
- 更新 CHANGELOG.md
- 测试所有修改的功能

### 问题报告

- 提供详细的问题描述
- 包含错误信息和堆栈跟踪
- 说明重现步骤
- 提供环境信息（Harbour 版本、操作系统等）

## 许可证

本项目采用 CC0-1.0 公共领域许可证。您可以自由使用、修改和分发此代码，无需署名。

## 相关资源

### 外部资源

- Harbour 官方文档：https://harbour.github.io/doc/
- Pikafish 官方网站：https://github.com/official-pikafish/Pikafish
- UCCI 协议规范：见本文档技术方案部分
- UCI 协议规范：见本文档技术方案部分

### 项目文档

- `CHANGELOG.md` - 项目更新日志
- `pikafish支持度分析.md` - Pikafish 功能支持度详细分析

---

**最后更新：** 2026-03-11
**当前版本：** v2.2.0
**生成工具：** iFlow CLI