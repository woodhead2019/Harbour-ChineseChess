/*
 * 中国象棋错误处理模块 v2.0
 * Written by freexbase in 2026
 *
 * 改进：
 * - 支持可恢复的错误处理模式
 * - 错误回调机制
 * - 区分致命错误和可恢复错误
 * - 错误历史记录
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 */

#include "error.ch"
#include "build_info.ch"
/***
codling=utf-8
***/

// ============================================================================
// 错误处理模式常量
// ============================================================================

#define XQ_ERROR_MODE_QUIT      1   // 致命错误时退出
#define XQ_ERROR_MODE_RECOVER   2   // 尝试恢复
#define XQ_ERROR_MODE_CALLBACK  3   // 回调处理

// ============================================================================
// 全局状态
// ============================================================================

STATIC s_lInHandler := .F.
STATIC s_nErrorMode := XQ_ERROR_MODE_RECOVER  // 默认恢复模式
STATIC s_bErrorCallback := NIL                 // 错误回调
STATIC s_cLastError := ""                      // 最后错误消息
STATIC s_oLastError := NIL                     // 最后错误对象
STATIC s_nErrorCount := 0                      // 错误计数
STATIC s_aErrorHistory := {}                   // 错误历史

// ============================================================================
// 初始化
// ============================================================================

INIT PROCEDURE XQErrorInit()

   SET CENTURY ON
   SET DATE ANSI
   SET EPOCH TO 1960
   SET EXAC ON

   ErrorBlock( {| oError | xq_ErrorHandler( oError ) } )

   RETURN

// ============================================================================
// 公共 API
// ============================================================================

// 初始化错误处理系统
FUNCTION xq_InitErrorHandling()
   ErrorBlock( {| oError | xq_ErrorHandler( oError ) } )
   RETURN NIL

// 设置错误处理模式
// nMode: XQ_ERROR_MODE_QUIT, XQ_ERROR_MODE_RECOVER, XQ_ERROR_MODE_CALLBACK
FUNCTION xq_SetErrorMode( nMode )
   LOCAL nOldMode := s_nErrorMode
   IF HB_ISNUMERIC( nMode ) .AND. nMode >= 1 .AND. nMode <= 3
      s_nErrorMode := nMode
   ENDIF
   RETURN nOldMode

// 获取当前错误处理模式
FUNCTION xq_GetErrorMode()
   RETURN s_nErrorMode

// 设置错误回调函数
// 回调签名: bCallback( oError, cMessage ) -> lHandled
// 返回 .T. 表示已处理，.F. 表示继续默认处理
FUNCTION xq_SetErrorCallback( bCallback )
   LOCAL bOldCallback := s_bErrorCallback
   IF HB_ISBLOCK( bCallback ) .OR. bCallback == NIL
      s_bErrorCallback := bCallback
   ENDIF
   RETURN bOldCallback

// 获取最后错误消息
FUNCTION xq_GetLastError()
   RETURN s_cLastError

// 获取最后错误对象
FUNCTION xq_GetLastErrorObject()
   RETURN s_oLastError

// 清除最后错误
FUNCTION xq_ClearLastError()
   s_cLastError := ""
   s_oLastError := NIL
   RETURN NIL

// 获取错误计数
FUNCTION xq_GetErrorCount()
   RETURN s_nErrorCount

// 获取错误历史
FUNCTION xq_GetErrorHistory()
   RETURN AClone( s_aErrorHistory )

// 清除错误历史
FUNCTION xq_ClearErrorHistory()
   s_aErrorHistory := {}
   s_nErrorCount := 0
   RETURN NIL

// 判断是否有错误
FUNCTION xq_HasError()
   RETURN !Empty( s_cLastError )

// ============================================================================
// 错误处理器 - 支持可恢复的错误处理
// ============================================================================
/**
 * XQEngine 错误处理器
 *
 * 功能:
 * - 捕获和处理所有运行时错误
 * - 支持三种错误处理模式（QUIT/RECOVER/CALLBACK）
 * - 记录错误历史（最多100条）
 * - 生成 JSON 格式的错误日志
 * - 支持错误回调机制
 * - 递归错误保护
 *
 * 错误处理模式:
 * - XQ_ERROR_MODE_QUIT (1): 致命错误时退出（传统模式）
 * - XQ_ERROR_MODE_RECOVER (2): 尝试恢复（只有致命错误才退出）
 * - XQ_ERROR_MODE_CALLBACK (3): 回调处理（让用户决定如何处理）
 *
 * 参数:
 * - oError (Error 对象): Harbour 错误对象
 *   - 包含错误信息、严重性、调用堆栈等
 *
 * 返回值:
 * - .T. (逻辑值): 错误已被处理（回调模式）
 * - .F. (逻辑值): 错误未被处理或需要恢复
 *
 * 执行流程:
 * 1. 检查递归错误（直接退出）
 * 2. 判断是否致命错误（severity > ES_WARNING）
 * 3. 构建错误消息
 * 4. 记录错误到历史
 * 5. 尝试回调处理（如果是 CALLBACK 模式）
 * 6. 输出错误信息到控制台
 * 7. 保存 JSON 格式的错误日志
 * 8. 根据模式处理错误
 *
 * 错误历史:
 * - 最多保留 100 条错误记录
 * - 每条记录包含: 时间、消息、是否致命、严重性
 * - 可通过 xq_GetErrorHistory() 获取
 *
 * JSON 日志:
 * - 文件名: error_YYYYMMDD_HHMMSS.json
 * - 包含: 错误详情、调用堆栈、时间戳
 * - AI 友好的格式，便于分析
 *
 * 致命错误判断:
 * - severity > ES_WARNING: 致命错误
 * - severity <= ES_WARNING: 可恢复错误
 *
 * 注意事项:
 * - 递归错误会直接退出程序
 * - 回调函数必须返回 .T. 表示已处理
 * - 日志文件写入失败会被忽略
 *
 * 使用示例:
 * // 设置错误处理模式
 * xq_SetErrorMode( XQ_ERROR_MODE_RECOVER )
 *
 * // 设置错误回调
 * xq_SetErrorCallback( {|oError, cMessage|
 *    ? "发生错误:", cMessage
 *    RETURN .T.  // 已处理
 * } )
 *
 * // 获取最后错误
 * IF xq_HasError()
 *    ? xq_GetLastError()
 * ENDIF
 */
STATIC FUNCTION xq_ErrorHandler( oError )

   LOCAL l_cMessage, l_cJSON, l_n, l_cFileName, l_nHandle
   LOCAL l_lFatal, l_lHandled

   // 递归保护
   IF s_lInHandler
      // 递归错误，直接退出
      OutErr( hb_eol() + "=== RECURSIVE ERROR ===" + hb_eol() )
      QUIT
   ENDIF
   s_lInHandler := .T.

   // 判断是否致命错误
   l_lFatal := ( oError:severity > ES_WARNING )

   // 构建错误消息
   l_cMessage := BuildErrorMessage( oError )

   // 记录错误
   s_cLastError := l_cMessage
   s_oLastError := oError
   s_nErrorCount++

   // 添加到历史（最多保留100条）
   IF Len( s_aErrorHistory ) >= 100
      ADel( s_aErrorHistory, 1 )
      ASize( s_aErrorHistory, 99 )
   ENDIF
   AAdd( s_aErrorHistory, { ;
      "time" => Time(), ;
      "message" => l_cMessage, ;
      "fatal" => l_lFatal, ;
      "severity" => oError:severity ;
   } )

   // 尝试回调处理
   l_lHandled := .F.
   IF s_nErrorMode == XQ_ERROR_MODE_CALLBACK .AND. HB_ISBLOCK( s_bErrorCallback )
      BEGIN SEQUENCE
         l_lHandled := Eval( s_bErrorCallback, oError, l_cMessage )
      RECOVER
         l_lHandled := .F.
      END SEQUENCE
   ENDIF

   // 如果回调已处理，则返回
   IF l_lHandled
      s_lInHandler := .F.
      RETURN .T.
   ENDIF

   // 输出错误信息
   xq_OutputError( oError, l_cMessage )

   // 保存日志
   l_cJSON := BuildJSONError( oError, l_cMessage )
   l_cFileName := "error_" + DToS( Date() ) + "_" + StrTran( Time(), ":", "" ) + ".json"

   BEGIN SEQUENCE
      l_nHandle := FCreate( l_cFileName )
      IF l_nHandle >= 0
         FWrite( l_nHandle, l_cJSON )
         FClose( l_nHandle )
         OutErr( "Log saved: " + l_cFileName + hb_eol() )
      ENDIF
   RECOVER
      // 忽略日志写入错误
   END SEQUENCE

   // 根据模式处理
   s_lInHandler := .F.

   DO CASE
   CASE s_nErrorMode == XQ_ERROR_MODE_QUIT
      // 传统模式：总是退出
      ErrorLevel( 1 )
      QUIT

   CASE s_nErrorMode == XQ_ERROR_MODE_RECOVER
      // 恢复模式：只有致命错误才退出
      IF l_lFatal
         OutErr( "Fatal error - exiting" + hb_eol() )
         ErrorLevel( 1 )
         QUIT
      ENDIF
      // 非致命错误，尝试恢复
      OutErr( "Non-fatal error - attempting recovery" + hb_eol() )
      RETURN .F.  // 返回 .F. 让程序继续

   CASE s_nError_MODE_CALLBACK
      // 回调模式：不退出，返回让程序处理
      RETURN .F.
   ENDCASE

   RETURN .F.

// ============================================================================
// 输出错误信息
// ============================================================================

STATIC FUNCTION xq_OutputError( oError, cMessage )

   LOCAL l_n

   OutErr( hb_eol() + "========================================" + hb_eol() )
   OutErr( "XQEngine Error Report" + hb_eol() )
   OutErr( "Build: " + _HBMK_BUILD_DATE_ + " " + _HBMK_BUILD_TIME_ + hb_eol() )
   OutErr( "Mode: " + iif( s_nErrorMode == XQ_ERROR_MODE_QUIT, "QUIT", ;
                      iif( s_nErrorMode == XQ_ERROR_MODE_RECOVER, "RECOVER", "CALLBACK" ) ) + hb_eol() )
   OutErr( "========================================" + hb_eol() )
   OutErr( cMessage + hb_eol() )

   IF ! Empty( oError:osCode )
      OutErr( "OS Error: (DOS Error " + hb_ntos( oError:osCode ) + ")" + hb_eol() )
   ENDIF

   OutErr( "Severity: " + iif( oError:severity > ES_WARNING, "FATAL", "WARNING" ) + hb_eol() )
   OutErr( "GenCode: " + hb_ntos( oError:genCode ) + hb_eol() )

   // 调用堆栈
   OutErr( hb_eol() + "--- Call Stack ---" + hb_eol() )
   l_n := 1
   DO WHILE ! Empty( ProcName( ++l_n ) )
      OutErr( "  " + hb_ntos( l_n - 1 ) + ". " + ProcName( l_n ) + "(" + hb_ntos( ProcLine( l_n ) ) + ")" + hb_eol() )
   ENDDO

   OutErr( "========================================" + hb_eol() )

   RETURN NIL

// ============================================================================
// 辅助函数
// ============================================================================

STATIC FUNCTION BuildErrorMessage( oError )

   LOCAL l_cMessage := iif( oError:severity > ES_WARNING, "Error", "Warning" ) + " "

   l_cMessage += iif( HB_ISSTRING( oError:subsystem ), oError:subsystem, "???" )
   l_cMessage += "/" + iif( HB_ISNUMERIC( oError:subCode ), hb_ntos( oError:subCode ), "???" )

   IF HB_ISSTRING( oError:description )
      l_cMessage += "  " + oError:description
   ENDIF

   DO CASE
   CASE HB_ISSTRING( oError:filename ) .AND. !Empty( oError:filename )
      l_cMessage += ": " + oError:filename
   CASE HB_ISSTRING( oError:operation ) .AND. !Empty( oError:operation )
      l_cMessage += ": " + oError:operation
   ENDCASE

   RETURN l_cMessage

// --------------------------------------------------------------------------------

STATIC FUNCTION BuildJSONError( oError, cMessage )

   LOCAL l_cJSON := "{" + hb_eol()
   LOCAL l_n := 2

   l_cJSON += '  "error": {' + hb_eol()
   l_cJSON += '    "type": "' + iif( oError:severity > ES_WARNING, "ERROR", "WARNING" ) + '",' + hb_eol()
   l_cJSON += '    "message": ' + hb_jsonEncode( cMessage ) + "," + hb_eol()
   l_cJSON += '    "subsystem": ' + hb_jsonEncode( iif( HB_ISSTRING( oError:subsystem ), oError:subsystem, "???" ) ) + "," + hb_eol()
   l_cJSON += '    "code": ' + iif( HB_ISNUMERIC( oError:subCode ), hb_ntos( oError:subCode ), "null" ) + "," + hb_eol()
   l_cJSON += '    "description": ' + hb_jsonEncode( iif( HB_ISSTRING( oError:description ), oError:description, "" ) ) + "," + hb_eol()
   l_cJSON += '    "operation": ' + hb_jsonEncode( iif( HB_ISSTRING( oError:operation ), oError:operation, "" ) ) + "," + hb_eol()
   l_cJSON += '    "filename": ' + hb_jsonEncode( iif( HB_ISSTRING( oError:filename ), oError:filename, "" ) ) + "," + hb_eol()
   l_cJSON += '    "severity": ' + hb_ntos( oError:severity ) + "," + hb_eol()
   l_cJSON += '    "gencode": ' + hb_ntos( oError:genCode ) + "," + hb_eol()
   l_cJSON += '    "os_code": ' + iif( !Empty( oError:osCode ), hb_ntos( oError:osCode ), "null" ) + hb_eol()
   l_cJSON += '  },' + hb_eol()

   // 处理模式
   l_cJSON += '  "mode": "' + iif( s_nErrorMode == XQ_ERROR_MODE_QUIT, "QUIT", ;
                              iif( s_nErrorMode == XQ_ERROR_MODE_RECOVER, "RECOVER", "CALLBACK" ) ) + '",' + hb_eol()

   // 堆栈
   l_cJSON += '  "stacktrace": [' + hb_eol()
   DO WHILE ! Empty( ProcName( l_n ) )
      IF l_n > 2
         l_cJSON += "," + hb_eol()
      ENDIF
      l_cJSON += '    {"level": ' + hb_ntos( l_n - 1 ) + ', "function": ' + hb_jsonEncode( ProcName( l_n ) ) + ', "line": ' + hb_ntos( ProcLine( l_n ) ) + '}'
      l_n++
   ENDDO
   l_cJSON += hb_eol() + '  ],' + hb_eol()

   // 时间戳
   l_cJSON += '  "timestamp": "' + DToS( Date() ) + ' ' + Time() + '"' + hb_eol()
   l_cJSON += "}"

   RETURN l_cJSON

// ============================================================================
// 便捷函数 - 用于 XQEngine 类
// ============================================================================

// 安全执行代码块，捕获错误
// 返回: { success => lOk, result => xResult, error => cError }
/**
 * 安全执行代码块，捕获所有错误
 *
 * 功能:
 * - 执行指定的代码块
 * - 捕获所有运行时错误
 * - 返回结构化的结果
 * - 不会导致程序崩溃
 *
 * 参数:
 * - bBlock (代码块): 要执行的代码块
 *   - 必须是有效的代码块
 *   - 可以接受参数
 * - ... (可变参数): 传递给代码块的参数
 *
 * 返回值:
 * - 哈希表: 包含以下字段
 *   - "success" (逻辑值): 是否成功执行
 *   - "result" (任意): 执行结果（成功时）
 *   - "error" (字符串): 错误消息（失败时）
 *   - "errorObj" (Error 对象): 错误对象（失败时）
 *
 * 使用场景:
 * - 执行可能失败的代码
 * - 测试引擎功能
 * - 处理不确定的操作
 * - 单元测试
 *
 * 注意事项:
 * - 代码块必须有效，否则返回错误
 * - 错误被捕获，不会传播到错误处理器
 * - 可以传递参数到代码块
 *
 * 使用示例:
 * // 安全执行引擎操作
 * LOCAL oResult := xq_SafeExec( {|| oEngine:Start() } )
 * IF oResult["success"]
 *    ? "引擎启动成功"
 * ELSE
 *    ? "引擎启动失败:", oResult["error"]
 * ENDIF
 *
 * // 带参数的代码块
 * oResult := xq_SafeExec( {|oEngine, cFEN| oEngine:Analyze( cFEN, 5000 ) }, oEngine, "startpos" )
 *
 * // 处理错误
 * IF ! oResult["success"]
 *    ? "错误:", oResult["error"]
 *    ? "错误对象:", oResult["errorObj"]:description
 * ENDIF
 */
FUNCTION xq_SafeExec( bBlock, ... )

   LOCAL l_oResult := { => }
   LOCAL l_oError

   HB_HSet( l_oResult, "success", .F. )
   HB_HSet( l_oResult, "result", NIL )
   HB_HSet( l_oResult, "error", "" )

   IF !HB_ISBLOCK( bBlock )
      HB_HSet( l_oResult, "error", "Invalid block" )
      RETURN l_oResult
   ENDIF

   BEGIN SEQUENCE
      HB_HSet( l_oResult, "result", Eval( bBlock, ... ) )
      HB_HSet( l_oResult, "success", .T. )
   RECOVER USING l_oError
      HB_HSet( l_oResult, "error", BuildErrorMessage( l_oError ) )
      HB_HSet( l_oResult, "errorObj", l_oError )
   END SEQUENCE

   RETURN l_oResult

// 创建错误对象（用于手动抛出错误）
FUNCTION xq_CreateError( cMessage, nCode, cOperation )

   LOCAL l_oError := ErrorNew()

   l_oError:description := cMessage
   l_oError:subCode := iif( HB_ISNUMERIC( nCode ), nCode, 0 )
   l_oError:operation := iif( HB_ISSTRING( cOperation ), cOperation, "" )
   l_oError:severity := ES_ERROR
   l_oError:subsystem := "XQEngine"

   RETURN l_oError

// 抛出 XQEngine 错误
FUNCTION xq_ThrowError( cMessage, nCode, cOperation )

   LOCAL l_oError := xq_CreateError( cMessage, nCode, cOperation )
   Eval( ErrorBlock(), l_oError )

   RETURN NIL
