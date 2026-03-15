/*
 * xqengine_core.prg
 * 中国象棋引擎核心管理类
 *
 * 功能:
 * - 引擎生命周期管理(启动/停止/重启)
 * - UCCI 协议通信
 * - UCI 协议通信（新增）
 * - 进程 I/O 管理
 * - 异步思考支持
 * - 协议自动检测（UCI/UCCI）
 *
 * 支持的引擎:
 * - Pikafish (UCI 协议)
 * - 旋风 (UCCI 协议)
 * - 其他兼容 UCI/UCCI 协议的引擎
 *
 * 重要提示:
 * - hb_processOpen 必须使用正确的参数顺序
 * - 正确: hb_processOpen( cCommand, @hStdIn, @hStdOut, @hStdErr )
 * - 错误: hb_processOpen( cCommand, , @hStdOut, @hStdErr )
 * - stdin 句柄必须通过第二个参数获取，不能使用 hStdIn := hProcess
 *
 * 使用示例:
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * oEngine:Start()
 * LOCAL cMove := oEngine:Analyze( "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1", 5000 )
 * oEngine:Stop()
 *
 * 更新日志:
 * - v1.1 (2026-03-09): 添加 UCI 协议支持，修复 hb_processOpen 参数顺序
 * - v1.0 (2025-03-09): 初始版本，支持 UCCI 协议
 */

#include "hbclass.ch"
#include "xqengine_constants.ch"

// ============================================================================
// XQEngine 类 - 核心引擎管理
// ============================================================================

CREATE CLASS XQEngine

   // 配置和状态
   VAR oConfig
   VAR oState

   // 协议对象（策略模式）
   VAR oProtocol

   // 缓冲区
   VAR cInputBuffer    INIT ""
   VAR cOutputBuffer   INIT ""
   VAR cErrorBuffer    INIT ""

   // 回调函数
   VAR onInfoCallback  INIT NIL
   VAR onBestMoveCallback INIT NIL
   VAR onAsyncCompleteCallback INIT NIL
   VAR onAsyncErrorCallback INIT NIL

   // 异步操作状态
   VAR lAsyncRunning INIT .F.
   VAR cAsyncResult INIT ""
   VAR cAsyncError INIT ""
   VAR nAsyncStartTime INIT 0

   // 资源管理
   VAR lClosed INIT .F.
   VAR nBufferSizeLimit INIT 1048576  // 1MB 缓冲区限制

   // 异步操作配置
   VAR nAsyncTimeout INIT 60000     // 异步操作超时时间(毫秒)
   VAR nAsyncPollInterval INIT 10   // 轮询间隔(毫秒)

   // 异步操作状态（线程安全相关）
   VAR nAsyncLock INIT 0            // 简单锁（0=未锁定，1=锁定）
   VAR nAsyncState INIT 0           // 0=空闲，1=初始化，2=思考，3=完成，4=错误
   VAR nAsyncProgress INIT 0        // 进度百分比
   VAR cAsyncInfo INIT ""           // 最后收到的info信息

   // 方法
   METHOD New()
   METHOD Initialize( cEnginePath )
   METHOD Start()
   METHOD Stop()
   METHOD Restart()
   METHOD IsRunning()
   METHOD IsReady()
   METHOD IsThinking()

   // UCCI 协议方法
   METHOD SendCommand( cCommand )
   METHOD ReadLine( nTimeout )
   METHOD ReadResponse( nTimeout )
   METHOD SendAndWait( cCommand, nTimeout )

   // 引擎控制方法
   METHOD InitProtocol()
   METHOD CheckReady()
   METHOD SetPosition( cFEN, cMoves )
   METHOD Go( nDepth, nTime, nNodes )
   METHOD StopThinking()
   METHOD Quit()
   METHOD SetOption( cName, cValue )
   METHOD ClearHash()
   METHOD NewGame()
   METHOD ApplyConfig()

   // 高级方法
   METHOD Analyze( cFEN, nTimeLimit, nDepthLimit )
   METHOD AnalyzeAsync( cFEN, nTimeLimit, nDepthLimit )
   METHOD GetBestMove( nDepth, nTime )
   METHOD GoWithParams( oParams )
   METHOD AnalyzeWithParams( cFEN, oParams )
   METHOD GoInfinite( cFEN )
   METHOD StopInfinite()
   METHOD GetInfiniteResult()
   METHOD SetMultiPV( nCount )
   METHOD GetMultiPV()
   METHOD SetPonder( lEnable )
   METHOD PonderHit()
   METHOD PonderMiss()
   METHOD GetPonderMove()
   METHOD GetWDL()
   METHOD GetNNUEInfo()
   METHOD GetMate()
   METHOD IsStalemate()
   METHOD SetNNUEEvalFile( cFile )

   // 异步控制方法
   METHOD IsAsyncRunning()
   METHOD GetAsyncResult()
   METHOD GetLastError()
   METHOD CancelAsyncOperation()
   METHOD CheckAsyncProgress()
   METHOD SetAsyncTimeout( nTimeout )
   METHOD GetAsyncProgress()
   METHOD GetAsyncInfo()
   METHOD WaitAsync( nTimeout )

   // 信息方法
   METHOD GetState()
   METHOD GetStatistics()
   METHOD GetEngineInfo()

   // 设置方法
   METHOD SetConfig( oConfig )
   METHOD SetInfoCallback( bCallback )
   METHOD SetBestMoveCallback( bCallback )
   METHOD SetAsyncCompleteCallback( bCallback )
   METHOD SetAsyncErrorCallback( bCallback )

   // 内部方法
   METHOD ParseEngineOutput( cLine )
   METHOD ParseInfoLine( cLine )
   METHOD ParseBestMoveLine( cLine )
   METHOD SendCommandQuiet( cCommand )
   METHOD AsyncLock()
   METHOD AsyncUnlock()

   // 清理
   METHOD Close()
   METHOD IsClosed()
   METHOD Cleanup()
   METHOD Destructor()

ENDCLASS

// ============================================================================
// 构造函数 - 创建 XQEngine 实例
// ============================================================================
/**
 * 创建并初始化一个新的 XQEngine 实例
 *
 * 功能:
 * - 创建配置对象 (EngineConfig)
 * - 创建状态对象 (EngineState)
 * - 初始化所有缓冲区和回调
 *
 * 返回值:
 * - Self (XQEngine 对象实例)
 *
 * 使用示例:
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * oEngine:Start()
 */
METHOD New() CLASS XQEngine

   // 暂时禁用错误处理器以调试
   // InstallAiErrorHandler()

   ::oConfig := EngineConfig():New()
   ::oState  := EngineState():New()

   ::cInputBuffer  := ""
   ::cOutputBuffer := ""
   ::cErrorBuffer  := ""

   ::onInfoCallback       := NIL
   ::onBestMoveCallback   := NIL

   RETURN Self

// ============================================================================
// 初始化引擎 - 设置引擎路径
// ============================================================================
/**
 * 初始化引擎配置，设置引擎可执行文件路径
 *
 * 功能:
 * - 设置引擎可执行文件的路径
 * - 验证路径格式
 * - 路径可以是绝对路径或相对路径
 *
 * 参数:
 * - cEnginePath (字符串): 引擎可执行文件的路径
 *   - 示例: "./pikafish" 或 "/usr/local/bin/pikafish"
 *   - 如果为空或NIL，使用配置中的默认路径
 *
 * 返回值:
 * - .T. (逻辑值): 初始化成功
 *
 * 注意事项:
 * - 此方法仅设置路径，不会启动引擎
 * - 需要调用 Start() 方法来启动引擎
 * - 路径必须是有效的引擎可执行文件
 *
 * 使用示例:
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * oEngine:Start()
 */
METHOD Initialize( cEnginePath ) CLASS XQEngine

   IF HB_ISSTRING( cEnginePath )
      ::oConfig:SetEnginePath( cEnginePath )
   ENDIF

   RETURN .T.

// ============================================================================
// 启动引擎 - 启动引擎进程并初始化协议
// ============================================================================
/**
 * 启动引擎进程并初始化通信协议
 *
 * 功能:
 * - 验证配置有效性
 * - 启动引擎子进程
 * - 建立进程间通信管道
 * - 清空引擎启动信息
 * - 自动检测并初始化协议（UCI/UCCI）
 *
 * 执行步骤:
 * 1. 验证引擎配置是否有效
 * 2. 检查引擎是否已经在运行
 * 3. 使用 hb_processOpen 启动引擎进程
 * 4. 获取 stdin/stdout/stderr 句柄
 * 5. 清空引擎启动输出信息
 * 6. 初始化通信协议（先尝试UCI，失败则尝试UCCI）
 *
 * 参数:
 * - 无
 *
 * 返回值:
 * - .T. (逻辑值): 引擎启动成功
 * - .F. (逻辑值): 引擎启动失败
 *
 * 错误处理:
 * - 错误码 1: 无法启动引擎进程
 * - 错误码 2: 协议初始化失败
 * - 如果启动失败，会自动调用 Stop() 清理资源
 *
 * 注意事项:
 * - 重要: hb_processOpen 必须使用正确的参数顺序
 * - 正确: hb_processOpen( cCommand, @hStdIn, @hStdOut, @hStdErr )
 * - 错误: hb_processOpen( cCommand, , @hStdOut, @hStdErr )
 * - stdin 句柄必须通过第二个参数获取
 * - 如果引擎已在运行，会直接返回 .F.
 * - 启动后需要等待约2秒让引擎完全初始化
 *
 * 使用示例:
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * IF oEngine:Start()
 *    hb_idleSleep( 2.0 )  // 等待引擎初始化
 *    ? "引擎已就绪"
 * ENDIF
 */
METHOD Start() CLASS XQEngine

   LOCAL lResult
   LOCAL cJunk
   LOCAL nLen

   // 初始化调试系统（在验证配置之前）
   // 根据配置自动设置调试级别
   XQECI_SetDebugLevel( ::oConfig:nDebugLevel )
   
   // 如果配置了日志文件，设置日志输出
   IF ! Empty( ::oConfig:cDebugLogFile )
      XQECI_SetLogFile( ::oConfig:cDebugLogFile )
   ENDIF

   IF ! ::oConfig:Validate()
      RETURN .F.
   ENDIF

   IF ::oState:IsRunning()
      XQECI_Info( XQECI_MODULE_CORE, "Engine already running" )
      RETURN .F.
   ENDIF

   ::oState:SetState( ENGINE_STATE_STARTING )

   XQECI_InfoF( XQECI_MODULE_CORE, "Starting engine: %1", ::oConfig:cEnginePath )

   // 使用 hb_processOpen 异步打开进程
   // 正确的参数顺序: hb_processOpen( cCommand, @hStdIn, @hStdOut, @hStdErr )
   ::oState:hProcess := hb_processOpen( ::oConfig:cEnginePath, @::oState:hStdIn, @::oState:hStdOut, @::oState:hStdErr )

   IF ::oState:hProcess == 0
      ::oState:SetError( "无法启动引擎进程", 1 )
      RETURN .F.
   ENDIF

   XQECI_DebugF( XQECI_MODULE_CORE, "Engine process started, handle: %1", ::oState:hProcess )

   // 设置启动时间
   ::oState:nStartTime := GetTickCount()
   ::oState:SetState( ENGINE_STATE_RUNNING )

   // 清空启动信息
   XQECI_Debug( XQECI_MODULE_CORE, "Clearing startup info..." )
   hb_idleSleep( 0.5 )
   cJunk := Space( 4096 )
   nLen := FRead( ::oState:hStdOut, @cJunk, Len( cJunk ) )
   XQECI_DebugF( XQECI_MODULE_CORE, "Read %1 bytes of startup info", nLen )

   // 初始化协议
   XQECI_Debug( XQECI_MODULE_CORE, "Initializing protocol..." )
   lResult := ::InitProtocol()

   IF ! lResult
      ::oState:SetError( "协议初始化失败", 2 )
      XQECI_Error( XQECI_MODULE_CORE, "Protocol init failed, stopping engine" )
      ::Stop()
      RETURN .F.
   ENDIF

   XQECI_Info( XQECI_MODULE_CORE, "Protocol initialized successfully" )

   RETURN .T.

// ============================================================================
// 停止引擎 - 优雅停止并清理所有资源
// ============================================================================
/**
 * 停止引擎进程并清理所有资源
 *
 * 功能:
 * - 优雅停止引擎（先发送 stop 命令，再发送 quit 命令）
 * - 关闭所有文件句柄（stdin/stdout/stderr）
 * - 等待进程自然终止（最多2秒）
 * - 如果进程未终止，强制关闭
 * - 清空所有缓冲区
 * - 使用 TRY-FINALLY 模式保证资源清理
 *
 * 执行步骤:
 * 1. 检查引擎是否正在运行
 * 2. 设置状态为 STOPPING
 * 3. 如果引擎正在思考，发送 stop 命令
 * 4. 发送 quit 命令
 * 5. 关闭 stdin/stdout/stderr 句柄
 * 6. 等待进程终止（最多2秒）
 * 7. 如果进程未终止，强制关闭
 * 8. 清空所有缓冲区
 * 9. 设置状态为 STOPPED
 *
 * 参数:
 * - 无
 *
 * 返回值:
 * - .T. (逻辑值): 停止成功
 * - .F. (逻辑值): 停止失败
 *
 * 错误处理:
 * - 使用 BEGIN SEQUENCE ... RECOVER 捕获所有错误
 * - 使用 ALWAYS 块确保资源清理始终执行
 * - 即使发送命令失败，也会继续清理资源
 * - 即使关闭句柄失败，也会继续清理其他资源
 *
 * 注意事项:
 * - 如果引擎已经停止，直接返回 .T.
 * - 使用 SendCommandQuiet() 而不是 SendCommand()，避免记录统计
 * - 资源清理使用 ALWAYS 块保证必定执行
 * - 每个关闭操作都包裹在 BEGIN SEQUENCE 中防止二次错误
 * - 推荐使用 Close() 方法而不是 Stop()，Close() 会调用 Stop() 并做额外清理
 *
 * 使用示例:
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * oEngine:Start()
 * // ... 使用引擎 ...
 * oEngine:Stop()
 */
METHOD Stop() CLASS XQEngine

   LOCAL lResult := .T.
   LOCAL oError
   LOCAL nExitCode
   LOCAL nWaitCount

   // 如果已经停止或未运行，直接返回
   IF ! ::oState:IsRunning()
      RETURN .T.
   ENDIF

   ::oState:SetState( ENGINE_STATE_STOPPING )

   // 使用 TRY-FINALLY 模式保证资源清理
   BEGIN SEQUENCE

      // 尝试优雅停止
      BEGIN SEQUENCE
         // 如果引擎正在思考,先发送 stop 命令
         IF ::oState:IsThinking()
            ::SendCommandQuiet( "stop" )
            hb_idleSleep( 0.1 )
         ENDIF

         // 发送 quit 命令
         ::SendCommandQuiet( "quit" )
         hb_idleSleep( 0.2 )
      RECOVER
         // 忽略发送命令时的错误，继续清理
      END SEQUENCE

   ALWAYS  // FINALLY 块 - 保证执行

      // 关闭文件句柄 - 始终执行
      IF ::oState:hStdIn > 0
         BEGIN SEQUENCE
            FClose( ::oState:hStdIn )
         RECOVER
         END SEQUENCE
         ::oState:hStdIn := 0
      ENDIF

      IF ::oState:hStdOut > 0
         BEGIN SEQUENCE
            FClose( ::oState:hStdOut )
         RECOVER
         END SEQUENCE
         ::oState:hStdOut := 0
      ENDIF

      IF ::oState:hStdErr > 0
         BEGIN SEQUENCE
            FClose( ::oState:hStdErr )
         RECOVER
         END SEQUENCE
         ::oState:hStdErr := 0
      ENDIF

      // 等待进程终止
      IF ::oState:hProcess > 0
         nExitCode := hb_processValue( ::oState:hProcess )
         IF nExitCode == NIL
            // 进程还在运行，等待最多 2 秒
            nWaitCount := 0
            DO WHILE nWaitCount < 20
               hb_idleSleep( 0.1 )
               nExitCode := hb_processValue( ::oState:hProcess )
               IF nExitCode != NIL
                  EXIT
               ENDIF
               nWaitCount++
            ENDDO
         ENDIF

         // 如果进程还在运行，强制终止
         IF nExitCode == NIL
            BEGIN SEQUENCE
               hb_processClose( ::oState:hProcess )
            RECOVER
            END SEQUENCE
         ENDIF

         ::oState:hProcess := 0
      ENDIF

      // 清空缓冲区
      ::cInputBuffer := ""
      ::cOutputBuffer := ""
      ::cErrorBuffer := ""

      ::oState:SetState( ENGINE_STATE_STOPPED )

   END SEQUENCE

   RETURN lResult

// ============================================================================
// 静默发送命令 - 不记录统计信息
// ============================================================================
/**
 * 静默发送命令到引擎，不记录统计信息
 *
 * 功能:
 * - 向引擎发送命令
 * - 不记录命令统计（不调用 RecordCommand）
 * - 不记录响应统计
 * - 所有错误都被忽略（不抛出异常）
 *
 * 使用场景:
 * - 引擎停止时发送 stop/quit 命令
 * - 资源清理时发送命令
 * - 不需要追踪的辅助命令
 *
 * 参数:
 * - cCommand (字符串): 要发送的命令
 *   - 示例: "stop", "quit", "isready"
 *
 * 返回值:
 * - .T. (逻辑值): 总是返回 .T.，即使发送失败
 *
 * 注意事项:
 * - 此方法不检查引擎是否运行
 * - 此方法不记录统计信息
 * - 此方法忽略所有错误
 * - 如果 stdin 句柄无效，静默失败
 * - 使用场景: Stop() 方法中发送 stop/quit 命令
 *
 * 与 SendCommand() 的区别:
 * - SendCommand(): 记录统计，检查状态，返回成功/失败
 * - SendCommandQuiet(): 不记录统计，不检查状态，总是返回 .T.
 *
 * 使用示例:
 * ::SendCommandQuiet( "stop" )   // 停止引擎思考
 * ::SendCommandQuiet( "quit" )   // 退出引擎
 */
METHOD SendCommandQuiet( cCommand ) CLASS XQEngine

   LOCAL nLen

   IF ::oState:hStdIn > 0
      BEGIN SEQUENCE
         nLen := FWrite( ::oState:hStdIn, cCommand + hb_eol() )
         hb_idleSleep( 0.05 )
      RECOVER
      END SEQUENCE
   ENDIF

   RETURN .T.

// ============================================================================
// 重启引擎
// ============================================================================

METHOD Restart() CLASS XQEngine

   LOCAL lResult

   lResult := ::Stop()
   IF lResult
      hb_idleSleep( 0.5 )
      lResult := ::Start()
   ENDIF

   RETURN lResult

// ============================================================================
// 检查是否运行中
// ============================================================================

METHOD IsRunning() CLASS XQEngine
   RETURN ::oState:IsRunning()

// ============================================================================
// 检查是否就绪
// ============================================================================

METHOD IsReady() CLASS XQEngine
   RETURN ::oState:IsReady()

// ============================================================================
// 检查是否思考中
// ============================================================================

METHOD IsThinking() CLASS XQEngine
   RETURN ::oState:IsThinking()

// ============================================================================
// 发送命令到引擎 - 记录统计信息
// ============================================================================
/**
 * 发送命令到引擎并记录统计信息
 *
 * 功能:
 * - 向引擎发送命令
 * - 记录命令统计信息（调用 RecordCommand）
 * - 检查引擎状态
 * - 处理发送错误
 *
 * 参数:
 * - cCommand (字符串): 要发送的命令
 *   - UCI 命令: "uci", "isready", "position startpos", "go depth 10" 等
 *   - UCCI 命令: "ucci", "banmoves", "depth 10" 等
 *   - 不能为空或 NIL
 *
 * 返回值:
 * - .T. (逻辑值): 命令发送成功
 * - .F. (逻辑值): 命令发送失败
 *
 * 错误处理:
 * - 错误码 99: 引擎已关闭
 * - 错误码 5: 发送命令失败（FWrite 返回 0 或异常）
 * - 使用 BEGIN SEQUENCE 捕获异常
 *
 * 前置条件:
 * - 引擎必须已启动（IsRunning() 返回 .T.）
 * - 引擎不能已关闭（lClosed 不能为 .T.）
 * - 命令不能为空
 *
 * 注意事项:
 * - 发送后等待 0.1 秒让引擎处理
 * - 自动添加换行符
 * - 记录命令到统计信息
 * - 如果引擎已关闭，不会尝试发送
 *
 * 与 SendCommandQuiet() 的区别:
 * - SendCommand(): 记录统计，检查状态，返回成功/失败
 * - SendCommandQuiet(): 不记录统计，不检查状态，总是返回 .T.
 *
 * 使用示例:
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * oEngine:Start()
 *
 * // 发送 isready 命令
 * IF oEngine:SendCommand( "isready" )
 *    ? "命令发送成功"
 * ENDIF
 *
 * // 发送 go 命令
 * oEngine:SendCommand( "go depth 10" )
 */
METHOD SendCommand( cCommand ) CLASS XQEngine

   LOCAL lResult
   LOCAL nLen
   LOCAL oError

   // 检查是否已关闭
   IF ::lClosed
      ::oState:SetError( "引擎已关闭", 99 )
      RETURN .F.
   ENDIF

   IF ! ::oState:IsRunning()
      RETURN .F.
   ENDIF

   IF Empty( cCommand )
      RETURN .F.
   ENDIF

   BEGIN SEQUENCE

      // 发送命令(添加换行符)
      nLen := FWrite( ::oState:hStdIn, cCommand + hb_eol() )

      // 检查是否写入成功
      IF nLen <= 0
         ::oState:SetError( "发送命令失败: FWrite 返回 0", 5 )
         lResult := .F.
      ELSE
         // 给引擎一些时间处理命令
         hb_idleSleep( 0.1 )

         // 记录命令
         ::oState:RecordCommand( cCommand )

         lResult := .T.
      ENDIF

   RECOVER USING oError
      ::oState:SetError( "发送命令失败: " + oError:Description, 5 )
      ::oState:RecordError()
      lResult := .F.
   END SEQUENCE

   RETURN lResult

// ============================================================================
// 从引擎读取一行 - 支持超时和缓冲区管理
// ============================================================================
/**
 * 从引擎输出中读取一行数据
 *
 * 功能:
 * - 从缓冲区读取完整行（以换行符结尾）
 * - 如果缓冲区没有完整行，从引擎读取更多数据
 * - 支持超时控制
 * - 缓冲区大小限制（防止内存溢出）
 * - 记录响应统计信息
 *
 * 参数:
 * - nTimeout (数值): 超时时间（毫秒）
 *   - 默认值: 30000 (30秒)
 *   - 最小值: 1
 *   - 建议值: 1000-60000
 *
 * 返回值:
 * - 字符串: 读取到的一行数据（不包含换行符）
 * - 空字符串: 超时或引擎未运行
 *
 * 执行流程:
 * 1. 检查引擎是否运行
 * 2. 检查缓冲区是否有完整行
 * 3. 如果有，立即返回
 * 4. 如果没有，从引擎读取数据（最多超时时间）
 * 5. 每次读取 1024 字节
 * 6. 检查缓冲区大小，超过限制时截断
 * 7. 查找换行符，返回完整行
 *
 * 内存保护:
 * - 缓冲区大小限制: 1MB (nBufferSizeLimit)
 * - 超过限制时保留后 512KB，丢弃前面的数据
 * - 防止引擎输出大量数据导致内存溢出
 *
 * 超时处理:
 * - 超时后返回空字符串
 * - 即使超时，缓冲区中的数据仍然保留
 * - 下次调用可以从缓冲区继续读取
 *
 * 注意事项:
 * - 此方法是阻塞的，会等待直到收到完整行或超时
 * - 每次读取间隔 10ms (hb_idleSleep 0.01)
 * - 返回的行不包含换行符
 * - 调用后会记录响应统计信息
 *
 * 使用示例:
 * LOCAL cLine
 *
 * // 读取一行，超时 5 秒
 * cLine := oEngine:ReadLine( 5000 )
 * IF ! Empty( cLine )
 *    ? "收到:", cLine
 * ENDIF
 *
 * // 读取引擎输出
 * DO WHILE ( cLine := oEngine:ReadLine( 10000 ) ) != ""
 *    ? cLine
 *    IF "bestmove" $ Lower( cLine )
 *       EXIT
 *    ENDIF
 * ENDDO
 */
METHOD ReadLine( nTimeout ) CLASS XQEngine

   LOCAL cLine := ""
   LOCAL cData
   LOCAL nLen
   LOCAL nStartTime
   LOCAL nPos

   IF nTimeout == NIL
      nTimeout := 30000
   ENDIF

   IF ! ::oState:IsRunning()
      RETURN ""
   ENDIF

   nStartTime := GetTickCount()

   // 检查缓冲区
   nPos := At( hb_eol(), ::cOutputBuffer )
   IF nPos > 0
      cLine := Left( ::cOutputBuffer, nPos - 1 )
      ::cOutputBuffer := SubStr( ::cOutputBuffer, nPos + Len( hb_eol() ) )
      RETURN cLine
   ENDIF

   // 从引擎读取数据
   DO WHILE ( GetTickCount() - nStartTime ) < nTimeout
      cData := Space( 1024 )
      nLen := FRead( ::oState:hStdOut, @cData, Len( cData ) )

      IF nLen > 0
         ::cOutputBuffer += hb_BLeft( cData, nLen )

         // 检查缓冲区大小限制，防止内存溢出
         IF Len( ::cOutputBuffer ) > ::nBufferSizeLimit
            // 保留最后一部分数据，丢弃前面的
            ::cOutputBuffer := Right( ::cOutputBuffer, ::nBufferSizeLimit / 2 )
         ENDIF

         // 检查是否有完整行
         nPos := At( hb_eol(), ::cOutputBuffer )
         IF nPos > 0
            cLine := Left( ::cOutputBuffer, nPos - 1 )
            ::cOutputBuffer := SubStr( ::cOutputBuffer, nPos + Len( hb_eol() ) )
            EXIT
         ENDIF
      ELSE
         hb_idleSleep( 0.01 )
      ENDIF
   ENDDO

   IF ! Empty( cLine )
      ::oState:RecordResponse( cLine )
   ENDIF

   RETURN cLine

// ============================================================================
// 读取响应 - 读取完整的多行响应
// ============================================================================
/**
 * 从引擎读取完整的响应（多行）
 *
 * 功能:
 * - 持续读取引擎输出直到收到终止标记
 * - 支持多种终止条件
 * - 将所有行合并为一个字符串
 *
 * 参数:
 * - nTimeout (数值): 每行读取的超时时间（毫秒）
 *   - 默认值: 30000 (30秒)
 *   - 注意: 这是每行的超时，不是整个响应的超时
 *
 * 返回值:
 * - 字符串: 完整的响应（多行，每行带换行符）
 * - 空字符串: 未收到响应或超时
 *
 * 终止条件（满足任一条件即停止）:
 * 1. 收到 "bestmove" 行（最佳着法）
 * 2. 收到 "ucciok" 行（UCCI 协议确认）
 * 3. 收到 "uciok" 行（UCI 协议确认）
 * 4. 收到 "readyok" 行（就绪确认）
 * 5. ReadLine 返回空字符串（超时或无数据）
 *
 * 使用场景:
 * - 等待引擎初始化完成
 * - 等待分析结果
 * - 等待引擎状态确认
 *
 * 注意事项:
 * - 此方法会阻塞直到收到终止标记
 * - 每行都有独立的超时时间
 * - 返回的字符串包含所有行的换行符
 * - 不处理 info 行，只读取直到终止标记
 *
 * 使用示例:
 * // 等待引擎初始化
 * LOCAL cResponse := oEngine:SendAndWait( "uci", 5000 )
 * ? "初始化响应:", cResponse
 *
 * // 等待分析结果
 * cResponse := oEngine:ReadResponse( 10000 )
 * IF "bestmove" $ Lower( cResponse )
 *    ? "分析完成"
 * ENDIF
 */
METHOD ReadResponse( nTimeout ) CLASS XQEngine

   LOCAL cLine
   LOCAL cResponse := ""

   IF nTimeout == NIL
      nTimeout := 30000
   ENDIF

   DO WHILE ( cLine := ::ReadLine( nTimeout ) ) != ""
      cResponse += cLine + hb_eol()

      // 检查是否是完整响应
      IF "bestmove" $ Lower( cLine )
         EXIT
      ENDIF

      // UCCI/UCI 协议响应
      IF "ucciok" $ Lower( cLine ) .OR. "uciok" $ Lower( cLine )
         EXIT
      ENDIF

      IF "readyok" $ Lower( cLine )
         EXIT
      ENDIF
   ENDDO

   RETURN cResponse

// ============================================================================
// 发送命令并等待响应 - 便捷方法
// ============================================================================
/**
 * 发送命令并等待引擎响应
 *
 * 功能:
 * - 发送命令到引擎
 * - 等待引擎返回完整响应
 * - 组合了 SendCommand() 和 ReadResponse() 两个操作
 *
 * 参数:
 * - cCommand (字符串): 要发送的命令
 *   - 示例: "uci", "isready", "position startpos moves e2e4"
 * - nTimeout (数值): 响应超时时间（毫秒）
 *   - 默认值: 30000 (30秒)
 *   - 这是 ReadResponse 的超时时间
 *
 * 返回值:
 * - 字符串: 引擎的完整响应
 * - 空字符串: 发送失败或未收到响应
 *
 * 执行流程:
 * 1. 调用 SendCommand( cCommand ) 发送命令
 * 2. 如果发送失败，返回空字符串
 * 3. 调用 ReadResponse( nTimeout ) 等待响应
 * 4. 返回响应内容
 *
 * 使用场景:
 * - 初始化协议: SendAndWait( "uci" )
 * - 检查就绪: SendAndWait( "isready" )
 * - 简单查询: SendAndWait( "uci" )
 *
 * 注意事项:
 * - 此方法是同步阻塞的
 * - 如果发送失败，不会等待响应
 * - 响应可能包含多行
 * - 适合简单的请求-响应场景
 *
 * 使用示例:
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * oEngine:Start()
 *
 * // 检查引擎是否就绪
 * LOCAL cResponse := oEngine:SendAndWait( "isready", 3000 )
 * IF "readyok" $ Lower( cResponse )
 *    ? "引擎已就绪"
 * ENDIF
 *
 * // 初始化 UCI 协议
 * cResponse := oEngine:SendAndWait( "uci", 5000 )
 * IF "uciok" $ Lower( cResponse )
 *    ? "UCI 协议初始化成功"
 * ENDIF
 */
METHOD SendAndWait( cCommand, nTimeout ) CLASS XQEngine

   IF ! ::SendCommand( cCommand )
      RETURN ""
   ENDIF

   RETURN ::ReadResponse( nTimeout )

// ============================================================================
// 初始化引擎协议 - 自动检测协议类型
// ============================================================================
/**
 * 初始化引擎通信协议，自动检测 UCI 或 UCCI 协议
 *
 * 功能:
 * - 自动检测引擎支持的协议（UCI 或 UCCI）
 * - 解析引擎信息（名称、作者、版本）
 * - 设置协议标志
 * - 创建对应的协议对象
 * - 等待引擎初始化完成
 *
 * 协议检测流程:
 * 1. 先发送 "uci" 命令（Pikafish 等现代引擎使用 UCI）
 * 2. 等待引擎响应（最多 10 秒）
 * 3. 如果收到 "uciok"，使用 UCI 协议
 * 4. 如果收到 "ucciok"，使用 UCCI 协议
 * 5. 解析引擎的 id name、id author、id version 信息
 * 6. 创建对应的协议对象
 *
 * 参数:
 * - 无
 *
 * 返回值:
 * - .T. (逻辑值): 协议初始化成功
 * - .F. (逻辑值): 协议初始化失败
 *
 * 引擎信息解析:
 * - cEngineName: 引擎名称（从 "id name" 行提取）
 * - cEngineAuthor: 引擎作者（从 "id author" 行提取）
 * - cEngineVersion: 引擎版本（从 "id version" 行提取）
 * - lUCIProtocol: UCI 协议标志
 *
 * 超时处理:
 * - 总超时时间: 10 秒
 * - 每行读取超时: 1 秒
 * - 连续 10 次空响应视为超时
 *
 * 支持的引擎:
 * - Pikafish (UCI 协议)
 * - 旋风 (UCCI 协议)
 * - 其他兼容 UCI/UCCI 协议的引擎
 *
 * 注意事项:
 * - 此方法必须在 Start() 后调用
 * - 引擎必须支持 UCI 或 UCCI 协议
 * - 如果引擎不支持 UCI，会尝试 UCCI
 * - 10 秒内必须收到响应，否则视为失败
 *
 * 使用示例:
 * // 通常不需要直接调用此方法
 * // Start() 方法会自动调用
 *
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * oEngine:Start()  // 内部调用 InitProtocol()
 *
 * // 手动调用（重新初始化协议）
 * IF oEngine:InitProtocol()
 *    ? "协议初始化成功"
 * ENDIF
 */
METHOD InitProtocol() CLASS XQEngine

   LOCAL cResponse
   LOCAL lUCIProtocol := .F.
   LOCAL lUCCIProtocol := .F.
   LOCAL nCount
   LOCAL nStartTime

   // 先尝试发送 uci 命令（Pikafish 使用 UCI 协议）
   IF ! ::SendCommand( "uci" )
      RETURN .F.
   ENDIF

   XQECI_Debug( XQECI_MODULE_CORE, "Waiting for engine response..." )

   // 读取引擎信息
   nStartTime := hb_MilliSeconds()
   nCount := 0
   DO WHILE ( hb_MilliSeconds() - nStartTime ) < 10000  // 10秒超时
      cResponse := ::ReadLine( 1000 )

      IF Empty( cResponse )
         nCount++
         IF nCount > 10  // 连续10次空响应
            XQECI_Warn( XQECI_MODULE_CORE, "No engine response, timeout possible" )
            EXIT
         ENDIF
         LOOP
      ENDIF

      nCount := 0  // 重置空响应计数
      XQECI_DebugF( XQECI_MODULE_CORE, "Received: %1", cResponse )

      // 解析引擎信息
      IF "id name" $ Lower( cResponse )
         ::oState:cEngineName := SubStr( cResponse, At( "name", cResponse ) + 5 )
         ::oState:cEngineName := AllTrim( ::oState:cEngineName )
      ELSEIF "id author" $ Lower( cResponse )
         ::oState:cEngineAuthor := SubStr( cResponse, At( "author", cResponse ) + 7 )
         ::oState:cEngineAuthor := AllTrim( ::oState:cEngineAuthor )
      ELSEIF "id version" $ Lower( cResponse )
         ::oState:cEngineVersion := SubStr( cResponse, At( "version", cResponse ) + 8 )
         ::oState:cEngineVersion := AllTrim( ::oState:cEngineVersion )
      ELSEIF "uciok" $ Lower( cResponse )
         // UCI 协议
         lUCIProtocol := .T.
         XQECI_Info( XQECI_MODULE_CORE, "UCI protocol detected" )
         EXIT
      ELSEIF "ucciok" $ Lower( cResponse )
         // UCCI 协议
         lUCCIProtocol := .T.
         XQECI_Info( XQECI_MODULE_CORE, "UCCI protocol detected" )
         EXIT
      ENDIF
   ENDDO

   // 如果是 UCI 协议，记录标志并创建协议对象
   ::oState:lUCIProtocol := lUCIProtocol

   // 创建对应的协议对象（策略模式）
   IF lUCIProtocol
      ::oProtocol := UCIProtocol():New()
      XQECI_Debug( XQECI_MODULE_CORE, "Creating UCI protocol object" )
   ELSEIF lUCCIProtocol
      ::oProtocol := UCCIProtocol():New()
      XQECI_Debug( XQECI_MODULE_CORE, "Creating UCCI protocol object" )
   ELSE
      XQECI_Warn( XQECI_MODULE_CORE, "Warning: No supported protocol detected" )
   ENDIF

   XQECI_InfoF( XQECI_MODULE_CORE, "Protocol init complete, UCI: %1 UCCI: %2", lUCIProtocol, lUCCIProtocol )
   RETURN .T.

// ============================================================================
// 检查引擎是否就绪
// ============================================================================

METHOD CheckReady() CLASS XQEngine

   LOCAL cResponse

   cResponse := ::SendAndWait( "isready", 3000 )

   RETURN "readyok" $ Lower( cResponse )

// ============================================================================
// 设置棋局位置
// ============================================================================

METHOD SetPosition( cFEN, cMoves ) CLASS XQEngine

   LOCAL cCommand

   // 使用协议对象构建命令
   IF ::oProtocol != NIL
      cCommand := ::oProtocol:BuildPosition( cFEN, cMoves )
   ELSE
      // 兼容性：如果没有协议对象，使用默认实现
      IF cFEN == NIL
         cFEN := "startpos"
      ENDIF

      IF cMoves == NIL
         cMoves := ""
      ENDIF

      IF Lower( cFEN ) == "startpos"
         IF Empty( cMoves )
            cCommand := "position startpos"
         ELSE
            cCommand := "position startpos moves " + cMoves
         ENDIF
      ELSE
         IF Empty( cMoves )
            cCommand := "position " + cFEN
         ELSE
            cCommand := "position " + cFEN + " moves " + cMoves
         ENDIF
      ENDIF
   ENDIF

   RETURN ::SendCommand( cCommand )

// ============================================================================
// 让引擎开始思考 - 基础搜索方法
// ============================================================================
/**
 * 让引擎开始分析局面并返回最佳着法
 *
 * 功能:
 * - 发送 go 命令到引擎
 * - 支持深度、时间、节点数限制
 * - 自动适配 UCI/UCCI 协议
 * - 解析引擎输出并提取最佳着法
 * - 超时处理和自动停止
 *
 * 参数:
 * - nDepth (数值): 搜索深度
 *   - 默认值: 配置中的 nDefaultDepth
 *   - 范围: 1-50
 *   - 示例: 10 (搜索到深度10)
 * - nTime (数值): 搜索时间限制（毫秒）
 *   - 默认值: 配置中的 nDefaultTime
 *   - 范围: 100-60000
 *   - 示例: 5000 (最多搜索5秒)
 * - nNodes (数值): 搜索节点数限制
 *   - 默认值: 0 (不限制)
 *   - 范围: 0-无穷大
 *   - 示例: 1000000 (最多搜索100万个节点)
 *
 * 返回值:
 * - 字符串: 最佳着法（如 "e2e4", "h2h8+"）
 * - 空字符串: 搜索失败或超时
 *
 * 协议差异:
 * - UCI 协议: 使用 "movetime" 参数
 * - UCCI 协议: 使用 "time" 参数
 * - 本方法会自动检测并使用正确的参数
 *
 * 执行流程:
 * 1. 构建命令字符串
 * 2. 设置状态为 THINKING
 * 3. 发送 go 命令
 * 4. 持续读取引擎输出
 * 5. 解析每行输出（调用 ParseEngineOutput）
 * 6. 提取 bestmove
 * 7. 如果超时，发送 stop 命令
 * 8. 恢复状态为 RUNNING
 *
 * 超时处理:
 * - 超时时间: nTime + 5000 毫秒
 * - 超时后自动发送 stop 命令
 * - 设置错误码 7
 *
 * 错误处理:
 * - 错误码 7: 搜索超时，未收到最佳着法
 *
 * 注意事项:
 * - 此方法是同步阻塞的
 * - 超时时间 = nTime + 5000ms
 * - 如果同时指定深度和时间，先到者为准
 * - 节点数限制为可选参数
 *
 * 使用示例:
 * // 按深度搜索
 * LOCAL cMove := oEngine:Go( 10, 0, 0 )  // 深度10
 *
 * // 按时间搜索
 * cMove := oEngine:Go( 0, 5000, 0 )  // 最多5秒
 *
 * // 按节点数搜索
 * cMove := oEngine:Go( 0, 0, 1000000 )  // 最多100万节点
 *
 * // 组合限制
 * cMove := oEngine:Go( 15, 10000, 0 )  // 深度15或10秒
 */
METHOD Go( nDepth, nTime, nNodes ) CLASS XQEngine

   LOCAL cCommand
   LOCAL cResponse
   LOCAL cBestMove
   LOCAL aParts
   LOCAL nPos

   IF nDepth == NIL
      nDepth := ::oConfig:nDefaultDepth
   ENDIF

   // 深度上限检查，防止无限搜索
   IF nDepth > 99
      nDepth := 99
   ENDIF

   IF nTime == NIL
      nTime := ::oConfig:nDefaultTime
   ENDIF

   IF nNodes == NIL
      nNodes := 0
   ENDIF

   // 使用协议对象构建命令（策略模式）
   IF ::oProtocol != NIL
      cCommand := ::oProtocol:BuildGo( nDepth, nTime, nNodes )
   ELSE
      // 兼容性：如果没有协议对象，使用默认实现
      cCommand := "go"

      IF nDepth > 0
         cCommand += " depth " + LTrim( Str( nDepth ) )
      ENDIF

      // UCI 协议使用 movetime，UCCI 协议使用 time
      IF nTime > 0
         IF ::oState:lUCIProtocol
            cCommand += " movetime " + LTrim( Str( nTime ) )
         ELSE
            cCommand += " time " + LTrim( Str( nTime ) )
         ENDIF
      ENDIF

      IF nNodes > 0
         cCommand += " nodes " + LTrim( Str( nNodes ) )
      ENDIF
   ENDIF

   // 更新状态
   ::oState:SetState( ENGINE_STATE_THINKING )

   // 发送命令
   XQECI_DebugF( XQECI_MODULE_CORE, "Sending go command: %1", cCommand )
   IF ! ::SendCommand( cCommand )
      ::oState:SetState( ENGINE_STATE_RUNNING )
      RETURN ""
   ENDIF

   // 读取输出
   cBestMove := ""
   XQECI_DebugF( XQECI_MODULE_CORE, "Reading engine response, timeout: %1 ms", nTime + 5000 )
   DO WHILE ( cResponse := ::ReadLine( nTime + 5000 ) ) != ""
      XQECI_DebugF( XQECI_MODULE_CORE, "Go: Received response: %1", cResponse )
      // 解析输出
      ::ParseEngineOutput( cResponse )

      // 检查是否是最佳着法
      IF "bestmove" $ Lower( cResponse )
         aParts := HB_ATokens( cResponse, " " )
         nPos := AScan( aParts, {|p| Lower( p ) == "bestmove"} )
         IF nPos > 0 .AND. nPos + 1 <= Len( aParts )
            cBestMove := aParts[nPos + 1]
         ENDIF
         EXIT
      ENDIF
   ENDDO

   // 检查是否超时
   IF Empty( cBestMove )
      XQECI_Warn( XQECI_MODULE_CORE, "Go: Warning - timeout waiting for best move" )
      ::oState:SetError( "搜索超时: 未收到引擎的最佳走法响应", 7 )

      // 发送stop命令停止引擎
      IF ::oState:IsThinking()
         XQECI_Debug( XQECI_MODULE_CORE, "Go: Sending stop command to engine..." )
         ::StopThinking()
      ENDIF
   ENDIF

   XQECI_DebugF( XQECI_MODULE_CORE, "Go: Read complete, best move: %1", iif( Empty( cBestMove ), "(none)", cBestMove ) )

   // 更新状态
   ::oState:SetState( ENGINE_STATE_RUNNING )

   RETURN cBestMove

// ============================================================================
// 停止引擎思考
// ============================================================================

METHOD StopThinking() CLASS XQEngine

   IF ::oState:IsThinking()
      ::SendCommand( "stop" )
      ::oState:SetState( ENGINE_STATE_RUNNING )
      RETURN .T.
   ENDIF

   RETURN .F.

// ============================================================================
// 退出引擎协议
// ============================================================================

METHOD Quit() CLASS XQEngine
   RETURN ::SendCommand( "quit" )

// ============================================================================
// 设置引擎选项
// ============================================================================

METHOD SetOption( cName, cValue ) CLASS XQEngine

   LOCAL cCommand
   LOCAL lResult

   IF ! ::oState:IsRunning()
      RETURN .F.
   ENDIF

   IF Empty( cName )
      RETURN .F.
   ENDIF

   // 构建 setoption 命令
   IF cValue == NIL .OR. Empty( cValue )
      cCommand := "setoption name " + cName
   ELSE
      // 支持数值和字符串类型
      IF HB_ISNUMERIC( cValue )
         cCommand := "setoption name " + cName + " value " + hb_ntos( cValue )
      ELSE
         cCommand := "setoption name " + cName + " value " + cValue
      ENDIF
   ENDIF

   lResult := ::SendCommand( cCommand )
   hb_idleSleep( 0.1 )

   RETURN lResult

// ============================================================================
// 清除哈希表
// ============================================================================

METHOD ClearHash() CLASS XQEngine
   RETURN ::SendCommand( "setoption name Clear Hash" )

// ============================================================================
// 开始新游戏
// ============================================================================

METHOD NewGame() CLASS XQEngine

   LOCAL lResult

   IF ! ::oState:IsRunning()
      RETURN .F.
   ENDIF

   lResult := ::SendCommand( "ucinewgame" )
   hb_idleSleep( 0.2 )

   RETURN lResult

// ============================================================================
// 应用配置到引擎
// ============================================================================

METHOD ApplyConfig() CLASS XQEngine

   LOCAL lResult := .T.

   IF ! ::oState:IsRunning()
      RETURN .F.
   ENDIF

   // 应用所有配置选项
   IF ! Empty( ::oConfig:cDebugLogFile )
      lResult := lResult .AND. ::SetOption( "Debug Log File", ::oConfig:cDebugLogFile )
   ENDIF

   IF ::oConfig:cNumaPolicy != "auto"
      lResult := lResult .AND. ::SetOption( "NumaPolicy", ::oConfig:cNumaPolicy )
   ENDIF

   lResult := lResult .AND. ::SetOption( "Threads", LTrim( Str( ::oConfig:nThreads ) ) )
   lResult := lResult .AND. ::SetOption( "Hash", LTrim( Str( ::oConfig:nHashSize ) ) )
   lResult := lResult .AND. ::SetOption( "Ponder", iif( ::oConfig:lPonder, "true", "false" ) )
   lResult := lResult .AND. ::SetOption( "MultiPV", LTrim( Str( ::oConfig:nMultiPV ) ) )
   lResult := lResult .AND. ::SetOption( "Move Overhead", LTrim( Str( ::oConfig:nMoveOverhead ) ) )
   lResult := lResult .AND. ::SetOption( "nodestime", LTrim( Str( ::oConfig:nNodeTime ) ) )
   lResult := lResult .AND. ::SetOption( "UCI_ShowWDL", iif( ::oConfig:lShowWDL, "true", "false" ) )

   IF ! Empty( ::oConfig:cEvalFile )
      lResult := lResult .AND. ::SetOption( "EvalFile", ::oConfig:cEvalFile )
   ENDIF

   RETURN lResult

// ============================================================================
// 分析局面
// ============================================================================

METHOD Analyze( cFEN, nTimeLimit, nDepthLimit ) CLASS XQEngine

   LOCAL cBestMove

   IF ! ::oState:IsReady()
      XQECI_Warn( XQECI_MODULE_CORE, "Engine not ready" )
      RETURN ""
   ENDIF

   IF nTimeLimit == NIL
      nTimeLimit := ::oConfig:nDefaultTime
   ENDIF

   IF nDepthLimit == NIL
      nDepthLimit := 0
   ENDIF

   // 设置局面
   IF ! ::SetPosition( cFEN )
      RETURN ""
   ENDIF

   // 开始分析
   cBestMove := ::Go( nDepthLimit, nTimeLimit, 0 )

   RETURN cBestMove

// ============================================================================
// 获取最佳走法 - 简化版分析方法
// ============================================================================
/**
 * 获取当前局面的最佳着法（简化版）
 *
 * 功能:
 * - 分析当前局面（不需要重新设置）
 * - 返回最佳着法
 *
 * 参数:
 * - nDepth (数值): 搜索深度
 *   - 默认值: 配置中的 nDefaultDepth
 *   - 示例: 10
 * - nTime (数值): 时间限制（毫秒）
 *   - 默认值: 配置中的 nDefaultTime
 *   - 示例: 5000
 *
 * 返回值:
 * - 字符串: 最佳着法
 * - 空字符串: 分析失败
 *
 * 注意事项:
 * - 此方法不设置局面，使用当前局面
 * - 需要先调用 SetPosition 设置局面
 *
 * 使用示例:
 * oEngine:SetPosition( "startpos" )
 * LOCAL cMove := oEngine:GetBestMove( 10, 5000 )
 */
METHOD GetBestMove( nDepth, nTime ) CLASS XQEngine

   IF ! ::oState:IsReady()
      RETURN ""
   ENDIF

   RETURN ::Go( nDepth, nTime, 0 )

// ============================================================================
// 使用参数让引擎开始思考
// ============================================================================

METHOD GoWithParams( oParams ) CLASS XQEngine

   LOCAL cCommand
   LOCAL cResponse
   LOCAL cBestMove
   LOCAL aParts
   LOCAL nPos
   LOCAL nTimeout

   IF ! HB_ISOBJECT( oParams )
      RETURN ""
   ENDIF

   cCommand := oParams:BuildCommand()

   // 更新状态
   ::oState:SetState( ENGINE_STATE_THINKING )

   // 发送命令
   XQECI_DebugF( XQECI_MODULE_CORE, "Sending go command: %1", cCommand )
   IF ! ::SendCommand( cCommand )
      ::oState:SetState( ENGINE_STATE_RUNNING )
      RETURN ""
   ENDIF

   // 计算超时时间
   IF oParams:lInfinite
      nTimeout := 3600000  // 1小时
   ELSEIF oParams:nMate > 0
      nTimeout := 300000   // 5分钟
   ELSEIF oParams:nMovetime > 0
      nTimeout := oParams:nMovetime + 10000
   ELSEIF oParams:nDepth > 0
      nTimeout := 120000  // 2分钟
   ELSEIF oParams:HasTimeControl()
      nTimeout := 600000  // 10分钟
   ELSE
      nTimeout := 30000   // 默认30秒
   ENDIF

   // 读取输出
   cBestMove := ""
   XQECI_DebugF( XQECI_MODULE_CORE, "Reading engine response, timeout: %1 ms", nTimeout )
   DO WHILE ( cResponse := ::ReadLine( nTimeout ) ) != ""
      XQECI_DebugF( XQECI_MODULE_CORE, "< Received response: %1", cResponse )
      // 解析输出
      ::ParseEngineOutput( cResponse )

      // 检查是否是最佳着法
      IF "bestmove" $ Lower( cResponse )
         aParts := HB_ATokens( cResponse, " " )
         nPos := AScan( aParts, {|p| Lower( p ) == "bestmove"} )
         IF nPos > 0 .AND. nPos + 1 <= Len( aParts )
            cBestMove := aParts[nPos + 1]
         ENDIF
         EXIT
      ENDIF
   ENDDO
   XQECI_DebugF( XQECI_MODULE_CORE, "< Read complete, best move: %1", iif( Empty( cBestMove ), "(none)", cBestMove ) )

   // 更新状态
   ::oState:SetState( ENGINE_STATE_RUNNING )

   RETURN cBestMove

// ============================================================================
// 使用参数分析局面
// ============================================================================

METHOD AnalyzeWithParams( cFEN, oParams ) CLASS XQEngine

   LOCAL cBestMove

   IF ! ::oState:IsReady()
      XQECI_Warn( XQECI_MODULE_CORE, "Engine not ready" )
      RETURN ""
   ENDIF

   // 设置局面
   IF ! ::SetPosition( cFEN )
      RETURN ""
   ENDIF

   // 开始分析
   cBestMove := ::GoWithParams( oParams )

   RETURN cBestMove

// ============================================================================
// 无限搜索
// ============================================================================

// ============================================================================
// 无限搜索 - 异步模式
// 注意: go infinite 模式下引擎不会主动返回 bestmove
// 必须发送 stop 命令才能获得结果，所以使用异步模式
// ============================================================================

METHOD GoInfinite( cFEN ) CLASS XQEngine

   LOCAL lResult

   // 设置局面
   IF ! ::SetPosition( cFEN )
      RETURN .F.
   ENDIF

   // 更新状态
   ::oState:SetState( ENGINE_STATE_THINKING )

   // 发送 go infinite 命令
   XQECI_Debug( XQECI_MODULE_CORE, "Sending go infinite command" )
   IF ! ::SendCommand( "go infinite" )
      ::oState:SetState( ENGINE_STATE_RUNNING )
      RETURN .F.
   ENDIF

   // 标记为无限搜索模式
   ::lAsyncRunning := .T.
   ::nAsyncState := 2  // 思考中

   RETURN .T.

// ============================================================================
// 获取无限搜索的结果（在 StopInfinite 后调用）
// ============================================================================

METHOD GetInfiniteResult() CLASS XQEngine
   RETURN ::cAsyncResult

// ============================================================================
// 停止无限搜索 - 发送 stop 并等待 bestmove
// ============================================================================

METHOD StopInfinite() CLASS XQEngine

   LOCAL cResponse
   LOCAL cBestMove := ""
   LOCAL aParts
   LOCAL nPos
   LOCAL nStartTime

   IF ! ::oState:IsThinking()
      RETURN ""
   ENDIF

   // 发送 stop 命令
   XQECI_Debug( XQECI_MODULE_CORE, "Sending stop command for infinite search" )
   ::SendCommandQuiet( "stop" )

   // 等待 bestmove（最多 5 秒）
   nStartTime := hb_MilliSeconds()
   DO WHILE ( hb_MilliSeconds() - nStartTime ) < 5000
      cResponse := ::ReadLine( 1000 )
      IF ! Empty( cResponse )
         ::ParseEngineOutput( cResponse )
         IF "bestmove" $ Lower( cResponse )
            aParts := HB_ATokens( cResponse, " " )
            nPos := AScan( aParts, {|p| Lower( p ) == "bestmove"} )
            IF nPos > 0 .AND. nPos + 1 <= Len( aParts )
               cBestMove := aParts[nPos + 1]
            ENDIF
            EXIT
         ENDIF
      ENDIF
   ENDDO

   // 保存结果
   ::cAsyncResult := cBestMove
   ::lAsyncRunning := .F.
   ::nAsyncState := 3  // 完成
   ::oState:SetState( ENGINE_STATE_RUNNING )

   RETURN cBestMove

// ============================================================================
// 设置MultiPV数量
// ============================================================================

METHOD SetMultiPV( nCount ) CLASS XQEngine

   LOCAL lResult

   IF ! ::oState:IsRunning()
      RETURN .F.
   ENDIF

   ::oState:SetMultiPV( nCount )

   // 设置引擎选项
   IF ::oState:lUCIProtocol
      lResult := ::SetOption( "MultiPV", LTrim( Str( nCount ) ) )
   ENDIF

   RETURN lResult

// ============================================================================
// 获取MultiPV候选着法
// ============================================================================

METHOD GetMultiPV() CLASS XQEngine

   LOCAL oResult := { => }

   HB_HSet( oResult, "count", Len( ::oState:aMultiPVMoves ) )
   HB_HSet( oResult, "moves", ::oState:aMultiPVMoves )
   HB_HSet( oResult, "scores", ::oState:aMultiPVScores )
   HB_HSet( oResult, "pvs", ::oState:aMultiPVPVs )

   RETURN oResult

// ============================================================================
// 设置Ponder模式
// ============================================================================

METHOD SetPonder( lEnable ) CLASS XQEngine

   LOCAL lResult

   IF ! ::oState:IsRunning()
      RETURN .F.
   ENDIF

   IF ! ::oState:lUCIProtocol
      RETURN .F.
   ENDIF

   ::oConfig:lPonder := lEnable
   lResult := ::SetOption( "Ponder", iif( lEnable, "true", "false" ) )

   RETURN lResult

// ============================================================================
// Ponder命中
// ============================================================================

METHOD PonderHit() CLASS XQEngine

   IF ! ::oState:IsThinking()
      RETURN .F.
   ENDIF

   ::SendCommand( "ponderhit" )

   RETURN .T.

// ============================================================================
// Ponder未命中
// ============================================================================

METHOD PonderMiss() CLASS XQEngine

   IF ! ::oState:IsThinking()
      RETURN .F.
   ENDIF

   ::StopThinking()

   RETURN .T.

// ============================================================================
// 获取Ponder着法
// ============================================================================

METHOD GetPonderMove() CLASS XQEngine
   RETURN ::oState:cPonderMove

// ============================================================================
// 获取WDL概率
// ============================================================================

METHOD GetWDL() CLASS XQEngine
   RETURN ::oState:GetWDL()

// ============================================================================
// 获取NNUE信息
// ============================================================================

METHOD GetNNUEInfo() CLASS XQEngine
   RETURN ::oState:GetNNUEInfo()

// ============================================================================
// 获取将死信息
// ============================================================================

METHOD GetMate() CLASS XQEngine
   RETURN ::oState:GetMate()

// ============================================================================
// 检查是否困毙
// ============================================================================

METHOD IsStalemate() CLASS XQEngine
   RETURN ::oState:IsStalemate()

// ============================================================================
// 设置NNUE评估文件
// ============================================================================

METHOD SetNNUEEvalFile( cFile ) CLASS XQEngine

   LOCAL lResult

   IF ! ::oState:IsRunning()
      RETURN .F.
   ENDIF

   IF ! ::oState:lUCIProtocol
      RETURN .F.
   ENDIF

   ::oConfig:cEvalFile := cFile
   lResult := ::SetOption( "EvalFile", cFile )

   RETURN lResult

// ============================================================================
// 获取状态
// ============================================================================

METHOD GetState() CLASS XQEngine
   RETURN ::oState

// ============================================================================
// 获取统计信息
// ============================================================================

METHOD GetStatistics() CLASS XQEngine
   RETURN ::oState:GetStatistics()

// ============================================================================
// 获取引擎信息
// ============================================================================

METHOD GetEngineInfo() CLASS XQEngine

   LOCAL oInfo := { => }

   oInfo["name"]    := ::oState:cEngineName
   oInfo["version"] := ::oState:cEngineVersion
   oInfo["author"]  := ::oState:cEngineAuthor
   oInfo["path"]    := ::oConfig:cEnginePath
   oInfo["state"]   := ::oState:GetStateName()

   RETURN oInfo

// ============================================================================
// 获取最后错误
// ============================================================================

METHOD GetLastError() CLASS XQEngine
   // 优先返回异步错误
   IF ! Empty( ::cAsyncError )
      RETURN ::cAsyncError
   ENDIF
   RETURN ::oState:GetLastError()

// ============================================================================
// 设置配置
// ============================================================================

METHOD SetConfig( oConfig ) CLASS XQEngine

   IF HB_ISOBJECT( oConfig )
      ::oConfig := oConfig
   ENDIF

   RETURN Self

// ============================================================================
// 设置信息回调
// ============================================================================

METHOD SetInfoCallback( bCallback ) CLASS XQEngine

   IF HB_ISBLOCK( bCallback )
      ::onInfoCallback := bCallback
   ENDIF

   RETURN Self

// ============================================================================
// 设置最佳着法回调
// ============================================================================

METHOD SetBestMoveCallback( bCallback ) CLASS XQEngine

   IF HB_ISBLOCK( bCallback )
      ::onBestMoveCallback := bCallback
   ENDIF

   RETURN Self

// ============================================================================
// 解析引擎输出
// ============================================================================

METHOD ParseEngineOutput( cLine ) CLASS XQEngine

   IF Empty( cLine )
      RETURN NIL
   ENDIF

   IF "info" $ Lower( cLine )
      ::ParseInfoLine( cLine )
   ELSEIF "bestmove" $ Lower( cLine )
      ::ParseBestMoveLine( cLine )
   ENDIF

   RETURN NIL

// ============================================================================
// 解析 info 行
// ============================================================================

METHOD ParseInfoLine( cLine ) CLASS XQEngine

   LOCAL aParts
   LOCAL nScore := 0
   LOCAL nDepth := 0
   LOCAL cPV := ""
   LOCAL nPos
   LOCAL lMate := .F.
   LOCAL nMate := 0
   LOCAL aPVParts
   LOCAL cBestMove

   aParts := HB_ATokens( cLine, " " )

   // 提取评分和将死信息
   nPos := AScan( aParts, {|p| Lower( p ) == "score"} )
   IF nPos > 0
      IF nPos + 1 <= Len( aParts )
         IF Lower( aParts[nPos + 1] ) == "mate"
            // 解析将死信息
            lMate := .T.
            IF nPos + 2 <= Len( aParts )
               nMate := Val( aParts[nPos + 2] )
            ENDIF
            ::oState:SetMate( lMate, nMate )
         ELSE
            // 解析普通评分
            nScore := Val( aParts[nPos + 1] )
            ::oState:SetMate( .F., 0 )
         ENDIF
      ENDIF
   ENDIF

   // 提取深度
   IF AScan( aParts, {|p| Lower( p ) == "depth"} ) > 0
      nDepth := Val( aParts[AScan( aParts, {|p| Lower( p ) == "depth"} ) + 1] )
   ENDIF

   // 提取主变例
   IF AScan( aParts, {|p| Lower( p ) == "pv"} ) > 0
      cPV := SubStr( cLine, At( "pv", cLine ) + 3 )
      cPV := AllTrim( cPV )
      
      // 提取第一个着法作为 bestMove，保存到 MultiPV
      aPVParts := HB_ATokens( cPV, " " )
      cBestMove := ""
      IF Len( aPVParts ) > 0
         cBestMove := aPVParts[1]
         // 保存 MultiPV 结果
         ::oState:AddMultiPVMove( cBestMove, nScore, cPV )
      ENDIF
   ENDIF

   // 更新状态
   ::oState:SetCurrentAnalysis( ::oState:cCurrentFEN, nScore, nDepth, 0, 0 )

   // 调用回调
   IF HB_ISBLOCK( ::onInfoCallback )
      Eval( ::onInfoCallback, nDepth, nScore, cPV )
   ENDIF

   RETURN NIL

// ============================================================================
// 解析 bestmove 行
// ============================================================================

METHOD ParseBestMoveLine( cLine ) CLASS XQEngine

   LOCAL aParts
   LOCAL cBestMove := ""
   LOCAL cPonder := ""

   aParts := HB_ATokens( cLine, " " )

   IF Len( aParts ) >= 2
      cBestMove := aParts[2]
   ENDIF

   IF Len( aParts ) >= 4 .AND. Lower( aParts[3] ) == "ponder"
      cPonder := aParts[4]
   ENDIF

   ::oState:SetBestMove( cBestMove, cPonder )

   // 调用回调
   IF HB_ISBLOCK( ::onBestMoveCallback )
      Eval( ::onBestMoveCallback, cBestMove, cPonder )
   ENDIF

   RETURN NIL

// ============================================================================
// 关闭引擎 - 显式资源释放（推荐使用）
// ============================================================================

METHOD Close() CLASS XQEngine

   IF ::lClosed
      RETURN .T.
   ENDIF

   // 取消异步操作
   IF ::lAsyncRunning
      ::CancelAsyncOperation()
   ENDIF

   // 停止引擎
   ::Stop()

   // 清理状态对象
   IF ::oState != NIL
      ::oState:hProcess := 0
      ::oState:hStdIn := 0
      ::oState:hStdOut := 0
      ::oState:hStdErr := 0
   ENDIF

   // 清空回调
   ::onInfoCallback := NIL
   ::onBestMoveCallback := NIL
   ::onAsyncCompleteCallback := NIL
   ::onAsyncErrorCallback := NIL

   // 标记已关闭
   ::lClosed := .T.

   RETURN .T.

// ============================================================================
// 检查是否已关闭
// ============================================================================

METHOD IsClosed() CLASS XQEngine
   RETURN ::lClosed

// ============================================================================
// 清理资源 - 向后兼容
// ============================================================================

METHOD Cleanup() CLASS XQEngine
   RETURN ::Close()

// ============================================================================
// 析构函数 - 不保证被调用，请使用 Close()
// ============================================================================

METHOD Destructor() CLASS XQEngine
   IF ! ::lClosed
      ::Close()
   ENDIF
   RETURN NIL

// ============================================================================
// 异步分析方法 - 非阻塞分析
// ============================================================================
/**
 * 异步分析指定局面（非阻塞）
 *
 * 功能:
 * - 启动异步分析任务
 * - 立即返回，不等待分析完成
 * - 通过回调函数获取结果
 * - 支持进度跟踪
 * - 使用锁机制防止并发
 *
 * 参数:
 * - cFEN (字符串): 局面描述
 *   - "startpos": 初始局面
 *   - FEN 字符串: 如 "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
 * - nTimeLimit (数值): 时间限制（毫秒）
 *   - 默认值: 配置中的 nDefaultTime
 *   - 示例: 5000 (5秒)
 * - nDepthLimit (数值): 深度限制
 *   - 默认值: 0 (不限制)
 *   - 示例: 10 (搜索到深度10)
 *
 * 返回值:
 * - .T. (逻辑值): 异步任务启动成功
 * - .F. (逻辑值): 异步任务启动失败
 *
 * 异步状态机:
 * - 0: 空闲（无异步任务）
 * - 1: 初始化（正在设置局面）
 * - 2: 思考中（引擎正在分析）
 * - 3: 完成（分析完成，结果可用）
 * - 4: 错误（发生错误）
 *
 * 回调函数:
 * - SetAsyncCompleteCallback( {|cResult| ? "结果:", cResult } )
 * - SetAsyncErrorCallback( {|cError| ? "错误:", cError } )
 * - SetInfoCallback( {|nDepth, nScore, cPV| ? "深度:", nDepth, "评分:", nScore } )
 *
 * 使用方法:
 * 1. 设置回调函数
 * 2. 调用 AnalyzeAsync() 启动分析
 * 3. 定期调用 CheckAsyncProgress() 检查进度
 * 4. 通过回调获取结果
 *
 * 注意事项:
 * - 必须先设置回调函数
 * - 同一时间只能有一个异步任务
 * - 使用锁机制防止并发启动
 * - 需要定期调用 CheckAsyncProgress() 获取进度
 * - 超时时间可通过 SetAsyncTimeout() 设置（默认60秒）
 *
 * 使用示例:
 * LOCAL oEngine := XQEngine():New()
 * oEngine:Initialize( "./pikafish" )
 * oEngine:Start()
 * hb_idleSleep( 2.0 )
 *
 * // 设置回调函数
 * oEngine:SetAsyncCompleteCallback( {|cResult| ? "最佳着法:", cResult } )
 * oEngine:SetAsyncErrorCallback( {|cError| ? "错误:", cError } )
 * oEngine:SetInfoCallback( {|nDepth, nScore, cPV| ? "深度:", nDepth, "评分:", nScore } )
 *
 * // 启动异步分析
 * IF oEngine:AnalyzeAsync( "startpos", 5000 )
 *    ? "异步分析已启动"
 *
 *    // 轮询进度
 *    DO WHILE oEngine:IsAsyncRunning()
 *       ? "进度:", oEngine:GetAsyncProgress(), "%"
 *       hb_idleSleep( 0.1 )
 *    ENDDO
 *
 *    ? "分析完成"
 * ENDIF
 *
 * // 或者使用 WaitAsync() 等待完成
 * IF oEngine:AnalyzeAsync( "startpos", 5000 )
 *    LOCAL cResult := oEngine:WaitAsync( 10000 )
 *    ? "最佳着法:", cResult
 * ENDIF
 */
METHOD AnalyzeAsync( cFEN, nTimeLimit, nDepthLimit ) CLASS XQEngine

   LOCAL cCommand
   LOCAL lResult

   // 检查是否已关闭
   IF ::lClosed
      ::oState:SetError( "引擎已关闭", 99 )
      IF HB_ISBLOCK( ::onAsyncErrorCallback )
         Eval( ::onAsyncErrorCallback, "引擎已关闭" )
      ENDIF
      RETURN .F.
   ENDIF

   // 检查是否就绪
   IF ! ::oState:IsReady()
      IF HB_ISBLOCK( ::onAsyncErrorCallback )
         Eval( ::onAsyncErrorCallback, "引擎未就绪" )
      ENDIF
      RETURN .F.
   ENDIF

   // 获取锁（简单自旋锁）
   IF ! ::AsyncLock()
      IF HB_ISBLOCK( ::onAsyncErrorCallback )
         Eval( ::onAsyncErrorCallback, "已有异步操作正在运行" )
      ENDIF
      RETURN .F.
   ENDIF

   // 设置异步状态
   ::lAsyncRunning := .T.
   ::cAsyncResult := ""
   ::cAsyncError := ""
   ::nAsyncStartTime := GetTickCount()
   ::nAsyncState := 1  // 初始化
   ::nAsyncProgress := 0
   ::cAsyncInfo := ""

   // 设置局面
   IF ! ::SetPosition( cFEN )
      ::AsyncUnlock()
      IF HB_ISBLOCK( ::onAsyncErrorCallback )
         Eval( ::onAsyncErrorCallback, "设置局面失败" )
      ENDIF
      RETURN .F.
   ENDIF

   // 构建 go 命令
   cCommand := "go"

   IF nDepthLimit != NIL .AND. nDepthLimit > 0
      cCommand += " depth " + LTrim( Str( nDepthLimit ) )
   ENDIF

   IF nTimeLimit != NIL .AND. nTimeLimit > 0
      IF ::oState:lUCIProtocol
         cCommand += " movetime " + LTrim( Str( nTimeLimit ) )
      ELSE
         cCommand += " time " + LTrim( Str( nTimeLimit ) )
      ENDIF
   ENDIF

   // 发送命令
   ::oState:SetState( ENGINE_STATE_THINKING )
   ::nAsyncState := 2  // 思考中
   lResult := ::SendCommand( cCommand )

   IF ! lResult
      ::AsyncUnlock()
      IF HB_ISBLOCK( ::onAsyncErrorCallback )
         Eval( ::onAsyncErrorCallback, "发送分析命令失败" )
      ENDIF
      RETURN .F.
   ENDIF

   RETURN .T.

// ============================================================================
// 检查异步操作进度 - 改进版本
// ============================================================================

METHOD CheckAsyncProgress() CLASS XQEngine

   LOCAL cResponse
   LOCAL cBestMove
   LOCAL aParts
   LOCAL nPos
   LOCAL nElapsed
   LOCAL nDepth := 0

   // 如果不在运行，返回结果
   IF ! ::lAsyncRunning
      RETURN ::cAsyncResult
   ENDIF

   // 检查超时
   nElapsed := GetTickCount() - ::nAsyncStartTime
   IF nElapsed > ::nAsyncTimeout
      ::cAsyncError := "异步操作超时 (" + LTrim( Str( nElapsed ) ) + "ms)"
      ::nAsyncState := 4  // 错误
      ::CancelAsyncOperation()
      IF HB_ISBLOCK( ::onAsyncErrorCallback )
         Eval( ::onAsyncErrorCallback, ::cAsyncError )
      ENDIF
      RETURN ""
   ENDIF

   // 尝试读取数据
   cResponse := ::ReadLine( ::nAsyncPollInterval )

   IF Empty( cResponse )
      RETURN ""  // 还没有数据
   ENDIF

   // 解析 info 信息
   IF "info" $ Lower( cResponse )
      ::cAsyncInfo := cResponse
      // 尝试提取深度作为进度
      nPos := At( " depth ", Lower( cResponse ) )
      IF nPos > 0
         nDepth := Val( SubStr( cResponse, nPos + 7 ) )
         // 假设最大深度为 50，计算进度
         ::nAsyncProgress := Min( 100, Int( nDepth * 2 ) )
      ENDIF
   ENDIF

   // 解析输出
   ::ParseEngineOutput( cResponse )

   // 检查是否是最佳着法
   IF "bestmove" $ Lower( cResponse )
      aParts := HB_ATokens( cResponse, " " )
      nPos := AScan( aParts, {|p| Lower( p ) == "bestmove"} )
      IF nPos > 0 .AND. nPos + 1 <= Len( aParts )
         cBestMove := aParts[nPos + 1]
      ENDIF

      // 异步操作完成
      ::cAsyncResult := cBestMove
      ::nAsyncState := 3  // 完成
      ::nAsyncProgress := 100
      ::lAsyncRunning := .F.
      ::oState:SetState( ENGINE_STATE_RUNNING )
      ::AsyncUnlock()

      // 调用完成回调
      IF HB_ISBLOCK( ::onAsyncCompleteCallback )
         Eval( ::onAsyncCompleteCallback, cBestMove )
      ENDIF

      RETURN cBestMove
   ENDIF

   RETURN ""  // 还在进行中

// ============================================================================
// 等待异步操作完成
// ============================================================================

METHOD WaitAsync( nTimeout ) CLASS XQEngine

   LOCAL nStartTime
   LOCAL cResult := ""

   IF nTimeout == NIL
      nTimeout := ::nAsyncTimeout
   ENDIF

   nStartTime := GetTickCount()

   DO WHILE ::lAsyncRunning .AND. ( GetTickCount() - nStartTime ) < nTimeout
      cResult := ::CheckAsyncProgress()
      IF ! Empty( cResult )
         EXIT
      ENDIF
      hb_idleSleep( 0.05 )  // 50ms 间隔
   ENDDO

   // 如果超时还在运行，取消
   IF ::lAsyncRunning
      ::CancelAsyncOperation()
   ENDIF

   RETURN cResult

// ============================================================================
// 设置异步超时时间
// ============================================================================

METHOD SetAsyncTimeout( nTimeout ) CLASS XQEngine
   IF HB_ISNUMERIC( nTimeout ) .AND. nTimeout > 0
      ::nAsyncTimeout := nTimeout
   ENDIF
   RETURN Self

// ============================================================================
// 获取异步进度（0-100）
// ============================================================================

METHOD GetAsyncProgress() CLASS XQEngine
   RETURN ::nAsyncProgress

// ============================================================================
// 获取异步info信息
// ============================================================================

METHOD GetAsyncInfo() CLASS XQEngine
   RETURN ::cAsyncInfo

// ============================================================================
// 获取异步结果
// ============================================================================

METHOD GetAsyncResult() CLASS XQEngine
   RETURN ::cAsyncResult

// ============================================================================
// 检查是否在执行异步操作
// ============================================================================

METHOD IsAsyncRunning() CLASS XQEngine
   RETURN ::lAsyncRunning

// ============================================================================
// 取消异步操作 - 改进版本
// ============================================================================

METHOD CancelAsyncOperation() CLASS XQEngine

   IF ! ::lAsyncRunning
      RETURN .T.
   ENDIF

   // 如果引擎正在思考，发送 stop 命令
   IF ::oState:IsThinking()
      ::SendCommandQuiet( "stop" )
      hb_idleSleep( 0.1 )
   ENDIF

   ::lAsyncRunning := .F.
   ::nAsyncState := 0  // 空闲
   ::cAsyncResult := ""
   ::cAsyncError := "操作已取消"
   ::oState:SetState( ENGINE_STATE_RUNNING )
   ::AsyncUnlock()

   RETURN .T.

// ============================================================================
// 异步锁操作（简单实现）
// ============================================================================

METHOD AsyncLock() CLASS XQEngine
   LOCAL nCount := 0
   // 简单自旋锁，最多等待100次
   DO WHILE ::nAsyncLock == 1 .AND. nCount < 100
      hb_idleSleep( 0.01 )
      nCount++
   ENDDO
   IF ::nAsyncLock == 1
      RETURN .F.
   ENDIF
   ::nAsyncLock := 1
   RETURN .T.

METHOD AsyncUnlock() CLASS XQEngine
   ::nAsyncLock := 0
   RETURN Self

// ============================================================================
// 设置异步完成回调
// ============================================================================

METHOD SetAsyncCompleteCallback( bCallback ) CLASS XQEngine

   IF HB_ISBLOCK( bCallback )
      ::onAsyncCompleteCallback := bCallback
   ENDIF

   RETURN Self

// ============================================================================
// 设置异步错误回调
// ============================================================================

METHOD SetAsyncErrorCallback( bCallback ) CLASS XQEngine

   IF HB_ISBLOCK( bCallback )
      ::onAsyncErrorCallback := bCallback
   ENDIF

   RETURN Self

// ============================================================================
// 获取当前时间戳(毫秒) - 定义在 xqengine_utils.prg 中
// ============================================================================