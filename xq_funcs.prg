/*
 * 中国象棋工具函数库
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 对应 Sunfish_prg/funcs.prg
 *
 * 【重要提示】
 * 1. 本文件中的所有 PUBLIC 函数声明已合并到 xq_funcs.txt（参考信息）
 * 2. Harbour 默认认为当前 .prg 文件中不存在的函数都在外部
 * 3. 没有 static 限制的函数或过程都是 public 的
 * 4. xq_funcs.txt 仅作为参考，不参与编译
 */

#include "xq_xiangqi.ch"
#include "hbtrace.ch"

// 全局变量
static aPieceValues := {}     // 棋子价值表
static aPieceDirections := {}  // 棋子移动方向表
static aLegalMoves := {}      // 保存找到的合法移动（用于将死检查）

/*
 * 获取合法移动列表（用于将死检查）
 *
 * 参数: 无
 * 返回: 合法移动数组
 */
function xq_GetLegalMoves()
RETURN aLegalMoves

/*
 * 初始化常量
 * 
 * 参数: 无
 * 返回: { XQ_MATE_LOWER, XQ_MATE_UPPER } - 评估上下界
 */
function xq_Init()

   // 棋子价值
   aPieceValues := Array( 2 )
   aPieceValues[1] := hb_hash( "K", XQ_VALUE_KING, "A", XQ_VALUE_ADV, "B", XQ_VALUE_ELEPH, ;
                               "N", XQ_VALUE_HORSE, "R", XQ_VALUE_ROOK, "C", XQ_VALUE_CANNON, "P", XQ_VALUE_PAWN )
   aPieceValues[2] := hb_hash( "k", XQ_VALUE_KING, "a", XQ_VALUE_ADV, "b", XQ_VALUE_ELEPH, ;
                               "n", XQ_VALUE_HORSE, "r", XQ_VALUE_ROOK, "c", XQ_VALUE_CANNON, "p", XQ_VALUE_PAWN )

   // 移动方向（11x12数组坐标系）
   aPieceDirections := hb_hash( "K", XQ_DIR_K_RED,  "k", XQ_DIR_K_BLK, ;
                                 "A", XQ_DIR_A_RED,  "a", XQ_DIR_A_BLK, ;
                                 "B", XQ_DIR_B_RED,  "b", XQ_DIR_B_BLK, ;
                                 "N", XQ_DIR_N_RED,  "n", XQ_DIR_N_BLK, ;
                                 "R", XQ_DIR_R_RED,  "r", XQ_DIR_R_BLK, ;
                                 "C", XQ_DIR_C_RED,  "c", XQ_DIR_C_BLK, ;
                                 "P", XQ_DIR_P_RED,  "p", XQ_DIR_P_BLK )

RETURN { XQ_MATE_LOWER, XQ_MATE_UPPER }

/*
 * 坐标转换：行列转数组索引（11x12）
 *
 * 参数:
 *   nGUIRow - GUI 行 (1-10，从上到下)
 *   nGUICol - GUI 列 (1-9，从左到右)
 * 返回: nIdx - 数组索引 (1-90)
 *
 * 注意: GUI 坐标转数组索引（90元素数组）
 */
function xq_RCToArrayIdx( nGUIRow, nGUICol )
local l_aUCCI

   // GUI → UCCI → 索引
   l_aUCCI := xq_GUIToUCCI( nGUIRow, nGUICol )

RETURN xq_UCCIToIdx( l_aUCCI[1], l_aUCCI[2] )
//--------------------------------------------------------------------------------

/*
 * ============================================================================
 * 新的坐标转换系统（以 UCCI 为基准）
 * ============================================================================
 *
 * 坐标体系：
 * 1. GUI/TUI 坐标：行1-10（从上到下），列1-9（从左到右）
 * 2. UCCI 坐标：行0-9（从下到上），列0-8（从左到右）
 * 3. 数组索引：1-90（Harbour 1-based，模拟0-89）
 *
 * 转换关系：
 * - GUI 行 = 10 - UCCI 行
 * - GUI 列 = UCCI 列 + 1
 * - 数组索引 = UCCI 行 * 9 + UCCI 列 + 1
 * ============================================================================
 */

/*
 * GUI/TUI 坐标转 UCCI 坐标
 *
 * 参数:
 *   nGUIRow - GUI 行 (1-10，从上到下)
 *   nGUICol - GUI 列 (1-9，从左到右)
 * 返回: { nUCCIRow, nUCCICol } - UCCI 坐标 (行0-9, 列0-8)
 *
 * 标准 UCCI 坐标系统：
 * - 行: 0-9（从下到上），行0=红方底线，行9=黑方底线
 * - 列: a-i（从左到右），对应0-8
 * - 格式: 列字母 + 行数字（如 "a0"、"e9"）
 *
 * 转换关系（标准UCCI）：
 * - UCCI行号 = 10 - GUI行号（因为GUI行10=红方底线=UCCI行0，GUI行1=黑方底线=UCCI行9）
 * - UCCI列号 = GUI列号 - 1
 *
 * 示例：
 *   xq_GUIToUCCI(10, 1) → {0, 0} → 红方左侧车（UCCI "a0"）
 *   xq_GUIToUCCI(10, 5) → {0, 4} → 红方帅（UCCI "e0"）
 *   xq_GUIToUCCI(1, 5) → {9, 4} → 黑方将（UCCI "e9"）
 *   xq_GUIToUCCI(1, 1) → {9, 0} → 黑方左侧车（UCCI "a9"）
 */
function xq_GUIToUCCI( nGUIRow, nGUICol )
local l_nUCCIRow, l_nUCCICol

   // 转换公式（标准UCCI）
   l_nUCCIRow := 10 - nGUIRow  // GUI行10=红方底线=UCCI行0，GUI行1=黑方底线=UCCI行9
   l_nUCCICol := nGUICol - 1

RETURN { l_nUCCIRow, l_nUCCICol }
//--------------------------------------------------------------------------------

/*
 * UCCI 坐标转 GUI/TUI 坐标
 *
 * 参数:
 *   nUCCIRow - UCCI 行 (0-9，从下到上)
 *   nUCCICol - UCCI 列 (0-8，从左到右)
 * 返回: { nGUIRow, nGUICol } - GUI 坐标 (行1-10, 列1-9)
 *
 * 标准 UCCI 坐标系统：
 * - 行: 0-9（从下到上），行0=红方底线，行9=黑方底线
 * - 列: a-i（从左到右），对应0-8
 * - 格式: 列字母 + 行数字（如 "a0"、"e9"）
 *
 * 转换关系（标准UCCI）：
 * - GUI行号 = 10 - UCCI行号
 * - GUI列号 = UCCI列号 + 1
 *
 * 示例：
 *   xq_UCCIToGUI(0, 0) → {10, 1} → 红方左侧车（UCCI "a0"）
 *   xq_UCCIToGUI(0, 4) → {10, 5} → 红方帅（UCCI "e0"）
 *   xq_UCCIToGUI(9, 4) → {1, 5} → 黑方将（UCCI "e9"）
 *   xq_UCCIToGUI(9, 0) → {1, 1} → 黑方左侧车（UCCI "a9"）
 */
function xq_UCCIToGUI( nUCCIRow, nUCCICol )
local l_nGUIRow, l_nGUICol

   // 转换公式（标准UCCI）
   l_nGUIRow := 10 - nUCCIRow  // UCCI行0=红方底线=GUI行10，UCCI行9=黑方底线=GUI行1
   l_nGUICol := nUCCICol + 1

RETURN { l_nGUIRow, l_nGUICol }
//--------------------------------------------------------------------------------

/*
 * UCCI 坐标转数组索引
 *
 * 参数:
 *   nUCCIRow - UCCI 行 (0-9，从下到上)
 *   nUCCICol - UCCI 列 (0-8，从左到右)
 * 返回: nIdx - 数组索引 (1-90)
 *
 * XQP/FEN 顺序（从黑方底线到红方底线）：
 * - UCCI行9 = 黑方底线 = 索引1-9
 * - UCCI行0 = 红方底线 = 索引82-90
 *
 * 标准 UCCI 坐标系统：
 * - 行: 0-9（从下到上），行0=红方底线，行9=黑方底线
 * - 列: a-i（从左到右），对应0-8
 * - 格式: 列字母 + 行数字（如 "a0"、"e9"）
 *
 * 索引计算公式：nIdx = (9 - nUCCIRow) * 9 + nUCCICol + 1
 *
 * 示例：
 *   xq_UCCIToIdx(0, 0) → 82  → 红方左侧车（UCCI "a0"）
 *   xq_UCCIToIdx(0, 4) → 86  → 红方帅（UCCI "e0"）
 *   xq_UCCIToIdx(9, 4) → 5   → 黑方将（UCCI "e9"）
 *   xq_UCCIToIdx(9, 0) → 1   → 黑方左侧车（UCCI "a9"）
 */
function xq_UCCIToIdx( nUCCIRow, nUCCICol )

RETURN (9 - nUCCIRow) * 9 + nUCCICol + 1

/*
 * 数组索引转 UCCI 坐标
 *
 * 参数:
 *   nIdx - 数组索引 (1-90)
 * 返回: { nUCCIRow, nUCCICol } - UCCI 坐标 (行0-9, 列0-8)
 *
 * XQP/FEN 顺序（从黑方底线到红方底线）：
 * - 索引1-9: 黑方底线（GUI行1，UCCI行9）
 * - 索引82-90: 红方底线（GUI行10，UCCI行0）
 *
 * 标准 UCCI 坐标系统：
 * - 行: 0-9（从下到上），行0=红方底线，行9=黑方底线
 * - 列: a-i（从左到右），对应0-8
 * - 格式: 列字母 + 行数字（如 "a0"、"e9"）
 *
 * 反向计算公式：
 * - nUCCIRow = 9 - Int((nIdx - 1) / 9)
 * - nUCCICol = (nIdx - 1) % 9
 *
 * 示例：
 *   xq_IdxToUCCI(1)   → {9, 0} → 黑方左侧车（UCCI "a9"）
 *   xq_IdxToUCCI(5)   → {9, 4} → 黑方将（UCCI "e9"）
 *   xq_IdxToUCCI(86)  → {0, 4} → 红方帅（UCCI "e0"）
 *   xq_IdxToUCCI(82)  → {0, 0} → 红方左侧车（UCCI "a0"）
 */
function xq_IdxToUCCI( nIdx )
local l_nUCCIRow, l_nUCCICol

   l_nUCCIRow := 9 - Int( (nIdx - 1) / 9 )
   l_nUCCICol := Int((nIdx - 1) % 9)

RETURN { l_nUCCIRow, l_nUCCICol }
//--------------------------------------------------------------------------------

/*
 * 数组索引转 UCCI 字符串（如 "a0"）
 *
 * 参数:
 *   nIdx - 数组索引 (1-90)
 * 返回: cUCCICoord - UCCI 字符串 (如 "a0", "e9")
 *
 * 标准 UCCI 坐标系统：
 * - 行: 0-9（从下到上），行0=红方底线，行9=黑方底线
 * - 列: a-i（从左到右），对应0-8
 * - 格式: 列字母 + 行数字（如 "a0"、"e9"）
 *
 * 棋盘字符串构建顺序（标准UCCI：从红方底线到黑方底线）：
 * - 索引1-9: 红方底线（UCCI行0）
 * - 索引82-90: 黑方底线（UCCI行9）
 *
 * 示例：
 *   xq_IdxToUCCIStr(1)   → "a0" → 红方左侧车（UCCI "a0"）
 *   xq_IdxToUCCIStr(5)   → "e0" → 红方帅（UCCI "e0"）
 *   xq_IdxToUCCIStr(86)  → "e9" → 黑方将（UCCI "e9"）
 *   xq_IdxToUCCIStr(82)  → "a9" → 黑方左侧车（UCCI "a9"）
 */
function xq_IdxToUCCIStr( nIdx )
local l_aUCCI, l_nUCCIRow, l_nUCCICol, l_cCol, l_cRow

   // 直接使用 xq_IdxToUCCI 转换到 UCCI 坐标
   l_aUCCI := xq_IdxToUCCI( nIdx )
   l_nUCCIRow := l_aUCCI[1]
   l_nUCCICol := l_aUCCI[2]

   l_cCol := Chr( Asc('a') + l_nUCCICol )
   l_cRow := LTrim( Str( l_nUCCIRow ) )

RETURN l_cCol + l_cRow
//--------------------------------------------------------------------------------

/*
 * UCCI 字符串转数组索引
 *
 * 参数:
 *   cUCCICoord - UCCI 字符串 (如 "a0", "e9")
 * 返回: nIdx - 数组索引 (1-90)
 *
 * 标准 UCCI 坐标系统：
 * - 行: 0-9（从下到上），行0=红方底线，行9=黑方底线
 * - 列: a-i（从左到右），对应0-8
 * - 格式: 列字母 + 行数字（如 "a0"、"e9"）
 *
 * 棋盘字符串构建顺序（标准UCCI：从红方底线到黑方底线）：
 * - 索引1-9: 红方底线（UCCI行0）
 * - 索引82-90: 黑方底线（UCCI行9）
 *
 * 示例：
 *   xq_StrToIdx("a0") → 1   → 红方左侧车（UCCI "a0"）
 *   xq_StrToIdx("e0") → 5   → 红方帅（UCCI "e0"）
 *   xq_StrToIdx("e9") → 86  → 黑方将（UCCI "e9"）
 *   xq_StrToIdx("a9") → 82  → 黑方左侧车（UCCI "a9"）
 */
function xq_StrToIdx( cUCCICoord )
local l_nUCCICol, l_nUCCIRow, l_cCol, l_cRow

   // 分离列和行
   l_cCol := Upper( SubStr( cUCCICoord, 1, 1 ) )
   l_cRow := SubStr( cUCCICoord, 2 )

   // 转换为数字
   l_nUCCICol := Asc( Lower( l_cCol ) ) - Asc( 'a' )
   l_nUCCIRow := Val( l_cRow )

   // 直接使用 xq_UCCIToIdx 转换到索引
RETURN xq_UCCIToIdx( l_nUCCIRow, l_nUCCICol )
//--------------------------------------------------------------------------------

/*
 * GUI/TUI 坐标转数组索引
 *
 * 参数:
 *   nGUIRow - GUI 行 (1-10，从上到下)
 *   nGUICol - GUI 列 (1-9，从左到右)
 * 返回: nIdx - 数组索引 (1-90)
 *
 * XQP/FEN 顺序（从黑方底线到红方底线）：
 * - 索引1-9: 黑方底线（GUI行1）
 * - 索引82-90: 红方底线（GUI行10）
 *
 * 标准 UCCI 坐标系统：
 * - 行: 0-9（从下到上），行0=红方底线，行9=黑方底线
 * - 列: a-i（从左到右），对应0-8
 * - 格式: 列字母 + 行数字（如 "a0"、"e9"）
 *
 * 转换关系：
 * - GUI → 索引: nIdx = (nGUIRow - 1) * 9 + nGUICol
 * - GUI → UCCI: nUCCIRow = 10 - nGUIRow, nUCCICol = nGUICol - 1
 *
 * 示例：
 *   xq_GUIToIdx(1, 1)  → 1   → 黑方左侧车（UCCI "a9"）
 *   xq_GUIToIdx(1, 5)  → 5   → 黑方将（UCCI "e9"）
 *   xq_GUIToIdx(10, 5) → 86  → 红方帅（UCCI "e0"）
 *   xq_GUIToIdx(10, 1) → 82  → 红方左侧车（UCCI "a0"）
 */
function xq_GUIToIdx( nGUIRow, nGUICol )

   // 直接基于 GUI 坐标计算索引（与 XQP/FEN 顺序一致）
   // nIdx = (nGUIRow - 1) * 9 + nGUICol
RETURN (nGUIRow - 1) * 9 + nGUICol
//--------------------------------------------------------------------------------

/*
 * 数组索引转 GUI/TUI 坐标
 *
 * 参数:
 *   nIdx - 数组索引 (1-90)
 * 返回: { nGUIRow, nGUICol } - GUI 坐标 (行1-10, 列1-9)
 *
 * XQP/FEN 顺序（从黑方底线到红方底线）：
 * - 索引1-9: 黑方底线（GUI行1）
 * - 索引82-90: 红方底线（GUI行10）
 *
 * 反向计算公式：
 * - nGUIRow = Int((nIdx - 1) / 9) + 1
 * - nGUICol = (nIdx - 1) % 9 + 1
 *
 * 示例：
 *   xq_IdxToGUI(1)   → {1, 1}  → 黑方左侧车（UCCI "a9"）
 *   xq_IdxToGUI(5)   → {1, 5}  → 黑方将（UCCI "e9"）
 *   xq_IdxToGUI(86)  → {10, 5} → 红方帅（UCCI "e0"）
 *   xq_IdxToGUI(82)  → {10, 1} → 红方左侧车（UCCI "a0"）
 */
function xq_IdxToGUI( nIdx )
local l_nGUIRow, l_nGUICol

   // 索引 → GUI 坐标（与 XQP/FEN 顺序一致）
   l_nGUIRow := Int((nIdx - 1) / 9) + 1
   l_nGUICol := Int((nIdx - 1) % 9) + 1

RETURN { l_nGUIRow, l_nGUICol }
//--------------------------------------------------------------------------------

/*
 * 坐标转换：数组索引转行列（用于兼容，实际应使用 xq_IdxToGUI）
 *
 * 参数:
 *   nIdx - 数组索引 (1-based，范围1-90)
 *   nWidth - 数组宽度（必须为9）
 * 返回: { nRow, nCol } - GUI 坐标 (行1-10, 列1-9)
 *
 * 注意: 此函数为兼容保留，建议使用 xq_IdxToGUI()
 */
function xq_ArrayIdxToRC_WithWidth( nIdx, nWidth )
local l_nRow, l_nCol, l_aUCCI

   // 使用新的转换函数
   l_aUCCI := xq_IdxToUCCI( nIdx )
   l_aUCCI := xq_UCCIToGUI( l_aUCCI[1], l_aUCCI[2] )

RETURN { l_aUCCI[1], l_aUCCI[2] }
//--------------------------------------------------------------------------------

/*
 * 坐标转换：数组索引转行列（用于兼容，实际应使用 xq_IdxToGUI）
 *
 * 参数:
 *   nIdx - 数组索引 (1-based，范围1-90)
 * 返回: { nRow, nCol } - GUI 坐标 (行1-10, 列1-9)
 *
 * 注意: 此函数为兼容保留，建议使用 xq_IdxToGUI()
 */
function xq_ArrayIdxToRC( nIdx )
local l_nRow, l_nCol, l_aUCCI

   // 使用新的转换函数
   l_aUCCI := xq_IdxToUCCI( nIdx )
   l_aUCCI := xq_UCCIToGUI( l_aUCCI[1], l_aUCCI[2] )

RETURN { l_aUCCI[1], l_aUCCI[2] }
//--------------------------------------------------------------------------------

/*
 * 检查位置是否在红方九宫格内
 *
 * 参数:
 *   nRow - 行号 (逻辑坐标 0-9，0=红方底线)
 *   nCol - 列号 (0-8)
 * 返回: .T. 在九宫格内, .F. 不在
 */
function xq_IsInRedPalace( nRow, nCol )
RETURN (nRow >= XQ_PALACE_RED_MIN_R .AND. nRow <= XQ_PALACE_RED_MAX_R .AND. ;
        nCol >= XQ_PALACE_RED_MIN_C .AND. nCol <= XQ_PALACE_RED_MAX_C)
//--------------------------------------------------------------------------------

/*
 * 检查位置是否在黑方九宫格内
 *
 * 参数:
 *   nRow - 行号 (逻辑坐标 0-9，9=黑方底线)
 *   nCol - 列号 (0-8)
 * 返回: .T. 在九宫格内, .F. 不在
 */
function xq_IsInBlackPalace( nRow, nCol )
RETURN (nRow >= XQ_PALACE_BLK_MIN_R .AND. nRow <= XQ_PALACE_BLK_MAX_R .AND. ;
        nCol >= XQ_PALACE_BLK_MIN_C .AND. nCol <= XQ_PALACE_BLK_MAX_C)
//--------------------------------------------------------------------------------

/*
 * 获取棋子名称（中文字符）
 *
 * 参数:
 *   cPiece - 棋子代码 (如 "r", "n", "b" 等)
 * 返回: cName - 棋子中文名称
 */
function GetPieceName( cPiece )
local l_cName

   DO CASE
   CASE cPiece == "r" ; l_cName := "車"
   CASE cPiece == "n" ; l_cName := "馬"
   CASE cPiece == "b" ; l_cName := "象"
   CASE cPiece == "a" ; l_cName := "士"
   CASE cPiece == "k" ; l_cName := "將"
   CASE cPiece == "c" ; l_cName := "砲"
   CASE cPiece == "p" ; l_cName := "卒"
   CASE cPiece == "R" ; l_cName := "俥"
   CASE cPiece == "N" ; l_cName := "傌"
   CASE cPiece == "B" ; l_cName := "相"
   CASE cPiece == "A" ; l_cName := "仕"
   CASE cPiece == "K" ; l_cName := "帥"
   CASE cPiece == "C" ; l_cName := "炮"
   CASE cPiece == "P" ; l_cName := "兵"
   OTHERWISE           ; l_cName := "＋"
   ENDCASE

RETURN l_cName
//--------------------------------------------------------------------------------

/*
 * 将棋盘数组转换为字符串
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 * 返回: cBoard - 棋盘字符串
 */
function xq_ArrayToString( aBoard )
local l_cBoard := ""
local l_nRow, l_nCol, l_nIdx

   FOR l_nRow := 1 TO 10
      FOR l_nCol := 1 TO 9
         l_nIdx := xq_RCToArrayIdx( l_nRow, l_nCol )
         IF aBoard[l_nIdx] == "0"
            l_cBoard += "0"
         ELSE
            l_cBoard += aBoard[l_nIdx]
         ENDIF
      NEXT
   NEXT

RETURN l_cBoard
//--------------------------------------------------------------------------------

/*
 * 将棋盘字符串转换为数组
 *
 * 参数:
 *   cBoard - 棋盘字符串（90字符，从左到右，从上到下）
 * 返回: aBoard - 11x12 数组
 */
function xq_StringToArray( cBoard )
local l_aBoard
local l_nRow, l_nCol, l_nPos, l_nBoardSize, l_nIdx

   // 检测字符串长度，决定数组大小
   l_nBoardSize := Len( cBoard )

   IF l_nBoardSize == 90
      // 90字符：10行×9列，创建90元素数组
      l_aBoard := Array( 90 )

      // 初始化为空
      FOR l_nRow := 1 TO Len( l_aBoard )
         l_aBoard[l_nRow] := "0"
      NEXT

      // 解析字符串：每行9个字符，共10行
      l_nPos := 1
      FOR l_nRow := 0 TO 9
         FOR l_nCol := 0 TO 8
            IF l_nPos <= Len( cBoard )
               // 简单的线性索引：nRow*9 + nCol + 1
               l_aBoard[l_nRow*9 + l_nCol + 1] := SubStr( cBoard, l_nPos, 1 )
               l_nPos++
            ENDIF
         NEXT
      NEXT
   ELSE
      // 120字符：12行×10列（带边界），创建120元素数组
      l_aBoard := Array( XQ_ARRAY_HEIGHT * XQ_ARRAY_WIDTH )

      // 初始化为空
      FOR l_nRow := 1 TO Len( l_aBoard )
         l_aBoard[l_nRow] := "0"
      NEXT

      // 解析字符串：每行9个字符，共10行
      l_nPos := 1
      FOR l_nRow := 1 TO 10
         FOR l_nCol := 1 TO 9
            IF l_nPos <= Len( cBoard )
               l_nIdx := xq_RCToArrayIdx( l_nRow, l_nCol )
               l_aBoard[l_nIdx] := SubStr( cBoard, l_nPos, 1 )
               l_nPos++
            ENDIF
         NEXT
      NEXT
   ENDIF

RETURN l_aBoard
//--------------------------------------------------------------------------------

/*
 * 将棋盘位置转换为 FEN 格式
 *
 * 参数:
 *   aBoard - 90 元素数组表示的棋盘（10x9）
 *   lRedTurn - 红方回合 (.T. / .F.)
 * 返回: cFen - FEN 格式的局面字符串
 * 
 * 注意: 数组存储顺序（物理位置0-9）已经与FEN格式一致
 * - 物理位置0（索引1-9）= 黑方底线 = FEN第一行
 * - 物理位置9（索引82-90）= 红方底线 = FEN最后一行
 * 所以不需要反转，直接按顺序生成FEN即可
 */
function xq_BoardToFen( aBoard, lRedTurn )
local l_cFen := ""
local l_nRow, l_nCol, l_nEmpty, l_nIdx, l_nBoardSize

   // 检测数组大小：90 (10x9) 或 120 (12x10)
   l_nBoardSize := Len( aBoard )
   IF l_nBoardSize == 120
      // 使用 XQ_ARRAY_WIDTH (12)
      FOR l_nRow := 1 TO 10
         l_nEmpty := 0
         FOR l_nCol := 1 TO 9
            l_nIdx := xq_RCToArrayIdx( l_nRow, l_nCol )  // 使用 xq_RCToArrayIdx 计算
            IF aBoard[l_nIdx] == "0"
               l_nEmpty++
            ELSE
               IF l_nEmpty > 0
                  l_cFen += LTrim(Str(l_nEmpty))
                  l_nEmpty := 0
               ENDIF
               l_cFen += aBoard[l_nIdx]
            ENDIF
         NEXT
         IF l_nEmpty > 0
            l_cFen += LTrim(Str(l_nEmpty))
         ENDIF
         IF l_nRow < 9
            l_cFen += "/"
         ENDIF
      NEXT
   ELSE
      // 使用 XQ_BOARD_COLS (9) - 90元素数组
      // XQP/FEN 顺序：数组索引1-9 = 黑方底线，索引82-90 = 红方底线
      // FEN 格式要求从黑方底线到红方底线，所以从索引1开始，到索引90结束
      FOR l_nRow := 0 TO 9
         l_nEmpty := 0
         FOR l_nCol := 0 TO 8
            l_nIdx := 1 + l_nRow * XQ_BOARD_COLS + l_nCol
            IF aBoard[l_nIdx] == "0"
               l_nEmpty++
            ELSE
               IF l_nEmpty > 0
                  l_cFen += LTrim(Str(l_nEmpty))
                  l_nEmpty := 0
               ENDIF
               l_cFen += aBoard[l_nIdx]
            ENDIF
         NEXT
         IF l_nEmpty > 0
            l_cFen += LTrim(Str(l_nEmpty))
         ENDIF
         IF l_nRow < 9
            l_cFen += "/"
         ENDIF
      NEXT
   ENDIF

   // 添加回合信息
   l_cFen += " " + Iif( lRedTurn, "w", "b" )

RETURN l_cFen
//--------------------------------------------------------------------------------

/*
 * 将 FEN 格式转换为棋盘数组
 *
 * 参数:
 *   cFen - FEN 格式的局面字符串
 * 返回: { aBoard, lRedTurn } - { 棋盘数组, 红方回合标志 }
 * 
 * 注意: FEN格式与数组存储顺序一致
 * - FEN第一行 = 黑方底线 = 数组物理位置0（索引1-9）
 * - FEN最后一行 = 红方底线 = 数组物理位置9（索引82-90）
 * 所以直接按顺序填充即可
 */
function xq_FenToArrayBoard( cFen )
local l_aBoard := Array( XQ_BOARD_SIZE )
local l_lRedTurn := .T.
local l_cParts, l_cFenBoard, l_cTurn, l_nRow, l_nCol, l_nCharPos, l_cChar, l_n
local l_cRow, l_nIdx, l_nEmpty

   // 初始化为空
   FOR l_nRow := 1 TO Len( l_aBoard )
      l_aBoard[l_nRow] := "0"
   NEXT

   // 解析 FEN
   l_cParts := hb_ATokens( cFen, " " )
   l_cFenBoard := l_cParts[1]
   IF Len( l_cParts ) > 1
      l_cTurn := l_cParts[2]
      l_lRedTurn := (l_cTurn == "w")
   ENDIF

   // 转换为棋盘数组
   // FEN格式与数组存储顺序一致，直接按顺序填充
   l_cParts := hb_ATokens( l_cFenBoard, "/" )
   FOR l_nRow := 1 TO 10
      l_cRow := l_cParts[l_nRow]
      l_nCharPos := 1
      l_nCol := 0
      DO WHILE l_nCharPos <= Len( l_cRow ) .AND. l_nCol <= 8
         l_cChar := SubStr( l_cRow, l_nCharPos, 1 )
         IF l_cChar >= "0" .AND. l_cChar <= "9"
            // 数字表示空位，跳过相应数量的列
            l_nEmpty := Val( l_cChar )
            FOR l_n := 1 TO l_nEmpty
               IF l_nCol <= 8
                  // 使用 XQ_BOARD_COLS (9) 而不是 XQ_ARRAY_WIDTH (12)
                  l_nIdx := 1 + (l_nRow - 1) * XQ_BOARD_COLS + l_nCol
                  l_aBoard[l_nIdx] := "0"
                  l_nCol++
               ENDIF
            NEXT
            l_nCharPos++
         ELSE
            // 棋子
            IF l_nCol <= 8
               // 使用 XQ_BOARD_COLS (9) 而不是 XQ_ARRAY_WIDTH (12)
               l_nIdx := 1 + (l_nRow - 1) * XQ_BOARD_COLS + l_nCol
               l_aBoard[l_nIdx] := l_cChar
               l_nCol++
            ENDIF
            l_nCharPos++
         ENDIF
      ENDDO
   NEXT

RETURN { l_aBoard, l_lRedTurn }
//--------------------------------------------------------------------------------

/*
 * 将 FEN 格式转换为 ASCII 棋盘布局
 *
 * 参数:
 *   cFen - FEN 格式的局面字符串
 * 返回: cBoard - ASCII 棋盘布局字符串
 */
function xq_FenToAscii( cFen )
local l_cBoard := ""
local l_cFenBoard, l_cTurn
local l_cParts, l_i, l_j, l_k, l_cChar, l_n
local l_aBoard := Array( 10, 9 )
local l_cRow, l_cPiece
local l_cLine, l_nEmpty

   // 解析 FEN
   l_cParts := hb_ATokens( cFen, " " )
   l_cFenBoard := l_cParts[1]
   IF Len( l_cParts ) > 1
      l_cTurn := l_cParts[2]
   ENDIF

   // 将 FEN 转换为棋盘数组
   l_cParts := hb_ATokens( l_cFenBoard, "/" )
   FOR l_i := 1 TO 10
      l_cRow := l_cParts[l_i]
      l_k := 1
      l_j := 1
      DO WHILE l_k <= Len( l_cRow ) .AND. l_j <= 9
         l_cChar := SubStr( l_cRow, l_k, 1 )
         IF l_cChar >= "0" .AND. l_cChar <= "9"
            // 数字表示空位，跳过相应数量的列
            l_nEmpty := Val( l_cChar )
            FOR l_n := 1 TO l_nEmpty
               IF l_j <= 9
                  l_aBoard[l_i,l_j] := "0"
                  l_j++
               ENDIF
            NEXT
            l_k++
         ELSE
            // 棋子
            IF l_j <= 9
               l_aBoard[l_i,l_j] := l_cChar
               l_j++
            ENDIF
            l_k++
         ENDIF
      ENDDO
      // 填充剩余的空位
      DO WHILE l_j <= 9
         l_aBoard[l_i,l_j] := "0"
         l_j++
      ENDDO
   NEXT

   // 添加回车
   l_cBoard += Chr(10)

   // 生成 19 行 ASCII 棋盘
   // 第1行：黑方底线（将车马象士）
   l_cLine := ""
   FOR l_j := 1 TO 9
      l_cPiece := l_aBoard[1,l_j]
      IF l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      ELSE
         l_cLine += "＋"
      ENDIF
      IF l_j < 9
         l_cLine += "－"
      ENDIF
   NEXT
   l_cBoard += l_cLine + Chr(10)

   // 第2行：斜线（黑方九宫格）
   l_cLine := "｜　｜　｜　｜＼｜／｜　｜　｜　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第3行：分隔线
   l_cLine := "＋－＋－＋－＋－＋－＋－＋－＋－＋"
   l_cBoard += l_cLine + Chr(10)

   // 第4行：斜线（黑方九宫格）
   l_cLine := "｜　｜　｜　｜／｜＼｜　｜　｜　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第5行：黑方炮线
   l_cLine := ""
   FOR l_j := 1 TO 9
      l_cPiece := l_aBoard[3,l_j]
      IF l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      ELSE
         l_cLine := "＋"
      ENDIF
      IF l_j < 9
         l_cLine += "－"
      ENDIF
   NEXT
   l_cBoard += l_cLine + Chr(10)

   // 第6行：空行
   l_cLine := "｜　｜　｜　｜　｜　｜　｜　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第7行：黑方卒线
   l_cLine := ""
   FOR l_j := 1 TO 9
      l_cPiece := l_aBoard[4,l_j]
      IF l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      ELSE
         l_cLine += "＋"
      ENDIF
      IF l_j < 9
         l_cLine += "－"
      ENDIF
   NEXT
   l_cBoard += l_cLine + Chr(10)

   // 第8行：空行
   l_cLine := "｜　｜　｜　｜　｜　｜　｜　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第9行：分隔线
   l_cLine := "＋－＋－＋－＋－＋－＋－＋－＋－＋"
   l_cBoard += l_cLine + Chr(10)

   // 第10行：楚河汉界
   l_cLine := "｜　　　　　　楚河汉界　　　　　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第11行：分隔线
   l_cLine := "＋－＋－＋－＋－＋－＋－＋－＋－＋"
   l_cBoard += l_cLine + Chr(10)

   // 第12行：空行
   l_cLine := "｜　｜　｜　｜　｜　｜　｜　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第13行：红方兵线
   l_cLine := ""
   FOR l_j := 1 TO 9
      l_cPiece := l_aBoard[7,l_j]
      IF l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      ELSE
         l_cLine += "＋"
      ENDIF
      IF l_j < 9
         l_cLine += "－"
      ENDIF
   NEXT
   l_cBoard += l_cLine + Chr(10)

   // 第14行：空行
   l_cLine := "｜　｜　｜　｜　｜　｜　｜　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第15行：红方炮线
   l_cLine := ""
   FOR l_j := 1 TO 9
      l_cPiece := l_aBoard[8,l_j]
      IF l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      ELSE
         l_cLine += "＋"
      ENDIF
      IF l_j < 9
         l_cLine += "－"
      ENDIF
   NEXT
   l_cBoard += l_cLine + Chr(10)

   // 第16行：斜线（红方九宫格）
   l_cLine := "｜　｜　｜　｜＼｜／｜　｜　｜　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第17行：分隔线
   l_cLine := "＋－＋－＋－＋－＋－＋－＋－＋－＋"
   l_cBoard += l_cLine + Chr(10)

   // 第18行：斜线（红方九宫格）
   l_cLine := "｜　｜　｜　｜／｜＼｜　｜　｜　｜"
   l_cBoard += l_cLine + Chr(10)

   // 第19行：红方底线（帅车马相仕）
   l_cLine := ""
   FOR l_j := 1 TO 9
      l_cPiece := l_aBoard[10,l_j]
      IF l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      ELSE
         l_cLine += "＋"
      ENDIF
      IF l_j < 9
         l_cLine += "－"
      ENDIF
   NEXT
   l_cBoard += l_cLine + Chr(10)

RETURN l_cBoard
//--------------------------------------------------------------------------------

/*
 * 检查移动是否合法（包括白脸将检测）
 *
 * 参数:
 *   aPos - 位置结构 (aPos[POS_BOARD] 为棋盘字符串, aPos[POS_TURN] 为回合标志)
 *   nMove - 移动编码 (低8位是源位置索引，高8位是目标位置索引)
 * 返回: .T. 合法, .F. 不合法
 */
function xq_IsMoveCorrect( aPos, nMove )
local l_cBoard := aPos[POS_BOARD]
local l_lRedTurn := aPos[POS_TURN]
local l_aBoard := xq_StringToArray( l_cBoard )
local l_nFromIdx := hb_BitAnd( nMove, 0xff )
local l_nToIdx := hb_BitAnd( hb_BitShift( nMove, -8 ), 0xff )
local l_cPiece := l_aBoard[l_nFromIdx]
local l_lIsRed := (Upper(l_cPiece) == l_cPiece)  // 使用Upper()判断大小写（UTF8EX兼容）
local l_lCorrect
local l_aTempBoard
local l_nRedKingIdx
local l_nBlackKingIdx
local l_lCurrentInCheck

   // 检查当前是否被将军
   l_lCurrentInCheck := xq_IsKingInCheck( l_aBoard, l_lRedTurn )

   // 检查索引是否有效
   IF l_nFromIdx < 1 .OR. l_nFromIdx > Len(l_aBoard) .OR. l_nToIdx < 1 .OR. l_nToIdx > Len(l_aBoard)
      RETURN .F.
   ENDIF

   // 检查是否是正确的回合
   IF l_lIsRed != l_lRedTurn
      RETURN .F.
   ENDIF

   // 检查移动规则
   l_lCorrect := xq_CheckMoveRules( l_aBoard, l_nFromIdx, l_nToIdx, l_cPiece )

   IF !l_lCorrect
      RETURN .F.
   ENDIF

   // 模拟移动
   l_aTempBoard := AClone( l_aBoard )
   l_aTempBoard[l_nToIdx] := l_aTempBoard[l_nFromIdx]
   l_aTempBoard[l_nFromIdx] := "0"

   // 检查是否吃掉对方老将
   l_nRedKingIdx := xq_FindKing( l_aTempBoard, .T. )
   l_nBlackKingIdx := xq_FindKing( l_aTempBoard, .F. )

   IF l_nRedKingIdx == -1 .OR. l_nBlackKingIdx == -1
      RETURN .T.  // 吃掉老将，胜利
   ENDIF

   // 检查移动后己方是否被将军（不能送将）
   IF xq_IsKingInCheck( l_aTempBoard, l_lIsRed )
      RETURN .F.
   ENDIF

   // 检查是否造成白脸将
   IF xq_CheckKingsFacing( l_aTempBoard )
      RETURN .F.
   ENDIF

RETURN .T.
//--------------------------------------------------------------------------------

/*
 * 检查某方是否被将军
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 *   lRed - 是否检查红方 (.T. 检查红方是否被将军, .F. 检查黑方是否被将军)
 * 返回: .T. 被将军, .F. 不被将军
 */
function xq_IsKingInCheck( aBoard, lRed )
local l_nKingIdx, l_i, l_j, l_nIdx, l_nFromIdx, l_nToIdx, l_cPiece, l_nMove
local l_aTempBoard
local l_lPieceIsRed
local l_nWidth := Iif(Len(aBoard) == 90, 9, 12)  // 根据数组长度确定宽度

   // 找到己方将/帅的位置
   l_nKingIdx := xq_FindKing( aBoard, lRed )
   IF l_nKingIdx == -1
      RETURN .T.  // 没有找到将/帅，算被将军（老将被吃了）
   ENDIF

   // 检查对方所有棋子是否可以攻击到己方将/帅
   FOR l_i := 1 TO 10
      FOR l_j := 1 TO 9
         l_nIdx := xq_GUIToIdx( l_i, l_j )  // 使用统一的坐标转换函数
         IF l_nIdx > Len(aBoard)
            LOOP  // 超出数组范围，跳过
         ENDIF
         l_cPiece := aBoard[l_nIdx]
         IF l_cPiece != "0"
            // 检查是否是对方棋子（使用Upper()判断大小写）
            l_lPieceIsRed := (Upper(l_cPiece) == l_cPiece)
            IF l_lPieceIsRed != lRed  // 是对方棋子
               // 检查这个棋子是否能攻击到将/帅
               l_nMove := l_nIdx + l_nKingIdx * 256  // 构建移动编码
               IF xq_CheckMoveRules( aBoard, l_nIdx, l_nKingIdx, l_cPiece )
                  RETURN .T.  // 被将军
               ENDIF
            ENDIF
         ENDIF
      NEXT
   NEXT

RETURN .F.
//--------------------------------------------------------------------------------

/*
 * 检查将帅是否照面（白脸将）
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 * 返回: .T. 将帅照面, .F. 将帅未照面
 */
function xq_CheckKingsFacing( aBoard )
local l_nRedKingIdx, l_nBlackKingIdx
local l_nRedKingRow, l_nRedKingCol
local l_nBlackKingRow, l_nBlackKingCol
local l_nWidth := Iif(Len(aBoard) == 90, 9, 12)
local l_aRC, l_i, l_nIdx

   // 找到红方帅和黑方将的位置
   l_nRedKingIdx := xq_FindKing( aBoard, .T. )
   l_nBlackKingIdx := xq_FindKing( aBoard, .F. )

   IF l_nRedKingIdx == -1 .OR. l_nBlackKingIdx == -1
      RETURN .F.  // 某个将/帅不存在，不算照面
   ENDIF

   // 将索引转换为行列坐标
   l_aRC := xq_IdxToGUI( l_nRedKingIdx )
   l_nRedKingRow := l_aRC[1]
   l_nRedKingCol := l_aRC[2]

   l_aRC := xq_IdxToGUI( l_nBlackKingIdx )
   l_nBlackKingRow := l_aRC[1]
   l_nBlackKingCol := l_aRC[2]

   // 检查是否在同一列
   IF l_nRedKingCol != l_nBlackKingCol
      RETURN .F.  // 不在同一列，不可能照面
   ENDIF

   // 检查两将之间是否有棋子
   // 确定起始和结束行（从小到大）
   IF l_nRedKingRow < l_nBlackKingRow
      FOR l_i := l_nRedKingRow + 1 TO l_nBlackKingRow - 1
         l_nIdx := xq_GUIToIdx( l_i, l_nRedKingCol )  // 使用统一的坐标转换函数
         IF l_nIdx < 1 .OR. l_nIdx > Len(aBoard)
            LOOP
         ENDIF
         IF aBoard[l_nIdx] != "0"
            RETURN .F.  // 中间有棋子，不算照面
         ENDIF
      NEXT
   ELSE
      FOR l_i := l_nBlackKingRow + 1 TO l_nRedKingRow - 1
         l_nIdx := xq_GUIToIdx( l_i, l_nRedKingCol )  // 使用统一的坐标转换函数
         IF l_nIdx < 1 .OR. l_nIdx > Len(aBoard)
            LOOP
         ENDIF
         IF aBoard[l_nIdx] != "0"
            RETURN .F.  // 中间有棋子，不算照面
         ENDIF
      NEXT
   ENDIF

   // 在同一列且中间无子，将帅照面
RETURN .T.
//--------------------------------------------------------------------------------

/*
 * 检查是否被将死
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 *   lRed - 是否检查红方 (.T. 检查红方是否被将死, .F. 检查黑方是否被将死)
 * 返回: .T. 被将死, .F. 不被将死
 */
function xq_IsCheckmate( aBoard, lRed )
local l_nFromRow, l_nFromCol, l_nToRow, l_nToCol, l_nFromIdx, l_nToIdx, l_nMove
local l_aTempBoard
local l_cPiece
local l_lHasLegalMove := .F.
local l_lPieceIsRed
local l_nWidth := Iif(Len(aBoard) == 90, 9, 12)  // 根据数组长度确定宽度
local l_nKingIdx, l_aKingRC, l_nKingRow, l_nKingCol, l_nKingLogicalRow, l_nKingLogicalCol

   // 如果没有被将军，就不可能是将死
   IF !xq_IsKingInCheck( aBoard, lRed )
      RETURN .F.
   ENDIF

   // 输出将帅位置
   l_nKingIdx := xq_FindKing( aBoard, lRed )
   IF l_nKingIdx > 0
      l_aKingRC := xq_IdxToGUI( l_nKingIdx )
      l_nKingRow := Int(l_aKingRC[1])
      l_nKingCol := Int(l_aKingRC[2])
      l_nKingLogicalRow := 10 - l_nKingRow
      l_nKingLogicalCol := l_nKingCol - 1
      // 已注释：OutErr( "Checkmate: " + Iif(lRed, "RED", "BLACK") + " king at idx=" + LTrim(Str(Int(l_nKingIdx))) + ", GUI=(" + LTrim(Str(l_nKingRow)) + "," + LTrim(Str(l_nKingCol)) + "), UCCI=(" + LTrim(Str(l_nKingLogicalCol)) + "," + LTrim(Str(l_nKingLogicalRow)) + ")" + hb_eol() )
   ENDIF

   // 清空全局数组
   IF ValType( aLegalMoves ) != "A"
      aLegalMoves := {}
   ELSE
      aLegalMoves := {}
   ENDIF

   // 尝试所有可能的移动
   FOR l_nFromRow := 0 TO 9
      FOR l_nFromCol := 0 TO 8
         l_nFromIdx := Int((l_nFromRow * l_nWidth) + l_nFromCol + 1)  // 直接计算索引
         IF l_nFromIdx > Len(aBoard)
            LOOP  // 超出数组范围，跳过
         ENDIF
         l_cPiece := aBoard[l_nFromIdx]
         IF l_cPiece != "0"
            // 检查是否是己方棋子（使用Upper()函数判断大小写）
            l_lPieceIsRed := (Upper(l_cPiece) == l_cPiece)
            IF l_lPieceIsRed == lRed  // 是己方棋子
               // 尝试移动到所有可能的位置
               FOR l_nToRow := 0 TO 9
                  FOR l_nToCol := 0 TO 8
                     l_nToIdx := Int((l_nToRow * l_nWidth) + l_nToCol + 1)  // 直接计算索引
                     IF l_nToIdx > Len(aBoard)
                        LOOP  // 超出数组范围，跳过
                     ENDIF
                     IF l_nToIdx != l_nFromIdx
                        // 构建移动编码
                        l_nMove := Int(l_nFromIdx) + Int(l_nToIdx) * 256
                        // 检查是否是合法移动
                        IF xq_IsMoveLegalWithoutCheck( aBoard, l_nMove, lRed )
                           l_lHasLegalMove := .T.
                           // 保存找到的合法移动
                           AAdd( aLegalMoves, l_cPiece + " " + Str(Int(l_nFromIdx)) + "->" + Str(Int(l_nToIdx)) )
                           // 调试输出：输出前10个合法移动（已注释）
                           // IF Len(aLegalMoves) <= 10
                           //    OutErr( "Legal move found: " + l_cPiece + " " + Str(Int(l_nFromIdx)) + "->" + Str(Int(l_nToIdx)) + hb_eol() )
                           // ENDIF
                        ENDIF
                     ENDIF
                  NEXT
               NEXT
            ENDIF
         ENDIF
      NEXT
   NEXT

RETURN !l_lHasLegalMove

//--------------------------------------------------------------------------------

/*
 * 检查是否有合法移动（用于困毙检测）
 * 不检查是否被将军，只检查是否有合法的走法
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 *   lRed - 红方标志
 * 返回: .T. 有合法移动, .F. 无合法移动
 */
function xq_HasLegalMoves( aBoard, lRed )
local l_nFromRow, l_nFromCol, l_nToRow, l_nToCol, l_nFromIdx, l_nToIdx, l_nMove
local l_cPiece
local l_lPieceIsRed
local l_nWidth := Iif(Len(aBoard) == 90, 9, 12)  // 根据数组长度确定宽度

   // 尝试所有可能的移动
   FOR l_nFromRow := 0 TO 9
      FOR l_nFromCol := 0 TO 8
         l_nFromIdx := Int((l_nFromRow * l_nWidth) + l_nFromCol + 1)  // 直接计算索引
         IF l_nFromIdx > Len(aBoard)
            LOOP  // 超出数组范围，跳过
         ENDIF
         l_cPiece := aBoard[l_nFromIdx]
         IF l_cPiece != "0"
            // 检查是否是己方棋子（使用Upper()判断大小写）
            l_lPieceIsRed := (Upper(l_cPiece) == l_cPiece)
            IF l_lPieceIsRed == lRed  // 是己方棋子
               // 尝试移动到所有可能的位置
               FOR l_nToRow := 0 TO 9
                  FOR l_nToCol := 0 TO 8
                     l_nToIdx := Int((l_nToRow * l_nWidth) + l_nToCol + 1)  // 直接计算索引
                     IF l_nToIdx > Len(aBoard)
                        LOOP  // 超出数组范围，跳过
                     ENDIF
                     IF l_nToIdx != l_nFromIdx
                        // 构建移动编码
                        l_nMove := Int(l_nFromIdx) + Int(l_nToIdx) * 256
                        // 检查是否是合法移动
                        IF xq_IsMoveLegalWithoutCheck( aBoard, l_nMove, lRed )
                           RETURN .T.  // 找到合法移动，返回 .T.
                        ENDIF
                     ENDIF
                  NEXT
               NEXT
            ENDIF
         ENDIF
      NEXT
   NEXT

RETURN .F.  // 没有找到合法移动，返回 .F.

//--------------------------------------------------------------------------------

/*
 * 检查移动是否合法（不检查当前是否被将军）
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 *   nMove - 移动编码
 *   lRedTurn - 当前回合
 * 返回: .T. 合法, .F. 不合法
 */
function xq_IsMoveLegalWithoutCheck( aBoard, nMove, lRedTurn )
local l_nFromIdx := hb_BitAnd( nMove, 0xff )
local l_nToIdx := hb_BitAnd( hb_BitShift( nMove, -8 ), 0xff )
local l_cPiece := aBoard[l_nFromIdx]
local l_lIsRed := (Upper(l_cPiece) == l_cPiece)  // 大写=红方，小写=黑方
local l_aTempBoard

   // 检查是否是正确的回合
   IF l_lIsRed != lRedTurn
      RETURN .F.
   ENDIF

   // 检查移动规则
   IF !xq_CheckMoveRules( aBoard, l_nFromIdx, l_nToIdx, l_cPiece )
      RETURN .F.
   ENDIF

   // 模拟移动，检查是否会被将军
   l_aTempBoard := AClone( aBoard )
   l_aTempBoard[l_nToIdx] := l_aTempBoard[l_nFromIdx]
   l_aTempBoard[l_nFromIdx] := "0"

   // 检查移动后是否造成白脸将（将帅照面）
   IF xq_CheckKingsFacing( l_aTempBoard )
      RETURN .F.
   ENDIF

   // 检查移动后己方是否被将军
   IF xq_IsKingInCheck( l_aTempBoard, l_lIsRed )
      RETURN .F.
   ENDIF

RETURN .T.
//--------------------------------------------------------------------------------

/*
 * 查找将/帅的位置
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 *   lRed - 是否找红方 (.T. 红方, .F. 黑方)
 * 返回: nIdx - 将/帅的位置索引，-1 表示未找到
 */
function xq_FindKing( aBoard, lRed )
local l_nRow, l_nCol, l_nIdx, l_cPiece, l_cKing, l_cLow, l_cHigh

   IF lRed
      l_cKing := "K"
      l_cLow := "A"
      l_cHigh := "Z"
   ELSE
      l_cKing := "k"
      l_cLow := "a"
      l_cHigh := "z"
   ENDIF

   // 检测数组类型，使用正确的索引计算
   IF Len( aBoard ) == 90
      // 90元素数组：使用新的坐标转换函数（以 UCCI 为基准）
      FOR l_nRow := 1 TO 10
         FOR l_nCol := 1 TO 9
            l_nIdx := xq_GUIToIdx( l_nRow, l_nCol )
            l_cPiece := aBoard[l_nIdx]
            IF l_cPiece == l_cKing
               RETURN l_nIdx
            ENDIF
         NEXT
      NEXT
   ELSE
      // 11x12数组：使用 xq_RCToArrayIdx
      FOR l_nRow := 1 TO 10
         FOR l_nCol := 1 TO 9
            l_nIdx := xq_RCToArrayIdx( l_nRow, l_nCol )
            l_cPiece := aBoard[l_nIdx]
            IF l_cPiece == l_cKing
               RETURN l_nIdx
            ENDIF
         NEXT
      NEXT
   ENDIF

RETURN -1
//--------------------------------------------------------------------------------

/*
 * 检查路径是否畅通
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 *   nFromIdx - 起始位置索引
 *   nToIdx - 目标位置索引
 * 返回: .T. 畅通, .F. 不畅通
 */
function xq_CheckPathClear( aBoard, nFromIdx, nToIdx, nWidth )
local l_aFromGUI, l_aToGUI  // GUI坐标数组（临时）
local l_nFromGUI_Row, l_nFromGUI_Col, l_nToGUI_Row, l_nToGUI_Col  // GUI坐标
local l_nStep, l_nIdx, l_i

   IF nWidth == NIL
      nWidth := Iif(Len(aBoard) == 90, 9, 12)
   ENDIF

   l_aFromGUI := xq_IdxToGUI( nFromIdx )
   l_aToGUI := xq_IdxToGUI( nToIdx )

   // 检查返回值是否有效
   IF Len(l_aFromGUI) < 2 .OR. Len(l_aToGUI) < 2
      RETURN .F.
   ENDIF

   l_nFromGUI_Row := l_aFromGUI[1]
   l_nFromGUI_Col := l_aFromGUI[2]
   l_nToGUI_Row := l_aToGUI[1]
   l_nToGUI_Col := l_aToGUI[2]

   // 垂直方向
   IF l_nFromGUI_Col == l_nToGUI_Col
      l_nStep := Iif( l_nToGUI_Row > l_nFromGUI_Row, 1, -1 )
      FOR l_i := l_nFromGUI_Row + l_nStep TO l_nToGUI_Row - l_nStep STEP l_nStep
         l_nIdx := xq_GUIToIdx( l_i, l_nFromGUI_Col )  // 使用统一的坐标转换函数
         IF l_nIdx >= 1 .AND. l_nIdx <= Len(aBoard) .AND. aBoard[l_nIdx] != "0"
            RETURN .F.
         ENDIF
      NEXT
   // 水平方向
   ELSEIF l_nFromGUI_Row == l_nToGUI_Row
      l_nStep := Iif( l_nToGUI_Col > l_nFromGUI_Col, 1, -1 )
      FOR l_i := l_nFromGUI_Col + l_nStep TO l_nToGUI_Col - l_nStep STEP l_nStep
         l_nIdx := xq_GUIToIdx( l_nFromGUI_Row, l_i )  // 使用统一的坐标转换函数
         IF l_nIdx >= 1 .AND. l_nIdx <= Len(aBoard) .AND. aBoard[l_nIdx] != "0"
            RETURN .F.
         ENDIF
      NEXT
   ELSE
      RETURN .F.
   ENDIF

RETURN .T.
//--------------------------------------------------------------------------------

/*
 * 检查移动规则
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 *   par_nFromIdx - 起始位置索引
 *   par_nToIdx - 目标位置索引
 *   par_cPiece - 棋子代码
 * 返回: .T. 合法, .F. 不合法
 */
function xq_CheckMoveRules( aBoard, par_nFromIdx, par_nToIdx, par_cPiece )
local l_aFromGUI, l_aToGUI  // GUI坐标数组（临时）
local l_nFromGUI_Row, l_nFromGUI_Col, l_nToGUI_Row, l_nToGUI_Col  // GUI坐标
local l_nLogicalRowFrom, l_nLogicalColFrom
local l_nLogicalRowTo, l_nLogicalColTo
local l_nDeltaRow, l_nDeltaCol
local l_nTargetPiece
local l_lIsRed := (Upper(par_cPiece) == par_cPiece)  // 大写=红方，小写=黑方
local l_lTargetRed, l_nMidRow, l_nMidCol, l_nMidIdx
local l_nLegRow, l_nLegCol, l_nLegIdx
local l_nStep, l_nIdx, l_nCount, l_i
local l_nWidth := Iif(Len(aBoard) == 90, 9, 12)  // 根据数组长度确定宽度

   // 使用统一的坐标转换函数
   l_aFromGUI := xq_IdxToGUI( par_nFromIdx )
   l_aToGUI := xq_IdxToGUI( par_nToIdx )

   l_nFromGUI_Row := l_aFromGUI[1]
   l_nFromGUI_Col := l_aFromGUI[2]
   l_nToGUI_Row := l_aToGUI[1]
   l_nToGUI_Col := l_aToGUI[2]

   // 将 GUI 坐标（1-based）转换为 UCCI 坐标（0-based）
   // GUI 行1 = 黑方底线 = UCCI 行9
   // GUI 行10 = 红方底线 = UCCI 行0
   l_nLogicalRowFrom := 10 - l_nFromGUI_Row
   l_nLogicalColFrom := l_nFromGUI_Col - 1
   l_nLogicalRowTo := 10 - l_nToGUI_Row
   l_nLogicalColTo := l_nToGUI_Col - 1  // 列：1-based转0-based

   l_nDeltaRow := Abs( l_nToGUI_Row - l_nFromGUI_Row )
   l_nDeltaCol := Abs( l_nToGUI_Col - l_nFromGUI_Col )

   l_nTargetPiece := aBoard[par_nToIdx]

   // 不能吃己方棋子
   IF l_nTargetPiece != "0"
      l_lTargetRed := (Upper(l_nTargetPiece) == l_nTargetPiece)  // 大写=红方，小写=黑方
      IF l_lTargetRed == l_lIsRed
         RETURN .F.
      ENDIF
   ENDIF

   DO CASE
   // 将/帅
   CASE Upper(par_cPiece) == "K"
      // 将/帅只能上下左右走一步，不能斜着走
      IF l_nDeltaRow + l_nDeltaCol != 1
         RETURN .F.
      ENDIF
      IF l_lIsRed
         IF !xq_IsInRedPalace( l_nLogicalRowTo, l_nLogicalColTo )
            RETURN .F.
         ENDIF
      ELSE
         IF !xq_IsInBlackPalace( l_nLogicalRowTo, l_nLogicalColTo )
            RETURN .F.
         ENDIF
      ENDIF

   // 士/仕
   CASE Upper(par_cPiece) == "A"
      IF l_nDeltaRow != 1 .OR. l_nDeltaCol != 1
         RETURN .F.
      ENDIF
      IF l_lIsRed
         IF !xq_IsInRedPalace( l_nLogicalRowTo, l_nLogicalColTo )
            RETURN .F.
         ENDIF
      ELSE
         IF !xq_IsInBlackPalace( l_nLogicalRowTo, l_nLogicalColTo )
            RETURN .F.
         ENDIF
      ENDIF

   // 象/相
   CASE Upper(par_cPiece) == "B"
      IF l_nDeltaRow != 2 .OR. l_nDeltaCol != 2
         RETURN .F.
      ENDIF
      // 不能过河（使用逻辑坐标）
      // 河界在逻辑行4和5之间
      // 红方：只能在逻辑行0-4（红方半场）
      // 黑方：只能在逻辑行5-9（黑方半场）
      IF l_lIsRed
         IF l_nLogicalRowFrom > 4 .OR. l_nLogicalRowTo > 4
            RETURN .F.
         ENDIF
      ELSE
         IF l_nLogicalRowFrom < 5 .OR. l_nLogicalRowTo < 5
            RETURN .F.
         ENDIF
      ENDIF
      // 检查象眼是否被堵
      l_nMidRow := Int( (l_nFromGUI_Row + l_nToGUI_Row) / 2 )
      l_nMidCol := Int( (l_nFromGUI_Col + l_nToGUI_Col) / 2 )
      l_nMidIdx := xq_GUIToIdx( l_nMidRow, l_nMidCol )  // 使用统一的坐标转换函数
      IF l_nMidIdx < 1 .OR. l_nMidIdx > Len(aBoard)
         RETURN .F.
      ENDIF
      IF aBoard[l_nMidIdx] != "0"
         RETURN .F.
      ENDIF

   // 馬
   CASE Upper(par_cPiece) == "N"
      IF !((l_nDeltaRow == 2 .AND. l_nDeltaCol == 1) .OR. (l_nDeltaRow == 1 .AND. l_nDeltaCol == 2))
         RETURN .F.
      ENDIF
      // 检查马腿是否被堵
      IF l_nDeltaRow == 2
         l_nLegRow := Iif( l_nToGUI_Row > l_nFromGUI_Row, l_nFromGUI_Row + 1, l_nFromGUI_Row - 1 )
         l_nLegCol := l_nFromGUI_Col
      ELSE
         l_nLegRow := l_nFromGUI_Row
         l_nLegCol := Iif( l_nToGUI_Col > l_nFromGUI_Col, l_nFromGUI_Col + 1, l_nFromGUI_Col - 1 )
      ENDIF
      l_nLegIdx := xq_GUIToIdx( l_nLegRow, l_nLegCol )  // 使用统一的坐标转换函数
      IF l_nLegIdx < 1 .OR. l_nLegIdx > Len(aBoard)
         RETURN .F.
      ENDIF
      IF aBoard[l_nLegIdx] != "0"
         RETURN .F.
      ENDIF

   // 車
   CASE Upper(par_cPiece) == "R"
      IF l_nFromGUI_Row != l_nToGUI_Row .AND. l_nFromGUI_Col != l_nToGUI_Col
         RETURN .F.
      ENDIF
      IF !xq_CheckPathClear( aBoard, par_nFromIdx, par_nToIdx, l_nWidth )
         RETURN .F.
      ENDIF

   // 炮
   CASE Upper(par_cPiece) == "C"
      IF l_nFromGUI_Row != l_nToGUI_Row .AND. l_nFromGUI_Col != l_nToGUI_Col
         RETURN .F.
      ENDIF
      // 移动时路径必须畅通
      IF l_nTargetPiece == "0"
         IF !xq_CheckPathClear( aBoard, par_nFromIdx, par_nToIdx, l_nWidth )
            RETURN .F.
         ENDIF
      ELSE
         // 吃子时路径必须正好有一个棋子
         l_nCount := xq_CountPiecesInPath( aBoard, par_nFromIdx, par_nToIdx, l_nWidth )
         IF l_nCount != 1
            RETURN .F.
         ENDIF
      ENDIF

   // 兵/卒
   CASE Upper(par_cPiece) == "P"
      IF l_lIsRed
         // 红兵只能向前（UCCI 行增大），过河后可以左右
         // UCCI 坐标：红方底线=行0-2，河界=行4-5，黑方底线=行7-9
         // 红兵从行0-2开始，向行9方向前进（UCCI 行增大）
         // 不能后退（UCCI 行减小），但可以横走（UCCI 行不变）
         IF l_nLogicalRowTo < l_nLogicalRowFrom
            RETURN .F.
         ENDIF
         // 使用 UCCI 坐标判断是否过河
         IF l_nLogicalRowFrom >= 5
            // 已经过河（UCCI 行5或更大），可以左右
            IF l_nDeltaRow > 1 .OR. l_nDeltaCol > 1
               RETURN .F.
            ENDIF
            // 不能同时横向和纵向移动
            IF l_nDeltaRow > 0 .AND. l_nDeltaCol > 0
               RETURN .F.
            ENDIF
         ELSE
            // 未过河只能向前（UCCI 行0-4）
            IF l_nDeltaCol != 0 .OR. l_nDeltaRow != 1
               RETURN .F.
            ENDIF
         ENDIF
      ELSE
         // 黑卒只能向前（UCCI 行减小），过河后可以左右
         // UCCI 坐标：黑方底线=行7-9，河界=行4-5，红方底线=行0-2
         // 黑卒从行7-9开始，向行0方向前进（UCCI 行减小）
         // 不能后退（UCCI 行增大），但可以横走（UCCI 行不变）
         IF l_nLogicalRowTo > l_nLogicalRowFrom
            RETURN .F.
         ENDIF
         // 使用 UCCI 坐标判断是否过河
         IF l_nLogicalRowFrom <= 4
            // 已经过河（UCCI 行4或更小），可以左右
            IF l_nDeltaRow > 1 .OR. l_nDeltaCol > 1
               RETURN .F.
            ENDIF
            // 不能同时横向和纵向移动
            IF l_nDeltaRow > 0 .AND. l_nDeltaCol > 0
               RETURN .F.
            ENDIF
         ELSE
            // 未过河只能向前（UCCI 行5-9）
            IF l_nDeltaCol != 0 .OR. l_nDeltaRow != 1
               RETURN .F.
            ENDIF
         ENDIF
      ENDIF

   ENDCASE

RETURN .T.

/*
 * 计算路径中的棋子数量
 *
 * 参数:
 *   aBoard - 11x12 数组表示的棋盘
 *   par_nFromIdx - 起始位置索引
 *   par_nToIdx - 目标位置索引
 * 返回: l_nCount - 棋子数量
 */
function xq_CountPiecesInPath( aBoard, par_nFromIdx, par_nToIdx, par_nWidth )
local l_aFromGUI, l_aToGUI  // GUI坐标数组（临时）
local l_nFromGUI_Row, l_nFromGUI_Col, l_nToGUI_Row, l_nToGUI_Col  // GUI坐标
local l_nStep, l_nIdx, l_nCount := 0, l_i

   IF par_nWidth == NIL
      par_nWidth := Iif(Len(aBoard) == 90, 9, 12)
   ENDIF

   l_aFromGUI := xq_IdxToGUI( par_nFromIdx )
   l_aToGUI := xq_IdxToGUI( par_nToIdx )

   l_nFromGUI_Row := l_aFromGUI[1]
   l_nFromGUI_Col := l_aFromGUI[2]
   l_nToGUI_Row := l_aToGUI[1]
   l_nToGUI_Col := l_aToGUI[2]

   // 垂直方向
   IF l_nFromGUI_Col == l_nToGUI_Col
      l_nStep := Iif( l_nToGUI_Row > l_nFromGUI_Row, 1, -1 )
      FOR l_i := l_nFromGUI_Row + l_nStep TO l_nToGUI_Row - l_nStep STEP l_nStep
         l_nIdx := xq_GUIToIdx( l_i, l_nFromGUI_Col )  // 使用统一的坐标转换函数
         IF aBoard[l_nIdx] != "0"
            l_nCount++
         ENDIF
      NEXT
   // 水平方向
   ELSEIF l_nFromGUI_Row == l_nToGUI_Row
      l_nStep := Iif( l_nToGUI_Col > l_nFromGUI_Col, 1, -1 )
      FOR l_i := l_nFromGUI_Col + l_nStep TO l_nToGUI_Col - l_nStep STEP l_nStep
         l_nIdx := xq_GUIToIdx( l_nFromGUI_Row, l_i )  // 使用统一的坐标转换函数
         IF aBoard[l_nIdx] != "0"
            l_nCount++
         ENDIF
      NEXT
   ENDIF

RETURN l_nCount

/*
 * 将引擎移动编码转换为 ICCS 格式
 *
 * 参数:
 *   par_nMove - 引擎移动编码 (nFrom + nTo * 256)，nFrom 和 nTo 都是 1-based 索引
 *   par_nWidth - 数组宽度（默认为9，对应90元素数组）
 * 返回: l_cICCS - ICCS 格式的移动字符串 (4字符)
 */
function xq_MoveToICCS( par_nMove, par_nWidth )
local l_nFrom, l_nTo
local l_aFromUCCI, l_aToUCCI
local l_cFromCol, l_cToCol, l_cFromRow, l_cToRow
local l_nUCCIFromRow, l_nUCCIToRow
local l_cICCS := ""

   // 默认宽度为9（90元素数组）
   IF par_nWidth == NIL
      par_nWidth := 9
   ENDIF

   // 解析移动编码（1-based 索引）
   l_nFrom := par_nMove % 256
   l_nTo := Int( par_nMove / 256 )

   // 转换为UCCI字符串（使用新的转换函数）
   l_cFromCol := SubStr( xq_IdxToUCCIStr( l_nFrom ), 1, 1 )
   l_cFromRow := SubStr( xq_IdxToUCCIStr( l_nFrom ), 2 )
   l_cToCol := SubStr( xq_IdxToUCCIStr( l_nTo ), 1, 1 )
   l_cToRow := SubStr( xq_IdxToUCCIStr( l_nTo ), 2 )

   // 构建UCCI字符串: 列+行+列+行
   l_cICCS := l_cFromCol + l_cFromRow + l_cToCol + l_cToRow

RETURN l_cICCS

/*
 * 将 ICCS 格式转换为引擎移动编码
 *
 * 参数:
 *   par_cICCS - ICCS 格式的移动字符串 (4字符)
 * 返回: l_nMove - 引擎移动编码 (nFrom + nTo * 256)，或 0 表示无效
 */
function xq_ICCSToMove( par_cICCS )
local l_nMove := 0
local l_cFromCol, l_cToCol
local l_nFromRow, l_nToRow      // UCCI坐标：行0-9（从下到上）
local l_nFromCol, l_nToCol      // UCCI坐标：列0-8（从左到右）
local l_nFromIdx, l_nToIdx

   IF Len( par_cICCS ) < 4
      RETURN 0
   ENDIF

   // 解析 ICCS 字符串
   // 格式: <from_col><from_row><to_col><to_row>
   // 例如: h2e2 -> from_col='h', from_row=2, to_col='e', to_row=2

   // 列坐标
   l_cFromCol := Lower(SubStr( par_cICCS, 1, 1 ))
   l_cToCol := Lower(SubStr( par_cICCS, 3, 1 ))

   // 行坐标 (可能是一位或两位数)
   IF IsDigit( SubStr( par_cICCS, 2, 1 ) )
      IF IsDigit( SubStr( par_cICCS, 3, 1 ) )
         // 格式如: a10b10 (列+两位数行)
         l_cFromCol := SubStr( par_cICCS, 1, 1 )
         l_nFromRow := Val( SubStr( par_cICCS, 2, 2 ) )
         l_cToCol := SubStr( par_cICCS, 4, 1 )
         l_nToRow := Val( SubStr( par_cICCS, 5, 2 ) )
      ELSE
         // 格式如: a2e2 (列+一位数行)
         l_cFromCol := Lower(SubStr( par_cICCS, 1, 1 ))
         l_nFromRow := Val( SubStr( par_cICCS, 2, 1 ) )
         l_cToCol := Lower(SubStr( par_cICCS, 3, 1 ))
         l_nToRow := Val( SubStr( par_cICCS, 4, 1 ) )
      ENDIF
   ELSE
      RETURN 0
   ENDIF

   // 列坐标转换为 0-8
   l_nFromCol := Asc( l_cFromCol ) - Asc('a')
   l_nToCol := Asc( l_cToCol ) - Asc('a')

   // 验证范围
   IF l_nFromRow < 0 .OR. l_nFromRow > 9 .OR. l_nToRow < 0 .OR. l_nToRow > 9
      RETURN 0
   ENDIF
   IF l_nFromCol < 0 .OR. l_nFromCol > 8 .OR. l_nToCol < 0 .OR. l_nToCol > 8
      RETURN 0
   ENDIF

   // 转换为数组索引（1-based）
   // ICCS格式：行0=红方底线，行9=黑方底线
   // 需要将逻辑行号转换为物理位置
   // 物理位置 = 9 - 逻辑行号（逻辑行9对应物理位置0，即黑方底线）
   // 索引 = 物理位置 * 9 + 列号 + 1
   l_nFromIdx := (9 - l_nFromRow) * 9 + l_nFromCol + 1
   l_nToIdx := (9 - l_nToRow) * 9 + l_nToCol + 1

   // 构建移动编码（1-based 索引）
   l_nMove := l_nFromIdx + l_nToIdx * 256

RETURN l_nMove

/*
 * 棋盘转FEN格式（UCCI扩展）
 *
 * 参数:
 *   par_aBoard - 11x12 数组表示的棋盘
 *   par_lRedTurn - 红方是否走棋
 *   par_nHalfMove - 半回合计数（可选，默认0）
 *   par_nFullMove - 回合计数（可选，默认1）
 * 返回: FEN字符串
 */
function xq_BoardToFenUCCI( par_aBoard, par_lRedTurn, par_nHalfMove, par_nFullMove )
local l_cFen

   // 使用现有的 xq_BoardToFen 函数
   l_cFen := xq_BoardToFen( par_aBoard, par_lRedTurn )

   // 添加 FEN 扩展字段
   // 格式: <fen_board> <turn> <castling> <en_passant> <half_move> <full_move>
   // 中国象棋没有易位和吃过路兵，所以使用 "- -"
   l_cFen += " - - " + LTrim(Str(Iif(par_nHalfMove==NIL,0,par_nHalfMove))) + " " + LTrim(Str(Iif(par_nFullMove==NIL,1,par_nFullMove)))

RETURN l_cFen

/*
 * ========================================
 * 棋局保存/加载通用接口
 * ========================================
 * Note: All save/load functions moved to xq_notation.prg
 * - xq_SaveGame
 * - xq_LoadGame
 * - xq_Save_PGN
 * - xq_Load_PGN
 * - xq_Save_FEN
 * - xq_Load_FEN
 * - xq_MoveToChineseNotation
 * - xq_RoadToChinese
 * - xq_MoveToEnglishNotation
 */