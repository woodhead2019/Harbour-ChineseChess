/*
 * 中国象棋记谱法窗口模块
 * Written by freexbase in 2026
 *
 * 功能:
 * - 使用 BROWSE 控件显示记谱法
 * - 支持自动滚动到最新内容
 * - 提供右键菜单（复制功能）
 * - 限制最大行数，避免内存占用过大
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 */

#include "hbclass.ch"
#include "hwgui.ch"
#include "xq_xiangqi.ch"

// ============================================================================
// 全局变量
// ============================================================================

STATIC oXQ_NotationWindow := NIL  // 记谱法窗口控件（BROWSE）
STATIC oXQ_NotationMenu := NIL    // 记谱法窗口右键菜单
STATIC aNotationLog := {}           // 记谱法记录数组
STATIC cNotationTitle := ""         // 记谱法窗口标题
STATIC cCurrentRedMove := ""        // 当前回合红方走法（缓存）
STATIC nCurrentRound := 1           // 当前回合数

// ============================================================================
// 常量定义
// ============================================================================

#define NOTATION_MAX_LINES  10000     // 最大行数限制

// ============================================================================
// 创建记谱法窗口
// -------------------------------------------------------------------------------

/**
 * 创建记谱法窗口
 *
 * 参数:
 *   oWnd       - 父窗口对象
 *   nRow       - 行位置
 *   nCol       - 列位置
 *   nWidth     - 宽度
 *   nHeight    - 高度
 *   oFont      - 字体对象
 *   cTitle     - 窗口标题（可选）
 * 返回: NIL
 */
FUNCTION xq_Notation_Create( oWnd, nRow, nCol, nWidth, nHeight, oFont, cTitle )

   LOCAL oColumn

   // 保存标题
   IF PCOUNT() >= 6 .AND. !Empty( cTitle )
      cNotationTitle := cTitle
   ELSE
      cNotationTitle := _XQ_I__( "engine.chinese_notation" )
   ENDIF

   // 创建 Browse 控件
   @ nRow, nCol BROWSE oXQ_NotationWindow ;
      ARRAY ;
      STYLE WS_VSCROLL + WS_HSCROLL + WS_BORDER ;
      SIZE nWidth, nHeight FONT oFont

   // 设置数据源
   oXQ_NotationWindow:aArray := aNotationLog

   // 初始化记录数
   oXQ_NotationWindow:nRecords := 0

   // 添加列（使用更大的列宽）
   oColumn := HColumn():New( cNotationTitle, {|v,o|(v),o:aArray[o:nCurrent,1]}, "C", nWidth - 20, 0 )
   oXQ_NotationWindow:AddColumn( oColumn )

   // 创建右键菜单（使用模块级STATIC变量）
   CONTEXT MENU oXQ_NotationMenu
      MENUITEM _XQ_I__( "notation.copy_current" ) ACTION xq_Notation_CopyCurrent()
      MENUITEM _XQ_I__( "notation.copy_all" ) ACTION xq_Notation_CopyAll()
   ENDMENU

   // 设置右键点击事件
   oXQ_NotationWindow:bRClick := {|o,nCol,nRow|oXQ_NotationMenu:Show(o)}

RETURN NIL

// ============================================================================
// 记谱法窗口操作
// -------------------------------------------------------------------------------

/**
 * 添加记谱法记录
 *
 * 参数:
 *   cNotation - 记谱法字符串
 * 返回: NIL
 */
FUNCTION xq_Notation_Add( cNotation, lIsRed )
   LOCAL nCount
   LOCAL nLastIndex

   IF Empty( oXQ_NotationWindow )
      RETURN NIL
   ENDIF

   // 确保 aArray 正确指向 aNotationLog
   IF oXQ_NotationWindow:aArray == NIL
      oXQ_NotationWindow:aArray := aNotationLog
   ENDIF

   IF lIsRed
      // 红方走法：直接显示，格式为 "1. 红方走法"
      AADD( aNotationLog, {Str( nCurrentRound ) + ". " + cNotation} )
      cCurrentRedMove := cNotation
   ELSE
      // 黑方走法：替换上一行，格式为 "1. 红方走法  黑方走法"
      nLastIndex := Len( aNotationLog )
      IF nLastIndex > 0
         aNotationLog[nLastIndex] := {Str( nCurrentRound ) + ". " + cCurrentRedMove + "  " + cNotation}
      ENDIF
      cCurrentRedMove := ""
      nCurrentRound++
   ENDIF

   // 限制最大行数
   nCount := Len( aNotationLog )
   IF nCount > NOTATION_MAX_LINES
      // 删除最早的 100 行
      ADel( aNotationLog, 1, .T. )
      // 调整数组大小
      ASize( aNotationLog, nCount - 100 )
   ENDIF

   // 更新记录数
   oXQ_NotationWindow:nRecords := Len( aNotationLog )

   // 再次确保 aArray 指向正确
   oXQ_NotationWindow:aArray := aNotationLog

   // 跳转到最后一行（自动滚动）
   oXQ_NotationWindow:Bottom()

   // 刷新显示
   oXQ_NotationWindow:Refresh()

RETURN NIL

/**
 * 刷新记谱法
 *
 * 参数: 无
 * 返回: NIL
 */
FUNCTION xq_Notation_Refresh()

   IF Empty( oXQ_NotationWindow )
      RETURN NIL
   ENDIF

   // 更新记录数
   oXQ_NotationWindow:nRecords := Len( aNotationLog )

   // 再次确保 aArray 指向正确
   oXQ_NotationWindow:aArray := aNotationLog

   // 跳转到最后一行（自动滚动）
   oXQ_NotationWindow:Bottom()

   // 刷新显示
   oXQ_NotationWindow:Refresh()

RETURN NIL

/**
 * 刷新缓存的红方走法（用于游戏结束时）
 *
 * 参数: 无
 * 返回: NIL
 */
FUNCTION xq_Notation_FlushRedMove()

   IF !Empty( cCurrentRedMove )
      AADD( aNotationLog, {Str( nCurrentRound ) + ". " + cCurrentRedMove} )
      cCurrentRedMove := ""
      nCurrentRound++
      
      IF !Empty( oXQ_NotationWindow )
         oXQ_NotationWindow:nRecords := Len( aNotationLog )
         oXQ_NotationWindow:aArray := aNotationLog
         oXQ_NotationWindow:Bottom()
         oXQ_NotationWindow:Refresh()
      ENDIF
   ENDIF

RETURN NIL

/**
 * 清空记谱法窗口
 *
 * 参数: 无
 * 返回: NIL
 */
FUNCTION xq_Notation_Clear()

   aNotationLog := {}
   cCurrentRedMove := ""
   nCurrentRound := 1

   IF !Empty( oXQ_NotationWindow )
      oXQ_NotationWindow:nRecords := 0
      oXQ_NotationWindow:Refresh()
   ENDIF

RETURN NIL

/**
 * 获取记谱法记录数组
 *
 * 参数: 无
 * 返回: 记谱法记录数组
 */
FUNCTION xq_Notation_GetLog()

RETURN aNotationLog

/**
 * 设置记谱法记录数组
 *
 * 参数:
 *   aLog - 记谱法记录数组
 * 返回: NIL
 */
FUNCTION xq_Notation_SetLog( aLog )

   IF ValType( aLog ) == "A"
      aNotationLog := AClone( aLog )
      
      IF !Empty( oXQ_NotationWindow )
         oXQ_NotationWindow:aArray := aNotationLog
         oXQ_NotationWindow:nRecords := Len( aNotationLog )
         oXQ_NotationWindow:Bottom()
         oXQ_NotationWindow:Refresh()
      ENDIF
   ENDIF

RETURN NIL

/**
 * 检查记谱法窗口是否已创建
 *
 * 参数: 无
 * 返回: .T. 已创建，.F. 未创建
 */
FUNCTION xq_Notation_IsCreated()

RETURN ( oXQ_NotationWindow != NIL )

/**
 * 获取记谱法记录数量
 *
 * 参数: 无
 * 返回: 记录数量
 */
FUNCTION xq_Notation_GetCount()

RETURN Len( aNotationLog )

// ============================================================================
// 辅助函数
// -------------------------------------------------------------------------------

/**
 * 复制当前行到剪贴板
 *
 * 参数: 无
 * 返回: NIL
 */
STATIC FUNCTION xq_Notation_CopyCurrent()
   LOCAL nCurrent, cText

   IF Empty( oXQ_NotationWindow )
      RETURN NIL
   ENDIF

   nCurrent := oXQ_NotationWindow:nCurrent

   IF nCurrent > 0 .AND. nCurrent <= Len( aNotationLog )
      IF ValType( aNotationLog[nCurrent] ) == "A" .AND. Len( aNotationLog[nCurrent] ) >= 1
         cText := aNotationLog[nCurrent,1]
         hwg_CopyStringToClipboard( cText )
         hwg_MsgInfo( _XQ_I__( "message.copied" ) + ": " + Left( cText, 50 ) + Iif( Len( cText ) > 50, "...", "" ) )
      ENDIF
   ELSE
      hwg_MsgInfo( _XQ_I__( "notation.no_notation_selected" ) )
   ENDIF

RETURN NIL

/**
 * 复制全部到剪贴板
 *
 * 参数: 无
 * 返回: NIL
 */
STATIC FUNCTION xq_Notation_CopyAll()
   LOCAL i, cText

   IF Empty( oXQ_NotationWindow )
      RETURN NIL
   ENDIF

   IF Empty( aNotationLog )
      hwg_MsgInfo( _XQ_I__( "notation.no_notations_to_copy" ) )
      RETURN NIL
   ENDIF

   cText := ""
   FOR i := 1 TO Len( aNotationLog )
      IF ValType( aNotationLog[i] ) == "A" .AND. Len( aNotationLog[i] ) >= 1
         cText += aNotationLog[i,1] + hb_eol()
      ENDIF
   NEXT

   IF !Empty( cText )
      hwg_CopyStringToClipboard( cText )
      hwg_MsgInfo( _XQ_I__( "notation.copied" ) + " (" + Str( Len( aNotationLog ) ) + " " + _XQ_I__( "message.messages" ) + ")" )
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------

// ============================================================================
// 记谱法转换函数
// -------------------------------------------------------------------------------

/*
 * 将路数数字转换为中文或阿拉伯数字
 *
 * 参数:
 *   par_nRoad - 路数 (1-9)，已经是各自视角的路数
 *   par_lIsRed - 是否红方
 * 返回: l_cRoad - 转换后的数字字符串
 *
 * 路数定义（从右到左）：
 *   红方：一路（最右）→ 九路（最左）
 *   黑方：9路（最右）→ 1路（最左）
 *
 * 红方：1→一，2→二，3→三，4→四，5→五，6→六，7→七，8→八，9→九
 * 黑方：1→1，2→2，3→3，4→4，5→5，6→6，7→7，8→8，9→9
 */
function xq_RoadToChinese( par_nRoad, par_lIsRed )
local l_cRoad := ""

   IF par_nRoad < 1 .OR. par_nRoad > 9
      RETURN LTrim(Str(par_nRoad, 10, 0))
   ENDIF

   IF par_lIsRed
      // 红方使用中文数字（从一到九）
      DO CASE
      CASE par_nRoad == 1 ; l_cRoad := "一"
      CASE par_nRoad == 2 ; l_cRoad := "二"
      CASE par_nRoad == 3 ; l_cRoad := "三"
      CASE par_nRoad == 4 ; l_cRoad := "四"
      CASE par_nRoad == 5 ; l_cRoad := "五"
      CASE par_nRoad == 6 ; l_cRoad := "六"
      CASE par_nRoad == 7 ; l_cRoad := "七"
      CASE par_nRoad == 8 ; l_cRoad := "八"
      CASE par_nRoad == 9 ; l_cRoad := "九"
      ENDCASE
   ELSE
      // 黑方使用阿拉伯数字
      l_cRoad := LTrim(Str(par_nRoad, 10, 0))
   ENDIF

RETURN l_cRoad

/*
 * 将引擎移动编码转换为中文记谱法
 *
 * 参数:
 *   par_nMove - 引擎移动编码（1-based索引）
 *   par_aBoard - 棋盘数组（10x9）
 * 返回: 中文记谱法字符串（如 "炮二平五"）
 *
 * 中文记谱法规则：
 * - 红方使用中文数字（一至九）
 * - 黑方使用阿拉伯数字（1至9）
 * - 行动符号：进（前进）、退（后退）、平（横移）
 * - 车/炮/帅：可用进/退/平
 * - 马/象/士：只用进/退，禁用"平"
 * - 兵/卒：未过河用进，过河后可用平，禁用退
 *
 * 示例：
 * - 炮二平五 → 红方炮从2路平移到5路
 * - 馬八進七 → 红方马从8路前进到7路
 * - 車二進九 → 红方车从2路前进9步
 * - 炮3退4 → 黑方炮从3路后退4步
 */
function xq_MoveToChineseNotation( par_nMove, par_aBoard )
local l_nFrom, l_nTo
local l_nFromIdx, l_nToIdx
local l_aFromGUI, l_aToGUI  // GUI坐标数组（临时）
local l_nFromGUI_Row, l_nFromGUI_Col, l_nToGUI_Row, l_nToGUI_Col  // GUI坐标
local l_cPiece, l_cPieceName, l_lIsRed
local l_nFromRoad, l_nToRoad
local l_cAction, l_cTarget
local l_nDeltaRow, l_nDeltaCol
local l_cChinese := ""

   // 初始化变量，防止NIL导致的字符串连接错误
   l_cAction := ""
   l_cTarget := ""

   // 解析移动编码（注意：nMove编码中使用1-based索引，范围1-90）
   // 编码格式：nMove = nFrom + nTo * 256
   // 其中 nFrom 和 nTo 都是1-based的数组索引
   l_nFrom := par_nMove % 256
   l_nTo := Int( par_nMove / 256 )

   // 转换为1-based行列坐标（GUI坐标）
   l_aFromGUI := xq_IdxToGUI( l_nFrom )
   l_aToGUI := xq_IdxToGUI( l_nTo )

   l_nFromGUI_Row := l_aFromGUI[1]  // 1-10（GUI坐标，自上而下）
   l_nFromGUI_Col := l_aFromGUI[2]  // 1-9
   l_nToGUI_Row := l_aToGUI[1]
   l_nToGUI_Col := l_aToGUI[2]

   // 获取棋子（nFrom已经是1-based索引，直接使用）
   l_cPiece := par_aBoard[l_nFrom]
   l_lIsRed := (Upper(l_cPiece) == l_cPiece)  // 大写=红方，小写=黑方

   // 计算路数（从右到左，1-9）
   // 红方视角（从右到左）：一路（最右）→ 九路（最左），路数 = 10 - GUI列号
   // 黑方视角（从右到左）：9路（最右）→ 1路（最左），路数 = GUI列号
   // 对称关系：红方路数 + 黑方路数 = 10
   // 例如：GUI列8 → 红方2路，黑方8路
   IF l_lIsRed
      l_nFromRoad := 10 - l_nFromGUI_Col
         l_nToRoad := 10 - l_nToGUI_Col
   ELSE
      l_nFromRoad := l_nFromGUI_Col
      l_nToRoad := l_nToGUI_Col
   ENDIF

   // 获取棋子中文名称
   DO CASE
   CASE l_cPiece == "K" ; l_cPieceName := "帥"
   CASE l_cPiece == "A" ; l_cPieceName := "仕"
   CASE l_cPiece == "B" ; l_cPieceName := "相"
   CASE l_cPiece == "N" ; l_cPieceName := "傌"
   CASE l_cPiece == "R" ; l_cPieceName := "俥"
   CASE l_cPiece == "C" ; l_cPieceName := "炮"
   CASE l_cPiece == "P" ; l_cPieceName := "兵"
   CASE l_cPiece == "k" ; l_cPieceName := "將"
   CASE l_cPiece == "a" ; l_cPieceName := "士"
   CASE l_cPiece == "b" ; l_cPieceName := "象"
   CASE l_cPiece == "n" ; l_cPieceName := "馬"
   CASE l_cPiece == "r" ; l_cPieceName := "車"
   CASE l_cPiece == "c" ; l_cPieceName := "炮"
   CASE l_cPiece == "p" ; l_cPieceName := "卒"
   OTHERWISE            ; l_cPieceName := "?"
   ENDCASE

   // 计算移动方向
   l_nDeltaRow := l_nToGUI_Row - l_nFromGUI_Row
   l_nDeltaCol := l_nToGUI_Col - l_nFromGUI_Col

   // 判断移动类型（根据棋子类型和移动方向）
   IF Upper(l_cPiece) == "R" .OR. Upper(l_cPiece) == "C" .OR. Upper(l_cPiece) == "K"
      // 车/炮/帅：直走或横走，可用进/退/平
      IF l_nDeltaRow == 0
         // 横向移动：平
         l_cAction := "平"
         l_cTarget := xq_RoadToChinese( l_nToRoad, l_lIsRed )
      ELSE
         // 纵向移动
         // GUI坐标从上到下：红方前进时行号减小（nDeltaRow < 0），黑方前进时行号增加（nDeltaRow > 0）
         IF (l_lIsRed .AND. l_nDeltaRow < 0) .OR. (!l_lIsRed .AND. l_nDeltaRow > 0)
            // 前进：进
            l_cAction := "进"
         ELSE
            // 后退：退
            l_cAction := "退"
         ENDIF
         // 第四字用步数
         l_cTarget := xq_RoadToChinese( Abs(l_nDeltaRow), l_lIsRed )
      ENDIF

   ELSEIF Upper(l_cPiece) == "N" .OR. Upper(l_cPiece) == "B" .OR. Upper(l_cPiece) == "A"
      // 马/象/士：斜走，只用进/退，禁用"平"
      IF (l_lIsRed .AND. l_nDeltaRow < 0) .OR. (!l_lIsRed .AND. l_nDeltaRow > 0)
         // 前进：进
         l_cAction := "进"
      ELSE
         // 后退：退
         l_cAction := "退"
      ENDIF
      // 第四字用目标线
      l_cTarget := xq_RoadToChinese( l_nToRoad, l_lIsRed )

   ELSEIF Upper(l_cPiece) == "P"
      // 兵/卒
      IF l_nDeltaRow == 0
         // 横向移动：平（仅过河后允许）
         l_cAction := "平"
         l_cTarget := xq_RoadToChinese( l_nToRoad, l_lIsRed )
      ELSE
         // 纵向移动
         IF (l_lIsRed .AND. l_nDeltaRow > 0) .OR. (!l_lIsRed .AND. l_nDeltaRow < 0)
            // 前进：进
            l_cAction := "进"
         ELSE
            // 兵/卒不能后退
            l_cAction := "进"
         ENDIF
         // 第四字用步数
         l_cTarget := xq_RoadToChinese( Abs(l_nDeltaRow), l_lIsRed )
      ENDIF
   ENDIF

   // 安全检查：确保所有变量都已设置
   IF Empty(l_cAction) .OR. Empty(l_cTarget)
      RETURN "?"
   ENDIF

   // 构建中国记谱法（红方用中文数字，黑方用阿拉伯数字）
   l_cChinese := l_cPieceName + xq_RoadToChinese( l_nFromRoad, l_lIsRed ) + l_cAction + l_cTarget

RETURN l_cChinese

/*
 * 将引擎移动编码转换为WXF英译标准记谱法
 *
 * 参数:
 *   par_nMove - 引擎移动编码（1-based索引）
 *   par_aBoard - 棋盘数组（10x9）
 * 返回: 英译标准记谱法字符串（如 "C2=5"、"H8+7"）
 *
 * WXF英译标准规则：
 * - 棋子代码：K（帅/将）、R（俥/車）、H（傌/馬）、C（炮/砲）、E（相/象）、A（仕/士）、P（兵/卒）
 * - 行动符号：+（进）、-（退）、=（平）
 * - 纵线编号：1-9（阿拉伯数字，各自视角从右到左）
 * - 记谱格式：[棋子][起始纵线][行动符号][目标/步数]
 *
 * 示例：
 * - 炮二平五 → C2=5
 * - 馬八進七 → H8+7
 * - 車二進九 → R2+9
 * - 炮3退4 → C3-4
 */
function xq_MoveToEnglishNotation( par_nMove, par_aBoard )
local l_nFrom, l_nTo
local l_nFromIdx, l_nToIdx
local l_aFromGUI, l_aToGUI
local l_nFromGUI_Row, l_nFromGUI_Col, l_nToGUI_Row, l_nToGUI_Col
local l_cPiece, l_cPieceCode
local l_lIsRed
local l_nFromRoad, l_nToRoad
local l_cAction, l_cTarget
local l_nDeltaRow, l_nDeltaCol
local l_cEnglish := ""

   // 初始化变量
   l_cAction := ""
   l_cTarget := ""

   // 解析移动编码
   l_nFrom := par_nMove % 256
   l_nTo := Int( par_nMove / 256 )

   // 转换为1-based行列坐标
   l_aFromGUI := xq_IdxToGUI( l_nFrom )
   l_aToGUI := xq_IdxToGUI( l_nTo )

   l_nFromGUI_Row := l_aFromGUI[1]  // 1-10
   l_nFromGUI_Col := l_aFromGUI[2]  // 1-9
   l_nToGUI_Row := l_aToGUI[1]
   l_nToGUI_Col := l_aToGUI[2]

   // 获取棋子（FEN 代码）
   l_cPiece := par_aBoard[l_nFrom]
   l_lIsRed := (Upper(l_cPiece) == l_cPiece)  // 大写=红方，小写=黑方

   // 重要：代码系统说明
   // ===================
   // FEN 代码（棋盘数组和移动验证使用）：
   //   - N（马）、B（象）、A（士）、K（帅）、R（车）、C（炮）、P（兵）
   //   - 从棋盘数组获取，用于移动类型判断
   //
   // WXF 英译代码（英文记谱法输出使用）：
   //   - H（马）、E（象）、A（士）、K（帅）、R（车）、C（炮）、P（兵）
   //   - 仅用于输出，不用于移动类型判断
   //
   // 关键原则：移动类型判断必须使用 FEN 代码，不能使用 WXF 英译代码！
   // 例如：判断马移动用 Upper(l_cPiece) == "N"，不能用 "H"
   //        判断象移动用 Upper(l_cPiece) == "B"，不能用 "E"

   // 转换为 WXF 棋子代码（仅用于输出）
   DO CASE
   CASE Upper(l_cPiece) == "K" ; l_cPieceCode := "K"  // King
   CASE Upper(l_cPiece) == "A" ; l_cPieceCode := "A"  // Advisor
   CASE Upper(l_cPiece) == "B" ; l_cPieceCode := "E"  // Elephant
   CASE Upper(l_cPiece) == "N" ; l_cPieceCode := "H"  // Horse
   CASE Upper(l_cPiece) == "R" ; l_cPieceCode := "R"  // Rook
   CASE Upper(l_cPiece) == "C" ; l_cPieceCode := "C"  // Cannon
   CASE Upper(l_cPiece) == "P" ; l_cPieceCode := "P"  // Pawn
   OTHERWISE               ; l_cPieceCode := "?"
   ENDCASE

   // 计算路数（各自视角从右到左1-9）
   IF l_lIsRed
      l_nFromRoad := 10 - l_nFromGUI_Col
      l_nToRoad := 10 - l_nToGUI_Col
   ELSE
      l_nFromRoad := l_nFromGUI_Col
      l_nToRoad := l_nToGUI_Col
   ENDIF

   // 计算移动方向
   l_nDeltaRow := l_nToGUI_Row - l_nFromGUI_Row
   l_nDeltaCol := l_nToGUI_Col - l_nFromGUI_Col

   // 判断移动类型
   IF Upper(l_cPiece) == "R" .OR. Upper(l_cPiece) == "C" .OR. Upper(l_cPiece) == "K"
      // 车/炮/帅：直走或横走
      IF l_nDeltaRow == 0
         // 横向移动：平
         l_cAction := "="
         l_cTarget := LTrim(Str(l_nToRoad, 10, 0))
      ELSE
         // 纵向移动
         IF (l_lIsRed .AND. l_nDeltaRow < 0) .OR. (!l_lIsRed .AND. l_nDeltaRow > 0)
            // 前进：+
            l_cAction := "+"
         ELSE
            // 后退：-
            l_cAction := "-"
         ENDIF
         // 第四字用步数
         l_cTarget := LTrim(Str(Abs(l_nDeltaRow), 10, 0))
      ENDIF

   ELSEIF Upper(l_cPiece) == "N" .OR. Upper(l_cPiece) == "B" .OR. Upper(l_cPiece) == "A"
      // 马/象/士：斜走，只用进/退
      IF (l_lIsRed .AND. l_nDeltaRow < 0) .OR. (!l_lIsRed .AND. l_nDeltaRow > 0)
         // 前进：+
         l_cAction := "+"
      ELSE
         // 后退：-
         l_cAction := "-"
      ENDIF
      // 第四字用目标线
      l_cTarget := LTrim(Str(l_nToRoad, 10, 0))

   ELSEIF Upper(l_cPiece) == "P"
      // 兵/卒
      IF l_nDeltaRow == 0
         // 横向移动：平（仅过河后允许）
         l_cAction := "="
         l_cTarget := LTrim(Str(l_nToRoad, 10, 0))
      ELSE
         // 纵向移动
         IF (l_lIsRed .AND. l_nDeltaRow > 0) .OR. (!l_lIsRed .AND. l_nDeltaRow < 0)
            // 前进：+
            l_cAction := "+"
         ELSE
            // 兵/卒不能后退
            l_cAction := "+"
         ENDIF
         // 第四字用步数
         l_cTarget := LTrim(Str(Abs(l_nDeltaRow), 10, 0))
      ENDIF
   ENDIF

   // 安全检查
   IF Empty(l_cAction) .OR. Empty(l_cTarget)
      RETURN "?"
   ENDIF

   // 构建WXF英译标准记谱法
   l_cEnglish := l_cPieceCode + LTrim(Str(l_nFromRoad, 10, 0)) + l_cAction + l_cTarget

RETURN l_cEnglish

// ============================================================================
// 保存/加载函数
// -------------------------------------------------------------------------------

/*
 * ========================================
 * FEN 格式相关函数
 * ========================================
 */

/*
 * 保存棋局为 FEN 格式
 *
 * 参数:
 *   par_cFileName - 文件名
 *   par_aBoardPos - 棋盘位置数组
 *   par_lRedTurn - 红方是否走棋
 * 返回: .T. 成功, .F. 失败
 */
function xq_Save_FEN( par_cFileName, par_aBoardPos, par_lRedTurn )
   LOCAL l_cFen

   l_cFen := xq_BoardToFenUCCI( par_aBoardPos, par_lRedTurn, 0, 1 )

   RETURN hb_MemoWrit( par_cFileName, l_cFen )

/*
 * 从 FEN 文件加载棋局
 *
 * 参数:
 *   par_cFileName - 文件名
 * 返回: 哈希表包含加载结果，{ "success" => .T./.F., "fen" => FEN字符串, "error" => 错误信息 }
 */
function xq_Load_FEN( par_cFileName )
   LOCAL l_cContent, l_hResult

   l_hResult := { => }
   l_hResult[ "success" ] := .F.

   IF !File( par_cFileName )
      l_hResult[ "error" ] := "File not found: " + par_cFileName
      RETURN l_hResult
   ENDIF

   l_cContent := hb_MemoRead( par_cFileName )
   IF Empty( l_cContent )
      l_hResult[ "error" ] := "File is empty"
      RETURN l_hResult
   ENDIF

   l_cContent := AllTrim( l_cContent )
   l_cContent := StrTran( l_cContent, Chr(13), "" )
   l_cContent := StrTran( l_cContent, Chr(10), "" )
   l_cContent := StrTran( l_cContent, Chr(9), "" )

   l_hResult[ "success" ] := .T.
   l_hResult[ "fen" ] := l_cContent

RETURN l_hResult

/*
 * ========================================
 * 通用保存/加载函数
 * ========================================
 */

/*
 * 通用保存函数（根据文件扩展名自动选择格式）
 *
 * 参数:
 *   par_cFileName - 文件名
 *   par_aNotationLog - 走法记录数组
 *   par_aBoardPos - 棋盘位置数组（当前局面）
 *   par_lRedTurn - 红方是否走棋
 *   par_cResult - 结果（1-0红胜，0-1黑胜，1/2-1/2和棋，*未知）
 *   par_nRedPlayer - 红方玩家类型（1=人, 2=AI）
 *   par_nBlackPlayer - 黑方玩家类型（1=人, 2=AI）
 *   par_cInitialFen - 对局初始局面 FEN
 * 返回: .T. 成功, .F. 失败
 */
function xq_SaveGame( par_cFileName, par_aNotationLog, par_aBoardPos, par_lRedTurn, par_cResult, par_nRedPlayer, par_nBlackPlayer, par_cInitialFen )
   LOCAL l_cExt := Upper( Right( par_cFileName, 4 ) )

   DO CASE
   CASE l_cExt == ".PGN"
      RETURN xq_Save_PGN( par_cFileName, par_aNotationLog, par_aBoardPos, par_lRedTurn, par_cResult, par_nRedPlayer, par_nBlackPlayer, par_cInitialFen )
   CASE l_cExt == ".FEN"
      RETURN xq_Save_FEN( par_cFileName, par_aBoardPos, par_lRedTurn )
   OTHERWISE
      RETURN .F.
   ENDCASE

RETURN .F.

/*
 * 通用加载函数（根据文件扩展名自动选择格式）
 *
 * 参数:
 *   par_cFileName - 文件名
 * 返回: 哈希表包含加载结果，{ "success" => .T./.F., "fen" => FEN字符串, "error" => 错误信息 }
 */
function xq_LoadGame( par_cFileName )
   LOCAL l_cExt := Upper( Right( par_cFileName, 4 ) )

   DO CASE
   CASE l_cExt == ".PGN"
      RETURN xq_Load_PGN( par_cFileName )
   CASE l_cExt == ".FEN"
      RETURN xq_Load_FEN( par_cFileName )
   OTHERWISE
      RETURN { "success" => .F., "error" => _XQ_I__( "error.unsupported_format" ) }
   ENDCASE

RETURN { "success" => .F., "error" => _XQ_I__( "error.unsupported_format" ) }

/*
 * ========================================
 * PGN 格式相关函数
 * ========================================
 *
 * 参考规范：https://www.xqbase.com/protocol/cchess_pgn.htm
 * 中国象棋电脑应用规范(四)：PGN文件格式
 *
 * 标签格式：
 *   [Game "Chinese Chess"]  - 必须，标识中国象棋
 *   [Event "..."]           - 比赛名称
 *   [Site "..."]            - 比赛地点
 *   [Date "YYYY.MM.DD"]     - 日期
 *   [Red "..."]             - 红方姓名
 *   [Black "..."]           - 黑方姓名
 *   [Result "..."]          - 结果（1-0红胜，0-1黑胜，1/2-1/2和棋，*未知）
 *   [FEN "..."]             - 可选，初始局面（FEN格式）
 *
 * 着法格式：
 *   使用 ICCS 坐标格式（推荐），如：h2e2, b9c7
 *   格式：起始坐标 + 目标坐标（4个字符）
 *   坐标：文件(a-i, 红方左到右) + 等级(0-9, 红方下到上)
 *
 * 示例：
 *   [Game "Chinese Chess"][Event "测试比赛"][Site "?"][Date "2024.01.15"]
 *   [Red "Player"][Black "AI"][Result "1-0"]
 *   1. h2e2 b9c7 2. h0g2 c9d7 3. h0a0 g7e5 *
 */

/*
 * 保存棋局为 PGN 格式
 *
 * 参数:
 *   par_cFileName - 文件名
 *   par_aNotationLog - 走法记录数组（ICCS坐标格式，如 "h2e2"）
 *   par_aBoardPos - 棋盘位置数组（11x12，当前局面，仅用于检查是否为空）
 *   par_lRedTurn - 红方是否走棋
 *   par_cResult - 结果（1-0红胜，0-1黑胜，1/2-1/2和棋，*未知）
 *   par_nRedPlayer - 红方玩家类型（1=人, 2=AI）
 *   par_nBlackPlayer - 黑方玩家类型（1=人, 2=AI）
 *   par_cInitialFen - 对局初始局面 FEN（保存起始局面，而不是当前局面）
 * 返回: .T. 成功, .F. 失败
 */
function xq_Save_PGN( par_cFileName, par_aNotationLog, par_aBoardPos, par_lRedTurn, par_cResult, par_nRedPlayer, par_nBlackPlayer, par_cInitialFen )
   LOCAL l_cPGN, l_i, l_j, l_k
   LOCAL l_cDate, l_cRedPlayer, l_cBlackPlayer, l_cFen
   LOCAL l_aBoard1D, l_cBoardStr, l_cMove, l_nSpacePos
   LOCAL l_cStandardFen
   LOCAL l_aLineTokens, l_cToken, l_nMoveIndex

   // 标准初始局面 FEN
   l_cStandardFen := "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

   // 格式化日期：YYYY.MM.DD
   l_cDate := Str( Year( Date() ) ) + "." + ;
            StrZero( Month( Date() ), 2 ) + "." + ;
            StrZero( Day( Date() ), 2 )

   // 确定玩家名称
   l_cRedPlayer := Iif( par_nRedPlayer == 1, _XQ_I__( "player.human" ), _XQ_I__( "player.ai" ) )
   l_cBlackPlayer := Iif( par_nBlackPlayer == 1, _XQ_I__( "player.human" ), _XQ_I__( "player.ai" ) )

   // 生成 PGN 标签（严格按照规范格式）
   l_cPGN := '[Event "' + _XQ_I__( "pgn.event" ) + '"]' + hb_eol()
   l_cPGN += '[Site "?"]' + hb_eol()
   l_cPGN += '[Date "' + AllTrim( l_cDate ) + '"]' + hb_eol()
   l_cPGN += '[Red "' + l_cRedPlayer + '"]' + hb_eol()
   l_cPGN += '[Black "' + l_cBlackPlayer + '"]' + hb_eol()
   l_cPGN += '[Result "' + par_cResult + '"]' + hb_eol()

   // 添加初始局面标签（符合 PGN 规范）
   // PGN 规范要求：
   //   1. 标准 FEN（初始局面）不应包含 FEN 和 SetUp 标签
   //   2. 非标准 FEN 必须同时包含 FEN 和 SetUp 标签
   //   3. SetUp 标签值 "1" 表示从自定义局面开始
   // 参考：PGN Specification 9.7.1 (SetUp) 和 9.7.2 (FEN)
   IF par_cInitialFen != NIL .AND. par_cInitialFen != l_cStandardFen
      // 非标准初始局面：添加 SetUp 和 FEN 标签
      l_cPGN += '[SetUp "1"]' + hb_eol()
      l_cPGN += '[FEN "' + par_cInitialFen + '"]' + hb_eol()
   ENDIF

   // 空行分隔标签和着法
   l_cPGN += hb_eol()

   // 生成着法列表（ICCS坐标格式，带连字符）
   // 格式：回合数. 红方着法 黑方着法
   // 示例：1. h2-e2 b9-c7 2. h0-g2 c9-d7
   // 注意：par_aNotationLog 是二维数组，每行包含一个回合的红黑双方着法
   //       如：{"1. h2e2 (炮二平五)  b9c7 (马8进7)"}
   //       需要分割字符串并提取所有4字符的ICCS坐标，并转换为带连字符格式
   l_nMoveIndex := 0  // 着法索引（从0开始）

   FOR l_i := 1 TO Len( par_aNotationLog )
      // 提取记谱法字符串
      l_cMove := par_aNotationLog[l_i]

      // 处理二维数组格式（BROWSE控件使用）
      IF ValType( l_cMove ) == "A" .AND. Len( l_cMove ) >= 1
         l_cMove := l_cMove[1]
      ENDIF

      // 按空格分割字符串
      l_aLineTokens := hb_ATokens( l_cMove, " " )

      // 提取所有4字符的ICCS坐标，并转换为带连字符格式（如 "h2e2" -> "h2-e2"）
      FOR l_j := 1 TO Len( l_aLineTokens )
         l_cToken := AllTrim( l_aLineTokens[l_j] )

         // 跳过回合号（如 "1."）
         IF Right( l_cToken, 1 ) == "." .OR. IsDigit( l_cToken )
            LOOP
         ENDIF

         // 检查是否是4字符的ICCS坐标（如 "h2e2"）
         IF Len( l_cToken ) == 4 .AND. IsAlpha( Left( l_cToken, 1 ) )
            l_nMoveIndex++

            // 转换为带连字符格式：h2e2 -> h2-e2
            l_cToken := Left( l_cToken, 2 ) + "-" + Right( l_cToken, 2 )

            IF Mod( l_nMoveIndex, 2 ) == 1
               // 红方着法：添加回合号和着法（使用hb_ntos避免前导空格）
               l_cPGN += hb_ntos( Int( (l_nMoveIndex + 1) / 2 ) ) + ". " + l_cToken + " "
            ELSE
               // 黑方着法：只添加着法，然后换行
               l_cPGN += l_cToken + hb_eol()
            ENDIF
         ENDIF
      NEXT
   NEXT

   // 添加结果标记（必须）
   l_cPGN += hb_eol() + par_cResult + hb_eol()

   // 保存到文件
   RETURN hb_MemoWrit( par_cFileName, l_cPGN )

/*
 * 从 PGN 文件加载棋局
 *
 * 参数:
 *   par_cFileName - 文件名
 * 返回: 哈希表包含加载结果：
 *   - "success" => .T./.F.
 *   - "fen" => FEN字符串（初始局面，如果没有则使用标准初始局面）
 *   - "moves" => 着法列表（ICCS坐标格式，如 "h2e2"）
 *   - "error" => 错误信息
 *
 * 改进：解析着法列表，支持从初始局面重新走棋
 * PGN 规范说明：
 *   - 标准 FEN（初始局面）不包含 FEN 和 SetUp 标签
 *   - 非标准 FEN 必须同时包含 SetUp 和 FEN 标签
 *   - SetUp "1" 表示从自定义局面开始
 */
function xq_Load_PGN( par_cFileName )
   LOCAL l_cContent, l_aLines, l_i, l_cLine, l_cFen, l_hResult
   LOCAL l_lFoundFen := .F.
   LOCAL l_lFoundSetUp := .F.
   LOCAL l_lFoundMoves := .F.
   LOCAL l_aMoves := {}
   LOCAL l_lInMoves := .F.
   LOCAL l_cMove, l_cStandardFen, l_aTokens, l_j
   LOCAL l_aBoard, l_lRedTurn, l_aBoardAndTurn, l_cParsedICCS, l_cFormat

   l_hResult := { => }
   l_hResult[ "success" ] := .F.
   l_hResult[ "moves" ] := {}

   // 标准初始局面 FEN
   l_cStandardFen := "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

   // 检查文件是否存在
   IF !File( par_cFileName )
      l_hResult[ "error" ] := _XQ_I__( "error.file_not_found" ) + ": " + par_cFileName
      RETURN l_hResult
   ENDIF

   // 读取文件内容
   l_cContent := hb_MemoRead( par_cFileName )
   IF Empty( l_cContent )
      l_hResult[ "error" ] := _XQ_I__( "error.file_empty" )
      RETURN l_hResult
   ENDIF

   // 按行分割
   l_aLines := hb_ATokens( l_cContent, hb_eol() )

   // 解析文件内容
   FOR l_i := 1 TO Len( l_aLines )
      l_cLine := AllTrim( l_aLines[l_i] )

      // 空行表示标签结束，着法开始
      IF Empty( l_cLine )
         IF !l_lInMoves
            l_lInMoves := .T.
         ENDIF
         LOOP
      ENDIF

      // 检查是否是标签行
      IF Left( l_cLine, 1 ) == '['
         l_lInMoves := .F.

         // 检查是否是 SetUp 标签（PGN 规范 9.7.1）
         // SetUp 标签表示对局是否从自定义局面开始
         IF Left( l_cLine, 7 ) == '[SetUp '
            l_lFoundSetUp := .T.
            LOOP
         ENDIF

         // 检查是否是 FEN 标签（PGN 规范 9.7.2）
         // FEN 标签包含初始局面的 FEN 字符串
         // 根据 PGN 规范，FEN 标签必须与 SetUp 标签同时出现
         IF Left( l_cLine, 5 ) == '[FEN '
            // 提取 FEN 值（去掉 [FEN " 和 "]
            l_cFen := SubStr( l_cLine, 6, Len( l_cLine ) - 6 )
            // 去掉可能的引号
            l_cFen := StrTran( l_cFen, '"', '' )
            l_lFoundFen := .T.
         ENDIF
         LOOP
      ENDIF

      // 解析着法行
      IF l_lInMoves
         // 检查是否是结果标记（1-0, 0-1, 1/2-1/2, *）
         IF l_cLine $ "1-0" .OR. l_cLine $ "0-1" .OR. l_cLine $ "1/2-1/2" .OR. l_cLine == "*"
            LOOP
         ENDIF

         // 如果是第一行着法，加载棋盘状态
         IF Len( l_aMoves ) == 0
            // 使用FEN加载棋盘状态
            IF !l_lFoundFen
               l_cFen := l_cStandardFen
            ENDIF
            l_aBoardAndTurn := xq_FenToArrayBoard( l_cFen )
            l_aBoard := l_aBoardAndTurn[1]
            l_lRedTurn := l_aBoardAndTurn[2]
         ENDIF

         // 解析着法，支持多种格式：
         // - ICCS坐标：h2-e2 或 h2e2
         // - 中文记谱法：炮二平五
         // - WXF记谱法：C2=5
         // 先去掉回合号和点号
         l_cLine := StrTran( l_cLine, ".", "" )

         // 按空格分割
         l_aTokens := hb_ATokens( l_cLine, " " )

         FOR l_j := 1 TO Len( l_aTokens )
            l_cMove := AllTrim( l_aTokens[l_j] )

            // 跳过回合号（纯数字）
            IF IsDigit( l_cMove )
               LOOP
            ENDIF

            // 跳过空字符串
            IF Empty( l_cMove )
               LOOP
            ENDIF

            // 检测记谱法格式并解析
            l_cFormat := xq_DetectNotationFormat( l_cMove )

            IF l_cFormat == "ICCS"
               // ICCS坐标格式：直接处理（移除连字符）
               l_cParsedICCS := StrTran( l_cMove, "-", "" )
            OutErr( "[xq_Load_PGN] Parsed ICCS: " + l_cParsedICCS, hb_eol() )
               AAdd( l_aMoves, l_cParsedICCS )
            ELSEIF l_cFormat == "CHINESE"
               // 中文记谱法：使用棋盘状态解析
               l_cParsedICCS := xq_ParseNotationToICCS( l_cMove, l_aBoard, l_lRedTurn )
               IF l_cParsedICCS != NIL
                  AAdd( l_aMoves, l_cParsedICCS )
               ENDIF
            ELSEIF l_cFormat == "WXF"
               // WXF英文记谱法：使用棋盘状态解析
               l_cParsedICCS := xq_ParseNotationToICCS( l_cMove, l_aBoard, l_lRedTurn )
               IF l_cParsedICCS != NIL
                  AAdd( l_aMoves, l_cParsedICCS )
               ENDIF
            ENDIF
         NEXT
      ENDIF
   NEXT

   // 如果没有找到 FEN 标签，使用标准初始局面
   IF !l_lFoundFen
      l_cFen := l_cStandardFen
   ENDIF

   // 返回成功结果
   l_hResult[ "success" ] := .T.
   l_hResult[ "fen" ] := l_cFen
   l_hResult[ "moves" ] := l_aMoves

RETURN l_hResult

// ============================================================================
// 记谱法模块初始化和智能添加函数
// -------------------------------------------------------------------------------

/*
 * 初始化记谱法模块
 *
 * 参数:
 *   cFEN - 初始局面 FEN 字符串
 * 返回: NIL
 */
FUNCTION xq_Notation_Init( cFEN )
   // 保存初始 FEN（用于保存文件时）
   // 注意：当前实现不需要存储 FEN，因为保存时从主程序传递
   // 这个函数保留为未来扩展使用
RETURN NIL

/*
 * 智能添加移动到记谱法窗口
 *
 * 这个函数接收移动编码和棋盘状态，内部计算出记谱法表述并添加到窗口
 *
 * 参数:
 *   nMove - 移动编码（引擎格式：nFrom + nTo * 256）
 *   lIsRed - 是否红方走棋
 *   aBoard - 当前棋盘状态（10x9 数组，1-based索引）
 * 返回: NIL
 *
 * 功能说明：
 *   1. 从 nMove 解析出起始和目标位置
 *   2. 调用 xq_MoveToICCS 生成 ICCS 坐标（如 "h2e2"）
 *   3. 获取当前语言设置
 *   4. 根据语言生成对应记谱法：
 *      - 中文界面：调用 xq_MoveToChineseNotation 生成中文记谱法
 *      - 英文界面：调用 xq_MoveToEnglishNotation 生成 WXF 格式英文记谱法
 *   5. 组合格式为 "ICCS坐标 (记谱法)"，如 "h2e2 (炮二平五)" 或 "h2e2 (C2=5)"
 *   6. 调用 xq_Notation_Add 添加到记谱法窗口
 *
 * 示例：
 *   xq_Notation_AddMove( nMove, .T., aBoard )
 *   中文界面：在记谱法窗口显示 "1. h2e2 (炮二平五)"
 *   英文界面：在记谱法窗口显示 "1. h2e2 (C2=5)"
 */
FUNCTION xq_Notation_AddMove( nMove, lIsRed, aBoard )
   LOCAL cICCS, cNotation, cLanguage

   // 检查参数有效性
   IF nMove == 0 .OR. Empty( aBoard )
      RETURN NIL
   ENDIF

   // 生成ICCS坐标格式
   cICCS := xq_MoveToICCS( nMove, 9 )

   // 获取当前语言
   cLanguage := xq_GetLanguage()

   // 根据语言选择记谱法格式
   IF cLanguage == "zh"
      // 中文界面：ICCS坐标 (中文记谱法)
      cNotation := cICCS + " (" + xq_MoveToChineseNotation( nMove, aBoard ) + ")"
   ELSE
      // 英文界面：ICCS坐标 (英文记谱法-WXF格式)
      cNotation := cICCS + " (" + xq_MoveToEnglishNotation( nMove, aBoard ) + ")"
   ENDIF

   // 添加到记谱法窗口
   xq_Notation_Add( cNotation, lIsRed )

RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 检测记谱法格式
 *
 * 参数:
 *   cNotation - 记谱法字符串
 * 返回: 字符串，表示格式类型：
 *   - "ICCS" - ICCS坐标格式（如 "h2e2" 或 "h2-e2"）
 *   - "CHINESE" - 中文记谱法（如 "炮二平五"）
 *   - "WXF" - WXF英文记谱法（如 "C2=5"）
 *   - "UNKNOWN" - 未知格式
 */
FUNCTION xq_DetectNotationFormat( cNotation )
   LOCAL l_cFirstChar, l_cSecondChar

   // 去除空格和点号
   cNotation := AllTrim( StrTran( cNotation, ".", "" ) )

   IF Empty( cNotation )
      RETURN "UNKNOWN"
   ENDIF

   l_cFirstChar := Left( cNotation, 1 )
   
   // 优先检查ICCS格式：4位或5位，以字母开头
   // 格式：列字母+行数字+列字母+行数字（如 "h2e2"）
   // 或带连字符：列字母+行数字+连字符+列字母+行数字（如 "h2-e2"）
   IF Len( cNotation ) == 4 .OR. Len( cNotation ) == 5
      IF l_cFirstChar >= "a" .AND. l_cFirstChar <= "i"
         // 检查第二位是否为数字
         l_cSecondChar := SubStr( cNotation, 2, 1 )
         IF l_cSecondChar >= "0" .AND. l_cSecondChar <= "9"
            RETURN "ICCS"
         ENDIF
      ENDIF
   ENDIF

   // 检查中文记谱法：以中文字符开头
   IF cNotation $ "帥將車馬炮相象士仕兵卒"
      RETURN "CHINESE"
   ENDIF

   // 检查WXF英文记谱法：以棋子代码开头
   IF l_cFirstChar $ "KAEHRCP"
      RETURN "WXF"
   ENDIF

RETURN "UNKNOWN"

//--------------------------------------------------------------------------------
//--------------------------------------------------------------------------------

/*
 * 将记谱法转换为ICCS坐标
 *
 * 参数:
 *   cNotation - 记谱法字符串（任意格式）
 *   aBoard - 当前棋盘状态（用于解析中文/WXF记谱法）
 *   lRedTurn - 是否红方走棋
 * 返回: ICCS坐标字符串（如 "h2e2"），失败返回 NIL
 */
FUNCTION xq_ParseNotationToICCS( cNotation, aBoard, lRedTurn )
   LOCAL l_cFormat, l_cICCS

   // 检测格式
   l_cFormat := xq_DetectNotationFormat( cNotation )

   DO CASE
   CASE l_cFormat == "ICCS"
      // ICCS坐标格式：直接处理（移除连字符）
      l_cICCS := StrTran( cNotation, "-", "" )
      RETURN l_cICCS

   CASE l_cFormat == "CHINESE"
      // 中文记谱法：解析并转换
      l_cICCS := xq_ParseChineseNotation( cNotation, aBoard, lRedTurn )
      RETURN l_cICCS

   CASE l_cFormat == "WXF"
      // WXF英文记谱法：解析并转换
      l_cICCS := xq_ParseWXFNotation( cNotation, aBoard, lRedTurn )
      RETURN l_cICCS

   ENDCASE

RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 解析中文记谱法并转换为ICCS坐标
 *
 * 参数:
 *   cNotation - 中文记谱法字符串（如 "炮二平五"）
 *   aBoard - 当前棋盘状态
 *   lRedTurn - 是否红方走棋
 * 返回: ICCS坐标字符串（如 "h2e2"），失败返回 NIL
 */
FUNCTION xq_ParseChineseNotation( cNotation, aBoard, lRedTurn )
   LOCAL l_cPieceName, l_cAction, l_cTarget, l_cPiece
   LOCAL l_nFromRoad, l_nToRoad
   LOCAL l_lIsRed, l_nFromIdx, l_nToIdx
   LOCAL l_aFromGUI, l_nFromRow, l_nFromCol, l_nToRow, l_nToCol
   LOCAL l_aCandidates, l_i

   // 移除空格
   cNotation := AllTrim( cNotation )

   // 提取棋子名称
   l_cPieceName := ""
   IF SubStr( cNotation, 1, 2 ) $ "帥將車馬炮相象士仕兵卒"
      l_cPieceName := SubStr( cNotation, 1, 2 )
      cNotation := SubStr( cNotation, 3 )
   ELSEIF SubStr( cNotation, 1, 1 ) $ "帥將車馬炮相象士仕兵卒"
      l_cPieceName := SubStr( cNotation, 1, 1 )
      cNotation := SubStr( cNotation, 2 )
   ELSE
      RETURN NIL
   ENDIF

   // 转换为FEN棋子代码
   l_lIsRed := ( l_cPieceName $ "帥仕相傌俥炮兵" )
   DO CASE
   CASE l_cPieceName == "帥" ; l_cPiece := "K"
   CASE l_cPieceName == "將" ; l_cPiece := "k"
   CASE l_cPieceName == "仕" ; l_cPiece := "A"
   CASE l_cPieceName == "士" ; l_cPiece := "a"
   CASE l_cPieceName == "相" ; l_cPiece := "B"
   CASE l_cPieceName == "象" ; l_cPiece := "b"
   CASE l_cPieceName == "傌" ; l_cPiece := "N"
   CASE l_cPieceName == "馬" ; l_cPiece := "n"
   CASE l_cPieceName == "俥" ; l_cPiece := "R"
   CASE l_cPieceName == "車" ; l_cPiece := "r"
   CASE l_cPieceName == "炮" ; l_cPiece := iif( l_lIsRed, "C", "c" )
   CASE l_cPieceName == "兵" ; l_cPiece := "P"
   CASE l_cPieceName == "卒" ; l_cPiece := "p"
   ENDCASE

   // 提取动作
   IF SubStr( cNotation, 1, 1 ) == "进"
      l_cAction := "进"
      cNotation := SubStr( cNotation, 2 )
   ELSEIF SubStr( cNotation, 1, 1 ) == "退"
      l_cAction := "退"
      cNotation := SubStr( cNotation, 2 )
   ELSEIF SubStr( cNotation, 1, 1 ) == "平"
      l_cAction := "平"
      cNotation := SubStr( cNotation, 2 )
   ELSE
      RETURN NIL
   ENDIF

   // 提取目标路数
   l_cTarget := cNotation
   l_nToRoad := xq_ChineseToNumber( l_cTarget )
   IF l_nToRoad == NIL .OR. l_nToRoad < 1 .OR. l_nToRoad > 9
      RETURN NIL
   ENDIF

   // 查找棋盘上所有匹配的棋子
   l_aCandidates := {}
   FOR l_i := 1 TO XQ_BOARD_SIZE
      IF aBoard[l_i] == l_cPiece
         AAdd( l_aCandidates, l_i )
      ENDIF
   NEXT

   IF Len( l_aCandidates ) == 0
      RETURN NIL
   ENDIF

   // 简化版：使用第一个候选棋子
   // TODO: 完善逻辑，检查多个候选棋子并匹配动作
   l_nFromIdx := l_aCandidates[1]
   l_aFromGUI := xq_IdxToGUI( l_nFromIdx )
   l_nFromRow := l_aFromGUI[1]
   l_nFromCol := l_aFromGUI[2]

   // 计算起始路数
   IF l_lIsRed
      l_nFromRoad := 10 - l_nFromCol
   ELSE
      l_nFromRoad := l_nFromCol
   ENDIF

   // 根据动作计算目标位置
   IF l_cAction == "平"
      // 横向移动
      IF l_lIsRed
         l_nToCol := 10 - l_nToRoad
      ELSE
         l_nToCol := l_nToRoad
      ENDIF
      l_nToRow := l_nFromRow
   ELSE
      // 进/退：暂不支持
      RETURN NIL
   ENDIF

   // 转换为索引
   l_nToIdx := (l_nToRow - 1) * XQ_BOARD_COLS + l_nToCol

   // 生成ICCS坐标
   RETURN xq_MoveToICCS( l_nFromIdx + l_nToIdx * 256, 9 )

//--------------------------------------------------------------------------------

/*
 * 解析WXF英文记谱法并转换为ICCS坐标
 *
 * 参数:
 *   cNotation - WXF记谱法字符串（如 "C2=5"）
 *   aBoard - 当前棋盘状态
 *   lRedTurn - 是否红方走棋
 * 返回: ICCS坐标字符串（如 "h2e2"），失败返回 NIL
 */
FUNCTION xq_ParseWXFNotation( cNotation, aBoard, lRedTurn )
   LOCAL l_cPieceCode, l_nFromRoad, l_cAction, l_cTarget, l_cPiece
   LOCAL l_lIsRed, l_nFromIdx, l_nToIdx
   LOCAL l_aFromGUI, l_nFromRow, l_nFromCol, l_nToRow, l_nToCol
   LOCAL l_aCandidates, l_i, l_nToRoad

   // 移除空格
   cNotation := AllTrim( cNotation )

   // 提取棋子代码
   l_cPieceCode := SubStr( cNotation, 1, 1 )
   IF !l_cPieceCode $ "KAEHRCP"
      RETURN NIL
   ENDIF
   cNotation := SubStr( cNotation, 2 )

   // 提取起始路数
   l_nFromRoad := 0
   WHILE Len( cNotation ) > 0 .AND. SubStr( cNotation, 1, 1 ) >= "0" .AND. SubStr( cNotation, 1, 1 ) <= "9"
      l_nFromRoad := l_nFromRoad * 10 + Val( SubStr( cNotation, 1, 1 ) )
      cNotation := SubStr( cNotation, 2 )
   ENDDO

   IF l_nFromRoad < 1 .OR. l_nFromRoad > 9
      RETURN NIL
   ENDIF

   // 提取动作
   IF Len( cNotation ) == 0
      RETURN NIL
   ENDIF
   l_cAction := SubStr( cNotation, 1, 1 )
   IF !l_cAction $ "=+-"
      RETURN NIL
   ENDIF
   cNotation := SubStr( cNotation, 2 )

   // 提取目标
   l_cTarget := cNotation

   // 转换为FEN棋子代码
   DO CASE
   CASE l_cPieceCode == "K" ; l_cPiece := iif( lRedTurn, "K", "k" )
   CASE l_cPieceCode == "A" ; l_cPiece := iif( lRedTurn, "A", "a" )
   CASE l_cPieceCode == "E" ; l_cPiece := iif( lRedTurn, "B", "b" )
   CASE l_cPieceCode == "H" ; l_cPiece := iif( lRedTurn, "N", "n" )
   CASE l_cPieceCode == "R" ; l_cPiece := iif( lRedTurn, "R", "r" )
   CASE l_cPieceCode == "C" ; l_cPiece := iif( lRedTurn, "C", "c" )
   CASE l_cPieceCode == "P" ; l_cPiece := iif( lRedTurn, "P", "p" )
   ENDCASE

   // 查找棋盘上所有匹配的棋子
   l_aCandidates := {}
   FOR l_i := 1 TO XQ_BOARD_SIZE
      IF aBoard[l_i] == l_cPiece
         AAdd( l_aCandidates, l_i )
      ENDIF
   NEXT

   IF Len( l_aCandidates ) == 0
      RETURN NIL
   ENDIF

   // 找到匹配起始路数的棋子
   l_nFromIdx := NIL
   FOR l_i := 1 TO Len( l_aCandidates )
      l_nCandidateIdx := l_aCandidates[l_i]
      l_aCandidateFromGUI := xq_IdxToGUI( l_nCandidateIdx )
      l_nCandidateFromRoad := iif( lRedTurn, 10 - l_aCandidateFromGUI[2], l_aCandidateFromGUI[2] )

      IF l_nCandidateFromRoad == l_nFromRoad
         l_nFromIdx := l_nCandidateIdx
         EXIT
      ENDIF
   NEXT

   IF l_nFromIdx == NIL
      RETURN NIL
   ENDIF

   // 根据动作计算目标位置
   l_aFromGUI := xq_IdxToGUI( l_nFromIdx )
   l_nFromRow := l_aFromGUI[1]
   l_nFromCol := l_aFromGUI[2]

   IF l_cAction == "="
      // 横向移动
      l_nToRoad := Val( l_cTarget )
      IF l_nToRoad < 1 .OR. l_nToRoad > 9
         RETURN NIL
      ENDIF
      IF lRedTurn
         l_nToCol := 10 - l_nToRoad
      ELSE
         l_nToCol := l_nToRoad
      ENDIF
      l_nToRow := l_nFromRow
   ELSE
      // 进/退：暂不支持
      RETURN NIL
   ENDIF

   // 转换为索引
   l_nToIdx := (l_nToRow - 1) * XQ_BOARD_COLS + l_nToCol

   // 生成ICCS坐标
   RETURN xq_MoveToICCS( l_nFromIdx + l_nToIdx * 256, 9 )

//--------------------------------------------------------------------------------

/*
 * 将中文数字转换为阿拉伯数字
 *
 * 参数:
 *   cChinese - 中文数字（如 "五"）
 * 返回: 阿拉伯数字（1-9），失败返回 NIL
 */
FUNCTION xq_ChineseToNumber( cChinese )
   LOCAL l_cDigit
   LOCAL l_nResult := 0

   cChinese := AllTrim( cChinese )

   DO WHILE Len( cChinese ) > 0
      l_cDigit := SubStr( cChinese, 1, 1 )

      DO CASE
      CASE l_cDigit == "一" ; l_nResult := l_nResult * 10 + 1
      CASE l_cDigit == "二" ; l_nResult := l_nResult * 10 + 2
      CASE l_cDigit == "三" ; l_nResult := l_nResult * 10 + 3
      CASE l_cDigit == "四" ; l_nResult := l_nResult * 10 + 4
      CASE l_cDigit == "五" ; l_nResult := l_nResult * 10 + 5
      CASE l_cDigit == "六" ; l_nResult := l_nResult * 10 + 6
      CASE l_cDigit == "七" ; l_nResult := l_nResult * 10 + 7
      CASE l_cDigit == "八" ; l_nResult := l_nResult * 10 + 8
      CASE l_cDigit == "九" ; l_nResult := l_nResult * 10 + 9
      OTHERWISE
         RETURN NIL
      ENDCASE

      cChinese := SubStr( cChinese, 2 )
   ENDDO

RETURN l_nResult

//--------------------------------------------------------------------------------
