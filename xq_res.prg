/*
 * 中国象棋资源管理模块
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 负责管理所有游戏资源（图片、声音）的加载和播放
 */

#include "xq_xiangqi.ch"

#ifdef __PLATFORM__WINDOWS
// REQUEST HWG_PLAYSOUND        // 播放声音功能（已废弃，需要额外库支持）
#endif
REQUEST HWG_OPENIMAGE
REQUEST HWG_DRAWTRANSPARENTBITMAP
REQUEST HWG_GETBITMAPSIZE

// ========================================
// 全局变量（需要从主程序访问）
// ========================================
// 这些变量在 xiangqiw.prg 中声明为 static
// 通过函数参数传递或使用公共接口

// --------------------------------------------------------------------------------

/*
 * 获取当前样式的资源路径
 *
 * 参数:
 *   par_cStyle - 样式名称（"woods" 或 "eleeye"）
 *   par_cFileName - 文件名
 * 返回: 完整路径字符串
 */
FUNCTION xq_GetSkinPath( par_cStyle, par_cFileName )

   LOCAL cStyleDir, cFilePath, cBaseName, cExt, nDotPos

   // 直接使用样式名称作为目录名，支持任意命名的皮肤文件夹
   IF Lower( AllTrim( par_cStyle ) ) == "embedded"
      cStyleDir := "embedded"
   ELSE
      cStyleDir := Lower( AllTrim( par_cStyle ) )
   ENDIF

   cFilePath := XQ_SKIN_BASE_DIR + cStyleDir + hb_osPathSeparator() + par_cFileName

   // 对于文件加载的样式（非 embedded），将 .png 转换为 .bmp
   // 棋盘保持 .jpg，embedded 样式不转换
   IF cStyleDir != "embedded" .AND. Upper( par_cFileName ) != "BOARD.JPG"
      nDotPos := RAt( ".", cFilePath )
      IF nDotPos > 0
         cBaseName := Left( cFilePath, nDotPos - 1 )
         cExt := SubStr( cFilePath, nDotPos )
         IF Upper( cExt ) == ".PNG"
            cFilePath := cBaseName + ".bmp"
         ENDIF
      ENDIF
   ENDIF

   RETURN cFilePath

// --------------------------------------------------------------------------------

/*
 * 加载图片文件（使用底层函数）
 *
 * 参数:
 *   par_cFileName - 图片文件完整路径
 * 返回: 图片句柄或 NIL
 */
FUNCTION xq_LoadImageFile( par_cFileName )

   LOCAL hImg

   hImg := hwg_OpenImage( par_cFileName, .F. )
   IF Empty( hImg )
      OutErr( "hwg_OpenImage failed: " + par_cFileName, hb_eol() )
   ENDIF

   RETURN hImg

// --------------------------------------------------------------------------------

/*
 * 加载单个棋子图片（辅助函数）
 *
 * 参数:
 *   par_cStyle - 样式名称
 *   par_cFileName - 文件名
 *   par_aPieceImages - 棋子图片哈希表引用
 *   par_cKey - 哈希表键名
 *   par_nTransparentColor - 透明色
 * 返回: .T. 成功, .F. 失败
 */
STATIC FUNCTION LoadPieceImage( par_cStyle, par_cFileName, par_aPieceImages, par_cKey, par_nTransparentColor )

   LOCAL hImg, aSize, cFilePath, l_cExt

   cFilePath := xq_GetSkinPath( par_cStyle, par_cFileName )
   hImg := xq_LoadImageFile( cFilePath )
   IF !Empty( hImg )
      aSize := hwg_Getbitmapsize( hImg )
      IF ValType( aSize ) == "A" .AND. Len( aSize ) >= 2
         // 判断文件格式
         l_cExt := Upper( SubStr( cFilePath, RAt( ".", cFilePath ) ) )
// 存储: { 图片句柄, 宽度, 高度, 格式, 透明色 }
         par_aPieceImages[ par_cKey ] := { hImg, aSize[ 1 ], aSize[ 2 ], l_cExt, par_nTransparentColor }
      ELSE
         OutErr( "hwg_Getbitmapsize returned wrong format: " + ValType( aSize ), hb_eol() )
      ENDIF
   ELSE
      OutErr( "Piece load failed: " + par_cKey + " (" + cFilePath + ")", hb_eol() )
   ENDIF

   RETURN .T.

// --------------------------------------------------------------------------------

/*
 * 加载所有游戏资源（棋盘和棋子）
 *
 * 参数:
 *   par_cStyle - 样式名称（如 "woods", "eleeye"）
 *   par_oBoardBitmap - 棋盘位图对象引用
 *   par_aPieceImages - 棋子图片哈希表引用
 *   par_nBoardWidth - 棋盘宽度引用
 *   par_nBoardHeight - 棋盘高度引用
 *   par_nCellSize - 单元格大小引用
 *   par_nOffsetX - 棋盘X偏移引用
 *   par_nOffsetY - 棋盘Y偏移引用
 * 返回: .T. 成功, .F. 失败
 */
FUNCTION xq_LoadResources( par_cStyle, par_oBoardBitmap, par_aPieceImages, ;
      par_nBoardWidth, par_nBoardHeight, par_nCellSize, ;
      par_nOffsetX, par_nOffsetY, par_nTransparentColor )
   // par_oBoardBitmap: pixbuf 句柄（GdkPixbuf handle），不是 HBitmap 对象
   // 由 hwg_OpenImage() 返回，可直接用于 hwg_DrawBitmap()

   LOCAL hImg, aSize
   LOCAL cFilePath, cKey, aImgInfo
   LOCAL nBoardScale, nPieceScale
   LOCAL nNewWidth, nNewHeight, hScaledBitmap
   LOCAL hMemDC, hNewBitmap, hOldBitmap

   // 根据皮肤类型选择加载方式
   IF Lower( AllTrim( par_cStyle ) ) == "embedded"
      // 使用嵌入资源（单独处理）
      RETURN xq_LoadFromEmbeddedResources( par_aPieceImages, @par_oBoardBitmap, ;
            @par_nBoardWidth, @par_nBoardHeight, @par_nCellSize, ;
            @par_nOffsetX, @par_nOffsetY, @par_nTransparentColor )
   ENDIF

// 文件加载样式（eleeye、woods、classic、traditional 都使用文件加载（逻辑相同）
   // 根据皮肤类型选择透明色
   IF par_cStyle == "eleeye" .OR. par_cStyle == "classic"
      // eleeye 和 classic 皮肤：使用洋红色透明
      par_nTransparentColor := 0xFF00FF
   ELSE
      // woods 和 traditional 皮肤：使用黑色透明
      par_nTransparentColor := 0x000000
   ENDIF

   // 加载棋盘背景
   cFilePath := xq_GetSkinPath( par_cStyle, XQ_BOARD_FILE_NAME )
   IF hb_FileExists( cFilePath )
      hImg := xq_LoadImageFile( cFilePath )
      IF !Empty( hImg )
         par_oBoardBitmap := hImg
      ELSE
         OutErr( "Board load failed: " + cFilePath, hb_eol() )
      ENDIF
   ELSE
      OutErr( "Board file not found: " + cFilePath, hb_eol() )
   ENDIF

   // 加载红方棋子（使用单字符键名）
   LoadPieceImage( par_cStyle, XQ_RED_K_FILE, par_aPieceImages, "K", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_RED_A_FILE, par_aPieceImages, "A", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_RED_B_FILE, par_aPieceImages, "B", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_RED_C_FILE, par_aPieceImages, "C", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_RED_N_FILE, par_aPieceImages, "N", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_RED_R_FILE, par_aPieceImages, "R", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_RED_P_FILE, par_aPieceImages, "P", par_nTransparentColor )

   // 加载黑方棋子（使用单字符键名）
   LoadPieceImage( par_cStyle, XQ_BLACK_K_FILE, par_aPieceImages, "k", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_BLACK_A_FILE, par_aPieceImages, "a", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_BLACK_B_FILE, par_aPieceImages, "b", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_BLACK_C_FILE, par_aPieceImages, "c", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_BLACK_N_FILE, par_aPieceImages, "n", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_BLACK_R_FILE, par_aPieceImages, "r", par_nTransparentColor )
   LoadPieceImage( par_cStyle, XQ_BLACK_P_FILE, par_aPieceImages, "p", par_nTransparentColor )

   // 计算棋盘尺寸
   IF !Empty( par_oBoardBitmap )
      aSize := hwg_Getbitmapsize( par_oBoardBitmap )
      IF ValType( aSize ) == "A" .AND. Len( aSize ) >= 2
         par_nBoardWidth := aSize[ 1 ]
         par_nBoardHeight := aSize[ 2 ]

         // 尝试读取配置文件获取偏移量和缩放比例
         nBoardScale := 1.0
         nPieceScale := 1.0
         xq_LoadStyleConfig( par_cStyle, @par_nOffsetX, @par_nOffsetY, @par_nTransparentColor, @nBoardScale, @nPieceScale )

         // 应用棋盘缩放（偏移量不缩放，用于调整棋子位置）
         par_nBoardWidth := Int( par_nBoardWidth * nBoardScale )
         par_nBoardHeight := Int( par_nBoardHeight * nBoardScale )

         // 计算单元格大小（考虑缩放后的棋盘尺寸和原始偏移量）
         par_nCellSize := Int( (par_nBoardWidth - 2 * par_nOffsetX) / 9 )

         // 更新所有棋子的透明色和大小

                  FOR EACH cKey IN hb_HKeys( par_aPieceImages )

                     aImgInfo := par_aPieceImages[ cKey ]

                     IF Len( aImgInfo ) >= 5

                        aImgInfo[ 5 ] := par_nTransparentColor

                        // 使用棋子缩放比例（仅更新尺寸，绘图时使用缩放参数）

                        IF nPieceScale != 1.0

                           nNewWidth := Int( aImgInfo[ 2 ] * nPieceScale )

                           nNewHeight := Int( aImgInfo[ 3 ] * nPieceScale )

                           aImgInfo[ 2 ] := nNewWidth

                           aImgInfo[ 3 ] := nNewHeight

                        ENDIF

                        par_aPieceImages[ cKey ] := aImgInfo

                     ENDIF

                  NEXT
      ELSE
         OutErr( "hwg_Getbitmapsize board returned wrong format: " + ValType( aSize ), hb_eol() )
         par_nBoardWidth := 540
         par_nBoardHeight := 600
         par_nCellSize := 60
         // 设置默认偏移量
         par_nOffsetX := 0
         par_nOffsetY := 0
      ENDIF
   ELSE
      par_nBoardWidth := 540
      par_nBoardHeight := 600
      par_nCellSize := 60
      // 设置默认偏移量
      par_nOffsetX := 0
      par_nOffsetY := 0
      OutErr( "Board load failed, using default size", hb_eol() )
   ENDIF

   RETURN .T.

//--------------------------------------------------------------------------------

/*
 * 缩放位图
 *
 * 参数:
 *   par_hBitmap - 原始位图句柄（pixbuf）
 *   par_nNewWidth - 新宽度
 *   par_nNewHeight - 新高度
 * 返回: 缩放后的位图句柄（pixbuf）或原始位图（如果缩放失败）
 */
STATIC FUNCTION xq_ScaleBitmap( par_hBitmap, par_nNewWidth, par_nNewHeight )

   LOCAL hResult, nOldWidth, nOldHeight
   LOCAL aSize, cTempFile, cCmd, nExitCode

   // 获取原始尺寸
   aSize := hwg_Getbitmapsize( par_hBitmap )
   IF ValType( aSize ) != "A" .OR. Len( aSize ) < 2
      RETURN NIL
   ENDIF

   nOldWidth := aSize[ 1 ]
   nOldHeight := aSize[ 2 ]

   // 如果尺寸相同，直接返回原始位图
   IF nOldWidth == par_nNewWidth .AND. nOldHeight == par_nNewHeight
      RETURN par_hBitmap
   ENDIF

   // 使用临时文件方法缩放
   // 1. 保存原始位图到临时文件
   cTempFile := hb_DirBase() + "temp_scale_" + hb_MilliSeconds() + ".bmp"
   
   // 注意：这里需要实现位图保存功能
   // 由于 HwGUI 可能不直接提供，我们暂时返回原始位图
   // 实际缩放需要更复杂的实现
   
   // 暂时返回原始位图，不进行缩放
   RETURN par_hBitmap

// --------------------------------------------------------------------------------

/*
 * 播放游戏音效
 *
 * 参数:
 *   par_cSoundType - 音效类型（move, capture, check, win, loss, draw, newgame）
 *   par_lSoundEnabled - 音效开关
 *   par_nMoveCount - 走棋计数（用于交替音效）
 * 返回: NIL
 */
FUNCTION xq_PlaySound( par_cSoundType, par_lSoundEnabled, par_nMoveCount )

   LOCAL cSoundPath, cSoundFile
   LOCAL lUseAlternate := ( par_nMoveCount % 2 == 0 )

   IF !par_lSoundEnabled
      RETURN NIL
   ENDIF

   cSoundPath := XQ_SOUND_BASE_DIR

   DO CASE
   CASE par_cSoundType == "move"
      cSoundFile := iif( lUseAlternate, "move.wav", "move2.wav" )
   CASE par_cSoundType == "capture"
      cSoundFile := iif( lUseAlternate, "capture.wav", "capture2.wav" )
   CASE par_cSoundType == "check"
      cSoundFile := iif( lUseAlternate, "check.wav", "check2.wav" )
   CASE par_cSoundType == "win"
      cSoundFile := "win.wav"
   CASE par_cSoundType == "loss"
      cSoundFile := "loss.wav"
   CASE par_cSoundType == "draw"
      cSoundFile := "draw.wav"
   CASE par_cSoundType == "newgame"
      cSoundFile := "newgame.wav"
   ENDCASE

   IF Empty( cSoundFile ) .OR. !File( cSoundPath + cSoundFile )
      RETURN NIL
   ENDIF

#ifndef __PLATFORM__WINDOWS
   // Linux/GTK: 使用 aplay 命令
   RUN ( "aplay " + cSoundPath + cSoundFile + " >/dev/null 2>&1 &" )
#else
   // Windows: 使用 hwg_Playsound
   hwg_Playsound( cSoundPath + cSoundFile, .F., .F. )
#endif

   RETURN NIL

// --------------------------------------------------------------------------------

/*
 * 返回棋子图片的文件路径列表（用于资源检查）
 *
 * 参数: 无
 * 返回: 资源文件列表数组
 */
FUNCTION xq_Chess_res()

   LOCAL l_aResources := {}

   // 棋盘背景
   AAdd( l_aResources, { "board", "skins/woods/board.jpg" } )

   // 红方棋子
   AAdd( l_aResources, { "rk", "skins/woods/rk.bmp" } )
   AAdd( l_aResources, { "ra", "skins/woods/ra.bmp" } )
   AAdd( l_aResources, { "rb", "skins/woods/rb.bmp" } )
   AAdd( l_aResources, { "rc", "skins/woods/rc.bmp" } )
   AAdd( l_aResources, { "rn", "skins/woods/rn.bmp" } )
   AAdd( l_aResources, { "rr", "skins/woods/rr.bmp" } )
   AAdd( l_aResources, { "rp", "skins/woods/rp.bmp" } )

   // 黑方棋子
   AAdd( l_aResources, { "bk", "skins/woods/bk.bmp" } )
   AAdd( l_aResources, { "ba", "skins/woods/ba.bmp" } )
   AAdd( l_aResources, { "bb", "skins/woods/bb.bmp" } )
   AAdd( l_aResources, { "bc", "skins/woods/bc.bmp" } )
   AAdd( l_aResources, { "bn", "skins/woods/bn.bmp" } )
   AAdd( l_aResources, { "br", "skins/woods/br.bmp" } )
   AAdd( l_aResources, { "bp", "skins/woods/bp.bmp" } )

   RETURN l_aResources

// --------------------------------------------------------------------------------

/*
 * 加载样式配置文件
 *
 * 参数:
 *   par_cStyle - 样式名称（如 "woods", "eleeye"）
 *   par_nOffsetX - 棋盘X偏移引用
 *   par_nOffsetY - 棋盘Y偏移引用
 *   par_nTransparentColor - 透明色引用
 * 返回: NIL
 */
STATIC FUNCTION xq_LoadStyleConfig( par_cStyle, par_nOffsetX, par_nOffsetY, par_nTransparentColor, par_nBoardScale, par_nPieceScale )

   LOCAL cConfigPath, cJsonContent, cTemp
   LOCAL nPos1, nPos2

   // 默认偏移量、透明色和缩放比例
   par_nOffsetX := 0
   par_nOffsetY := 0
   par_nTransparentColor := 0xFF00FF
   par_nBoardScale := 1.0
   par_nPieceScale := 1.0

   // 尝试读取 config.json（JSON 格式，如 woods 样式）
   cConfigPath := XQ_SKIN_BASE_DIR + par_cStyle + "/config.json"
   IF hb_FileExists( cConfigPath )
      cJsonContent := hb_MemoRead( cConfigPath )
      IF !Empty( cJsonContent )
         // 简单的 JSON 解析：提取 offset.dx 和 offset.dy
         IF "dx" $ cJsonContent
            nPos1 := At( '"dx"', cJsonContent )
            IF nPos1 > 0
               cTemp := SubStr( cJsonContent, nPos1 )
               nPos1 := At( ':', cTemp )
               IF nPos1 > 0
                  nPos2 := At( ',', cTemp )
                  IF nPos2 == 0
                     nPos2 := At( '}', cTemp )
                  ENDIF
                  IF nPos2 > 0
                     par_nOffsetX := Val( LTrim( SubStr( cTemp, nPos1 + 1, nPos2 - nPos1 - 1 ) ) )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF

         IF "dy" $ cJsonContent
            nPos1 := At( '"dy"', cJsonContent )
            IF nPos1 > 0
               cTemp := SubStr( cJsonContent, nPos1 )
               nPos1 := At( ':', cTemp )
               IF nPos1 > 0
                  nPos2 := At( '}', cTemp )
                  IF nPos2 > 0
                     par_nOffsetY := Val( LTrim( SubStr( cTemp, nPos1 + 1, nPos2 - nPos1 - 1 ) ) )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF

         // 读取透明色配置
         IF "transparent" $ cJsonContent
            nPos1 := At( '"transparent"', cJsonContent )
            IF nPos1 > 0
               cTemp := SubStr( cJsonContent, nPos1 )
               nPos1 := At( ':', cTemp )
               IF nPos1 > 0
                  nPos2 := At( '}', cTemp )
                  IF nPos2 == 0
                     nPos2 := At( ',', cTemp )
                  ENDIF
                  IF nPos2 > 0
                     cTemp := LTrim( SubStr( cTemp, nPos1 + 1, nPos2 - nPos1 - 1 ) )
                     // 支持十进制或十六进制颜色
                     IF "0x" $ Lower( cTemp )
                        par_nTransparentColor := hb_HexToNum( cTemp )
                     ELSE
                        par_nTransparentColor := Int( Val( cTemp ) )
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
         ENDIF

         // 读取棋盘缩放比例配置
         IF "boardScale" $ cJsonContent
            nPos1 := At( '"boardScale"', cJsonContent )
            IF nPos1 > 0
               cTemp := SubStr( cJsonContent, nPos1 )
               nPos1 := At( ':', cTemp )
               IF nPos1 > 0
                  nPos2 := At( ',', cTemp )
                  IF nPos2 == 0
                     nPos2 := At( '}', cTemp )
                  ENDIF
                  IF nPos2 > 0
                     cTemp := LTrim( SubStr( cTemp, nPos1 + 1, nPos2 - nPos1 - 1 ) )
                     par_nBoardScale := Val( cTemp )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF

         // 读取棋子缩放比例配置
         IF "pieceScale" $ cJsonContent
            nPos1 := At( '"pieceScale"', cJsonContent )
            IF nPos1 > 0
               cTemp := SubStr( cJsonContent, nPos1 )
               nPos1 := At( ':', cTemp )
               IF nPos1 > 0
                  nPos2 := At( ',', cTemp )
                  IF nPos2 == 0
                     nPos2 := At( '}', cTemp )
                  ENDIF
                  IF nPos2 > 0
                     cTemp := LTrim( SubStr( cTemp, nPos1 + 1, nPos2 - nPos1 - 1 ) )
                     par_nPieceScale := Val( cTemp )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------
// 皮肤目录扫描
// 用于自动发现 skins/ 目录下的所有皮肤
//--------------------------------------------------------------------------------

/*
 * 扫描皮肤目录，发现所有可用皮肤
 *
 * 返回: 皮肤名称数组，例如 {"woods", "eleeye", "classic", "traditional"}
 */
STATIC FUNCTION xq_ScanSkinDirectories()
   LOCAL cSkinDir, cConfigPath, aSkinList := {}
   LOCAL aDirList, cDirName, cSkinBaseDir

   // 检查皮肤目录是否存在
   IF !hb_DirExists( XQ_SKIN_BASE_DIR )
      RETURN aSkinList  // 返回空数组
   ENDIF

   // 确保 base 目录以分隔符结尾
   cSkinBaseDir := XQ_SKIN_BASE_DIR
   IF Right( cSkinBaseDir, 1 ) != hb_osPathSeparator()
      cSkinBaseDir += hb_osPathSeparator()
   ENDIF

   // 扫描 skins/ 目录下的所有子目录
   aDirList := hb_Directory( cSkinBaseDir, "D" )
   IF Empty( aDirList )
      RETURN aSkinList
   ENDIF

   // 检查每个子目录是否有 config.json
   // hb_Directory 返回数组，每个元素是：[F_NAME, F_SIZE, F_DATE, F_TIME, F_ATTR]
   FOR EACH cDirName IN aDirList
      cSkinDir := cSkinBaseDir + cDirName[1] + hb_osPathSeparator()
      cConfigPath := cSkinDir + "config.json"

      // 检查是否存在 config.json
      IF hb_FileExists( cConfigPath )
         AAdd( aSkinList, cDirName[1] )
      ENDIF
   NEXT

RETURN aSkinList

/*
 * 获取可用的皮肤列表（包括 embedded）
 *
 * 返回: 皮肤数组，每个元素是哈希表 { "name": "皮肤名", "label": "显示标签" }
 */
FUNCTION xq_GetAvailableSkins()
   LOCAL aSkinList := {}
   LOCAL aDiskSkins, cSkinName, cLabel
   LOCAL hSkin

   // 1. 添加 embedded 皮肤
   hSkin := hb_hash()
   hb_HSet( hSkin, "name", "embedded" )
   hb_HSet( hSkin, "label", "Default (Embedded)" )
   AAdd( aSkinList, hSkin )

   // 2. 扫描磁盘皮肤
   aDiskSkins := xq_ScanSkinDirectories()
   FOR EACH cSkinName IN aDiskSkins
      hSkin := hb_hash()
      hb_HSet( hSkin, "name", Lower( cSkinName ) )

      // 生成显示标签（首字母大写）
      cLabel := Upper( Left( cSkinName, 1 ) ) + Lower( SubStr( cSkinName, 2 ) ) + " Style"
      hb_HSet( hSkin, "label", cLabel )

      AAdd( aSkinList, hSkin )
   NEXT

RETURN aSkinList

//--------------------------------------------------------------------------------
// 嵌入资源管理（来自 resdemo）
// 用于 embedded 皮肤，所有资源嵌入代码中，无需外部文件
//--------------------------------------------------------------------------------

/*
 * 初始化嵌入资源（来自 xq_res_embedded.prg）
 *
 * 返回: NIL
 */
FUNCTION xq_InitEmbeddedResources()
   // 调用嵌入资源初始化函数
   xq_InitResources()
RETURN NIL

//--------------------------------------------------------------------------------
/*
 * 从嵌入资源加载棋子和棋盘（embedded 皮肤）
 *
 * 参数:
 *   par_aPieceImages - 棋子图片哈希表引用
 *   par_oBoardBitmap - 棋盘背景位图引用
 *   par_nBoardWidth - 棋盘宽度（引用）
 *   par_nBoardHeight - 棋盘高度（引用）
 *   par_nCellSize - 单元格大小（引用）
 *   par_nOffsetX - X偏移量（引用）
 *   par_nOffsetY - Y偏移量（引用）
 *   par_nTransparentColor - 透明色（引用）
 * 返回: .T. 成功, .F. 失败
 */
FUNCTION xq_LoadFromEmbeddedResources( par_aPieceImages, par_oBoardBitmap, ;
      par_nBoardWidth, par_nBoardHeight, par_nCellSize, ;
      par_nOffsetX, par_nOffsetY, par_nTransparentColor )

   LOCAL l_aBitmapInfo, l_aSize, l_cKey
   LOCAL nBoardScale, nPieceScale
   LOCAL nNewWidth, nNewHeight

   // 设置 embedded 皮肤的默认配置（硬编码）
   nBoardScale := 1.0
   nPieceScale := 1.0
   par_nOffsetX := 1
   par_nOffsetY := 14
   par_nTransparentColor := 0xFF00FF

   // 初始化嵌入资源
   xq_InitEmbeddedResources()

   // 加载棋盘背景
   l_aBitmapInfo := xq_GetChessBitmap( "board" )
   IF !Empty( l_aBitmapInfo ) .AND. ValType( l_aBitmapInfo ) == "A" .AND. Len( l_aBitmapInfo ) >= 3
      par_oBoardBitmap := l_aBitmapInfo[ 1 ]  // pixbuf 句柄
      par_nBoardWidth := l_aBitmapInfo[ 2 ]
      par_nBoardHeight := l_aBitmapInfo[ 3 ]
   ELSE
      // 使用默认尺寸
      par_nBoardWidth := 540
      par_nBoardHeight := 600
   ENDIF

   // 应用棋盘缩放（偏移量不缩放，用于调整棋子位置）
   par_nBoardWidth := Int( par_nBoardWidth * nBoardScale )
   par_nBoardHeight := Int( par_nBoardHeight * nBoardScale )

   // 计算单元格大小（考虑缩放后的棋盘尺寸和原始偏移量）
   par_nCellSize := Int( (par_nBoardWidth - 2 * par_nOffsetX) / 9 )

   // 加载黑方棋子
   l_aBitmapInfo := xq_GetChessBitmap( "bk" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "k" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "ba" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "a" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "bb" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "b" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "bc" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "c" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "bn" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "n" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "bp" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "p" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "br" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "r" ] := l_aBitmapInfo
   ENDIF

   // 加载红方棋子
   l_aBitmapInfo := xq_GetChessBitmap( "rk" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "K" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "ra" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "A" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "rb" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "B" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "rc" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "C" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "rn" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "N" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "rp" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "P" ] := l_aBitmapInfo
   ENDIF
   l_aBitmapInfo := xq_GetChessBitmap( "rr" )
   IF !Empty( l_aBitmapInfo )
      par_aPieceImages[ "R" ] := l_aBitmapInfo
   ENDIF

   // 更新所有棋子的透明色和缩放（统一逻辑）
   FOR EACH l_cKey IN hb_HKeys( par_aPieceImages )
      l_aBitmapInfo := par_aPieceImages[ l_cKey ]
      IF Len( l_aBitmapInfo ) >= 3
         // 应用棋子缩放
         IF nPieceScale != 1.0
            nNewWidth := Int( l_aBitmapInfo[ 2 ] * nPieceScale )
            nNewHeight := Int( l_aBitmapInfo[ 3 ] * nPieceScale )
            l_aBitmapInfo[ 2 ] := nNewWidth
            l_aBitmapInfo[ 3 ] := nNewHeight
         ENDIF
         
         // 在位图信息中添加格式和透明色（格式：{句柄, 宽度, 高度, 格式, 透明色}）
         IF Len( l_aBitmapInfo ) == 3
            // 添加格式和透明色
            AAdd( l_aBitmapInfo, "hbitmap" )  // 格式为 hbitmap
            AAdd( l_aBitmapInfo, par_nTransparentColor )  // 透明色
            par_aPieceImages[ l_cKey ] := l_aBitmapInfo
         ELSEIF Len( l_aBitmapInfo ) >= 5
            // 已经有格式和透明色，只更新透明色
            l_aBitmapInfo[ 5 ] := par_nTransparentColor
            par_aPieceImages[ l_cKey ] := l_aBitmapInfo
         ENDIF
      ENDIF
   NEXT

   RETURN .T.

//--------------------------------------------------------------------------------
/*
 * 从嵌入资源加载棋盘背景（embedded 皮肤）
 *
 * 返回: pixbuf 句柄或 NIL
 */
FUNCTION xq_LoadBoardBackgroundEmbedded()
   LOCAL l_aBitmapInfo

   // 初始化嵌入资源
   xq_InitEmbeddedResources()

   // 获取棋盘背景
   l_aBitmapInfo := xq_GetChessBitmap( "board" )

   IF !Empty( l_aBitmapInfo ) .AND. ValType( l_aBitmapInfo ) == "A" .AND. Len( l_aBitmapInfo ) >= 1
      RETURN l_aBitmapInfo[ 1 ]  // 返回 pixbuf 句柄
   ENDIF

   RETURN NIL

// --------------------------------------------------------------------------------
