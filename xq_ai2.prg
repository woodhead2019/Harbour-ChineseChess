/*
 * 中国象棋 AI2 引擎接口
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * 功能:
 * - 为 AI2 提供 UCI 协议引擎接口
 * - 使用 xqengine 库进行引擎管理
 * - 与现有的 xq_UCCI 接口保持一致的接口
 *
 * 依赖:
 * - xqengine.prg 库（不修改原代码）
 *
 * 使用方法:
 * 在 xq.hbp 中添加 xqengine 源文件和本文件
 * 在 xq_xiangqi.prg 中将 AI2 引擎改为使用本文件
 */

#include "hbclass.ch"

// ============================================================================
// 全局变量
// ============================================================================

STATIC oAI2Engine := NIL  // AI2 引擎实例（XQEngine 对象）
STATIC s_cAI2EngineName := ""  // AI2 引擎文件名

// ============================================================================
// 工具函数
// -------------------------------------------------------------------------------

/**
 * 日志记录函数（使用统一日志系统）
 * @param cMessage 日志消息
 */
static PROCEDURE xq_AI2_Log( cMessage )
   IF Empty( s_cAI2EngineName )
      xq_Log_Info( "AI2", cMessage )
   ELSE
      xq_Log_Info( "AI2-" + s_cAI2EngineName, cMessage )
   ENDIF
RETURN

// ============================================================================
// AI2 引擎接口
// -------------------------------------------------------------------------------

/**
 * 初始化 AI2 引擎
 * @param par_hConfig 全局配置哈希表引用
 * @return .T. 初始化成功，.F. 初始化失败
 */
function xq_AI2_Init( par_hConfig )

   LOCAL lOk
   LOCAL cEnginePath
   LOCAL oConfig
   LOCAL cCmd

   // 参数验证
   IF par_hConfig == NIL .OR. !HB_ISHASH( par_hConfig )
      xq_AI2_Log( "ERROR: AI2 init failed: invalid config parameters" )
      RETURN .F.
   ENDIF

   // 如果已经初始化，直接返回
   IF par_hConfig["AI2Initialized"]
      RETURN .T.
   ENDIF

   // 获取引擎路径
   cEnginePath := par_hConfig["AI2EnginePath"]

   IF Empty( cEnginePath )
      xq_AI2_Log( "ERROR: AI2 engine path is empty" )
      RETURN .F.
   ENDIF

   // 保存引擎文件名
   s_cAI2EngineName := hb_FNameName( cEnginePath )

   xq_AI2_Log( "Initializing AI2 engine: " + cEnginePath )

   // 创建引擎实例
   oAI2Engine := XQEngine():New()

   // 初始化引擎
   oAI2Engine:Initialize( cEnginePath )

   // 启动引擎
   IF !oAI2Engine:Start()
      xq_AI2_Log( "ERROR: AI2 failed to start engine" )
      xq_AI2_Log( "ERROR: " + oAI2Engine:GetLastError() )
      oAI2Engine := NIL
      RETURN .F.
   ENDIF

   // 等待引擎完全初始化
   hb_idleSleep( 2.0 )

   // 检查引擎是否运行
   IF !oAI2Engine:IsRunning()
      xq_AI2_Log( "ERROR: AI2 engine is not running" )
      oAI2Engine:Close()
      oAI2Engine := NIL
      RETURN .F.
   ENDIF

   // 应用配置
   oConfig := EngineConfig():New()
   oConfig:SetHashSize( 256 )
   oConfig:SetThreads( 2 )
   oAI2Engine:ApplyConfig()

   // 等待配置应用
   hb_idleSleep( 0.5 )

   // 关键修复：发送一个初始 position 命令来"唤醒"引擎，确保引擎状态正确
   cCmd := "position startpos"
   oAI2Engine:SendCommandQuiet( cCmd )
   hb_idleSleep( 0.2 )

   // 发送 isready 确保引擎就绪
   cCmd := "isready"
   oAI2Engine:SendCommandQuiet( cCmd )
   hb_idleSleep( 0.2 )

   // 标记为已初始化
   par_hConfig["AI2Initialized"] := .T.

   xq_AI2_Log( "AI2 engine initialized successfully" )

RETURN .T.

//--------------------------------------------------------------------------------

/**
 * 获取 AI2 引擎的最佳走法
 * @param par_hConfig 全局配置哈希表引用
 * @param aPos 局面位置数组（未使用，仅保持接口兼容）
 * @param nDepth 搜索深度（未使用，仅保持接口兼容）
 * @param cFEN FEN 格式的局面
 * @return 移动编码（整数），0 表示无合法走法
 */
function xq_AI2_GetBestMove( par_hConfig, aPos, nDepth, cFEN )

   LOCAL cFenToUse
   LOCAL cBestMove
   LOCAL nMove
   LOCAL nThinkTime

   // 参数验证
   IF par_hConfig == NIL .OR. !HB_ISHASH( par_hConfig )
      xq_AI2_Log( "ERROR: AI2 get best move failed: invalid config parameters" )
      RETURN 0
   ENDIF

   // 检查是否已初始化
   IF !par_hConfig["AI2Initialized"]
      xq_AI2_Log( "ERROR: AI2 engine not initialized" )
      RETURN 0
   ENDIF

   // 检查引擎实例
   IF oAI2Engine == NIL
      xq_AI2_Log( "ERROR: AI2 engine instance is NIL" )
      RETURN 0
   ENDIF

   // 检查引擎是否运行
   IF !oAI2Engine:IsRunning()
      xq_AI2_Log( "ERROR: AI2 engine is not running" )
      RETURN 0
   ENDIF

   // 确定 FEN
   IF Empty( cFEN )
      cFenToUse := "startpos"
   ELSE
      cFenToUse := cFEN
   ENDIF

   // 获取思考时间
   nThinkTime := par_hConfig["AI2ThinkTime"]
   IF nThinkTime == NIL .OR. nThinkTime <= 0
      nThinkTime := 3000  // 默认 3 秒
   ENDIF

   xq_AI2_Log( "Analyzing position: " + cFenToUse )
   xq_AI2_Log( "Think time: " + LTrim(Str(nThinkTime)) + "ms" )

   // 使用 xqengine 的 Analyze 方法
   cBestMove := oAI2Engine:Analyze( cFenToUse, nThinkTime, 0 )

   IF Empty( cBestMove )
      xq_AI2_Log( "No best move received" )
   ENDIF

   xq_AI2_Log( "Best move: " + cBestMove )

   // 将 UCCI/UCI 坐标转换为移动编码
   nMove := xq_UCCICoordToMovePublic( cBestMove )

   IF nMove == 0
      xq_AI2_Log( "WARNING: Failed to convert move to internal format: " + cBestMove )
   ENDIF

RETURN nMove

//--------------------------------------------------------------------------------

/**
 * 关闭 AI2 引擎
 * @param par_hConfig 全局配置哈希表引用（可选，默认使用 GetGlobalConfig()）
 */
function xq_AI2_Close( par_hConfig )

   // 如果没有提供par_hConfig，使用GetGlobalConfig()
   IF par_hConfig == NIL
      par_hConfig := GetGlobalConfig()
   ENDIF

   xq_AI2_Log( "Closing AI2 engine" )

   // 关闭引擎
   IF oAI2Engine != NIL
      IF oAI2Engine:IsRunning()
         oAI2Engine:Close()
      ENDIF
      oAI2Engine := NIL
   ENDIF

   // 标记为未初始化
   IF par_hConfig != NIL .AND. HB_ISHASH( par_hConfig )
      par_hConfig["AI2Initialized"] := .F.
   ENDIF

   xq_AI2_Log( "AI2 engine closed" )

RETURN NIL

//--------------------------------------------------------------------------------

/**
 * 检查 AI2 引擎是否已初始化
 * @return .T. 已初始化，.F. 未初始化
 */
function xq_AI2_IsInitialized()

RETURN ( oAI2Engine != NIL .AND. oAI2Engine:IsRunning() )

//--------------------------------------------------------------------------------

/**
 * 检查 AI2 引擎是否正在思考
 * @return .T. 正在思考，.F. 未思考
 */
function xq_AI2_IsThinking()

RETURN ( oAI2Engine != NIL .AND. oAI2Engine:IsThinking() )

//--------------------------------------------------------------------------------

/**
 * 停止 AI2 引擎的思考
 * @return .T. 成功停止，.F. 停止失败
 */
function xq_AI2_Stop()

   IF oAI2Engine == NIL
      RETURN .F.
   ENDIF

RETURN oAI2Engine:Stop()

//--------------------------------------------------------------------------------

/**
 * 获取 AI2 引擎的统计信息
 * @return 哈希表，包含统计信息
 */
function xq_AI2_GetStatistics()

   IF oAI2Engine == NIL
      RETURN {=>}
   ENDIF

RETURN oAI2Engine:GetStatistics()

//--------------------------------------------------------------------------------

/**
 * 获取 AI2 引擎的引擎信息
 * @return 哈希表，包含引擎信息
 */
function xq_AI2_GetEngineInfo()

   IF oAI2Engine == NIL
      RETURN {=>}
   ENDIF

RETURN oAI2Engine:GetEngineInfo()

//--------------------------------------------------------------------------------

/**
 * 设置 AI2 引擎的选项
 * @param cName 选项名称
 * @param cValue 选项值
 * @return .T. 成功，.F. 失败
 */
function xq_AI2_SetOption( cName, cValue )

   IF oAI2Engine == NIL
      RETURN .F.
   ENDIF

RETURN oAI2Engine:SetOption( cName, cValue )

//--------------------------------------------------------------------------------

/**
 * 清除 AI2 引擎的哈希表
 * @return .T. 成功，.F. 失败
 */
function xq_AI2_ClearHash()

   IF oAI2Engine == NIL
      RETURN .F.
   ENDIF

RETURN oAI2Engine:ClearHash()

//--------------------------------------------------------------------------------

/**
 * 开始新游戏
 * @return .T. 成功，.F. 失败
 */
function xq_AI2_NewGame()

   IF oAI2Engine == NIL
      RETURN .F.
   ENDIF

RETURN oAI2Engine:NewGame()