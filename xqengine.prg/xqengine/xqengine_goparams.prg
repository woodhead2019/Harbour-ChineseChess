/*
 * xqengine_goparams.prg
 * Go 命令参数类
 *
 * 功能:
 * - 封装所有 go 命令参数
 * - 支持棋钟控制
 * - 支持无限搜索和杀棋搜索
 *
 * 使用示例:
 * LOCAL oParams := GoParams():New()
 * oParams:SetDepth( 20 )
 * oParams:SetWtime( 300000 )
 * oEngine:AnalyzeWithParams( "startpos", oParams )
 */

#include "hbclass.ch"

// ============================================================================
// GoParams 类 - Go 命令参数
// ============================================================================

CREATE CLASS GoParams

   // 搜索参数
   VAR nDepth       INIT 0      // 搜索深度
   VAR nMovetime    INIT 0      // 移动时间(毫秒)
   VAR nNodes       INIT 0      // 节点数限制

   // 棋钟参数
   VAR nWtime       INIT 0      // 白方剩余时间(毫秒)
   VAR nBtime       INIT 0      // 黑方剩余时间(毫秒)
   VAR nWinc        INIT 0      // 白方时间增量(毫秒)
   VAR nBinc        INIT 0      // 黑方时间增量(毫秒)
   VAR nMovestogo   INIT 0      // 距离时间控制回合数

   // 特殊模式
   VAR lInfinite    INIT .F.    // 无限搜索
   VAR nMate        INIT 0      // 杀棋搜索

   // 方法
   METHOD New()
   METHOD SetDepth( nDepth )
   METHOD SetMovetime( nTime )
   METHOD SetNodes( nNodes )
   METHOD SetWtime( nTime )
   METHOD SetBtime( nTime )
   METHOD SetWinc( nInc )
   METHOD SetBinc( nInc )
   METHOD SetMovestogo( nMoves )
   METHOD SetInfinite( lEnable )
   METHOD SetMate( nMate )
   METHOD HasTimeControl()
   METHOD BuildCommand()
   METHOD Clone()
   METHOD Reset()

ENDCLASS

// ============================================================================
// 构造函数
// ============================================================================

METHOD New() CLASS GoParams
   ::Reset()
   RETURN Self

// ============================================================================
// 设置搜索深度
// ============================================================================

METHOD SetDepth( nDepth ) CLASS GoParams

   IF HB_ISNUMERIC( nDepth ) .AND. nDepth > 0
      ::nDepth := Int( nDepth )
   ENDIF

   RETURN Self

// ============================================================================
// 设置移动时间
// ============================================================================

METHOD SetMovetime( nTime ) CLASS GoParams

   IF HB_ISNUMERIC( nTime ) .AND. nTime > 0
      ::nMovetime := Int( nTime )
   ENDIF

   RETURN Self

// ============================================================================
// 设置节点数限制
// ============================================================================

METHOD SetNodes( nNodes ) CLASS GoParams

   IF HB_ISNUMERIC( nNodes ) .AND. nNodes > 0
      ::nNodes := Int( nNodes )
   ENDIF

   RETURN Self

// ============================================================================
// 设置白方剩余时间
// ============================================================================

METHOD SetWtime( nTime ) CLASS GoParams

   IF HB_ISNUMERIC( nTime ) .AND. nTime > 0
      ::nWtime := Int( nTime )
   ENDIF

   RETURN Self

// ============================================================================
// 设置黑方剩余时间
// ============================================================================

METHOD SetBtime( nTime ) CLASS GoParams

   IF HB_ISNUMERIC( nTime ) .AND. nTime > 0
      ::nBtime := Int( nTime )
   ENDIF

   RETURN Self

// ============================================================================
// 设置白方时间增量
// ============================================================================

METHOD SetWinc( nInc ) CLASS GoParams

   IF HB_ISNUMERIC( nInc ) .AND. nInc >= 0
      ::nWinc := Int( nInc )
   ENDIF

   RETURN Self

// ============================================================================
// 设置黑方时间增量
// ============================================================================

METHOD SetBinc( nInc ) CLASS GoParams

   IF HB_ISNUMERIC( nInc ) .AND. nInc >= 0
      ::nBinc := Int( nInc )
   ENDIF

   RETURN Self

// ============================================================================
// 设置距离时间控制回合数
// ============================================================================

METHOD SetMovestogo( nMoves ) CLASS GoParams

   IF HB_ISNUMERIC( nMoves ) .AND. nMoves > 0
      ::nMovestogo := Int( nMoves )
   ENDIF

   RETURN Self

// ============================================================================
// 设置无限搜索
// ============================================================================

METHOD SetInfinite( lEnable ) CLASS GoParams

   IF HB_ISLOGICAL( lEnable )
      ::lInfinite := lEnable
   ENDIF

   RETURN Self

// ============================================================================
// 设置杀棋搜索
// ============================================================================

METHOD SetMate( nMate ) CLASS GoParams

   IF HB_ISNUMERIC( nMate ) .AND. nMate > 0
      ::nMate := Int( nMate )
   ENDIF

   RETURN Self

// ============================================================================
// 检查是否有时间控制
// ============================================================================

METHOD HasTimeControl() CLASS GoParams
   RETURN ::nWtime > 0 .OR. ::nBtime > 0 .OR. ::nWinc > 0 .OR. ::nBinc > 0

// ============================================================================
// 构建 go 命令
// ============================================================================

METHOD BuildCommand() CLASS GoParams

   LOCAL cCommand := "go"

   // 无限搜索
   IF ::lInfinite
      cCommand += " infinite"
      RETURN cCommand
   ENDIF

   // 杀棋搜索
   IF ::nMate > 0
      cCommand += " mate " + LTrim( Str( ::nMate ) )
      RETURN cCommand
   ENDIF

   // 搜索深度
   IF ::nDepth > 0
      cCommand += " depth " + LTrim( Str( ::nDepth ) )
   ENDIF

   // 移动时间
   IF ::nMovetime > 0
      cCommand += " movetime " + LTrim( Str( ::nMovetime ) )
   ENDIF

   // 节点数限制
   IF ::nNodes > 0
      cCommand += " nodes " + LTrim( Str( ::nNodes ) )
   ENDIF

   // 棋钟参数
   IF ::nWtime > 0
      cCommand += " wtime " + LTrim( Str( ::nWtime ) )
   ENDIF

   IF ::nBtime > 0
      cCommand += " btime " + LTrim( Str( ::nBtime ) )
   ENDIF

   IF ::nWinc > 0
      cCommand += " winc " + LTrim( Str( ::nWinc ) )
   ENDIF

   IF ::nBinc > 0
      cCommand += " binc " + LTrim( Str( ::nBinc ) )
   ENDIF

   IF ::nMovestogo > 0
      cCommand += " movestogo " + LTrim( Str( ::nMovestogo ) )
   ENDIF

   RETURN cCommand

// ============================================================================
// 克隆参数
// ============================================================================

METHOD Clone() CLASS GoParams

   LOCAL oClone := GoParams():New()

   oClone:nDepth       := ::nDepth
   oClone:nMovetime    := ::nMovetime
   oClone:nNodes       := ::nNodes
   oClone:nWtime       := ::nWtime
   oClone:nBtime       := ::nBtime
   oClone:nWinc        := ::nWinc
   oClone:nBinc        := ::nBinc
   oClone:nMovestogo   := ::nMovestogo
   oClone:lInfinite    := ::lInfinite
   oClone:nMate        := ::nMate

   RETURN oClone

// ============================================================================
// 重置参数
// ============================================================================

METHOD Reset() CLASS GoParams

   ::nDepth       := 0
   ::nMovetime    := 0
   ::nNodes       := 0
   ::nWtime       := 0
   ::nBtime       := 0
   ::nWinc        := 0
   ::nBinc        := 0
   ::nMovestogo   := 0
   ::lInfinite    := .F.
   ::nMate        := 0

   RETURN Self