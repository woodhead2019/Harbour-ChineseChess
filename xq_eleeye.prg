/*
 * 象眼引擎接口模块
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 为 xiangqiw.prg 提供象眼引擎功能
 * 象眼引擎使用直接函数调用接口，无需进程间通信
 *
 * ======== 第三方库许可说明 ========
 *
 * 本模块集成了象眼引擎 (ElephantEye)，使用 GPL v3 许可证。
 *
 * 象眼引擎项目：https://github.com/xqbase/eleeye
 * 许可证：GPL v3
 * 集成方式：静态链接 (libeleeye.a)
 *
 * 根据 GPL v3 许可证的要求，使用象眼引擎的项目也必须遵循 GPL v3 许可证。
 * 本项目的其他部分仍遵循 CC0 Public Domain 许可证。
 */

#include "xq_xiangqi.ch"

// 全局变量
STATIC s_lEleeyeInitialized := .F.

//--------------------------------------------------------------------------------

/**
 * ElephantEye 日志记录函数（使用统一日志系统）
 * @param cMessage 日志消息
 */
static PROCEDURE xq_Eleeye_Log( cMessage )
   // 只有在调试模式下才记录日志
   IF !IsDebugEnabled()
      RETURN
   ENDIF
   xq_Log_Info( "ElephantEye", cMessage )
RETURN

//--------------------------------------------------------------------------------

/**
 * 初始化象眼引擎
 * @return .T. 成功, .F. 失败
 */
function xq_Eleeye_Init()

   LOCAL l_nResult

   IF s_lEleeyeInitialized
      RETURN .T.
   ENDIF

   xq_Log_Info( "ElephantEye", "Initializing ElephantEye engine..." )

   // 调用 C 函数初始化引擎
   l_nResult := ELEngine_InitString()

   IF l_nResult == 0
      xq_Log_Error( "ElephantEye", "Engine initialization failed" )
      RETURN .F.
   ENDIF

   s_lEleeyeInitialized := .T.
   xq_Log_Info( "ElephantEye", "Engine initialized successfully" )

   RETURN .T.

//--------------------------------------------------------------------------------

/**
 * 获取最佳走法
 * @param aPos 引擎位置结构
 * @param nDepth 搜索深度
 * @param cFEN FEN 字符串（可选）
 * @return nMove 移动编码（0 表示无走法）
 */
function xq_Eleeye_GetBestMove( aPos, nDepth, cFEN )

   LOCAL cCmd, cResponse, cBestMove
   LOCAL l_cPosStr
   LOCAL nMoveCode

   // 象眼引擎在程序启动时已经初始化，无需再次检查

   // 设置局面
   IF Empty( cFEN )
      cCmd := "position startpos" + hb_eol()
      xq_Eleeye_Log( "position startpos" )
   ELSE
      cCmd := "position fen " + cFEN + hb_eol()
      xq_Eleeye_Log( "position fen " + cFEN )
   ENDIF

   cResponse := ELEngine_ProcessString( cCmd )

   // 发送思考命令（使用深度）
   cCmd := "go depth " + LTrim(Str(nDepth)) + hb_eol()
   xq_Eleeye_Log( "go depth " + LTrim(Str(nDepth)) )
   cResponse := ELEngine_ProcessString( cCmd )

   // 解析最佳走法
   cBestMove := AllTrim( cResponse )

   IF Empty( cBestMove ) .OR. cBestMove == "error" .OR. cBestMove == "nobestmove"
      xq_Eleeye_Log( "no best move found" )
      RETURN 0
   ENDIF

   xq_Eleeye_Log( "bestmove " + cBestMove )

   // 将 UCCI 坐标转换为移动编码
   nMoveCode := xq_UCCICoordToMovePublic( cBestMove )
   xq_Eleeye_Log( "converted move code: " + Str(nMoveCode) )
   RETURN nMoveCode

//--------------------------------------------------------------------------------

/**
 * 清理象眼引擎
 * @return NIL
 */
function xq_Eleeye_Cleanup()

   IF s_lEleeyeInitialized
      xq_Log_Info( "ElephantEye", "Cleaning up engine..." )
      ELEngine_CleanupString()
      s_lEleeyeInitialized := .F.
      xq_Log_Info( "ElephantEye", "Engine cleaned up successfully" )
   ENDIF

   RETURN NIL

//--------------------------------------------------------------------------------

/**
 * 检查象眼引擎是否已初始化
 * @return .T. 已初始化, .F. 未初始化
 */
function xq_Eleeye_IsInitialized()

   RETURN s_lEleeyeInitialized

//--------------------------------------------------------------------------------