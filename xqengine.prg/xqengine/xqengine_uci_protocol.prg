/*
 * xqengine_uci_protocol.prg
 * UCI 协议类（通用国际象棋协议，中国象棋引擎也支持）
 *
 * 功能:
 * - UCI 命令解析和生成
 * - UCI 响应解析和生成
 * - 协议验证
 *
 * 设计模式:
 * - 继承 EngineProtocol 抽象基类
 * - 实现 UCI 协议特有细节
 *
 * 使用示例:
 * LOCAL oUCI := UCIProtocol():New()
 * LOCAL cCmd := oUCI:BuildPosition( "startpos", "e2e4 e7e5" )
 * LOCAL oResp := oUCI:ParseResponse( "bestmove e2e4 ponder e7e5" )
 */

#include "hbclass.ch"
#include "xqengine_constants.ch"

// ============================================================================
// UCIProtocol 类 - UCI 协议处理
// ============================================================================

/**
 * UCI 协议实现类
 *
 * 继承自:
 * - EngineProtocol: 引擎协议抽象基类
 *
 * 实现的抽象方法:
 * - GetProtocolName(): 返回 "UCI"
 * - GetInitCommand(): 返回 "uci"
 * - IsInitOK(): 检查是否收到 "uciok"
 * - BuildInit(): 返回 "uci"
 * - BuildPosition(): 构建局面设置命令
 * - BuildGo(): 构建 go 命令（使用 movetime 参数）
 * - ParseResponse(): 解析 UCI 响应
 *
 * 特点:
 * - 使用 "movetime" 参数指定搜索时间
 * - 使用 "uci" 命令初始化
 * - 等待 "uciok" 响应确认初始化
 */
CREATE CLASS UCIProtocol INHERIT EngineProtocol

   // 方法
   METHOD New()
   METHOD ParseCommand( cCommand )
   METHOD ParseResponse( cResponse )

   // 实现抽象方法
   METHOD GetProtocolName()
   METHOD GetInitCommand()
   METHOD IsInitOK( cResponse )
   METHOD BuildInit()
   METHOD BuildPosition( cFEN, cMoves )
   METHOD BuildGo( nDepth, nTime, nNodes )

   // UCI 特有方法
   METHOD BuildUCIOK()

ENDCLASS

// ============================================================================
// 构造函数
// ============================================================================

METHOD New() CLASS UCIProtocol

   // 调用父类构造函数
   ::Super:New()

   RETURN Self

// ============================================================================
// 实现抽象方法
// ============================================================================

/**
 * 获取协议名称
 *
 * 返回值:
 * - "UCI" (字符串): UCI 协议名称
 */
METHOD GetProtocolName() CLASS UCIProtocol
   RETURN "UCI"

/**
 * 获取初始化命令字符串
 *
 * 返回值:
 * - "uci" (字符串): UCI 初始化命令
 */
METHOD GetInitCommand() CLASS UCIProtocol
   RETURN "uci"

/**
 * 检查初始化是否成功
 *
 * 参数:
 * - cResponse (字符串): 引擎响应
 *
 * 返回值:
 * - .T. (逻辑值): 收到 "uciok"，初始化成功
 * - .F. (逻辑值): 未收到 "uciok"，初始化失败
 */
METHOD IsInitOK( cResponse ) CLASS UCIProtocol
   RETURN "uciok" $ Lower( cResponse )

/**
 * 构建 UCI 初始化命令
 *
 * 返回值:
 * - "uci" (字符串): UCI 初始化命令
 */
METHOD BuildInit() CLASS UCIProtocol
   RETURN "uci"

/**
 * 构建 UCI position 命令
 *
 * 参数:
 * - cFEN (字符串): FEN 字符串或 "startpos"
 * - cMoves (字符串): 走法序列（可选）
 *
 * 返回值:
 * - 字符串: position 命令
 *
 * 示例:
 * - BuildPosition( "startpos", "e2e4 e7e5" )
 *   -> "position startpos moves e2e4 e7e5"
 * - BuildPosition( "rnbakabnr/9/1c5c1/...", "" )
 *   -> "position rnbakabnr/9/1c5c1/..."
 */
METHOD BuildPosition( cFEN, cMoves ) CLASS UCIProtocol

   IF cFEN == NIL
      cFEN := "startpos"
   ENDIF

   IF cMoves == NIL
      cMoves := ""
   ENDIF

   IF Lower( cFEN ) == "startpos"
      IF Empty( cMoves )
         RETURN "position startpos"
      ELSE
         RETURN "position startpos moves " + cMoves
      ENDIF
   ELSE
      IF Empty( cMoves )
         RETURN "position fen " + cFEN
      ELSE
         RETURN "position fen " + cFEN + " moves " + cMoves
      ENDIF
   ENDIF

   RETURN ""

/**
 * 构建 UCI go 命令
 *
 * 参数:
 * - nDepth (数值): 搜索深度
 * - nTime (数值): 搜索时间限制（毫秒）
 * - nNodes (数值): 搜索节点数限制
 *
 * 返回值:
 * - 字符串: go 命令
 *
 * 注意:
 * - UCI 协议使用 "movetime" 参数指定搜索时间
 * - UCCI 协议使用 "time" 参数指定搜索时间
 * - 这是两种协议的主要区别之一
 *
 * 示例:
 * - BuildGo( 10, 5000, 0 ) -> "go depth 10 movetime 5000"
 * - BuildGo( 0, 0, 1000000 ) -> "go nodes 1000000"
 */
METHOD BuildGo( nDepth, nTime, nNodes ) CLASS UCIProtocol

   LOCAL cCommand := "go"

   IF nDepth == NIL
      nDepth := 0
   ENDIF

   IF nTime == NIL
      nTime := 0
   ENDIF

   IF nNodes == NIL
      nNodes := 0
   ENDIF

   IF nDepth > 0
      cCommand += " depth " + LTrim( Str( nDepth ) )
   ENDIF

   // UCI 协议使用 movetime 参数
   IF nTime > 0
      cCommand += " movetime " + LTrim( Str( nTime ) )
   ENDIF

   IF nNodes > 0
      cCommand += " nodes " + LTrim( Str( nNodes ) )
   ENDIF

   RETURN cCommand

// ============================================================================
// UCI 特有方法
// ============================================================================

/**
 * 构建 uciok 响应
 *
 * 返回值:
 * - "uciok" (字符串): UCI 初始化确认
 */
METHOD BuildUCIOK() CLASS UCIProtocol
   RETURN "uciok"

// ============================================================================
// 解析 UCI 命令
// ============================================================================

METHOD ParseCommand( cCommand ) CLASS UCIProtocol

   LOCAL oResult := { => }
   LOCAL aParts
   LOCAL cFirst
   LOCAL nPos

   IF Empty( cCommand )
      HB_HSet( oResult, "type", UCI_CMD_NONE )
      HB_HSet( oResult, "name", "" )
      RETURN oResult
   ENDIF

   cCommand := AllTrim( cCommand )
   aParts   := ::SplitLine( cCommand )

   IF Len( aParts ) == 0
      HB_HSet( oResult, "type", UCI_CMD_NONE )
      HB_HSet( oResult, "name", "" )
      RETURN oResult
   ENDIF

   cFirst := Lower( aParts[1] )

   // 使用 IF-ELSEIF 替代 SWITCH，因为 SWITCH 语句在某些情况下会跳过 HB_HSet 调用
   IF cFirst == "uci"
      HB_HSet( oResult, "type", UCI_CMD_UCI )
      HB_HSet( oResult, "name", "uci" )
   ELSEIF cFirst == "isready"
      HB_HSet( oResult, "type", UCI_CMD_ISREADY )
      HB_HSet( oResult, "name", "isready" )
   ELSEIF cFirst == "setoption"
      HB_HSet( oResult, "type", UCI_CMD_SETOPTION )
      HB_HSet( oResult, "name", "setoption" )
      // 解析 name 和 value
      IF Len( aParts ) >= 4 .AND. Lower( aParts[2] ) == "name"
         HB_HSet( oResult, "optionName", aParts[3] )
         IF Len( aParts ) >= 6 .AND. Lower( aParts[4] ) == "value"
            HB_HSet( oResult, "optionValue", aParts[5] )
         ENDIF
      ENDIF
   ELSEIF cFirst == "position"
      HB_HSet( oResult, "type", UCI_CMD_POSITION )
      HB_HSet( oResult, "name", "position" )
      // 解析 FEN 和 moves
      IF Len( aParts ) >= 2
         IF Lower( aParts[2] ) == "startpos"
            HB_HSet( oResult, "fen", "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1" )
         ELSE
            HB_HSet( oResult, "fen", aParts[2] )
         ENDIF
      ENDIF
      IF Len( aParts ) >= 4 .AND. Lower( aParts[3] ) == "moves"
         HB_HSet( oResult, "moves", SubStr( cCommand, At( "moves", cCommand ) + 6 ) )
         HB_HSet( oResult, "moves", AllTrim( HB_HGet( oResult, "moves" ) ) )
      ENDIF
   ELSEIF cFirst == "go"
      HB_HSet( oResult, "type", UCI_CMD_GO )
      HB_HSet( oResult, "name", "go" )
      // 解析参数（带边界检查）
      IF AScan( aParts, {|p| Lower( p ) == "depth"} ) > 0
         nPos := AScan( aParts, {|p| Lower( p ) == "depth"} )
         IF nPos + 1 <= Len( aParts )
            HB_HSet( oResult, "depth", Val( aParts[nPos + 1] ) )
         ENDIF
      ENDIF
      IF AScan( aParts, {|p| Lower( p ) == "time"} ) > 0
         nPos := AScan( aParts, {|p| Lower( p ) == "time"} )
         IF nPos + 1 <= Len( aParts )
            HB_HSet( oResult, "time", Val( aParts[nPos + 1] ) )
         ENDIF
      ENDIF
      IF AScan( aParts, {|p| Lower( p ) == "movetime"} ) > 0
         nPos := AScan( aParts, {|p| Lower( p ) == "movetime"} )
         IF nPos + 1 <= Len( aParts )
            HB_HSet( oResult, "movetime", Val( aParts[nPos + 1] ) )
         ENDIF
      ENDIF
      IF AScan( aParts, {|p| Lower( p ) == "nodes"} ) > 0
         nPos := AScan( aParts, {|p| Lower( p ) == "nodes"} )
         IF nPos + 1 <= Len( aParts )
            HB_HSet( oResult, "nodes", Val( aParts[nPos + 1] ) )
         ENDIF
      ENDIF
   ELSEIF cFirst == "stop"
      HB_HSet( oResult, "type", UCI_CMD_STOP )
      HB_HSet( oResult, "name", "stop" )
   ELSEIF cFirst == "ponderhit"
      HB_HSet( oResult, "type", UCI_CMD_PONDERHIT )
      HB_HSet( oResult, "name", "ponderhit" )
   ELSEIF cFirst == "quit"
      HB_HSet( oResult, "type", UCI_CMD_QUIT )
      HB_HSet( oResult, "name", "quit" )
   ELSE
      HB_HSet( oResult, "type", UCI_CMD_NONE )
      HB_HSet( oResult, "name", cFirst )
   ENDIF

   RETURN oResult

// ============================================================================
// 解析 UCI 响应
// ============================================================================

METHOD ParseResponse( cResponse ) CLASS UCIProtocol

   LOCAL oResult := { => }
   LOCAL aParts
   LOCAL cFirst

   IF Empty( cResponse )
      HB_HSet( oResult, "type", UCI_RESP_NONE )
      HB_HSet( oResult, "name", "" )
      RETURN oResult
   ENDIF

   cResponse := AllTrim( cResponse )
   aParts     := ::SplitLine( cResponse )

   IF Len( aParts ) == 0
      HB_HSet( oResult, "type", UCI_RESP_NONE )
      HB_HSet( oResult, "name", "" )
      RETURN oResult
   ENDIF

   cFirst := Lower( aParts[1] )

   // 使用 IF-ELSEIF 替代 SWITCH，因为 SWITCH 语句在某些情况下会跳过 HB_HSet 调用
   IF cFirst == "id"
      HB_HSet( oResult, "type", UCI_RESP_ID )
      HB_HSet( oResult, "name", "id" )
      IF Len( aParts ) >= 3
         HB_HSet( oResult, "field", Lower( aParts[2] ) )
         HB_HSet( oResult, "value", SubStr( cResponse, At( aParts[2], cResponse ) + Len( aParts[2] ) ) )
         HB_HSet( oResult, "value", AllTrim( HB_HGet( oResult, "value" ) ) )
         // 更新引擎信息
         IF Lower( aParts[2] ) == "name"
            ::cEngineName := HB_HGet( oResult, "value" )
         ELSEIF Lower( aParts[2] ) == "author"
            ::cEngineAuthor := HB_HGet( oResult, "value" )
         ELSEIF Lower( aParts[2] ) == "version"
            ::cEngineVersion := HB_HGet( oResult, "value" )
         ENDIF
      ENDIF
   ELSEIF cFirst == "uciok"
      HB_HSet( oResult, "type", UCI_RESP_UCIOK )
      HB_HSet( oResult, "name", "uciok" )
   ELSEIF cFirst == "readyok"
      HB_HSet( oResult, "type", UCI_RESP_READYOK )
      HB_HSet( oResult, "name", "readyok" )
   ELSEIF cFirst == "bestmove"
      HB_HSet( oResult, "type", UCI_RESP_BESTMOVE )
      HB_HSet( oResult, "name", "bestmove" )
      IF Len( aParts ) >= 2
         HB_HSet( oResult, "move", aParts[2] )
      ENDIF
      IF Len( aParts ) >= 4 .AND. Lower( aParts[3] ) == "ponder"
         HB_HSet( oResult, "ponder", aParts[4] )
      ENDIF
   ELSEIF cFirst == "info"
      HB_HSet( oResult, "type", UCI_RESP_INFO )
      HB_HSet( oResult, "name", "info" )
      // 详细解析 info 信息
      ::ParseInfo( cResponse, oResult )
   ELSEIF cFirst == "option"
      HB_HSet( oResult, "type", UCI_RESP_OPTION )
      HB_HSet( oResult, "name", "option" )
      // 解析 option 信息
   ELSEIF cFirst == "error"
      HB_HSet( oResult, "type", UCI_RESP_ERROR )
      HB_HSet( oResult, "name", "error" )
   ELSE
      HB_HSet( oResult, "type", UCI_RESP_NONE )
      HB_HSet( oResult, "name", cFirst )
   ENDIF

   RETURN oResult