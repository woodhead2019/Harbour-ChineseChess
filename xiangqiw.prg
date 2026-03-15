/*
 * 中国象棋 GUI 版本
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 使用 HwGUI 界面
 *
 * 【重要提示】
 * 1. 本文件中的所有非 static 函数都不用在 xq_xiangqi.ch 中添加 ANNOUNCE 声明
 * 2. 修改函数签名时（函数名、参数），必须同步更新 xq_funcslist.txt 中的备忘提醒
 * 3. 删除函数时，必须从 xq_funcslist.txt 中移除对应的说明
 *
 * ======== 第三方库许可说明 ========
 *
 * 本项目集成了象眼引擎 (ElephantEye)，使用 GPL v3 许可证。
 *
 * 象眼引擎项目：https://github.com/xqbase/eleeye
 * 许可证：GPL v3
 * 集成方式：静态链接 (libeleeye.a)
 *
 * 根据 GPL v3 许可证的要求，使用象眼引擎的项目也必须遵循 GPL v3 许可证。
 * 本项目的其他部分仍遵循 CC0 Public Domain 许可证。
 */

#include "hwgui.ch"
#include "xq_xiangqi.ch"
REQUEST HB_CODEPAGE_UTF8EX

// HwGUI 使用 HB_GT_HWGUI 驱动（Linux 和 Windows 通用）
// 注意：注释掉 REQUEST，依赖 hwgui.ch 中的默认配置
//REQUEST HB_GT_HWGUI
//REQUEST HB_GT_HWGUI_DEFAULT

// 常量定义已移至 xq_xiangqi.ch

// ========== HwGUI 控件变量 ==========
// 所有控件都以 'o' 开头（HwGUI约定）

static oMainWnd              // 主窗口控件（WINDOW）
static oChessBoard           // 棋盘控件（BOARD）- 用于绘制棋盘和棋子
static oBoardBitmap := NIL   // 棋盘位图对象（BITMAP）
static oStatusBarLine1       // 状态栏第一行控件（SAY）- 显示"等待开局"或"红方走棋/黑方走棋"
static oStatusBarLine2       // 状态栏第二行控件（SAY）- 显示走法信息或临时消息
static oXQ_MsgWnd            // 消息窗口控件（BROWSE）- 显示调试信息、走棋记录
static oXQ_MsgMenu           // 消息窗口右键菜单（CONTEXT MENU）
// static oStringBoard          // 中国记谱法窗口（EDITBOX）- 显示传统记法（已移至 xq_notation.prg）
static oEngineOutput         // 引擎输出窗口（EDITBOX）- 显示引擎返回信息
static oTraceText            // 调试追踪控件（SAY）- 显示调试追踪信息
static oAITimer := NIL       // AI计时器（HTIMER）- 用于延迟执行AI走棋
static oCheckmateTimer := NIL  // 将死检查计时器（HTIMER）- 用于异步检查将死
static lCheckmateCheckRunning := .F.  // 将死检查是否正在运行（防止重复触发）
static oDebugOverlay         // 调试边框覆盖层控件（BOARD）
static oBtnNew               // 新游戏按钮
static oBtnPlayers           // 玩家按钮
static oBtnLoad              // 加载按钮
static oBtnSave              // 保存按钮
static oBtnOptions           // 选项按钮
static oBtnUndo              // 悔棋按钮
static oBtnHelp              // 帮助按钮
static oBtnStopAI            // 停止AI按钮

// ========== 游戏状态变量 ==========
static nRedPlayer := 1        // 1=人, 2=AI(ElephantEye), 3=AI(Pikafish)
static nBlackPlayer := 1      // 1=人, 2=AI(ElephantEye), 3=AI(Pikafish)
static lDebugMode := .F.      // 调试模式：.T.=显示调试信息, .F.=不显示
static lUCCIEngineInitialized := .F.  // UCCI 引擎是否已初始化
static lAI1Initialized := .F.  // AI1 引擎是否已初始化
static lAI2Initialized := .F.  // AI2 引擎是否已初始化
static lAITimerRunning := .F.  // AI计时器是否正在运行（防止重复触发）
static lAIEnabled := .T.      // AI 是否启用（用于停止 AI 对战）
static aCheckmateBoard := {}  // 待检查将死的棋盘状态
static lCheckmateRedTurn := .F.  // 待检查将死的回合
static aPieceImages := {}     // 棋子图片数组
static aBoardPos := {}        // 棋盘位置数组（10行×9列）
static nSelectedCol := -1     // 选中的列（1-9）

//--------------------------------------------------------------------------------

static nSelectedRow := -1     // 选中的行（1-10）
static aLegalMovePositions := {}  // 合法走法位置列表（每个元素是 {行, 列}）
static nLastMoveCol := -1     // 最后一步移动的目标列（1-9）
static nLastMoveRow := -1     // 最后一步移动的目标行（1-10）
static nLastMoveFromCol := -1 // 最后一步移动的起始列（1-9）
static nLastMoveFromRow := -1 // 最后一步移动的起始行（1-10）
static lRedTurn := .T.        // 当前回合：.T.=红方, .F.=黑方
static lGameRunning := .F.    // 游戏是否运行中
static cLastMove := ""        // 最近一次走法（用于状态栏显示）
static aMoveHistory := {}     // 移动历史记录（用于悔棋），每个元素包含棋盘状态、回合、计数器等
static cTempMsg := ""         // 状态栏临时消息（第二行显示）
static nMoveCount := 0      // 总走棋次数计数器（用于显示回合数和限制总步数）
static nHalfMoveCount := 0   // 半回合计数（用于50回合规则，吃子或走兵时重置）
static nFullMoveCount := 1   // 回合计数（从1开始，黑方走完才+1）
static nAIMaxMoves := 80      // AI 最大走棋次数（80次 = 40个回合）

// ========== 长将和长捉检测变量 ==========
static nConsecutiveCheckCount := 0  // 连续将军次数（用于检测长将）
static cInitialFen := ""       // 对局初始局面 FEN（用于保存 PGN）
static aFenHistory := {}           // FEN历史记录（用于检测三次重复局面）
static nMaxFenHistory := 10        // 最多记录10个FEN

// ========== 游戏设置变量 ==========
static lSoundEnabled := .T.   // 音效开关
static nDifficultyLevel := 3  // 难度级别 (1-5)
static lAutoSave := .T.       // 自动保存
static cBoardStyle := "woods" // 棋盘样式
static cPieceStyle := "woods" // 棋子样式
static cOldBoardStyle := ""   // 旧的棋盘样式（用于资源释放）
static cOldPieceStyle := ""   // 旧的棋子样式（用于资源释放）

// ========== 界面设置变量 ==========
static lShowMoveHints := .T.  // 显示走棋提示
static lShowCoordinates := .F. // 显示坐标
static lShowLastMove := .T.   // 显示上一步
static lCurrentLanguage := "en"  // 当前语言（默认英文）
static oComboLanguage := NIL  // 设置对话框中的语言下拉框控件

// ========== 引擎设置变量 ==========
static cEnginePath := ""      // 引擎路径（旧版，保留兼容）
static cEngineType := "eleeye" // 引擎类型（旧版，保留兼容）
static nThinkTime := 2000     // 思考时间（毫秒）（旧版，保留兼容）

// ========== AI引擎初始化状态（在xq_ucci.prg中定义）==========
// lAI1Initialized, lAI2Initialized, lUCCIEngineInitialized

// ========== AI1 配置变量（在Main函数中声明为PUBLIC）==========
// LAI1ENABLED, CAI1ENGINETYPE, CAI1ENGINEPATH, NAI1THINKTIME

// ========== AI2 配置变量（在Main函数中声明为PUBLIC）==========
// LAI2ENABLED, CAI2ENGINETYPE, CAI2ENGINEPATH, NAI2THINKTIME

// ========== 快捷键变量 ==========
static cHotKeyStopAI := "Ctrl+T"     // 停止 AI
static cHotKeyNewGame := "Ctrl+N"   // 新游戏
static cHotKeySaveGame := "Ctrl+S"  // 保存游戏
static cHotKeyLoadGame := "Ctrl+L"  // 加载游戏
static cHotKeyUndoMove := "Ctrl+Z"  // 悔棋
static cHotKeyOptions := "Ctrl+O"   // 选项
static cHotKeyHelp := "F1"          // 帮助

// ========== 字体和样式变量 ==========
static oFontMain              // 主字体（用于普通文本）
static oFontButton            // 按钮字体（用于按钮）
static oFontMono              // 等宽字体（用于代码和数据）
static oStyleNormal           // 按钮正常状态样式
static oStylePressed          // 按钮按下状态样式
static oStyleOver             // 按钮悬停状态样式

// ========== 调试日志相关 ==========
static LOG_MAX_LINES := 1000  // 最大日志行数
static aDebugLog := {}        // 调试日志数组

// ========== HwGUI 常用函数说明 ==========
/*
控件常用方法：
1. SetText( 文本 ) - 设置控件文本（SAY, EDITBOX, BUTTON）
2. GetText() - 获取控件文本（EDITBOX）
3. Refresh() - 刷新控件显示（BROWSE）
4. Bottom() - 滚动到最后一行（BROWSE）
5. SetFocus() - 设置焦点
6. Move( row, col, width, height ) - 移动控件

事件处理：
- ON CLICK {||函数()} - 点击事件
- ON PAINT {|o,h|函数()} - 绘制事件
- ON SIZE {|o,x,y|函数()} - 大小改变事件
- bOther := {|o,m,w,l|函数()} - 其他事件（鼠标等）

常用颜色常量：
- CLR_BLACK - 黑色
- CLR_WHITE - 白色
- CLR_RED - 红色
- CLR_BLUE - 蓝色
- CLR_GREEN - 绿色
- CLR_BGRAY1 - 浅灰色
- CLR_BGRAY2 - 深灰色
- CLR_DBROWN - 深棕色

常用样式常量：
- WS_VSCROLL - 垂直滚动条
- WS_HSCROLL - 水平滚动条
- WS_BORDER - 边框
- ES_MULTILINE - 多行文本（EDITBOX）
- ES_READONLY - 只读（EDITBOX）

坐标系统：
- @ row, col - 控件位置（相对于父容器）
- SIZE width, height - 控件大小
- 所有坐标和大小都是像素单位
*/

// ========== 棋盘尺寸变量 ==========
static nBoardWidth := 0      // 棋盘宽度（像素）
static nBoardHeight := 0     // 棋盘高度（像素）
static nCellSize := 60       // 单元格大小（像素）
static nOffsetX := 0         // 棋盘X偏移（相对于BOARD控件的偏移）
static nOffsetY := 0         // 棋盘Y偏移（相对于BOARD控件的偏移）
static nFixedBoardWidth := 550  // 固定棋盘窗口宽度（像素）
static nFixedBoardHeight := 600 // 固定棋盘窗口高度（像素）
static nBoardOffsetX := 0    // 棋盘背景X偏移（居中偏移）
static nBoardOffsetY := 0    // 棋盘背景Y偏移（居中偏移）
static nPieceOffsetX := 0    // 棋子X偏移（居中偏移 + 样式偏移）
static nPieceOffsetY := 0    // 棋子Y偏移（居中偏移 + 样式偏移）

function Main()
   LOCAL aMateBounds, oPaneTop
   LOCAL cDummy  // 调试文本框的临时变量
   LOCAL hGameSettings

   // 设置 UTF8EX 代码页（支持欧洲语言大小写转换）
   hb_cdpSelect( "UTF8EX" )

   // 初始化配置文件（提前初始化以读取 debug 开关）
   xq_ConfigInit()

   // 从配置文件读取 debug 开关
   lDebugMode := xq_ConfigGet( "MAIN", "DebugMode", "0" ) == "1"

   // 初始化日志系统（根据 debug 开关决定是否启用）
   IF lDebugMode
      xq_Log_Init( LOG_LEVEL_DEBUG, LOG_TARGET_FILE, "" )
      xq_Log_Info( "SYSTEM", "Starting Chinese Chess GUI application" )
      xq_Log_Info( "SYSTEM", "Debug mode enabled" )
   ENDIF

   // 初始化国际化系统（必须在其他初始化之前）
   xq_I18NInit()

   // 从配置文件读取语言设置并应用
   xq_SetLanguage( xq_ConfigGet( "MAIN", "Language", "English" ) )

// 初始化全局配置哈希表（用于替代PUBLIC变量）
   InitGlobalConfig()

   // 设置错误处理器
   xq_InitErrorHandling()

   // 从配置文件加载游戏设置
   hGameSettings := xq_ConfigGetGameSettings()

   // 应用游戏配置到全局变量
   nRedPlayer := hGameSettings["RedPlayerType"]
   nBlackPlayer := hGameSettings["BlackPlayerType"]
   nAIMaxMoves := hGameSettings["AIMaxMoves"]
   lDebugMode := hGameSettings["DebugMode"]
   lAIEnabled := hGameSettings["AIEnabled"]
   lSoundEnabled := hGameSettings["SoundEnabled"]
   nDifficultyLevel := hGameSettings["DifficultyLevel"]
   lAutoSave := hGameSettings["AutoSave"]
   cBoardStyle := hGameSettings["BoardStyle"]
   cPieceStyle := hGameSettings["PieceStyle"]

   // 从配置文件加载界面设置
   hGameSettings := xq_ConfigGetUISettings()
   lShowMoveHints := hGameSettings["ShowMoveHints"]
   lShowCoordinates := hGameSettings["ShowCoordinates"]
   lShowLastMove := hGameSettings["ShowLastMove"]
   lCurrentLanguage := hGameSettings["Language"]  // 加载语言设置（默认英文）

   // 应用语言设置到 i18n 系统
   IF !Empty( lCurrentLanguage )
      xq_SetLanguage( lCurrentLanguage )
   ENDIF

   // 从配置文件加载引擎设置（旧版兼容）
   hGameSettings := xq_ConfigGetEngineSettings()
   cEnginePath := hGameSettings["EnginePath"]
   cEngineType := hGameSettings["EngineType"]
   nThinkTime := hGameSettings["ThinkTime"]

   // 从配置文件加载AI1设置
   hGameSettings := xq_ConfigGetAI1Settings()
   GetGlobalConfig()["AI1Enabled"] := hGameSettings["Enabled"]
   GetGlobalConfig()["AI1EngineType"] := hGameSettings["EngineType"]
   GetGlobalConfig()["AI1EnginePath"] := hGameSettings["EnginePath"]
   GetGlobalConfig()["AI1ThinkTime"] := hGameSettings["ThinkTime"]

   // 从配置文件加载AI2设置
   hGameSettings := xq_ConfigGetAI2Settings()
   GetGlobalConfig()["AI2Enabled"] := hGameSettings["Enabled"]
   GetGlobalConfig()["AI2EngineType"] := hGameSettings["EngineType"]
   GetGlobalConfig()["AI2EnginePath"] := hGameSettings["EnginePath"]
   GetGlobalConfig()["AI2ThinkTime"] := hGameSettings["ThinkTime"]

   // 从配置文件加载快捷键设置
   hGameSettings := xq_ConfigGetHotkeys()
   cHotKeyStopAI := Iif( hGameSettings["StopAI"] == NIL, "Ctrl+T", hGameSettings["StopAI"] )
   cHotKeyNewGame := Iif( hGameSettings["NewGame"] == NIL, "Ctrl+N", hGameSettings["NewGame"] )
   cHotKeySaveGame := Iif( hGameSettings["SaveGame"] == NIL, "Ctrl+S", hGameSettings["SaveGame"] )
   cHotKeyLoadGame := Iif( hGameSettings["LoadGame"] == NIL, "Ctrl+L", hGameSettings["LoadGame"] )
   cHotKeyUndoMove := Iif( hGameSettings["UndoMove"] == NIL, "Ctrl+Z", hGameSettings["UndoMove"] )
   cHotKeyOptions := Iif( hGameSettings["Options"] == NIL, "Ctrl+O", hGameSettings["Options"] )
   cHotKeyHelp := Iif( hGameSettings["Help"] == NIL, "F1", hGameSettings["Help"] )

   // 初始化引擎
   aMateBounds := pos_Init()

   // 初始化象眼引擎
   xq_Eleeye_Init()

   // 初始化空棋盘
   ClearBoard()

   // 加载资源（初始加载，没有旧样式）
   LoadResources( "", "" )

   // ========== 创建字体 ==========
   // HFont():Add(字体名称, 字符集, 大小, 粗细)
   // 字体大小使用负数表示点数，正数表示像素
   // 字符集: 0=DEFAULT, 1=SYMBOL, 2=SHIFTJIS, 128=JOHAB, 129=HANGUL, 134=GB2312, 136=CHINESEBIG5, 255=OEM
#ifndef __PLATFORM__WINDOWS
   oFontMain := HFont():Add( "Sans", 0, -14, 400 )    // 主字体：Sans，14号，常规
   oFontButton := HFont():Add( "Sans", 0, -13, 400 )  // 按钮字体：Sans，13号，常规
   oFontMono := HFont():Add( "DejaVu Sans Mono", 0, -12, 400 ) // 等宽字体：DejaVu Sans Mono，12号，常规
#else
   // Windows: 使用缺省字符集
   oFontMain := HFont():Add( "宋体", 0, -14, 400 )  // 主字体：宋体，14号，常规
   oFontButton := HFont():Add( "宋体", 0, -13, 400 ) // 按钮字体：宋体，13号，常规
   oFontMono := HFont():Add( "Courier New", 0, -12, 400 ) // 等宽字体：Courier New，12号，常规
#endif

   // ========== 创建按钮样式 ==========
   // HStyle():New(颜色数组, 边框类型, 边框宽度, 阴影类型, 文字颜色)
   // 颜色数组：{背景色1, 背景色2}（渐变效果）
   oStyleNormal := HStyle():New( {XQ_CLR_BGRAY1,XQ_CLR_BGRAY2}, 1 )     // 正常状态：灰白渐变
   oStylePressed := HStyle():New( {XQ_CLR_BGRAY1}, 1,, 2, XQ_CLR_BLACK ) // 按下状态：灰色，凹陷效果
   oStyleOver := HStyle():New( {XQ_CLR_BGRAY1}, 1 )                // 悬停状态：灰色

   // ========== 创建主窗口 ==========
   // INIT WINDOW oVar MAIN TITLE "标题" AT x, y SIZE width, height
   // MAIN: 设置为主窗口
   // TITLE: 窗口标题
   // AT x, y: 窗口位置（居中显示）
   // SIZE width, height: 窗口大小
   // BACKCOLOR: 背景颜色
   // FONT: 默认字体
   // ON EXIT: 窗口关闭时的回调函数，关闭引擎进程
   INIT WINDOW oMainWnd MAIN TITLE _XQ_I__( "app.title" ) ;
      AT (hwg_GetDesktopWidth()-iif( lDebugMode, XQ_MAIN_WIDTH_DEBUG, XQ_MAIN_WIDTH_NORMAL ))/2, (hwg_GetDesktopHeight()-XQ_MAIN_HEIGHT)/2 ;
      SIZE iif( lDebugMode, XQ_MAIN_WIDTH_DEBUG, XQ_MAIN_WIDTH_NORMAL ), XQ_MAIN_HEIGHT ;
      BACKCOLOR XQ_CLR_WHITE ;
      FONT oFontMain ;
      ON EXIT {||xq_Log_Close(), xq_Eleeye_Cleanup(), xq_UCCI_CloseAI1(), xq_AI2_Close()}

   // ========== 创建顶部面板 ==========
   // @ row, col PANEL oVar SIZE width, height
   // PANEL: 面板控件，用于容器布局
   // HSTYLE: 默认样式
   // ON SIZE: 窗口大小改变时的回调
   @ 0, 0 PANEL oPaneTop SIZE oMainWnd:nWidth, XQ_TOP_HEIGHT ;
      HSTYLE oStyleNormal ;
      ON SIZE {|o,x,y|o:Move( ,,x )}

   // ========== 创建按钮控件 ==========
   // @ row, col OWNERBUTTON oVar OF oParent SIZE width, height
   // OWNERBUTTON: 自定义按钮控件
   // OF oParent: 父容器
   // HSTYLES: 三种状态样式（正常、按下、悬停）
   // TEXT: 按钮文本
   // ON CLICK: 点击事件
   // TOOLTIP: 工具提示文本

   @ 0, 0 OWNERBUTTON oBtnNew OF oPaneTop SIZE 100, XQ_TOP_HEIGHT ;
      HSTYLES oStyleNormal, oStylePressed, oStyleOver TEXT _XQ_I__( "button.new_game" ) ;
      ON CLICK {||NewGame()} TOOLTIP _XQ_I__( "tooltip.new_game" )

   @ 100, 0 OWNERBUTTON oBtnPlayers OF oPaneTop SIZE 100, XQ_TOP_HEIGHT ;
      HSTYLES oStyleNormal, oStylePressed, oStyleOver TEXT _XQ_I__( "button.game" ) ;
      ON CLICK {||Game_Players()} TOOLTIP _XQ_I__( "tooltip.game" )

   @ 200, 0 OWNERBUTTON oBtnLoad OF oPaneTop SIZE 100, XQ_TOP_HEIGHT ;
      HSTYLES oStyleNormal, oStylePressed, oStyleOver TEXT _XQ_I__( "button.load" ) ;
      ON CLICK {||LoadGame()} TOOLTIP _XQ_I__( "tooltip.load" )

   @ 300, 0 OWNERBUTTON oBtnSave OF oPaneTop SIZE 100, XQ_TOP_HEIGHT ;
      HSTYLES oStyleNormal, oStylePressed, oStyleOver TEXT _XQ_I__( "button.save" ) ;
      ON CLICK {||SaveGame()} TOOLTIP _XQ_I__( "tooltip.save" )

   @ 400, 0 OWNERBUTTON oBtnOptions OF oPaneTop SIZE 100, XQ_TOP_HEIGHT ;
      HSTYLES oStyleNormal, oStylePressed, oStyleOver TEXT _XQ_I__( "button.options" ) ;
      ON CLICK {||Game_Options()} TOOLTIP _XQ_I__( "tooltip.options" )

   @ 500, 0 OWNERBUTTON oBtnUndo OF oPaneTop SIZE 100, XQ_TOP_HEIGHT ;
      HSTYLES oStyleNormal, oStylePressed, oStyleOver TEXT _XQ_I__( "button.undo" ) ;
      ON CLICK {||UndoMove()} TOOLTIP _XQ_I__( "tooltip.undo" )

   @ 600, 0 OWNERBUTTON oBtnHelp OF oPaneTop SIZE 100, XQ_TOP_HEIGHT ;
      HSTYLES oStyleNormal, oStylePressed, oStyleOver TEXT _XQ_I__( "button.help" ) ;
      ON CLICK {||ShowHelp()} TOOLTIP _XQ_I__( "tooltip.help" )

   @ 700, 0 OWNERBUTTON oBtnStopAI OF oPaneTop SIZE 100, XQ_TOP_HEIGHT ;
      HSTYLES oStyleNormal, oStylePressed, oStyleOver TEXT _XQ_I__( "button.stop_ai" ) ;
      ON CLICK {||StopAI()} TOOLTIP _XQ_I__( "tooltip.stop_ai" )

   // ========== 设置快捷键 ==========
   // SET KEY 0, VK_xxx TO 函数
   // VK_F1: F1键
   // VK_F3: F3键
   // VK_F4: F4键
   // VK_F6: F6键
   SET KEY 0, VK_F1 TO ShowHelp()
   SET KEY 0, VK_F3 TO NewGame()
   SET KEY 0, VK_F6 TO Game_Players()
   SET KEY 0, VK_F4 TO LoadGame()
   SET KEY 0, VK_F8 TO StopAI()

   // ========== 创建 GUI 控件 ==========
   // 1. 创建游戏棋盘控件（BOARD）
   // @ row, col BOARD oVar SIZE width, height
   // BOARD: HwGUI的绘图控件，支持自定义绘制
   // ON PAINT: 当控件需要重绘时调用 BoardPaint 函数
   // BACKCOLOR: 设置背景颜色（可选）
   // bOther: 处理鼠标事件（点击、移动等）
   @ XQ_BOARD_START_X, XQ_BOARD_START_Y BOARD oChessBoard SIZE XQ_BOARD_WIDTH, XQ_BOARD_HEIGHT ;
      ON PAINT {|o,h|BoardPaint(o,h)}
   oChessBoard:bOther := {|o,m,w,l|BoardClick(o,m,w,l)}

   // 2. 创建记谱法窗口（BROWSE）- 位于左上
   // 使用 BROWSE 控件替代 EDITBOX，支持自动滚动
   xq_Notation_Create( oMainWnd, XQ_RIGHT_START_X, XQ_BOARD_START_Y, XQ_RIGHT_COL1_WIDTH, XQ_RIGHT_BOTTOM_HEIGHT, oFontMono, _XQ_I__( "engine.chinese_notation" ) )

   // 3. 创建引擎输出窗口（EDITBOX）- 位于左下
   @ XQ_RIGHT_START_X, XQ_BOARD_START_Y + XQ_RIGHT_BOTTOM_HEIGHT + 20 EDITBOX oEngineOutput ;
      CAPTION _XQ_I__( "engine.output" ) ;
      STYLE ES_MULTILINE ;
      SIZE XQ_RIGHT_COL1_WIDTH, XQ_RIGHT_BOTTOM_HEIGHT FONT oFontMono

   // 4. 创建消息调试窗口（仅调试模式显示，最右侧）
   IF lDebugMode
      XQ_MsgWnd_Create( oMainWnd, XQ_RIGHT_COL3_START, XQ_BOARD_START_Y, XQ_RIGHT_COL3_WIDTH, XQ_BOARD_HEIGHT, oFontMono )
   ENDIF

   // 6. 创建状态栏控件（第一行、第二行、调试追踪）
   create_statusbar()

   // 初始化状态栏
   UpdateStatus()

   // ========== 创建菜单 ==========
   MENU OF oMainWnd
      MENU TITLE _XQ_I__( "menu.file" )
         MENUITEM _XQ_I__( "menu.new" ) ACTION NewGame()
         MENUITEM _XQ_I__( "menu.load" ) ACTION LoadGame()
         MENUITEM _XQ_I__( "menu.save" ) ACTION SaveGame()
         SEPARATOR
         MENUITEM _XQ_I__( "menu.exit" ) ACTION ExitGame()
      ENDMENU
      MENU TITLE _XQ_I__( "menu.game" )
         MENUITEM _XQ_I__( "menu.players_settings" ) ACTION Game_Players()
         SEPARATOR
         MENUITEM _XQ_I__( "menu.resign" ) ACTION ResignGame()
         MENUITEM _XQ_I__( "menu.stop_game" ) ACTION StopGame()
         SEPARATOR
         MENUITEM _XQ_I__( "menu.stop_ai" ) ACTION StopAI()
      ENDMENU
      MENU TITLE _XQ_I__( "menu.options" )
         MENUITEM _XQ_I__( "menu.options" ) ACTION Game_Options()
         MENUITEM _XQ_I__( "menu.language" ) ACTION ChangeLanguage()
      ENDMENU
      MENU TITLE _XQ_I__( "menu.help" )
         MENUITEM _XQ_I__( "menu.help" ) ACTION ShowHelp()
         MENUITEM _XQ_I__( "menu.about" ) ACTION ShowAbout()
      ENDMENU
   ENDMENU

   // 激活窗口
   ACTIVATE WINDOW oMainWnd

RETURN NIL

/*
 * 清空棋盘
 * 
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION ClearBoard()
   LOCAL i, j, aRow

   // 手动创建二维数组：10行9列
   // 每行是一个独立的数组
   aBoardPos := {}
   FOR i := 1 TO 10
      aRow := Array( 9 )
      FOR j := 1 TO 9
         aRow[j] := "0"  // 初始化为 "0" 而不是 ""
      NEXT
      AAdd( aBoardPos, aRow )
   NEXT

RETURN NIL

/*
 * 设置初始棋局
 * 
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION SetupBoard()
   LOCAL i, j, cTemp, k

   ClearBoard()

   // 黑方棋子
   aBoardPos[1,1] := "r"
   aBoardPos[1,2] := "n"
   aBoardPos[1,3] := "b"
   aBoardPos[1,4] := "a"
   aBoardPos[1,5] := "k"
   aBoardPos[1,6] := "a"
   aBoardPos[1,7] := "b"
   aBoardPos[1,8] := "n"
   aBoardPos[1,9] := "r"
   aBoardPos[3,2] := "c"
   aBoardPos[3,8] := "c"
   aBoardPos[4,1] := "p"
   aBoardPos[4,3] := "p"
   aBoardPos[4,5] := "p"
   aBoardPos[4,7] := "p"
   aBoardPos[4,9] := "p"

   // 红方棋子
   aBoardPos[10,1] := "R"
   aBoardPos[10,2] := "N"
   aBoardPos[10,3] := "B"
   aBoardPos[10,4] := "A"
   aBoardPos[10,5] := "K"
   aBoardPos[10,6] := "A"
   aBoardPos[10,7] := "B"
   aBoardPos[10,8] := "N"
   aBoardPos[10,9] := "R"
   aBoardPos[8,2] := "C"
   aBoardPos[8,8] := "C"
   aBoardPos[7,1] := "P"
   aBoardPos[7,3] := "P"
   aBoardPos[7,5] := "P"
   aBoardPos[7,7] := "P"
   aBoardPos[7,9] := "P"

   // 保存标准初始局面 FEN
   cInitialFen := "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

RETURN NIL

/*
 * 加载资源
 * 调用 xq_res.prg 中的资源管理函数
 * 
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION LoadResources()
   LOCAL nStyleOffsetX, nStyleOffsetY, nCenterOffsetX, nCenterOffsetY, nTransparentColor
   LOCAL cKey, aImgInfo, aKeys
   LOCAL l_cType

   // 释放旧的棋盘位图
   IF !Empty( oBoardBitmap ) .AND. !Empty( cOldBoardStyle )
      // embedded 皮肤的棋盘是 pixbuf，不手动释放，让 GDK 自动管理引用计数
      // 其他皮肤的棋盘是 HBitmap，需要释放
      IF cOldBoardStyle != "embedded"
         hwg_DeleteObject( oBoardBitmap )
      ENDIF
      oBoardBitmap := NIL
   ENDIF

   // 释放旧的棋子图片
   IF ValType( aPieceImages ) == "H" .AND. Len( aPieceImages ) > 0 .AND. !Empty( cOldBoardStyle )
      aKeys := hb_HKeys( aPieceImages )
      FOR EACH cKey IN aKeys
         aImgInfo := aPieceImages[cKey]
         IF ValType( aImgInfo ) == "A" .AND. Len( aImgInfo ) >= 1 .AND. !Empty( aImgInfo[1] )
            // embedded 皮肤的棋子是 HBitmap（从 xq_GetChessBitmap 返回的是 HBitmap:handle）
            // 但对于 embedded 皮肤，我们不应该释放，因为它们来自静态哈希表
            IF cOldBoardStyle != "embedded"
               hwg_DeleteObject( aImgInfo[1] )
            ENDIF
         ENDIF
      NEXT
   ENDIF
   aPieceImages := hb_hash()

   xq_LoadResources( cBoardStyle, @oBoardBitmap, @aPieceImages, ;
                    @nBoardWidth, @nBoardHeight, @nCellSize, @nStyleOffsetX, @nStyleOffsetY, @nTransparentColor )

   // 计算棋盘在固定窗口内的居中偏移量
   nCenterOffsetX := Int( (nFixedBoardWidth - nBoardWidth) / 2 )
   nCenterOffsetY := Int( (nFixedBoardHeight - nBoardHeight) / 2 )

   // 棋盘背景只使用居中偏移
   nBoardOffsetX := nCenterOffsetX
   nBoardOffsetY := nCenterOffsetY

   // 棋子使用居中偏移 + 样式偏移
   nPieceOffsetX := nCenterOffsetX + nStyleOffsetX
   nPieceOffsetY := nCenterOffsetY + nStyleOffsetY

   // 为了兼容旧代码，设置 nOffsetX 和 nOffsetY 为棋子偏移
   nOffsetX := nPieceOffsetX
   nOffsetY := nPieceOffsetY

RETURN NIL

/*
 * 棋盘绘制函数
 * 
 * 参数:
 *   o - 棋盘控件对象
 *   hDC - 设备上下文句柄
 * 返回: NIL
 */
static FUNCTION BoardPaint( o, hDC )
   LOCAL i, j, x, y
   LOCAL cPiece, aImgInfo
   LOCAL oBrushYellow, oPenYellow
   LOCAL oBrushGreen, oPenGreen
   LOCAL oBrushBlue, oPenBlue, nDotSize, nDotX, nDotY, aPos
   LOCAL oBrushGray, oPenGray, nFromX, nFromY, nCircleSize, nSolidSize

   // 绘制棋盘背景（JPG格式）
   IF !Empty( oBoardBitmap )
      hwg_DrawBitmap( hDC, oBoardBitmap, , nBoardOffsetX, nBoardOffsetY, nBoardWidth, nBoardHeight )
   ENDIF
   // 绘制最后移动高亮（浅蓝色圆圈）
   IF nLastMoveCol > 0 .AND. nLastMoveRow > 0
      oPenGreen := HPen():Add( PS_SOLID, 4, 0xEBCE87 )  // 浅蓝色 BGR，线宽4
      x := nOffsetX + (nLastMoveCol-1) * nCellSize
      y := nOffsetY + (nLastMoveRow-1) * nCellSize
      // 原矩形实现方式（已注释）：
      // hwg_Rectangle( hDC, x, y, x + nCellSize, y + nCellSize, oPenGreen:handle )
      // 改为圆圈实现：
      nFromX := x + Int( nCellSize / 2 )
      nFromY := y + Int( nCellSize / 2 )
      nCircleSize := Int( nCellSize / 2 )  // 圆圈大小为格子的一半
      hwg_Ellipse( hDC, nFromX - nCircleSize, nFromY - nCircleSize, nFromX + nCircleSize, nFromY + nCircleSize, oPenGreen:handle )
      oPenGreen:Release()
   ENDIF

   // 绘制选中高亮（亮黄色圆圈）
   IF nSelectedCol > 0 .AND. nSelectedRow > 0
      oPenYellow := HPen():Add( PS_SOLID, 4, 0x00FFFF )  // 亮黄色 BGR，线宽4
      x := nOffsetX + (nSelectedCol-1) * nCellSize
      y := nOffsetY + (nSelectedRow-1) * nCellSize
      // 原矩形实现方式（已注释）：
      // hwg_Rectangle( hDC, x, y, x + nCellSize, y + nCellSize, oPenYellow:handle )
      // 改为圆圈实现：
      nFromX := x + Int( nCellSize / 2 )
      nFromY := y + Int( nCellSize / 2 )
      nCircleSize := Int( nCellSize / 2 )  // 圆圈大小为格子的一半
      hwg_Ellipse( hDC, nFromX - nCircleSize, nFromY - nCircleSize, nFromX + nCircleSize, nFromY + nCircleSize, oPenYellow:handle )
      oPenYellow:Release()
   ENDIF

   // 绘制合法走法位置提示（浅绿色小圆圈+实心圆）
   IF lShowMoveHints .AND. nSelectedCol > 0 .AND. nSelectedRow > 0 .AND. Len( aLegalMovePositions ) > 0
      nSolidSize := Int( nCellSize / 6 )   // 实心圆大小为格子的1/6
      nCircleSize := nSolidSize + 3        // 外圈大小 = 实心圆大小 + 3
      FOR i := 1 TO Len( aLegalMovePositions )
         aPos := aLegalMovePositions[i]
         nFromX := nOffsetX + (aPos[2]-1) * nCellSize + Int( nCellSize / 2 )
         nFromY := nOffsetY + (aPos[1]-1) * nCellSize + Int( nCellSize / 2 )
         // 绘制外圆圈（亮浅绿色空心，线宽1）
         oPenBlue := HPen():Add( PS_SOLID, 1, 0xB0F0B0 )  // 亮浅绿色
         hwg_Ellipse( hDC, nFromX - nCircleSize, nFromY - nCircleSize, nFromX + nCircleSize, nFromY + nCircleSize, oPenBlue:handle )
         oPenBlue:Release()
         // 绘制实心圆（浅绿色）
         oBrushBlue := HBrush():Add( 0x90EE90 )  // 浅绿色
         hwg_Ellipse_Filled( hDC, nFromX - nSolidSize, nFromY - nSolidSize, nFromX + nSolidSize, nFromY + nSolidSize, .F., oBrushBlue:handle )
         oBrushBlue:Release()
      NEXT
   ENDIF

   // 绘制棋子移动起始位置标记（灰色小圆圈+实心圆）
   IF nLastMoveFromCol > 0 .AND. nLastMoveFromRow > 0
      nFromX := nOffsetX + (nLastMoveFromCol-1) * nCellSize + Int( nCellSize / 2 )
      nFromY := nOffsetY + (nLastMoveFromRow-1) * nCellSize + Int( nCellSize / 2 )
      nSolidSize := Int( nCellSize / 6 )   // 实心圆大小为格子的1/6
      nCircleSize := nSolidSize + 3        // 外圈大小 = 实心圆大小 + 3，使外圈更靠近实心圆

      // 绘制外圆圈（亮灰色空心，线宽1）
      oPenGray := HPen():Add( PS_SOLID, 1, 0xB0B0B0 )  // 亮灰色
      hwg_Ellipse( hDC, nFromX - nCircleSize, nFromY - nCircleSize, nFromX + nCircleSize, nFromY + nCircleSize, oPenGray:handle )
      oPenGray:Release()

      // 绘制实心圆（灰色）
      oBrushGray := HBrush():Add( 0x808080 )  // 灰色
      hwg_Ellipse_Filled( hDC, nFromX - nSolidSize, nFromY - nSolidSize, nFromX + nSolidSize, nFromY + nSolidSize, .F., oBrushGray:handle )
      oBrushGray:Release()
   ENDIF

   // 绘制棋子
   FOR i := 1 TO 10
      FOR j := 1 TO 9
         cPiece := aBoardPos[i,j]
         IF cPiece != "0" .AND. hb_hHasKey( aPieceImages, cPiece )
            aImgInfo := aPieceImages[cPiece]
            IF Len( aImgInfo ) >= 3
               x := nOffsetX + (j-1) * nCellSize + Int( (nCellSize - aImgInfo[2]) / 2 )
               y := nOffsetY + (i-1) * nCellSize + Int( (nCellSize - aImgInfo[3]) / 2 )
               // aImgInfo = { 图片句柄, 宽度, 高度, 格式, 透明色 }
               IF (ValType( aImgInfo[1] ) == "N" .AND. aImgInfo[1] != 0) .OR. ValType( aImgInfo[1] ) == "P"
                  // 使用缩放后的棋子尺寸绘制
                  hwg_DrawTransparentBitmap( hDC, aImgInfo[1], x, y, aImgInfo[5], aImgInfo[2], aImgInfo[3] )
               ENDIF
            ENDIF
         ENDIF
      NEXT
   NEXT

RETURN NIL

/*
 * 棋盘点击事件处理
 * 
 * 工作流程：
 * 1. 获取点击坐标并转换为棋盘行列 (nRow, nCol) - 1-based
 * 2. 获取点击位置的棋子 (cPiece)
 * 3. 根据当前选中状态处理：
 *    - 如果没有选中棋子 (nSelectedCol == -1)：
 *      * 点击己方棋子 → 选中该棋子
 *      * 点击空位或敌方棋子 → 忽略
 *    - 如果已有选中的棋子：
 *      * 点击另一个己方棋子 → 重新选中
 *      * 点击空位或敌方棋子 → 尝试移动到该位置
 * 4. 移动验证：
 *    - 将棋盘位置转换为引擎格式 (90字符字符串)
 *    - 转换为 0-based 索引 (nFrom, nTo)
 *    - 调用 xq_IsMoveCorrect() 验证移动是否合法
 *    - 如果合法，执行移动并切换回合
 */
static FUNCTION BoardClick( o, msg, wParam, lParam )
   LOCAL nCol, nRow, cPiece, cTarget   // 点击位置列、行，点击位置棋子，目标位置棋子
   LOCAL aPos, nMove, nFrom, nTo       // 引擎位置结构，移动编码，源索引，目标索引
   LOCAL x, y                           // 鼠标点击坐标
   LOCAL aCheckPos, aCheckBoard, nRedKing, nBlackKing  // 胜负判断相关变量
   LOCAL lOpponentInCheck               // 对方是否被将军
   LOCAL lCurrentTurn                   // 当前回合（在切换回合之前保存）
   LOCAL aBoardBeforeMove, aPosBeforeMoveString  // 移动前的棋盘状态
   LOCAL nUCCIRow, nUCCICol, cUCCICoord  // UCCI坐标转换相关变量
   LOCAL aBoard, cFen, cICCS, cChinese  // 走棋信息相关变量
   LOCAL isCapture, isPawn              // 是否吃子，是否是兵/卒
   LOCAL nCount, i                      // 计数器和循环变量
   LOCAL nPos1, nPos2, cFenBase         // FEN字段提取相关变量
   LOCAL cBoardStr2, i2, j2, nIdx2      // 调试变量

   // 只处理鼠标左键按下事件
   IF msg != WM_LBUTTONDOWN
      RETURN -1
   ENDIF

   // 从 lParam 提取鼠标坐标
   x := hwg_Loword( lParam )
   y := hwg_Hiword( lParam )

   // 计算格子位置（考虑棋盘偏移 nOffsetX, nOffsetY）
   // 结果为 1-based 坐标：行 1-10，列 1-9
   nCol := Int( (x - nOffsetX) / nCellSize ) + 1
   nRow := Int( (y - nOffsetY) / nCellSize ) + 1

   // 转换为UCCI坐标（从下到上，0-based）
   //
   // UCCI 坐标系统定义：
   // - 列: a-i（从左到右），对应 0-8
   // - 行: 0-9（从下到上）
   //   - 行 0 = 红方底线
   //   - 行 9 = 黑方底线
   //
   // 转换公式：
   // - UCCI 行号 = 10 - GUI 行号
   // - UCCI 列号 = GUI 列号 - 1
   //
   // 示例：
   // - GUI (10, 1) = 红方左侧车 → UCCI (0, 0) = "a0"
   // - GUI (1, 1) = 黑方左侧车 → UCCI (9, 0) = "a9"
   // - GUI (10, 5) = 红方帅 → UCCI (0, 4) = "e0"
   // - GUI (1, 5) = 黑方将 → UCCI (9, 4) = "e9"
   nUCCIRow := 10 - nRow
   nUCCICol := nCol - 1
   cUCCICoord := Chr( Asc('a') + nUCCICol ) + LTrim( Str( nUCCIRow ) )

   // ShowDebugMsg( "点击: " + cUCCICoord + "，GUI：第" + LTrim(Str(nRow)) + "行, 第" + LTrim(Str(nCol)) + "列 (从上至下从左往右)" )

   // 检查坐标是否在棋盘范围内
   IF nCol < 1 .OR. nCol > 9 .OR. nRow < 1 .OR. nRow > 10
      RETURN -1
   ENDIF

   // 获取点击位置的棋子
   cPiece := aBoardPos[nRow,nCol]

   // === 情况1：没有选中棋子，尝试选中 ===
   IF nSelectedCol == -1
      IF cPiece != "0"
         // 点击了棋子，检查是否是当前玩家的棋子
         IF IsCurrentPlayerPiece( cPiece )
            // 选中该棋子
            nSelectedCol := nCol
            nSelectedRow := nRow

            // 转换为UCCI坐标
            nUCCIRow := 10 - nRow
            nUCCICol := nCol - 1
            cUCCICoord := Chr( Asc('a') + nUCCICol ) + LTrim( Str( nUCCIRow ) )

            // 计算合法走法
            CalculateLegalMoves()

            // ShowDebugMsg( "选中: " + cUCCICoord + " -> " + cPiece + "，GUI：第" + LTrim(Str(nRow)) + "行, 第" + LTrim(Str(nCol)) + "列 (从上至下从左往右)" )
            hwg_Invalidaterect( oChessBoard:handle )
         ENDIF
      ELSE
         // 不是当前玩家的棋子，不选中
      ENDIF
   ELSE
      // === 情况2：已有选中的棋子 ===
      IF cPiece != "0" .AND. IsCurrentPlayerPiece( cPiece )
         // 点击了另一个己方棋子，重新选中
         nSelectedCol := nCol
         nSelectedRow := nRow

         // 转换为UCCI坐标
         nUCCIRow := 10 - nRow
         nUCCICol := nCol - 1
         cUCCICoord := Chr( Asc('a') + nUCCICol ) + LTrim( Str( nUCCIRow ) )

         // 计算合法走法
         CalculateLegalMoves()

         // ShowDebugMsg( "重新选中: " + cUCCICoord + " -> " + cPiece + "，GUI：第" + LTrim(Str(nRow)) + "行, 第" + LTrim(Str(nCol)) + "列 (从上至下从左往右)" )
         hwg_Invalidaterect( oChessBoard:handle )
      ELSE
         // 点击了空位或敌方棋子，尝试移动到目标位置

         // 1. 获取目标位置的棋子
         cTarget := aBoardPos[nRow,nCol]
         
         // 2. 将棋盘位置转换为引擎的 Position 结构
         aPos := BoardPosToPos()

         // 3. 转换为引擎使用的索引
         //    引擎使用 90 元素数组（10x9），索引范围 1-90
         //    使用新的坐标转换函数（以 UCCI 为基准）
         nFrom := xq_GUIToIdx( nSelectedRow, nSelectedCol )
         nTo := xq_GUIToIdx( nRow, nCol )

         // OutErr( "BoardClick: nSelectedRow=" + LTrim(Str(nSelectedRow)) + ", nSelectedCol=" + LTrim(Str(nSelectedCol)) + " -> nFrom=" + LTrim(Str(nFrom)), hb_eol() )
         // OutErr( "BoardClick: nRow=" + LTrim(Str(nRow)) + ", nCol=" + LTrim(Str(nCol)) + " -> nTo=" + LTrim(Str(nTo)), hb_eol() )

         // 4. 构建移动编码：低8位是源位置，高8位是目标位置
         nMove := nFrom + nTo * 256

         // 5. 获取要移动的棋子
         cPiece := aBoardPos[nSelectedRow,nSelectedCol]

// 6. 验证移动是否合法
         IF xq_IsMoveCorrect( aPos, nMove )
            // 保存当前回合（在切换之前）
            lCurrentTurn := lRedTurn

            // 保存移动前的棋盘状态（用于计算中国记谱法）
            aBoardBeforeMove := xq_StringToArray( aPos[POS_BOARD] )
            aPosBeforeMoveString := aPos[POS_BOARD]

            // 检查目标位置是否有棋子（吃子）
            cTarget := aBoardPos[nRow, nCol]
            isCapture := (cTarget != " " .AND. cTarget != "0")

            // 检查是否是兵/卒（走兵会重置半回合计数）
            isPawn := (cPiece == "P" .OR. cPiece == "p")

            // 先移动棋子
            MovePiece( nSelectedCol, nSelectedRow, nCol, nRow )

            // 检查胜负
            aCheckPos := BoardPosToPos()
            aCheckBoard := xq_StringToArray( aCheckPos[POS_BOARD] )

            IF nRedKing == -1
               // 播放胜负音效
               xq_PlaySound( "loss", lSoundEnabled, nMoveCount)
               hwg_MsgInfo( _XQ_I__( "result.black_wins" ) )
            ELSEIF nBlackKing == -1
               // 播放胜负音效
               xq_PlaySound( "win", lSoundEnabled, nMoveCount)
               hwg_MsgInfo( _XQ_I__( "result.red_wins" ) )
            ELSE
               // 打印 FEN 格式的局面（先显示回合信息）
               ShowFen()

               // 增加移动计数（包括人走棋和AI走棋）
               nMoveCount++

               // 更新半回合计数（吃子或走兵时重置）
               IF isCapture .OR. isPawn
                  nHalfMoveCount := 0
               ELSE
                  nHalfMoveCount++
               ENDIF

               // 更新回合计数（黑方走完才+1）
               nFullMoveCount := Int((nMoveCount + 1) / 2)

               // 检查50回合规则（100半回合=50回合无吃子无动兵）
               IF nHalfMoveCount >= 100
                  // 播放和棋音效
                  xq_PlaySound( "draw", lSoundEnabled, nMoveCount)
                  hwg_MsgInfo( _XQ_I__( "result.draw_50move" ) )
                  lGameRunning := .F.
                  UpdateStatus()
                  RETURN NIL
               ENDIF

               // 检查长将（连续6次将军即3个回合）
               IF xq_IsKingInCheck( aCheckBoard, !lCurrentTurn )
                  nConsecutiveCheckCount++
                  IF nConsecutiveCheckCount >= 6
                     // 播放胜负音效
                     xq_PlaySound( Iif(lCurrentTurn, "loss", "win"), lSoundEnabled, nMoveCount)
                     hwg_MsgInfo( Iif(lCurrentTurn, _XQ_I__( "result.red_perpetual_check" ), _XQ_I__( "result.black_perpetual_check" )) )
                     lGameRunning := .F.
                     UpdateStatus()
                     RETURN NIL
                  ENDIF
               ELSE
                  nConsecutiveCheckCount := 0
               ENDIF

               // 检查三次重复局面
               cFen := xq_BoardToFenUCCI( aCheckBoard, lRedTurn, nHalfMoveCount, nFullMoveCount )
               // 只提取FEN的前3个字段（棋盘状态、回合方、易位）进行比较，忽略半回合计数和回合计数
               // FEN格式: <board> <turn> <castling> <en_passant> <half_move> <full_move>
               nPos1 := At( " ", cFen )
               nPos2 := At( " ", SubStr( cFen, nPos1 + 1 ) )
               cFenBase := Left( cFen, nPos1 + nPos2 )
               AAdd( aFenHistory, cFenBase )
               IF Len( aFenHistory ) > nMaxFenHistory
                  ADel( aFenHistory, 1 )
               ENDIF
               nCount := 0
               FOR i := Len( aFenHistory ) TO 1 STEP -1
                  IF aFenHistory[i] == cFenBase
                     nCount++
                  ENDIF
               NEXT
               IF nCount >= 3
                  // 播放和棋音效
                  xq_PlaySound( "draw", lSoundEnabled, nMoveCount)
                  hwg_MsgInfo( _XQ_I__( "result.draw_repetition" ) )
                  lGameRunning := .F.
                  UpdateStatus()
                  RETURN NIL
               ENDIF

               // 显示走棋信息（UCCI坐标和中国/英译记谱法）
               cICCS := xq_MoveToICCS( nMove, 9 )
               
               // 根据语言选择记谱法
               IF lCurrentLanguage == "zh"
                  cChinese := xq_MoveToChineseNotation( nMove, aBoardBeforeMove )
               ELSE
                  cChinese := xq_MoveToEnglishNotation( nMove, aBoardBeforeMove )
               ENDIF

               // 回合数显示格式：[round:X-Y]，X=总回合数（从1开始），Y=步数（1=红方走，2=黑方走）
               // 注释掉调试输出
               // IF lCurrentTurn  // 红方走棋
               //    ShowDebugMsg( "HUMAN (RED): " + cICCS + " (" + cChinese + ") [round:" + LTrim(Str(Int((nMoveCount+1)/2))) + "-1]" )
               // ELSE  // 黑方走棋
               //    ShowDebugMsg( "HUMAN (BLACK): " + cICCS + " (" + cChinese + ") [round:" + LTrim(Str(Int(nMoveCount/2))) + "-2]" )
               // ENDIF

               // 记录最近的走法到状态栏
               cLastMove := cICCS + " (" + cChinese + ")"

               // 添加到中国记谱法窗口（使用新的 API，内部计算记谱法）
               xq_Notation_AddMove( nMove, lCurrentTurn, aBoardBeforeMove )

               // 触发异步将死检查（检查对手是否被将军/被将死）
               // lCurrentTurn 是走棋前的回合，应该检查对手（!lCurrentTurn）
               TriggerCheckmateCheck( aCheckBoard, lCurrentTurn )

               // 显示回合信息（显示走棋后的回合）
               // 注释掉调试输出
               // ShowDebugMsg( "--- " + Iif(lRedTurn, "RED", "BLACK") + " ---" )

               // 检查是否需要触发当前回合的AI走棋
               IF lGameRunning .AND. lAIEnabled
                  // 重置AI计时器，防止重复触发（HTimer没有Destroy方法，只需设为NIL）
                  oAITimer := NIL

                  // 如果当前是红方回合且红方是AI，或者当前是黑方回合且黑方是AI
                  IF lRedTurn .AND. nRedPlayer > 1
                     // AI 思考
                     ShowDebugMsg( "Creating AI timer for RED (PlayerType:" + LTrim(Str(nRedPlayer)) + ")", , LOG_LEVEL_DEBUG )
                     oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
                  ELSEIF !lRedTurn .AND. nBlackPlayer > 1
                     // AI 思考
                     ShowDebugMsg( "Creating AI timer for BLACK (PlayerType:" + LTrim(Str(nBlackPlayer)) + ")", , LOG_LEVEL_DEBUG )
                     oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
                  ENDIF
               ENDIF
            ENDIF
         ELSE
            // 非法移动，播放音效提示
            xq_PlaySound( "illegal", lSoundEnabled, nMoveCount)
         ENDIF

         // 清除选中状态
         nSelectedCol := -1
         nSelectedRow := -1
         aLegalMovePositions := {}  // 清空合法走法列表
         hwg_Invalidaterect( oChessBoard:handle )
      ENDIF
   ENDIF

   // 注意：AI走棋后已经会自动触发对方AI走棋，这里不需要再调用

RETURN -1

/*
 * 将棋盘位置转换为引擎的 Position 结构
 */
static FUNCTION BoardPosToPos()
local aTempPos := Array( 10 )
local i, j, cBoard := ""

   // 构建 XQP 字符串（与 FEN 顺序一致：从黑方底线到红方底线）
   // 即：从上到下（GUI行1到GUI行10）
   // 这样索引1-9对应黑方底线（GUI行1），索引82-90对应红方底线（GUI行10）
   FOR i := 1 TO 10
      FOR j := 1 TO 9
         IF aBoardPos[i,j] == "0"
            cBoard += "0"
         ELSE
            cBoard += aBoardPos[i,j]
         ENDIF
      NEXT
   NEXT

   aTempPos[POS_BOARD] := cBoard
   aTempPos[POS_TURN] := lRedTurn

RETURN aTempPos
/*
 * 转换为 UCCI 格式（带调试输出）
 */
static FUNCTION XQ_ConvertToUCCI( nFromIdx, nToIdx )
local nMove, cUCCI
local aFromUCCI, aToUCCI
local cFromCol, cToCol, cFromRow, cToRow
local nUCCIFromRow, nUCCIToRow

   // 构建移动编码
   nMove := nFromIdx + nToIdx * 256

   // 转换为UCCI字符串（使用新的转换函数）
   cFromCol := SubStr( xq_IdxToUCCIStr( nFromIdx ), 1, 1 )
   cFromRow := SubStr( xq_IdxToUCCIStr( nFromIdx ), 2 )
   cToCol := SubStr( xq_IdxToUCCIStr( nToIdx ), 1, 1 )
   cToRow := SubStr( xq_IdxToUCCIStr( nToIdx ), 2 )

   // 构建UCCI字符串
   cUCCI := cFromCol + cFromRow + cToCol + cToRow

RETURN cUCCI

/*
 * 显示棋盘字符串（调试用）
 *
 * 参数: 无 (使用全局变量 aBoardPos)
 * 返回: NIL
 */
static FUNCTION ShowBoardString()
local i, cText

   // 调用 xq_notation.prg 中的刷新函数来显示当前记谱法
   xq_Notation_Refresh()

RETURN NIL

/*
 * 添加记谱法记录
 *
 * 参数:
 *   cNotation - 记谱法字符串
 * 返回: NIL
 */
static FUNCTION AddToNotationWindow( cNotation, lIsRed )
   // 调用 xq_notation.prg 中的函数，传入是否是红方走法
   xq_Notation_Add( cNotation, lIsRed )
RETURN NIL

/*
 * 重新显示记谱法（按回合格式）
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION RefreshNotationWindow()
   // 调用 xq_notation.prg 中的函数
   xq_Notation_Refresh()
RETURN NIL

/*
 * 检查是否是当前玩家的棋子
 * 
 * 参数:
 *   cPiece - 棋子字符 (K, A, B, N, R, C, P 或 k, a, b, n, r, c, p)
 * 返回: .T. - 是当前玩家的棋子, .F. - 不是当前玩家的棋子
 */
static FUNCTION IsCurrentPlayerPiece( cPiece )
   LOCAL isRed := Upper( cPiece ) == cPiece  // 如果大写，则是红方

RETURN ( lRedTurn .AND. isRed ) .OR. ( !lRedTurn .AND. !isRed )

/*
 * 计算当前选中棋子的所有合法走法
 *
 * 参数: 无（使用全局变量 nSelectedRow, nSelectedCol, aBoardPos, lRedTurn）
 * 返回: NIL（结果保存在全局变量 aLegalMovePositions 中）
 */
static FUNCTION CalculateLegalMoves()
   LOCAL aPos, nFrom, nTo, nMove, i, j
   LOCAL aGUI

   // 清空合法走法列表
   aLegalMovePositions := {}

   // 检查是否有选中的棋子
   IF nSelectedRow == -1 .OR. nSelectedCol == -1
      RETURN NIL
   ENDIF

   // 转换为引擎格式
   aPos := BoardPosToPos()
   nFrom := xq_GUIToIdx( nSelectedRow, nSelectedCol )

   // 遍历所有可能的目标位置
   FOR i := 1 TO 10
      FOR j := 1 TO 9
         nTo := xq_GUIToIdx( i, j )
         // 跳过源位置
         IF nTo == nFrom
            LOOP
         ENDIF
         // 构建移动编码
         nMove := nFrom + nTo * 256
         // 检查移动是否合法
         IF xq_IsMoveCorrect( aPos, nMove )
            // 添加到合法走法列表
            AAdd( aLegalMovePositions, {i, j} )
         ENDIF
      NEXT
   NEXT

RETURN NIL

/*
 * 移动棋子
 *
 * 参数:
 *   nFromCol - 源位置列 (1-9)
 *   nFromRow - 源位置行 (1-10)
 *   nToCol - 目标位置列 (1-9)
 *   nToRow - 目标位置行 (1-10)
 * 返回: NIL
 */
static FUNCTION MovePiece( nFromCol, nFromRow, nToCol, nToRow )
   LOCAL cPiece, i, j
   LOCAL aState  // 保存当前状态
   LOCAL aTempBoard  // 临时棋盘数组
   LOCAL isCapture  // 是否吃子
   LOCAL aPosForCheck  // 用于将军检测的棋盘
   LOCAL aBoardForCheck  // 将军检测用的棋盘数组

   // 测试：在状态栏第三行显示移动信息
   xq_showstatusbar( 3, "MovePiece: (" + LTrim(Str(nFromCol)) + "," + LTrim(Str(nFromRow)) + ") -> (" + LTrim(Str(nToCol)) + "," + LTrim(Str(nToRow)) + ")" )

   cPiece := aBoardPos[nFromRow,nFromCol]

   // 保存移动前的完整状态（用于悔棋）
   aState := hb_hash()
   // 棋盘状态的深拷贝
   aTempBoard := Array( 10 )
   FOR i := 1 TO 10
      aTempBoard[i] := AClone( aBoardPos[i] )
   NEXT
   hb_HSet( aState, "board", aTempBoard )
   hb_HSet( aState, "turn", lRedTurn )
   hb_HSet( aState, "moveCount", nMoveCount )
   hb_HSet( aState, "halfMoveCount", nHalfMoveCount )
   hb_HSet( aState, "fullMoveCount", nFullMoveCount )
   hb_HSet( aState, "lastMoveCol", nLastMoveCol )
   hb_HSet( aState, "lastMoveRow", nLastMoveRow )
   hb_HSet( aState, "lastMoveFromCol", nLastMoveFromCol )
   hb_HSet( aState, "lastMoveFromRow", nLastMoveFromRow )
   // 保存完整的记谱法记录副本，而不是只保存长度
   hb_HSet( aState, "notationLog", xq_Notation_GetLog() )
   // 保存完整的FEN历史记录副本
   hb_HSet( aState, "fenHistory", AClone( aFenHistory ) )
   hb_HSet( aState, "consecutiveCheckCount", nConsecutiveCheckCount )
   AAdd( aMoveHistory, aState )

   // 判断是否吃子（目标位置是否为空）
   isCapture := (aBoardPos[nToRow,nToCol] != "0")
   
   // 将源位置设为空位 "0"，目标位置设为棋子
   aBoardPos[nFromRow,nFromCol] := "0"
   aBoardPos[nToRow,nToCol] := cPiece

   // 记录最后移动位置
   nLastMoveFromCol := nFromCol
   nLastMoveFromRow := nFromRow
   nLastMoveCol := nToCol
   nLastMoveRow := nToRow

   // 切换回合
   lRedTurn := !lRedTurn

   // 播放音效（先判断是否吃子）
   IF isCapture
      xq_PlaySound("capture", lSoundEnabled, nMoveCount)
   ELSE
      xq_PlaySound("move", lSoundEnabled, nMoveCount)
   ENDIF
   
   // 检查是否将军（需要转换棋盘格式）
   aPosForCheck := BoardPosToPos()
   aBoardForCheck := xq_StringToArray( aPosForCheck[POS_BOARD] )
   IF xq_IsKingInCheck(aBoardForCheck, lRedTurn)
      xq_PlaySound("check", lSoundEnabled, nMoveCount)
   ENDIF

   // 更新状态栏
   UpdateStatus()

   // 更新右侧窗口的记谱法显示（按回合格式）
   RefreshNotationWindow()

   // 重绘棋盘
   hwg_Invalidaterect( oChessBoard:handle )

RETURN .T.

/*
 * AI 走棋处理
 */
static FUNCTION AIMakeMove()
   LOCAL aPos, nMove, nFromIdx, nToIdx, nFromGUIRow, nFromGUICol, nToGUIRow, nToGUICol
   LOCAL lCurrentPlayerAI := .F.
   LOCAL cFen, aBoard, aBoardBeforeMove
   LOCAL i, cChar, nRow, nCol, nDebugUCCICol, nDebugUCCIRow
   LOCAL nPureMove, cICCS
   LOCAL lCurrentTurn                   // 当前回合（在切换回合之前保存）
   LOCAL aCheckPos, aCheckBoard, lOpponentInCheck, lCurrentInCheck  // 将死判断相关变量
   LOCAL nUCCIFromRow, nUCCIFromCol, nUCCIToRow, nUCCIToCol  // UCCI坐标转换
   LOCAL cUCCIFrom, cUCCITo, cUCCIMove, cChinese  // 走棋信息
   LOCAL j, nIdx, cRowStr  // 调试信息变量
   LOCAL nKingIdx, nKingRow, nKingCol, aKingRC  // 将王位置调试变量
   LOCAL nCheckIdx, cPiece  // 周围棋子检查变量
   LOCAL nCurrentAIPlayer  // 当前AI玩家（1=旧版引擎, 2=AI1, 3=AI2）
   LOCAL lAIEngineInitialized  // AI引擎初始化状态
   LOCAL isCapture, isPawn  // 吃子和走兵检测
   LOCAL cTarget  // 目标位置棋子
   LOCAL nCount  // 计数器
   LOCAL nPos1, nPos2, cFenBase  // FEN字段提取相关变量

   ShowDebugMsg( "=== AIMakeMove called ===", , LOG_LEVEL_DEBUG )
   ShowDebugMsg( "lRedTurn: " + Iif(lRedTurn, "RED", "BLACK"), , LOG_LEVEL_DEBUG )
   ShowDebugMsg( "nRedPlayer: " + LTrim(Str(nRedPlayer)) + ", nBlackPlayer: " + LTrim(Str(nBlackPlayer)), , LOG_LEVEL_DEBUG )

   // 检查 AI 是否已启用
   IF !lAIEnabled
      ShowDebugMsg( "AI disabled, not executing move" )
      lAITimerRunning := .F.
      RETURN NIL
   ENDIF

   // 防止重复触发：如果AI已经在运行，直接返回
   IF lAITimerRunning
      RETURN NIL
   ENDIF

   // 检查游戏是否还在运行（避免游戏结束后仍被调用）
   IF !lGameRunning
      RETURN NIL
   ENDIF

   // 设置运行标志
   lAITimerRunning := .T.

   // ShowDebugMsg( "=== AIMakeMove 开始 ===" )

   // 检查当前回合是否是 AI
   IF lRedTurn .AND. nRedPlayer > 1
      lCurrentPlayerAI := .T.
   ELSEIF !lRedTurn .AND. nBlackPlayer > 1
      lCurrentPlayerAI := .T.
   ENDIF

   IF !lCurrentPlayerAI
      ShowDebugMsg( "Not AI turn, exiting" )
      lAITimerRunning := .F.
      RETURN NIL
   ENDIF

   // 检查引擎是否已初始化（根据当前玩家选择象眼、AI1或AI2）
   // 注意：象眼引擎是内嵌的，已在程序启动时初始化，始终可用，不需要检查
   nCurrentAIPlayer := Iif(lRedTurn, nRedPlayer, nBlackPlayer)
   lAIEngineInitialized := .F.

   IF nCurrentAIPlayer == 2  // 象眼
      lAIEngineInitialized := .T.
   ELSEIF nCurrentAIPlayer == 3  // AI1
      IF !lAI1Initialized
         ShowDebugMsg( "AI1 engine not initialized, initializing..." )
         lAI1Initialized := xq_UCCI_InitAI1( GetGlobalConfig() )
         IF !lAI1Initialized
            ShowDebugMsg( "AI1 engine initialization failed" )
            lAITimerRunning := .F.
            RETURN NIL
         ENDIF
      ENDIF
      lAIEngineInitialized := lAI1Initialized
   ELSEIF nCurrentAIPlayer == 4  // AI2
      IF !lAI2Initialized
         ShowDebugMsg( "AI2 engine not initialized, initializing..." )
         lAI2Initialized := xq_AI2_Init( GetGlobalConfig() )
         IF !lAI2Initialized
            ShowDebugMsg( "AI2 engine initialization failed" )
            lAITimerRunning := .F.
            RETURN NIL
         ENDIF
      ENDIF
      lAIEngineInitialized := lAI2Initialized
   ELSE  // 默认使用 AI1
      IF !lAI1Initialized
         ShowDebugMsg( "AI1 engine not initialized, initializing..." )
         lAI1Initialized := xq_UCCI_InitAI1( GetGlobalConfig() )
         IF !lAI1Initialized
            ShowDebugMsg( "AI1 engine initialization failed" )
            lAITimerRunning := .F.
            RETURN NIL
         ENDIF
      ENDIF
      lAIEngineInitialized := lAI1Initialized
   ENDIF

   // 再次检查 AI 是否已启用（防止在等待期间被禁用）
   IF !lAIEnabled
      ShowDebugMsg( "AI disabled, canceling move" )
      cTempMsg := ""
      UpdateStatus()
      lAITimerRunning := .F.
      RETURN NIL
   ENDIF

   // 检查 AI 走棋次数限制（0表示不限制）
   IF nAIMaxMoves > 0 .AND. nMoveCount >= nAIMaxMoves
      ShowDebugMsg( "AI move count reached limit (" + Str(nAIMaxMoves) + " moves, " + Str(nAIMaxMoves/2) + " rounds), stopping AI" )
      ShowDebugMsg( "=== AI stopped ===" )
      cTempMsg := ""
      UpdateStatus()
      lAITimerRunning := .F.
      lAIEnabled := .F.  // 禁用 AI
      lGameRunning := .F.  // 停止游戏
      UpdateStatus()
      RETURN NIL
   ENDIF

   // 重置停止请求标志
   xq_UCCI_ResetStopRequest()

   // 转换为引擎位置结构
   aPos := BoardPosToPos()
   aBoard := xq_StringToArray( aPos[POS_BOARD] )

   cFen := xq_BoardToFenUCCI( aBoard, lRedTurn, nHalfMoveCount, nFullMoveCount )  // 使用 UCCI 兼容的完整 FEN 格式（包含回合数）

   // 获取 AI 的最佳走法
   // 状态栏显示AI思考提示
   cTempMsg := "AI thinking... (round " + LTrim(Str(Int((nMoveCount+1)/2))) + "-" + LTrim(Str(nMoveCount%2+1)) + ", Press F8 to stop)"
   UpdateStatus()

   // 调试：显示当前棋盘状态
   // ShowDebugMsg( "=== AI 思考前的棋盘状态 ===" )
   // ShowDebugMsg( "当前FEN: " + cFen )
   // ShowDebugMsg( "轮到: " + Iif(lRedTurn, "红方", "黑方") + " [回合:" + LTrim(Str(Int((nMoveCount+2)/2))) + "-" + Iif(nMoveCount%2==0, "1", "2") + "]" )

   // 检查当前回合是否被将军
   lCurrentInCheck := xq_IsKingInCheck( aBoard, lRedTurn )
   // ShowDebugMsg( "Current player in check: " + Iif(lCurrentInCheck, "Yes", "No") )
      
      // 检查对手是否被将军
      lOpponentInCheck := xq_IsKingInCheck( aBoard, !lRedTurn )
      // ShowDebugMsg( "Opponent in check: " + Iif(lOpponentInCheck, "Yes", "No") )

   // 根据当前玩家选择调用相应的引擎
   IF nCurrentAIPlayer == 2  // 象眼
      nMove := xq_Eleeye_GetBestMove( aPos, 5, cFen )
   ELSEIF nCurrentAIPlayer == 3  // AI1
      nMove := xq_UCCI_GetBestMoveAI1( GetGlobalConfig(), aPos, 5, cFen )
   ELSEIF nCurrentAIPlayer == 4  // AI2
      nMove := xq_AI2_GetBestMove( GetGlobalConfig(), aPos, 5, cFen )
   ELSE  // 默认使用 AI1
      nMove := xq_UCCI_GetBestMoveAI1( GetGlobalConfig(), aPos, 5, cFen )
   ENDIF

   // 调试：显示 AI 返回的结果
   ShowDebugMsg( "AI move code: " + Str(nMove) + " [FromIdx:" + LTrim(Str(Int(nMove % 256))) + "][ToIdx:" + LTrim(Str(Int(Int(nMove / 256) % 256))) + "][Col:" + LTrim(Str(Int(Int(nMove / 65536) % 16))) + "][Row:" + LTrim(Str(Int(Int(nMove / 1048576) % 16))) + "]" )

   // AI 思考完成后，清除状态栏临时消息
   cTempMsg := ""
   UpdateStatus()

   // AI 思考完成后，再次检查是否被禁用
   IF !lAIEnabled
      ShowDebugMsg( "AI disabled, move not executed" )
      lAITimerRunning := .F.
      RETURN NIL
   ENDIF

   IF nMove == 0
      ShowDebugMsg( "AI has no legal moves" )
      // ShowDebugMsg( "Checking if current player is checkmated..." )

      // 保存引擎日志（即使没有移动也保存）
      ShowEngineOutput( "AI返回: 0 (无合法移动)", "FEN: " + cFen )

      // 调试：显示棋盘字符串
      // ShowDebugMsg( "=== 棋盘详细状态 ===" )
      // ShowDebugMsg( "XQP: " + xq_ArrayToString( aBoard ) )  // 注释掉XQP输出

      // 调试：显示黑方将王周围的位置
      nKingIdx := xq_FindKing( aBoard, .F. )  // 找黑方将王
      IF nKingIdx > 0
         aKingRC := xq_IdxToGUI( nKingIdx )
         nKingRow := Int(aKingRC[1])
         nKingCol := Int(aKingRC[2])
         // ShowDebugMsg( "黑方将王位置: 索引=" + LTrim(Str(Int(nKingIdx))) + ", 行=" + LTrim(Str(nKingRow)) + ", 列=" + LTrim(Str(nKingCol)) )

         // 检查周围 8 个位置
         // ShowDebugMsg( "将王周围棋子:" )
         FOR i := nKingRow - 1 TO nKingRow + 1
            FOR j := nKingCol - 1 TO nKingCol + 1
               IF i >= 1 .AND. i <= 10 .AND. j >= 1 .AND. j <= 9
                  nCheckIdx := xq_GUIToIdx( i, j )
                  cPiece := aBoard[nCheckIdx]
                  // ShowDebugMsg( "  位置(" + LTrim(Str(i)) + "," + LTrim(Str(j)) + ")=" + cPiece + " (索引" + LTrim(Str(Int(nCheckIdx))) + ")" )
               ENDIF
            NEXT
         NEXT
      ENDIF

      // 中国象棋规则：
      // - 被将军且无合法走法 = 将死（判负）
      // - 未被将军但无合法走法 = 困毙（判负）
      // - 中国象棋没有"逼和"（和棋）这个说法
      IF xq_IsCheckmate( aBoard, lRedTurn )
                  ShowDebugMsg( "Checkmate! (King in check with no escape)" )
                  // 播放胜负音效
                  xq_PlaySound( Iif(lRedTurn, "loss", "win"), lSoundEnabled, nMoveCount)
                  ShowDebugMsg( "About to show Checkmate message box..." )
                  // 临时注释掉消息框，避免Windows下卡死
                  // hwg_MsgInfo( Iif(lRedTurn, _XQ_I__( "result.red_checkmated" ), _XQ_I__( "result.black_checkmated" )) )
                  ShowDebugMsg( "Checkmate message box skipped" )
      ELSE
         ShowDebugMsg( "Stalemate! (No legal moves)" )
         // 播放胜负音效
         xq_PlaySound( Iif(lRedTurn, "loss", "win"), lSoundEnabled, nMoveCount)
         ShowDebugMsg( "About to show Stalemate message box..." )
         // 临时注释掉消息框，避免Windows下卡死
         // hwg_MsgInfo( Iif(lRedTurn, _XQ_I__( "result.red_stalemate" ), _XQ_I__( "result.black_stalemate" )) )
         ShowDebugMsg( "Stalemate message box skipped" )
      ENDIF
      lAITimerRunning := .F.
      // 清除将死检查定时器，防止无限循环
      oCheckmateTimer := NIL
      // 停止游戏
      lGameRunning := .F.
      UpdateStatus()
      RETURN NIL
   ENDIF

   // 解析移动编码（1-based 索引）
   // 编码格式：nFromIdx(0-7位) + nToIdx(8-15位) + nFromCol(16-19位) + nFromRow(20-23位)
   nFromIdx := Int(nMove % 256)
   nToIdx := Int(Int(nMove / 256) % 256)
   nDebugUCCICol := Int(Int(nMove / 65536) % 16)
   nDebugUCCIRow := Int(Int(nMove / 1048576) % 16)
   ShowDebugMsg( "UCCI coords: col=" + LTrim(Str(nDebugUCCICol)) + " (0-8,a-i), row=" + LTrim(Str(nDebugUCCIRow)) + " (0-9,red base=9)" )
   ShowDebugMsg( "Array indices: From=" + LTrim(Str(Int(nFromIdx))) + ", To=" + LTrim(Str(Int(nToIdx))) + " (0-89, row-major 10x9)" )

   // 转换为行列坐标（返回1-based）
   // 使用正确的宽度：90元素数组用9，120元素数组用12
   nFromGUIRow := xq_ArrayIdxToRC_WithWidth( nFromIdx, Iif(Len(aBoard)==90, 9, 12) )[1]
   nFromGUICol := xq_ArrayIdxToRC_WithWidth( nFromIdx, Iif(Len(aBoard)==90, 9, 12) )[2]
   nToGUIRow := xq_ArrayIdxToRC_WithWidth( nToIdx, Iif(Len(aBoard)==90, 9, 12) )[1]
   nToGUICol := xq_ArrayIdxToRC_WithWidth( nToIdx, Iif(Len(aBoard)==90, 9, 12) )[2]
   ShowDebugMsg( "GUI coords: From(" + LTrim(Str(Int(nFromGUIRow))) + "," + LTrim(Str(Int(nFromGUICol))) + ") To(" + LTrim(Str(Int(nToGUIRow))) + "," + LTrim(Str(Int(nToGUICol))) + ") [row=1-10,top→down, col=1-9,left→right]" )

   // 转换为UCCI绝对坐标（列字母+行数字，从下到上）
   // GUI坐标（行1-10从上到下，列1-9从左到右）-> UCCI坐标（行0-9从下到上，列0-8从左到右）
   // UCCI行号 = 10 - GUI行号
   // UCCI列号 = GUI列号 - 1
   nUCCIFromRow := 10 - nFromGUIRow
   nUCCIFromCol := nFromGUICol - 1
   nUCCIToRow := 10 - nToGUIRow
   nUCCIToCol := nToGUICol - 1

   cUCCIFrom := Chr( Asc('a') + nUCCIFromCol ) + LTrim( Str( nUCCIFromRow ) )
   cUCCITo := Chr( Asc('a') + nUCCIToCol ) + LTrim( Str( nUCCIToRow ) )
   cUCCIMove := cUCCIFrom + cUCCITo

   // 解析移动编码（1-based 索引）
   cUCCIFrom := Chr( Asc('a') + nUCCIFromCol ) + LTrim( Str( nUCCIFromRow ) )
   cUCCITo := Chr( Asc('a') + nUCCIToCol ) + LTrim( Str( nUCCIToRow ) )
   cUCCIMove := cUCCIFrom + cUCCITo

   // 保存当前回合（在切换之前）
   lCurrentTurn := lRedTurn

   // 调试：输出移动前后的棋盘状态
   // ShowDebugMsg( "=== 移动前棋盘状态 ===" )
   // ShowDebugMsg( "XQP: " + xq_ArrayToString( aBoard ) )  // 注释掉XQP输出
   // ShowDebugMsg( "nFromIdx=" + LTrim(Str(Int(nFromIdx))) + ", nToIdx=" + LTrim(Str(Int(nToIdx))) )
   // ShowDebugMsg( "From: GUI(" + LTrim(Str(Int(nFromGUIRow))) + "," + LTrim(Str(Int(nFromGUICol))) + ") UCCI(" + LTrim(Str(Int(nUCCIFromCol))) + "," + LTrim(Str(Int(nUCCIFromRow))) + ")=" + cUCCIFrom )
   // ShowDebugMsg( "To:   GUI(" + LTrim(Str(Int(nToGUIRow))) + "," + LTrim(Str(Int(nToGUICol))) + ") UCCI(" + LTrim(Str(Int(nUCCIToCol))) + "," + LTrim(Str(Int(nUCCIToRow))) + ")=" + cUCCITo )
   // ShowDebugMsg( "棋子: " + Iif(Int(nFromIdx)>0 .AND. Int(nFromIdx)<=Len(aBoard), aBoard[Int(nFromIdx)], "N/A") + " -> " + Iif(Int(nToIdx)>0 .AND. Int(nToIdx)<=Len(aBoard), aBoard[Int(nToIdx)], "N/A") )

   // 保存移动前的棋盘状态（用于计算中国记谱法）
   aBoardBeforeMove := AClone( aBoard )

   // 检查目标位置是否有棋子（吃子）
   cTarget := aBoard[nToIdx]
   isCapture := (cTarget != "0")

   // 检查是否是兵/卒（走兵会重置半回合计数）
   cPiece := aBoard[nFromIdx]
   isPawn := (cPiece == "P" .OR. cPiece == "p")

   // 执行移动（传递1-based坐标：列，行）
   MovePiece( nFromGUICol, nFromGUIRow, nToGUICol, nToGUIRow )

   // 强制立即重绘主窗口（AI vs AI 模式下需要确保 GUI 实时更新）
   hwg_Redrawwindow( oMainWnd:handle, RDW_INVALIDATE + RDW_ERASE + RDW_UPDATENOW + RDW_ALLCHILDREN )

   // 处理 GTK 事件队列，确保重绘请求被立即处理
   hwg_ProcessMessage()

   // 清除选中状态
   nSelectedCol := -1
   nSelectedRow := -1

   // 重新获取移动后的棋盘状态（用于将军检测和FEN生成）
   aPos := BoardPosToPos()
   aBoard := xq_StringToArray( aPos[POS_BOARD] )

   // 显示真正的移动（使用纯移动编码）
   nPureMove := nFromIdx + nToIdx * 256
   cICCS := xq_MoveToICCS( nPureMove, Iif(Len(aBoard)==90, 9, 12) )
   
   // 根据语言选择记谱法
   IF lCurrentLanguage == "zh"
      cChinese := xq_MoveToChineseNotation( nPureMove, aBoardBeforeMove )
   ELSE
      cChinese := xq_MoveToEnglishNotation( nPureMove, aBoardBeforeMove )
   ENDIF
   
   // 增加 AI 走棋次数计数（在显示之前增加）
   nMoveCount++

   // 更新半回合计数（吃子或走兵时重置）
   IF isCapture .OR. isPawn
      nHalfMoveCount := 0
   ELSE
      nHalfMoveCount++
   ENDIF

   // 更新回合计数（黑方走完才+1）
   nFullMoveCount := Int((nMoveCount + 1) / 2)

   // 检查50回合规则（100半回合=50回合无吃子无动兵）
   IF nHalfMoveCount >= 100
      ShowDebugMsg( "50-move rule: Draw by insufficient material/no pawn moves!" )
      // 播放和棋音效
      xq_PlaySound( "draw", lSoundEnabled, nMoveCount)
      hwg_MsgInfo( _XQ_I__( "result.draw_50_moves" ) )
      lGameRunning := .F.
      lAITimerRunning := .F.
      oAITimer := NIL
      UpdateStatus()
      RETURN NIL
   ENDIF

   // 检查长将（连续6次将军即3个回合）
   IF xq_IsKingInCheck( aBoard, !lCurrentTurn )
      nConsecutiveCheckCount++
      ShowDebugMsg( "Consecutive Checks: " + LTrim(Str(nConsecutiveCheckCount)) )
      IF nConsecutiveCheckCount >= 6
         ShowDebugMsg( "Perpetual check! 6 consecutive checks prohibited!" )
         // 播放胜负音效
         xq_PlaySound( Iif(lCurrentTurn, "loss", "win"), lSoundEnabled, nMoveCount)
         hwg_MsgInfo( Iif(lCurrentTurn, _XQ_I__( "result.perpetual_check_red" ), _XQ_I__( "result.perpetual_check_black" )) )
         lGameRunning := .F.
         lAITimerRunning := .F.
         oAITimer := NIL
         UpdateStatus()
         RETURN NIL
      ENDIF
   ELSE
      nConsecutiveCheckCount := 0
   ENDIF

   // 检查三次重复局面
   cFen := xq_BoardToFenUCCI( aBoard, lRedTurn, nHalfMoveCount, nFullMoveCount )
   // 只提取FEN的前3个字段（棋盘状态、回合方、易位）进行比较，忽略半回合计数和回合计数
   // FEN格式: <board> <turn> <castling> <en_passant> <half_move> <full_move>
   nPos1 := At( " ", cFen )
   nPos2 := At( " ", SubStr( cFen, nPos1 + 1 ) )
   cFenBase := Left( cFen, nPos1 + nPos2 )
   AAdd( aFenHistory, cFenBase )
   IF Len( aFenHistory ) > nMaxFenHistory
      ADel( aFenHistory, 1 )
   ENDIF
   nCount := 0
   FOR i := Len( aFenHistory ) TO 1 STEP -1
      IF aFenHistory[i] == cFenBase
         nCount++
      ENDIF
   NEXT
   IF nCount >= 3
      ShowDebugMsg( "Threefold repetition! Draw!" )
      // 播放和棋音效
      xq_PlaySound( "draw", lSoundEnabled, nMoveCount)
      hwg_MsgInfo( _XQ_I__( "result.draw_repetition" ) )
      lGameRunning := .F.
      lAITimerRunning := .F.
      oAITimer := NIL
      UpdateStatus()
      RETURN NIL
   ENDIF

   // 显示AI走棋信息（使用走棋前的回合lCurrentTurn）
   // 回合数显示格式：[round:X-Y]，X=总回合数（从1开始），Y=步数（1=红方走，2=黑方走）
   IF lCurrentTurn  // 红方走棋
      ShowDebugMsg( "AI (RED) " + cICCS + " (" + cChinese + ") [round:" + LTrim(Str(Int((nMoveCount+1)/2))) + "-1]", , LOG_LEVEL_INFO )
   ELSE  // 黑方走棋
      ShowDebugMsg( "AI (BLACK) " + cICCS + " (" + cChinese + ") [round:" + LTrim(Str(Int(nMoveCount/2))) + "-2]", , LOG_LEVEL_INFO )
   ENDIF

   // 记录最近的走法到状态栏
   cLastMove := cICCS + " (" + cChinese + ")"

   // 添加到中国记谱法窗口（使用新的 API，内部计算记谱法）
   xq_Notation_AddMove( nPureMove, lCurrentTurn, aBoardBeforeMove )

   // 显示 FEN 到调试窗口（与人走棋保持一致）
   ShowFen()

   // 重新计算移动后的 FEN（因为 MovePiece 已经切换了回合）
   aPos := BoardPosToPos()
   aBoard := xq_StringToArray( aPos[POS_BOARD] )
   cFen := xq_BoardToFenUCCI( aBoard, lRedTurn, nHalfMoveCount, nFullMoveCount )

   // 显示引擎输出信息到 oEngineOutput
   ShowEngineOutput( _XQ_I__( "engine.ucci_coordinate" ) + " " + cUCCIMove, _XQ_I__( "engine.fen" ) + " " + cFen )

   // 强制立即重绘GUI（AI vs AI模式下，确保界面实时更新）
   // hwg_Redrawwindow 用法说明：
   // 参数1：窗口句柄
   // 参数2：重绘标志（使用 RDW_UPDATENOW 强制立即更新）
   // 标志含义：
   //   RDW_INVALIDATE(1) - 使窗口区域无效
   //   RDW_ERASE(4) - 擦除背景
   //   RDW_UPDATENOW(256) - 立即更新，不等待消息队列
   hwg_Redrawwindow( oMainWnd:handle, RDW_INVALIDATE + RDW_UPDATENOW )

   // 触发异步将死检查
   TriggerCheckmateCheck( aBoard, lCurrentTurn )

   // 检查是否需要触发对方AI走棋
   // 添加 lGameRunning 检查，避免异步检查已经设置游戏结束标志后仍然创建 AI Timer
   IF lGameRunning .AND. lAIEnabled
      // 重置AI计时器，防止重复触发（HTimer没有Destroy方法，只需设为NIL）
      oAITimer := NIL

      IF lCurrentTurn .AND. nBlackPlayer > 1
         // 红方刚走完，现在轮到黑方走（第nMoveCount+1步）
         IF (nMoveCount + 1) % 2 == 1
            ShowDebugMsg( "AI (RED) thinking... [round:" + LTrim(Str(Int(((nMoveCount+1)+1)/2))) + "-1]" )
         ELSE
            ShowDebugMsg( "AI (BLACK) thinking... [round:" + LTrim(Str(Int((nMoveCount+1)/2))) + "-2]" )
         ENDIF
         oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
      ELSEIF !lCurrentTurn .AND. nRedPlayer > 1
         // 黑方刚走完，现在轮到红方走（第nMoveCount+1步）
         IF (nMoveCount + 1) % 2 == 1
            ShowDebugMsg( "AI (RED) thinking... [round:" + LTrim(Str(Int(((nMoveCount+1)+1)/2))) + "-1]" )
         ELSE
            ShowDebugMsg( "AI (BLACK) thinking... [round:" + LTrim(Str(Int((nMoveCount+1)/2))) + "-2]" )
         ENDIF
         oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
      ENDIF
   ENDIF

   // 重置运行标志
   lAITimerRunning := .F.

RETURN NIL

/*
 * 显示引擎输出信息
 *
 * 参数: 可变参数，每个参数都是一行输出
 * 返回: NIL
 */
static FUNCTION ShowEngineOutput( ... )
local cText, i
local aParams := hb_AParams()
local aInterfaceLog, j, nStart, nCount

   IF !Empty( oEngineOutput )
      cText := _XQ_I__( "engine.output" ) + CRLF

      // 显示引擎状态（根据当前游戏模式）
      IF nRedPlayer > 1 .OR. nBlackPlayer > 1
         cText += _XQ_I__( "engine.status_enabled" ) + CRLF
      ELSE
         cText += _XQ_I__( "engine.status_disabled" ) + CRLF
      ENDIF
      cText += CRLF
   // 引擎接口日志现在通过 xq_UCCILogMessage 实时写入文件和显示

      // 添加走棋信息
      FOR i := 1 TO Len( aParams )
         IF ValType( aParams[i] ) == "C"
            cText += aParams[i] + CRLF
         ENDIF
      NEXT
      oEngineOutput:SetText( cText )
      // 强制刷新 EDITBOX，确保立即显示
      hwg_InvalidateRect( oEngineOutput:handle )
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 创建状态栏控件
 *
 * 创建三个 SAY 控件：
 * - 状态栏第一行：显示"等待开局"或"红方走棋/黑方走棋"
 * - 状态栏第二行：显示走法信息或临时消息
 * - 调试追踪信息：显示调试追踪信息
 *
 * 参数: 无
 * 返回: NIL
 */
/*
 * 创建状态栏控件
 *
 * 创建状态栏的三行控件（第一行、第二行、调试追踪）
 * 根据调试模式动态调整宽度
 *
 * 返回: NIL
 */
static FUNCTION create_statusbar()
   LOCAL l_nStatusBarWidth

   // 根据调试模式选择状态栏宽度
   l_nStatusBarWidth := iif( lDebugMode, XQ_STATUSBAR_WIDTH_DEBUG, XQ_STATUSBAR_WIDTH_NORMAL )

   // 创建状态栏第一行
   @ XQ_STATUSBAR_START_X, XQ_STATUSBAR_Y SAY oStatusBarLine1 CAPTION "" OF oMainWnd ;
      SIZE l_nStatusBarWidth, XQ_STATUSBAR_LINE1_HEIGHT ;
      FONT oFontMain COLOR XQ_CLR_WHITE ;
      BACKCOLOR XQ_CLR_GBROWN

   // 创建状态栏第二行
   @ XQ_STATUSBAR_START_X, XQ_STATUSBAR_Y + XQ_STATUSBAR_LINE1_HEIGHT SAY oStatusBarLine2 CAPTION "" OF oMainWnd ;
      SIZE l_nStatusBarWidth, XQ_STATUSBAR_LINE2_HEIGHT ;
      FONT oFontMain COLOR XQ_CLR_WHITE ;
      BACKCOLOR XQ_CLR_GBROWN

   // 创建调试追踪信息
   @ XQ_STATUSBAR_START_X, XQ_STATUSBAR_Y + XQ_STATUSBAR_LINE1_HEIGHT + XQ_STATUSBAR_LINE2_HEIGHT SAY oTraceText CAPTION "" OF oMainWnd ;
      SIZE l_nStatusBarWidth, XQ_STATUSBAR_TRACE_HEIGHT ;
      FONT oFontMain COLOR XQ_CLR_WHITE ;
      BACKCOLOR XQ_CLR_GBROWN

RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 绘制调试边框
 *
 * 在调试模式下为各个窗口控件绘制边框，便于观察布局
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION draw_debug_borders_on_dc( hDC )
   LOCAL l_oPen, l_nColor
   LOCAL l_nStatusBarWidth

   IF hDC == NIL
      RETURN NIL
   ENDIF

   // 创建红色画笔
   l_oPen := HPen():Add( PS_SOLID, 2, 0xFF0000 )

   // 绘制棋盘边框
   hwg_SelectObject( hDC, l_oPen:handle )
   hwg_Rectangle( hDC, XQ_BOARD_START_X, XQ_BOARD_START_Y, XQ_BOARD_START_X + XQ_BOARD_WIDTH, XQ_BOARD_START_Y + XQ_BOARD_HEIGHT )

   // 绘制记谱法窗口边框
   hwg_Rectangle( hDC, XQ_RIGHT_START_X, XQ_BOARD_START_Y, XQ_RIGHT_START_X + XQ_RIGHT_COL1_WIDTH, XQ_BOARD_START_Y + XQ_RIGHT_BOTTOM_HEIGHT )

   // 绘制引擎输出窗口边框
   hwg_Rectangle( hDC, XQ_RIGHT_START_X, XQ_BOARD_START_Y + XQ_RIGHT_BOTTOM_HEIGHT + 20, XQ_RIGHT_START_X + XQ_RIGHT_COL1_WIDTH, XQ_BOARD_START_Y + XQ_RIGHT_BOTTOM_HEIGHT + 20 + XQ_RIGHT_BOTTOM_HEIGHT )

   // 绘制消息调试窗口边框（仅调试模式）
   IF lDebugMode
      hwg_Rectangle( hDC, XQ_RIGHT_COL3_START, XQ_BOARD_START_Y, XQ_RIGHT_COL3_START + XQ_RIGHT_COL3_WIDTH, XQ_BOARD_START_Y + XQ_BOARD_HEIGHT )
   ENDIF

   // 绘制状态栏边框
   l_nStatusBarWidth := iif( lDebugMode, XQ_STATUSBAR_WIDTH_DEBUG, XQ_STATUSBAR_WIDTH_NORMAL )
   hwg_Rectangle( hDC, XQ_STATUSBAR_START_X, XQ_STATUSBAR_Y, XQ_STATUSBAR_START_X + l_nStatusBarWidth, XQ_STATUSBAR_Y + XQ_STATUSBAR_LINE1_HEIGHT + XQ_STATUSBAR_LINE2_HEIGHT + XQ_STATUSBAR_TRACE_HEIGHT )

   // 释放资源
   l_oPen:Release()

RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 更新状态栏文本
 *
 * 封装状态栏控件的更新操作，避免其他代码直接访问控件引用
 *
 * 参数:
 *   par_nLine - 行号：1=状态栏第一行, 2=状态栏第二行, 3=调试追踪
 *   par_cText - 要显示的文本
 * 返回: NIL
 */
static FUNCTION xq_showstatusbar( par_nLine, par_cText )
   local l_cDisplayText

   l_cDisplayText := "[" + LTrim(Str(par_nLine)) + "] " + par_cText

   IF par_nLine == 1 .AND. !Empty( oStatusBarLine1 )
      oStatusBarLine1:SetText( l_cDisplayText )
   ELSEIF par_nLine == 2 .AND. !Empty( oStatusBarLine2 )
      oStatusBarLine2:SetText( l_cDisplayText )
   ELSEIF par_nLine == 3 .AND. !Empty( oTraceText )
      oTraceText:SetText( l_cDisplayText )
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 更新状态栏（两行显示）
 *
 * 第一行：显示"等待开局"或"红方走棋/黑方走棋"以及玩家类型
 * 第二行：显示走法信息或临时消息
 *
 * 参数: 无 (使用全局变量 oStatusBarLine1, oStatusBarLine2, lRedTurn, lGameRunning, cLastMove, cTempMsg, nRedPlayer, nBlackPlayer)
 * 返回: NIL
 */
static FUNCTION UpdateStatus()
local cLine1, cLine2, cPlayerInfo, cRedPlayerType, cBlackPlayerType

   // 生成玩家类型信息（支持四种类型：1=人, 2=象眼, 3=AI1, 4=AI2）
   cRedPlayerType := Iif(nRedPlayer==1, "Human", Iif(nRedPlayer==2, "ElephantEye", "AI"+LTrim(Str(nRedPlayer-2))))
   cBlackPlayerType := Iif(nBlackPlayer==1, "Human", Iif(nBlackPlayer==2, "ElephantEye", "AI"+LTrim(Str(nBlackPlayer-2))))
   cPlayerInfo := "[Red:" + cRedPlayerType + " Black:" + cBlackPlayerType + "]"

   // 检查游戏是否运行中
   IF !lGameRunning
      // 游戏未开始：玩家信息在前，其他信息在后
      cLine1 := cPlayerInfo + " Waiting for game start"
      // 第二行：优先显示临时消息，否则显示提示
      IF !Empty( cTempMsg )
         cLine2 := cTempMsg
      ELSE
         cLine2 := "Please select [New Game] to start"
      ENDIF
   ELSE
      // 游戏进行中：玩家信息在前，其他信息在后
      cLine1 := cPlayerInfo + " " + Iif( lRedTurn, "Red's turn", "Black's turn" )
      // 第二行：优先显示临时消息，否则显示走法
      IF !Empty( cTempMsg )
         cLine2 := cTempMsg
      ELSEIF !Empty( cLastMove )
         cLine2 := cLastMove
      ELSE
         cLine2 := ""
      ENDIF
   ENDIF

   // 使用封装函数更新状态栏
   xq_showstatusbar( 1, cLine1 )
   xq_showstatusbar( 2, cLine2 )

RETURN NIL

/*
 * 在调试窗口显示调试信息（使用 Browse 控件）
 */
function ShowDebugMsg( cMsg, nColor, nLogLevel )
   // 只有在调试模式下才显示消息
   IF lDebugMode
      // 输出到 message 窗口
      XQ_MsgWnd_ShowMsg( cMsg, nColor )
      // 同步输出到终端
      OutErr( cMsg, hb_eol() )
      
      // 写入日志系统（默认 INFO 级别）
      nLogLevel := iif( HB_ISNUMERIC( nLogLevel ), nLogLevel, LOG_LEVEL_INFO )
      xq_Log_WriteInternal( nLogLevel, "GAME", cMsg )
   ENDIF
   
RETURN NIL

/*
 * 显示引擎输出信息（FEN 格式和引擎状态）
 */
static FUNCTION ShowFen()
local aPos, aBoard, cFen, cText

   // 从 GUI 棋盘状态转换为引擎位置结构
   aPos := BoardPosToPos()
   aBoard := xq_StringToArray( aPos[POS_BOARD] )

   // 调试：显示棋盘字符串
   // ShowDebugMsg( "XQP: " + aPos[POS_BOARD] )  // 注释掉XQP输出

   cFen := xq_BoardToFenUCCI( aBoard, lRedTurn, nHalfMoveCount, nFullMoveCount )
   // 输出 FEN 到调试文本框
   ShowDebugMsg( "FEN: " + cFen, , LOG_LEVEL_INFO )

   // 只在 AI 模式下显示引擎输出信息
   IF !Empty( oEngineOutput ) .AND. (nRedPlayer > 1 .OR. nBlackPlayer > 1)
      cText := _XQ_I__( "engine.output" ) + CRLF
      cText += _XQ_I__( "engine.status_enabled" ) + CRLF
      cText += _XQ_I__( "engine.current_turn" ) + " " + Iif(lRedTurn, _XQ_I__( "side.red" ), _XQ_I__( "side.black" )) + CRLF
      cText += _XQ_I__( "engine.fen_position" ) + " " + cFen + CRLF
      oEngineOutput:SetText( cText )
   ENDIF

RETURN NIL

/*
 * 返回: NIL
 */
static FUNCTION NewGame()

   // 清空消息窗口
   XQ_MsgWnd_Clear()

   // 清空中国记谱法窗口
   xq_Notation_Clear()
   aMoveHistory := {}  // 清空移动历史记录

   // 清空引擎输出窗口
   IF !Empty( oEngineOutput )
      oEngineOutput:SetText( _XQ_I__( "engine.output" ) + CRLF )
      // 根据当前游戏模式显示引擎状态
      IF nRedPlayer > 1 .OR. nBlackPlayer > 1
         oEngineOutput:SetText( oEngineOutput:GetText() + _XQ_I__( "engine.status_enabled" ) + CRLF )
      ELSE
         oEngineOutput:SetText( oEngineOutput:GetText() + _XQ_I__( "engine.status_disabled" ) + CRLF )
      ENDIF
   ENDIF

   // 清空状态栏变量
   cLastMove := ""
   cTempMsg := ""

   // 清除将死检查定时器
   oCheckmateTimer := NIL

   // 重置 AI 走棋计数器
   nMoveCount := 0
   nHalfMoveCount := 0
   nFullMoveCount := 1

   // 重置长将和FEN历史
   nConsecutiveCheckCount := 0
   aFenHistory := {}

   // 重置 AI 启用标志
   lAIEnabled := .T.

   SetupBoard()
   nSelectedCol := -1
   nSelectedRow := -1
   nLastMoveCol := -1
   nLastMoveRow := -1
   nLastMoveFromCol := -1
   nLastMoveFromRow := -1
   lRedTurn := .T.
   lGameRunning := .T.  // 游戏开始运行
   hwg_Invalidaterect( oChessBoard:handle )

   // 播放新游戏音效
   xq_PlaySound("newgame", lSoundEnabled, nMoveCount)

   ShowDebugMsg( "=== New Game Started ===", , LOG_LEVEL_INFO )
   ShowDebugMsg( "Player mode: RED=" + Iif(nRedPlayer==1,"HUMAN","AI") + " vs BLACK=" + Iif(nBlackPlayer==1,"HUMAN","AI"), , LOG_LEVEL_INFO )

   // 显示 FEN 格式（所有模式都显示，方便调试）
   ShowFen()

   // AI 模式才显示棋盘字符串
   IF nRedPlayer > 1 .OR. nBlackPlayer > 1
      ShowBoardString()  // 显示棋盘字符串
   ENDIF

   // 如果 AI 先手，触发 AI 走棋
   IF nRedPlayer > 1 .AND. lRedTurn
      // 重置AI计时器（HTimer没有Destroy方法，只需设为NIL）
      oAITimer := NIL
      ShowDebugMsg( "AI (RED) to move first, waiting..." )
      oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
   ENDIF

   // 设置消息窗口焦点到最后一行
   XQ_MsgWnd_ScrollBottom()

RETURN NIL

/*
 * 停止 AI 对战
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION StopAI()

   // 禁用 AI
   lAIEnabled := .F.

   // 请求停止 UCCI 引擎思考
   xq_UCCI_RequestStop()

   // 清除状态栏临时消息
   cTempMsg := ""
   UpdateStatus()

   // 清除 AI 计时器
   oAITimer := NIL

   // 重置运行标志
   lAITimerRunning := .F.

   // 显示提示信息
   XQ_MsgWnd_ShowMsg( _XQ_I__( "status.ai_stopped" ) )
   hwg_MsgInfo( _XQ_I__( "error.ai_stopped" ) )

   // 将双方玩家改为人类
   nRedPlayer := 1
   nBlackPlayer := 1

   UpdateStatus()

RETURN NIL

//--------------------------------------------------------------------------------
/**
 * 认输
 * @return NIL
 */
static FUNCTION ResignGame()

   LOCAL lConfirm

   // 检查游戏是否正在进行
   IF !lGameRunning
      RETURN NIL
   ENDIF

   // 显示确认对话框
   lConfirm := hwg_MsgYesNo( _XQ_I__( "message.resign_confirm" ), _XQ_I__( "button.resign" ) )

   IF lConfirm
      // 停止 AI 思考
      xq_UCCI_RequestStop()

      // 结束游戏
      lGameRunning := .F.

      // 停止 AI 计时器
      oAITimer := NIL
      lAITimerRunning := .F.

      // 播放输棋音效
      xq_PlaySound( "loss", lSoundEnabled, nMoveCount )

      // 显示认输结果
      IF lRedTurn
         XQ_MsgWnd_ShowMsg( _XQ_I__( "message.resign_red" ) )
         hwg_MsgInfo( _XQ_I__( "message.resign_red" ) )
      ELSE
         XQ_MsgWnd_ShowMsg( _XQ_I__( "message.resign_black" ) )
         hwg_MsgInfo( _XQ_I__( "message.resign_black" ) )
      ENDIF

      // 更新状态栏
      UpdateStatus()
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------
/**
 * 停止游戏
 * @return NIL
 */
static FUNCTION StopGame()

   LOCAL lConfirm

   // 检查游戏是否正在进行
   IF !lGameRunning
      RETURN NIL
   ENDIF

   // 显示确认对话框
   lConfirm := hwg_MsgYesNo( _XQ_I__( "message.stop_game_confirm" ), _XQ_I__( "button.stop_game" ) )

   IF lConfirm
      // 停止 AI 思考
      xq_UCCI_RequestStop()

      // 结束游戏
      lGameRunning := .F.

      // 停止 AI 计时器
      oAITimer := NIL
      lAITimerRunning := .F.

      // 清除状态栏临时消息
      cTempMsg := ""

      // 更新状态栏
      UpdateStatus()

      XQ_MsgWnd_ShowMsg( _XQ_I__( "status.waiting" ) )
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------
/**
 * 退出游戏
 * @return NIL
 */
static FUNCTION ExitGame()

   LOCAL lConfirm

   // 显示确认对话框
   lConfirm := hwg_MsgYesNo( _XQ_I__( "message.exit_confirm" ), _XQ_I__( "menu.exit" ) )

   IF lConfirm
      // 停止 AI
      xq_UCCI_RequestStop()

      // 关闭引擎
      xq_UCCI_CloseAI1()
      xq_AI2_Close()

      // 关闭窗口
      hwg_EndWindow()
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------
/**
 * 切换语言
 * @return NIL
 */
static FUNCTION ChangeLanguage()

   LOCAL oDlg, oComboLanguage, oBtnOK, oBtnCancel
   LOCAL aLanguageList := { "English", "中文" }
   LOCAL cCurrentLanguage
   LOCAL nLanguage

   // 从配置文件读取当前语言
   cCurrentLanguage := xq_ConfigGet( "MAIN", "Language", "English" )
   nLanguage := Iif(cCurrentLanguage=="English", 1, 2)

   // 创建对话框（居中显示）
   INIT DIALOG oDlg TITLE _XQ_I__( "menu.language" ) ;
      AT (hwg_GetDesktopWidth()-300)/2, (hwg_GetDesktopHeight()-150)/2 SIZE 300, 150

   @ 50, 30 SAY _XQ_I__( "label.language" ) SIZE 80, 20 OF oDlg
#ifdef __PLATFORM__UNIX
   @ 100, 30 GET COMBOBOX oComboLanguage VAR nLanguage ITEMS aLanguageList SIZE 120, 25 OF oDlg
#else
   @ 100, 30 GET COMBOBOX oComboLanguage VAR nLanguage ITEMS aLanguageList SIZE 120, 100 OF oDlg
#endif

   // 确定按钮
   @ 80, 90 BUTTON oBtnOK CAPTION _XQ_I__( "button.ok" ) SIZE 80, 30 OF oDlg ;
      ON CLICK {||SaveLanguageSelection(oComboLanguage:Value()), hwg_EndDialog()}

   // 取消按钮
   @ 180, 90 BUTTON oBtnCancel CAPTION _XQ_I__( "button.cancel" ) SIZE 80, 30 OF oDlg ;
      ON CLICK {||hwg_EndDialog()}

   ACTIVATE DIALOG oDlg

RETURN NIL

//--------------------------------------------------------------------------------
/**
 * 保存语言选择
 * @return NIL
 */
static FUNCTION SaveLanguageSelection(nSelection)

   LOCAL cNewLanguage
   LOCAL cCurrentLanguage

   // 从配置文件读取当前语言
   cCurrentLanguage := xq_ConfigGet( "MAIN", "Language", "English" )

   IF nSelection == 1
      cNewLanguage := "English"
   ELSE
      cNewLanguage := "中文"
   ENDIF

   // 如果语言没有改变，不做任何操作
   IF cNewLanguage == cCurrentLanguage
      RETURN NIL
   ENDIF

   // 保存到配置文件
   xq_ConfigSet( "MAIN", "Language", cNewLanguage )

   // 提示用户需要重启
   hwg_MsgInfo( _XQ_I__( "message.language_changed" ) )

RETURN NIL

//--------------------------------------------------------------------------------
/**
 * 显示关于对话框
 * @return NIL
 */
static FUNCTION ShowAbout()

   hwg_MsgInfo( _XQ_I__( "message.about" ), _XQ_I__( "menu.about" ) )

RETURN NIL

//--------------------------------------------------------------------------------
/*
 * 悔棋
 */
static FUNCTION UndoMove()
   LOCAL aState, i
   LOCAL aTempBoard, aSavedNotationLog, aSavedFenHistory

   // 检查是否有历史记录
   IF Len( aMoveHistory ) == 0
      hwg_MsgInfo( _XQ_I__( "error.no_undo" ) )
      RETURN NIL
   ENDIF

   // 如果游戏已结束，不允许悔棋
   IF !lGameRunning
      hwg_MsgInfo( _XQ_I__( "error.game_over" ) )
      RETURN NIL
   ENDIF

   // 获取上一步的状态
   aState := ATail( aMoveHistory )

   // 检查aState是否有效
   IF ValType( aState ) != "H"
      hwg_MsgInfo( _XQ_I__( "error.undo_failed_history" ) )
      RETURN NIL
   ENDIF

   // 恢复棋盘状态
   aTempBoard := hb_HGet( aState, "board" )
   IF ValType( aTempBoard ) == "A" .AND. Len( aTempBoard ) == 10
      FOR i := 1 TO 10
         aBoardPos[i] := AClone( aTempBoard[i] )
      NEXT
   ELSE
      hwg_MsgInfo( _XQ_I__( "error.undo_failed_board" ) )
      RETURN NIL
   ENDIF

   // 恢复回合和计数器
   lRedTurn := hb_HGet( aState, "turn" )
   nMoveCount := hb_HGet( aState, "moveCount" )
   nHalfMoveCount := hb_HGet( aState, "halfMoveCount" )
   nFullMoveCount := hb_HGet( aState, "fullMoveCount" )

   // 恢复最后移动位置
   nLastMoveCol := hb_HGet( aState, "lastMoveCol" )
   nLastMoveRow := hb_HGet( aState, "lastMoveRow" )
   nLastMoveFromCol := hb_HGet( aState, "lastMoveFromCol" )
   nLastMoveFromRow := hb_HGet( aState, "lastMoveFromRow" )

   // 恢复记谱法记录（直接使用保存的副本）
   aSavedNotationLog := hb_HGet( aState, "notationLog" )
   IF ValType( aSavedNotationLog ) == "A"
      xq_Notation_SetLog( aSavedNotationLog )
   ENDIF

   // 恢复FEN历史记录（直接使用保存的副本）
   aSavedFenHistory := hb_HGet( aState, "fenHistory" )
   IF ValType( aSavedFenHistory ) == "A"
      aFenHistory := AClone( aSavedFenHistory )
   ENDIF

   // 恢复连续将军计数
   nConsecutiveCheckCount := hb_HGet( aState, "consecutiveCheckCount" )

   // 从历史记录中删除最后一步
   IF Len( aMoveHistory ) > 0
      ASize( aMoveHistory, Len( aMoveHistory ) - 1 )
   ENDIF

   // 清除选中状态
   nSelectedCol := -1
   nSelectedRow := -1

   // 更新状态栏
   UpdateStatus()

   // 更新记谱法窗口显示
   RefreshNotationWindow()

   // 重绘棋盘
   hwg_Invalidaterect( oChessBoard:handle )

   ShowDebugMsg( "Undo successful" )

RETURN NIL

/*
 * 选择玩家
 */
static FUNCTION Game_Players()

   LOCAL oDlg, oComboRed, oComboBlack, oBtnOK, oBtnCancel
   LOCAL aPlayerList := { _XQ_I__( "player.human" ), _XQ_I__( "player.elephanteye" ), "AI1", "AI2" }

   // 创建对话框（居中显示）
   INIT DIALOG oDlg TITLE _XQ_I__( "dialog.select_players" ) ;
      AT (hwg_GetDesktopWidth()-300)/2, (hwg_GetDesktopHeight()-200)/2 SIZE 300, 200

   // 红方选择（直接使用全局变量）
   @ 20, 20 SAY _XQ_I__( "label.red" ) SIZE 80, 20 OF oDlg
#ifdef __PLATFORM__UNIX
   @ 100, 20 GET COMBOBOX oComboRed VAR nRedPlayer ITEMS aPlayerList SIZE 120, 25 OF oDlg
#else
   @ 100, 20 GET COMBOBOX oComboRed VAR nRedPlayer ITEMS aPlayerList SIZE 120, 120 OF oDlg
#endif

   // 黑方选择（直接使用全局变量）
   @ 20, 60 SAY _XQ_I__( "label.black" ) SIZE 80, 20 OF oDlg
#ifdef __PLATFORM__UNIX
   @ 100, 60 GET COMBOBOX oComboBlack VAR nBlackPlayer ITEMS aPlayerList SIZE 120, 25 OF oDlg
#else
   @ 100, 60 GET COMBOBOX oComboBlack VAR nBlackPlayer ITEMS aPlayerList SIZE 120, 120 OF oDlg
#endif

   // 确定按钮
   @ 50, 130 BUTTON oBtnOK CAPTION _XQ_I__( "button.ok" ) SIZE 80, 30 OF oDlg ;
      ON CLICK {||SavePlayerSelection(oComboRed:Value(), oComboBlack:Value()), hwg_EndDialog()}

   // 取消按钮
   @ 150, 130 BUTTON oBtnCancel CAPTION _XQ_I__( "button.cancel" ) SIZE 80, 30 OF oDlg ;
      ON CLICK {||hwg_EndDialog()}

   ACTIVATE DIALOG oDlg

RETURN NIL

/*
 * 保存玩家选择并初始化 AI 引擎
 */
static FUNCTION SavePlayerSelection(nRed, nBlack)
   LOCAL lNeedNewGame := .F.
   LOCAL i, j, cBoardStr
   LOCAL lRedAI := .F., lBlackAI := .F.
   LOCAL lAIForcedToHuman := .F.  // 记录是否有AI被强制转为HUMAN

   // 检查棋盘是否已初始化
   IF !Empty(aBoardPos)
      cBoardStr := ""
      FOR i := 1 TO 10
         FOR j := 1 TO 9
            cBoardStr += aBoardPos[i][j]
         NEXT
      NEXT
      // 如果棋盘全是"0"，说明未初始化
      IF AllTrim(StrTran(cBoardStr, "0", "")) == ""
         lNeedNewGame := .T.
      ENDIF
   ELSE
      lNeedNewGame := .T.
   ENDIF

   // 检查选择的AI是否已配置
   IF nRed == 2  // 象眼（内嵌引擎，始终可用）
      lRedAI := .T.
   ELSEIF nRed == 3  // AI1
      IF !GetGlobalConfig()["AI1Enabled"] .OR. Empty(GetGlobalConfig()["AI1EnginePath"])
         ShowDebugMsg( "AI1 not configured, forced to HUMAN")
         nRed := 1
         lAIForcedToHuman := .T.
      ELSE
         lRedAI := .T.
      ENDIF
   ELSEIF nRed == 4  // AI2
      IF !GetGlobalConfig()["AI2Enabled"] .OR. Empty(GetGlobalConfig()["AI2EnginePath"])
         ShowDebugMsg( "AI2 not configured, forced to HUMAN")
         nRed := 1
         lAIForcedToHuman := .T.
      ELSE
         lRedAI := .T.
      ENDIF
   ENDIF

   IF nBlack == 2  // 象眼（内嵌引擎，始终可用）
      lBlackAI := .T.
   ELSEIF nBlack == 3  // AI1
      IF !GetGlobalConfig()["AI1Enabled"] .OR. Empty(GetGlobalConfig()["AI1EnginePath"])
         ShowDebugMsg( "AI1 not configured, forced to HUMAN")
         nBlack := 1
         lAIForcedToHuman := .T.
      ELSE
         lBlackAI := .T.
      ENDIF
   ELSEIF nBlack == 4  // AI2
      IF !GetGlobalConfig()["AI2Enabled"] .OR. Empty(GetGlobalConfig()["AI2EnginePath"])
         ShowDebugMsg( "AI2 not configured, forced to HUMAN")
         nBlack := 1
         lAIForcedToHuman := .T.
      ELSE
         lBlackAI := .T.
      ENDIF
   ENDIF

   // 保存选择
   nRedPlayer := nRed
   nBlackPlayer := nBlack

   // 如果有 AI 玩家，重新启用 AI
   IF lRedAI .OR. lBlackAI
      lAIEnabled := .T.
   ENDIF

   // 保存到配置文件
   xq_ConfigSet( "MAIN", "RedPlayerType", Str(nRedPlayer) )
   xq_ConfigSet( "MAIN", "BlackPlayerType", Str(nBlackPlayer) )

   // 如果有AI被强制转为HUMAN，显示提示
   IF lAIForcedToHuman
      hwg_MsgInfo( _XQ_I__( "error.ai_not_configured" ) )
   ENDIF

   // 初始化 AI 引擎（根据玩家选择分别初始化）
   // 注意：象眼引擎是内嵌的，已在程序启动时初始化，始终可用，不需要检查
   IF lRedAI
      IF nRedPlayer == 3  // AI1
         IF !lAI1Initialized
            lAI1Initialized := xq_UCCI_InitAI1( GetGlobalConfig() )
            IF !lAI1Initialized
               ShowDebugMsg( "AI1 engine initialization failed" )
               nRedPlayer := 1
               lAIForcedToHuman := .T.
            ENDIF
         ENDIF
      ELSEIF nRedPlayer == 4  // AI2
         IF !lAI2Initialized
            lAI2Initialized := xq_AI2_Init( GetGlobalConfig() )
            IF !lAI2Initialized
               ShowDebugMsg( "AI2 engine initialization failed" )
               nRedPlayer := 1
               lAIForcedToHuman := .T.
            ENDIF
         ENDIF
      ENDIF
   ENDIF

   IF lBlackAI
      IF nBlackPlayer == 3  // AI1
         IF !lAI1Initialized
            lAI1Initialized := xq_UCCI_InitAI1( GetGlobalConfig() )
            IF !lAI1Initialized
               ShowDebugMsg( "AI1 engine initialization failed")
               nBlackPlayer := 1
               lAIForcedToHuman := .T.
            ENDIF
         ENDIF
      ELSEIF nBlackPlayer == 4  // AI2
         IF !lAI2Initialized
            lAI2Initialized := xq_AI2_Init( GetGlobalConfig() )
            IF !lAI2Initialized
               ShowDebugMsg( "AI2 engine initialization failed")
               nBlackPlayer := 1
               lAIForcedToHuman := .T.
            ENDIF
         ENDIF
      ENDIF
   ENDIF

   ShowDebugMsg( "Player mode: RED=" + Iif(nRedPlayer==1,"HUMAN", Iif(nRedPlayer==2,"ElephantEye", "AI"+LTrim(Str(nRedPlayer-2)))) + " vs BLACK=" + Iif(nBlackPlayer==1,"HUMAN", Iif(nBlackPlayer==2,"ElephantEye", "AI"+LTrim(Str(nBlackPlayer-2)))) )

   // 如果棋盘未初始化，自动开始新游戏
   IF lNeedNewGame
      NewGame()
   ELSE
      // 如果当前是AI回合，触发 AI 走棋
      IF nRedPlayer > 1 .AND. lRedTurn
         oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
      ELSEIF nBlackPlayer > 1 .AND. !lRedTurn
         oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
      ENDIF
   ENDIF

RETURN NIL

/*
 * 从样式索引获取样式值
 */
static FUNCTION GetStyleFromIndex( par_nIndex, par_aOptions, par_cDefault )
   RETURN iif( par_nIndex >= 1 .AND. par_nIndex <= Len( par_aOptions ), par_aOptions[par_nIndex], par_cDefault )

/*
 * 界面选项
 */
static FUNCTION Game_Options()
   // 对象变量
   LOCAL oDlg, oTab, oBtnOK, oBtnCancel, oBtnSaveConfig, oBtnApply
   LOCAL oComboDifficulty, oSpinAIMoves
   LOCAL oComboEngineType, oBtnBrowsePath
   LOCAL oGetEnginePath, oGetThinkTime
   LOCAL oComboAI1EngineType, oBtnBrowseAI1Path, oGetAI1EnginePath, oGetAI1ThinkTime
   LOCAL oComboAI2EngineType, oBtnBrowseAI2Path, oGetAI2EnginePath, oGetAI2ThinkTime
   LOCAL oGetStopAI, oGetNewGame, oGetSaveGame, oGetLoadGame, oGetUndoMove
   LOCAL oGetOptions, oGetHelp
   LOCAL oComboBoardStyle
   LOCAL cNewEnginePath  // 用于存储 BrowseEnginePath 的返回值

   // 平台相关变量
   LOCAL nTop := Iif( "windows" $ Lower(Os()), 24, 0 )

   // 游戏设置临时变量
   LOCAL lTempDebug, lTempAIEnabled, nTempAIMoves
   LOCAL lTempSound, nTempDifficulty, lTempAutoSave
   LOCAL nTempBoardStyle, nTempLanguage
   LOCAL nTempAI1EngineType, nTempAI2EngineType
   LOCAL aBoardStyleOptions, aBoardStyleLabels

   // 皮肤扫描相关变量
   LOCAL aAvailableSkins, i, hSkin

   // 界面设置临时变量
   LOCAL lTempShowHints, lTempShowCoords, lTempShowLastMove

   // 引擎设置临时变量
   LOCAL cTempEnginePath, cTempEngineType, nTempThinkTime
   LOCAL lTempAI1Enabled, cTempAI1EngineType, cTempAI1EnginePath, nTempAI1ThinkTime
   LOCAL lTempAI2Enabled, cTempAI2EngineType, cTempAI2EnginePath, nTempAI2ThinkTime

   // 快捷键临时变量
   LOCAL cTempStopAI, cTempNewGame, cTempSaveGame, cTempLoadGame, cTempUndoMove
   LOCAL cTempOptions, cTempHelp

   // 数组
   LOCAL aDifficulty
   LOCAL aEngineTypes := { "ElephantEye", "Pikafish" }
   
   // 根据当前语言生成难度级别数组（使用翻译键）
   IF lCurrentLanguage == "en"
      aDifficulty := { _XQ_I__( "difficulty.novice" ), _XQ_I__( "difficulty.easy" ), _XQ_I__( "difficulty.normal" ), _XQ_I__( "difficulty.hard" ), _XQ_I__( "difficulty.master" ) }
   ELSE
      aDifficulty := { _XQ_I__( "difficulty.novice" ), _XQ_I__( "difficulty.easy" ), _XQ_I__( "difficulty.normal" ), _XQ_I__( "difficulty.hard" ), _XQ_I__( "difficulty.master" ) }
   ENDIF

   // 保存当前状态
   lTempDebug := lDebugMode
   lTempAIEnabled := lAIEnabled
   nTempAIMoves := nAIMaxMoves
   lTempSound := lSoundEnabled
   nTempDifficulty := nDifficultyLevel
   lTempAutoSave := lAutoSave
   
   // 初始化样式选项数组（动态从 skins/ 目录扫描）
   aAvailableSkins := xq_GetAvailableSkins()
   nTempBoardStyle := 1

   aBoardStyleOptions := {}
   aBoardStyleLabels := {}

   // 生成皮肤选项列表
   FOR i := 1 TO Len( aAvailableSkins )
      hSkin := aAvailableSkins[i]
      AAdd( aBoardStyleOptions, hSkin["name"] )
      AAdd( aBoardStyleLabels, hSkin["label"] )

      // 映射当前样式到组合框索引
      IF Lower( cBoardStyle ) == Lower( hSkin["name"] )
         nTempBoardStyle := i
      ENDIF
   NEXT

   // 如果没有找到当前样式，使用第一个
   IF nTempBoardStyle == 1 .AND. !Empty( aAvailableSkins )
      IF Lower( cBoardStyle ) != Lower( aAvailableSkins[1]["name"] )
         nTempBoardStyle := 1
      ENDIF
   ENDIF

   // 初始化语言选择（1=English, 2=中文）
   nTempLanguage := Iif(lCurrentLanguage=="en",1,2)

   lTempShowHints := lShowMoveHints
   lTempShowCoords := lShowCoordinates
   lTempShowLastMove := lShowLastMove

   cTempEnginePath := cEnginePath
   cTempEngineType := cEngineType
   nTempThinkTime := nThinkTime

   // 保存当前AI1配置
   lTempAI1Enabled := GetGlobalConfig()["AI1Enabled"]
   cTempAI1EngineType := GetGlobalConfig()["AI1EngineType"]
   cTempAI1EnginePath := GetGlobalConfig()["AI1EnginePath"]
   nTempAI1ThinkTime := GetGlobalConfig()["AI1ThinkTime"]

   // 保存当前AI2配置
   lTempAI2Enabled := GetGlobalConfig()["AI2Enabled"]
   cTempAI2EngineType := GetGlobalConfig()["AI2EngineType"]
   cTempAI2EnginePath := GetGlobalConfig()["AI2EnginePath"]
   nTempAI2ThinkTime := GetGlobalConfig()["AI2ThinkTime"]

   // 确保路径变量不为0（防止 TRANSFORM 错误）
   IF cTempAI1EnginePath == NIL .OR. ValType(cTempAI1EnginePath) != "C"
      cTempAI1EnginePath := ""
   ENDIF
   IF cTempAI2EnginePath == NIL .OR. ValType(cTempAI2EnginePath) != "C"
      cTempAI2EnginePath := ""
   ENDIF

   // 初始化 AI 引擎类型选择（1=UCCI, 2=UCI）
   nTempAI1EngineType := Iif(cTempAI1EngineType=="UCCI",1,2)
   nTempAI2EngineType := Iif(cTempAI2EngineType=="UCCI",1,2)

   cTempStopAI := cHotKeyStopAI
   cTempNewGame := cHotKeyNewGame
   cTempSaveGame := cHotKeySaveGame
   cTempLoadGame := cHotKeyLoadGame
   cTempUndoMove := cHotKeyUndoMove
   cTempOptions := cHotKeyOptions
   cTempHelp := cHotKeyHelp

   // 创建对话框（居中显示）
   INIT DIALOG oDlg TITLE _XQ_I__( "dialog.game_options" ) ;
      AT (hwg_GetDesktopWidth()-560)/2, (hwg_GetDesktopHeight()-420)/2 SIZE 560, 420

   // 根据当前语言设置标题
   IF lCurrentLanguage == "en"
      oDlg:SetTitle( "Game Options" )
   ENDIF

   // 创建选项卡
   @ 10, 10 TAB oTab ITEMS {} SIZE 540, 340 OF oDlg

   // ========== 选项卡 1: 游戏设置 ==========
   BEGIN PAGE _XQ_I__( "tab.game_settings" ) OF oTab
   // 基本设置组
   @ 20, nTop+20 GET CHECKBOX lTempDebug CAPTION _XQ_I__( "option.enable_debug" ) SIZE 150, 20
   @ 20, nTop+45 GET CHECKBOX lTempAIEnabled CAPTION _XQ_I__( "option.enable_ai" ) SIZE 150, 20
   @ 20, nTop+70 GET CHECKBOX lTempSound CAPTION _XQ_I__( "option.enable_sound" ) SIZE 150, 20

   // AI 设置组
   @ 20, nTop+105 SAY _XQ_I__( "settings.ai_max_moves" ) + ":" SIZE 180, 20
   @ 210, nTop+100 GET oSpinAIMoves VAR nTempAIMoves PICTURE "999" SIZE 80, 24

   @ 20, nTop+135 SAY _XQ_I__( "settings.difficulty" ) + ":" SIZE 80, 20
#ifdef __PLATFORM__UNIX
   @ 110, nTop+130 GET COMBOBOX oComboDifficulty VAR nTempDifficulty ITEMS aDifficulty SIZE 120, 25
#else
   @ 110, nTop+130 GET COMBOBOX oComboDifficulty VAR nTempDifficulty ITEMS aDifficulty SIZE 120, 100
#endif

   @ 20, nTop+170 GET CHECKBOX lTempAutoSave CAPTION _XQ_I__( "option.auto_save" ) SIZE 150, 20
   END PAGE OF oTab

   // ========== 选项卡 2: 界面设置 ==========
   BEGIN PAGE _XQ_I__( "tab.ui_settings" ) OF oTab
   @ 20, nTop+20 SAY _XQ_I__( "settings.language" ) + ":" SIZE 70, 20 OF oTab
#ifdef __PLATFORM__UNIX
   @ 95, nTop+15 GET COMBOBOX oComboLanguage VAR nTempLanguage ITEMS {_XQ_I__( "lang.english" ), _XQ_I__( "lang.chinese" )} SIZE 80, 25 OF oTab
#else
   @ 95, nTop+15 GET COMBOBOX oComboLanguage VAR nTempLanguage ITEMS {_XQ_I__( "lang.english" ), _XQ_I__( "lang.chinese" )} SIZE 80, 100 OF oTab
#endif

   @ 20, nTop+50 SAY _XQ_I__( "settings.skin_style" ) + ":" SIZE 90, 20 OF oTab
#ifdef __PLATFORM__UNIX
   @ 115, nTop+45 GET COMBOBOX oComboBoardStyle VAR nTempBoardStyle ITEMS aBoardStyleLabels SIZE 120, 25 OF oTab
#else
   @ 115, nTop+45 GET COMBOBOX oComboBoardStyle VAR nTempBoardStyle ITEMS aBoardStyleLabels SIZE 120, 100 OF oTab
#endif
   @ 20, nTop+80 GET CHECKBOX lTempShowHints CAPTION _XQ_I__( "settings.show_move_hints" ) SIZE 150, 20 OF oTab
   @ 20, nTop+105 GET CHECKBOX lTempShowCoords CAPTION _XQ_I__( "settings.show_coordinates" ) SIZE 150, 20 OF oTab
   @ 20, nTop+130 GET CHECKBOX lTempShowLastMove CAPTION _XQ_I__( "settings.show_last_move" ) SIZE 150, 20 OF oTab
   END PAGE OF oTab

   // ========== 选项卡 3: 引擎设置 ==========
   BEGIN PAGE _XQ_I__( "tab.engine_settings" ) OF oTab
   // ---------- AI1 设置 ----------
   @ 20, nTop+20 GROUPBOX _XQ_I__( "ai.enable_ai1" ) SIZE 500, 95 OF oTab
   @ 30, nTop+40 GET CHECKBOX lTempAI1Enabled CAPTION _XQ_I__( "ai.enable_ai1" ) SIZE 100, 20 OF oTab
   @ 150, nTop+40 SAY _XQ_I__( "ai.engine_type" ) + ":" SIZE 90, 20 OF oTab
#ifdef __PLATFORM__UNIX
   @ 250, nTop+35 GET COMBOBOX oComboAI1EngineType VAR nTempAI1EngineType ITEMS {"UCCI", "UCI"} SIZE 100, 30 OF oTab
#else
   @ 250, nTop+35 GET COMBOBOX oComboAI1EngineType VAR nTempAI1EngineType ITEMS {"UCCI", "UCI"} SIZE 100, 150 OF oTab
#endif

   @ 30, nTop+65 SAY _XQ_I__( "ai.engine_file" ) + ":" SIZE 90, 20 OF oTab
   @ 130, nTop+60 GET oGetAI1EnginePath VAR cTempAI1EnginePath PICTURE "@S200" SIZE 250, 30 OF oTab
   @ 390, nTop+60 BUTTON oBtnBrowseAI1Path CAPTION _XQ_I__( "ai.browse" ) SIZE 90, 30 OF oTab ;
      ON CLICK {||cNewEnginePath := BrowseEnginePath(), Iif( !Empty(cNewEnginePath), cTempAI1EnginePath := cNewEnginePath, ), oGetAI1EnginePath:Refresh()}

   @ 30, nTop+95 SAY _XQ_I__( "ai.think_time" ) + ":" SIZE 110, 20 OF oTab
   @ 150, nTop+90 GET oGetAI1ThinkTime VAR nTempAI1ThinkTime PICTURE "9999" SIZE 60, 24 OF oTab

   // ---------- AI2 设置 ----------
   @ 20, nTop+140 GROUPBOX _XQ_I__( "ai.enable_ai2" ) SIZE 500, 95 OF oTab
   @ 30, nTop+160 GET CHECKBOX lTempAI2Enabled CAPTION _XQ_I__( "ai.enable_ai2" ) SIZE 100, 20 OF oTab
   @ 150, nTop+160 SAY _XQ_I__( "ai.engine_type" ) + ":" SIZE 90, 20 OF oTab
#ifdef __PLATFORM__UNIX
   @ 250, nTop+155 GET COMBOBOX oComboAI2EngineType VAR nTempAI2EngineType ITEMS {"UCCI", "UCI"} SIZE 100, 30 OF oTab
#else
   @ 250, nTop+155 GET COMBOBOX oComboAI2EngineType VAR nTempAI2EngineType ITEMS {"UCCI", "UCI"} SIZE 100, 150 OF oTab
#endif

   @ 30, nTop+185 SAY _XQ_I__( "ai.engine_file" ) + ":" SIZE 90, 20 OF oTab
   @ 130, nTop+180 GET oGetAI2EnginePath VAR cTempAI2EnginePath PICTURE "@S200" SIZE 250, 30 OF oTab
   @ 390, nTop+180 BUTTON oBtnBrowseAI2Path CAPTION _XQ_I__( "ai.browse" ) SIZE 90, 30 OF oTab ;
      ON CLICK {||cNewEnginePath := BrowseEnginePath(), Iif( !Empty(cNewEnginePath), cTempAI2EnginePath := cNewEnginePath, ), oGetAI2EnginePath:Refresh()}

   @ 30, nTop+215 SAY _XQ_I__( "ai.think_time" ) + ":" SIZE 110, 20 OF oTab
   @ 150, nTop+210 GET oGetAI2ThinkTime VAR nTempAI2ThinkTime PICTURE "9999" SIZE 60, 24 OF oTab

   // 提示信息
   @ 20, nTop+255 SAY _XQ_I__( "ai.settings_hint" ) SIZE 500, 20 OF oTab COLOR {0,0,128}
   END PAGE OF oTab

   // ========== 选项卡 4: 快捷键 ==========
   BEGIN PAGE _XQ_I__( "tab.hotkeys" ) OF oTab
   @ 20, nTop+20 SAY _XQ_I__( "hotkey.stop_ai" ) + ":" SIZE 80, 20 OF oTab
   @ 110, nTop+15 GET oGetStopAI VAR cTempStopAI PICTURE "@S15" SIZE 120, 24 OF oTab

   @ 20, nTop+50 SAY _XQ_I__( "hotkey.new_game" ) + ":" SIZE 80, 20 OF oTab
   @ 110, nTop+45 GET oGetNewGame VAR cTempNewGame PICTURE "@S15" SIZE 120, 24 OF oTab

   @ 20, nTop+80 SAY _XQ_I__( "hotkey.save_game" ) + ":" SIZE 80, 20 OF oTab
   @ 110, nTop+75 GET oGetSaveGame VAR cTempSaveGame PICTURE "@S15" SIZE 120, 24 OF oTab

   @ 20, nTop+110 SAY _XQ_I__( "hotkey.load_game" ) + ":" SIZE 80, 20 OF oTab
   @ 110, nTop+105 GET oGetLoadGame VAR cTempLoadGame PICTURE "@S15" SIZE 120, 24 OF oTab

   @ 20, nTop+140 SAY _XQ_I__( "hotkey.undo" ) + ":" SIZE 80, 20 OF oTab
   @ 110, nTop+135 GET oGetUndoMove VAR cTempUndoMove PICTURE "@S15" SIZE 120, 24 OF oTab

   @ 20, nTop+170 SAY _XQ_I__( "hotkey.options" ) + ":" SIZE 80, 20 OF oTab
   @ 110, nTop+165 GET oGetOptions VAR cTempOptions PICTURE "@S15" SIZE 120, 24 OF oTab

   @ 20, nTop+200 SAY _XQ_I__( "hotkey.help" ) + ":" SIZE 80, 20 OF oTab
   @ 110, nTop+195 GET oGetHelp VAR cTempHelp PICTURE "@S15" SIZE 120, 24 OF oTab
   END PAGE OF oTab

   // ========== 底部按钮 ==========
   @ 60, 360 BUTTON oBtnOK CAPTION _XQ_I__( "button.ok" ) SIZE 80, 30 OF oDlg ;
      ON CLICK {||ApplyAllOptions(lTempDebug, lTempAIEnabled, nTempAIMoves, lTempSound, nTempDifficulty, lTempAutoSave, aBoardStyleOptions[oComboBoardStyle:Value()], aBoardStyleOptions[oComboBoardStyle:Value()], lTempShowHints, lTempShowCoords, lTempShowLastMove, cTempEnginePath, cTempEngineType, nTempThinkTime, cTempStopAI, cTempNewGame, cTempSaveGame, cTempLoadGame, cTempUndoMove, cTempOptions, cTempHelp, lTempAI1Enabled, cTempAI1EngineType, cTempAI1EnginePath, nTempAI1ThinkTime, lTempAI2Enabled, cTempAI2EngineType, cTempAI2EnginePath, nTempAI2ThinkTime), SaveAllOptionsToConfig(), CheckLanguageAndSave(), hwg_EndDialog()}

   @ 160, 360 BUTTON oBtnCancel CAPTION _XQ_I__( "button.cancel" ) SIZE 80, 30 OF oDlg ;
      ON CLICK {||hwg_EndDialog()}

   @ 260, 360 BUTTON oBtnSaveConfig CAPTION _XQ_I__( "button.save" ) SIZE 80, 30 OF oDlg ;
      ON CLICK {||hwg_MsgInfo(_XQ_I__( "message.config_saved" ))}

   @ 360, 360 BUTTON oBtnApply CAPTION _XQ_I__( "button.apply" ) SIZE 80, 30 OF oDlg ;
      ON CLICK {||ApplyAllOptions(lTempDebug, lTempAIEnabled, nTempAIMoves, lTempSound, nTempDifficulty, lTempAutoSave, aBoardStyleOptions[oComboBoardStyle:Value()], aBoardStyleOptions[oComboBoardStyle:Value()], lTempShowHints, lTempShowCoords, lTempShowLastMove, cTempEnginePath, cTempEngineType, nTempThinkTime, cTempStopAI, cTempNewGame, cTempSaveGame, cTempLoadGame, cTempUndoMove, cTempOptions, cTempHelp, lTempAI1Enabled, cTempAI1EngineType, cTempAI1EnginePath, nTempAI1ThinkTime, lTempAI2Enabled, cTempAI2EngineType, cTempAI2EnginePath, nTempAI2ThinkTime), SaveAllOptionsToConfig(), CheckLanguageAndSave(), hwg_MsgInfo(_XQ_I__( "message.settings_applied" ))}

   // 根据语言更新按钮文本（实际上已经在 CAPTION 中使用了翻译，这里可以删除）
   IF lCurrentLanguage == "en"
      oBtnOK:SetText( _XQ_I__( "button.ok" ) )
      oBtnCancel:SetText( _XQ_I__( "button.cancel" ) )
      oBtnSaveConfig:SetText( _XQ_I__( "button.save" ) )
      oBtnApply:SetText( _XQ_I__( "button.apply" ) )
   ENDIF

   ACTIVATE DIALOG oDlg

RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 从全局变量创建配置对象
 * 
 * 参数: 无
 * 返回: 包含所有配置的哈希表
 */
static FUNCTION CreateConfigFromGlobals()
   LOCAL l_oConfig := hb_Hash()
   
   // 游戏设置
   l_oConfig["debug"] := lDebugMode
   l_oConfig["ai"] := lAIEnabled
   l_oConfig["aiMoves"] := nAIMaxMoves
   l_oConfig["sound"] := lSoundEnabled
   l_oConfig["difficulty"] := nDifficultyLevel
   l_oConfig["autoSave"] := lAutoSave
   l_oConfig["boardStyle"] := cBoardStyle
   l_oConfig["pieceStyle"] := cPieceStyle
   l_oConfig["showHints"] := lShowMoveHints
   l_oConfig["showCoords"] := lShowCoordinates
   l_oConfig["showLastMove"] := lShowLastMove
   
   // 引擎设置
   l_oConfig["enginePath"] := cEnginePath
   l_oConfig["engineType"] := cEngineType
   l_oConfig["thinkTime"] := nThinkTime
   
   // 快捷键设置
   l_oConfig["hkStopAI"] := cHotKeyStopAI
   l_oConfig["hkNewGame"] := cHotKeyNewGame
   l_oConfig["hkSaveGame"] := cHotKeySaveGame
   l_oConfig["hkLoadGame"] := cHotKeyLoadGame
   l_oConfig["hkUndoMove"] := cHotKeyUndoMove
   l_oConfig["hkOptions"] := cHotKeyOptions
   l_oConfig["hkHelp"] := cHotKeyHelp
   
   // AI1 设置
   l_oConfig["ai1Enabled"] := GetGlobalConfig()["AI1Enabled"]
   l_oConfig["ai1EngineType"] := GetGlobalConfig()["AI1EngineType"]
   l_oConfig["ai1EnginePath"] := GetGlobalConfig()["AI1EnginePath"]
   l_oConfig["ai1ThinkTime"] := GetGlobalConfig()["AI1ThinkTime"]
   
   // AI2 设置
   l_oConfig["ai2Enabled"] := GetGlobalConfig()["AI2Enabled"]
   l_oConfig["ai2EngineType"] := GetGlobalConfig()["AI2EngineType"]
   l_oConfig["ai2EnginePath"] := GetGlobalConfig()["AI2EnginePath"]
   l_oConfig["ai2ThinkTime"] := GetGlobalConfig()["AI2ThinkTime"]
   
RETURN l_oConfig

//--------------------------------------------------------------------------------

/*
 * 从对话框控件更新配置对象
 *
 * 参数:
 *   par_oConfig - 配置对象（哈希表）
 *   par_oComboBoardStyle - 棋盘样式组合框
 *   par_oComboPieceStyle - 棋子样式组合框
 *   par_nTempBoardStyle - 临时棋盘样式索引
 *   par_aBoardStyleOptions - 棋盘样式选项数组
 *   par_nTempPieceStyle - 临时棋子样式索引
 *   par_aPieceStyleOptions - 棋子样式选项数组
 * 返回: NIL
 */
static FUNCTION UpdateConfigFromDialog( par_oConfig, par_oComboBoardStyle, par_oComboPieceStyle, ;
                                       par_nTempBoardStyle, par_aBoardStyleOptions, ;
                                       par_nTempPieceStyle, par_aPieceStyleOptions )
   // 更新样式（从组合框获取当前选择）
   IF !Empty( par_oComboBoardStyle )
      par_oConfig["boardStyle"] := GetStyleFromIndex( par_nTempBoardStyle, par_aBoardStyleOptions, "woods" )
   ENDIF

   IF !Empty( par_oComboPieceStyle )
      par_oConfig["pieceStyle"] := GetStyleFromIndex( par_nTempPieceStyle, par_aPieceStyleOptions, "woods" )
   ENDIF
RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 应用所有选项设置
 */
static FUNCTION ApplyAllOptions(lNewDebug, lNewAI, nNewMoves, lNewSound, nNewDiff, lNewAutoSave, cNewBoardStyle, cNewPieceStyle, lNewShowHints, lNewShowCoords, lNewShowLastMove, cNewEnginePath, cNewEngineType, nNewThinkTime, cNewHKStopAI, cNewHKNewGame, cNewHKSave, cNewHKLoad, cNewHKUndo, cNewHKOptions, cNewHKHelp, lNewAI1Enabled, cNewAI1EngineType, cNewAI1EnginePath, nNewAI1ThinkTime, lNewAI2Enabled, cNewAI2EngineType, cNewAI2EnginePath, nNewAI2ThinkTime)

   // 检查并确保样式参数不为NIL
   IF cNewBoardStyle == NIL
      cNewBoardStyle := cBoardStyle
   ENDIF
   IF cNewPieceStyle == NIL
      cNewPieceStyle := cPieceStyle
   ENDIF

   // 注意：语言设置由 CheckLanguageAndSave 函数单独处理

   // 更新游戏设置
   lDebugMode := lNewDebug
   lAIEnabled := lNewAI
   nAIMaxMoves := nNewMoves
   lSoundEnabled := lNewSound
   nDifficultyLevel := nNewDiff
   lAutoSave := lNewAutoSave

   // 检查棋盘样式或棋子样式是否改变
   IF cNewBoardStyle != cBoardStyle .OR. cNewPieceStyle != cPieceStyle
      // 记录旧样式（在更新之前）
      cOldBoardStyle := cBoardStyle
      cOldPieceStyle := cPieceStyle
      // 先更新全局变量，这样 LoadResources 会加载新的样式
      cBoardStyle := cNewBoardStyle
      cPieceStyle := cNewPieceStyle
      // 然后重新加载资源（使用新的样式）
      LoadResources()
      // 重绘整个窗口以确保显示正确
      hwg_Redrawwindow( oMainWnd:handle, RDW_INVALIDATE + RDW_UPDATENOW + RDW_ERASE + RDW_ALLCHILDREN )
      // 重绘棋盘
      IF lGameRunning
         hwg_Invalidaterect( oChessBoard:handle )
      ENDIF
   ENDIF

   // 更新界面设置
   lShowMoveHints := lNewShowHints
   lShowCoordinates := lNewShowCoords
   lShowLastMove := lNewShowLastMove

   // 更新引擎设置（旧版兼容）
   cEnginePath := cNewEnginePath
   cEngineType := cNewEngineType
   nThinkTime := nNewThinkTime

   // 更新AI1设置并同步到配置哈希表
   // 如果引擎路径为空，自动禁用AI1
   IF Empty(cNewAI1EnginePath)
      lNewAI1Enabled := .F.
   ENDIF
   GetGlobalConfig()["AI1Enabled"] := lNewAI1Enabled
   GetGlobalConfig()["AI1EngineType"] := cNewAI1EngineType
   GetGlobalConfig()["AI1EnginePath"] := cNewAI1EnginePath
   GetGlobalConfig()["AI1ThinkTime"] := nNewAI1ThinkTime

   // 更新AI2设置并同步到配置哈希表
   // 如果引擎路径为空，自动禁用AI2
   IF Empty(cNewAI2EnginePath)
      lNewAI2Enabled := .F.
   ENDIF
   GetGlobalConfig()["AI2Enabled"] := lNewAI2Enabled
   GetGlobalConfig()["AI2EngineType"] := cNewAI2EngineType
   GetGlobalConfig()["AI2EnginePath"] := cNewAI2EnginePath
   GetGlobalConfig()["AI2ThinkTime"] := nNewAI2ThinkTime

   // 重新初始化AI1引擎（如果已启用且配置已更改）
   IF GetGlobalConfig()["AI1Enabled"] .AND. !Empty(GetGlobalConfig()["AI1EnginePath"]) .AND. File(GetGlobalConfig()["AI1EnginePath"])
      // 停止当前AI1引擎
      IF lAI1Initialized
         xq_UCCI_CloseAI1()
      ENDIF
      // 重新初始化AI1
      lAI1Initialized := xq_UCCI_InitAI1( GetGlobalConfig() )
      IF lAI1Initialized
         ShowDebugMsg( "AI1 engine re-initialized: " + GetGlobalConfig()["AI1EnginePath"] )
      ELSE
         ShowDebugMsg( "AI1 engine re-initialization failed: " + GetGlobalConfig()["AI1EnginePath"] )
      ENDIF
   ELSEIF GetGlobalConfig()["AI1Enabled"] .AND. (Empty(GetGlobalConfig()["AI1EnginePath"]) .OR. !File(GetGlobalConfig()["AI1EnginePath"]))
      ShowDebugMsg( "AI1 enabled but engine path is empty or not found, skipping initialization" )
   ENDIF

   // 重新初始化AI2引擎（如果已启用且配置已更改）
   IF GetGlobalConfig()["AI2Enabled"] .AND. !Empty(GetGlobalConfig()["AI2EnginePath"]) .AND. File(GetGlobalConfig()["AI2EnginePath"])
      // 停止当前AI2引擎
      IF lAI2Initialized
         xq_AI2_Close()
      ENDIF
      // 重新初始化AI2
      lAI2Initialized := xq_AI2_Init( GetGlobalConfig() )
      IF lAI2Initialized
         ShowDebugMsg( "AI2 engine re-initialized: " + GetGlobalConfig()["AI2EnginePath"] )
      ELSE
         ShowDebugMsg( "AI2 engine re-initialization failed: " + GetGlobalConfig()["AI2EnginePath"] )
      ENDIF
   ELSEIF GetGlobalConfig()["AI2Enabled"] .AND. (Empty(GetGlobalConfig()["AI2EnginePath"]) .OR. !File(GetGlobalConfig()["AI2EnginePath"]))
      ShowDebugMsg( "AI2 enabled but engine path is empty or not found, skipping initialization" )
   ENDIF

   // 更新快捷键
   cHotKeyStopAI := cNewHKStopAI
   cHotKeyNewGame := cNewHKNewGame
   cHotKeySaveGame := cNewHKSave
   cHotKeyLoadGame := cNewHKLoad
   cHotKeyUndoMove := cNewHKUndo
   cHotKeyOptions := cNewHKOptions
   cHotKeyHelp := cNewHKHelp

   // 显示提示信息
   XQ_MsgWnd_ShowMsg( "Settings updated" )

RETURN NIL

/*
 * 辅助函数：在数组中查找项目索引
 */
static FUNCTION FindItemIndex(aArray, cSearch)
   LOCAL i
   LOCAL nIndex := 1
   LOCAL cLowerSearch := Lower( AllTrim( cSearch ) )

   FOR i := 1 TO Len( aArray )
      IF Lower( AllTrim( aArray[i] ) ) == cLowerSearch
         nIndex := i
         EXIT
      ENDIF
   NEXT

RETURN nIndex

/*
 * 辅助函数：浏览引擎路径
 */
static FUNCTION BrowseEnginePath()
   LOCAL cFile
   LOCAL cInitialDir := hb_DirBase() + "engines/"
   LOCAL aFilterNames := {}
   LOCAL aFilterMasks := {}

#ifdef __PLATFORM__WINDOWS
   // Windows 过滤器
   AAdd( aFilterNames, _XQ_I__( "ai.filter_executable" ) + " (*.exe)" )
   AAdd( aFilterMasks, "*.exe" )
   AAdd( aFilterNames, _XQ_I__( "ai.filter_batch_files" ) + " (*.bat;*.cmd)" )
   AAdd( aFilterMasks, "*.bat;*.cmd" )
#else
   // Linux 过滤器
   AAdd( aFilterNames, _XQ_I__( "ai.filter_executable" ) + " (*)" )
   AAdd( aFilterMasks, "*" )
   AAdd( aFilterNames, _XQ_I__( "ai.filter_shell_scripts" ) + " (*.sh)" )
   AAdd( aFilterMasks, "*.sh" )
#endif

   // 通用过滤器
   AAdd( aFilterNames, _XQ_I__( "ai.filter_all_files" ) + " (*.*)" )
   AAdd( aFilterMasks, "*.*" )

   IF hb_DirExists( cInitialDir )
      cFile := hwg_Selectfile( aFilterNames, aFilterMasks, cInitialDir, _XQ_I__( "ai.select_engine_title" ) )
   ELSE
      cFile := hwg_Selectfile( aFilterNames, aFilterMasks, hb_DirBase(), _XQ_I__( "ai.select_engine_title" ) )
   ENDIF

   // 调试：打印返回的文件路径
   IF !Empty(cFile)
      OutErr( "BrowseEnginePath returned: " + cFile + hb_eol() )
   ENDIF

RETURN cFile

/*
 * 保存所有选项到配置文件
 */
static FUNCTION SaveAllOptionsToConfig()

   // 保存主设置
   xq_ConfigSet( "MAIN", "RedPlayerType", Str(nRedPlayer) )
   xq_ConfigSet( "MAIN", "BlackPlayerType", Str(nBlackPlayer) )
   xq_ConfigSet( "MAIN", "DebugMode", Iif(lDebugMode, "1", "0") )

   // 保存游戏设置
   xq_ConfigSet( "GameSettings", "BoardStyle", cBoardStyle )
   xq_ConfigSet( "GameSettings", "PieceStyle", cPieceStyle )
   xq_ConfigSet( "GameSettings", "SoundEnabled", Iif(lSoundEnabled, "1", "0") )
   xq_ConfigSet( "GameSettings", "DifficultyLevel", Str(nDifficultyLevel) )
   xq_ConfigSet( "GameSettings", "AutoSave", Iif(lAutoSave, "1", "0") )
   xq_ConfigSet( "GameSettings", "AIMaxMoves", Str(nAIMaxMoves) )
   xq_ConfigSet( "GameSettings", "AIEnabled", Iif(lAIEnabled, "1", "0") )

   // 保存界面设置
   xq_ConfigSet( "UISettings", "ShowMoveHints", Iif(lShowMoveHints, "1", "0") )
   xq_ConfigSet( "UISettings", "ShowCoordinates", Iif(lShowCoordinates, "1", "0") )
   xq_ConfigSet( "UISettings", "ShowLastMove", Iif(lShowLastMove, "1", "0") )
   xq_ConfigSet( "UISettings", "Language", lCurrentLanguage )

   // 保存引擎设置（旧版兼容）
   xq_ConfigSet( "EngineSettings", "EnginePath", cEnginePath )
   xq_ConfigSet( "EngineSettings", "EngineType", cEngineType )
   xq_ConfigSet( "EngineSettings", "ThinkTime", Str(nThinkTime) )

   // 保存AI1设置
   xq_ConfigSet( "AI1Settings", "Enabled", Iif(GetGlobalConfig()["AI1Enabled"], "1", "0") )
   xq_ConfigSet( "AI1Settings", "EngineType", GetGlobalConfig()["AI1EngineType"] )
   xq_ConfigSet( "AI1Settings", "EnginePath", GetGlobalConfig()["AI1EnginePath"] )
   xq_ConfigSet( "AI1Settings", "ThinkTime", Str(GetGlobalConfig()["AI1ThinkTime"]) )

   // 保存AI2设置
   xq_ConfigSet( "AI2Settings", "Enabled", Iif(GetGlobalConfig()["AI2Enabled"], "1", "0") )
   xq_ConfigSet( "AI2Settings", "EngineType", GetGlobalConfig()["AI2EngineType"] )
   xq_ConfigSet( "AI2Settings", "EnginePath", GetGlobalConfig()["AI2EnginePath"] )
   xq_ConfigSet( "AI2Settings", "ThinkTime", Str(GetGlobalConfig()["AI2ThinkTime"]) )

   // 保存快捷键
   xq_ConfigSet( "Hotkeys", "StopAI", cHotKeyStopAI )
   xq_ConfigSet( "Hotkeys", "NewGame", cHotKeyNewGame )
   xq_ConfigSet( "Hotkeys", "SaveGame", cHotKeySaveGame )
   xq_ConfigSet( "Hotkeys", "LoadGame", cHotKeyLoadGame )
   xq_ConfigSet( "Hotkeys", "UndoMove", cHotKeyUndoMove )
   xq_ConfigSet( "Hotkeys", "Options", cHotKeyOptions )
   xq_ConfigSet( "Hotkeys", "Help", cHotKeyHelp )

   // 保存配置到文件
   xq_ConfigSave()

RETURN NIL

/*
 * 保存游戏
 */
static FUNCTION SaveGame()
   LOCAL cFileName, cDefaultFileName, cResult
   LOCAL aFiles, lSuccess
   LOCAL aFilterNames, aFilterMasks
   
   // 确定结果字符串
   IF !lGameRunning
      cResult := "*"
   ELSEIF lRedTurn
      cResult := "0-1"  // 黑方胜（红方回合结束）
   ELSE
      cResult := "1-0"  // 红方胜（黑方回合结束）
   ENDIF
   
   // 生成默认文件名（包含日期时间）
   // 格式：cchess_YYYYMMDD_HHMM.pgn
   // 示例：cchess_20260223_1330.pgn
   cDefaultFileName := "cchess_" + ;
                       StrZero( Year( Date() ), 4 ) + ;
                       StrZero( Month( Date() ), 2 ) + ;
                       StrZero( Day( Date() ), 2 ) + "_" + ;
                       StrZero( Val( SubStr( Time(), 1, 2 ) ), 2 ) + ;
                       StrZero( Val( SubStr( Time(), 4, 2 ) ), 2 ) + ".pgn"   

   // 构建过滤器
   aFilterNames := {}
   aFilterMasks := {}
   AAdd( aFilterNames, _XQ_I__( "filter.pgn_files" ) )
   AAdd( aFilterMasks, "*.pgn" )
   AAdd( aFilterNames, _XQ_I__( "filter.fen_files" ) )
   AAdd( aFilterMasks, "*.fen" )
   AAdd( aFilterNames, _XQ_I__( "filter.all_files" ) )
   AAdd( aFilterMasks, "*.*" )

   // 使用文件选择对话框
   cFileName := hwg_Selectfile( aFilterNames, aFilterMasks, hb_DirBase(), _XQ_I__( "dialog.save_game_title" ) )
   
   IF Empty( cFileName )
      RETURN NIL  // 用户取消
   ENDIF
   
   // 确保文件扩展名为 .pgn
   IF Right( Upper( cFileName ), 4 ) != ".PGN"
      cFileName += ".pgn"
   ENDIF
   
   // 调用通用保存函数
   lSuccess := xq_SaveGame( cFileName, xq_Notation_GetLog(), aBoardPos, lRedTurn, cResult, nRedPlayer, nBlackPlayer, cInitialFen )
   
   IF lSuccess
      hwg_MsgInfo( _XQ_I__( "message.game_saved" ) + hb_eol() + cFileName )
   ELSE
      hwg_MsgStop( _XQ_I__( "message.save_failed" ) )
   ENDIF

RETURN NIL
/*
 * 加载游戏
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION LoadGame()
local cFen, aResult, aBoard, i, j, nIdx, cPiece, cBoardStr
local cErrorMsg, oDlg, oGetFen, oBtnOk, oBtnCancel
local cTitle, cPrompt, cCleanFen, cPart, nPartCount, cPartsTemp
local isDuplicate, cMoveCount
local cPGNFile, hPGNResult, nChoice, aPGNMoves
local aPos, cMoveStr, nMove, lResult, k
local cFromCol, cFromRow, cToCol, cToRow
local nFromCol, nFromRow, nToCol, nToRow
local aTempBoard
local aFilterNames, aFilterMasks

   // 首先提供选择：从文件加载或手动输入 FEN
   nChoice := hwg_MsgYesNo( _XQ_I__( "dialog.load_game_select_method" ) + hb_eol() + _XQ_I__( "dialog.load_game_from_file" ) + hb_eol() + _XQ_I__( "dialog.load_game_manual_fen" ) )

   IF nChoice == .T.
      // 从文件加载
      // 构建过滤器
      aFilterNames := {}
      aFilterMasks := {}
      AAdd( aFilterNames, _XQ_I__( "filter.pgn_files" ) )
      AAdd( aFilterMasks, "*.pgn" )
      AAdd( aFilterNames, _XQ_I__( "filter.fen_files" ) )
      AAdd( aFilterMasks, "*.fen" )
      AAdd( aFilterNames, _XQ_I__( "filter.all_files" ) )
      AAdd( aFilterMasks, "*.*" )

      cPGNFile := hwg_Selectfile( aFilterNames, aFilterMasks, hb_DirBase(), _XQ_I__( "dialog.load_game_title" ) )

      IF Empty( cPGNFile )
         RETURN NIL  // 用户取消
      ENDIF

      // 调用通用加载函数
      hPGNResult := xq_LoadGame( cPGNFile )

      IF !hPGNResult[ "success" ]
         hwg_MsgStop( _XQ_I__( "message.load_failed" ) + hb_eol() + hb_eol() + hPGNResult[ "error" ] )
         RETURN NIL
      ENDIF

      cFen := hPGNResult[ "fen" ]
      
      // 获取着法列表（如果有）
      aPGNMoves := {}
      IF hPGNResult[ "moves" ] != NIL
         aPGNMoves := hPGNResult[ "moves" ]
      ENDIF

      // 显示 FEN 以便确认
      IF hwg_MsgYesNo( _XQ_I__( "message.load_this_game" ) + hb_eol() + hb_eol() + "FEN: " + cFen ) == .F.
         RETURN NIL  // 用户取消
      ENDIF
   ELSE
      // 手动输入 FEN - 创建输入对话框
      cTitle := _XQ_I__( "dialog.load_game_manual_title" )
      cPrompt := _XQ_I__( "dialog.load_game_fen_prompt" )
      cFen := ""  // 初始化为空字符串
      aPGNMoves := {}  // 手动输入 FEN 时没有着法记录
      
      INIT DIALOG oDlg TITLE cTitle AT (hwg_GetDesktopWidth()-500)/2, (hwg_GetDesktopHeight()-200)/2 SIZE 500, 200 FONT oFontMain
      @ 20, 20 SAY cPrompt SIZE 460, 24
      @ 20, 60 GET oGetFen VAR cFen PICTURE "@S200" SIZE 460, 24
      @ 120, 120 BUTTON oBtnOk CAPTION _XQ_I__( "button.ok" ) SIZE 100, 32 ON CLICK { ||oDlg:lResult:=.T., hwg_EndDialog() }
      @ 300, 120 BUTTON oBtnCancel CAPTION _XQ_I__( "button.cancel" ) SIZE 100, 32 ON CLICK { ||hwg_EndDialog() }
      
      ACTIVATE DIALOG oDlg CENTER
      
      IF Empty( cFen )
         RETURN NIL
      ENDIF
   ENDIF
   
   IF !Empty( cFen )
   // 以下为原有 FEN 加载逻辑（从 IF !Empty( cFen ) 开始）
      cFen := StrTran( cFen, Chr(13), "" )  // 去除回车
      cFen := StrTran( cFen, Chr(10), "" )  // 去除换行
      cFen := StrTran( cFen, Chr(9), "" )   // 去除制表符
      
      // 检测并去除重复的FEN（可能粘贴了两次）
      // 正常FEN格式：棋盘/棋盘/... 回合 权利 回合数 回合号 走法数
      // 空格分隔的字段数是6：棋盘、回合、权利、回合数、回合号、走法数
      cPartsTemp := hb_ATokens( cFen, " " )
      
      // 情况1：标准重复格式（两个FEN之间有空格）→ 12个部分
      IF Len( cPartsTemp ) >= 12
         // 检查是否是重复的FEN
         isDuplicate := .T.
         FOR i := 1 TO 6
            IF cPartsTemp[i] != cPartsTemp[i + 6]
               isDuplicate := .F.
               EXIT
            ENDIF
         NEXT
         
         IF isDuplicate
            // 是重复的，只取前6个字段
            cCleanFen := ""
            FOR i := 1 TO 6
               cCleanFen += cPartsTemp[i] + " "
            NEXT
            cFen := AllTrim( cCleanFen )
         ENDIF
      ELSEIF Len( cPartsTemp ) > 6
         // 情况2：拼接格式（FEN[数字]FEN）→ 例如 "0 12bakab2/..."
         // 这种情况下，第6部分（索引5）可能包含第二个FEN的开始
         // 检测：如果第6部分是"数字+FEN开始"，则提取出正确的走法数
         
         // 获取第一个FEN的前5个字段
         cCleanFen := ""
         FOR i := 1 TO 5
            cCleanFen += cPartsTemp[i] + " "
         NEXT
         
         // 第6部分应该是走法数，但如果格式错误，可能包含更多内容
         cPart := cPartsTemp[6]
         
         // 如果这一部分包含斜杠，说明它包含了第二个FEN的开始
         IF "/" $ cPart
            // 提取纯数字部分作为走法数
            cMoveCount := ""
            FOR j := 1 TO Len( cPart )
               IF IsDigit( SubStr( cPart, j, 1 ) )
                  cMoveCount += SubStr( cPart, j, 1 )
               ELSE
                  EXIT
               ENDIF
            NEXT
            cCleanFen += cMoveCount + " "
         ELSE
            // 正常的走法数
            cCleanFen += cPart + " "
         ENDIF
         
         cFen := AllTrim( cCleanFen )
      ENDIF
      
      // 验证FEN格式
      IF !ValidateFen( cFen, @cErrorMsg )
         hwg_MsgStop( _XQ_I__( "message.fen_format_error" ) + CRLF + cErrorMsg )
         RETURN NIL
      ENDIF

      // 转换FEN为棋盘数组
      aResult := xq_FenToArrayBoard( cFen )
      aBoard := aResult[1]
      lRedTurn := aResult[2]

      // 保存初始 FEN
      cInitialFen := cFen

      // 清空当前棋盘
      ClearBoard()

      // 从棋盘数组填充aBoardPos
      FOR i := 1 TO 10
         FOR j := 1 TO 9
            nIdx := (i-1)*9 + j
            aBoardPos[i,j] := aBoard[nIdx]
         NEXT
      NEXT

      // 更新游戏状态
      lGameRunning := .T.
      nSelectedCol := -1
      nSelectedRow := -1
      nLastMoveCol := -1
      nLastMoveRow := -1
      nLastMoveFromCol := -1
      nLastMoveFromRow := -1

      // 清空消息窗口
      XQ_MsgWnd_Clear()
      
      // 清空中国记谱法窗口
      xq_Notation_Clear()

      // 清空引擎输出窗口
      IF !Empty( oEngineOutput )
         oEngineOutput:SetText( _XQ_I__( "engine.output" ) + CRLF )
         IF nRedPlayer > 1 .OR. nBlackPlayer > 1
            oEngineOutput:SetText( oEngineOutput:GetText() + _XQ_I__( "engine.status_enabled" ) + CRLF )
         ELSE
            oEngineOutput:SetText( oEngineOutput:GetText() + _XQ_I__( "engine.status_disabled" ) + CRLF )
         ENDIF
      ENDIF

      // 更新状态栏
      UpdateStatus()

      // 重绘棋盘
      hwg_Invalidaterect( oChessBoard:handle )

      // 加载 FEN 棋局
      ShowDebugMsg( "=== Load game from FEN ===" )
      ShowDebugMsg( "FEN: " + cFen )

      // 手动构建棋盘字符串（紧凑格式）
      cBoardStr := ""
      FOR i := 1 TO 10
         FOR j := 1 TO 9
            nIdx := (i-1)*9 + j
            IF aBoard[nIdx] == "0"
               cBoardStr += "0"
            ELSE
               cBoardStr += aBoard[nIdx]
            ENDIF
         NEXT
      NEXT
      // ShowDebugMsg( "XQP: " + cBoardStr )  // 注释掉XQP输出
      ShowDebugMsg( "Current turn: " + Iif(lRedTurn, "RED", "BLACK") )
      ShowBoardString()
      ShowFen()

      // 检查游戏状态（将死/困毙）
      CheckGameState( aBoardPos, lRedTurn )

      // 如果是从 PGN 加载且有着法，自动走棋到目标局面
      IF Len( aPGNMoves ) > 0
         ShowDebugMsg( "=== Replaying moves to target position ===" )

         FOR k := 1 TO Len( aPGNMoves )
            cMoveStr := aPGNMoves[k]

            // 解析 UCCI 坐标（ICCS 格式）
            // 格式：列字母+行数字+列字母+行数字（如 "b7b0"）
            // 提取起始和目标坐标
            IF Len( cMoveStr ) == 4
               // 4位格式：列1+行1+列2+行2（如 b7b0）
               cFromCol := Upper( Left( cMoveStr, 1 ) )
               cFromRow := SubStr( cMoveStr, 2, 1 )
               cToCol := Upper( SubStr( cMoveStr, 3, 1 ) )
               cToRow := SubStr( cMoveStr, 4, 1 )
            ELSE
               ShowDebugMsg( "Warning: Invalid move format " + cMoveStr )
               LOOP
            ENDIF

            // 转换为数字坐标
            // 列：a-i -> 1-9
            // 行：UCCI 行号（0-9）转换为 GUI 行号（1-10）
            //     UCCI 行0 = 红方底线 = GUI 行10
            //     UCCI 行9 = 黑方底线 = GUI 行1
            //     公式：GUI行 = 10 - UCCI行
            nFromCol := Asc( Lower( cFromCol ) ) - Asc( 'a' ) + 1
            nFromRow := 10 - Val( cFromRow )
            nToCol := Asc( Lower( cToCol ) ) - Asc( 'a' ) + 1
            nToRow := 10 - Val( cToRow )

            // 将 UCCI 坐标转换为移动编码（用于验证）
            nMove := xq_UCCICoordToMovePublic( cMoveStr )

            IF nMove == 0
               ShowDebugMsg( "Warning: Invalid move " + cMoveStr )
               LOOP
            ENDIF

            // 验证走法是否正确
            aPos := BoardPosToPos()
            IF !xq_IsMoveCorrect( aPos, nMove )
               ShowDebugMsg( "Warning: Move verification failed " + cMoveStr )
               LOOP
            ENDIF

            // 保存移动前的棋盘状态（用于计算记谱法）
            aBoardBeforeMove := xq_StringToArray( aPos[POS_BOARD] )

            // 执行走棋（传递 4 个坐标参数）
            lResult := MovePiece( nFromCol, nFromRow, nToCol, nToRow )

            IF !lResult
               ShowDebugMsg( "Warning: Move execution failed " + cMoveStr )
               LOOP
            ENDIF

            // 添加到记谱法窗口（使用新的 API）
            // 计算回合：奇数索引为红方，偶数索引为黑方
            xq_Notation_AddMove( nMove, (k % 2 == 1), aBoardBeforeMove )
         NEXT
         
         ShowDebugMsg( "=== Replay completed ===" )
         ShowDebugMsg( "Replay completed: lRedTurn=" + Iif(lRedTurn, "RED", "BLACK") )

         // 重新获取棋盘状态
         // 将二维棋盘数组转换为一维数组（90元素）
         aTempBoard := Array( 90 )
         k := 1
         FOR i := 1 TO 10
            FOR j := 1 TO 9
               IF aBoardPos[i,j] != NIL
                  aTempBoard[k] := aBoardPos[i,j]
               ELSE
                  aTempBoard[k] := "0"
               ENDIF
               k++
            NEXT
         NEXT

         aResult := xq_FenToArrayBoard( xq_BoardToFenUCCI( aTempBoard, lRedTurn, 0, 1 ) )
         aBoard := aResult[1]
         lRedTurn := aResult[2]
      ENDIF

      // 如果当前是AI回合，触发AI走棋
      IF lRedTurn .AND. nRedPlayer > 1
         oAITimer := NIL
         ShowDebugMsg( "AI (RED) to move..." )
         oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
      ELSEIF !lRedTurn .AND. nBlackPlayer > 1
         oAITimer := NIL
         ShowDebugMsg( "AI (BLACK) to move..." )
         oAITimer := HTimer():New( oMainWnd, 1001, 2000, {|o|AIMakeMove()}, .T. )
      ENDIF

      hwg_MsgInfo( _XQ_I__( "message.game_loaded_from_fen" ) + CRLF + _XQ_I__( "message.current_turn" ) + ": " + Iif(lRedTurn, _XQ_I__( "side.red" ), _XQ_I__( "side.black" )) + Iif(Len(aPGNMoves)>0, CRLF+_XQ_I__( "message.moves_replayed" ) + " " + Str(Len(aPGNMoves)) + " " + _XQ_I__( "message.moves" ), "") )
   ENDIF

RETURN NIL

/*
 * 验证FEN格式
 *
 * 参数:
 *   cFen - FEN字符串
 *   cErrorMsg - 错误消息（通过引用返回）
 * 返回: .T. 合法, .F. 不合法
 */
static FUNCTION ValidateFen( cFen, cErrorMsg )
local cParts, cFenBoard, cTurn
local aRows, i, j, cRow, cPiece, nLen, nEmpty, nCount

   cErrorMsg := ""

   // 检查是否为空
   IF Empty( cFen )
      cErrorMsg := "FEN字符串为空"
      RETURN .F.
   ENDIF

   // 分割FEN字符串
   cParts := hb_ATokens( cFen, " " )
   
   // 至少要有两部分（棋盘和回合）
   IF Len( cParts ) < 2
      cErrorMsg := "FEN格式不完整，至少需要棋盘和回合信息"
      RETURN .F.
   ENDIF

   cFenBoard := cParts[1]
   cTurn := cParts[2]

   // 验证回合
   IF !(cTurn == "w" .OR. cTurn == "b")
      cErrorMsg := "回合信息必须是 'w' (红方) 或 'b' (黑方)"
      RETURN .F.
   ENDIF

   // 验证棋盘部分
   aRows := hb_ATokens( cFenBoard, "/" )
   
   // 必须有10行
   IF Len( aRows ) != 10
      cErrorMsg := "棋盘必须有10行，实际有 " + Str(Len(aRows)) + " 行"
      RETURN .F.
   ENDIF

   // 验证每一行
   FOR i := 1 TO 10
      cRow := aRows[i]
      nLen := 0
      nCount := 0
      nEmpty := 0
      
      // 解析行
      FOR j := 1 TO Len( cRow )
         cPiece := SubStr( cRow, j, 1 )
         
         IF cPiece >= "0" .AND. cPiece <= "9"
            // 数字表示空位
            nEmpty := Val( cPiece )
            nLen += nEmpty
         ELSE
            // 棋子
            nLen += 1
            nCount++
         ENDIF
      NEXT
      
      // 每行必须有9个位置
      IF nLen != 9
         cErrorMsg := "第 " + Str(i) + " 行位置数不正确，应该是9，实际是 " + Str(nLen)
         RETURN .F.
      ENDIF
   NEXT

RETURN .T.

/*
 * 显示帮助
 */
static FUNCTION ShowHelp()
   LOCAL cMsg1, cMsg2, cMsg3, cMsg4, cMsg5, cMsg6, cMsg7, cMsg8
   LOCAL oDlg, oTab, oBtnClose
   LOCAL oHelp1, oHelp2, oHelp3, oHelp4, oHelp5, oHelp6, oHelp7, oHelp8
   LOCAL nTop := Iif( "windows" $ Lower(Os()), 24, 0 )

   // 测试：在状态栏第三行显示帮助信息
   xq_showstatusbar( 3, _XQ_I__( "status.showhelp_open" ) )

   // 准备各页内容（使用国际化）
   cMsg1 := _XQ_I__( "help.basic.title" ) + hb_eol()
   cMsg1 += _XQ_I__( "help.basic.item1" ) + hb_eol()
   cMsg1 += _XQ_I__( "help.basic.item2" ) + hb_eol()
   cMsg1 += _XQ_I__( "help.basic.item3" ) + hb_eol()
   cMsg1 += _XQ_I__( "help.basic.item4" ) + hb_eol()
   cMsg1 += _XQ_I__( "help.basic.item5" ) + hb_eol()
   cMsg1 += _XQ_I__( "help.basic.item6" )

   cMsg2 := _XQ_I__( "help.modes.title" ) + hb_eol()
   cMsg2 += _XQ_I__( "help.modes.item1" ) + hb_eol()
   cMsg2 += _XQ_I__( "help.modes.item2" ) + hb_eol()
   cMsg2 += _XQ_I__( "help.modes.item3" ) + hb_eol()
   cMsg2 += _XQ_I__( "help.modes.item4" )

   cMsg3 := _XQ_I__( "help.menu.title" ) + hb_eol()
   cMsg3 += _XQ_I__( "help.menu.item1" ) + hb_eol()
   cMsg3 += _XQ_I__( "help.menu.item2" ) + hb_eol()
   cMsg3 += _XQ_I__( "help.menu.item3" ) + hb_eol()
   cMsg3 += _XQ_I__( "help.menu.item4" ) + hb_eol()
   cMsg3 += _XQ_I__( "help.menu.item5" ) + hb_eol()
   cMsg3 += _XQ_I__( "help.menu.item6" ) + hb_eol()
   cMsg3 += _XQ_I__( "help.menu.item7" )

   cMsg4 := _XQ_I__( "help.hotkeys.title" ) + hb_eol()
   cMsg4 += _XQ_I__( "help.hotkeys.line1" ) + hb_eol()
   cMsg4 += _XQ_I__( "help.hotkeys.line2" ) + hb_eol()
   cMsg4 += _XQ_I__( "help.hotkeys.line3" ) + hb_eol()
   cMsg4 += _XQ_I__( "help.hotkeys.line4" )

   cMsg5 := _XQ_I__( "help.options.title" ) + hb_eol()
   cMsg5 += _XQ_I__( "help.options.item1" ) + hb_eol()
   cMsg5 += _XQ_I__( "help.options.item2" ) + hb_eol()
   cMsg5 += _XQ_I__( "help.options.item3" ) + hb_eol()
   cMsg5 += _XQ_I__( "help.options.item4" ) + hb_eol()
   cMsg5 += _XQ_I__( "help.options.item5" ) + hb_eol()
   cMsg5 += _XQ_I__( "help.options.item6" ) + hb_eol()
   cMsg5 += _XQ_I__( "help.options.item7" ) + hb_eol()
   cMsg5 += _XQ_I__( "help.options.item8" )

   cMsg6 := _XQ_I__( "help.engines.title" ) + hb_eol()
   cMsg6 += _XQ_I__( "help.engines.item1" ) + hb_eol()
   cMsg6 += _XQ_I__( "help.engines.item2" ) + hb_eol()
   cMsg6 += hb_eol()
   cMsg6 += _XQ_I__( "help.engines.config" ) + hb_eol()
   cMsg6 += _XQ_I__( "help.engines.config_desc" ) + hb_eol()
   cMsg6 += hb_eol()
   cMsg6 += _XQ_I__( "help.engines.dual" ) + hb_eol()
   cMsg6 += _XQ_I__( "help.engines.dual_desc" )

   cMsg7 := _XQ_I__( "help.formats.title" ) + hb_eol()
   cMsg7 += _XQ_I__( "help.formats.pgn" ) + hb_eol()
   cMsg7 += _XQ_I__( "help.formats.pgn_desc" ) + hb_eol()
   cMsg7 += _XQ_I__( "help.formats.fen" ) + hb_eol()
   cMsg7 += _XQ_I__( "help.formats.fen_desc" ) + hb_eol()
   cMsg7 += _XQ_I__( "help.formats.ini" ) + hb_eol()
   cMsg7 += _XQ_I__( "help.formats.ini_desc" )

   cMsg8 := _XQ_I__( "help.technical.title" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.lang" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.gui" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.build" ) + hb_eol()
   cMsg8 += hb_eol()
   cMsg8 += _XQ_I__( "help.technical.protocols" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.ucci" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.uci" ) + hb_eol()
   cMsg8 += hb_eol()
   cMsg8 += _XQ_I__( "help.technical.notation" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.iccs" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.chinese" ) + hb_eol()
   cMsg8 += hb_eol()
   cMsg8 += _XQ_I__( "help.technical.rules" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.rule50" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.rule_perpetual" ) + hb_eol()
   cMsg8 += _XQ_I__( "help.technical.rule_repetition" )

   INIT DIALOG oDlg TITLE _XQ_I__( "help.title" ) AT (hwg_GetDesktopWidth()-560)/2, (hwg_GetDesktopHeight()-400)/2 SIZE 560, 400

   @ 10, 10 TAB oTab ITEMS {} SIZE 540, 330 OF oDlg

   BEGIN PAGE _XQ_I__( "help.tab.basic" ) OF oTab
   @ 10, nTop+10 EDITBOX oHelp1 CAPTION cMsg1 STYLE ES_MULTILINE SIZE 520, 280 OF oTab
   END PAGE OF oTab

   BEGIN PAGE _XQ_I__( "help.tab.modes" ) OF oTab
   @ 10, nTop+10 EDITBOX oHelp2 CAPTION cMsg2 STYLE ES_MULTILINE SIZE 520, 280 OF oTab
   END PAGE OF oTab

   BEGIN PAGE _XQ_I__( "help.tab.menu" ) OF oTab
   @ 10, nTop+10 EDITBOX oHelp3 CAPTION cMsg3 STYLE ES_MULTILINE SIZE 520, 280 OF oTab
   END PAGE OF oTab

   BEGIN PAGE _XQ_I__( "help.tab.hotkeys" ) OF oTab
   @ 10, nTop+10 EDITBOX oHelp4 CAPTION cMsg4 STYLE ES_MULTILINE SIZE 520, 280 OF oTab
   END PAGE OF oTab

   BEGIN PAGE _XQ_I__( "help.tab.options" ) OF oTab
   @ 10, nTop+10 EDITBOX oHelp5 CAPTION cMsg5 STYLE ES_MULTILINE SIZE 520, 280 OF oTab
   END PAGE OF oTab

   BEGIN PAGE _XQ_I__( "help.tab.engines" ) OF oTab
   @ 10, nTop+10 EDITBOX oHelp6 CAPTION cMsg6 STYLE ES_MULTILINE SIZE 520, 280 OF oTab
   END PAGE OF oTab

   BEGIN PAGE _XQ_I__( "help.tab.formats" ) OF oTab
   @ 10, nTop+10 EDITBOX oHelp7 CAPTION cMsg7 STYLE ES_MULTILINE SIZE 520, 280 OF oTab
   END PAGE OF oTab

   BEGIN PAGE _XQ_I__( "help.tab.technical" ) OF oTab
   @ 10, nTop+10 EDITBOX oHelp8 CAPTION cMsg8 STYLE ES_MULTILINE SIZE 520, 280 OF oTab
   END PAGE OF oTab

   @ 470, 350 BUTTON oBtnClose CAPTION _XQ_I__( "button.close" ) SIZE 60, 30 OF oDlg ;
      ON CLICK {|| xq_showstatusbar( 3, _XQ_I__( "status.showhelp_close" ) ), hwg_EndDialog()}

   ACTIVATE DIALOG oDlg

   // 测试：对话框关闭后恢复状态栏第三行
   xq_showstatusbar( 3, "" )

RETURN NIL

/*
 * 异步检查将死（使用定时器避免阻塞 GUI）
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION AsyncCheckCheckmate()
   LOCAL lOpponentInCheck
   LOCAL i, cMsg, aMoves
   LOCAL cUCCIMoves, cUCCI, nFromIdx, nToIdx, nMove, nAt, nAt2, cCleanMove
   LOCAL cFromStr, cToStr
   LOCAL cBoardStr, j

   IF !lGameRunning
      RETURN NIL
   ENDIF

   // 检查是否将军（检查对手是否被将军）
   lOpponentInCheck := xq_IsKingInCheck( aCheckmateBoard, !lCheckmateRedTurn )
   IF lOpponentInCheck
      // 检查是否将死（检查对手是否被将死）
      IF xq_IsCheckmate( aCheckmateBoard, !lCheckmateRedTurn )
         // 游戏结束，停止AI计时器
         lGameRunning := .F.
         lAITimerRunning := .F.
         UpdateStatus()
         
         // 播放胜负音效（当前玩家获胜）
         xq_PlaySound( Iif(lCheckmateRedTurn, "win", "loss"), lSoundEnabled, nMoveCount)
         
         // 弹窗提示
         hwg_MsgInfo( Iif(!lCheckmateRedTurn, _XQ_I__( "result.red_checkmated" ), _XQ_I__( "result.black_checkmated" )) )
      ENDIF
   ELSE
      // 检查是否困毙（对手没有被将军但无棋可走）
      IF !xq_HasLegalMoves( aCheckmateBoard, !lCheckmateRedTurn )
         // 游戏结束，停止AI计时器
         lGameRunning := .F.
         lAITimerRunning := .F.
         UpdateStatus()
         
         // 播放胜负音效（当前玩家获胜）
         xq_PlaySound( Iif(lCheckmateRedTurn, "win", "loss"), lSoundEnabled, nMoveCount)
         
         // 弹窗提示
         hwg_MsgInfo( Iif(!lCheckmateRedTurn, _XQ_I__( "result.red_stalemated" ), _XQ_I__( "result.black_stalemated" )) )
      ELSE
         ShowDebugMsg( Iif(!lCheckmateRedTurn, "RED", "BLACK") + " has legal moves, game continues", , LOG_LEVEL_INFO )
      ENDIF
   ENDIF

   // 清除定时器
   oCheckmateTimer := NIL

   // 清除运行标志
   lCheckmateCheckRunning := .F.

RETURN NIL

/*

 * 同步检查游戏状态（将死/困毙）

 * 用于加载 FEN 或 PGN 后立即检查

 *

 * 参数:

 *   aBoard - 棋盘数组

 *   lRedTurn - 红方回合标志

 * 返回: NIL

 */

static FUNCTION CheckGameState( aBoard, lRedTurn )

   LOCAL lOpponentInCheck

   LOCAL aBoardToCheck

   LOCAL i, j, nIdx

   LOCAL cBoardStr



   // 转换棋盘格式用于检查

   aBoardToCheck := Array( 90 )

   FOR i := 1 TO 10

      FOR j := 1 TO 9

         nIdx := (i-1)*9 + j

         aBoardToCheck[nIdx] := aBoard[i,j]

      NEXT

         NEXT

      

         // 检查当前回合的玩家是否被将军

         lOpponentInCheck := xq_IsKingInCheck( aBoardToCheck, lRedTurn )
   IF lOpponentInCheck
      // 检查是否将死（当前玩家被将军且无合法走法）
      IF xq_IsCheckmate( aBoardToCheck, lRedTurn )
         // 游戏结束，停止AI计时器
         lGameRunning := .F.
         lAITimerRunning := .F.
         UpdateStatus()
         
         // 播放胜负音效（当前玩家获胜）
         xq_PlaySound( Iif(!lRedTurn, "win", "loss"), lSoundEnabled, nMoveCount)
         
         // 弹窗提示
         hwg_MsgInfo( Iif(lRedTurn, _XQ_I__( "result.red_checkmated" ), _XQ_I__( "result.black_checkmated" )) )
      ENDIF
   ELSE
      // 检查是否困毙（当前玩家没有被将军但无棋可走）
      IF !xq_HasLegalMoves( aBoardToCheck, lRedTurn )
         // 游戏结束，停止AI计时器
         lGameRunning := .F.
         lAITimerRunning := .F.
         UpdateStatus()
         
         // 播放胜负音效（当前玩家获胜）
         xq_PlaySound( Iif(!lRedTurn, "win", "loss"), lSoundEnabled, nMoveCount)
         
         // 弹窗提示
         hwg_MsgInfo( Iif(lRedTurn, _XQ_I__( "result.red_stalemated" ), _XQ_I__( "result.black_stalemated" )) )
      ENDIF
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------

/*
 * 触发异步将死检查
 *
 * 参数:
 *   aBoard - 棋盘数组
 *   par_lRedTurn - 红方回合标志（走棋前的回合）
 * 返回: NIL
 */
static FUNCTION TriggerCheckmateCheck( aBoard, par_lRedTurn )
   // 如果已经有一个检查正在运行，不再触发新的检查
   IF lCheckmateCheckRunning
      RETURN NIL
   ENDIF

   ShowDebugMsg( "TriggerCheckmateCheck: par_lRedTurn=" + Iif(par_lRedTurn, "RED", "BLACK"), , LOG_LEVEL_DEBUG )
   ShowDebugMsg( "TriggerCheckmateCheck: global lRedTurn=" + Iif(lRedTurn, "RED", "BLACK"), , LOG_LEVEL_DEBUG )

   // 保存棋盘状态和回合信息（使用 AClone 复制数组，避免引用传递）
   aCheckmateBoard := AClone( aBoard )
   lCheckmateRedTurn := par_lRedTurn

   // 清除之前的定时器
   IF !Empty( oCheckmateTimer )
      oCheckmateTimer := NIL
   ENDIF

   // 设置运行标志
   lCheckmateCheckRunning := .T.

   // 延迟 100ms 后检查将死，避免阻塞 GUI
   oCheckmateTimer := HTimer():New( oMainWnd, 1002, 100, {|o|AsyncCheckCheckmate()}, .T. )

RETURN NIL

/*
 * 显示消息窗口右键菜单
 *
 * 参数:
 *   oBrowse - Browse 控件对象
 *   nCol - 点击的列位置
 *   nRow - 点击的行位置
 * 返回: NIL
 */
static FUNCTION PopupMenu_Show( oBrowse, nCol, nRow )
   // 显示菜单（CONTEXT MENU 创建的对象有 Show 方法）
   IF !Empty( oXQ_MsgMenu )
      oXQ_MsgMenu:Show( oBrowse )
   ENDIF

RETURN NIL

// ========== 消息窗口管理函数 ==========

/*
 * 创建消息窗口控件
 *
 * 参数:
 *   oWnd - 主窗口对象
 *   nRow, nCol - 位置
 *   nWidth, nHeight - 尺寸
 *   oFont - 字体对象
 * 返回: NIL
 */
static FUNCTION XQ_MsgWnd_Create( oWnd, nRow, nCol, nWidth, nHeight, oFont )
   
   // 创建 Browse 控件
   @ nRow, nCol BROWSE oXQ_MsgWnd ;
      ARRAY ;
      STYLE WS_VSCROLL + WS_HSCROLL + WS_BORDER ;
      SIZE nWidth, nHeight FONT oFont

   // 设置数据源
   oXQ_MsgWnd:aArray := aDebugLog

   // 添加列
   oXQ_MsgWnd:AddColumn(HColumn():New("Message", {|v,o|(v),o:aArray[o:nCurrent,1]}, "C", 100, 0))

   // 创建右键菜单
   CONTEXT MENU oXQ_MsgMenu
      MENUITEM _XQ_I__( "notation.copy_current" ) ACTION XQ_MsgWnd_CopyCurrent()
      MENUITEM _XQ_I__( "notation.copy_all" ) ACTION XQ_MsgWnd_CopyAll()
   ENDMENU

   // 设置右键点击事件
   oXQ_MsgWnd:bRClick := {|o,nCol,nRow|PopupMenu_Show(o,nCol,nRow)}

RETURN NIL

/*
 * 显示消息到窗口
 *
 * 参数:
 *   cMsg - 要显示的消息
 *   nColor - 消息颜色（可选，默认黑色）
 * 返回: NIL
 */
function XQ_MsgWnd_ShowMsg( cMsg, nColor )
   LOCAL nCount
   
   // 仅在调试模式下显示消息
   IF !lDebugMode
      RETURN NIL
   ENDIF
   
   IF PCOUNT() < 2 .OR. Empty( nColor )
      nColor := 0x000000  // 默认黑色文字
   ENDIF

   IF !Empty( oXQ_MsgWnd )
      // 初始化数组（如果需要）
      IF oXQ_MsgWnd:aArray == NIL
         oXQ_MsgWnd:aArray := {}
      ENDIF
      
      // 添加新日志记录
      AADD(oXQ_MsgWnd:aArray, {cMsg})
      
      // 限制最大行数
      nCount := Len(oXQ_MsgWnd:aArray)
      IF nCount > LOG_MAX_LINES
         // 删除最早的 100 行
         ADel(oXQ_MsgWnd:aArray, 1, .T.)
         // 调整数组大小
         ASize(oXQ_MsgWnd:aArray, nCount - 100)
      ENDIF
      
      // 更新记录数
      oXQ_MsgWnd:nRecords := Len(oXQ_MsgWnd:aArray)
      
      // 跳转到最后一行（自动滚动）
      oXQ_MsgWnd:Bottom()
      
      // 刷新显示
      oXQ_MsgWnd:Refresh()
      
      // 更新状态栏临时消息并刷新显示
      cTempMsg := cMsg
      UpdateStatus()
   ENDIF

RETURN NIL

/*
 * 清空消息窗口
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION XQ_MsgWnd_Clear()
   
   IF !Empty( oXQ_MsgWnd )
      oXQ_MsgWnd:aArray := {}
      oXQ_MsgWnd:Refresh()
   ENDIF

RETURN NIL

/*
 * 复制当前行到剪贴板
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION XQ_MsgWnd_CopyCurrent()
   LOCAL cText := ""

   IF !Empty(oXQ_MsgWnd) .AND. !Empty(oXQ_MsgWnd:aArray) .AND. oXQ_MsgWnd:nCurrent > 0
      IF oXQ_MsgWnd:nCurrent <= Len(oXQ_MsgWnd:aArray)
         cText := oXQ_MsgWnd:aArray[oXQ_MsgWnd:nCurrent,1]

         // 复制到剪贴板
         hwg_CopyStringToClipboard(cText)
         hwg_MsgInfo(_XQ_I__( "message.copied" ) + ": " + Left(cText, 50) + Iif(Len(cText) > 50, "...", ""))
      ENDIF
   ELSE
      hwg_MsgInfo(_XQ_I__( "message.no_message_selected" ))
   ENDIF

RETURN NIL

/*
 * 复制全部消息到剪贴板
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION XQ_MsgWnd_CopyAll()
   LOCAL cAllText := ""
   LOCAL i
   LOCAL cNewLine := hb_osNewLine()

   IF Empty(oXQ_MsgWnd) .OR. Empty(oXQ_MsgWnd:aArray)
      hwg_MsgInfo(_XQ_I__( "message.no_messages_to_copy" ), _XQ_I__( "message.hint" ))
      RETURN NIL
   ENDIF

   // 合并所有消息，每行一个
   FOR i := 1 TO Len(oXQ_MsgWnd:aArray)
      IF ValType(oXQ_MsgWnd:aArray[i]) == "A" .AND. Len(oXQ_MsgWnd:aArray[i]) >= 1
         cAllText += oXQ_MsgWnd:aArray[i][1] + cNewLine
      ENDIF
   NEXT

   // 复制到剪贴板
   IF !Empty( cAllText )
      hwg_CopyStringToClipboard( cAllText )
      hwg_MsgInfo( _XQ_I__( "message.copied_messages" ) + " " + Str( Len(oXQ_MsgWnd:aArray) ) + " " + _XQ_I__( "message.messages" ), _XQ_I__( "message.hint" ))
   ENDIF

RETURN NIL

/*
 * 滚动到消息窗口底部
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION XQ_MsgWnd_ScrollBottom()
   
   IF !Empty( oXQ_MsgWnd ) .AND. Len(oXQ_MsgWnd:aArray) > 0
      oXQ_MsgWnd:Bottom()
      hwg_SetFocus( oXQ_MsgWnd:handle )
   ENDIF

RETURN NIL

/*
 * 简单的翻译函数
 *
 * 参数:
 *   cKey - 翻译键
 * 返回: 当前语言的翻译文本
 */
static FUNCTION I18N( cKey )
   IF lCurrentLanguage == "en"
      // 英文
      DO CASE
      CASE cKey == "menu_newgame"; RETURN "New Game"
      CASE cKey == "menu_save"; RETURN "Save"
      CASE cKey == "menu_load"; RETURN "Load"
      CASE cKey == "menu_undo"; RETURN "Undo"
      CASE cKey == "menu_options"; RETURN "Options"
      CASE cKey == "menu_help"; RETURN "Help"
      CASE cKey == "menu_stopai"; RETURN "Stop AI"
      
      CASE cKey == "status_red_turn"; RETURN "Red's turn"
      CASE cKey == "status_black_turn"; RETURN "Black's turn"
      CASE cKey == "status_waiting"; RETURN "Waiting to start"
      
      CASE cKey == "msg_no_undo"; RETURN "No moves to undo"
      CASE cKey == "msg_game_over"; RETURN "Game over, cannot undo"
      CASE cKey == "msg_undo_success"; RETURN "Undo successful"
      CASE cKey == "msg_red_wins"; RETURN "Red wins!"
      CASE cKey == "msg_black_wins"; RETURN "Black wins!"
      CASE cKey == "msg_draw"; RETURN "Draw!"
      
      CASE cKey == "options_language"; RETURN "Language"
      CASE cKey == "options_language_en"; RETURN "English"
      CASE cKey == "options_language_zh"; RETURN "中文"
      
      OTHERWISE; RETURN cKey
      ENDCASE
   ELSE
      // 中文
      DO CASE
      CASE cKey == "menu_newgame"; RETURN "新游戏"
      CASE cKey == "menu_save"; RETURN "保存"
      CASE cKey == "menu_load"; RETURN "加载"
      CASE cKey == "menu_undo"; RETURN "悔棋"
      CASE cKey == "menu_options"; RETURN "选项"
      CASE cKey == "menu_help"; RETURN "帮助"
      CASE cKey == "menu_stopai"; RETURN "停止AI"
      
      CASE cKey == "status_red_turn"; RETURN "红方走棋"
      CASE cKey == "status_black_turn"; RETURN "黑方走棋"
      CASE cKey == "status_waiting"; RETURN "等待开局"
      
      CASE cKey == "msg_no_undo"; RETURN "没有可悔棋的步骤"
      CASE cKey == "msg_game_over"; RETURN "游戏已结束，无法悔棋"
      CASE cKey == "msg_undo_success"; RETURN "悔棋成功"
      CASE cKey == "msg_red_wins"; RETURN "红方胜利！"
      CASE cKey == "msg_black_wins"; RETURN "黑方胜利！"
      CASE cKey == "msg_draw"; RETURN "和棋！"
      
      CASE cKey == "options_language"; RETURN "语言"
      CASE cKey == "options_language_en"; RETURN "English"
      CASE cKey == "options_language_zh"; RETURN "中文"
      
      OTHERWISE; RETURN cKey
      ENDCASE
   ENDIF

RETURN NIL

/*
 * 播放音效
 *
 * 参数:
 *   cSoundType - 音效类型: "move", "capture", "check", "win", "loss", "draw", "newgame"
 */
// 播放音效函数已移至 xq_res.prg

/*
 * 获取当前选择的语言
 *
 * 参数: 无
 * 返回: 语言代码 ("en" 或 "zh")
 */
static FUNCTION GetCurrentSelectedLanguage()
   LOCAL nSel, cLang

   nSel := 1
   IF ValType( oComboLanguage ) == "O"
      nSel := oComboLanguage:Value()
      OutErr( "GetCurrentSelectedLanguage: oComboLanguage:Value()=" + Str( nSel ), hb_eol() )
   ELSE
      OutErr( "GetCurrentSelectedLanguage: oComboLanguage is NIL or not object", hb_eol() )
   ENDIF

   cLang := iif( nSel == 1, "en", "zh" )
   OutErr( "GetCurrentSelectedLanguage: returning " + cLang, hb_eol() )

RETURN cLang

//--------------------------------------------------------------------------------

/*
 * 更新主窗口的所有界面文本
 *
 * 参数: 无
 * 返回: NIL
 */
static FUNCTION UpdateMainWindowText()
   OutErr( "UpdateMainWindowText: starting", hb_eol() )

   // 更新窗口标题
   IF ValType( oMainWnd ) == "O"
      oMainWnd:SetTitle( _XQ_I__( "app.title" ) )
      OutErr( "UpdateMainWindowText: title updated to " + _XQ_I__( "app.title" ), hb_eol() )
   ENDIF

   // 更新按钮文本（OWNERBUTTON 可能不支持动态更新文本）
   // 先只更新窗口标题，按钮文本需要重启才能生效

   OutErr( "UpdateMainWindowText: completed", hb_eol() )
RETURN NIL

//--------------------------------------------------------------------------------

static FUNCTION CheckLanguageAndSave()
   LOCAL nSelected, cNewLanguage

   OutErr( "CheckLanguageAndSave: starting", hb_eol() )

   // 使用类型检查确保不会崩溃
   IF ValType( oComboLanguage ) == "O"
      OutErr( "CheckLanguageAndSave: oComboLanguage is object", hb_eol() )
      BEGIN SEQUENCE
         nSelected := oComboLanguage:Value()
         OutErr( "CheckLanguageAndSave: nSelected=" + Str( nSelected ), hb_eol() )
         IF ValType( nSelected ) == "N"
            IF nSelected == 1
               cNewLanguage := "en"
            ELSE
               cNewLanguage := "zh"
            ENDIF

            IF ValType( lCurrentLanguage ) == "C" .AND. cNewLanguage != lCurrentLanguage
               lCurrentLanguage := cNewLanguage
               xq_SetLanguage( lCurrentLanguage )
               xq_ConfigSet( "UISettings", "Language", lCurrentLanguage )
               xq_ConfigSave()
               UpdateMainWindowText()
               hwg_MsgInfo( _XQ_I__( "message.language_changed" ) )
            ENDIF
         ENDIF
      RECOVER
         OutErr( "CheckLanguageAndSave: error calling Value", hb_eol() )
      END SEQUENCE
   ELSE
      OutErr( "CheckLanguageAndSave: oComboLanguage is not object, type=" + ValType( oComboLanguage ), hb_eol() )
   ENDIF

RETURN NIL

//--------------------------------------------------------------------------------
/*
 * 画线棋盘绘制函数
 * 根据棋盘大小自动绘制中国象棋棋盘
 *
 * 参数:
 *   par_hDC - 设备上下文句柄
 *   par_nStartX - 起始X坐标
 *   par_nStartY - 起始Y坐标
 *   par_nCellWidth - 单元格宽度
 *   par_nCellHeight - 单元格高度
 *
 * 返回: NIL
 */
FUNCTION DrawLineBoard( par_hDC, par_nStartX, par_nStartY, par_nCellWidth, par_nCellHeight )

   LOCAL l_oPenThick, l_oPenMedium, l_oPenThin, l_oPenBorder
   LOCAL l_oBrush
   LOCAL l_i, l_j, l_nX, l_nY
   LOCAL l_nBoardWidth := 8 * par_nCellWidth
   LOCAL l_nBoardHeight := 9 * par_nCellHeight

   // 绘制背景色（浅绿色）
   l_oBrush := HBrush():Add( 0xAFBEA3 )  // 浅绿色背景
   hwg_FillRect( par_hDC, par_nStartX - 20, par_nStartY - 20, ;
                 par_nStartX + l_nBoardWidth + 20, par_nStartY + l_nBoardHeight + 20, ;
                 l_oBrush:handle )
   l_oBrush:Release()

   // 创建画笔
   l_oPenThick := HPen():Add( PS_SOLID, 3, 0x000000 )
   l_oPenMedium := HPen():Add( PS_SOLID, 2, 0x000000 )
   l_oPenThin := HPen():Add( PS_SOLID, 1, 0x000000 )
   l_oPenBorder := HPen():Add( PS_SOLID, 5, 0x000000 )

   // 绘制四条边界线（黑色加粗）
   hwg_Selectobject( par_hDC, l_oPenBorder:handle )
   hwg_Drawline( par_hDC, par_nStartX, par_nStartY, ;
                 par_nStartX + l_nBoardWidth, par_nStartY )
   hwg_Drawline( par_hDC, par_nStartX, par_nStartY + l_nBoardHeight, ;
                 par_nStartX + l_nBoardWidth, par_nStartY + l_nBoardHeight )
   hwg_Drawline( par_hDC, par_nStartX, par_nStartY, ;
                 par_nStartX, par_nStartY + l_nBoardHeight )
   hwg_Drawline( par_hDC, par_nStartX + l_nBoardWidth, par_nStartY, ;
                 par_nStartX + l_nBoardWidth, par_nStartY + l_nBoardHeight )

   // 绘制横线（9条）
   hwg_Selectobject( par_hDC, l_oPenThin:handle )
   FOR l_i := 1 TO 8
      l_nY := par_nStartY + l_i * par_nCellHeight
      hwg_Drawline( par_hDC, par_nStartX, l_nY, ;
                    par_nStartX + l_nBoardWidth, l_nY )
   NEXT

   // 绘制竖线（8条，中间断开楚河）
   FOR l_j := 1 TO 7
      l_nX := par_nStartX + l_j * par_nCellWidth
      hwg_Drawline( par_hDC, l_nX, par_nStartY, ;
                    l_nX, par_nStartY + 4 * par_nCellHeight )
      hwg_Drawline( par_hDC, l_nX, par_nStartY + 5 * par_nCellHeight, ;
                    l_nX, par_nStartY + l_nBoardHeight )
   NEXT

   // 绘制九宫格斜线（黑方）
   hwg_Drawline( par_hDC, par_nStartX + 3 * par_nCellWidth, par_nStartY, ;
                 par_nStartX + 5 * par_nCellWidth, par_nStartY + 2 * par_nCellHeight )
   hwg_Drawline( par_hDC, par_nStartX + 5 * par_nCellWidth, par_nStartY, ;
                 par_nStartX + 3 * par_nCellWidth, par_nStartY + 2 * par_nCellHeight )

   // 绘制九宫格斜线（红方）
   hwg_Drawline( par_hDC, par_nStartX + 3 * par_nCellWidth, par_nStartY + 7 * par_nCellHeight, ;
                 par_nStartX + 5 * par_nCellWidth, par_nStartY + 9 * par_nCellHeight )
   hwg_Drawline( par_hDC, par_nStartX + 5 * par_nCellWidth, par_nStartY + 7 * par_nCellHeight, ;
                 par_nStartX + 3 * par_nCellWidth, par_nStartY + 9 * par_nCellHeight )

   // 释放画笔
   l_oPenThick:Release()
   l_oPenMedium:Release()
   l_oPenThin:Release()
   l_oPenBorder:Release()

RETURN NIL

//--------------------------------------------------------------------------------
/**
 * 检查调试模式是否启用
 * @return .T. 启用, .F. 未启用
 */
function IsDebugEnabled()
   RETURN lDebugMode

//--------------------------------------------------------------------------------
