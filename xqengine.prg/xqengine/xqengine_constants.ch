/*
 * xqengine_constants.ch
 * 中国象棋引擎常量定义
 *
 * 功能:
 * - 定义所有引擎相关常量
 * - 提供跨文件共享
 * - 支持多种协议（UCCI/UCI）
 *
 * 使用方式:
 * #include "xqengine_constants.ch"
 */

// ============================================================================
// 引擎状态常量
// ============================================================================
/**
 * 引擎运行状态常量
 *
 * 状态转换流程:
 * STOPPED -> STARTING -> RUNNING -> THINKING -> RUNNING -> STOPPING -> STOPPED
 *
 * 状态说明:
 * - STOPPED (0): 引擎已停止，未运行
 * - STARTING (1): 引擎正在启动中
 * - RUNNING (2): 引擎已启动，处于空闲状态
 * - THINKING (3): 引擎正在分析局面
 * - PONDERING (4): 引擎正在进行后台思考
 * - STOPPING (5): 引擎正在停止中
 * - ERROR (6): 引擎发生错误
 */
#define ENGINE_STATE_STOPPED    0
#define ENGINE_STATE_STARTING   1
#define ENGINE_STATE_RUNNING    2
#define ENGINE_STATE_THINKING   3
#define ENGINE_STATE_PONDERING  4
#define ENGINE_STATE_STOPPING   5
#define ENGINE_STATE_ERROR      6

// ============================================================================
// UCCI 命令类型常量
// ============================================================================
/**
 * UCCI（中国象棋引擎通信接口）命令类型常量
 *
 * UCCI 协议支持的主要命令:
 * - UCCI (1): 初始化协议
 * - ISREADY (2): 检查引擎是否就绪
 * - SETOPTION (3): 设置引擎选项
 * - POSITION (4): 设置棋局位置
 * - GO (5): 开始分析
 * - STOP (6): 停止分析
 * - PONDERHIT (7): 后台思考命中
 * - QUIT (8): 退出
 */
#define UCCI_CMD_NONE       0
#define UCCI_CMD_UCCI       1
#define UCCI_CMD_ISREADY    2
#define UCCI_CMD_SETOPTION  3
#define UCCI_CMD_POSITION   4
#define UCCI_CMD_GO         5
#define UCCI_CMD_STOP       6
#define UCCI_CMD_PONDERHIT  7
#define UCCI_CMD_QUIT       8

// ============================================================================
// UCCI 响应类型常量
// ============================================================================
/**
 * UCCI 协议响应类型常量
 *
 * 主要响应类型:
 * - ID (1): 引擎标识信息
 * - UCCIOK (2): 协议初始化确认
 * - READYOK (3): 就绪确认
 * - BESTMOVE (4): 最佳着法
 * - INFO (5): 分析信息
 * - OPTION (6): 选项信息
 * - ERROR (7): 错误信息
 */
#define UCCI_RESP_NONE      0
#define UCCI_RESP_ID        1
#define UCCI_RESP_UCCIOK    2
#define UCCI_RESP_READYOK   3
#define UCCI_RESP_BESTMOVE  4
#define UCCI_RESP_INFO      5
#define UCCI_RESP_OPTION    6
#define UCCI_RESP_ERROR     7

// ============================================================================
// UCI 命令类型常量
// ============================================================================
/**
 * UCI（通用棋类引擎接口）命令类型常量
 *
 * UCI 协议支持的主要命令:
 * - UCI (1): 初始化协议
 * - ISREADY (2): 检查引擎是否就绪
 * - SETOPTION (3): 设置引擎选项
 * - POSITION (4): 设置棋局位置
 * - GO (5): 开始分析
 * - STOP (6): 停止分析
 * - PONDERHIT (7): 后台思考命中
 * - QUIT (8): 退出
 *
 * 注意: UCI 命令类型与 UCCI 相同，便于统一处理
 */
#define UCI_CMD_NONE        0
#define UCI_CMD_UCI         1
#define UCI_CMD_ISREADY     2
#define UCI_CMD_SETOPTION   3
#define UCI_CMD_POSITION    4
#define UCI_CMD_GO          5
#define UCI_CMD_STOP        6
#define UCI_CMD_PONDERHIT   7
#define UCI_CMD_QUIT        8

// ============================================================================
// UCI 响应类型常量
// ============================================================================
/**
 * UCI 协议响应类型常量
 *
 * 主要响应类型:
 * - ID (1): 引擎标识信息
 * - UCIOK (2): 协议初始化确认
 * - READYOK (3): 就绪确认
 * - BESTMOVE (4): 最佳着法
 * - INFO (5): 分析信息（包含深度、评分、主变例等）
 * - OPTION (6): 选项信息
 * - ERROR (7): 错误信息
 */
#define UCI_RESP_NONE       0
#define UCI_RESP_ID         1
#define UCI_RESP_UCIOK      2
#define UCI_RESP_READYOK    3
#define UCI_RESP_BESTMOVE   4
#define UCI_RESP_INFO       5
#define UCI_RESP_OPTION     6
#define UCI_RESP_ERROR      7

// ============================================================================
// 调试级别常量
// ============================================================================
/**
 * XQEngine 调试级别常量
 *
 * 级别说明:
 * - NONE (0): 无输出
 * - ERROR (1): 仅错误
 * - WARN (2): 警告 + 错误
 * - INFO (3): 一般信息 + 警告 + 错误
 * - DEBUG (4): 详细调试
 * - TRACE (5): 最详细跟踪
 */
#define XQECI_DEBUG_LEVEL_NONE    0
#define XQECI_DEBUG_LEVEL_ERROR   1
#define XQECI_DEBUG_LEVEL_WARN    2
#define XQECI_DEBUG_LEVEL_INFO    3
#define XQECI_DEBUG_LEVEL_DEBUG   4
#define XQECI_DEBUG_LEVEL_TRACE   5

// ============================================================================
// 调试模块前缀
// ============================================================================
/**
 * XQEngine 调试模块前缀
 *
 * 用于标识日志消息来源模块
 */
#define XQECI_MODULE_CORE      "[XQECI-Core]"
#define XQECI_MODULE_CONFIG    "[XQECI-Config]"
#define XQECI_MODULE_STATE     "[XQECI-State]"
#define XQECI_MODULE_PROTOCOL  "[XQECI-Protocol]"
#define XQECI_MODULE_TEST      "[XQECI-Test]"

// ============================================================================
// 调试日志级别前缀
// ============================================================================
#define XQECI_LOG_ERROR  "[ERROR]"
#define XQECI_LOG_WARN   "[WARN]"
#define XQECI_LOG_INFO   "[INFO]"
#define XQECI_LOG_DEBUG  "[DEBUG]"
#define XQECI_LOG_TRACE  "[TRACE]"

// ============================================================================
// 调试级别默认值
// ============================================================================
/**
 * 调试系统默认级别
 * 
 * 默认值: ERROR (1)
 * - 生产环境: ERROR (1) - 仅输出错误
 * - 用户反馈问题: INFO (3) - 输出信息、警告、错误
 * - 开发调试: DEBUG (4) - 输出详细调试信息
 */
#define XQECI_DEFAULT_DEBUG_LEVEL  XQECI_DEBUG_LEVEL_ERROR