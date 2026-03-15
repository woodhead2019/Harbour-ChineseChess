/*
 * 中国象棋配置文件管理模块
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 使用 Harbour 内置的 hb_ini* 函数
 */

#include "xq_xiangqi.ch"

// 配置文件路径
STATIC s_cConfigFile := "cchess.ini"

// 配置缓存
STATIC s_hConfigCache := NIL

// 获取配置文件完整路径
//--------------------------------------------------------------------------------

static function GetConfigPath()
   return hb_DirBase() + s_cConfigFile

// 初始化配置管理器
//
// 参数: 无
// 返回: NIL
//--------------------------------------------------------------------------------

function xq_ConfigInit()

   local l_hIni, l_cHeader, l_cFooter

   // 如果配置文件不存在，创建默认配置
   if !File( GetConfigPath() )
      l_hIni := hb_iniNew( .F. )  // 不自动创建 MAIN 节

      // 主节全局配置
      l_hIni[ "MAIN" ] := { => }
      l_hIni[ "MAIN" ][ "RedPlayerType" ] := "1"      // 1=人, 2=象眼, 3=AI1, 4=AI2
      l_hIni[ "MAIN" ][ "BlackPlayerType" ] := "2"    // 1=人, 2=象眼, 3=AI1, 4=AI2
      l_hIni[ "MAIN" ][ "DebugMode" ] := "0"          // 调试模式: 0=关, 1=开

      // 游戏设置节
      l_hIni[ "GameSettings" ] := { => }
      l_hIni[ "GameSettings" ][ "BoardStyle" ] := "embedded"     // 棋盘样式: embedded/woods/eleeye/classic/traditional
         l_hIni[ "GameSettings" ][ "PieceStyle" ] := "embedded"   // 棋子样式: embedded/woods/eleeye/classic/traditional      l_hIni[ "GameSettings" ][ "SoundEnabled" ] := "1"        // 音效开关
      l_hIni[ "GameSettings" ][ "DifficultyLevel" ] := "3"      // 难度等级: 1-5
      l_hIni[ "GameSettings" ][ "AutoSave" ] := "1"            // 自动保存
      l_hIni[ "GameSettings" ][ "AIMaxMoves" ] := "0"          // AI 最大走棋次数（0=不限制）
      l_hIni[ "GameSettings" ][ "AIEnabled" ] := "1"           // AI 是否启用

      // 界面设置节
      l_hIni[ "UISettings" ] := { => }
      l_hIni[ "UISettings" ][ "ShowMoveHints" ] := "1"       // 显示移动提示
      l_hIni[ "UISettings" ][ "ShowCoordinates" ] := "0"     // 显示坐标
      l_hIni[ "UISettings" ][ "ShowLastMove" ] := "1"        // 显示最后一步
      l_hIni[ "UISettings" ][ "Language" ] := "en"           // 语言: en/zh (默认英文)

      // 玩家配置节
      l_hIni[ "PlayerProfile" ] := { => }
      l_hIni[ "PlayerProfile" ][ "PlayerName" ] := _XQ_I__( "player.default_name" )
      l_hIni[ "PlayerProfile" ][ "WinCount" ] := "0"
      l_hIni[ "PlayerProfile" ][ "LoseCount" ] := "0"
      l_hIni[ "PlayerProfile" ][ "DrawCount" ] := "0"
      l_hIni[ "PlayerProfile" ][ "LastPlayed" ] := DToC( Date() )

      // 引擎设置节
      l_hIni[ "EngineSettings" ] := { => }
      l_hIni[ "EngineSettings" ][ "EnginePath" ] := ""
      l_hIni[ "EngineSettings" ][ "EngineType" ] := "eleeye"     // 引擎类型: eleeye/pikafish
      l_hIni[ "EngineSettings" ][ "ThinkTime" ] := "2000"        // 思考时间(ms)

      // AI1设置节
      l_hIni[ "AI1Settings" ] := { => }
      l_hIni[ "AI1Settings" ][ "Enabled" ] := "1"               // AI1启用
      l_hIni[ "AI1Settings" ][ "EngineType" ] := "UCCI"         // AI1引擎类型: UCCI/UCI
      l_hIni[ "AI1Settings" ][ "EnginePath" ] := ""             // AI1引擎路径
      l_hIni[ "AI1Settings" ][ "ThinkTime" ] := "5000"          // AI1思考时间(ms)

      // AI2设置节
      l_hIni[ "AI2Settings" ] := { => }
      l_hIni[ "AI2Settings" ][ "Enabled" ] := "0"               // AI2启用
      l_hIni[ "AI2Settings" ][ "EngineType" ] := "UCI"          // AI2引擎类型: UCCI/UCI
      l_hIni[ "AI2Settings" ][ "EnginePath" ] := ""             // AI2引擎路径
      l_hIni[ "AI2Settings" ][ "ThinkTime" ] := "3000"          // AI2思考时间(ms)

      // 快捷键节
      l_hIni[ "Hotkeys" ] := { => }
      l_hIni[ "Hotkeys" ][ "StopAI" ] := "Ctrl+T"            // 停止 AI
      l_hIni[ "Hotkeys" ][ "NewGame" ] := "Ctrl+N"
      l_hIni[ "Hotkeys" ][ "SaveGame" ] := "Ctrl+S"
      l_hIni[ "Hotkeys" ][ "LoadGame" ] := "Ctrl+L"
      l_hIni[ "Hotkeys" ][ "UndoMove" ] := "Ctrl+Z"
      l_hIni[ "Hotkeys" ][ "Options" ] := "Ctrl+O"
      l_hIni[ "Hotkeys" ][ "Help" ] := "F1"

      // 文件头注释
      l_cHeader := "; 中国象棋游戏配置文件" + hb_eol() + ;
         "; 生成时间: " + DToC( Date() ) + " " + Time() + hb_eol() + ;
         "; 版本: 1.0" + hb_eol() + hb_eol()

      // 文件尾注释
      l_cFooter := hb_eol() + "; 配置文件结束"

      // 保存配置
      hb_iniWrite( GetConfigPath(), l_hIni, l_cHeader, l_cFooter, .F. )
   endif

   // 加载配置到缓存
   xq_ConfigReload()

   return nil

// 重新加载配置文件
//
// 参数: 无
// 返回: .T. 成功, .F. 失败
//--------------------------------------------------------------------------------

function xq_ConfigReload()

   local l_cPath

   l_cPath := GetConfigPath()

   if !File( l_cPath )
      return .F.
   endif

   s_hConfigCache := hb_iniRead( l_cPath, .T., "=" )

   // 确保缓存是哈希表
   if !HB_ISHASH( s_hConfigCache )
      s_hConfigCache := { => }
   endif

   return ( s_hConfigCache != NIL )

// 获取配置值
//
// 参数:
//   par_cSection - 节名
//   par_cKey - 键名
//   par_cDefault - 默认值
// 返回: 配置值
//--------------------------------------------------------------------------------

function xq_ConfigGet( par_cSection, par_cKey, par_cDefault )

   local l_cValue := par_cDefault
   local l_hSection

   if s_hConfigCache != NIL .AND. HB_ISHASH( s_hConfigCache )
      // 检查节是否存在
      if hb_HHasKey( s_hConfigCache, par_cSection )
         l_hSection := s_hConfigCache[ par_cSection ]
         if l_hSection != NIL .AND. HB_ISHASH( l_hSection ) .AND. hb_HHasKey( l_hSection, par_cKey )
            l_cValue := l_hSection[ par_cKey ]
         endif
      endif
   endif

   return l_cValue

// 设置配置值
//
// 参数:
//   par_cSection - 节名
//   par_cKey - 键名
//   par_cValue - 值
// 返回: .T. 成功, .F. 失败
//--------------------------------------------------------------------------------

function xq_ConfigSet( par_cSection, par_cKey, par_cValue )

   if s_hConfigCache == NIL
      s_hConfigCache := hb_iniNew()
   endif

   if s_hConfigCache[ par_cSection ] == NIL
      s_hConfigCache[ par_cSection ] := { => }
   endif

   s_hConfigCache[ par_cSection ][ par_cKey ] := par_cValue

   return .T.

// 保存配置到文件
//
// 参数: 无
// 返回: .T. 成功, .F. 失败
//--------------------------------------------------------------------------------

function xq_ConfigSave()

   if s_hConfigCache == NIL
      return .F.
   endif

   return hb_iniWrite( GetConfigPath(), s_hConfigCache, ;
      "; 中国象棋游戏配置文件" + hb_eol() + ;
      "; 最后修改: " + DToC( Date() ) + " " + Time() + hb_eol() )

// 获取游戏设置
//
// 参数: 无
// 返回: 哈希表包含游戏设置
//--------------------------------------------------------------------------------

function xq_ConfigGetGameSettings()

   local l_hSettings := { => }

   // 从主节获取全局设置
   l_hSettings[ "RedPlayerType" ] := Val( xq_ConfigGet( "MAIN", "RedPlayerType", "1" ) )
   l_hSettings[ "BlackPlayerType" ] := Val( xq_ConfigGet( "MAIN", "BlackPlayerType", "1" ) )
   l_hSettings[ "DebugMode" ] := ( xq_ConfigGet( "MAIN", "DebugMode", "1" ) == "1" )

   // 从 GameSettings 节获取游戏设置
   l_hSettings[ "BoardStyle" ] := xq_ConfigGet( "GameSettings", "BoardStyle", "embedded" )
   l_hSettings[ "PieceStyle" ] := xq_ConfigGet( "GameSettings", "PieceStyle", "embedded" )
   l_hSettings[ "SoundEnabled" ] := ( xq_ConfigGet( "GameSettings", "SoundEnabled", "1" ) == "1" )
   l_hSettings[ "DifficultyLevel" ] := Val( xq_ConfigGet( "GameSettings", "DifficultyLevel", "3" ) )
   l_hSettings[ "AutoSave" ] := ( xq_ConfigGet( "GameSettings", "AutoSave", "1" ) == "1" )
   l_hSettings[ "AIMaxMoves" ] := Val( xq_ConfigGet( "GameSettings", "AIMaxMoves", "80" ) )
   l_hSettings[ "AIEnabled" ] := ( xq_ConfigGet( "GameSettings", "AIEnabled", "1" ) == "1" )

   return l_hSettings

// 获取界面设置
//
// 参数: 无
// 返回: 哈希表包含界面设置
//--------------------------------------------------------------------------------

function xq_ConfigGetUISettings()

   local l_hSettings := { => }

   l_hSettings[ "ShowMoveHints" ] := ( xq_ConfigGet( "UISettings", "ShowMoveHints", "1" ) == "1" )
   l_hSettings[ "ShowCoordinates" ] := ( xq_ConfigGet( "UISettings", "ShowCoordinates", "0" ) == "1" )
   l_hSettings[ "ShowLastMove" ] := ( xq_ConfigGet( "UISettings", "ShowLastMove", "1" ) == "1" )
   l_hSettings[ "Language" ] := xq_ConfigGet( "UISettings", "Language", "en" )  // 语言设置

   return l_hSettings

// 获取引擎设置
//
// 参数: 无
// 返回: 哈希表包含引擎设置
//--------------------------------------------------------------------------------

function xq_ConfigGetEngineSettings()

   local l_hSettings := { => }

   l_hSettings[ "EnginePath" ] := xq_ConfigGet( "EngineSettings", "EnginePath", "" )
   l_hSettings[ "EngineType" ] := xq_ConfigGet( "EngineSettings", "EngineType", "eleeye" )
   l_hSettings[ "ThinkTime" ] := Val( xq_ConfigGet( "EngineSettings", "ThinkTime", "2000" ) )

   return l_hSettings

// 获取快捷键设置
//
// 参数: 无
// 返回: 哈希表包含快捷键设置
//--------------------------------------------------------------------------------

function xq_ConfigGetHotkeys()

   local l_hSettings := { => }

   l_hSettings[ "StopAI" ] := xq_ConfigGet( "Hotkeys", "StopAI", "Ctrl+T" )
   l_hSettings[ "NewGame" ] := xq_ConfigGet( "Hotkeys", "NewGame", "Ctrl+N" )
   l_hSettings[ "SaveGame" ] := xq_ConfigGet( "Hotkeys", "SaveGame", "Ctrl+S" )
   l_hSettings[ "LoadGame" ] := xq_ConfigGet( "Hotkeys", "LoadGame", "Ctrl+L" )
   l_hSettings[ "UndoMove" ] := xq_ConfigGet( "Hotkeys", "UndoMove", "Ctrl+Z" )
   l_hSettings[ "Options" ] := xq_ConfigGet( "Hotkeys", "Options", "Ctrl+O" )
   l_hSettings[ "Help" ] := xq_ConfigGet( "Hotkeys", "Help", "F1" )

   return l_hSettings

// 获取AI1设置
//
// 参数: 无
// 返回: 哈希表包含AI1设置
//--------------------------------------------------------------------------------

function xq_ConfigGetAI1Settings()

   local l_hSettings := { => }

   l_hSettings[ "Enabled" ] := ( xq_ConfigGet( "AI1Settings", "Enabled", "1" ) == "1" )
   l_hSettings[ "EngineType" ] := xq_ConfigGet( "AI1Settings", "EngineType", "UCCI" )
   l_hSettings[ "EnginePath" ] := xq_ConfigGet( "AI1Settings", "EnginePath", "" )
   l_hSettings[ "ThinkTime" ] := Val( xq_ConfigGet( "AI1Settings", "ThinkTime", "5000" ) )

   return l_hSettings

// 获取AI2设置
//
// 参数: 无
// 返回: 哈希表包含AI2设置
//--------------------------------------------------------------------------------

function xq_ConfigGetAI2Settings()

   local l_hSettings := { => }

   l_hSettings[ "Enabled" ] := ( xq_ConfigGet( "AI2Settings", "Enabled", "0" ) == "1" )
   l_hSettings[ "EngineType" ] := xq_ConfigGet( "AI2Settings", "EngineType", "UCI" )
   l_hSettings[ "EnginePath" ] := xq_ConfigGet( "AI2Settings", "EnginePath", "" )
   l_hSettings[ "ThinkTime" ] := Val( xq_ConfigGet( "AI2Settings", "ThinkTime", "3000" ) )

   return l_hSettings

//--------------------------------------------------------------------------------
