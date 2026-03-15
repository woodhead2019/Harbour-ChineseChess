/*
 * demo.prg
 * XQEngine 综合演示程序
 *
 * 功能:
 * - 演示引擎初始化、配置、启动、停止流程
 * - 演示用户与AI对弈的基本逻辑
 * - 演示所有引擎功能（同步、异步、MultiPV、Ponder等）
 * - 演示特殊局面处理（将死、困毙）
 * - 演示错误处理和资源管理
 *
 * 使用方法:
 * ./demo
 */

#include "hbclass.ch"

// ============================================================================
// 全局变量
// ============================================================================

STATIC oEngine := NIL  // 引擎实例
STATIC cCurrentFEN := ""  // 当前局面FEN
STATIC lGameRunning := .F.  // 游戏是否运行中

// ============================================================================
// 主程序
// ============================================================================

PROCEDURE Main()

   LOCAL nChoice

   ? "========================================"
   ? "XQEngine 综合演示程序 v2.2"
   ? "========================================"
   ? ""
   ? "本程序演示中国象棋引擎的完整使用方式"
   ? "包括引擎管理、用户对弈、功能演示等"
   ? ""

   // 初始化引擎
   IF ! InitializeEngine()
      RETURN
   ENDIF

   // 主菜单循环
   DO WHILE .T.
      ShowMainMenu()
      nChoice := GetMenuChoice( 0, 9 )

      DO CASE
      CASE nChoice == 0
         EXIT

      CASE nChoice == 1
         PlayGame()

      CASE nChoice == 2
         DemoBasicFeatures()

      CASE nChoice == 3
         DemoAdvancedFeatures()

      CASE nChoice == 4
         DemoAsyncFeatures()

      CASE nChoice == 5
         DemoMultiPV()

      CASE nChoice == 6
         DemoSpecialPositions()

      CASE nChoice == 7
         DemoEngineOptions()

      CASE nChoice == 8
         ShowEngineStatistics()

      CASE nChoice == 9
         ShowHelp()
      ENDCASE

      IF nChoice != 0
         ? ""
         ? "按任意键继续..."
         Inkey( 0 )
         CLS
      ENDIF
   ENDDO

   // 清理引擎
   CleanupEngine()

   ? ""
   ? "========================================"
   ? "感谢使用 XQEngine"
   ? "========================================"

   RETURN

// ============================================================================
// 初始化引擎
// ============================================================================

FUNCTION InitializeEngine()

   LOCAL oConfig

   ? "========================================"
   ? "初始化引擎"
   ? "========================================"
   ? ""

   // 创建引擎实例
   ? "1. 创建引擎实例..."
   oEngine := XQEngine():New()

   // 创建配置
   ? "2. 创建引擎配置..."
   oConfig := EngineConfig():New()
   oConfig:SetEnginePath( "./xqengine/pikafish" )
   oConfig:SetHashSize( 256 )
   oConfig:SetThreads( 2 )
   oConfig:SetMultiPV( 3 )
   oConfig:SetPonder( .T. )
   oConfig:SetShowWDL( .T. )

   IF ! oConfig:Validate()
      ? "错误: 引擎配置验证失败"
      RETURN .F.
   ENDIF

   ? "  Hash:", oConfig:nHashSize, "MB"
   ? "  Threads:", oConfig:nThreads
   ? "  MultiPV:", oConfig:nMultiPV
   ? ""

   // 初始化引擎
   ? "3. 初始化引擎..."
   oEngine:Initialize( "./xqengine/pikafish" )

   // 启动引擎
   ? "4. 启动引擎..."
   IF ! oEngine:Start()
      ? "错误: 引擎启动失败"
      ? "错误信息:", oEngine:GetLastError()
      RETURN .F.
   ENDIF

   // 等待引擎完全初始化
   ? "5. 等待引擎初始化..."
   hb_idleSleep( 2.0 )

   // 应用配置
   ? "6. 应用配置到引擎..."
   IF oEngine:ApplyConfig()
      ? "  配置应用成功"
   ELSE
      ? "  警告: 配置应用失败"
   ENDIF

   // 等待引擎就绪
   ? "7. 等待引擎就绪..."
   hb_idleSleep( 1.0 )

   IF ! oEngine:IsRunning()
      ? "错误: 引擎未运行"
      RETURN .F.
   ENDIF

   ? ""
   ? "引擎初始化完成！"
   ? ""

   RETURN .T.

// ============================================================================
// 清理引擎
// ============================================================================

PROCEDURE CleanupEngine()

   IF oEngine != NIL
      ? "清理引擎资源..."

      IF oEngine:IsRunning()
         oEngine:Stop()
      ENDIF

      oEngine := NIL
   ENDIF

   RETURN

// ============================================================================
// 显示主菜单
// ============================================================================

PROCEDURE ShowMainMenu()

   ? "========================================"
   ? "主菜单"
   ? "========================================"
   ? ""
   ? "1. 用户与AI对弈"
   ? "2. 基础功能演示"
   ? "3. 高级功能演示"
   ? "4. 异步功能演示"
   ? "5. MultiPV模式演示"
   ? "6. 特殊局面演示"
   ? "7. 引擎选项演示"
   ? "8. 引擎统计信息"
   ? "9. 帮助信息"
   ? "0. 退出程序"
   ? ""
   ? "请选择 (0-9):"

   RETURN

// ============================================================================
// 获取菜单选择
// ============================================================================

FUNCTION GetMenuChoice( nMin, nMax )

   LOCAL cInput
   LOCAL nChoice

   ACCEPT ">>>" TO cInput
   cInput := AllTrim( cInput )

   IF Empty( cInput )
      RETURN nMin
   ENDIF

   IF IsDigit( cInput )
      nChoice := Val( cInput )
      IF nChoice >= nMin .AND. nChoice <= nMax
         RETURN nChoice
      ENDIF
   ENDIF

   RETURN nMin

// ============================================================================
// 用户与AI对弈
// ============================================================================

PROCEDURE PlayGame()

   LOCAL cUserMove
   LOCAL cAIMove
   LOCAL lGameOver := .F.
   LOCAL oMate
   LOCAL oWDL
   LOCAL nMoveCount := 0
   LOCAL cMoves := ""

   CLS
   ? "========================================"
   ? "用户与AI对弈"
   ? "========================================"
   ? ""
   ? "说明:"
   ? "  - 用户执红，AI执黑"
   ? "  - 输入格式: h2e2 (从h2到e2)"
   ? "  - 输入 'quit' 退出对弈"
   ? "  - 输入 'fen' 查看当前局面"
   ? ""

   // 开始新游戏
   oEngine:NewGame()
   cCurrentFEN := "startpos"
   lGameRunning := .T.
   nMoveCount := 0
   cMoves := ""

   ? "对弈开始！"
   ? ""

   // 对弈循环
   DO WHILE ! lGameOver .AND. lGameRunning
      nMoveCount++

      // 显示当前局面
      ? "========================================"
      ? "回合", nMoveCount
      ? "========================================"
      ? ""
      ? "当前局面:", cCurrentFEN
      ? ""

      // 用户走棋
      DO WHILE .T.
         ? "请输入您的走法 (或 quit/fen):"
         ACCEPT ">>>" TO cUserMove
         cUserMove := AllTrim( cUserMove )

         IF Lower( cUserMove ) == "quit"
            lGameRunning := .F.
            EXIT
         ENDIF

         IF Lower( cUserMove ) == "fen"
            ? cCurrentFEN
            LOOP
         ENDIF

         IF ValidateMove( cUserMove )
            EXIT
         ELSE
            ? "走法格式错误，请重新输入 (例如: h2e2)"
         ENDIF
      ENDDO

      IF ! lGameRunning
         EXIT
      ENDIF

      ? "您的走法:", cUserMove

      // 更新局面
      IF ! UpdatePosition( cUserMove )
         ? "错误: 无法更新局面"
         lGameRunning := .F.
         EXIT
      ENDIF

      // 检查是否将死
      oMate := oEngine:GetMate()
      IF oMate["mate"]
         ? ""
         ? "========================================"
         ? "游戏结束: 将死！"
         ? "========================================"
         IF oMate["steps"] > 0
            ? "AI", iif( oMate["steps"] > 0, "将", "被" ), "死，", Abs( oMate["steps"] ), "步"
         ENDIF
         lGameOver := .T.
         EXIT
      ENDIF

      // 检查是否困毙
      IF oEngine:IsStalemate()
         ? ""
         ? "========================================"
         ? "游戏结束: 困毙！"
         ? "========================================"
         lGameOver := .T.
         EXIT
      ENDIF

      ? ""
      ? "AI正在思考..."

      // AI走棋
      cAIMove := oEngine:Analyze( cCurrentFEN, 3000, 0 )

      IF Empty( cAIMove )
         ? "错误: AI无法生成走法"
         ? "错误信息:", oEngine:GetLastError()
         lGameRunning := .F.
         EXIT
      ENDIF

      ? "AI走法:", cAIMove

      // 更新局面
      IF ! UpdatePosition( cAIMove )
         ? "错误: 无法更新局面"
         lGameRunning := .F.
         EXIT
      ENDIF

      // 显示分析信息
      oWDL := oEngine:GetWDL()
      IF ! Empty( oWDL )
         ? "胜率评估: Win", oWDL["win"], "%  Draw", oWDL["draw"], "%  Loss", oWDL["loss"], "%"
      ENDIF

      ? ""

      // 检查是否将死
      oMate := oEngine:GetMate()
      IF oMate["mate"]
         ? ""
         ? "========================================"
         ? "游戏结束: 将死！"
         ? "========================================"
         IF oMate["steps"] > 0
            ? "AI", iif( oMate["steps"] > 0, "将", "被" ), "死，", Abs( oMate["steps"] ), "步"
         ENDIF
         lGameOver := .T.
         EXIT
      ENDIF

      // 检查是否困毙
      IF oEngine:IsStalemate()
         ? ""
         ? "========================================"
         ? "游戏结束: 困毙！"
         ? "========================================"
         lGameOver := .T.
         EXIT
      ENDIF

      // 限制回合数防止无限循环
      IF nMoveCount >= 100
         ? ""
         ? "========================================"
         ? "游戏结束: 回合数达到上限"
         ? "========================================"
         lGameOver := .T.
         EXIT
      ENDIF

   ENDDO

   ? ""
   ? "对弈结束！"

   RETURN

// ============================================================================
// 验证走法格式
// ============================================================================

FUNCTION ValidateMove( cMove )

   // 参数类型检查：确保 cMove 是有效的字符串类型
   IF ValType( cMove ) != "C"
      RETURN .F.
   ENDIF

   // 先检查长度，避免数组越界错误
   IF Len( cMove ) != 4
      RETURN .F.
   ENDIF

   // 使用 SubStr 函数访问字符串字符，避免数组访问错误
   RETURN SubStr( cMove, 1, 1 ) >= "a" .AND. SubStr( cMove, 1, 1 ) <= "i" .AND. ;
          SubStr( cMove, 2, 1 ) >= "0" .AND. SubStr( cMove, 2, 1 ) <= "9" .AND. ;
          SubStr( cMove, 3, 1 ) >= "a" .AND. SubStr( cMove, 3, 1 ) <= "i" .AND. ;
          SubStr( cMove, 4, 1 ) >= "0" .AND. SubStr( cMove, 4, 1 ) <= "9"

// ============================================================================
// 更新局面
// ============================================================================

FUNCTION UpdatePosition( cMove )

   // 在实际应用中，这里应该有完整的象棋逻辑来验证和更新局面
   // 这里简化处理，只记录走法

   IF cCurrentFEN == "startpos"
      cCurrentFEN := "startpos moves " + cMove
   ELSE
      cCurrentFEN += " " + cMove
   ENDIF

   RETURN .T.

// ============================================================================
// 基础功能演示
// ============================================================================

PROCEDURE DemoBasicFeatures()

   LOCAL cFEN
   LOCAL cBestMove
   LOCAL oInfo

   CLS
   ? "========================================"
   ? "基础功能演示"
   ? "========================================"
   ? ""

   // 演示1: 获取引擎信息
   ? "1. 获取引擎信息..."
   oInfo := oEngine:GetEngineInfo()
   ? "  引擎名称:", oInfo["name"]
   ? "  引擎版本:", oInfo["version"]
   ? "  引擎作者:", oInfo["author"]
   ? "  引擎状态:", oInfo["state"]
   ? ""

   // 演示2: 分析开局局面
   ? "2. 分析开局局面..."
   cFEN := "startpos"
   ? "  FEN:", cFEN
   cBestMove := oEngine:Analyze( cFEN, 3000, 0 )
   ? "  最佳走法:", iif( Empty( cBestMove ), "(无)", cBestMove )
   ? ""

   // 演示3: 分析指定局面
   ? "3. 分析指定局面..."
   cFEN := "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
   ? "  FEN:", cFEN
   cBestMove := oEngine:Analyze( cFEN, 3000, 0 )
   IF Empty( cBestMove )
      ? "  最佳走法: (无 - 超时或错误)"
      ? "  错误信息:", oEngine:GetLastError()
   ELSE
      ? "  最佳走法:", cBestMove
   ENDIF
   ? ""

   ? "基础功能演示完成！"

   RETURN

// ============================================================================
// 高级功能演示
// ============================================================================

PROCEDURE DemoAdvancedFeatures()

   LOCAL oParams
   LOCAL cPonderMove
   LOCAL oWDL
   LOCAL oNNUE
   LOCAL cBestMove

   CLS
   ? "========================================"
   ? "高级功能演示"
   ? "========================================"
   ? ""

   // 演示1: Ponder模式
   ? "1. Ponder模式..."
   oEngine:SetPonder( .T. )
   hb_idleSleep( 0.5 )
   ? "  分析开局局面（启用Ponder）..."
   cBestMove := oEngine:Analyze( "startpos", 3000, 0 )
   ? "  最佳走法:", cBestMove

   cPonderMove := oEngine:GetPonderMove()
   IF Empty( cPonderMove )
      ? "  无Ponder着法"
   ELSE
      ? "  Ponder着法:", cPonderMove
   ENDIF
   ? ""

   // 演示2: WDL概率
   ? "2. WDL概率..."
   oEngine:SetOption( "UCI_ShowWDL", "true" )
   hb_idleSleep( 0.5 )
   ? "  分析局面（获取WDL概率）..."
   oEngine:Analyze( "startpos", 3000, 0 )

   oWDL := oEngine:GetWDL()
   ? "  Win:", oWDL["win"]
   ? "  Draw:", oWDL["draw"]
   ? "  Loss:", oWDL["loss"]
   ? ""

   // 演示3: NNUE信息
   ? "3. NNUE信息..."
   oNNUE := oEngine:GetNNUEInfo()
   ? "  启用:", oNNUE["enabled"]
   ? "  文件:", oNNUE["file"]
   ? "  大小:", oNNUE["size"]
   ? ""

   // 演示4: 棋钟控制
   ? "4. 棋钟控制..."
   oParams := GoParams():New()
   oParams:SetWtime( 300000 )  // 5分钟
   oParams:SetBtime( 300000 )
   oParams:SetWinc( 2000 )    // 每步加2秒
   oParams:SetBinc( 2000 )

   ? "  使用棋钟参数分析..."
   cBestMove := oEngine:AnalyzeWithParams( "startpos", oParams )
   ? "  最佳走法:", cBestMove
   ? ""

   // 演示5: 杀棋搜索
   ? "5. 杀棋搜索..."
   oParams := GoParams():New()
   oParams:SetMate( 3 )

   cBestMove := oEngine:AnalyzeWithParams( "startpos", oParams )
   IF Empty( cBestMove )
      ? "  未找到杀棋路径（开局局面正常）"
   ELSE
      ? "  杀棋路径:", cBestMove
   ENDIF
   ? ""

   // 演示6: 节点数限制
   ? "6. 节点数限制..."
   oParams := GoParams():New()
   oParams:SetNodes( 100000 )

   cBestMove := oEngine:AnalyzeWithParams( "startpos", oParams )
   ? "  最佳走法:", cBestMove
   ? ""

   ? "高级功能演示完成！"

   RETURN

// ============================================================================
// 异步功能演示
// ============================================================================

PROCEDURE DemoAsyncFeatures()

   LOCAL cFEN
   LOCAL nLoop
   LOCAL lDone
   LOCAL cResult

   CLS
   ? "========================================"
   ? "异步功能演示"
   ? "========================================"
   ? ""

   // 设置回调函数
   ? "设置回调函数..."
   oEngine:SetAsyncCompleteCallback( {|cMove| OnAsyncComplete( cMove ) } )
   oEngine:SetAsyncErrorCallback( {|cError| OnAsyncError( cError ) } )
   ? ""

   // 演示1: 异步分析
   ? "1. 异步分析..."
   cFEN := "startpos"
   ? "  开始分析局面:", cFEN

   IF oEngine:AnalyzeAsync( cFEN, 3000, 0 )
      ? "  异步分析已启动，不阻塞主线程"
      ? ""

      // 在分析过程中可以做其他事情
      ? "  --- 在分析过程中进行其他操作 ---"
      FOR nLoop := 1 TO 30
         cResult := oEngine:CheckAsyncProgress()

         IF nLoop % 5 == 0
            ? "  [", nLoop, "/30] 检查进度: "
            IF ! Empty( cResult )
               ? "已完成，结果:", cResult
            ELSE
               IF oEngine:IsAsyncRunning()
                  ? "正在分析中..."
               ELSE
                  ? "分析已结束"
               ENDIF
            ENDIF
         ENDIF

         hb_idleSleep( 0.1 )
      NEXT
      ? ""

      // 等待分析完成
      lDone := .F.
      DO WHILE ! lDone .AND. nLoop < 100
         cResult := oEngine:CheckAsyncProgress()

         IF ! oEngine:IsAsyncRunning()
            lDone := .T.
            ? "  分析完成，结果:", cResult
         ENDIF

         hb_idleSleep( 0.1 )
         nLoop++
      ENDDO
   ELSE
      ? "  启动异步分析失败"
      ? "  错误信息:", oEngine:GetLastError()
   ENDIF

   ? ""

   // 演示2: 取消异步操作
   ? "2. 取消异步操作..."
   cFEN := "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
   ? "  开始分析局面:", cFEN

   IF oEngine:AnalyzeAsync( cFEN, 5000, 0 )
      ? "  异步分析已启动"
      ? ""

      ? "  等待1秒后取消操作..."
      hb_idleSleep( 1.0 )

      IF oEngine:CancelAsyncOperation()
         ? "  操作已成功取消"
      ELSE
         ? "  取消操作失败"
      ENDIF

      IF oEngine:IsAsyncRunning()
         ? "  警告: 异步操作仍在运行"
      ELSE
         ? "  确认: 异步操作已停止"
      ENDIF
   ENDIF

   ? ""
   ? "异步功能演示完成！"

   RETURN

// ============================================================================
// 异步完成回调
// ============================================================================

PROCEDURE OnAsyncComplete( cMove )

   ? ""
   ? "  >>> 异步分析完成"
   ? "      最佳走法:", cMove
   ? ""

   RETURN

// ============================================================================
// 异步错误回调
// ============================================================================

PROCEDURE OnAsyncError( cError )

   ? ""
   ? "  >>> 异步分析错误"
   ? "      错误信息:", cError
   ? ""

   RETURN

// ============================================================================
// MultiPV模式演示
// ============================================================================

PROCEDURE DemoMultiPV()

   LOCAL oMultiPV
   LOCAL cBestMove
   LOCAL i

   CLS
   ? "========================================"
   ? "MultiPV模式演示"
   ? "========================================"
   ? ""

   // 设置MultiPV
   ? "设置MultiPV为5..."
   oEngine:SetMultiPV( 5 )
   hb_idleSleep( 0.5 )
   ? ""

   // 分析开局局面
   ? "分析开局局面（获取前5个最佳走法）..."
   cBestMove := oEngine:Analyze( "startpos", 5000, 0 )
   IF Empty( cBestMove )
      ? "  最佳走法: (无 - 超时或错误)"
      ? "  错误信息:", oEngine:GetLastError()
   ELSE
      ? "  最佳走法:", cBestMove
   ENDIF
   ? ""

   // 获取候选着法
   ? "获取候选着法..."
   oMultiPV := oEngine:GetMultiPV()
   ? "  候选着法数量:", oMultiPV["count"]
   IF oMultiPV["count"] > 0
      FOR i := 1 TO Len( oMultiPV["moves"] )
         ? "  [" + hb_ntos( i ) + "]", oMultiPV["moves"][i], "评分:", oMultiPV["scores"][i]
      NEXT
   ENDIF
   ? ""

   ? "MultiPV模式演示完成！"

   RETURN

// ============================================================================
// 特殊局面演示
// ============================================================================

PROCEDURE DemoSpecialPositions()

   LOCAL cFEN
   LOCAL cBestMove
   LOCAL oMate

   CLS
   ? "========================================"
   ? "特殊局面演示"
   ? "========================================"
   ? ""

   // 测试1: 将死检测
   ? "1. 将死检测..."
   cFEN := "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
   ? "  FEN:", cFEN
   cBestMove := oEngine:Analyze( cFEN, 5000, 0 )

   IF Empty( cBestMove )
      ? "  最佳走法: (无)"
   ELSE
      ? "  最佳走法:", cBestMove
   ENDIF

   oMate := oEngine:GetMate()
   IF oMate["mate"]
      ? "  检测到将死:", oMate["steps"], "步"
   ELSE
      ? "  未检测到将死"
   ENDIF
   ? ""

   // 测试2: 困毙检测
   ? "2. 困毙检测..."
   cFEN := "4k4/9/9/9/9/9/9/9/4K4 w - - 0 1"
   ? "  FEN:", cFEN
   cBestMove := oEngine:Analyze( cFEN, 5000, 0 )

   IF Empty( cBestMove )
      ? "  最佳走法: (无)"
   ELSE
      ? "  最佳走法:", cBestMove
   ENDIF

   IF oEngine:IsStalemate()
      ? "  检测到困毙"
   ELSE
      ? "  未检测到困毙"
   ENDIF
   ? ""

   ? "特殊局面演示完成！"

   RETURN

// ============================================================================
// 引擎选项演示
// ============================================================================

PROCEDURE DemoEngineOptions()

   CLS
   ? "========================================"
   ? "引擎选项演示"
   ? "========================================"
   ? ""

   ? "设置Hash为128MB..."
   oEngine:SetOption( "Hash", "128" )

   ? "设置Threads为4..."
   oEngine:SetOption( "Threads", "4" )

   ? "启用Ponder模式..."
   oEngine:SetOption( "Ponder", "true" )

   ? "设置MultiPV为3..."
   oEngine:SetOption( "MultiPV", "3" )

   ? "启用WDL显示..."
   oEngine:SetOption( "UCI_ShowWDL", "true" )

   hb_idleSleep( 0.5 )
   ? ""

   ? "清除哈希表..."
   IF oEngine:ClearHash()
      ? "  哈希表已清除"
   ENDIF

   ? "开始新游戏..."
   IF oEngine:NewGame()
      ? "  新游戏已开始"
   ENDIF
   ? ""

   ? "引擎选项演示完成！"

   RETURN

// ============================================================================
// 显示引擎统计信息
// ============================================================================

PROCEDURE ShowEngineStatistics()

   LOCAL oStats

   CLS
   ? "========================================"
   ? "引擎统计信息"
   ? "========================================"
   ? ""

   oStats := oEngine:GetStatistics()
   ? "状态:", oStats["state"]
   ? "命令数:", oStats["commandCount"]
   ? "响应数:", oStats["responseCount"]
   ? "错误数:", oStats["errorCount"]
   ? "运行时间:", oStats["uptime"], "ms"
   ? "引擎名称:", oStats["engineName"]
   ? "引擎版本:", oStats["engineVersion"]
   ? ""

   RETURN

// ============================================================================
// 显示帮助信息
// ============================================================================

PROCEDURE ShowHelp()

   CLS
   ? "========================================"
   ? "帮助信息"
   ? "========================================"
   ? ""
   ? "XQEngine 综合演示程序使用说明："
   ? ""
   ? "1. 用户与AI对弈"
   ? "   - 用户执红，AI执黑"
   ? "   - 输入走法格式: h2e2"
   ? "   - 输入quit退出对弈"
   ? ""
   ? "2. 基础功能演示"
   ? "   - 获取引擎信息"
   ? "   - 分析开局局面"
   ? "   - 分析指定局面"
   ? ""
   ? "3. 高级功能演示"
   ? "   - Ponder模式"
   ? "   - WDL概率"
   ? "   - NNUE信息"
   ? "   - 棋钟控制"
   ? "   - 杀棋搜索"
   ? "   - 节点数限制"
   ? ""
   ? "4. 异步功能演示"
   ? "   - 异步分析"
   ? "   - 取消异步操作"
   ? ""
   ? "5. MultiPV模式演示"
   ? "   - 获取多个候选着法"
   ? ""
   ? "6. 特殊局面演示"
   ? "   - 将死检测"
   ? "   - 困毙检测"
   ? ""
   ? "7. 引擎选项演示"
   ? "   - 设置引擎参数"
   ? "   - 清除哈希表"
   ? "   - 开始新游戏"
   ? ""
   ? "8. 引擎统计信息"
   ? "   - 查看引擎运行统计"
   ? ""
   ? "9. 帮助信息"
   ? "   - 显示本帮助"
   ? ""
   ? "0. 退出程序"
   ? "   - 退出演示程序"
   ? ""
   ? "========================================"

   RETURN
