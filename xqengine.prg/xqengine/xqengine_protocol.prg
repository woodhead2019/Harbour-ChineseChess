/*
 * xqengine_protocol.prg
 * 引擎协议抽象基类（策略模式）
 *
 * 功能:
 * - 定义引擎协议的统一接口
 * - 提供协议无关的抽象方法
 * - 支持多种协议（UCCI/UCI）
 *
 * 设计模式:
 * - 策略模式（Strategy Pattern）
 * - 子类实现具体协议细节
 *
 * 子类:
 * - UCIProtocol: UCI 协议实现
 * - UCCIProtocol: UCCI 协议实现
 *
 * 使用示例:
 * LOCAL oProtocol := UCIProtocol():New()
 * LOCAL cCmd := oProtocol:BuildInit()
 * LOCAL cPosCmd := oProtocol:BuildPosition( "startpos", "e2e4" )
 * LOCAL cGoCmd := oProtocol:BuildGo( 10, 5000, 0 )
 */

#include "hbclass.ch"
#include "xqengine_constants.ch"

// ============================================================================
// EngineProtocol 类 - 引擎协议抽象基类
// ============================================================================
/**
 * 引擎协议抽象基类，定义所有协议共有的接口
 *
 * 功能:
 * - 定义协议初始化、命令构建、响应解析的统一接口
 * - 子类实现具体协议细节
 * - 提供协议无关的抽象方法
 *
 * 设计原则:
 * - 依赖倒置原则（DIP）：XQEngine 依赖抽象而非具体实现
 * - 开闭原则（OCP）：对扩展开放，对修改关闭
 * - 单一职责原则（SRP）：每个协议类负责自己的协议实现
 *
 * 抽象方法（子类必须实现）:
 * - GetProtocolName(): 获取协议名称
 * - GetInitCommand(): 获取初始化命令字符串
 * - IsInitOK(): 检查初始化是否成功
 * - BuildInit(): 构建初始化命令
 * - BuildIsReady(): 构建 isready 命令
 * - BuildPosition(): 构建局面设置命令
 * - BuildGo(): 构建 go 命令
 * - BuildStop(): 构建停止命令
 * - BuildQuit(): 构建退出命令
 * - ParseResponse(): 解析响应
 *
 * 共享方法（基类提供默认实现）:
 * - ParseInfo(): 解析 info 行（子类可覆盖）
 * - ParseBestMove(): 解析 bestmove 行（子类可覆盖）
 * - BuildSetOption(): 构建 setoption 命令
 * - BuildId(): 构建 id 响应
 * - BuildInfo(): 构建 info 响应
 * - BuildBestMove(): 构建 bestmove 响应
 * - BuildReadyOK(): 构建 readyok 响应
 * - SplitLine(): 分割命令行
 * - TrimQuotes(): 去除引号
 */
CREATE CLASS EngineProtocol

   // 引擎信息
   VAR cEngineName     INIT "Unknown"
   VAR cEngineVersion  INIT ""
   VAR cEngineAuthor   INIT ""

   // 协议信息
   VAR cProtocolVersion INIT "2.0"

   // 抽象方法 - 子类必须实现
   METHOD GetProtocolName()  // 获取协议名称
   METHOD GetInitCommand()   // 获取初始化命令字符串（"uci" 或 "ucci"）
   METHOD IsInitOK( cResponse )  // 检查初始化是否成功（收到 "uciok" 或 "ucciok"）

   // 构建命令 - 子类必须实现
   METHOD BuildInit()
   METHOD BuildIsReady()
   METHOD BuildPosition( cFEN, cMoves )
   METHOD BuildGo( nDepth, nTime, nNodes )
   METHOD BuildStop()
   METHOD BuildQuit()

   // 解析响应 - 子类必须实现
   METHOD ParseResponse( cResponse )

   // 共享方法 - 基类提供默认实现
   METHOD ParseInfo( cLine, oResult )
   METHOD ParseBestMove( cLine )
   METHOD BuildSetOption( cName, cValue )
   METHOD BuildId( cName, cValue )
   METHOD BuildInfo( hParams )
   METHOD BuildBestMove( cMove, cPonder )
   METHOD BuildReadyOK()
   METHOD SplitLine( cLine )
   METHOD TrimQuotes( cStr )

ENDCLASS

// ============================================================================
// 抽象方法 - 子类必须实现
// ============================================================================

METHOD GetProtocolName() CLASS EngineProtocol
   RETURN "Unknown"

METHOD GetInitCommand() CLASS EngineProtocol
   RETURN ""

METHOD IsInitOK( cResponse ) CLASS EngineProtocol
   RETURN .F.

METHOD BuildInit() CLASS EngineProtocol
   RETURN ""

METHOD BuildIsReady() CLASS EngineProtocol
   RETURN "isready"

METHOD BuildPosition( cFEN, cMoves ) CLASS EngineProtocol
   RETURN ""

METHOD BuildGo( nDepth, nTime, nNodes ) CLASS EngineProtocol
   RETURN ""

METHOD BuildStop() CLASS EngineProtocol
   RETURN "stop"

METHOD BuildQuit() CLASS EngineProtocol
   RETURN "quit"

METHOD ParseResponse( cResponse ) CLASS EngineProtocol
   RETURN { => }

// ============================================================================
// 共享方法 - 基类提供默认实现
// ============================================================================

/**
 * 解析 info 行 - 提取深度、评分、时间、节点数、主变例等信息
 *
 * 参数:
 * - cLine (字符串): info 行内容
 * - oResult (哈希表): 结果哈希表，用于存储解析结果
 *
 * 返回值:
 * - NIL
 *
 * 默认实现支持以下关键字:
 * - depth: 搜索深度
 * - score: 评分（cp分值）
 * - mate: 杀棋步数
 * - time: 搜索时间（毫秒）
 * - nodes: 搜索节点数
 * - pv: 主变例（最佳着法序列）
 *
 * 子类可以覆盖此方法以支持更多关键字
 */
METHOD ParseInfo( cLine, oResult ) CLASS EngineProtocol

   LOCAL aParts
   LOCAL i

   aParts := ::SplitLine( cLine )

   FOR i := 2 TO Len( aParts )
      SWITCH Lower( aParts[i] )
         CASE "depth"
            IF i + 1 <= Len( aParts )
               HB_HSet( oResult, "depth", Val( aParts[i + 1] ) )
            ENDIF

         CASE "score"
            IF i + 1 <= Len( aParts )
               IF Lower( aParts[i + 1] ) == "mate"
                  IF i + 2 <= Len( aParts )
                     HB_HSet( oResult, "mate", Val( aParts[i + 2] ) )
                  ENDIF
               ELSE
                  HB_HSet( oResult, "score", Val( aParts[i + 1] ) )
               ENDIF
            ENDIF

         CASE "time"
            IF i + 1 <= Len( aParts )
               HB_HSet( oResult, "time", Val( aParts[i + 1] ) )
            ENDIF

         CASE "nodes"
            IF i + 1 <= Len( aParts )
               HB_HSet( oResult, "nodes", Val( aParts[i + 1] ) )
            ENDIF

         CASE "pv"
            HB_HSet( oResult, "pv", SubStr( cLine, At( "pv", cLine ) + 3 ) )
            HB_HSet( oResult, "pv", AllTrim( HB_HGet( oResult, "pv" ) ) )
      ENDSWITCH
   NEXT

   RETURN NIL

/**
 * 解析 bestmove 行 - 提取最佳着法和思考着法
 *
 * 参数:
 * - cLine (字符串): bestmove 行内容
 *
 * 返回值:
 * - 哈希表: 包含 move 和 ponder 字段
 *
 * 默认实现支持以下格式:
 * - "bestmove e2e4"
 * - "bestmove e2e4 ponder e7e5"
 *
 * 子类可以覆盖此方法以支持更多格式
 */
METHOD ParseBestMove( cLine ) CLASS EngineProtocol
   RETURN ::ParseResponse( cLine )

/**
 * 构建 setoption 命令 - 设置引擎选项
 *
 * 参数:
 * - cName (字符串): 选项名称
 * - cValue (字符串): 选项值（可选）
 *
 * 返回值:
 * - 字符串: setoption 命令
 *
 * 示例:
 * - BuildSetOption( "Hash", "256" ) -> "setoption name Hash value 256"
 * - BuildSetOption( "Clear Hash" ) -> "setoption name Clear Hash"
 */
METHOD BuildSetOption( cName, cValue ) CLASS EngineProtocol

   IF cName == NIL
      cName := ""
   ENDIF

   IF cValue == NIL
      cValue := ""
   ENDIF

   IF Empty( cValue )
      RETURN "setoption name " + cName
   ELSE
      RETURN "setoption name " + cName + " value " + cValue
   ENDIF

/**
 * 构建 id 响应 - 引擎标识信息
 *
 * 参数:
 * - cName (字符串): 标识字段名称（name, author, version）
 * - cValue (字符串): 标识字段值
 *
 * 返回值:
 * - 字符串: id 响应
 *
 * 示例:
 * - BuildId( "name", "Pikafish" ) -> "id name Pikafish"
 */
METHOD BuildId( cName, cValue ) CLASS EngineProtocol
   RETURN "id " + cName + " " + cValue

/**
 * 构建 info 响应 - 分析信息
 *
 * 参数:
 * - hParams (哈希表): info 参数
 *   - depth: 搜索深度
 *   - score: 评分
 *   - time: 搜索时间
 *   - nodes: 搜索节点数
 *   - pv: 主变例
 *
 * 返回值:
 * - 字符串: info 响应
 *
 * 示例:
 * - BuildInfo( {"depth"=>10, "score"=>120, "pv"=>"e2e4 e7e5"} )
 *   -> "info depth 10 score 120 pv e2e4 e7e5"
 */
METHOD BuildInfo( hParams ) CLASS EngineProtocol

   LOCAL cResponse := "info"

   IF HB_ISHASH( hParams )
      IF "depth" $ hParams
         cResponse += " depth " + LTrim( Str( hParams["depth"] ) )
      ENDIF

      IF "score" $ hParams
         cResponse += " score " + LTrim( Str( hParams["score"] ) )
      ENDIF

      IF "time" $ hParams
         cResponse += " time " + LTrim( Str( hParams["time"] ) )
      ENDIF

      IF "nodes" $ hParams
         cResponse += " nodes " + LTrim( Str( hParams["nodes"] ) )
      ENDIF

      IF "pv" $ hParams
         cResponse += " pv " + hParams["pv"]
      ENDIF
   ENDIF

   RETURN cResponse

/**
 * 构建 bestmove 响应 - 最佳着法
 *
 * 参数:
 * - cMove (字符串): 最佳着法
 * - cPonder (字符串): 思考着法（可选）
 *
 * 返回值:
 * - 字符串: bestmove 响应
 *
 * 示例:
 * - BuildBestMove( "e2e4" ) -> "bestmove e2e4"
 * - BuildBestMove( "e2e4", "e7e5" ) -> "bestmove e2e4 ponder e7e5"
 */
METHOD BuildBestMove( cMove, cPonder ) CLASS EngineProtocol

   IF cMove == NIL
      cMove := ""
   ENDIF

   IF cPonder == NIL
      cPonder := ""
   ENDIF

   IF Empty( cPonder )
      RETURN "bestmove " + cMove
   ELSE
      RETURN "bestmove " + cMove + " ponder " + cPonder
   ENDIF

/**
 * 构建 readyok 响应 - 就绪确认
 *
 * 返回值:
 * - 字符串: "readyok"
 */
METHOD BuildReadyOK() CLASS EngineProtocol
   RETURN "readyok"

/**
 * 分割命令行 - 按空格分割，支持引号
 *
 * 参数:
 * - cLine (字符串): 要分割的命令行
 *
 * 返回值:
 * - 数组: 分割后的单词数组
 *
 * 功能:
 * - 按空格分割命令行
 * - 支持引号内的空格（不分割）
 * - 自动去除引号
 *
 * 示例:
 * - SplitLine( "position startpos moves e2e4 e7e5" )
 *   -> {"position", "startpos", "moves", "e2e4", "e7e5"}
 * - SplitLine( "setoption name \"My Option\" value 123" )
 *   -> {"setoption", "name", "My Option", "value", "123"}
 */
METHOD SplitLine( cLine ) CLASS EngineProtocol

   LOCAL aResult := {}
   LOCAL cWord := ""
   LOCAL lInQuotes := .F.
   LOCAL i
   LOCAL ch

   IF Empty( cLine )
      RETURN aResult
   ENDIF

   FOR i := 1 TO Len( cLine )
      ch := SubStr( cLine, i, 1 )

      IF ch == '"'
         lInQuotes := ! lInQuotes
      ELSEIF ch == " " .AND. ! lInQuotes
         IF ! Empty( cWord )
            AAdd( aResult, cWord )
            cWord := ""
         ENDIF
      ELSE
         cWord += ch
      ENDIF
   NEXT

   IF ! Empty( cWord )
      AAdd( aResult, cWord )
   ENDIF

   RETURN aResult

/**
 * 去除引号 - 去除字符串两端的引号
 *
 * 参数:
 * - cStr (字符串): 要处理的字符串
 *
 * 返回值:
 * - 字符串: 去除引号后的字符串
 *
 * 示例:
 * - TrimQuotes( '"My Value"' ) -> "My Value"
 * - TrimQuotes( "My Value" ) -> "My Value"
 */
METHOD TrimQuotes( cStr ) CLASS EngineProtocol

   IF Left( cStr, 1 ) == '"' .AND. Right( cStr, 1 ) == '"'
      RETURN SubStr( cStr, 2, Len( cStr ) - 2 )
   ENDIF

   RETURN cStr
