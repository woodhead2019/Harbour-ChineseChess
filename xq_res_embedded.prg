/*
 * 中国象棋棋子资源定义
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 使用 Harbour e"..." 转义字符串语法（编译时转换）
 */

#include "hwgui.ch"

REQUEST HB_HASH
REQUEST HB_HGETDEF
REQUEST HB_HHASKEY
REQUEST HB_HKEYS

STATIC s_aResourceBitmaps  // 缓存位图对象（哈希表）

//--------------------------------------------------------------------------------
// 获取棋子资源数组
// 返回格式: { {名称, 类型, 二进制数据}, ... }
//--------------------------------------------------------------------------------

FUNCTION xq_GetChessResources()
   RETURN xq_GetEmbeddedResources()

//--------------------------------------------------------------------------------
// 初始化资源到 HwGUI 系统
//--------------------------------------------------------------------------------

FUNCTION xq_InitResources()

   LOCAL aResources := xq_GetChessResources()
   LOCAL l_i, l_cName, l_cType, l_cData, l_hBitmap, l_aSize
   LOCAL l_hImage, l_aResource

   // 初始化位图缓存哈希表（只在未初始化时初始化）
   IF Empty( s_aResourceBitmaps )
      s_aResourceBitmaps := hb_Hash()
      // 第一次加载资源
      FOR l_i := 1 TO Len( aResources )
         // 提取资源信息
         l_aResource := aResources[ l_i ]
l_cName := l_aResource[ 1 ]
         l_cType := l_aResource[ 2 ]
         l_cData := l_aResource[ 3 ]

         // 统一使用 hwg_OpenImage 加载所有资源
         l_hBitmap := hwg_OpenImage( l_cData, .T. )
         IF !Empty( l_hBitmap )
            // 获取 pixbuf 尺寸
            l_aSize := hwg_GetBitmapSize( l_hBitmap )
            s_aResourceBitmaps[ l_cName ] := { l_hBitmap, l_aSize[1], l_aSize[2] }
         ELSE
            OutErr( "WARNING: Failed to load " + Upper(l_cType) + " resource '" + l_cName + "'", hb_eol() )
         ENDIF
      NEXT
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------
// 获取棋子位图信息
//
// 参数: par_cPieceName - 资源名称（如 "rc", "bb"）
// 返回: {句柄, 宽度, 高度} 或 NIL
//--------------------------------------------------------------------------------

FUNCTION xq_GetChessBitmap( par_cPieceName )

   LOCAL l_cName := Lower( AllTrim( par_cPieceName ) )
   LOCAL l_cColor := Left( AllTrim( par_cPieceName ), 1 )
   LOCAL l_aResult
   
   // FEN 代码到资源名称的映射
   // 黑方: a→ba, b→bb, c→bc, k→bk, n→bn, p→bp, r→br
   // 红方: A→ra, B→rb, C→rc, K→rk, N→rn, P→rp, R→rr
   IF Len( l_cName ) == 1
      DO CASE
      CASE l_cName == "a" ; l_cName := iif( l_cColor == "A", "ra", "ba" )
      CASE l_cName == "b" ; l_cName := iif( l_cColor == "B", "rb", "bb" )
      CASE l_cName == "c" ; l_cName := iif( l_cColor == "C", "rc", "bc" )
      CASE l_cName == "k" ; l_cName := iif( l_cColor == "K", "rk", "bk" )
      CASE l_cName == "n" ; l_cName := iif( l_cColor == "N", "rn", "bn" )
      CASE l_cName == "p" ; l_cName := iif( l_cColor == "P", "rp", "bp" )
      CASE l_cName == "r" ; l_cName := iif( l_cColor == "R", "rr", "br" )
      ENDCASE
   ENDIF
   
   // 检查哈希表是否已初始化
   IF Empty( s_aResourceBitmaps )
      RETURN NIL
   ENDIF
   
   // 检查键是否存在
   IF !hb_HHasKey( s_aResourceBitmaps, l_cName )
      OutErr( "WARNING: Resource '" + l_cName + "' not found", hb_eol() )
      RETURN NIL
   ENDIF
   
   // 直接访问哈希表
   l_aResult := s_aResourceBitmaps[ l_cName ]
   
   // 如果结果不是数组，返回 NIL
   IF ValType( l_aResult ) != "A"
      RETURN NIL
   ENDIF
   
   // 如果数组为空，返回 NIL
   IF Len( l_aResult ) == 0
      RETURN NIL
   ENDIF
   
RETURN l_aResult

//--------------------------------------------------------------------------------
// 获取程序图标
//--------------------------------------------------------------------------------

FUNCTION xq_GetAppIcon()
   RETURN HIcon():FindResource( "app_icon" )

//--------------------------------------------------------------------------------
// 释放资源
//--------------------------------------------------------------------------------

FUNCTION xq_FreeResources()

   // HwGUI 会自动管理资源，这里只清空缓存
   s_aResourceBitmaps := {}

   RETURN NIL