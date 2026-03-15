/*
 * 中国象棋核心引擎
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 基于 sunfish.prg 架构
 * 支持棋局状态管理、移动生成、评估函数、搜索算法
 *
 * 【重要提示】
 * 1. 本文件中的所有非 static 函数都不用在 xq_xiangqi.ch 中添加 ANNOUNCE 声明
 * 2. 修改函数签名时（函数名、参数），必须同步更新 xq_funcslist.txt 中的备忘提醒
 * 3. 删除函数时，必须从 xq_funcslist.txt 中移除对应的说明
 */

#include "xq_xiangqi.ch"

// 全局变量
static s_lXqPrgInit := .F.
static s_hPiece, s_hDirections, s_hPst
static s_nMateLower, s_nMateUpper
// 全局配置哈希表（用于替代PUBLIC变量）
// GetGlobalConfig() 返回此哈希表的引用，所有调用者共享
// 通过引用修改会影响全局配置（验证通过test_hash_ref.prg）
static s_hGlobalConfig := {=>}

/*
 * 初始化引擎
 */
function pos_Init()

   LOCAL l_i, l_arr

   IF !s_lXqPrgInit
      // 棋子分值
      s_hPiece := hb_Hash( ;
         'K', XQ_VALUE_KING, ;
         'A', XQ_VALUE_ADV, ;
         'B', XQ_VALUE_ELEPH, ;
         'N', XQ_VALUE_HORSE, ;
         'R', XQ_VALUE_ROOK, ;
         'C', XQ_VALUE_CANNON, ;
         'P', XQ_VALUE_PAWN ;
         )

      // 方向表（基于 11x12 计算数组）
      // N = -11, S = 11, E = 1, W = -1
      s_hDirections := hb_Hash( ;
         'K', { - 11, - 10, - 9, - 1, 1, 9, 10, 11 }, ;      // 将/帅：周围8格
         'A', { - 11, - 9, 11, 9 }, ;                       // 士/仕：4个斜向
         'B', { - 22, - 18, 22, 18 }, ;                     // 相/象：田字（先检查象眼）
         'N', { - 23, - 21, - 13, - 12, 12, 13, 21, 23 }, ;   // 马：日字（先检查马腿）
         'R', { - 11, - 1, 1, 11 }, ;                       // 车：直线
         'C', { - 11, - 1, 1, 11 }, ;                       // 炮：直线（吃子需要炮架）
         'P', { - 11, - 1, 1 } ;                            // 兵/卒：向前+过河后横走
         )

      // Piece-Square Tables (PST)
      // 基础分值 + 位置分值
      s_hPst := hb_Hash()

      // 兵/卒 PST
      s_hPst[ 'P' ] := xq_CreatePawnPST( .T. )  // 红方兵
      s_hPst[ 'p' ] := xq_CreatePawnPST( .F. )  // 黑方卒

      // 马 PST
      s_hPst[ 'N' ] := xq_CreateHorsePST( .T. ) // 红方马
      s_hPst[ 'n' ] := xq_CreateHorsePST( .F. ) // 黑方马

      // 车 PST
      s_hPst[ 'R' ] := xq_CreateRookPST( .T. )  // 红方车
      s_hPst[ 'r' ] := xq_CreateRookPST( .F. )  // 黑方车

      // 炮 PST
      s_hPst[ 'C' ] := xq_CreateCannonPST( .T. ) // 红方炮
      s_hPst[ 'c' ] := xq_CreateCannonPST( .F. ) // 黑方炮

      // 相/象 PST
      s_hPst[ 'B' ] := xq_CreateElephPST( .T. )  // 红方相
      s_hPst[ 'b' ] := xq_CreateElephPST( .F. )  // 黑方象

      // 士/仕 PST
      s_hPst[ 'A' ] := xq_CreateAdvPST( .T. )   // 红方仕
      s_hPst[ 'a' ] := xq_CreateAdvPST( .F. )   // 黑方士

      // 将/帅 PST
      s_hPst[ 'K' ] := xq_CreateKingPST( .T. )  // 红方帅
      s_hPst[ 'k' ] := xq_CreateKingPST( .F. )  // 黑方将

      // 将杀边界值
      s_nMateLower := s_hPiece[ 'K' ] - 10 * s_hPiece[ 'R' ]
      s_nMateUpper := s_hPiece[ 'K' ] + 10 * s_hPiece[ 'R' ]

      s_lXqPrgInit := .T.
   ENDIF

   RETURN { s_nMateLower, s_nMateUpper }
//--------------------------------------------------------------------------------

/*
 * 创建初始棋局
 */
function pos_CreateInitial()

   LOCAL l_cBoard := ""
   LOCAL l_aPos

   // 初始化 90 字符棋盘字符串
   // 黑方（上方）
   l_cBoard += "rnbakabnr"  // 行 0
   l_cBoard += "000000000"  // 行 1
   l_cBoard += "0c00000c0"  // 行 2 - 炮在第2列和第8列（0-based: 1和7）
   l_cBoard += "p0p0p0p0p"  // 行 3
   l_cBoard += "000000000"  // 行 4（河界上沿）
   l_cBoard += "000000000"  // 行 5（河界下沿）
   l_cBoard += "P0P0P0P0P"  // 行 6
   l_cBoard += "0C00000C0"  // 行 7 - 炮在第2列和第8列（0-based: 1和7）
   l_cBoard += "000000000"  // 行 8
   l_cBoard += "RNBAKABNR"  // 行 9

   // 创建位置结构
   // aPos[1]: 棋盘字符串
   // aPos[2]: 上一次移动
   // aPos[3]: 将/帅位置（红方）
   // aPos[4]: 将/帅位置（黑方）
   // aPos[5]: 前一步移动（用于检查重复）
   // aPos[10]: 当前回合（.T.=红方, .F.=黑方）

   l_aPos := Array( 10 )
   l_aPos[ 1 ] := l_cBoard
   l_aPos[ 2 ] := 0
   l_aPos[ 3 ] := xq_RCToArrayIdx( 10, 5 )  // 红方帅位置 (行10, 列5)
   l_aPos[ 4 ] := xq_RCToArrayIdx( 1, 5 )   // 黑方将位置 (行1, 列5)
   l_aPos[ 5 ] := ""
   l_aPos[ 10 ] := .T.  // 红方先行

   RETURN l_aPos
//--------------------------------------------------------------------------------

/*
 * 生成所有合法移动
 */
function pos_GenMoves( aPos )

   LOCAL l_cBoard := aPos[ 1 ]
   LOCAL l_lRedTurn := aPos[ 10 ]
   LOCAL l_i, l_j, l_p, l_d, l_q, l_aMoves := {}
   LOCAL l_nRow, l_nCol

   // 遍历棋盘
   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_p := SubStr( l_cBoard, l_i, 1 )

      // 跳过空位和对方棋子
      IF l_p == "0"
         LOOP
      ENDIF

      // 检查是否是当前回合的棋子
      IF l_lRedTurn .AND. ( l_p < 'A' .OR. l_p > 'Z' )
         LOOP
      ENDIF
      IF !l_lRedTurn .AND. ( l_p < 'a' .OR. l_p > 'z' )
         LOOP
      ENDIF

      // 转换为 11x12 数组索引
      l_j := xq_90To11Idx( l_i )

      // 生成该棋子的移动
      l_nRow := xq_ArrayIdxToRow( l_i )
      l_nCol := xq_ArrayIdxToCol( l_i )

      l_aMoves := xq_GenPieceMoves( aPos, l_p, l_nRow, l_nCol, l_aMoves )
   NEXT

   RETURN l_aMoves

/*
 * 生成单个棋子的所有合法移动
 */
static FUNCTION xq_GenPieceMoves( aPos, p, nRow, nCol, aMoves )

   LOCAL cBoard := aPos[ 1 ]
   LOCAL lRedTurn := aPos[ 10 ]
   LOCAL pUpper := Upper( p )
   LOCAL nToRow, nToCol, nIdx, nToIdx, cTarget
   LOCAL arrDirs, i, nDir, nLegRow, nLegCol, nEyeRow, nEyeCol

   // 计算原始位置索引
   nIdx := xq_RCToArrayIdx( nRow, nCol )

   // 获取移动方向
   IF pUpper == 'K'  // 将/帅
      arrDirs := s_hDirections[ 'K' ]
   ELSEIF pUpper == 'A'  // 士/仕
      arrDirs := s_hDirections[ 'A' ]
   ELSEIF pUpper == 'B'  // 相/象
      arrDirs := s_hDirections[ 'B' ]
   ELSEIF pUpper == 'N'  // 马
      arrDirs := s_hDirections[ 'N' ]
   ELSEIF pUpper == 'R'  // 车
      arrDirs := s_hDirections[ 'R' ]
   ELSEIF pUpper == 'C'  // 炮
      arrDirs := s_hDirections[ 'C' ]
   ELSEIF pUpper == 'P'  // 兵/卒
      arrDirs := s_hDirections[ 'P' ]
   ELSE
      RETURN aMoves
   ENDIF

   // 遍历每个方向
   FOR i := 1 TO Len( arrDirs )
      nDir := arrDirs[ i ]

      IF pUpper == 'N'  // 马：检查马腿
         // 马腿位置
         nLegRow := nRow + iif( nDir < -20, - 1, iif( nDir < -10, - 1, iif( nDir < 0, 1, iif( nDir < 10, 1, 1 ) ) ) )
         nLegCol := nCol + iif( nDir % 10 == -3, - 1, iif( nDir % 10 == -1, - 1, iif( nDir % 10 == 1, 1, 1 ) ) )

         // 检查马腿是否被阻挡
         IF !xq_CheckHorseLeg( cBoard, nRow, nCol, nRow + Int( nDir / 11 ), nCol + nDir % 11 )
            LOOP
         ENDIF

         nToRow := nRow + Int( nDir / 11 )
         nToCol := nCol + nDir % 11

      ELSEIF pUpper == 'B'  // 相/象：检查象眼
         // 象眼位置
         nEyeRow := nRow + Int( nDir / 22 )
         nEyeCol := nCol + Int( nDir % 22 )

         // 检查象眼是否被阻挡
         IF !xq_CheckElephantEye( cBoard, nRow, nCol, nEyeRow, nEyeCol )
            LOOP
         ENDIF

         nToRow := nRow + Int( nDir / 11 )
         nToCol := nCol + nDir % 11

      ELSEIF pUpper == 'C'  // 炮
         // 炮可以直线移动任意距离
         // 移动：中间不能有子
         // 吃子：中间必须恰好有一个子（炮架）
         nToRow := nRow
         nToCol := nCol
         DO WHILE .T.
            nToRow += Int( nDir / 11 )
            nToCol += nDir % 11

            // 检查边界
            IF nToRow < 0 .OR. nToRow >= XQ_BOARD_ROWS .OR. nToCol < 0 .OR. nToCol >= XQ_BOARD_COLS
               EXIT
            ENDIF

            nToIdx := xq_RCToArrayIdx( nToRow, nToCol )
            cTarget := SubStr( cBoard, nToIdx, 1 )

            IF cTarget == "0"
               // 空位，可以移动
               AAdd( aMoves, nIdx + nToIdx * 256 )
            ELSE
               // 有子，检查是否是炮架
               IF lRedTurn .AND. Upper(cTarget) != cTarget  // 红方回合，目标是小写（黑方），UTF8EX兼容
                  // 吃子，但需要炮架
                  // 继续查找炮架
                  DO WHILE .T.
                     nToRow += Int( nDir / 11 )
                     nToCol += nDir % 11

                     IF nToRow < 0 .OR. nToRow >= XQ_BOARD_ROWS .OR. nToCol < 0 .OR. nToCol >= XQ_BOARD_COLS
                        EXIT
                     ENDIF

                     nToIdx := xq_RCToArrayIdx( nToRow, nToCol )
                     cTarget := SubStr( cBoard, nToIdx, 1 )

                     IF cTarget == "0"
                        EXIT
                     ENDIF

                     IF lRedTurn .AND. Upper(cTarget) != cTarget  // 红方回合，目标是小写（黑方），UTF8EX兼容
                        // 找到炮架后的敌方棋子，可以吃
                        AAdd( aMoves, nIdx + nToIdx * 256 )
                     ENDIF
                     EXIT
                  ENDDO
               ENDIF
               EXIT
            ENDIF
         ENDDO
         LOOP

      ELSEIF pUpper == 'P'  // 兵/卒
         nToRow := nRow + Int( nDir / 11 )
         nToCol := nCol + nDir % 11

         // 兵/卒规则
         IF lRedTurn  // 红方兵
            // 未过河（行 > 4）：只能向前
            IF nRow > XQ_RIVER_BOTTOM .AND. nDir != -11
               LOOP
            ENDIF
            // 过河后（行 <= 4）：可以向前或横走
            IF nRow <= XQ_RIVER_BOTTOM .AND. nDir == 11
               LOOP
            ENDIF
         ELSE  // 黑方卒
            // 未过河（行 < 5）：只能向前
            IF nRow < XQ_RIVER_TOP .AND. nDir != 11
               LOOP
            ENDIF
            // 过河后（行 >= 5）：可以向前或横走
            IF nRow >= XQ_RIVER_TOP .AND. nDir == -11
               LOOP
            ENDIF
         ENDIF

      ELSE
         // 其他棋子：一步移动
         nToRow := nRow + Int( nDir / 11 )
         nToCol := nCol + nDir % 11
      ENDIF

      // 检查边界
      IF nToRow < 0 .OR. nToRow >= XQ_BOARD_ROWS .OR. nToCol < 0 .OR. nToCol >= XQ_BOARD_COLS
         LOOP
      ENDIF

      nToIdx := xq_RCToArrayIdx( nToRow, nToCol )
      cTarget := SubStr( cBoard, nToIdx, 1 )

      // 检查是否是己方棋子
      IF cTarget != "0"
         IF lRedTurn .AND. Upper(cTarget) == cTarget  // 红方回合，目标是大写（红方），UTF8EX兼容
            LOOP
         ENDIF
         IF !lRedTurn .AND. Upper(cTarget) != cTarget  // 黑方回合，目标是小写（黑方），UTF8EX兼容
            LOOP
         ENDIF
      ENDIF

      // 检查宫殿规则（将/帅、士/仕）
      IF pUpper == 'K' .OR. pUpper == 'A'
         IF lRedTurn .AND. !xq_IsInRedPalace( nToRow, nToCol )
            LOOP
         ENDIF
         IF !lRedTurn .AND. !xq_IsInBlackPalace( nToRow, nToCol )
            LOOP
         ENDIF
      ENDIF

      // 检查河界规则（相/象）
      IF pUpper == 'B'
         IF lRedTurn .AND. nToRow < XQ_RIVER_BOTTOM
            LOOP
         ENDIF
         IF !lRedTurn .AND. nToRow > XQ_RIVER_TOP
            LOOP
         ENDIF
      ENDIF

      // 添加移动
      AAdd( aMoves, nIdx + nToIdx * 256 )
   NEXT

   RETURN aMoves

/*
 * 检查马腿
 */
static FUNCTION xq_CheckHorseLeg( cBoard, nFromRow, nFromCol, nToRow, nToCol )

   LOCAL nLegRow, nLegCol

   // 马腿位置
   nLegRow := Int( ( nFromRow + nToRow ) / 2 )
   nLegCol := Int( ( nFromCol + nToCol ) / 2 )

   // 检查马腿是否为空

   RETURN SubStr( cBoard, xq_RCToArrayIdx( nLegRow, nLegCol ), 1 ) == "0"

/*
 * 检查象眼
 */
static FUNCTION xq_CheckElephantEye( cBoard, nFromRow, nFromCol, nToRow, nToCol )

   LOCAL nEyeRow, nEyeCol

   // 象眼位置
   nEyeRow := Int( ( nFromRow + nToRow ) / 2 )
   nEyeCol := Int( ( nFromCol + nToCol ) / 2 )

   // 检查象眼是否为空

   RETURN SubStr( cBoard, xq_RCToArrayIdx( nEyeRow, nEyeCol ), 1 ) == "0"

/*
 * 旋转棋盘（交换红黑方）
 */
function pos_Rotate( aPos )

   LOCAL l_cBoard := aPos[ 1 ]
   LOCAL l_cNewBoard := ""
   LOCAL l_i, l_c

   // 翻转棋盘（UTF8EX兼容）
   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_c := SubStr( l_cBoard, l_i, 1 )
      IF Upper(l_c) == l_c  // 大写
         l_cNewBoard += Lower( l_c )
      ELSEIF Lower(l_c) == l_c  // 小写
         l_cNewBoard += Upper( l_c )
      ELSE
         l_cNewBoard += l_c
      ENDIF
   NEXT

   // 反转字符串
   l_cNewBoard := StrReverse( l_cNewBoard )

   RETURN { l_cNewBoard, aPos[ 2 ], aPos[ 4 ], aPos[ 3 ], aPos[ 5 ], !aPos[ 10 ] }
//--------------------------------------------------------------------------------

/*
 * 执行移动，返回新位置
 */
function pos_Move( aPos, par_nMove )

   LOCAL l_nFrom := hb_bitAnd( par_nMove, 0xff )
   LOCAL l_nTo := hb_bitAnd( hb_bitShift( par_nMove, - 8 ), 0xff )
   LOCAL l_cBoard := aPos[ 1 ]
   LOCAL l_cPiece := SubStr( l_cBoard, l_nFrom, 1 )
   LOCAL l_cNewBoard := l_cBoard
   LOCAL l_aNewPos, l_nKingPos

   // 执行移动
   l_cNewBoard := Stuff( l_cNewBoard, l_nFrom, 1, "0" )
   l_cNewBoard := Stuff( l_cNewBoard, l_nTo, 1, l_cPiece )

   // 更新将/帅位置
   IF Upper( l_cPiece ) == 'K'
      IF Upper(l_cPiece) == l_cPiece  // 大写（红方）
         l_nKingPos := l_nTo
      ELSE  // 小写（黑方）
         l_nKingPos := aPos[ 3 ]
      ENDIF
   ELSE
      l_nKingPos := aPos[ 3 ]
   ENDIF

   // 创建新位置
   l_aNewPos := Array( 10 )
   l_aNewPos[ 1 ] := l_cNewBoard
   l_aNewPos[ 2 ] := par_nMove
   l_aNewPos[ 3 ] := l_nKingPos
   l_aNewPos[ 4 ] := aPos[ 4 ]
   l_aNewPos[ 5 ] := l_cBoard
   l_aNewPos[ 10 ] := !aPos[ 10 ]

   // 旋转棋盘，准备下一回合

   RETURN pos_Rotate( l_aNewPos )
//--------------------------------------------------------------------------------

/*
 * PST 创建函数（简化版）
 */
static FUNCTION xq_CreatePawnPST( par_lRed )

   LOCAL l_arr := Array( XQ_BOARD_SIZE )
   LOCAL l_i, l_nRow, l_nCol, l_nVal

   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_nRow := Int( ( l_i - 1 ) / XQ_BOARD_COLS )
      l_nCol := ( l_i - 1 ) % XQ_BOARD_COLS

      l_nVal := XQ_VALUE_PAWN

      // 过河加分
      IF par_lRed .AND. l_nRow <= XQ_RIVER_BOTTOM
         l_nVal += 10
      ENDIF
      IF !par_lRed .AND. l_nRow >= XQ_RIVER_TOP
         l_nVal += 10
      ENDIF

      // 中路加分
      IF l_nCol >= 3 .AND. l_nCol <= 5
         l_nVal += 5
      ENDIF

      l_arr[ l_i ] := l_nVal
   NEXT

   RETURN l_arr

static FUNCTION xq_CreateHorsePST( par_lRed )

   LOCAL l_arr := Array( XQ_BOARD_SIZE )
   LOCAL l_i, l_nRow, l_nCol

   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_nRow := Int( ( l_i - 1 ) / XQ_BOARD_COLS )
      l_nCol := ( l_i - 1 ) % XQ_BOARD_COLS

      // 中路加分
      l_arr[ l_i ] := XQ_VALUE_HORSE + iif( l_nCol >= 3 .AND. l_nCol <= 5, 5, 0 )
   NEXT

   RETURN l_arr

static FUNCTION xq_CreateRookPST( par_lRed )

   LOCAL l_arr := Array( XQ_BOARD_SIZE )
   LOCAL l_i

   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_arr[ l_i ] := XQ_VALUE_ROOK
   NEXT

   RETURN l_arr

static FUNCTION xq_CreateCannonPST( par_lRed )

   LOCAL l_arr := Array( XQ_BOARD_SIZE )
   LOCAL l_i

   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_arr[ l_i ] := XQ_VALUE_CANNON
   NEXT

   RETURN l_arr

static FUNCTION xq_CreateElephPST( par_lRed )

   LOCAL l_arr := Array( XQ_BOARD_SIZE )
   LOCAL l_i

   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_arr[ l_i ] := XQ_VALUE_ELEPH
   NEXT

   RETURN l_arr

static FUNCTION xq_CreateAdvPST( par_lRed )

   LOCAL l_arr := Array( XQ_BOARD_SIZE )
   LOCAL l_i

   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_arr[ l_i ] := XQ_VALUE_ADV
   NEXT

   RETURN l_arr

static FUNCTION xq_CreateKingPST( par_lRed )

   LOCAL l_arr := Array( XQ_BOARD_SIZE )
   LOCAL l_i

   FOR l_i := 1 TO XQ_BOARD_SIZE
      l_arr[ l_i ] := XQ_VALUE_KING
   NEXT

   RETURN l_arr

/*
 * 辅助函数
 */
static FUNCTION xq_90To11Idx( par_nIdx )

   LOCAL l_nRow := xq_ArrayIdxToRow( par_nIdx )
   LOCAL l_nCol := xq_ArrayIdxToCol( par_nIdx )

   RETURN xq_RCToArrayIdx( l_nRow, l_nCol )

static FUNCTION xq_ArrayIdxToRow( par_nIdx )
   RETURN Int( ( par_nIdx - 1 ) / XQ_BOARD_COLS ) + 1

static FUNCTION xq_ArrayIdxToCol( par_nIdx )
   RETURN ( par_nIdx - 1 ) % XQ_BOARD_COLS + 1

static FUNCTION StrReverse( par_cStr )

   LOCAL l_cResult := ""
   LOCAL l_i

   FOR l_i := Len( par_cStr ) TO 1 STEP -1
      l_cResult += SubStr( par_cStr, l_i, 1 )
   NEXT

   RETURN l_cResult

//--------------------------------------------------------------------------------
// 全局配置管理函数
// 用于替代 PUBLIC 变量，提供统一的配置访问接口
//--------------------------------------------------------------------------------

/**
 * 初始化全局配置
 * 在程序启动时调用，初始化所有配置项的默认值
 */
function InitGlobalConfig()

   // AI1 配置（红方AI）
   s_hGlobalConfig["AI1Enabled"] := .T.
   s_hGlobalConfig["AI1EngineType"] := "UCCI"
   s_hGlobalConfig["AI1EnginePath"] := hb_DirBase() + "engines/eleeye/eleeye"
   s_hGlobalConfig["AI1ThinkTime"] := 5000

   // AI2 配置（黑方AI）
   s_hGlobalConfig["AI2Enabled"] := .F.
   s_hGlobalConfig["AI2EngineType"] := "UCI"
   s_hGlobalConfig["AI2EnginePath"] := hb_DirBase() + "engines/pikafish/pikafish"
   s_hGlobalConfig["AI2ThinkTime"] := 3000

   // UCCI 引擎状态（用于替代 PUBLIC 变量）
   s_hGlobalConfig["AI1Initialized"] := .F.
   s_hGlobalConfig["AI2Initialized"] := .F.
   s_hGlobalConfig["UcciEngineInitialized"] := .F.

return NIL
//--------------------------------------------------------------------------------

/**
 * 获取全局配置哈希表引用
 * 返回 s_hGlobalConfig 的引用，所有调用者共享同一个哈希表
 * 通过返回的引用修改配置会影响全局配置（验证通过test_hash_ref.prg）
 */
function GetGlobalConfig()
return s_hGlobalConfig
//--------------------------------------------------------------------------------
