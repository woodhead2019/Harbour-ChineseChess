/*
 * 中国象棋错误处理模块
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 */

#include "error.ch"
#include "xq_xiangqi.ch"
/***
codling=utf-8
***/

REQUEST HB_LANG_zh_sim
// REQUEST HB_CODEPAGE_UTF8EX  // 不在此处设置，由 Main() 函数统一设置为 UTF8EX


INIT PROCEDURE MyXQInit()

   SET CENTURY ON
   SET DATE ANSI
   SET EPOCH TO 1960
   SET EXAC ON

   // hwg_writelog( "Program " + DToC( Date() ) + " at " + Time() + "run start", "myinit.log" )
   // HiWinWriteLog( "myinit启动" )

   // 不在此处设置代码页，让Main()函数统一设置为UTF8
   // hb_cdpSelect( 'UTF8EX' )  // 已移除，避免在引擎通信时出现问题

   hb_langSelect( 'zh_sim' )

   ErrorBlock( {| oError | xq_ErrorHandler( oError ) } )

   RETURN

// --------------------------------------------------------------------------------
FUNCTION xq_InitErrorHandling()

   ErrorBlock( {| oError | xq_ErrorHandler( oError ) } )

   RETURN NIL

// AI 友好的错误处理器 - 记录并退出
// --------------------------------------------------------------------------------

STATIC FUNCTION xq_ErrorHandler( oError )
   LOCAL l_cMessage, l_cJSON, l_n, l_cFileName, l_nHandle
   LOCAL l_dNow, l_cTimeStamp

   // 构建错误消息
   l_cMessage := BuildErrorMessage( oError )

   // 输出到控制台
   OutErr( hb_eol() + "========================================" + hb_eol() )
   OutErr( "Chinese Chess - Error Report" + hb_eol() )
   OutErr( "Build: " + _HBMK_BUILD_DATE_ + " " + _HBMK_BUILD_TIME_ + hb_eol() )
   OutErr( "========================================" + hb_eol() )
   OutErr( l_cMessage + hb_eol() )

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

   // JSON 输出（暂时禁用，避免可能的函数调用错误）
   // l_cJSON := BuildJSONError( oError, l_cMessage )
   // OutErr( hb_eol() + "--- JSON ---" + hb_eol() + l_cJSON + hb_eol() )

   // 生成时间戳和文件名 - 使用 hb_TToC 替代
   // l_dNow := hb_DateTime()
   // l_cTimeStamp := hb_TToC( l_dNow, "YYYYMMDD", "HHMMSS" )
   // l_cFileName := "error_" + l_cTimeStamp + ".json"
   l_cFileName := "error_" + DToS( Date() ) + "_" + StrTran( Time(), ":", "" ) + ".txt"

   // 确保 logs 目录存在
   IF !hb_DirExists( "logs" )
      hb_DirCreate( "logs" )
   ENDIF

   // 保存日志到 logs 目录（使用纯文本格式）
   BEGIN SEQUENCE
      l_cFileName := "logs/" + l_cFileName
      l_nHandle := FCreate( l_cFileName )
      IF l_nHandle >= 0
         FWrite( l_nHandle, l_cMessage )
         FClose( l_nHandle )
         OutErr( "Log saved: " + l_cFileName + hb_eol() )
      ELSE
         OutErr( "Warning: Cannot create log file" + hb_eol() )
      ENDIF
   recover
      OutErr( "Warning: Error writing to log file" + hb_eol() )
   END SEQUENCE

   OutErr( "========================================" + hb_eol() )

   // 退出
   ErrorLevel( 1 )
   QUIT

   RETURN .F.

// --------------------------------------------------------------------------------

// ========== 辅助函数 ==========

// --------------------------------------------------------------------------------

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
   LOCAL l_dNow

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

   // 时间戳 - 使用 hb_TToC 替代
   // l_dNow := hb_DateTime()
   // l_cJSON += '  "timestamp": ' + hb_jsonEncode( hb_TToC( l_dNow, "YYYY-MM-DD", "HH:MM:SS" ) ) + hb_eol()
   l_cJSON += '  "timestamp": "' + DToS( Date() ) + ' ' + Time() + '"' + hb_eol()
   l_cJSON += "}"

   RETURN l_cJSON

// --------------------------------------------------------------------------------
