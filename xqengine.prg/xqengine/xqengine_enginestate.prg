/*
 * xqengine_enginestate.prg
 * 中国象棋引擎状态类
 *
 * 功能:
 * - 引擎状态管理
 * - 状态转换和监控
 * - 统计信息收集
 *
 * 使用示例:
 * LOCAL oState := EngineState():New()
 * oState:SetState( ENGINE_STATE_THINKING )
 * ? oState:GetStateName()
 */

#include "hbclass.ch"
#include "xqengine_constants.ch"

// ============================================================================
// EngineState 类 - 引擎状态管理
// ============================================================================

CREATE CLASS EngineState

   // 当前状态
   VAR nState          INIT ENGINE_STATE_STOPPED
   VAR cStateName      INIT "STOPPED"

   // 进程信息
   VAR nPID            INIT 0
   VAR hProcess        INIT 0
   VAR hStdIn          INIT 0
   VAR hStdOut         INIT 0
   VAR hStdErr         INIT 0

   // 时间信息
   VAR nStartTime      INIT 0
   VAR nStopTime       INIT 0
   VAR nLastActivity   INIT 0
   VAR nThinkStartTime INIT 0

   // 通信统计
   VAR nCommandCount   INIT 0
   VAR nResponseCount  INIT 0
   VAR nErrorCount     INIT 0

   // 当前分析信息
   VAR cCurrentFEN     INIT ""
   VAR cBestMove       INIT ""
   VAR cPonderMove     INIT ""
   VAR nCurrentScore   INIT 0
   VAR nCurrentDepth   INIT 0
   VAR nCurrentNodes   INIT 0
   VAR nCurrentTime    INIT 0

   // 最后通信信息
   VAR cLastCommand    INIT ""
   VAR cLastResponse   INIT ""

   // 错误信息
   VAR cLastError      INIT ""
   VAR nLastErrorCode  INIT 0

   // 引擎信息
   VAR cEngineName     INIT "Unknown"
   VAR cEngineVersion  INIT ""
   VAR cEngineAuthor   INIT ""

   // 协议类型
   VAR lUCIProtocol    INIT .F.

   // MultiPV 支持
   VAR nMultiPV        INIT 1
   VAR aMultiPVMoves   INIT {}   // 多候选着法数组
   VAR aMultiPVScores  INIT {}   // 多候选评分数组
   VAR aMultiPVPVs     INIT {}   // 多候选PV数组

   // WDL 概率 (Win/Draw/Loss)
   VAR nWDL_Win        INIT 0
   VAR nWDL_Draw       INIT 0
   VAR nWDL_Loss       INIT 0

   // NNUE 信息
   VAR lNNUE_Enabled   INIT .T.
   VAR cNNUE_File      INIT ""
   VAR nNNUE_Size      INIT 0

   // 将死/困毙信息
   VAR lMate           INIT .F.    // 是否将死
   VAR nMate           INIT 0      // 几步将死（正数=我方将死对方，负数=对方将死我方）
   VAR lStalemate      INIT .F.    // 是否困毙

   // 方法
   METHOD New()
   METHOD SetState( nNewState )
   METHOD GetState()
   METHOD GetStateName()
   METHOD IsRunning()
   METHOD IsThinking()
   METHOD IsReady()
   METHOD SetError( cError, nCode )
   METHOD GetLastError()
   METHOD GetLastErrorCode()
   METHOD RecordCommand( cCommand )
   METHOD RecordResponse( cResponse )
   METHOD RecordError()
   METHOD GetStatistics()
   METHOD ResetStatistics()
   METHOD UpdateActivity()
   METHOD GetUptime()
   METHOD GetThinkTime()
   METHOD SetCurrentAnalysis( cFEN, nScore, nDepth, nNodes, nTime )
   METHOD SetBestMove( cMove, cPonder )
   METHOD SetMultiPV( nCount )
   METHOD GetMultiPV()
   METHOD AddMultiPVMove( cMove, nScore, cPV )
   METHOD ClearMultiPV()
   METHOD SetWDL( nWin, nDraw, nLoss )
   METHOD GetWDL()
   METHOD SetNNUEInfo( cFile, nSize )
   METHOD GetNNUEInfo()
   METHOD SetMate( lMate, nMate )
   METHOD GetMate()
   METHOD SetStalemate( lStalemate )
   METHOD IsStalemate()
   METHOD ToString()

ENDCLASS

// ============================================================================
// 构造函数
// ============================================================================

METHOD New() CLASS EngineState

   ::nState          := ENGINE_STATE_STOPPED
   ::cStateName      := "STOPPED"
   ::nPID            := 0
   ::hProcess        := 0
   ::hStdIn          := 0
   ::hStdOut         := 0
   ::hStdErr         := 0
   ::nStartTime      := 0
   ::nStopTime       := 0
   ::nLastActivity   := 0
   ::nThinkStartTime := 0
   ::nCommandCount   := 0
   ::nResponseCount  := 0
   ::nErrorCount     := 0
   ::cCurrentFEN     := ""
   ::cBestMove       := ""
   ::cPonderMove     := ""
   ::nCurrentScore   := 0
   ::nCurrentDepth   := 0
   ::nCurrentNodes   := 0
   ::nCurrentTime    := 0
   ::cLastCommand    := ""
   ::cLastResponse   := ""
   ::cLastError      := ""
   ::nLastErrorCode  := 0
   ::cEngineName     := "Unknown"
   ::cEngineVersion  := ""
   ::cEngineAuthor   := ""

   RETURN Self

// ============================================================================
// 设置状态
// ============================================================================

METHOD SetState( nNewState ) CLASS EngineState

   IF HB_ISNUMERIC( nNewState )
      ::nState := nNewState

      IF ::nState == ENGINE_STATE_STOPPED
         ::cStateName := "STOPPED"
         ::nStopTime := GetTickCount()

      ELSEIF ::nState == ENGINE_STATE_STARTING
         ::cStateName := "STARTING"

      ELSEIF ::nState == ENGINE_STATE_RUNNING
         ::cStateName := "RUNNING"

      ELSEIF ::nState == ENGINE_STATE_THINKING
         ::cStateName := "THINKING"
         ::nThinkStartTime := GetTickCount()

      ELSEIF ::nState == ENGINE_STATE_PONDERING
         ::cStateName := "PONDERING"

      ELSEIF ::nState == ENGINE_STATE_STOPPING
         ::cStateName := "STOPPING"

      ELSEIF ::nState == ENGINE_STATE_ERROR
         ::cStateName := "ERROR"
      ENDIF
   ENDIF

   RETURN Self

// ============================================================================
// 获取状态
// ============================================================================

METHOD GetState() CLASS EngineState
   RETURN ::nState

// ============================================================================
// 获取状态名称
// ============================================================================

METHOD GetStateName() CLASS EngineState
   RETURN ::cStateName

// ============================================================================
// 检查是否运行中
// ============================================================================

METHOD IsRunning() CLASS EngineState
   RETURN ::nState >= ENGINE_STATE_RUNNING .AND. ::nState <= ENGINE_STATE_PONDERING

// ============================================================================
// 检查是否思考中
// ============================================================================

METHOD IsThinking() CLASS EngineState
   RETURN ::nState == ENGINE_STATE_THINKING

// ============================================================================
// 检查是否就绪
// ============================================================================

METHOD IsReady() CLASS EngineState
   RETURN ::nState == ENGINE_STATE_RUNNING .AND. ::nCommandCount > 0

// ============================================================================
// 设置错误信息
// ============================================================================

METHOD SetError( cError, nCode ) CLASS EngineState

   IF HB_ISSTRING( cError )
      ::cLastError := cError
   ENDIF

   IF HB_ISNUMERIC( nCode )
      ::nLastErrorCode := nCode
   ENDIF

   ::RecordError()
   ::SetState( ENGINE_STATE_ERROR )

   RETURN Self

// ============================================================================
// 获取最后错误
// ============================================================================

METHOD GetLastError() CLASS EngineState
   RETURN ::cLastError

// ============================================================================
// 获取最后错误代码
// ============================================================================

METHOD GetLastErrorCode() CLASS EngineState
   RETURN ::nLastErrorCode

// ============================================================================
// 记录命令
// ============================================================================

METHOD RecordCommand( cCommand ) CLASS EngineState

   IF HB_ISSTRING( cCommand )
      ::cLastCommand := cCommand
      ::nCommandCount++
      ::UpdateActivity()
   ENDIF

   RETURN Self

// ============================================================================
// 记录响应
// ============================================================================

METHOD RecordResponse( cResponse ) CLASS EngineState

   IF HB_ISSTRING( cResponse )
      ::cLastResponse := cResponse
      ::nResponseCount++
      ::UpdateActivity()
   ENDIF

   RETURN Self

// ============================================================================
// 记录错误
// ============================================================================

METHOD RecordError() CLASS EngineState
   ::nErrorCount++
   RETURN Self

// ============================================================================
// 获取统计信息
// ============================================================================

METHOD GetStatistics() CLASS EngineState

   LOCAL oStats := { => }

   HB_HSet( oStats, "state", ::cStateName )
   HB_HSet( oStats, "pid", ::nPID )
   HB_HSet( oStats, "commandCount", ::nCommandCount )
   HB_HSet( oStats, "responseCount", ::nResponseCount )
   HB_HSet( oStats, "errorCount", ::nErrorCount )
   HB_HSet( oStats, "uptime", ::GetUptime() )
   HB_HSet( oStats, "engineName", ::cEngineName )
   HB_HSet( oStats, "engineVersion", ::cEngineVersion )

   RETURN oStats

// ============================================================================
// 重置统计信息
// ============================================================================

METHOD ResetStatistics() CLASS EngineState

   ::nCommandCount  := 0
   ::nResponseCount := 0
   ::nErrorCount    := 0

   RETURN Self

// ============================================================================
// 更新活动时间
// ============================================================================

METHOD UpdateActivity() CLASS EngineState
   ::nLastActivity := GetTickCount()
   RETURN Self

// ============================================================================
// 获取运行时间(毫秒)
// ============================================================================

METHOD GetUptime() CLASS EngineState

   IF ::nStartTime > 0
      RETURN GetTickCount() - ::nStartTime
   ENDIF

   RETURN 0

// ============================================================================
// 获取思考时间(毫秒)
// ============================================================================

METHOD GetThinkTime() CLASS EngineState

   IF ::nThinkStartTime > 0 .AND. ::IsThinking()
      RETURN GetTickCount() - ::nThinkStartTime
   ENDIF

   RETURN 0

// ============================================================================
// 设置当前分析信息
// ============================================================================

METHOD SetCurrentAnalysis( cFEN, nScore, nDepth, nNodes, nTime ) CLASS EngineState

   IF HB_ISSTRING( cFEN )
      ::cCurrentFEN := cFEN
   ENDIF

   IF HB_ISNUMERIC( nScore )
      ::nCurrentScore := nScore
   ENDIF

   IF HB_ISNUMERIC( nDepth )
      ::nCurrentDepth := nDepth
   ENDIF

   IF HB_ISNUMERIC( nNodes )
      ::nCurrentNodes := nNodes
   ENDIF

   IF HB_ISNUMERIC( nTime )
      ::nCurrentTime := nTime
   ENDIF

   RETURN Self

// ============================================================================
// 设置最佳走法
// ============================================================================

METHOD SetBestMove( cMove, cPonder ) CLASS EngineState

   IF HB_ISSTRING( cMove )
      ::cBestMove := cMove
   ENDIF

   IF HB_ISSTRING( cPonder )
      ::cPonderMove := cPonder
   ENDIF

   RETURN Self

// ============================================================================
// 设置MultiPV数量
// ============================================================================

METHOD SetMultiPV( nCount ) CLASS EngineState

   IF HB_ISNUMERIC( nCount ) .AND. nCount > 0
      ::nMultiPV := Int( nCount )
      ::ClearMultiPV()
   ENDIF

   RETURN Self

// ============================================================================
// 获取MultiPV数量
// ============================================================================

METHOD GetMultiPV() CLASS EngineState
   RETURN ::nMultiPV

// ============================================================================
// 添加MultiPV着法
// ============================================================================

METHOD AddMultiPVMove( cMove, nScore, cPV ) CLASS EngineState

   IF Len( ::aMultiPVMoves ) < ::nMultiPV
      AAdd( ::aMultiPVMoves, cMove )
      AAdd( ::aMultiPVScores, nScore )
      AAdd( ::aMultiPVPVs, cPV )
   ENDIF

   RETURN Self

// ============================================================================
// 清除MultiPV数据
// ============================================================================

METHOD ClearMultiPV() CLASS EngineState

   ::aMultiPVMoves := {}
   ::aMultiPVScores := {}
   ::aMultiPVPVs := {}

   RETURN Self

// ============================================================================
// 设置WDL概率
// ============================================================================

METHOD SetWDL( nWin, nDraw, nLoss ) CLASS EngineState

   IF HB_ISNUMERIC( nWin )
      ::nWDL_Win := nWin
   ENDIF

   IF HB_ISNUMERIC( nDraw )
      ::nWDL_Draw := nDraw
   ENDIF

   IF HB_ISNUMERIC( nLoss )
      ::nWDL_Loss := nLoss
   ENDIF

   RETURN Self

// ============================================================================
// 获取WDL概率
// ============================================================================

METHOD GetWDL() CLASS EngineState

   LOCAL oResult := { => }

   HB_HSet( oResult, "win", ::nWDL_Win )
   HB_HSet( oResult, "draw", ::nWDL_Draw )
   HB_HSet( oResult, "loss", ::nWDL_Loss )

   RETURN oResult

// ============================================================================
// 设置NNUE信息
// ============================================================================

METHOD SetNNUEInfo( cFile, nSize ) CLASS EngineState

   IF HB_ISSTRING( cFile )
      ::cNNUE_File := cFile
   ENDIF

   IF HB_ISNUMERIC( nSize )
      ::nNNUE_Size := nSize
   ENDIF

   RETURN Self

// ============================================================================
// 获取NNUE信息
// ============================================================================

METHOD GetNNUEInfo() CLASS EngineState

   LOCAL oResult := { => }

   HB_HSet( oResult, "enabled", ::lNNUE_Enabled )
   HB_HSet( oResult, "file", ::cNNUE_File )
   HB_HSet( oResult, "size", ::nNNUE_Size )

   RETURN oResult

// ============================================================================
// 设置将死信息
// ============================================================================

METHOD SetMate( lMate, nMate ) CLASS EngineState

   ::lMate := lMate
   ::nMate := nMate

   RETURN Self

// ============================================================================
// 获取将死信息
// ============================================================================

METHOD GetMate() CLASS EngineState

   LOCAL oResult := { => }

   HB_HSet( oResult, "mate", ::lMate )
   HB_HSet( oResult, "steps", ::nMate )

   RETURN oResult

// ============================================================================
// 设置困毙状态
// ============================================================================

METHOD SetStalemate( lStalemate ) CLASS EngineState

   ::lStalemate := lStalemate

   RETURN Self

// ============================================================================
// 检查是否困毙
// ============================================================================

METHOD IsStalemate() CLASS EngineState

   RETURN ::lStalemate

// ============================================================================
// 转换为字符串
// ============================================================================

METHOD ToString() CLASS EngineState

   LOCAL cResult := ""

   cResult += "引擎状态:"
   cResult += "  状态: " + ::cStateName + hb_eol()
   cResult += "  PID: " + Iif( ::nPID > 0, hb_ntos( ::nPID ), "N/A" ) + hb_eol()
   cResult += "  引擎: " + ::cEngineName + hb_eol()
   cResult += "  版本: " + ::cEngineVersion + hb_eol()
   cResult += "  命令数: " + hb_ntos( ::nCommandCount ) + hb_eol()
   cResult += "  响应数: " + hb_ntos( ::nResponseCount ) + hb_eol()
   cResult += "  错误数: " + hb_ntos( ::nErrorCount ) + hb_eol()
   cResult += "  运行时间: " + hb_ntos( ::GetUptime() ) + "ms" + hb_eol()

   IF ::IsThinking()
      cResult += "  思考时间: " + hb_ntos( ::GetThinkTime() ) + "ms" + hb_eol()
   ENDIF

   IF ! Empty( ::cLastError )
      cResult += "  最后错误: " + ::cLastError + hb_eol()
   ENDIF

   RETURN cResult

// ============================================================================
// 获取当前时间戳(毫秒) - 定义在 xqengine_utils.prg 中
// ============================================================================

// ============================================================================
// 测试代码
// ============================================================================

PROCEDURE Test_EngineState()

   LOCAL oState

   XQECI_Info( XQECI_MODULE_TEST, "=== EngineState Class Test ===" )
   XQECI_Info( XQECI_MODULE_TEST, "" )

   // 创建状态
   oState := EngineState():New()
   oState:cEngineName := "Pikafish"
   oState:cEngineVersion := "1.0.0"

   // 测试状态转换
   XQECI_InfoF( XQECI_MODULE_TEST, "Initial state: %1", oState:GetStateName() )

   oState:SetState( ENGINE_STATE_STARTING )
   XQECI_InfoF( XQECI_MODULE_TEST, "Starting: %1", oState:GetStateName() )

   oState:SetState( ENGINE_STATE_RUNNING )
   XQECI_InfoF( XQECI_MODULE_TEST, "Running: %1", oState:GetStateName() )
   XQECI_InfoF( XQECI_MODULE_TEST, "Is running: %1", oState:IsRunning() )

   oState:SetState( ENGINE_STATE_THINKING )
   XQECI_InfoF( XQECI_MODULE_TEST, "Thinking: %1", oState:GetStateName() )
   XQECI_InfoF( XQECI_MODULE_TEST, "Is thinking: %1", oState:IsThinking() )

   // 记录命令和响应
   oState:RecordCommand( "ucci" )
   oState:RecordResponse( "ucciok" )
   oState:RecordCommand( "isready" )
   oState:RecordResponse( "readyok" )

   // 打印状态
   XQECI_Info( XQECI_MODULE_TEST, "" )
   XQECI_Info( XQECI_MODULE_TEST, oState:ToString() )

   // 测试错误
   oState:SetError( "测试错误", 1 )
   XQECI_Info( XQECI_MODULE_TEST, "" )
   XQECI_InfoF( XQECI_MODULE_TEST, "Error state: %1", oState:GetStateName() )
   XQECI_InfoF( XQECI_MODULE_TEST, "Error message: %1", oState:GetLastError() )

   RETURN