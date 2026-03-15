/*
 * xqengine_engineconfig.prg
 * 中国象棋引擎配置类
 *
 * 功能:
 * - 引擎配置管理
 * - 参数设置和验证
 *
 * 使用示例:
 * LOCAL oConfig := EngineConfig():New()
 * oConfig:SetEnginePath( "./pikafish" )
 * oConfig:SetHashSize( 256 )
 * oConfig:SetThreads( 4 )
 */

#include "hbclass.ch"
#include "xqengine_constants.ch"

#include "hbclass.ch"

// ============================================================================
// EngineConfig 类 - 引擎配置管理
// ============================================================================
/**
 * 中国象棋引擎配置类
 *
 * 功能:
 * - 管理引擎的所有配置参数
 * - 提供参数验证功能
 * - 支持配置克隆
 * - 支持 Pikafish 所有选项
 *
 * 配置分类:
 * 1. 引擎基本信息: 名称、路径、版本、作者
 * 2. 引擎参数: Hash 大小、线程数、开局库、残局库
 * 3. 搜索参数: 默认深度、默认时间、节点数限制
 * 4. 调试选项: 调试模式、详细输出
 * 5. Pikafish 选项: Ponder、MultiPV、NNUE 等
 *
 * 默认值:
 * - Hash 大小: 64 MB
 * - 线程数: 1
 * - 默认深度: 10
 * - 默认时间: 30000 ms (30秒)
 * - MultiPV: 1
 *
 * 使用示例:
 * // 创建配置
 * LOCAL oConfig := EngineConfig():New()
 * oConfig:SetEnginePath( "./pikafish" )
 * oConfig:SetHashSize( 256 )
 * oConfig:SetThreads( 4 )
 * oConfig:SetDefaultDepth( 15 )
 * oConfig:SetDefaultTime( 5000 )
 *
 * // 验证配置
 * IF oConfig:Validate()
 *    ? "配置有效"
 * ENDIF
 *
 * // 克隆配置
 * LOCAL oClone := oConfig:Clone()
 *
 * // 设置到引擎
 * LOCAL oEngine := XQEngine():New()
 * oEngine:SetConfig( oConfig )
 *
 * 注意事项:
 * - 引擎路径必须有效且文件存在
 * - Hash 大小建议: 32-1024 MB
 * - 线程数建议: 1-8
 * - MultiPV 范围: 1-128
 * - 使用 Validate() 方法验证配置
 */
CREATE CLASS EngineConfig

   // 引擎基本信息
   VAR cEngineName     INIT ""
   VAR cEnginePath     INIT ""
   VAR cEngineVersion  INIT ""
   VAR cEngineAuthor   INIT ""

   // 引擎参数
   VAR nHashSize       INIT 64      // Hash 表大小 (MB)
   VAR nThreads        INIT 1       // 线程数
   VAR lUseBook        INIT .T.     // 是否使用开局库
   VAR lUseEGTB        INIT .T.     // 是否使用残局库
   VAR lUseMilliSec    INIT .T.     // 是否使用毫秒计时

   // 搜索参数
   VAR nDefaultDepth   INIT 10      // 默认搜索深度
   VAR nDefaultTime    INIT 30000   // 默认思考时间 (毫秒)
   VAR nMaxNodes       INIT 0       // 最大节点数限制 (0=无限制)

   // 调试配置
   VAR nDebugLevel     INIT XQECI_DEFAULT_DEBUG_LEVEL  // 调试级别（0-5）
   VAR cDebugLogFile   INIT ""                            // 调试日志文件

   // Pikafish 选项
   VAR cNumaPolicy       INIT "auto" // NUMA策略
   VAR lPonder           INIT .F.    // 思考模式
   VAR nMultiPV          INIT 1      // 多PV数量
   VAR nMoveOverhead     INIT 10     // 移动时间开销(ms)
   VAR nNodeTime         INIT 0      // 节点时间
   VAR lShowWDL          INIT .F.    // 显示WDL概率
   VAR cEvalFile         INIT "pikafish.nnue" // NNUE评估文件

   // 方法
   METHOD New()
   METHOD SetEnginePath( cPath )
   METHOD SetEngineName( cName )
   METHOD SetHashSize( nSize )
   METHOD SetThreads( nThreads )
   METHOD SetUseBook( lUse )
   METHOD SetUseEGTB( lUse )
   METHOD SetDefaultDepth( nDepth )
   METHOD SetDefaultTime( nTime )
   METHOD SetDebugLevel( nLevel )
   METHOD SetDebugLogFile( cFile )
   METHOD SetNumaPolicy( cPolicy )
   METHOD SetPonder( lEnable )
   METHOD SetMultiPV( nPV )
   METHOD SetMoveOverhead( nOverhead )
   METHOD SetNodeTime( nTime )
   METHOD SetShowWDL( lShow )
   METHOD SetEvalFile( cFile )
   METHOD Validate()
   METHOD Clone()
   METHOD ToString()

ENDCLASS

// ============================================================================
// 构造函数 - 创建配置对象
// ============================================================================
/**
 * 创建并初始化一个新的 EngineConfig 对象
 *
 * 功能:
 * - 初始化所有配置参数为默认值
 * - 设置合理的默认参数
 *
 * 返回值:
 * - Self (EngineConfig 对象实例)
 *
 * 默认值:
 * - Hash 大小: 64 MB
 * - 线程数: 1
 * - 默认深度: 10
 * - 默认时间: 30000 ms (30秒)
 * - MultiPV: 1
 * - Ponder: .F.
 * - 开局库: .T.
 * - 残局库: .T.
 *
 * 使用示例:
 * LOCAL oConfig := EngineConfig():New()
 * oConfig:SetEnginePath( "./pikafish" )
 */
METHOD New() CLASS EngineConfig

   ::cEngineName     := ""
   ::cEnginePath     := ""
   ::cEngineVersion  := ""
   ::cEngineAuthor   := ""
   ::nHashSize       := 64
   ::nThreads        := 1
   ::lUseBook        := .T.
   ::lUseEGTB        := .T.
   ::lUseMilliSec    := .T.
   ::nDefaultDepth   := 10
   ::nDefaultTime    := 30000
   ::nMaxNodes       := 0

   // 调试配置
   ::nDebugLevel     := XQECI_DEFAULT_DEBUG_LEVEL
   ::cDebugLogFile   := ""

   // Pikafish 选项
   ::cNumaPolicy     := "auto"
   ::lPonder         := .F.
   ::nMultiPV        := 1
   ::nMoveOverhead   := 10
   ::nNodeTime       := 0
   ::lShowWDL        := .F.
   ::cEvalFile       := "pikafish.nnue"

   RETURN Self

// ============================================================================
// Setter 方法 - 设置配置参数
// ============================================================================

METHOD SetEnginePath( cPath ) CLASS EngineConfig
   IF HB_ISSTRING( cPath )
      ::cEnginePath := cPath
   ENDIF
   RETURN Self

METHOD SetEngineName( cName ) CLASS EngineConfig
   IF HB_ISSTRING( cName )
      ::cEngineName := cName
   ENDIF
   RETURN Self

METHOD SetHashSize( nSize ) CLASS EngineConfig
   // Hash 大小范围: 0-65536 MB (0 表示使用引擎默认值)
   IF HB_ISNUMERIC( nSize ) .AND. nSize >= 0 .AND. nSize <= 65536
      ::nHashSize := nSize
   ENDIF
   RETURN Self

METHOD SetThreads( nThreads ) CLASS EngineConfig
   // 线程数范围: 1-512
   IF HB_ISNUMERIC( nThreads ) .AND. nThreads >= 1 .AND. nThreads <= 512
      ::nThreads := nThreads
   ENDIF
   RETURN Self

METHOD SetUseBook( lUse ) CLASS EngineConfig
   IF HB_ISLOGICAL( lUse )
      ::lUseBook := lUse
   ENDIF
   RETURN Self

METHOD SetUseEGTB( lUse ) CLASS EngineConfig
   IF HB_ISLOGICAL( lUse )
      ::lUseEGTB := lUse
   ENDIF
   RETURN Self

METHOD SetDefaultDepth( nDepth ) CLASS EngineConfig
   // 深度范围: 1-99
   IF HB_ISNUMERIC( nDepth ) .AND. nDepth >= 1 .AND. nDepth <= 99
      ::nDefaultDepth := nDepth
   ENDIF
   RETURN Self

METHOD SetDefaultTime( nTime ) CLASS EngineConfig
   // 时间范围: 1-3600000 ms (1小时)
   IF HB_ISNUMERIC( nTime ) .AND. nTime >= 1 .AND. nTime <= 3600000
      ::nDefaultTime := nTime
   ENDIF
   RETURN Self

METHOD SetDebugLevel( nLevel ) CLASS EngineConfig

   /**
    * 设置调试级别
    * 
    * 功能说明:
    * - 设置调试输出的详细程度
    * - 影响所有 XQECI_* 函数的输出
    * 
    * 参数:
    *   nLevel (数值): 调试级别 (0-5)
    *     - 0: 无输出
    *     - 1: 仅错误 (ERROR)
    *     - 2: 警告 + 错误 (WARN)
    *     - 3: 信息 + 警告 + 错误 (INFO)
    *     - 4: 调试 + 信息 + 警告 + 错误 (DEBUG)
    *     - 5: 跟踪 + 调试 + 信息 + 警告 + 错误 (TRACE)
    * 
    * 返回值:
    *   - EngineConfig 对象: 返回自身，支持链式调用
    * 
    * 使用示例:
    *   oConfig:SetDebugLevel( 1 )  // 生产环境
    *   oConfig:SetDebugLevel( 3 )  // 用户反馈问题
    *   oConfig:SetDebugLevel( 4 )  // 开发调试
    */
   IF HB_ISNUMERIC( nLevel ) .AND. nLevel >= 0 .AND. nLevel <= 5
      ::nDebugLevel := Int( nLevel )
   ENDIF

   RETURN Self

METHOD SetDebugLogFile( cFile ) CLASS EngineConfig

   /**
    * 设置调试日志文件
    * 
    * 功能说明:
    * - 设置日志文件路径
    * - 日志会同时输出到控制台和文件
    * - 文件以追加模式打开
    * 
    * 参数:
    *   cFile (字符串): 日志文件路径
    *     - 空字符串: 禁用文件输出
    *     - 非空字符串: 启用文件输出
    * 
    * 返回值:
    *   - EngineConfig 对象: 返回自身，支持链式调用
    * 
    * 使用示例:
    *   oConfig:SetDebugLogFile( "xqengine.log" )
    *   oConfig:SetDebugLogFile( "" )  // 禁用文件输出
    */
   IF HB_ISSTRING( cFile )
      ::cDebugLogFile := cFile
   ENDIF

   RETURN Self

METHOD SetNumaPolicy( cPolicy ) CLASS EngineConfig
   IF HB_ISSTRING( cPolicy )
      ::cNumaPolicy := cPolicy
   ENDIF
   RETURN Self

METHOD SetPonder( lEnable ) CLASS EngineConfig
   IF HB_ISLOGICAL( lEnable )
      ::lPonder := lEnable
   ENDIF
   RETURN Self

METHOD SetMultiPV( nPV ) CLASS EngineConfig
   // MultiPV 范围: 1-256
   IF HB_ISNUMERIC( nPV ) .AND. nPV >= 1 .AND. nPV <= 256
      ::nMultiPV := nPV
   ENDIF
   RETURN Self

METHOD SetMoveOverhead( nOverhead ) CLASS EngineConfig
   // 移动时间开销范围: 0-10000 ms
   IF HB_ISNUMERIC( nOverhead ) .AND. nOverhead >= 0 .AND. nOverhead <= 10000
      ::nMoveOverhead := nOverhead
   ENDIF
   RETURN Self

METHOD SetNodeTime( nTime ) CLASS EngineConfig
   IF HB_ISNUMERIC( nTime ) .AND. nTime >= 0
      ::nNodeTime := nTime
   ENDIF
   RETURN Self

METHOD SetShowWDL( lShow ) CLASS EngineConfig
   IF HB_ISLOGICAL( lShow )
      ::lShowWDL := lShow
   ENDIF
   RETURN Self

METHOD SetEvalFile( cFile ) CLASS EngineConfig
   IF HB_ISSTRING( cFile )
      ::cEvalFile := cFile
   ENDIF
   RETURN Self

// ============================================================================
// 验证配置 - 检查参数有效性
// ============================================================================
/**
 * 验证配置参数是否有效
 *
 * 功能:
 * - 检查引擎路径是否设置
 * - 检查引擎文件是否存在
 * - 检查参数范围是否有效
 * - 输出详细的错误信息
 *
 * 返回值:
 * - .T. (逻辑值): 配置有效
 * - .F. (逻辑值): 配置无效
 *
 * 验证规则:
 * - 引擎路径不能为空
 * - 引擎文件必须存在
 * - Hash 大小 >= 0
 * - 线程数 >= 1
 * - 默认深度 >= 1
 * - 默认时间 >= 1
 *
 * 使用示例:
 * IF oConfig:Validate()
 *    ? "配置有效"
 * ELSE
 *    ? "配置无效，请检查参数"
 * ENDIF
 */
METHOD Validate() CLASS EngineConfig

   LOCAL lValid := .T.

   IF Empty( ::cEnginePath )
      XQECI_Error( XQECI_MODULE_CONFIG, "Engine path not set" )
      lValid := .F.
   ENDIF

   IF ! File( ::cEnginePath )
      XQECI_ErrorF( XQECI_MODULE_CONFIG, "Engine file not found: %1", ::cEnginePath )
      lValid := .F.
   ENDIF

   IF ::nHashSize < 0
      XQECI_Error( XQECI_MODULE_CONFIG, "Hash size must be >= 0" )
      lValid := .F.
   ENDIF

   IF ::nThreads < 1
      XQECI_Error( XQECI_MODULE_CONFIG, "Thread count must be >= 1" )
      lValid := .F.
   ENDIF

   IF ::nDefaultDepth < 1
      XQECI_Error( XQECI_MODULE_CONFIG, "Default depth must be >= 1" )
      lValid := .F.
   ENDIF

   IF ::nDefaultTime < 1
      XQECI_Error( XQECI_MODULE_CONFIG, "Default time must be >= 1" )
      lValid := .F.
   ENDIF

   RETURN lValid

// ============================================================================
// 克隆配置 - 创建配置副本
// ============================================================================
/**
 * 创建当前配置的深拷贝
 *
 * 功能:
 * - 创建一个新的配置对象
 * - 复制所有参数到新对象
 * - 新对象与原对象独立
 *
 * 返回值:
 * - EngineConfig 对象: 配置的副本
 *
 * 使用场景:
 * - 创建多个引擎实例时共享配置
 * - 修改配置前备份
 * - 测试不同配置组合
 *
 * 使用示例:
 * LOCAL oConfig1 := EngineConfig():New()
 * oConfig1:SetEnginePath( "./pikafish" )
 * oConfig1:SetHashSize( 256 )
 *
 * // 克隆配置
 * LOCAL oConfig2 := oConfig1:Clone()
 *
 * // 修改副本不影响原配置
 * oConfig2:SetHashSize( 512 )
 * ? oConfig1:nHashSize  // 256
 * ? oConfig2:nHashSize  // 512
 */
METHOD Clone() CLASS EngineConfig

   LOCAL oClone := EngineConfig():New()

   oClone:cEngineName    := ::cEngineName
   oClone:cEnginePath    := ::cEnginePath
   oClone:cEngineVersion := ::cEngineVersion
   oClone:cEngineAuthor  := ::cEngineAuthor
   oClone:nHashSize      := ::nHashSize
   oClone:nThreads       := ::nThreads
   oClone:lUseBook       := ::lUseBook
   oClone:lUseEGTB       := ::lUseEGTB
   oClone:lUseMilliSec   := ::lUseMilliSec
   oClone:nDefaultDepth  := ::nDefaultDepth
   oClone:nDefaultTime   := ::nDefaultTime
   oClone:nMaxNodes      := ::nMaxNodes
   oClone:nDebugLevel    := ::nDebugLevel
   oClone:cDebugLogFile  := ::cDebugLogFile

   // Pikafish 选项
   oClone:cNumaPolicy    := ::cNumaPolicy
   oClone:lPonder        := ::lPonder
   oClone:nMultiPV       := ::nMultiPV
   oClone:nMoveOverhead  := ::nMoveOverhead
   oClone:nNodeTime      := ::nNodeTime
   oClone:lShowWDL       := ::lShowWDL
   oClone:cEvalFile      := ::cEvalFile

   RETURN oClone

// ============================================================================
// 转换为字符串
// ============================================================================

METHOD ToString() CLASS EngineConfig

   LOCAL cResult := ""

   cResult += "引擎配置:"
   cResult += "  名称: " + ::cEngineName + hb_eol()
   cResult += "  路径: " + ::cEnginePath + hb_eol()
   cResult += "  Hash: " + hb_ntos( ::nHashSize ) + "MB" + hb_eol()
   cResult += "  线程: " + hb_ntos( ::nThreads ) + hb_eol()
   cResult += "  开局库: " + Iif( ::lUseBook, "启用", "禁用" ) + hb_eol()
   cResult += "  残局库: " + Iif( ::lUseEGTB, "启用", "禁用" ) + hb_eol()
   cResult += "  默认深度: " + hb_ntos( ::nDefaultDepth ) + hb_eol()
   cResult += "  默认时间: " + hb_ntos( ::nDefaultTime ) + "ms" + hb_eol()

   RETURN cResult

// ============================================================================
// 测试代码
// ============================================================================

PROCEDURE Test_EngineConfig()

   LOCAL oConfig

   ? "=== EngineConfig 类测试 ==="
   ? ""

   // 创建配置
   oConfig := EngineConfig():New()
   oConfig:SetEnginePath( "./pikafish" )
   oConfig:SetHashSize( 256 )
   oConfig:SetThreads( 4 )
   oConfig:SetDefaultDepth( 15 )
   oConfig:SetDefaultTime( 5000 )

   // 打印配置
   ? oConfig:ToString()

   // 验证配置
   IF oConfig:Validate()
      ? "配置验证通过!"
   ELSE
      ? "配置验证失败!"
   ENDIF

   RETURN