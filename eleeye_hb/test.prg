/*
 * test.prg - 模拟对弈程序调用 ElephantEye 引擎
 */

#include "hb.ch"

// 对弈配置
#define MAX_MOVES 20        // 最多走20步
#define SEARCH_DEPTH 3      // 搜索深度
#define START_FEN "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

FUNCTION Main()
   LOCAL nResult
   LOCAL cMove
   LOCAL cMoveList := ""
   LOCAL nMoveNum := 0
   LOCAL lRedTurn := .T.
   LOCAL cResult

   hb_cdpSelect("UTF8")
   OutErr( "" + hb_eol() )
   OutErr( "========================================" + hb_eol() )
   OutErr( "      象棋对弈模拟程序" + hb_eol() )
   OutErr( "========================================" + hb_eol() )
   OutErr( "" + hb_eol() )

   // 初始化引擎
   OutErr( "正在初始化引擎..." + hb_eol() )
   nResult := ELEngine_InitString()
   IF nResult != 1
      OutErr( "引擎初始化失败！" + hb_eol() )
      ELEngine_CleanupString()
      RETURN NIL
   ENDIF
   OutErr( "引擎初始化成功" + hb_eol() )
   OutErr( "" + hb_eol() )

   // 设置初始位置
   OutErr( "设置初始棋局..." + hb_eol() )
   cResult := ELEngine_ProcessString( "position startpos" + hb_eol() )
   IF cResult != "position ok"
      OutErr( "设置初始位置失败！" + hb_eol() )
      ELEngine_CleanupString()
      RETURN NIL
   ENDIF
   OutErr( "初始棋局设置完成" + hb_eol() )
   OutErr( "" + hb_eol() )

   // 开始对弈循环
   OutErr( "========================================" + hb_eol() )
   OutErr( "开始对弈 (红方先手)" + hb_eol() )
   OutErr( "========================================" + hb_eol() )
   OutErr( "" + hb_eol() )

   DO WHILE nMoveNum < MAX_MOVES
      nMoveNum++

      // 显示当前回合信息
      IF lRedTurn
         OutErr( "回合 " + hb_ntos( nMoveNum ) + " - 红方思考中..." + hb_eol() )
      ELSE
         OutErr( "回合 " + hb_ntos( nMoveNum ) + " - 黑方思考中..." + hb_eol() )
      ENDIF

      // 请求最佳走法
      cMove := ELEngine_ProcessString( "go depth " + hb_ntos( SEARCH_DEPTH ) + hb_eol() )

      // 检查走法有效性
      IF cMove == "nobestmove"
         OutErr( "  -> 无合法走法，对弈结束" + hb_eol() )
         EXIT
      ELSEIF cMove == "error"
         OutErr( "  -> 引擎错误，对弈结束" + hb_eol() )
         EXIT
      ENDIF

      // 显示走法
      OutErr( "  -> 走法: " + cMove + hb_eol() )

      // 更新走法列表
      IF Empty( cMoveList )
         cMoveList := cMove
      ELSE
         cMoveList += " " + cMove
      ENDIF

      // 更新位置
      cResult := ELEngine_ProcessString( "position startpos moves " + cMoveList + hb_eol() )
      IF cResult != "position ok"
         OutErr( "  -> 位置更新失败！" + hb_eol() )
         EXIT
      ENDIF

      // 切换回合
      lRedTurn := !lRedTurn
      OutErr( "" + hb_eol() )
   ENDDO

   // 对弈结束
   OutErr( "========================================" + hb_eol() )
   OutErr( "对弈结束" + hb_eol() )
   OutErr( "========================================" + hb_eol() )
   OutErr( "总回合数: " + hb_ntos( nMoveNum ) + hb_eol() )
   OutErr( "" + hb_eol() )

   // 显示走法记录
   OutErr( "走法记录:" + hb_eol() )
   IF !Empty( cMoveList )
      OutErr( cMoveList + hb_eol() )
   ELSE
      OutErr( "(无)" + hb_eol() )
   ENDIF
   OutErr( "" + hb_eol() )

   // 清理引擎
   OutErr( "正在清理引擎..." + hb_eol() )
   ELEngine_CleanupString()
   OutErr( "引擎已清理" + hb_eol() )
   OutErr( "" + hb_eol() )
   OutErr( "对弈模拟完成！" + hb_eol() )
   OutErr( "" + hb_eol() )

RETURN NIL
