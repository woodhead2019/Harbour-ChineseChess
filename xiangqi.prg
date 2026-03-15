/*
 * 中国象棋控制台版本
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 */

#include "xq_xiangqi.ch"
REQUEST HB_CODEPAGE_UTF8EX

// 初始化国际化系统
init procedure InitI18N()
   xq_I18NInit()
return

// 获取棋子名称（中文字符）
//
// 参数:
//   par_cPiece - 棋子代码 (如 "r", "n", "b" 等)
// 返回: l_cName - 棋子中文名称
//--------------------------------------------------------------------------------

static function GetPieceName( par_cPiece )

   local l_cName

   do case
   case par_cPiece == "r" ; l_cName := "車"
   case par_cPiece == "n" ; l_cName := "馬"
   case par_cPiece == "b" ; l_cName := "象"
   case par_cPiece == "a" ; l_cName := "士"
   case par_cPiece == "k" ; l_cName := "將"
   case par_cPiece == "c" ; l_cName := "砲"
   case par_cPiece == "p" ; l_cName := "卒"
   case par_cPiece == "R" ; l_cName := "車"
   case par_cPiece == "N" ; l_cName := "馬"
   case par_cPiece == "B" ; l_cName := "相"
   case par_cPiece == "A" ; l_cName := "仕"
   case par_cPiece == "K" ; l_cName := "帥"
   case par_cPiece == "C" ; l_cName := "炮"
   case par_cPiece == "P" ; l_cName := "兵"
   otherwise            ; l_cName := "＋"
   endcase

   return l_cName

// 将 FEN 格式转换为 ASCII 棋盘布局
//
// 参数:
//   par_cFen - FEN 格式的局面字符串
// 返回: l_cBoard - ASCII 棋盘布局字符串
//--------------------------------------------------------------------------------

static function xq_FenToAscii( par_cFen )

   local l_cBoard := ""
   local l_cFenBoard, l_cTurn
   local l_cParts, l_i, l_j, l_k, l_cChar, l_n
   local l_aBoard := Array( 10, 9 )
   local l_cRow, l_cPiece
   local l_cLine, l_nEmpty

   // 解析 FEN
   l_cParts := hb_ATokens( par_cFen, " " )
   l_cFenBoard := l_cParts[ 1 ]
   if Len( l_cParts ) > 1
      l_cTurn := l_cParts[ 2 ]
   endif

   // 将 FEN 转换为棋盘数组
   l_cParts := hb_ATokens( l_cFenBoard, "/" )
   for l_i := 1 to 10
      l_cRow := l_cParts[ l_i ]
      l_k := 1
      l_j := 1
      do while l_k <= Len( l_cRow ) .AND. l_j <= 9
         l_cChar := SubStr( l_cRow, l_k, 1 )
         if l_cChar >= "0" .AND. l_cChar <= "9"
            // 数字表示空位，跳过相应数量的列
            l_nEmpty := Val( l_cChar )
            for l_n := 1 to l_nEmpty
               if l_j <= 9
                  l_aBoard[ l_i, l_j ] := "0"
                  l_j++
               endif
            next
            l_k++
         else
            // 棋子
            if l_j <= 9
               l_aBoard[ l_i, l_j ] := l_cChar
               l_j++
            endif
            l_k++
         endif
      enddo
      // 填充剩余的空位
      do while l_j <= 9
         l_aBoard[ l_i, l_j ] := "0"
         l_j++
      enddo
   next

   // 生成 19 行 ASCII 棋盘
   // 第1行：黑方底线（将车马象士）
   l_cLine := ""
   for l_j := 1 to 9
      l_cPiece := l_aBoard[ 1, l_j ]
      if l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      else
         l_cLine += "＋"
      endif
      if l_j < 9
         l_cLine += "－"
      endif
   next
   l_cBoard += l_cLine + Chr( 10 )

   // 第2行：斜线（黑方九宫格）
   l_cBoard += "｜　｜　｜　｜＼｜／｜　｜　｜　｜" + Chr( 10 )

   // 第3行：分隔线
   l_cBoard += "＋－＋－＋－＋－＋－＋－＋－＋－＋" + Chr( 10 )

   // 第4行：斜线（黑方九宫格）
   l_cBoard += "｜　｜　｜　｜／｜＼｜　｜　｜　｜" + Chr( 10 )

   // 第5行：黑方炮线
   l_cLine := ""
   for l_j := 1 to 9
      l_cPiece := l_aBoard[ 3, l_j ]
      if l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      else
         l_cLine += "＋"
      endif
      if l_j < 9
         l_cLine += "－"
      endif
   next
   l_cBoard += l_cLine + Chr( 10 )

   // 第6行：空行
   l_cBoard += "｜　｜　｜　｜　｜　｜　｜　｜　｜" + Chr( 10 )

   // 第7行：黑方卒线
   l_cLine := ""
   for l_j := 1 to 9
      l_cPiece := l_aBoard[ 4, l_j ]
      if l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      else
         l_cLine += "＋"
      endif
      if l_j < 9
         l_cLine += "－"
      endif
   next
   l_cBoard += l_cLine + Chr( 10 )

   // 第8行：空行
   l_cBoard += "｜　｜　｜　｜　｜　｜　｜　｜　｜" + Chr( 10 )

   // 第9行：分隔线
   l_cBoard += "＋－＋－＋－＋－＋－＋－＋－＋－＋" + Chr( 10 )

   // 第10行：楚河汉界
   l_cBoard += "｜　　　　　　楚河汉界　　　　　｜" + Chr( 10 )

   // 第11行：分隔线
   l_cBoard += "＋－＋－＋－＋－＋－＋－＋－＋－＋" + Chr( 10 )

   // 第12行：空行
   l_cBoard += "｜　｜　｜　｜　｜　｜　｜　｜　｜" + Chr( 10 )

   // 第13行：红方兵线
   l_cLine := ""
   for l_j := 1 to 9
      l_cPiece := l_aBoard[ 7, l_j ]
      if l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      else
         l_cLine += "＋"
      endif
      if l_j < 9
         l_cLine += "－"
      endif
   next
   l_cBoard += l_cLine + Chr( 10 )

   // 第14行：空行
   l_cBoard += "｜　｜　｜　｜　｜　｜　｜　｜　｜" + Chr( 10 )

   // 第15行：红方炮线
   l_cLine := ""
   for l_j := 1 to 9
      l_cPiece := l_aBoard[ 8, l_j ]
      if l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      else
         l_cLine += "＋"
      endif
      if l_j < 9
         l_cLine += "－"
      endif
   next
   l_cBoard += l_cLine + Chr( 10 )

   // 第16行：斜线（红方九宫格）
   l_cBoard += "｜　｜　｜　｜＼｜／｜　｜　｜　｜" + Chr( 10 )

   // 第17行：分隔线
   l_cBoard += "＋－＋－＋－＋－＋－＋－＋－＋－＋" + Chr( 10 )

   // 第18行：斜线（红方九宫格）
   l_cBoard += "｜　｜　｜　｜／｜＼｜　｜　｜　｜" + Chr( 10 )

   // 第19行：红方底线（帅车马相仕）
   l_cLine := ""
   for l_j := 1 to 9
      l_cPiece := l_aBoard[ 10, l_j ]
      if l_cPiece != "0"
         l_cLine += GetPieceName( l_cPiece )
      else
         l_cLine += "＋"
      endif
      if l_j < 9
         l_cLine += "－"
      endif
   next
   l_cBoard += l_cLine + Chr( 10 )

   return l_cBoard

// 显示帮助信息
//--------------------------------------------------------------------------------

static function ShowHelp()



   ? Replicate( "=", 60 )

   ? _XQ_I__( "app.console.title" )

   ?

   ? _XQ_I__( "console.move_format" )

   ? _XQ_I__( "console.from_row" )

   ? _XQ_I__( "console.from_col" )

   ? _XQ_I__( "console.to_row" )

   ? _XQ_I__( "console.to_col" )

   ?

   ? _XQ_I__( "console.example_moves" )

   ? _XQ_I__( "console.example1" )

   ? _XQ_I__( "console.example2" )

   ? _XQ_I__( "console.example3" )

   ?

   ? _XQ_I__( "console.other_commands" )

   ? _XQ_I__( "console.cmd_help" )

   ? _XQ_I__( "console.cmd_list" )

   ? _XQ_I__( "console.cmd_new" )

   ? _XQ_I__( "console.cmd_quit" )

   ?

   ? _XQ_I__( "console.coord_system" )

   ? _XQ_I__( "console.row_desc" )

   ? _XQ_I__( "console.col_desc" )

   ?

   ? _XQ_I__( "console.rules_title" )

   ? _XQ_I__( "console.rule1" )

   ? _XQ_I__( "console.rule2" )

   ? _XQ_I__( "console.rule3" )

   ? _XQ_I__( "console.rule4" )

   ? _XQ_I__( "console.rule5" )

   ? _XQ_I__( "console.rule6" )

   ? _XQ_I__( "console.rule7" )

   ?

   ? Replicate( "=", 60 )

   ?

   return nil

// 显示合法移动列表
//--------------------------------------------------------------------------------

static function ShowLegalMoves( par_aPos )

   local l_aMoves, l_i, l_nMove, l_nFrom, l_nTo, l_nFromRow, l_nFromCol, l_nToRow, l_nToCol
   local l_cPiece, l_aBoard, l_cFen

   l_aMoves := pos_GenMoves( par_aPos )

   if Len( l_aMoves ) == 0
      ? _XQ_I__( "console.no_legal_moves" )
      return nil
   endif

   ? _XQ_I__( "console.legal_moves_header" )
   ? Replicate( "-", 50 )

   for l_i := 1 to Min( 20, Len( l_aMoves ) )
      l_nMove := l_aMoves[ l_i ]
      l_nFrom := hb_bitAnd( l_nMove, 0xff )
      l_nTo := hb_bitAnd( hb_bitShift( l_nMove, - 8 ), 0xff )

      l_nFromRow := Int( l_nFrom / 9 ) + 1
      l_nFromCol := ( l_nFrom % 9 ) + 1
      l_nToRow := Int( l_nTo / 9 ) + 1
      l_nToCol := ( l_nTo % 9 ) + 1

      l_aBoard := xq_StringToArray( par_aPos[ POS_BOARD ] )
      l_cFen := xq_BoardToFen( l_aBoard, par_aPos[ POS_TURN ] )
      l_cPiece := SubStr( par_aPos[ POS_BOARD ], l_nFrom + 1, 1 )

      ? Str( l_i, 3 ) + ": " + GetPieceName( l_cPiece ) + ;
         " (" + Str( l_nFromRow ) + "," + Str( l_nFromCol ) + ") -> " + ;
         " (" + Str( l_nToRow ) + "," + Str( l_nToCol ) + ")"
   next

   if Len( l_aMoves ) > 20
      ? xq_Translate( "console.more_moves", { Str( Len( l_aMoves ) - 20 ) } )
   endif

   ? xq_Translate( "console.total_moves", { Str( Len( l_aMoves ) ) } )
   ?

   return nil

// 主程序入口
//--------------------------------------------------------------------------------

procedure Main()

   local l_aMateBounds, l_aPos, l_aMoves, l_i, l_nMove
   local l_cInput, l_nFromRow, l_nFromCol, l_nToRow, l_nToCol
   local l_nFromIdx, l_nToIdx, l_nMoveCode, l_lValid
   local l_aBoard, l_cFen, l_cAscii
   local l_lRunning := .T.
   local l_nMoveCount := 0
   local l_cPiece, l_lIsRed
   local l_nShowCount, l_nFrom, l_nTo, l_nFoundMove

   // 设置 UTF8EX 代码页（支持欧洲语言大小写转换）
   hb_cdpSelect( "UTF8EX" )

   // 初始化引擎
   l_aMateBounds := pos_Init()

   // 初始化工具函数
   xq_Init()

   // 创建初始棋局
   l_aPos := pos_CreateInitial()

   // 转换为棋盘数组
   l_aBoard := xq_StringToArray( l_aPos[ POS_BOARD ] )

   ? Replicate( "=", 60 )
   ? _XQ_I__( "app.console.title" )
   ? Replicate( "=", 60 )
   ?
   ? _XQ_I__( "console.welcome" )
   ?
   ? _XQ_I__( "console.input_format" )
   ? _XQ_I__( "console.input_example" )
   ?
   ? _XQ_I__( "console.other_commands" )
   ? "  h or help - " + _XQ_I__( "console.cmd_help" )
   ? "  l or list - " + _XQ_I__( "console.cmd_list" )
   ? "  n or new  - " + _XQ_I__( "console.cmd_new" )
   ? "  q or quit - " + _XQ_I__( "console.cmd_quit" )
   ?

   do while l_lRunning

      ? Replicate( "=", 60 )

      ? _XQ_I__( "app.console.title" )

      ? Replicate( "=", 60 )
      ?

      // 构建 FEN 格式
      l_cFen := xq_BoardToFen( l_aBoard, l_aPos[ POS_TURN ] )
      ? "FEN:", l_cFen
      ?

      // 显示 ASCII 棋盘
      l_cAscii := xq_FenToAscii( l_cFen )
      ? l_cAscii
      ?

      // 显示当前回合和移动计数
      ? _XQ_I__( "console.current_turn" ), iif( l_aPos[ POS_TURN ], _XQ_I__( "console.turn_red" ), _XQ_I__( "console.turn_black" ) )
      ? _XQ_I__( "console.move_count" ), l_nMoveCount
      ?

      // 显示合法移动数量
      l_aMoves := pos_GenMoves( l_aPos )
      ? _XQ_I__( "console.legal_move_count" ), Len( l_aMoves )
      ?

      // 显示所有当前回合棋子的合法移动
      l_nFoundMove := 0
      for l_i := 1 to Len( l_aMoves )
         l_nMove := l_aMoves[ l_i ]
         l_nFrom := hb_bitAnd( l_nMove, 0xff )

         // 只显示当前回合棋子的移动
         l_cPiece := SubStr( l_aPos[ POS_BOARD ], l_nFrom + 1, 1 )
         l_lIsRed := ( Upper(l_cPiece) == l_cPiece )  // 使用Upper()判断大小写（UTF8EX兼容）

         if l_lIsRed == l_aPos[ POS_TURN ]
            l_nTo := hb_bitAnd( hb_bitShift( l_nMove, - 8 ), 0xff )
            l_nFromRow := Int( Int( l_nFrom / 9 ) + 1 )
            l_nFromCol := Int( ( l_nFrom % 9 ) + 1 )
            l_nToRow := Int( Int( l_nTo / 9 ) + 1 )
            l_nToCol := Int( ( l_nTo % 9 ) + 1 )
            ? "  " + GetPieceName( l_cPiece ) + " (" + Str( l_nFromRow, 2, 0 ) + "," + Str( l_nFromCol, 2, 0 ) + ") -> (" + Str( l_nToRow, 2, 0 ) + "," + Str( l_nToCol, 2, 0 ) + ")"
            l_nFoundMove++
         endif
      next

      if l_nFoundMove == 0
         ? _XQ_I__( "console.no_moves_found" )
      endif
      ?

      // 获取用户输入
      ? _XQ_I__( "console.prompt" )
      l_cInput := ""

      // 直接使用 ACCEPT 读取一行（需要交互式终端）
      ACCEPT l_cInput TO l_cInput
      l_cInput := AllTrim( Lower( l_cInput ) )

      // 处理命令
      if l_cInput == "q" .OR. l_cInput == "quit"
         l_lRunning := .F.
         loop
      elseif l_cInput == ""
         // 空输入，继续游戏
         loop
      elseif l_cInput == "h" .OR. l_cInput == "help"
         ShowHelp()
         loop
      elseif l_cInput == "l" .OR. l_cInput == "list"
         ShowLegalMoves( l_aPos )
         loop
      elseif l_cInput == "n" .OR. l_cInput == "new"
         l_aPos := pos_CreateInitial()
         l_aBoard := xq_StringToArray( l_aPos[ POS_BOARD ] )
         l_nMoveCount := 0
         ? "New Game Started!"
         loop
      endif

      // 解析移动输入
      if Len( hb_ATokens( l_cInput, " " ) ) == 4
         l_nFromRow := Val( hb_ATokens( l_cInput, " " )[ 1 ] )
         l_nFromCol := Val( hb_ATokens( l_cInput, " " )[ 2 ] )
         l_nToRow := Val( hb_ATokens( l_cInput, " " )[ 3 ] )
         l_nToCol := Val( hb_ATokens( l_cInput, " " )[ 4 ] )

         // 检查坐标范围
         if l_nFromRow < 1 .OR. l_nFromRow > 10 .OR. l_nFromCol < 1 .OR. l_nFromCol > 9 .OR. ;
               l_nToRow < 1 .OR. l_nToRow > 10 .OR. l_nToCol < 1 .OR. l_nToCol > 9
            ? _XQ_I__( "error.coord_out_of_range" )
            ?
            loop
         endif

         // 检查起始位置是否有棋子
         l_nFromIdx := ( l_nFromRow - 1 ) * 9 + ( l_nFromCol - 1 )
         l_cPiece := SubStr( l_aPos[ POS_BOARD ], l_nFromIdx + 1, 1 )
         if l_cPiece == "0"
            ? _XQ_I__( "error.no_piece_at_start" )
            ?
            loop
         endif

         // 检查是否是正确的回合
         l_lIsRed := ( Upper(l_cPiece) == l_cPiece )  // 使用Upper()判断大小写（UTF8EX兼容）
         if l_lIsRed != l_aPos[ POS_TURN ]
            ? _XQ_I__( "error.not_own_piece" )
            ?
            loop
         endif

         // 转换为数组索引 (0-based: 0-89)
         l_nToIdx := ( l_nToRow - 1 ) * 9 + ( l_nToCol - 1 )

         // 构建移动编码
         l_nMoveCode := l_nFromIdx + l_nToIdx * 256

         // 验证移动
         l_lValid := xq_IsMoveCorrect( l_aPos, l_nMoveCode )

         if l_lValid
            // 执行移动
            l_aPos := pos_Move( l_aPos, l_nMoveCode )
            // 更新棋盘数组
            l_aBoard := xq_StringToArray( l_aPos[ POS_BOARD ] )
            l_nMoveCount++
            ? xq_Translate( "console.move_success", { GetPieceName( l_cPiece ), Str( l_nFromRow ), Str( l_nFromCol ), Str( l_nToRow ), Str( l_nToCol ) } )
            ?
         else
            ? _XQ_I__( "error.invalid_move" )
            ?
         endif
      else
         ? _XQ_I__( "error.input_format_wrong" )
         ? _XQ_I__( "error.format" )
         ? _XQ_I__( "error.example" )
         ? _XQ_I__( "error.help_hint" )
         ?
      endif
   enddo

   ? Replicate( "=", 60 )

   ? _XQ_I__( "console.game_over" )

   ? Replicate( "=", 60 )
   ?
   ? _XQ_I__( "console.total_moves_summary" ), l_nMoveCount
   ?
   ? _XQ_I__( "console.goodbye" )
   ?

   return

//--------------------------------------------------------------------------------
