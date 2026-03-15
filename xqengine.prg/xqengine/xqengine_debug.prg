/*
 * xqengine_debug.prg
 * XQEngine 调试工具模块
 *
 * 功能:
 * - 统一的调试输出接口
 * - 可配置的调试级别
 * - 支持日期时间戳
 * - 支持日志文件输出
 *
 * 使用方法:
 *   XQECI_SetDebugLevel( XQECI_DEBUG_LEVEL_DEBUG )
 *   XQECI_Info( XQECI_MODULE_CORE, "正在启动引擎" )
 *   XQECI_DebugF( XQECI_MODULE_CORE, "参数: %s, 数值: %d", cParam, nValue )
 */

#include "hbclass.ch"
#include "fileio.ch"
#include "xqengine_constants.ch"

// ============================================================================
// 静态变量 - 调试配置
// ============================================================================
STATIC s_nDebugLevel := XQECI_DEBUG_LEVEL_ERROR   // 默认仅输出错误
STATIC s_lShowTime := .T.                          // 默认显示时间
STATIC s_lShowMs := .F.                            // 默认不显示毫秒
STATIC s_cLogFile := ""                            // 日志文件路径
STATIC s_nLogFileHandle := -1                      // 日志文件句柄

// ============================================================================
// 初始化函数
// ============================================================================

/**
 * 初始化调试系统
 *
 * 参数:
 *   nLevel    - 调试级别 (0-5)
 *   cLogFile  - 日志文件路径 (可选)
 *   lShowTime - 是否显示时间 (默认 .T.)
 */
PROCEDURE XQECI_DebugInit( nLevel, cLogFile, lShowTime )

   IF HB_ISNUMERIC( nLevel ) .AND. nLevel >= 0 .AND. nLevel <= 5
      s_nDebugLevel := nLevel
   ENDIF

   IF HB_ISSTRING( cLogFile ) .AND. !Empty( cLogFile )
      s_cLogFile := cLogFile
      XQECI_OpenLogFile()
   ENDIF

   IF HB_ISLOGICAL( lShowTime )
      s_lShowTime := lShowTime
   ENDIF

   RETURN

/**
 * 设置调试级别
 */
PROCEDURE XQECI_SetDebugLevel( nLevel )

   IF HB_ISNUMERIC( nLevel ) .AND. nLevel >= 0 .AND. nLevel <= 5
      s_nDebugLevel := nLevel
   ENDIF

   RETURN

/**
 * 获取当前调试级别
 */
FUNCTION XQECI_GetDebugLevel()
   RETURN s_nDebugLevel

/**
 * 设置是否显示时间
 *
 * 参数:
 *   lShow   - 是否显示时间
 *   lShowMs - 是否显示毫秒 (可选)
 */
PROCEDURE XQECI_SetShowTime( lShow, lShowMs )

   IF HB_ISLOGICAL( lShow )
      s_lShowTime := lShow
   ENDIF

   IF HB_ISLOGICAL( lShowMs )
      s_lShowMs := lShowMs
   ENDIF

   RETURN

/**
 * 设置日志文件
 */
PROCEDURE XQECI_SetLogFile( cFile )

   // 先关闭现有文件
   XQECI_CloseLogFile()

   IF HB_ISSTRING( cFile ) .AND. !Empty( cFile )
      s_cLogFile := cFile
      XQECI_OpenLogFile()
   ENDIF

   RETURN

/**
 * 关闭调试系统
 */
PROCEDURE XQECI_CloseDebug()
   XQECI_CloseLogFile()
   RETURN

// ============================================================================
// 核心日志输出函数
// ============================================================================

/**
 * 核心日志输出函数
 *
 * 格式: 时间戳 [模块] [级别] 消息
 */
PROCEDURE XQECI_Log( nLevel, cModule, cMessage )

   LOCAL cOutput
   LOCAL cTimeStr
   LOCAL cLevelStr

   // 检查级别
   IF s_nDebugLevel < nLevel
      RETURN
   ENDIF

   // 构建时间戳
   IF s_lShowTime
      IF s_lShowMs
         cTimeStr := DToS( Date() ) + " " + Time() + "." + ;
                     StrZero( hb_MilliSeconds() % 1000, 3 ) + " "
      ELSE
         cTimeStr := DToS( Date() ) + " " + Time() + " "
      ENDIF
   ELSE
      cTimeStr := ""
   ENDIF

   // 获取级别字符串
   DO CASE
   CASE nLevel == XQECI_DEBUG_LEVEL_ERROR
      cLevelStr := XQECI_LOG_ERROR
   CASE nLevel == XQECI_DEBUG_LEVEL_WARN
      cLevelStr := XQECI_LOG_WARN
   CASE nLevel == XQECI_DEBUG_LEVEL_INFO
      cLevelStr := XQECI_LOG_INFO
   CASE nLevel == XQECI_DEBUG_LEVEL_DEBUG
      cLevelStr := XQECI_LOG_DEBUG
   CASE nLevel == XQECI_DEBUG_LEVEL_TRACE
      cLevelStr := XQECI_LOG_TRACE
   OTHERWISE
      cLevelStr := "[LOG]"
   ENDCASE

   // 组装输出
   cOutput := cTimeStr + cModule + " " + cLevelStr + " " + cMessage

   // 控制台输出
   ? cOutput

   // 文件输出
   IF s_nLogFileHandle >= 0
      BEGIN SEQUENCE
         FWrite( s_nLogFileHandle, cOutput + hb_eol() )
      RECOVER
         // 写入失败，忽略
      END SEQUENCE
   ENDIF

   RETURN

// ============================================================================
// 便捷输出函数 - 基础版
// ============================================================================

/**
 * 输出错误日志
 */
PROCEDURE XQECI_Error( cModule, cMessage )
   XQECI_Log( XQECI_DEBUG_LEVEL_ERROR, cModule, cMessage )
   RETURN

/**
 * 输出警告日志
 */
PROCEDURE XQECI_Warn( cModule, cMessage )
   XQECI_Log( XQECI_DEBUG_LEVEL_WARN, cModule, cMessage )
   RETURN

/**
 * 输出信息日志
 */
PROCEDURE XQECI_Info( cModule, cMessage )
   XQECI_Log( XQECI_DEBUG_LEVEL_INFO, cModule, cMessage )
   RETURN

/**
 * 输出调试日志
 */
PROCEDURE XQECI_Debug( cModule, cMessage )
   XQECI_Log( XQECI_DEBUG_LEVEL_DEBUG, cModule, cMessage )
   RETURN

/**
 * 输出跟踪日志
 */
PROCEDURE XQECI_Trace( cModule, cMessage )
   XQECI_Log( XQECI_DEBUG_LEVEL_TRACE, cModule, cMessage )
   RETURN

// ============================================================================
// 便捷输出函数 - 格式化版
// ============================================================================

/**
 * 格式化错误输出
 * 用法: XQECI_ErrorF( XQECI_MODULE_CORE, "启动失败: %s", cPath )
 */
PROCEDURE XQECI_ErrorF( cModule, cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 )
   XQECI_Log( XQECI_DEBUG_LEVEL_ERROR, cModule, ;
              XQECI_Format( cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 ) )
   RETURN

/**
 * 格式化警告输出
 */
PROCEDURE XQECI_WarnF( cModule, cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 )
   XQECI_Log( XQECI_DEBUG_LEVEL_WARN, cModule, ;
              XQECI_Format( cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 ) )
   RETURN

/**
 * 格式化信息输出
 */
PROCEDURE XQECI_InfoF( cModule, cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 )
   XQECI_Log( XQECI_DEBUG_LEVEL_INFO, cModule, ;
              XQECI_Format( cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 ) )
   RETURN

/**
 * 格式化调试输出
 */
PROCEDURE XQECI_DebugF( cModule, cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 )
   XQECI_Log( XQECI_DEBUG_LEVEL_DEBUG, cModule, ;
              XQECI_Format( cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 ) )
   RETURN

/**
 * 格式化跟踪输出
 */
PROCEDURE XQECI_TraceF( cModule, cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 )
   XQECI_Log( XQECI_DEBUG_LEVEL_TRACE, cModule, ;
              XQECI_Format( cFormat, cParam1, cParam2, cParam3, cParam4, cParam5 ) )
   RETURN

// ============================================================================
// 内部辅助函数
// ============================================================================

/**
 * 简单格式化函数
 * 支持: %s (字符串), %d (整数), %f (浮点)
 */
STATIC FUNCTION XQECI_Format( cFormat, cP1, cP2, cP3, cP4, cP5 )

   LOCAL cResult := cFormat
   LOCAL aParams := { cP1, cP2, cP3, cP4, cP5 }
   LOCAL i, cParam, cSpec

   FOR i := 1 TO Len( aParams )
      cParam := aParams[i]

      // 查找格式说明符
      cSpec := "%" + LTrim( Str( i ) )  // %1, %2, ...

      IF cSpec $ cResult
         IF cParam == NIL
            cParam := "(nil)"
         ELSEIF HB_ISNUMERIC( cParam )
            cParam := LTrim( Str( cParam ) )
         ELSEIF HB_ISLOGICAL( cParam )
            cParam := iif( cParam, ".T.", ".F." )
         ENDIF

         cResult := StrTran( cResult, cSpec, cParam )
      ENDIF
   NEXT

   // 兼容 %s 和 %d 格式
   IF "%s" $ cResult .AND. aParams[1] != NIL
      cResult := StrTran( cResult, "%s", cValToStr( aParams[1] ), , 1 )
   ENDIF

   IF "%d" $ cResult .AND. HB_ISNUMERIC( aParams[1] )
      cResult := StrTran( cResult, "%d", LTrim( Str( aParams[1] ) ), , 1 )
   ENDIF

   RETURN cResult

/**
 * 值转字符串
 */
STATIC FUNCTION cValToStr( xValue )

   DO CASE
   CASE xValue == NIL
      RETURN "(nil)"
   CASE HB_ISSTRING( xValue )
      RETURN xValue
   CASE HB_ISNUMERIC( xValue )
      RETURN LTrim( Str( xValue ) )
   CASE HB_ISLOGICAL( xValue )
      RETURN iif( xValue, ".T.", ".F." )
   CASE HB_ISARRAY( xValue )
      RETURN "{array:" + LTrim( Str( Len( xValue ) ) ) + "}"
   CASE HB_ISHASH( xValue )
      RETURN "{hash:" + LTrim( Str( Len( xValue ) ) ) + "}"
   CASE HB_ISOBJECT( xValue )
      RETURN "{object}"
   OTHERWISE
      RETURN "{unknown}"
   ENDCASE

// ============================================================================
// 日志文件管理
// ============================================================================

/**
 * 打开日志文件
 */
STATIC PROCEDURE XQECI_OpenLogFile()

   IF Empty( s_cLogFile )
      RETURN
   ENDIF

   BEGIN SEQUENCE
      IF File( s_cLogFile )
         s_nLogFileHandle := FOpen( s_cLogFile, 2 )  // 读写模式
         IF s_nLogFileHandle >= 0
            FSeek( s_nLogFileHandle, 0, 2 )  // 定位到末尾
         ENDIF
      ELSE
         s_nLogFileHandle := FCreate( s_cLogFile )
      ENDIF
   RECOVER
      s_nLogFileHandle := -1
   END SEQUENCE

   RETURN

/**
 * 关闭日志文件
 */
STATIC PROCEDURE XQECI_CloseLogFile()

   IF s_nLogFileHandle >= 0
      BEGIN SEQUENCE
         FClose( s_nLogFileHandle )
      RECOVER
      END SEQUENCE
      s_nLogFileHandle := -1
   ENDIF

   RETURN

// ============================================================================
// 测试函数
// ============================================================================

PROCEDURE Test_XQECI_Debug()

   XQECI_Info( XQECI_MODULE_TEST, "=== XQECI Debug Module Test ===" )
   XQECI_Info( XQECI_MODULE_TEST, "" )

   // 测试各级别输出
   XQECI_Info( XQECI_MODULE_TEST, "1. Testing output levels:" )
   XQECI_SetDebugLevel( XQECI_DEBUG_LEVEL_DEBUG )
   XQECI_Error( XQECI_MODULE_CORE, "This is an error message" )
   XQECI_Warn( XQECI_MODULE_CORE, "This is a warning message" )
   XQECI_Info( XQECI_MODULE_CORE, "This is an info message" )
   XQECI_Debug( XQECI_MODULE_CORE, "This is a debug message" )
   XQECI_Trace( XQECI_MODULE_CORE, "This is a trace message (TRACE level not output)" )

   XQECI_Info( XQECI_MODULE_TEST, "" )
   XQECI_Info( XQECI_MODULE_TEST, "2. Testing formatted output:" )
   XQECI_InfoF( XQECI_MODULE_CORE, "Parameter: %1, Value: %2", "test", 123 )
   XQECI_DebugF( XQECI_MODULE_PROTOCOL, "Protocol: %1, Version: %2", "UCI", "1.0" )

   XQECI_Info( XQECI_MODULE_TEST, "" )
   XQECI_Info( XQECI_MODULE_TEST, "3. Testing log file output:" )
   XQECI_SetLogFile( "xqeci_test.log" )
   XQECI_Info( XQECI_MODULE_CORE, "This message will be written to file" )
   XQECI_CloseDebug()
   XQECI_Info( XQECI_MODULE_TEST, "Log written to xqeci_test.log" )

   XQECI_Info( XQECI_MODULE_TEST, "" )
   XQECI_Info( XQECI_MODULE_TEST, "=== Test Complete ===" )

   RETURN
