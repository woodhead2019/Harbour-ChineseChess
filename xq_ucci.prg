/*
 * UCCI 引擎接口模块
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 为 xiangqiw.prg 提供 UCCI 引擎功能
 *
 * 【重要提示】
 * 1. 本文件中的所有 PUBLIC 函数声明已合并到 xq_funcs.txt（参考信息）
 * 2. Harbour 默认认为当前 .prg 文件中不存在的函数都在外部
 * 3. 没有 static 限制的函数或过程都是 public 的
 * 4. xq_funcs.txt 仅作为参考，不参与编译
 * 5. 本版本使用 Harbour 原生 API，不再使用 C 代码
 */

#include "inkey.ch"
#include "fileio.ch"

// ============================================================================
// 引擎进程管理结构
// ============================================================================

// 引擎进程句柄结构（使用哈希表存储）
// 哈希表键值：
//   "hProcess"    - 进程句柄（数值）
//   "hStdIn"      - 标准输入句柄（数值）
//   "hStdOut"     - 标准输出句柄（数值）
//   "hStdErr"     - 标准错误句柄（数值）
//   "nPID"        - 进程ID（数值）
//   "lRunning"    - 运行状态（逻辑）
//   "nErrorCode"  - 错误代码（数值）

// 全局变量
// AI1 引擎实例（哈希表）
STATIC pAI1App := NIL

// AI2 引擎实例（哈希表）
STATIC pAI2App := NIL

STATIC lUCCIStopRequested := .F.  // 是否请求停止 AI 思考

STATIC s_cAI1EngineName := ""     // AI1 引擎文件名
STATIC s_cAI2EngineName := ""     // AI2 引擎文件名

// ============================================================================
// 工具函数
// ============================================================================

//--------------------------------------------------------------------------------

/**
 * 日志记录辅助函数（使用统一日志系统）
 * @param cMessage 日志消息
 */
static PROCEDURE xq_UCCILogMessage( cMessage )
   xq_Log_Info( "UCCI", cMessage )
RETURN

//--------------------------------------------------------------------------------

/**
 * AI1 日志记录函数
 * @param cMessage 日志消息
 */
static PROCEDURE xq_UCCILogMessageAI1( cMessage )
   LOCAL cPrefix
   IF Empty( s_cAI1EngineName )
      xq_Log_Info( "AI1", cMessage )
   ELSE
      xq_Log_Info( "AI1-" + s_cAI1EngineName, cMessage )
   ENDIF
RETURN

//--------------------------------------------------------------------------------

/**
 * AI2 日志记录函数
 * @param cMessage 日志消息
 */
static PROCEDURE xq_UCCILogMessageAI2( cMessage )
   LOCAL cPrefix
   IF Empty( s_cAI2EngineName )
      cPrefix := "[AI2] "
   ELSE
      cPrefix := "[AI2-" + s_cAI2EngineName + "] "
   ENDIF
   xq_UCCILogMessage( cPrefix + cMessage, .F. )
RETURN

//--------------------------------------------------------------------------------

/**
 * 检测字符串中是否包含换行符
 * @param cStr 要检测的字符串
 * @return .T. 包含换行符，.F. 不包含
 */
static FUNCTION UCCI_HasNewLine( cStr )
   RETURN ( Chr( 10 ) $ cStr .OR. Chr( 13 ) $ cStr )

//--------------------------------------------------------------------------------

/**
 * 从字符串中提取完整的一行
 * @param cBuffer 缓冲区字符串
 * @return 数组 {行内容, 剩余缓冲区} 或空字符串
 */
static FUNCTION UCCI_ReadLine( cBuffer )
   LOCAL nPosLF := At( Chr( 10 ), cBuffer )
   LOCAL nPosCR := At( Chr( 13 ), cBuffer )
   LOCAL nPos := 0
   LOCAL cLine := ""
   LOCAL aResult := {}
   
   // 查找行结束符
   IF nPosLF > 0 .AND. nPosCR > 0
      nPos := Min( nPosLF, nPosCR )
   ELSEIF nPosLF > 0
      nPos := nPosLF
   ELSEIF nPosCR > 0
      nPos := nPosCR
   ENDIF
   
   // 如果找到行结束符
   IF nPos > 0
      cLine := SubStr( cBuffer, 1, nPos - 1 )
      // Skip line terminator
      IF SubStr( cBuffer, nPos, 1 ) == Chr( 13 )
         cBuffer := SubStr( cBuffer, nPos + 1 )
         IF Left( cBuffer, 1 ) == Chr( 10 )
            cBuffer := SubStr( cBuffer, 2 )
         ENDIF
      ELSE
         cBuffer := SubStr( cBuffer, nPos + 1 )
      ENDIF
      AAdd( aResult, cLine )
      AAdd( aResult, cBuffer )
      RETURN aResult
   ENDIF
   
   RETURN ""

//--------------------------------------------------------------------------------

/**
 * 睡眠函数（毫秒）
 * @param nMilliseconds 毫秒数
 */
static PROCEDURE cedi_Sleep( nMilliseconds )
   // 使用系统级睡眠函数，避免触发 Harbour 垃圾回收
   CEDI_SystemSleep( nMilliseconds )
RETURN

#pragma BEGINDUMP

#include "hbapi.h"

#if defined(HB_OS_UNIX) || defined(HB_OS_LINUX)
#include <unistd.h>
#elif defined(HB_OS_WIN_32)
#include <windows.h>
#endif

HB_FUNC( CEDI_SYSTEMSLEEP )
{
   int nMilliseconds = (int) hb_parni(1);
   
#if defined(HB_OS_UNIX) || defined(HB_OS_LINUX)
   usleep( nMilliseconds * 1000 );
#elif defined(HB_OS_WIN_32)
   Sleep( nMilliseconds );
#else
   // 通用方案，使用 Harbour 的 hb_idleSleep
   hb_idleSleep( nMilliseconds / 1000.0 );
#endif
}

#pragma ENDDUMP

//--------------------------------------------------------------------------------

/**
 * 启动控制台应用程序（Harbour 原生实现）
 * @param cEnginePath 引擎路径
 * @param nShowMode 显示模式（Windows专用，Unix下忽略）
 * @return 引擎哈希表或 NIL
 */
static FUNCTION cedi_StartConsoleApp( cEnginePath, nShowMode )

   LOCAL hEngine
   LOCAL hProcess
   LOCAL hStdIn
   LOCAL hStdOut
   LOCAL hStdErr
   LOCAL nPID

   // 使用 Harbour 原生 API 启动进程
   // 参数：命令行，标准输入句柄，标准输出句柄，标准错误句柄，继承句柄标志，PID变量
   hProcess := hb_ProcessOpen( cEnginePath, @hStdIn, @hStdOut, @hStdErr, .F., @nPID )
   
   IF hProcess == 0 .OR. hProcess == -1
      xq_UCCILogMessage( "= ERROR: Engine start failed, hb_ProcessOpen returned " + Str( hProcess ) )
      // 返回错误状态的哈希表
      hEngine := {=>}
      hEngine["hProcess"] := 0
      hEngine["hStdIn"] := 0
      hEngine["hStdOut"] := 0
      hEngine["hStdErr"] := 0
      hEngine["nPID"] := 0
      hEngine["lRunning"] := .F.
      hEngine["nErrorCode"] := 1
      RETURN hEngine
   ENDIF
   
   // 创建引擎哈希表
   hEngine := {=>}
   hEngine["hProcess"] := hProcess
   hEngine["hStdIn"] := hStdIn
   hEngine["hStdOut"] := hStdOut
   hEngine["hStdErr"] := hStdErr
   hEngine["nPID"] := nPID
   hEngine["lRunning"] := .T.
   hEngine["nErrorCode"] := 0
   
   xq_UCCILogMessage( "= Engine started successfully, PID: " + Str( nPID ) )
   
   RETURN hEngine

//--------------------------------------------------------------------------------

/**
 * 返回错误代码
 * @param hEngine 引擎哈希表
 * @return 错误代码
 */
static FUNCTION cedi_ReturnErrCode( hEngine )

   IF hEngine == NIL
      RETURN -1
   ENDIF
   
   RETURN hEngine["nErrorCode"]

//--------------------------------------------------------------------------------

/**
 * 从控制台应用程序读取数据（Harbour 原生实现）
 * @param hEngine 引擎哈希表
 * @return 读取的数据字符串
 */
static FUNCTION cedi_ReadFromConsoleApp( hEngine )

   LOCAL cChunk
   LOCAL nRead
   LOCAL cData := ""
   LOCAL nMaxRead := 1024
   
   IF hEngine == NIL .OR. !hEngine["lRunning"]
      RETURN NIL
   ENDIF
   
   // 尝试从标准输出读取数据
   cChunk := Space( nMaxRead )
   nRead := FRead( hEngine["hStdOut"], @cChunk, nMaxRead )
   
   IF nRead > 0
      cData := Left( cChunk, nRead )
      RETURN cData
   ENDIF
   
   // 尝试从标准错误读取数据
   cChunk := Space( nMaxRead )
   nRead := FRead( hEngine["hStdErr"], @cChunk, nMaxRead )
   
   IF nRead > 0
      cData := Left( cChunk, nRead )
      RETURN cData
   ENDIF
   
   RETURN ""

//--------------------------------------------------------------------------------

/**
 * 向控制台应用程序写入数据（Harbour 原生实现）
 * @param hEngine 引擎哈希表
 * @param cData 要写入的数据
 * @return .T. 成功，.F. 失败
 */
static FUNCTION cedi_WriteToConsoleApp( hEngine, cData )

   LOCAL nWritten
   
   IF hEngine == NIL .OR. !hEngine["lRunning"]
      RETURN .F.
   ENDIF
   
   nWritten := FWrite( hEngine["hStdIn"], cData )
   
   IF nWritten > 0
      RETURN .T.
   ELSE
      RETURN .F.
   ENDIF

RETURN .F.

//--------------------------------------------------------------------------------

/**
 * 结束控制台应用程序（Harbour 原生实现）
 * @param hEngine 引擎哈希表
 * @return NIL
 */
static PROCEDURE cedi_EndConsoleApp( hEngine )

   LOCAL nExitCode
   
   IF hEngine == NIL
      RETURN
   ENDIF
   
   IF hEngine["lRunning"]
      // 等待进程结束
      nExitCode := hb_ProcessValue( hEngine["hProcess"], .T. )
      xq_UCCILogMessage( "= Engine exit code: " + Str( nExitCode ) )
      
      // 关闭进程
      hb_ProcessClose( hEngine["hProcess"], .F. )
   ENDIF
   
   // 关闭文件句柄
   IF hEngine["hStdIn"] != 0
      FClose( hEngine["hStdIn"] )
   ENDIF
   
   IF hEngine["hStdOut"] != 0
      FClose( hEngine["hStdOut"] )
   ENDIF
   
   IF hEngine["hStdErr"] != 0
      FClose( hEngine["hStdErr"] )
   ENDIF
   
   hEngine["lRunning"] := .F.
   hEngine["hProcess"] := 0
   hEngine["hStdIn"] := 0
   hEngine["hStdOut"] := 0
   hEngine["hStdErr"] := 0
   hEngine["nPID"] := 0

RETURN

// ============================================================================
// UCCI 引擎接口函数
// ============================================================================

//--------------------------------------------------------------------------------

/**
 * 初始化 AI1 引擎
 * @param par_hConfig 全局配置哈希表引用（由 GetGlobalConfig() 返回）
 * @return .T. 成功, .F. 失败
 */
function xq_UCCI_InitAI1( par_hConfig )
   LOCAL lOk := .F.

   // 参数验证：确保 par_hConfig 是哈希表
   IF par_hConfig == NIL .OR. !HB_ISHASH( par_hConfig )
      xq_UCCILogMessageAI1( "ERROR: AI1 init failed: invalid config parameters" )
      RETURN .F.
   ENDIF

   // par_hConfig 是 GetGlobalConfig() 返回的哈希表引用，修改会影响全局配置（验证通过test_hash_ref.prg）
   IF par_hConfig["AI1Initialized"]
      RETURN .T.
   ENDIF

   // 保存引擎文件名
   s_cAI1EngineName := hb_FNameName( par_hConfig["AI1EnginePath"] )

   // 启动引擎
   pAI1App := cedi_StartConsoleApp( par_hConfig["AI1EnginePath"], 2 )

   IF cedi_ReturnErrCode( pAI1App ) > 0
      xq_UCCILogMessageAI1( "ERROR: AI1 failed to start engine" )
      pAI1App := NIL
      RETURN .F.
   ENDIF

   // 发送握手命令
   xq_UCCILogMessageAI1( "> ucci" )
   cedi_WriteToConsoleApp( pAI1App, "ucci" + hb_eol() )
   
   lOk := xq_UCCIWaitUcciokForApp( pAI1App, 5000 )
   IF !lOk
      xq_UCCILogMessageAI1( "ERROR: AI1 init failed: ucciok not received" )
      cedi_EndConsoleApp( pAI1App )
      pAI1App := NIL
      RETURN .F.
   ENDIF

   cedi_WriteToConsoleApp( pAI1App, "isready" + hb_eol() )
   lOk := xq_UCCIWaitReadyokForApp( pAI1App, 3000 )

      IF !lOk
         xq_UCCILogMessageAI1( "ERROR: AI1 init failed: readyok not received" )
         cedi_EndConsoleApp( pAI1App )
         pAI1App := NIL
         RETURN .F.
      ENDIF
   
      par_hConfig["AI1Initialized"] := .T.
   RETURN .T.

//--------------------------------------------------------------------------------

/**
 * 初始化 AI2 引擎
 * @param par_hConfig 全局配置哈希表引用（由 GetGlobalConfig() 返回）
 * @return .T. 成功, .F. 失败
 */
function xq_UCCI_InitAI2( par_hConfig )
   LOCAL lOk := .F.

   // 参数验证：确保 par_hConfig 是哈希表
   IF par_hConfig == NIL .OR. !HB_ISHASH( par_hConfig )
      xq_UCCILogMessageAI2( "ERROR: AI2 init failed: invalid config parameters" )
      RETURN .F.
   ENDIF

   // par_hConfig 是 GetGlobalConfig() 返回的哈希表引用，修改会影响全局配置（验证通过test_hash_ref.prg）
   IF par_hConfig["AI2Initialized"]
      RETURN .T.
   ENDIF

   // 保存引擎文件名
   s_cAI2EngineName := hb_FNameName( par_hConfig["AI2EnginePath"] )

   // 启动引擎
   pAI2App := cedi_StartConsoleApp( par_hConfig["AI2EnginePath"], 2 )

   IF cedi_ReturnErrCode( pAI2App ) > 0
      xq_UCCILogMessageAI2( "ERROR: AI2 failed to start engine" )
      pAI2App := NIL
      RETURN .F.
   ENDIF

   // 发送握手命令
   xq_UCCILogMessageAI2( "> ucci" )
   cedi_WriteToConsoleApp( pAI2App, "ucci" + hb_eol() )
   
   lOk := xq_UCCIWaitUcciokForApp( pAI2App, 5000 )
   IF !lOk
      xq_UCCILogMessageAI2( "ERROR: AI2 init failed: ucciok not received" )
      cedi_EndConsoleApp( pAI2App )
      pAI2App := NIL
      RETURN .F.
   ENDIF

   xq_UCCILogMessageAI2( "> isready" )
   cedi_WriteToConsoleApp( pAI2App, "isready" + hb_eol() )
   lOk := xq_UCCIWaitReadyokForApp( pAI2App, 3000 )

      IF !lOk
         xq_UCCILogMessageAI2( "ERROR: AI2 init failed: readyok not received" )
         cedi_EndConsoleApp( pAI2App )
         pAI2App := NIL
         RETURN .F.
      ENDIF
   
      par_hConfig["AI2Initialized"] := .T.
   RETURN .T.

//--------------------------------------------------------------------------------

/**
 * 获取最佳走法（AI1）
 * @param par_hConfig 全局配置哈希表引用（由 GetGlobalConfig() 返回）
 * @param aPos 引擎位置结构（当前版本未使用）
 * @param nDepth 搜索深度（当前版本未使用）
 * @param cFEN FEN 字符串（可选）
 * @return nMove 移动编码（0 表示无走法）
 */
function xq_UCCI_GetBestMoveAI1( par_hConfig, aPos, nDepth, cFEN )

   LOCAL cResponse, cBestMove, nMove
   LOCAL cCmd
   LOCAL nThinkTime := par_hConfig["AI1ThinkTime"]  // 使用AI1的思考时间

   // par_hConfig 是 GetGlobalConfig() 返回的哈希表引用，修改会影响全局配置（验证通过test_hash_ref.prg）
   IF !par_hConfig["AI1Initialized"]
      RETURN 0
   ENDIF

   // 设置局面
   IF Empty( cFEN )
      cCmd := "position startpos"
   ELSE
      cCmd := "position fen " + cFEN
   ENDIF

   cedi_WriteToConsoleApp( pAI1App, cCmd + hb_eol() )
   xq_UCCILogMessageAI1( "> " + cCmd )  // 记录发送的指令
   cedi_Sleep( 100 )

   // 发送思考命令（使用AI1的思考时间）
   cCmd := "go time " + LTrim(Str(nThinkTime))
   xq_UCCILogMessageAI1( "> " + cCmd )  // 记录发送的指令
   cedi_WriteToConsoleApp( pAI1App, cCmd + hb_eol() )
   cedi_Sleep( 100 )

   // 验证引擎进程是否仍然有效
   IF pAI1App == NIL .OR. (HB_ISHASH(pAI1App) .AND. !pAI1App["lRunning"])
      xq_UCCILogMessageAI1( "ERROR: pAI1App is NIL or not running before waiting for response" )
      RETURN 0
   ENDIF

   // 等待并读取最佳走法
   cBestMove := xq_UCCIWaitBestMoveForApp( pAI1App )

   IF Empty( cBestMove )
      xq_UCCILogMessageAI1( "< bestmove (none)" )
      RETURN 0
   ENDIF

   // 记录引擎返回的最佳走法
   xq_UCCILogMessageAI1( "< bestmove " + cBestMove )

   // 将 UCCI 坐标转换为移动编码
   nMove := xq_UCCICoordToMove( cBestMove )
   RETURN nMove

//--------------------------------------------------------------------------------

/**
 * 获取最佳走法
 * @param par_hConfig 全局配置哈希表引用（由 GetGlobalConfig() 返回）
 * @param aPos 引擎位置结构
 * @param nDepth 搜索深度
 * @param cFEN FEN 字符串（可选）
 * @return nMove 移动编码（0 表示无走法）
 */
function xq_UCCI_GetBestMoveAI2( par_hConfig, aPos, nDepth, cFEN )

   LOCAL cResponse, cBestMove, nMove
   LOCAL cCmd
   LOCAL nThinkTime := par_hConfig["AI2ThinkTime"]  // 使用AI2的思考时间

   // par_hConfig 是 GetGlobalConfig() 返回的哈希表引用，修改会影响全局配置（验证通过test_hash_ref.prg）
   IF !par_hConfig["AI2Initialized"]
      RETURN 0
   ENDIF

   // 设置局面
   IF Empty( cFEN )
      cCmd := "position startpos"
   ELSE
      cCmd := "position fen " + cFEN
   ENDIF

   cedi_WriteToConsoleApp( pAI2App, cCmd + hb_eol() )
   xq_UCCILogMessageAI2( "> " + cCmd )  // 记录发送的指令
   cedi_Sleep( 100 )

   // 发送思考命令（使用AI2的思考时间）
   cCmd := "go time " + LTrim(Str(nThinkTime))
   xq_UCCILogMessageAI2( "> " + cCmd )  // 记录发送的指令
   cedi_WriteToConsoleApp( pAI2App, cCmd + hb_eol() )
   cedi_Sleep( 100 )

   // 验证引擎进程是否仍然有效
   IF pAI2App == NIL .OR. (HB_ISHASH(pAI2App) .AND. !pAI2App["lRunning"])
      xq_UCCILogMessageAI2( "ERROR: pAI2App is NIL or not running before waiting for response" )
      RETURN 0
   ENDIF

   // 等待并读取最佳走法
   cBestMove := xq_UCCIWaitBestMoveForApp( pAI2App )

   IF Empty( cBestMove )
      xq_UCCILogMessageAI2( "< bestmove (none)" )
      RETURN 0
   ENDIF

   // 记录引擎返回的最佳走法
   xq_UCCILogMessageAI2( "< bestmove " + cBestMove )

   // 将 UCCI 坐标转换为移动编码
   nMove := xq_UCCICoordToMove( cBestMove )
   RETURN nMove

//--------------------------------------------------------------------------------

/**
 * 关闭 AI1 引擎
 * @param par_hConfig 全局配置哈希表引用（可选，默认使用 GetGlobalConfig()）
 */
function xq_UCCI_CloseAI1( par_hConfig )

   // 如果没有提供par_hConfig，使用GetGlobalConfig()
   IF par_hConfig == NIL
      par_hConfig := GetGlobalConfig()
   ENDIF

   IF pAI1App != NIL
      cedi_WriteToConsoleApp( pAI1App, "quit" + hb_eol() )
      cedi_Sleep( 200 )  // 给引擎一点时间退出
      cedi_EndConsoleApp( pAI1App )
      pAI1App := NIL
   ENDIF
   par_hConfig["AI1Initialized"] := .F.

   RETURN NIL

//--------------------------------------------------------------------------------

/**
 * 关闭 AI2 引擎
 * @param par_hConfig 全局配置哈希表引用（可选，默认使用 GetGlobalConfig()）
 */
function xq_UCCI_CloseAI2( par_hConfig )

   // 如果没有提供par_hConfig，使用GetGlobalConfig()
   IF par_hConfig == NIL
      par_hConfig := GetGlobalConfig()
   ENDIF

   IF pAI2App != NIL
      cedi_WriteToConsoleApp( pAI2App, "quit" + hb_eol() )
      cedi_Sleep( 200 )  // 给引擎一点时间退出
      cedi_EndConsoleApp( pAI2App )
      pAI2App := NIL
   ENDIF
   par_hConfig["AI2Initialized"] := .F.

   RETURN NIL

//--------------------------------------------------------------------------------

//--------------------------------------------------------------------------------

/**
 * 清理所有资源（程序退出时调用）
 * @return NIL
 */
function xq_UCCI_Cleanup()

   LOCAL hConfig

   // 尝试关闭引擎
   hConfig := GetGlobalConfig()
   IF hConfig != NIL .AND. HB_ISHASH( hConfig )
      IF hConfig["AI1Initialized"]
         xq_UCCI_CloseAI1( hConfig )
      ENDIF
      IF hConfig["AI2Initialized"]
         xq_UCCI_CloseAI2( hConfig )
      ENDIF
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------

/**
 * 请求停止 AI 思考
 * @return NIL
 */
function xq_UCCI_RequestStop()

   lUCCIStopRequested := .T.

RETURN NIL

//--------------------------------------------------------------------------------

/**
 * 重置停止请求标志
 * @return NIL
 */
function xq_UCCI_ResetStopRequest()

   lUCCIStopRequested := .F.

RETURN NIL

//--------------------------------------------------------------------------------

/**
 * 等待 ucciok 响应（指定引擎实例）
 * @param hEngineApp 引擎哈希表
 * @param nTimeoutMs 超时时间（毫秒）
 * @return .T. 成功, .F. 超时或失败
 */
static FUNCTION xq_UCCIWaitUcciokForApp( hEngineApp, nTimeoutMs )

   LOCAL cChunk
   LOCAL cAccum := ""
   LOCAL nStart := Seconds()
   LOCAL nTimeout := nTimeoutMs / 1000

   IF hEngineApp == NIL .OR. !hEngineApp["lRunning"]
      RETURN .F.
   ENDIF

   DO WHILE Seconds() - nStart < nTimeout
      cChunk := cedi_ReadFromConsoleApp( hEngineApp )
      IF !Empty( cChunk )
         xq_UCCILogMessage( "< " + AllTrim( StrTran(cChunk, Chr(10), " | ") ) )
         cAccum += cChunk
         IF "ucciok" $ cAccum
            RETURN .T.
         ENDIF
      ENDIF
      cedi_Sleep( 50 )
   ENDDO
   RETURN .F.

//--------------------------------------------------------------------------------

/**
 * 等待 readyok 响应（指定引擎实例）
 * @param hEngineApp 引擎哈希表
 * @param nTimeoutMs 超时时间（毫秒）
 * @return .T. 成功, .F. 超时或失败
 */
static FUNCTION xq_UCCIWaitReadyokForApp( hEngineApp, nTimeoutMs )

   LOCAL cAccum := ""
   LOCAL cChunk
   LOCAL nStart := Seconds()
   LOCAL nTimeout := nTimeoutMs / 1000

   IF hEngineApp == NIL .OR. !hEngineApp["lRunning"]
      RETURN .F.
   ENDIF

   DO WHILE Seconds() - nStart < nTimeout
      cChunk := cedi_ReadFromConsoleApp( hEngineApp )
      IF !Empty( cChunk )
         xq_UCCILogMessage( "< " + AllTrim( StrTran(cChunk, Chr(10), " | ") ) )
         cAccum += cChunk
         IF "readyok" $ cAccum
            RETURN .T.
         ENDIF
      ENDIF
      cedi_Sleep( 50 )
   ENDDO
   RETURN .F.

//--------------------------------------------------------------------------------

/**
 * 等待指定引擎实例返回最佳走法
 * @param hEngineApp 引擎哈希表
 * @return 最佳走法字符串（如 "c3c4"），如果超时或出错则返回空字符串
 */
static FUNCTION xq_UCCIWaitBestMoveForApp( hEngineApp )

   LOCAL cAccum := ""           // 累积缓冲区
   LOCAL cChunk
   LOCAL nStart := Seconds()
   LOCAL cBest := ""
   LOCAL nTimeout
   LOCAL nPos
   LOCAL cTail
   LOCAL aWords
   LOCAL nLoopCount := 0        // 循环计数器
   LOCAL cCleanMove
   LOCAL i
   LOCAL cChar
   LOCAL lTimedOut := .F.       // 是否超时

   IF hEngineApp == NIL .OR. !hEngineApp["lRunning"]
      xq_UCCILogMessage( "< ERROR: hEngineApp is NIL or not running in WaitBestMove" )
      RETURN ""
   ENDIF

   // 设置超时时间：30秒（绝杀局面需要更多时间计算）
   nTimeout := 30

   DO WHILE Seconds() - nStart < nTimeout
      // 检查是否请求停止
      IF lUCCIStopRequested
         // 发送stop命令
         cedi_WriteToConsoleApp( hEngineApp, "stop" + hb_eol() )
         xq_UCCILogMessage( "> stop (requested)" )
         lUCCIStopRequested := .F.
         // 继续等待响应，但标记为中断
      ENDIF

      // 循环计数器
      nLoopCount++

      // 每秒输出一次调试信息
      IF nLoopCount % 33 == 0  // 约1秒（33 * 30ms = 990ms）
         xq_UCCILogMessage( "= Loop count: " + Str(nLoopCount) + ", elapsed: " + Str(Int(Seconds() - nStart)) + "s, accumulated length: " + Str(Len(cAccum)) )
      ENDIF

      cChunk := cedi_ReadFromConsoleApp( hEngineApp )

      IF cChunk != NIL .AND. !Empty( cChunk )
         // 标准化换行符
         cChunk := StrTran( cChunk, Chr(13)+Chr(10), Chr(10) )
         cChunk := StrTran( cChunk, Chr(13), Chr(10) )

         // 处理制表符和空字符
         IF Chr(9) $ cChunk
            cChunk := StrTran( cChunk, Chr(9), Space(4) )
         ENDIF
         IF Chr(0) $ cChunk
            cChunk := StrTran( cChunk, Chr(0), "" )
         ENDIF

         cAccum += cChunk

         // 记录引擎输出到日志
         xq_UCCILogMessage( "< " + AllTrim( StrTran(cChunk, Chr(10), " | ") ) )

         // 检查是否返回 nobestmove（游戏结束/逼和/困毙）
         IF "nobestmove" $ cAccum
            xq_UCCILogMessage( "= Detected nobestmove, game over" )
            RETURN ""
         ENDIF

         // 从右向左查找最后一个 bestmove
         nPos := RAt( "bestmove", cAccum )
         IF nPos > 0
            cTail := LTrim( SubStr( cAccum, nPos + 8 ) )
            aWords := hb_ATokens( cTail, " " )
            IF Len( aWords ) >= 1
               // 清理字符串：只保留字母数字
               cCleanMove := ""
               FOR i := 1 TO Len( aWords[1] )
                  cChar := SubStr( aWords[1], i, 1 )
                  IF IsAlpha( cChar ) .OR. IsDigit( cChar )
                     cCleanMove += cChar
                  ENDIF
               NEXT
               cBest := cCleanMove
               EXIT
            ENDIF
         ENDIF
      ENDIF

      // 短暂休眠，减少 CPU 占用
      cedi_Sleep( 30 )
   ENDDO

   // **关键修复：超时后发送stop**
   IF Empty( cBest )
      lTimedOut := .T.
      xq_UCCILogMessage( "= timeout (" + Str(nTimeout) + "s), sending stop" )
      cedi_WriteToConsoleApp( hEngineApp, "stop" + hb_eol() )
      xq_UCCILogMessage( "> stop (timeout)" )

      // 等待一小段时间让引擎响应stop
      nStart := Seconds()
      DO WHILE Seconds() - nStart < 1.0  // 等待1秒
         cChunk := cedi_ReadFromConsoleApp( hEngineApp )
         IF !Empty( cChunk )
            xq_UCCILogMessage( "< " + AllTrim( StrTran(cChunk, Chr(10), " | ") ) )
            // 如果返回了bestmove，可以提取
            IF "bestmove" $ cChunk
               nPos := At( "bestmove", cChunk )
               IF nPos > 0
                  cTail := LTrim( SubStr( cChunk, nPos + 8 ) )
                  aWords := hb_ATokens( cTail, " " )
                  IF Len( aWords ) >= 1 .AND. Len( aWords[1] ) >= 4
                     cBest := aWords[1]
                     xq_UCCILogMessage( "= bestmove received after timeout: " + cBest )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
         cedi_Sleep( 50 )
      ENDDO

      xq_UCCILogMessage( "= Timeout handling complete" + Iif(!Empty(cBest), ", move obtained", ", no move") )
   ENDIF

   RETURN cBest

//--------------------------------------------------------------------------------

/**
 * 将 UCCI 坐标转换为移动编码（Public 接口）
 * @param cCoord UCCI 坐标（如 "c3c4"）
 * @return nMove 移动编码
 */
function xq_UCCICoordToMovePublic( cCoord )
   RETURN xq_UCCICoordToMove( cCoord )

//--------------------------------------------------------------------------------

/**
 * 将 UCCI 坐标转换为移动编码（内部实现）
 * @param cCoord UCCI 坐标（如 "c3c4"）
 * @return nMove 移动编码
 */
static FUNCTION xq_UCCICoordToMove( cCoord )

   LOCAL cFrom
   LOCAL cTo
   LOCAL nFromCol
   LOCAL nFromRow
   LOCAL nToCol
   LOCAL nToRow
   LOCAL nFromIdx
   LOCAL nToIdx
   LOCAL nResult
   LOCAL cFromCol
   LOCAL cFromRow
   LOCAL cToCol
   LOCAL cToRow

   IF Len( cCoord ) < 4
      RETURN 0
   ENDIF

   // 解析 UCCI 坐标（ICCS 格式）
   // 
   // UCCI 坐标系统定义：
   // - 列: a-i（从左到右），对应 0-8
   // - 行: 0-9（从下到上）
   //   - 行 0 = 红方底线
   //   - 行 9 = 黑方底线
   // - 格式: 列字母 + 行数字（如 "a0"、"e9"）
   //
   // 示例：
   // - "a0" (0, 0) = 红方左侧车
   // - "i0" (0, 8) = 红方右侧车
   // - "e0" (0, 4) = 红方帅
   // - "a9" (9, 0) = 黑方左侧车
   // - "i9" (9, 8) = 黑方右侧车
   // - "e9" (9, 4) = 黑方将
   //
   // 格式: 列字符(a-i) + 行数字(0-9) + 列字符 + 行数字
   // 标准UCCI: 行0=红方底线，行9=黑方底线，不需要反转
   // 支持一位数和两位数行号

   // 提取起始坐标（列字母+行数字）
   cFromCol := Upper( Left( cCoord, 1 ) )
   // 判断坐标格式
   IF Len( cCoord ) == 4
      // 4位格式：列1+行1+列2+行2（如 b7b0）
      cFromRow := SubStr( cCoord, 2, 1 )
      cToCol := Upper( SubStr( cCoord, 3, 1 ) )
      cToRow := SubStr( cCoord, 4, 1 )
   ELSEIF Len( cCoord ) >= 5
      // 5位以上格式：可能包含两位数行号
      IF IsDigit( SubStr( cCoord, 2, 1 ) )
         IF Len( cCoord ) >= 6 .AND. IsDigit( SubStr( cCoord, 3, 1 ) )
            // 两位数起始行号：列1+行2+列2+行1或2（如 b10h7 或 b10h10）
            cFromRow := SubStr( cCoord, 2, 2 )
            cToCol := Upper( SubStr( cCoord, 4, 1 ) )
            cToRow := SubStr( cCoord, 5, 1 )
            IF Len( cCoord ) >= 6 .AND. IsDigit( SubStr( cCoord, 6, 1 ) )
               // 两位数目标行号（如 b10h10）
               cToRow := SubStr( cCoord, 5, 2 )
            ENDIF
         ELSE
            // 一位数起始行号，但总长度>=5（不可能的情况，因为4位格式已经处理了）
            RETURN 0
         ENDIF
      ELSE
         RETURN 0
      ENDIF
   ELSE
      RETURN 0
   ENDIF

   // UCCI列号（0-based）转换为我们的列号（1-based，用于 GUI 显示）
   // 注意：cFromCol 已经被 Upper() 转换为大写了，所以需要还原为小写进行计算
   nFromCol := Asc( Lower( cFromCol ) ) - Asc( 'a' ) + 1  // a->1, b->2, ..., i->9
   nToCol := Asc( Lower( cToCol ) ) - Asc( 'a' ) + 1      // a->1, b->2, ..., i->9

   // UCCI行号转换为数字
   nFromRow := Val( cFromRow )
   nToRow := Val( cToRow )

   // 直接基于 UCCI 坐标计算索引
   // 索引公式：(9 - UCCI行号) * 9 + (UCCI列号 + 1)
   // 这样索引1-9对应黑方底线（UCCI行9），索引82-90对应红方底线（UCCI行0）
   nFromIdx := (9 - nFromRow) * 9 + (Asc( Lower( cFromCol ) ) - Asc( 'a' )) + 1
   nToIdx := (9 - nToRow) * 9 + (Asc( Lower( cToCol ) ) - Asc( 'a' )) + 1

   // 将原始UCCI坐标信息编码，用于调试
   nResult := nFromIdx + nToIdx * 256 + nFromCol * 65536 + nFromRow * 1048576

   // 输出原始UCCI坐标解析结果到日志文件
   // 格式: nFromCol(1-9) nFromRow(1-10) -> nToCol nToRow

   RETURN nFromIdx + nToIdx * 256  // 只返回纯净的移动编码，不包含调试信息