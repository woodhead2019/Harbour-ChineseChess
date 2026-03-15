/*
 * 中国象棋国际化（i18n）模块
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 提供多语言支持，默认英文
 */

#include "xq_xiangqi.ch"

// ========== 代码页声明 ==========
REQUEST HB_CODEPAGE_GBK

// ========== 全局变量 ==========
static s_hTranslations := {=>}  // 翻译哈希表
static s_cCurrentLanguage := "en"  // 当前语言（默认英文）

//--------------------------------------------------------------------------------

FUNCTION xq_I18NInit()
   // 初始化翻译表
   xq_LoadTranslations( "en" )
   xq_LoadTranslations( "zh" )
RETURN NIL

//--------------------------------------------------------------------------------

FUNCTION xq_SetLanguage( par_cLanguage )
   // 设置当前语言
   IF hb_HHasKey( s_hTranslations, par_cLanguage )
      s_cCurrentLanguage := par_cLanguage
      RETURN .T.
   ENDIF
RETURN .F.

//--------------------------------------------------------------------------------

FUNCTION xq_GetLanguage()
   // 获取当前语言
RETURN s_cCurrentLanguage

//--------------------------------------------------------------------------------

FUNCTION xq_GetAvailableLanguages()
   // 获取可用语言列表
RETURN hb_HKeys( s_hTranslations )

//--------------------------------------------------------------------------------

STATIC FUNCTION xq_ConvertForDisplay( par_cText )
   // 根据平台转换字符串以供显示
   // 参数: par_cText - 要转换的文本（UTF-8 编码）
   // 返回: 转换后的文本（Windows 下为 GBK，Linux 下为 UTF-8）
   LOCAL l_cResult := par_cText

#ifdef __PLATFORM__WINDOWS
   // Windows 下：将 UTF-8 转换为 GBK
   // 这样中文字符才能在 Windows GUI 中正确显示
   IF !Empty( par_cText )
      l_cResult := hb_utf8ToStr( par_cText, "GBK" )
   ENDIF
#endif

RETURN l_cResult

//--------------------------------------------------------------------------------

FUNCTION xq_Translate( par_cKey, par_cParams )
   // 翻译字符串
   LOCAL l_cText, l_i, l_cParam

   l_cText := xq_GetTranslation( par_cKey )

   // 如果有参数，替换占位符
   IF HB_ISARRAY( par_cParams )
      FOR l_i := 1 TO Len( par_cParams )
         l_cParam := par_cParams[ l_i ]
         l_cText := StrTran( l_cText, "{" + Str( l_i - 1 ) + "}", l_cParam )
      NEXT
   ENDIF

   // 根据平台转换编码（Windows 下 UTF-8 -> GBK）
   l_cText := xq_ConvertForDisplay( l_cText )

RETURN l_cText

//--------------------------------------------------------------------------------

STATIC FUNCTION xq_GetTranslation( par_cKey )
   // 获取翻译文本
   LOCAL l_hLang

   IF hb_HHasKey( s_hTranslations, s_cCurrentLanguage )
      l_hLang := s_hTranslations[ s_cCurrentLanguage ]
      IF hb_HHasKey( l_hLang, par_cKey )
         RETURN l_hLang[ par_cKey ]
      ENDIF
   ENDIF

   // 如果找不到翻译，返回键名本身
RETURN par_cKey

//--------------------------------------------------------------------------------

STATIC FUNCTION xq_LoadTranslations( par_cLanguage )
   // 加载指定语言的翻译
   LOCAL l_hLang := {=>}

   SWITCH par_cLanguage
   CASE "en"
      l_hLang := xq_LoadEnglishTranslations()
      EXIT

   CASE "zh"
      l_hLang := xq_LoadChineseTranslations()
      EXIT
   ENDSWITCH

   s_hTranslations[ par_cLanguage ] := l_hLang
RETURN NIL

//--------------------------------------------------------------------------------

STATIC FUNCTION xq_LoadEnglishTranslations()
   // 加载英文翻译
   LOCAL l_hLang := {=>}

   // 应用程序
   l_hLang[ "app.title" ] := "Chinese Chess"

   // 对话框
   l_hLang[ "dialog.select_players" ] := "Select Player Mode"
   l_hLang[ "dialog.game_options" ] := "Game Options"

   // 标签页
   l_hLang[ "tab.game_settings" ] := "Game Settings"
   l_hLang[ "tab.ui_settings" ] := "UI Settings"
   l_hLang[ "tab.engine_settings" ] := "Engine Settings"

   // 标签
   l_hLang[ "label.red" ] := "Red:"
   l_hLang[ "label.black" ] := "Black:"

   // 选项
   l_hLang[ "option.enable_debug" ] := "Enable Debug Mode"
   l_hLang[ "option.enable_ai" ] := "Enable AI"
   l_hLang[ "option.enable_sound" ] := "Enable Sound"
   l_hLang[ "option.auto_save" ] := "Auto Save Game"
   l_hLang[ "option.show_hints" ] := "Show Move Hints"
   l_hLang[ "option.show_coords" ] := "Show Coordinates"
   l_hLang[ "option.show_last_move" ] := "Show Last Move"
   l_hLang[ "player.mode.dialog.title" ] := "Select Player Mode"
   l_hLang[ "game.options.dialog.title" ] := "Game Options"
   l_hLang[ "help.dialog.title" ] := "Help"

   // 菜单项
      l_hLang[ "menu.file" ] := "File"
      l_hLang[ "menu.new" ] := "New Game"
      l_hLang[ "menu.load" ] := "Load Game"
      l_hLang[ "menu.save" ] := "Save Game"
      l_hLang[ "menu.exit" ] := "Exit"
      l_hLang[ "menu.game" ] := "Game"
      l_hLang[ "menu.players_settings" ] := "Players Settings"
      l_hLang[ "menu.resign" ] := "Resign"
      l_hLang[ "menu.stop_game" ] := "Stop Game"
      l_hLang[ "menu.stop_ai" ] := "Stop AI"
      l_hLang[ "menu.options" ] := "Options"
      l_hLang[ "menu.language" ] := "Language"
      l_hLang[ "menu.help" ] := "Help"
      l_hLang[ "menu.about" ] := "About"
   // 帮助对话框
   l_hLang[ "help.title" ] := "Chinese Chess - Help v0.9.9"
   l_hLang[ "help.tab.basic" ] := "Basic Operations"
   l_hLang[ "help.tab.modes" ] := "Game Modes"
   l_hLang[ "help.tab.menu" ] := "Menu Functions"
   l_hLang[ "help.tab.hotkeys" ] := "Hotkeys"
   l_hLang[ "help.tab.options" ] := "Options Settings"
   l_hLang[ "help.tab.engines" ] := "AI Engines"
   l_hLang[ "help.tab.formats" ] := "File Formats"
   l_hLang[ "help.tab.technical" ] := "Technical Info"

   // 帮助内容 - 基本操作
   l_hLang[ "help.basic.title" ] := "Basic Operations:"
   l_hLang[ "help.basic.item1" ] := "- Click a piece to select, then click target position to move"
   l_hLang[ "help.basic.item2" ] := "- Red moves first, players take turns"
   l_hLang[ "help.basic.item3" ] := "- Follow Chinese Chess rules (Horse moves in '日', Elephant in '田', etc.)"
   l_hLang[ "help.basic.item4" ] := "- Capture or pawn move resets 50-move counter"
   l_hLang[ "help.basic.item5" ] := "- Perpetual check forbidden (6 consecutive checks)"
   l_hLang[ "help.basic.item6" ] := "- Threefold repetition is a draw"

   // 帮助内容 - 游戏模式
   l_hLang[ "help.modes.title" ] := "Game Modes:"
   l_hLang[ "help.modes.item1" ] := "- Player vs Player - Two-player battle"
   l_hLang[ "help.modes.item2" ] := "- Player vs AI1 - Using ElephantEye engine"
   l_hLang[ "help.modes.item3" ] := "- Player vs AI2 - Using Pikafish engine"
   l_hLang[ "help.modes.item4" ] := "- AI vs AI - Dual-engine self-play"

   // 帮助内容 - 菜单功能
   l_hLang[ "help.menu.title" ] := "Menu Functions:"
   l_hLang[ "help.menu.item1" ] := "- New Game - Start a new game"
   l_hLang[ "help.menu.item2" ] := "- Players - Select Red and Black player types"
   l_hLang[ "help.menu.item3" ] := "- Load - Load PGN/FEN format game"
   l_hLang[ "help.menu.item4" ] := "- Save - Save current game as PGN"
   l_hLang[ "help.menu.item5" ] := "- Undo - Undo last move"
   l_hLang[ "help.menu.item6" ] := "- Options - Set game parameters and engines"
   l_hLang[ "help.menu.item7" ] := "- Stop AI - Interrupt AI thinking"

   // 帮助内容 - 快捷键
   l_hLang[ "help.hotkeys.title" ] := "Hotkeys:"
   l_hLang[ "help.hotkeys.line1" ] := "F1 - Help  F3 - New Game  F4 - Load"
   l_hLang[ "help.hotkeys.line2" ] := "F6 - Players  F8 - Options"
   l_hLang[ "help.hotkeys.line3" ] := "Ctrl+S - Save  Ctrl+L - Load"
   l_hLang[ "help.hotkeys.line4" ] := "Ctrl+Z - Undo  Ctrl+T - Stop AI"

   // 帮助内容 - 选项设置
   l_hLang[ "help.options.title" ] := "Options Settings:"
   l_hLang[ "help.options.item1" ] := "- AI Difficulty 1-5 levels (Beginner to Master)"
   l_hLang[ "help.options.item2" ] := "- AI Think Time 1-10 seconds"
   l_hLang[ "help.options.item3" ] := "- AI Max Moves (0=unlimited)"
   l_hLang[ "help.options.item4" ] := "- Board Style: Wood/Classic/Retro"
   l_hLang[ "help.options.item5" ] := "- Piece Style: Traditional/Modern/Cartoon"
   l_hLang[ "help.options.item6" ] := "- Show move hints/coordinates/last move"
   l_hLang[ "help.options.item7" ] := "- Sound and auto-save toggles"
   l_hLang[ "help.options.item8" ] := "- Language: Chinese/English"

   // 帮助内容 - AI 引擎
   l_hLang[ "help.engines.title" ] := "AI Engines:"
   l_hLang[ "help.engines.item1" ] := "- AI1 - ElephantEye (UCCI protocol)"
   l_hLang[ "help.engines.item2" ] := "- AI2 - Pikafish (UCI protocol)"
   l_hLang[ "help.engines.config" ] := "Configuration:"
   l_hLang[ "help.engines.config_desc" ] := "Options → Engine Settings → Select engine file"
   l_hLang[ "help.engines.dual" ] := "Dual Engine Battle:"
   l_hLang[ "help.engines.dual_desc" ] := "Support AI1 vs AI2 dual-engine battle"

   // 帮助内容 - 文件格式
   l_hLang[ "help.formats.title" ] := "File Formats:"
   l_hLang[ "help.formats.pgn" ] := "• PGN - Portable Game Notation"
   l_hLang[ "help.formats.pgn_desc" ] := "  Records entire game moves, can save and load complete games"
   l_hLang[ "help.formats.fen" ] := "• FEN - Forsyth-Edwards Notation"
   l_hLang[ "help.formats.fen_desc" ] := "  Describes current game state (position, turn, etc.)"
   l_hLang[ "help.formats.ini" ] := "• INI - Game configuration file"
   l_hLang[ "help.formats.ini_desc" ] := "  Stores game settings and preferences"

   // 帮助内容 - 技术信息
   l_hLang[ "help.technical.title" ] := "Development Environment:"
   l_hLang[ "help.technical.lang" ] := "Language: Harbour 3.2.0dev"
   l_hLang[ "help.technical.gui" ] := "GUI: HwGUI (Lightweight framework)"
   l_hLang[ "help.technical.build" ] := "Build: hbmk2 + GCC/Mingw64"
   l_hLang[ "help.technical.protocols" ] := "Engine Protocols:"
   l_hLang[ "help.technical.ucci" ] := "• UCCI - Chinese Chess specific protocol (ElephantEye)"
   l_hLang[ "help.technical.uci" ] := "• UCI - International Chess protocol (Pikafish needs conversion)"
   l_hLang[ "help.technical.notation" ] := "Move Notation:"
   l_hLang[ "help.technical.iccs" ] := "• ICCS: h2e2 (Red perspective, a-h columns/1-9 rows)"
   l_hLang[ "help.technical.chinese" ] := "- Chinese: 炮二平五 (Traditional notation)"
   l_hLang[ "help.technical.rules" ] := "Rule System:"
   l_hLang[ "help.technical.rule50" ] := "• 50-move rule - Draw if 50 moves without capture or pawn move"
   l_hLang[ "help.technical.rule_perpetual" ] := "- Perpetual check forbidden - 6 consecutive checks"
   l_hLang[ "help.technical.rule_repetition" ] := "- Threefold repetition - Same position 3 times is a draw"

   // 按钮
   l_hLang[ "button.new_game" ] := "New Game"
   l_hLang[ "button.game" ] := "Game"
   l_hLang[ "button.load" ] := "Load"
   l_hLang[ "button.save" ] := "Save"
   l_hLang[ "button.options" ] := "Options"
   l_hLang[ "button.undo" ] := "Undo"
   l_hLang[ "button.help" ] := "Help"
   l_hLang[ "button.stop_ai" ] := "Stop AI"
   l_hLang[ "button.players_settings" ] := "Players Settings"
   l_hLang[ "button.resign" ] := "Resign"
   l_hLang[ "button.stop_game" ] := "Stop Game"
   l_hLang[ "button.ok" ] := "OK"
   l_hLang[ "button.cancel" ] := "Cancel"
   l_hLang[ "button.yes" ] := "Yes"
   l_hLang[ "button.no" ] := "No"

   // 对话框
   l_hLang[ "dialog.load_game_title" ] := "Load Game"
   l_hLang[ "dialog.save_game_title" ] := "Save Game"

   // 帮助对话框
   l_hLang[ "button.close" ] := "Close"

   // 工具提示
   l_hLang[ "tooltip.new_game" ] := "New Game (F3)"
   l_hLang[ "tooltip.game" ] := "Game Menu (F6)"
   l_hLang[ "tooltip.load" ] := "Load Game (F4)"
   l_hLang[ "tooltip.save" ] := "Save Game"
   l_hLang[ "tooltip.options" ] := "Settings"
   l_hLang[ "tooltip.undo" ] := "Undo (Ctrl+Z)"
   l_hLang[ "tooltip.help" ] := "Help (F1)"
   l_hLang[ "tooltip.stop_ai" ] := "Stop AI (F8)"

   // 游戏状态
   l_hLang[ "status.waiting" ] := "Waiting to start"
   l_hLang[ "status.red_turn" ] := "Red's turn"
   l_hLang[ "status.black_turn" ] := "Black's turn"
   l_hLang[ "status.check" ] := "Check!"
   l_hLang[ "status.showhelp_open" ] := "ShowHelp: 打开帮助对话框"
   l_hLang[ "status.showhelp_close" ] := "ShowHelp: 关闭帮助对话框"

   // 游戏结果
   l_hLang[ "result.red_wins" ] := "Red wins!"
   l_hLang[ "result.black_wins" ] := "Black wins!"
   l_hLang[ "result.red_resign" ] := "Red resigned! Black wins!"
   l_hLang[ "result.black_resign" ] := "Black resigned! Red wins!"
   l_hLang[ "result.draw_50_moves" ] := "Draw! 50-move rule (no captures or pawn moves)"
   l_hLang[ "result.draw_50move" ] := "Draw! 50-move rule (no captures or pawn moves)"
   l_hLang[ "result.red_checkmated" ] := "Red is checkmated! Black wins!"
   l_hLang[ "result.black_checkmated" ] := "Black is checkmated! Red wins!"
   l_hLang[ "result.red_stalemate" ] := "Red is stalemated! Black wins!"
   l_hLang[ "result.red_stalemated" ] := "Red is stalemated! Black wins!"
   l_hLang[ "result.black_stalemate" ] := "Black is stalemated! Red wins!"
   l_hLang[ "result.black_stalemated" ] := "Black is stalemated! Red wins!"
   l_hLang[ "result.red_perpetual_check" ] := "Red perpetual check! Black wins!"
   l_hLang[ "result.black_perpetual_check" ] := "Black perpetual check! Red wins!"
   l_hLang[ "result.perpetual_check_red" ] := "Red perpetual check! Black wins!"
   l_hLang[ "result.perpetual_check_black" ] := "Black perpetual check! Red wins!"
   l_hLang[ "result.draw_repetition" ] := "Draw! Threefold repetition"

   // 消息
   l_hLang[ "message.config_saved" ] := "Configuration saved to cchess.ini"
   l_hLang[ "message.settings_applied" ] := "Settings applied"
   l_hLang[ "message.game_saved" ] := "Game saved to:"
   l_hLang[ "message.save_failed" ] := "Save failed!"
   l_hLang[ "message.load_failed" ] := "Load failed!"
   l_hLang[ "message.load_this_game" ] := "Load this game?"
   l_hLang[ "message.fen_format_error" ] := "FEN format error!"
   l_hLang[ "message.game_loaded_from_fen" ] := "Game loaded from FEN!"

   // 加载游戏对话框
   l_hLang[ "dialog.load_game_select_method" ] := "Load game from file?"
   l_hLang[ "dialog.load_game_from_file" ] := "  - Select [Yes] to load from file"
   l_hLang[ "dialog.load_game_manual_fen" ] := "  - Select [No] to enter FEN string manually"
   l_hLang[ "dialog.load_game_manual_title" ] := "Load Game (Enter FEN manually)"
   l_hLang[ "dialog.load_game_fen_prompt" ] := "Please enter FEN string:"
   l_hLang[ "dialog.load_game_title" ] := "Load Game"
   l_hLang[ "message.current_turn" ] := "Current turn"
   l_hLang[ "message.moves_replayed" ] := "Moves replayed"
   l_hLang[ "message.moves" ] := "moves"
   l_hLang[ "message.copied" ] := "Copied"
   l_hLang[ "message.no_message_selected" ] := "No message selected"
   l_hLang[ "message.no_messages_to_copy" ] := "No messages to copy"
   l_hLang[ "message.copied_messages" ] := "Copied"
   l_hLang[ "message.messages" ] := "messages"
   l_hLang[ "message.hint" ] := "Hint"
   l_hLang[ "notation.copy_current" ] := "Copy current line"
   l_hLang[ "notation.copy_all" ] := "Copy all"
   l_hLang[ "notation.no_notation_selected" ] := "No notation selected"
   l_hLang[ "notation.no_notations_to_copy" ] := "No notations to copy"
   l_hLang[ "notation.copied" ] := "Notation copied"
   l_hLang[ "message.language_changed" ] := "Language changed, please restart application to take effect."
   l_hLang[ "message.resign_confirm" ] := "Are you sure you want to resign?"
   l_hLang[ "message.resign_red" ] := "Red resigned! Black wins!"
   l_hLang[ "message.resign_black" ] := "Black resigned! Red wins!"
   l_hLang[ "message.stop_game_confirm" ] := "Are you sure you want to stop the game?"
   l_hLang[ "message.exit_confirm" ] := "Are you sure you want to exit?"
   l_hLang[ "message.about" ] := "Chinese Chess v1.0.0" + hb_eol() + "Build: " + _HBMK_BUILD_DATE_ + " " + _HBMK_BUILD_TIME_ + hb_eol() + hb_eol() + "A full-featured Chinese Chess game with AI support" + hb_eol() + hb_eol() + "Features:" + hb_eol() + "• Play against AI (ElephantEye/Pikafish)" + hb_eol() + "• Save and load games (PGN/FEN)" + hb_eol() + "• Undo moves" + hb_eol() + "• Move hints and coordinates" + hb_eol() + "• Multiple board and piece styles"

   // PGN 相关
   l_hLang[ "pgn.game" ] := "Chinese Chess"
   l_hLang[ "pgn.event" ] := "Man vs AI"

   // 错误消息
   l_hLang[ "error.file_not_found" ] := "File not found"
   l_hLang[ "error.file_empty" ] := "File is empty"
   l_hLang[ "error.unsupported_format" ] := "Unsupported file format"

   // 方面
   l_hLang[ "side.red" ] := "Red"
   l_hLang[ "side.black" ] := "Black"
   l_hLang[ "label.language" ] := "Language"

   // 错误消息
   l_hLang[ "error.ai_stopped" ] := "AI stopped, game in manual mode"
   l_hLang[ "status.ai_stopped" ] := "=== AI Stopped ==="
   l_hLang[ "error.no_undo" ] := "No moves to undo"
   l_hLang[ "error.game_over" ] := "Game over, cannot undo"
   l_hLang[ "error.undo_failed_history" ] := "Undo failed: history corrupted"
   l_hLang[ "error.undo_failed_board" ] := "Undo failed: Board state corrupted"
   l_hLang[ "error.ai_not_configured" ] := "AI not configured! Switching to Human vs Human mode."

   // 玩家模式
   l_hLang[ "player.human" ] := "Human"
   l_hLang[ "player.elephanteye" ] := "ElephantEye"
   l_hLang[ "player.ai" ] := "AI"
   l_hLang[ "player.red" ] := "Red"
   l_hLang[ "player.black" ] := "Black"

   // 设置
   l_hLang[ "settings.difficulty" ] := "Difficulty level"
   l_hLang[ "settings.auto_save" ] := "Auto save"
   l_hLang[ "settings.ai_max_moves" ] := "AI max moves"
   l_hLang[ "settings.ai_think_time" ] := "AI Think Time (ms)"
   l_hLang[ "settings.language" ] := "Language"
   l_hLang[ "settings.skin_style" ] := "Skin Style"
   l_hLang[ "settings.show_move_hints" ] := "Show Move Hints"
   l_hLang[ "settings.show_coordinates" ] := "Show Coordinates"
   l_hLang[ "settings.show_last_move" ] := "Show Last Move"
   l_hLang[ "settings.board_type" ] := "Board Type"
   l_hLang[ "settings.line_board" ] := "Line Board"
   
   // 难度级别
   l_hLang[ "difficulty.novice" ] := "Novice (1)"
   l_hLang[ "difficulty.easy" ] := "Easy (2)"
   l_hLang[ "difficulty.normal" ] := "Normal (3)"
   l_hLang[ "difficulty.hard" ] := "Hard (4)"
   l_hLang[ "difficulty.master" ] := "Master (5)"
   
   // AI 设置
   l_hLang[ "ai.enable_ai1" ] := "Enable AI1"
   l_hLang[ "ai.enable_ai2" ] := "Enable AI2"
   l_hLang[ "ai.engine_type" ] := "Engine Type"
   l_hLang[ "ai.engine_file" ] := "Engine File"
   l_hLang[ "ai.think_time" ] := "Think Time (ms)"
   l_hLang[ "ai.browse" ] := "Browse..."
   l_hLang[ "ai.settings_hint" ] := "Hint: Please click Browse button to select engine executable"
   l_hLang[ "ai.select_engine_title" ] := "Select Engine"
   
   // 文件过滤器
   l_hLang[ "ai.filter_all_files" ] := "All files (*.*)"
   l_hLang[ "ai.filter_executable" ] := "Executable files"
   l_hLang[ "ai.filter_batch_files" ] := "Batch files (*.bat;*.cmd)"
   l_hLang[ "ai.filter_shell_scripts" ] := "Shell scripts (*.sh)"
   
   // 快捷键
   l_hLang[ "hotkey.stop_ai" ] := "Stop AI"
   l_hLang[ "hotkey.new_game" ] := "New Game"
   l_hLang[ "hotkey.save_game" ] := "Save Game"
   l_hLang[ "hotkey.load_game" ] := "Load Game"

// ==================== 文件过滤器 ====================
l_hLang[ "filter.pgn_files" ] := "PGN files (*.pgn)"
l_hLang[ "filter.fen_files" ] := "FEN files (*.fen)"
l_hLang[ "filter.all_files" ] := "All files (*.*)"
   l_hLang[ "hotkey.undo" ] := "Undo"
   l_hLang[ "hotkey.options" ] := "Options"
   l_hLang[ "hotkey.help" ] := "Help"
   
   // 选项卡
   l_hLang[ "tab.hotkeys" ] := "Hotkeys"
   
   // 按钮
   l_hLang[ "button.apply" ] := "Apply"

   // 语言名称
   l_hLang[ "lang.english" ] := "English"
   l_hLang[ "lang.chinese" ] := "中文"

   // 棋盘样式
   l_hLang[ "style.woods" ] := "Woods"
   l_hLang[ "style.eleeye" ] := "Eleeye"

   // 控制台版本
   l_hLang[ "app.console.title" ] := "Chinese Chess v1.0.0 - Build " + _HBMK_BUILD_DATE_ + " " + _HBMK_BUILD_TIME_ + " - Console Mode"
   l_hLang[ "console.move_format" ] := "Move format: from_row from_col to_row to_col"
   l_hLang[ "console.from_row" ] := "  from_row  - Start row (1-10, 1=black baseline, 10=red baseline)"
   l_hLang[ "console.from_col" ] := "  from_col  - Start column (1-9, left to right)"
   l_hLang[ "console.to_row" ] := "  to_row    - Target row"
   l_hLang[ "console.to_col" ] := "  to_col    - Target column"
   l_hLang[ "console.example_moves" ] := "Example moves:"
   l_hLang[ "console.example1" ] := "  10 2 8 3  - Red horse from (10,2) to (8,3)"
   l_hLang[ "console.example2" ] := "  7 1 6 1   - Red pawn from (7,1) moves forward"
   l_hLang[ "console.example3" ] := "  8 2 3 2   - Red cannon from (8,2) moves straight to (3,2)"
   l_hLang[ "console.other_commands" ] := "Other commands:"
   l_hLang[ "console.cmd_help" ] := "  h or help - Show this help"
   l_hLang[ "console.cmd_list" ] := "  l or list  - List all legal moves"
   l_hLang[ "console.cmd_new" ] := "  n or new  - New game"
   l_hLang[ "console.cmd_quit" ] := "  q or quit - Quit game"
   l_hLang[ "console.coord_system" ] := "Coordinate system:"
   l_hLang[ "console.row_desc" ] := "  Row: 1(black baseline) -> 10(red baseline)"
   l_hLang[ "console.col_desc" ] := "  Col: 1(left) -> 9(right)"
   l_hLang[ "console.rules_title" ] := "Chinese Chess Rules:"
   l_hLang[ "console.rule1" ] := "  - Horse moves in '日' pattern, Elephant in '田' pattern, Advisors and Kings stay in palace"
   l_hLang[ "console.rule2" ] := "  - Cannon moves straight, needs platform to capture"
   l_hLang[ "console.rule3" ] := "  - Chariot moves straight, no blocking"
   l_hLang[ "console.rule4" ] := "  - Pawns can move sideways after crossing river"
   l_hLang[ "console.rule5" ] := "  - 50-move rule: Draw if 50 moves without capture or pawn move"
   l_hLang[ "console.rule6" ] := "  - Perpetual check forbidden: 6 consecutive checks"
   l_hLang[ "console.rule7" ] := "  - Threefold repetition is a draw"
   l_hLang[ "console.no_legal_moves" ] := "No legal moves!"
   l_hLang[ "console.legal_moves_header" ] := "Legal moves list (first 20):"
   l_hLang[ "console.more_moves" ] := "... and {0} more moves"
   l_hLang[ "console.total_moves" ] := "Total {0} legal moves"
   l_hLang[ "console.welcome" ] := "Welcome to Chinese Chess!"
   l_hLang[ "console.input_format" ] := "Input format: from_row from_col to_row to_col"
   l_hLang[ "console.input_example" ] := "Example: 10 2 8 3 (Red horse from row 10 col 2 to row 8 col 3)"
   l_hLang[ "console.current_turn" ] := "Current turn:"
   l_hLang[ "console.turn_red" ] := "Red (uppercase)"
   l_hLang[ "console.turn_black" ] := "Black (lowercase)"
   l_hLang[ "console.move_count" ] := "Move count:"
   l_hLang[ "console.legal_move_count" ] := "Legal moves:"
   l_hLang[ "console.no_moves_found" ] := "  (No legal moves found)"
   l_hLang[ "console.prompt" ] := "Command> "
   l_hLang[ "error.coord_out_of_range" ] := "Error: Coordinates out of range (row: 1-10, col: 1-9)"
   l_hLang[ "error.no_piece_at_start" ] := "Error: No piece at start position"
   l_hLang[ "error.not_own_piece" ] := "Error: Not your piece"
   l_hLang[ "console.move_success" ] := "Move successful! {0} ({1},{2}) -> ({3},{4})"
   l_hLang[ "error.invalid_move" ] := "Invalid move! Please check move rules"
   l_hLang[ "error.input_format_wrong" ] := "Error: Input format incorrect"
   l_hLang[ "error.format" ] := "  Format: from_row from_col to_row to_col"
   l_hLang[ "error.example" ] := "  Example: 10 2 8 3"
   l_hLang[ "error.help_hint" ] := "  Or enter 'h' for help"
   l_hLang[ "console.game_over" ] := "Game over"
   l_hLang[ "console.total_moves_summary" ] := "Total moves:"
   l_hLang[ "console.goodbye" ] := "Thank you for playing! Goodbye!"
   l_hLang[ "player.default_name" ] := "Player"

   // 引擎输出
   l_hLang[ "engine.chinese_notation" ] := "=== Chinese Chess Notation ==="
   l_hLang[ "engine.output" ] := "=== Engine Output ==="
   l_hLang[ "engine.status_enabled" ] := "Engine status: Enabled"
   l_hLang[ "engine.status_disabled" ] := "Engine status: Disabled"
   l_hLang[ "engine.current_turn" ] := "Current turn:"
   l_hLang[ "engine.fen_position" ] := "FEN position:"
   l_hLang[ "engine.ucci_coordinate" ] := "UCCI coordinate:"
   l_hLang[ "engine.fen" ] := "FEN:"

RETURN l_hLang

//--------------------------------------------------------------------------------

STATIC FUNCTION xq_LoadChineseTranslations()
   // 加载中文翻译
   LOCAL l_hLang := {=>}

// 应用程序
   l_hLang[ "app.title" ] := "中国象棋"

   // 对话框
   l_hLang[ "dialog.select_players" ] := "选择玩家模式"
   l_hLang[ "dialog.game_options" ] := "游戏选项"

   // 标签页
   l_hLang[ "tab.game_settings" ] := "游戏设置"
   l_hLang[ "tab.ui_settings" ] := "界面设置"
   l_hLang[ "tab.engine_settings" ] := "引擎设置"

   // 标签
   l_hLang[ "label.red" ] := "红方:"
   l_hLang[ "label.black" ] := "黑方:"

   // 选项
   l_hLang[ "option.enable_debug" ] := "启用调试模式"
   l_hLang[ "option.enable_ai" ] := "启用 AI 功能"
   l_hLang[ "option.enable_sound" ] := "启用音效"
   l_hLang[ "option.auto_save" ] := "自动保存游戏"
   l_hLang[ "option.show_hints" ] := "显示走棋提示"
   l_hLang[ "option.show_coords" ] := "显示坐标"
   l_hLang[ "option.show_last_move" ] := "显示上一步"
   l_hLang[ "player.mode.dialog.title" ] := "选择玩家模式"
   l_hLang[ "game.options.dialog.title" ] := "游戏选项"
   l_hLang[ "help.dialog.title" ] := "帮助"

   // 菜单项
      l_hLang[ "menu.file" ] := "文件"
      l_hLang[ "menu.new" ] := "新游戏"
      l_hLang[ "menu.load" ] := "加载棋局"
      l_hLang[ "menu.save" ] := "保存棋局"
      l_hLang[ "menu.exit" ] := "退出"
      l_hLang[ "menu.game" ] := "游戏"
      l_hLang[ "menu.players_settings" ] := "玩家设置"
      l_hLang[ "menu.resign" ] := "认输"
      l_hLang[ "menu.stop_game" ] := "停止游戏"
      l_hLang[ "menu.stop_ai" ] := "停止AI"
      l_hLang[ "menu.options" ] := "选项"
      l_hLang[ "menu.language" ] := "语言"
      l_hLang[ "menu.help" ] := "帮助"
      l_hLang[ "menu.about" ] := "关于"
   // 按钮
   l_hLang[ "button.new_game" ] := "新游戏"
   l_hLang[ "button.game" ] := "游戏"
   l_hLang[ "button.load" ] := "加载"
   l_hLang[ "button.save" ] := "保存"
   l_hLang[ "button.options" ] := "选项"
   l_hLang[ "button.undo" ] := "悔棋"
   l_hLang[ "button.help" ] := "帮助"
   l_hLang[ "button.stop_ai" ] := "停止AI"
   l_hLang[ "button.players_settings" ] := "玩家设置"
   l_hLang[ "button.resign" ] := "认输"
   l_hLang[ "button.stop_game" ] := "停止游戏"
   l_hLang[ "button.ok" ] := "确定"
   l_hLang[ "button.cancel" ] := "取消"
   l_hLang[ "button.apply" ] := "应用"
   l_hLang[ "button.yes" ] := "是"
   l_hLang[ "button.no" ] := "否"

   // 对话框
   l_hLang[ "dialog.load_game_title" ] := "加载棋局"
   l_hLang[ "dialog.save_game_title" ] := "保存棋局"

   // 帮助对话框
   l_hLang[ "button.close" ] := "关闭"

   // 工具提示
   l_hLang[ "tooltip.new_game" ] := "新游戏 (F3)"
   l_hLang[ "tooltip.game" ] := "游戏菜单 (F6)"
   l_hLang[ "tooltip.load" ] := "加载游戏 (F4)"
   l_hLang[ "tooltip.save" ] := "保存游戏"
   l_hLang[ "tooltip.options" ] := "界面选项"
   l_hLang[ "tooltip.undo" ] := "悔棋 (Ctrl+Z)"
   l_hLang[ "tooltip.help" ] := "帮助 (F1)"
   l_hLang[ "tooltip.stop_ai" ] := "停止 AI (F8)"

   // 游戏状态
   l_hLang[ "status.waiting" ] := "等待开局"
   l_hLang[ "status.red_turn" ] := "红方走棋"
   l_hLang[ "status.black_turn" ] := "黑方走棋"
   l_hLang[ "status.check" ] := "将军！"
   l_hLang[ "status.showhelp_open" ] := "ShowHelp: 打开帮助对话框"
   l_hLang[ "status.showhelp_close" ] := "ShowHelp: 关闭帮助对话框"

   // 游戏结果
   l_hLang[ "result.red_wins" ] := "红方胜利！"
   l_hLang[ "result.black_wins" ] := "黑方胜利！"
   l_hLang[ "result.red_resign" ] := "红方认输！黑方胜！"
   l_hLang[ "result.black_resign" ] := "黑方认输！红方胜！"
   l_hLang[ "result.draw_50_moves" ] := "和棋！50回合规则（无吃子无动兵）"
   l_hLang[ "result.draw_50move" ] := "和棋！50回合规则（无吃子无动兵）"
   l_hLang[ "result.red_checkmated" ] := "红方被将死！黑方胜！"
   l_hLang[ "result.black_checkmated" ] := "黑方被将死！红方胜！"
   l_hLang[ "result.red_stalemate" ] := "红方困毙！黑方胜！"
   l_hLang[ "result.red_stalemated" ] := "红方困毙！黑方胜！"
   l_hLang[ "result.black_stalemate" ] := "黑方困毙！红方胜！"
   l_hLang[ "result.black_stalemated" ] := "黑方困毙！红方胜！"
   l_hLang[ "result.red_perpetual_check" ] := "红方长将！黑方胜！"
   l_hLang[ "result.black_perpetual_check" ] := "黑方长将！红方胜！"
   l_hLang[ "result.perpetual_check_red" ] := "红方长将！黑方胜！"
   l_hLang[ "result.perpetual_check_black" ] := "黑方长将！红方胜！"
   l_hLang[ "result.draw_repetition" ] := "和棋！三次重复局面"

   // 消息
   l_hLang[ "message.config_saved" ] := "配置已保存到 cchess.ini"
   l_hLang[ "message.settings_applied" ] := "设置已应用"
   l_hLang[ "message.game_saved" ] := "棋局已保存到:"
   l_hLang[ "message.save_failed" ] := "保存失败!"
   l_hLang[ "message.load_failed" ] := "加载失败!"
   l_hLang[ "message.load_this_game" ] := "是否加载此棋局?"
   l_hLang[ "message.fen_format_error" ] := "FEN格式错误!"
   l_hLang[ "message.game_loaded_from_fen" ] := "棋局已从FEN加载!"

   // 加载游戏对话框
   l_hLang[ "dialog.load_game_select_method" ] := "是否从文件加载棋局?"
   l_hLang[ "dialog.load_game_from_file" ] := "  - 选择[是]从文件加载"
   l_hLang[ "dialog.load_game_manual_fen" ] := "  - 选择[否]手动输入 FEN 字符串"
   l_hLang[ "dialog.load_game_manual_title" ] := "加载棋局 (手动输入 FEN)"
   l_hLang[ "dialog.load_game_fen_prompt" ] := "请输入 FEN 字符串:"
   l_hLang[ "dialog.load_game_title" ] := "加载棋局"
   l_hLang[ "message.current_turn" ] := "当前回合"
   l_hLang[ "message.moves_replayed" ] := "已重新走棋"
   l_hLang[ "message.moves" ] := "步"
   l_hLang[ "message.copied" ] := "已复制"
   l_hLang[ "message.no_message_selected" ] := "没有选中消息"
   l_hLang[ "message.no_messages_to_copy" ] := "没有消息可复制"
   l_hLang[ "message.copied_messages" ] := "已复制"
   l_hLang[ "message.messages" ] := "条消息"
   l_hLang[ "message.hint" ] := "提示"
   l_hLang[ "notation.copy_current" ] := "复制当前行"
   l_hLang[ "notation.copy_all" ] := "复制全部"
   l_hLang[ "notation.no_notation_selected" ] := "没有选中记谱"
   l_hLang[ "notation.no_notations_to_copy" ] := "没有记谱可复制"
   l_hLang[ "notation.copied" ] := "记谱已复制"
   l_hLang[ "message.language_changed" ] := "语言已更改，请重启应用以生效。"

   // PGN 相关
   l_hLang[ "pgn.game" ] := "中国象棋"
   l_hLang[ "pgn.event" ] := "人机对战"

   // 错误消息
   l_hLang[ "error.file_not_found" ] := "文件未找到"
   l_hLang[ "error.file_empty" ] := "文件为空"
   l_hLang[ "error.unsupported_format" ] := "不支持的文件格式"
   l_hLang[ "message.resign_confirm" ] := "确定要认输吗？"
   l_hLang[ "message.resign_red" ] := "红方认输！黑方胜！"
   l_hLang[ "message.resign_black" ] := "黑方认输！红方胜！"
   l_hLang[ "message.stop_game_confirm" ] := "确定要停止游戏吗？"
   l_hLang[ "message.exit_confirm" ] := "确定要退出吗？"
   l_hLang[ "message.about" ] := "中国象棋 v1.0.0" + hb_eol() + "构建: " + _HBMK_BUILD_DATE_ + " " + _HBMK_BUILD_TIME_ + hb_eol() + hb_eol() + "一个功能完善的中国象棋游戏，支持AI对弈" + hb_eol() + hb_eol() + "功能特点：" + hb_eol() + "• 与AI对弈（象眼/Pikafish）" + hb_eol() + "• 保存和加载棋局（PGN/FEN）" + hb_eol() + "• 悔棋功能" + hb_eol() + "• 走棋提示和坐标显示" + hb_eol() + "• 多种棋盘和棋子样式"

   // 方面
   l_hLang[ "side.red" ] := "红方"
   l_hLang[ "side.black" ] := "黑方"
   l_hLang[ "label.language" ] := "语言"

   // 错误消息
   l_hLang[ "error.ai_stopped" ] := "AI 已停止，游戏进入手动模式"
   l_hLang[ "status.ai_stopped" ] := "=== AI 已停止 ==="
   l_hLang[ "error.no_undo" ] := "没有可悔棋的步骤"
   l_hLang[ "error.game_over" ] := "游戏已结束，无法悔棋"
   l_hLang[ "error.undo_failed_history" ] := "悔棋失败：历史记录损坏"
   l_hLang[ "error.undo_failed_board" ] := "悔棋失败：棋盘状态损坏"
   l_hLang[ "error.ai_not_configured" ] := "AI 未配置！将切换为 人对人人 模式。"

   // 玩家模式
   l_hLang[ "player.human" ] := "人"
   l_hLang[ "player.elephanteye" ] := "象眼"
   l_hLang[ "player.ai" ] := "AI"
   l_hLang[ "player.red" ] := "红方"
   l_hLang[ "player.black" ] := "黑方"

   // 设置
   l_hLang[ "settings.difficulty" ] := "难度等级"
   l_hLang[ "settings.auto_save" ] := "自动保存"
   l_hLang[ "settings.ai_max_moves" ] := "AI 最大走棋次数"
   l_hLang[ "settings.ai_think_time" ] := "AI 思考时间 (毫秒)"
   l_hLang[ "settings.language" ] := "语言"
   l_hLang[ "settings.skin_style" ] := "皮肤样式"
   l_hLang[ "settings.board_type" ] := "棋盘类型"
   l_hLang[ "settings.jpg_board" ] := "JPG 棋盘"
   l_hLang[ "settings.line_board" ] := "画线棋盘"
   l_hLang[ "settings.show_move_hints" ] := "显示走棋提示"
   l_hLang[ "settings.show_coordinates" ] := "显示坐标"
   l_hLang[ "settings.show_last_move" ] := "显示上一步"
   
   // 难度级别
   l_hLang[ "difficulty.novice" ] := "新手 (1)"
   l_hLang[ "difficulty.easy" ] := "简单 (2)"
   l_hLang[ "difficulty.normal" ] := "普通 (3)"
   l_hLang[ "difficulty.hard" ] := "困难 (4)"
   l_hLang[ "difficulty.master" ] := "大师 (5)"
   
   // AI 设置
   l_hLang[ "ai.enable_ai1" ] := "启用 AI1"
   l_hLang[ "ai.enable_ai2" ] := "启用 AI2"
   l_hLang[ "ai.engine_type" ] := "引擎类型"
   l_hLang[ "ai.engine_file" ] := "引擎文件"
   l_hLang[ "ai.think_time" ] := "思考时间 (毫秒)"
   l_hLang[ "ai.browse" ] := "浏览..."
   l_hLang[ "ai.settings_hint" ] := "提示：请点击浏览按钮选择引擎可执行文件"
   l_hLang[ "ai.select_engine_title" ] := "选择引擎"
   
   // 文件过滤器
   l_hLang[ "ai.filter_all_files" ] := "所有文件 (*.*)"
   l_hLang[ "ai.filter_executable" ] := "可执行文件"
   l_hLang[ "ai.filter_batch_files" ] := "批处理文件 (*.bat;*.cmd)"
   l_hLang[ "ai.filter_shell_scripts" ] := "Shell 脚本 (*.sh)"
   
   // 快捷键
   l_hLang[ "hotkey.stop_ai" ] := "停止 AI"
   l_hLang[ "hotkey.new_game" ] := "新游戏"
   l_hLang[ "hotkey.save_game" ] := "保存游戏"
   l_hLang[ "hotkey.load_game" ] := "加载游戏"

// ==================== 文件过滤器 ====================
l_hLang[ "filter.pgn_files" ] := "PGN 文件 (*.pgn)"
l_hLang[ "filter.fen_files" ] := "FEN 文件 (*.fen)"
l_hLang[ "filter.all_files" ] := "所有文件 (*.*)"
   l_hLang[ "hotkey.undo" ] := "悔棋"
   l_hLang[ "hotkey.options" ] := "选项"
   l_hLang[ "hotkey.help" ] := "帮助"
   
   // 选项卡
   l_hLang[ "tab.hotkeys" ] := "快捷键"
   
   // 语言名称
   l_hLang[ "lang.english" ] := "English"
   l_hLang[ "lang.chinese" ] := "中文"

   // 棋盘样式
   l_hLang[ "style.woods" ] := "木纹"
   l_hLang[ "style.eleeye" ] := "象眼"

   // 帮助对话框
   l_hLang[ "help.title" ] := "中国象棋 - 帮助 v0.9.9"
   l_hLang[ "help.tab.basic" ] := "基本操作"
   l_hLang[ "help.tab.modes" ] := "游戏模式"
   l_hLang[ "help.tab.menu" ] := "菜单功能"
   l_hLang[ "help.tab.hotkeys" ] := "快捷键"
   l_hLang[ "help.tab.options" ] := "选项设置"
   l_hLang[ "help.tab.engines" ] := "AI 引擎"
   l_hLang[ "help.tab.formats" ] := "文件格式"
   l_hLang[ "help.tab.technical" ] := "技术信息"

   // 帮助内容 - 基本操作
   l_hLang[ "help.basic.title" ] := "基本操作："
   l_hLang[ "help.basic.item1" ] := "- 点击棋子选中，再点击目标位置移动"
   l_hLang[ "help.basic.item2" ] := "- 红方先行，双方轮流走棋"
   l_hLang[ "help.basic.item3" ] := "- 遵循中国象棋规则（马走日、象走田等）"
   l_hLang[ "help.basic.item4" ] := "- 吃子或走兵重置50回合计数"
   l_hLang[ "help.basic.item5" ] := "- 连续6次将军禁止（长将）"
   l_hLang[ "help.basic.item6" ] := "- 三次重复局面判和"

   // 帮助内容 - 游戏模式
   l_hLang[ "help.modes.title" ] := "游戏模式："
   l_hLang[ "help.modes.item1" ] := "- 玩家 vs 玩家 - 双人对战"
   l_hLang[ "help.modes.item2" ] := "- 玩家 vs AI1 - 使用 ElephantEye 引擎"
   l_hLang[ "help.modes.item3" ] := "- 玩家 vs AI2 - 使用 Pikafish 引擎"
   l_hLang[ "help.modes.item4" ] := "- AI vs AI - 双引擎自对弈"

   // 帮助内容 - 菜单功能
   l_hLang[ "help.menu.title" ] := "菜单功能："
   l_hLang[ "help.menu.item1" ] := "- 新游戏 - 开始新对局"
   l_hLang[ "help.menu.item2" ] := "- 玩家 - 选择红方和黑方类型"
   l_hLang[ "help.menu.item3" ] := "- 加载 - 加载 PGN/FEN 格式棋局"
   l_hLang[ "help.menu.item4" ] := "- 保存 - 保存当前棋局为 PGN"
   l_hLang[ "help.menu.item5" ] := "- 悔棋 - 撤销上一步"
   l_hLang[ "help.menu.item6" ] := "- 选项 - 设置游戏参数和引擎"
   l_hLang[ "help.menu.item7" ] := "- 停止 AI - 中断 AI 思考"

   // 帮助内容 - 快捷键
   l_hLang[ "help.hotkeys.title" ] := "快捷键："
   l_hLang[ "help.hotkeys.line1" ] := "F1 - 帮助  F3 - 新游戏  F4 - 加载"
   l_hLang[ "help.hotkeys.line2" ] := "F6 - 玩家  F8 - 选项"
   l_hLang[ "help.hotkeys.line3" ] := "Ctrl+S - 保存  Ctrl+L - 加载"
   l_hLang[ "help.hotkeys.line4" ] := "Ctrl+Z - 悔棋  Ctrl+T - 停止 AI"

   // 帮助内容 - 选项设置
   l_hLang[ "help.options.title" ] := "选项设置："
   l_hLang[ "help.options.item1" ] := "- AI 难度 1-5 级（新手到大师）"
   l_hLang[ "help.options.item2" ] := "- AI 思考时间 1-10 秒"
   l_hLang[ "help.options.item3" ] := "- AI 最大走棋数（0=不限制）"
   l_hLang[ "help.options.item4" ] := "- 棋盘样式：木纹/简约/复古"
   l_hLang[ "help.options.item5" ] := "- 棋子样式：传统/现代/卡通"
   l_hLang[ "help.options.item6" ] := "- 显示移动提示/坐标/上一步"
   l_hLang[ "help.options.item7" ] := "- 音效和自动保存开关"
   l_hLang[ "help.options.item8" ] := "- 语言：中文/英文"

   // 帮助内容 - AI 引擎
   l_hLang[ "help.engines.title" ] := "AI 引擎："
   l_hLang[ "help.engines.item1" ] := "- AI1 - ElephantEye (UCCI 协议)"
   l_hLang[ "help.engines.item2" ] := "- AI2 - Pikafish (UCI 协议)"
   l_hLang[ "help.engines.config" ] := "配置方法："
   l_hLang[ "help.engines.config_desc" ] := "选项 → 引擎设置 → 选择引擎文件"
   l_hLang[ "help.engines.dual" ] := "双引擎对战："
   l_hLang[ "help.engines.dual_desc" ] := "支持 AI1 vs AI2 双引擎对战"

   // 帮助内容 - 文件格式
   l_hLang[ "help.formats.title" ] := "文件格式："
   l_hLang[ "help.formats.pgn" ] := "- PGN - Portable Game Notation"
   l_hLang[ "help.formats.pgn_desc" ] := "  记录整盘棋走法，可保存和加载完整对局"
   l_hLang[ "help.formats.fen" ] := "- FEN - Forsyth-Edwards Notation"
   l_hLang[ "help.formats.fen_desc" ] := "  描述当前棋局状态（位置、回合等）"
   l_hLang[ "help.formats.ini" ] := "- INI - 游戏配置文件"
   l_hLang[ "help.formats.ini_desc" ] := "  存储游戏设置和偏好"

   // 帮助内容 - 技术信息
   l_hLang[ "help.technical.title" ] := "开发环境："
   l_hLang[ "help.technical.lang" ] := "语言: Harbour 3.2.0dev"
   l_hLang[ "help.technical.gui" ] := "GUI: HwGUI (自研轻量框架)"
   l_hLang[ "help.technical.build" ] := "构建: hbmk2 + GCC/Mingw64"
   l_hLang[ "help.technical.protocols" ] := "引擎协议："
   l_hLang[ "help.technical.ucci" ] := "- UCCI - 中国象棋专用协议 (ElephantEye)"
   l_hLang[ "help.technical.uci" ] := "- UCI - 国际象棋协议 (Pikafish 需转换)"
   l_hLang[ "help.technical.notation" ] := "走法表示："
   l_hLang[ "help.technical.iccs" ] := "- ICCS: h2e2 (红方视角，a-h列/1-9行)"
   l_hLang[ "help.technical.chinese" ] := "- 中文: 炮二平五 (传统记谱)"
   l_hLang[ "help.technical.rules" ] := "规则系统："
   l_hLang[ "help.technical.rule50" ] := "- 50回合 - 双方50回合无吃子无动兵判和"
   l_hLang[ "help.technical.rule_perpetual" ] := "- 长将禁止 - 连续6次将军禁止"
   l_hLang[ "help.technical.rule_repetition" ] := "- 三次重复 - 相同局面3次判和"

   // 控制台版本
   l_hLang[ "app.console.title" ] := "中国象棋 v1.0.0 - 构建 " + _HBMK_BUILD_DATE_ + " " + _HBMK_BUILD_TIME_ + " - 控制台模式"
   l_hLang[ "console.move_format" ] := "移动格式: from_row from_col to_row to_col"
   l_hLang[ "console.from_row" ] := "  from_row  - 起始行号 (1-10, 1为黑方底线, 10为红方底线)"
   l_hLang[ "console.from_col" ] := "  from_col  - 起始列号 (1-9, 从左到右)"
   l_hLang[ "console.to_row" ] := "  to_row    - 目标行号"
   l_hLang[ "console.to_col" ] := "  to_col    - 目标列号"
   l_hLang[ "console.example_moves" ] := "示例移动:"
   l_hLang[ "console.example1" ] := "  10 2 8 3  - 红马从(10,2)移到(8,3)"
   l_hLang[ "console.example2" ] := "  7 1 6 1   - 红兵从(7,1)前进一步"
   l_hLang[ "console.example3" ] := "  8 2 3 2   - 红炮从(8,2)直线移动到(3,2)"
   l_hLang[ "console.other_commands" ] := "其他命令:"
   l_hLang[ "console.cmd_help" ] := "  h 或 help - 显示此帮助信息"
   l_hLang[ "console.cmd_list" ] := "  l 或 list  - 列出所有合法走法"
   l_hLang[ "console.cmd_new" ] := "  n 或 new  - 新游戏"
   l_hLang[ "console.cmd_quit" ] := "  q 或 quit - 退出游戏"
   l_hLang[ "console.coord_system" ] := "坐标系统:"
   l_hLang[ "console.row_desc" ] := "  行号: 1(黑方底线) -> 10(红方底线)"
   l_hLang[ "console.col_desc" ] := "  列号: 1(左) -> 9(右)"
   l_hLang[ "console.rules_title" ] := "中国象棋规则:"
   l_hLang[ "console.rule1" ] := "  - 马走日，象走田，士不出宫，将帅不出宫"
   l_hLang[ "console.rule2" ] := "  - 炮走直线，隔子打（炮打隔山）"
   l_hLang[ "console.rule3" ] := "  - 车走直线，无阻挡"
   l_hLang[ "console.rule4" ] := "  - 兵过河后可横走"
   l_hLang[ "console.rule5" ] := "  - 50回合规则：双方50回合无吃子无动兵判和"
   l_hLang[ "console.rule6" ] := "  - 长将禁止：连续6次将军禁止"
   l_hLang[ "console.rule7" ] := "  - 三次重复局面判和"
   l_hLang[ "console.no_legal_moves" ] := "没有合法移动！"
   l_hLang[ "console.legal_moves_header" ] := "合法移动列表 (前20个):"
   l_hLang[ "console.more_moves" ] := "... 还有 {0} 个移动"
   l_hLang[ "console.total_moves" ] := "共 {0} 个合法移动"
   l_hLang[ "console.welcome" ] := "欢迎来到中国象棋游戏！"
   l_hLang[ "console.input_format" ] := "输入格式: from_row from_col to_row to_col"
   l_hLang[ "console.input_example" ] := "示例: 10 2 8 3 (红马从第10行第2列移到第8行第3列)"
   l_hLang[ "console.current_turn" ] := "当前回合:"
   l_hLang[ "console.turn_red" ] := "红方 (大写)"
   l_hLang[ "console.turn_black" ] := "黑方 (小写)"
   l_hLang[ "console.move_count" ] := "移动次数:"
   l_hLang[ "console.legal_move_count" ] := "合法移动数量:"
   l_hLang[ "console.no_moves_found" ] := "  (没有找到合法移动)"
   l_hLang[ "console.prompt" ] := "命令> "
   l_hLang[ "error.coord_out_of_range" ] := "错误: 坐标超出范围 (行: 1-10, 列: 1-9)"
   l_hLang[ "error.no_piece_at_start" ] := "错误: 起始位置没有棋子"
   l_hLang[ "error.not_own_piece" ] := "错误: 不是己方棋子"
   l_hLang[ "console.move_success" ] := "移动成功! {0} ({1},{2}) -> ({3},{4})"
   l_hLang[ "error.invalid_move" ] := "移动不合法! 请检查移动规则"
   l_hLang[ "error.input_format_wrong" ] := "错误: 输入格式不正确"
   l_hLang[ "error.format" ] := "  格式: from_row from_col to_row to_col"
   l_hLang[ "error.example" ] := "  示例: 10 2 8 3"
   l_hLang[ "error.help_hint" ] := "  或输入 'h' 查看帮助"
   l_hLang[ "console.game_over" ] := "游戏结束"
   l_hLang[ "console.total_moves_summary" ] := "总移动次数:"
   l_hLang[ "console.goodbye" ] := "谢谢游戏！再见！"
   l_hLang[ "player.default_name" ] := "玩家"

   // 引擎输出
   l_hLang[ "engine.chinese_notation" ] := "=== 中国象棋记谱法 ==="
   l_hLang[ "engine.output" ] := "=== 引擎输出 ==="
   l_hLang[ "engine.status_enabled" ] := "引擎状态: 已启用"
   l_hLang[ "engine.status_disabled" ] := "引擎状态: 未启用"
   l_hLang[ "engine.current_turn" ] := "当前回合:"
   l_hLang[ "engine.fen_position" ] := "FEN 局面:"
   l_hLang[ "engine.ucci_coordinate" ] := "UCCI坐标:"
   l_hLang[ "engine.fen" ] := "FEN:"

RETURN l_hLang

//--------------------------------------------------------------------------------
