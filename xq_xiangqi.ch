/*
 * 中国象棋常量定义
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 */

// 构建信息（由 hbmk2 自动生成）
#include "hbmk_build_info.ch"
#include "hbmk_vcs_info.ch"

// ========== 国际化宏 ==========
#define _XQ_I__(key) xq_Translate(key)

// ========== 通用宏 ==========
#define CRLF Chr(13) + Chr(10)
#define NL hb_eol()

// ========== 日志系统常量 ==========
#define LOG_LEVEL_DEBUG   1
#define LOG_LEVEL_INFO    2
#define LOG_LEVEL_WARNING 3
#define LOG_LEVEL_ERROR   4
#define LOG_LEVEL_FATAL   5

#define LOG_TARGET_NONE    0x00
#define LOG_TARGET_FILE    0x01
#define LOG_TARGET_STDERR  0x02
#define LOG_TARGET_ALL     0xFF

// ========== 棋盘坐标常量 ==========
#define XQ_BOARD_ROWS    10
#define XQ_BOARD_COLS    9
#define XQ_BOARD_SIZE    90

// 位置结构常量（对应 funcs.prg 的 POS_*）
#define POS_BOARD        1      // 90字符棋盘字符串
#define POS_R0           2      // 红方右炮位置
#define POS_R2           3      // 红方左炮位置
#define POS_R7           4      // 红方右炮移动过河标志
#define POS_R9           5      // 红方左炮移动过河标志
#define POS_r0           6      // 黑方右炮位置
#define POS_r2           7      // 黑方左炮位置
#define POS_r7           8      // 黑方右炮移动过河标志
#define POS_r9           9      // 黑方左炮移动过河标志
#define POS_TURN         10     // 当前回合（TRUE=红，FALSE=黑）

// 棋子常量
#define XQ_EMPTY         '0'    // 空位（数字0）
#define XQ_KING_RED      'K'    // 帅
#define XQ_ADV_RED      'A'    // 仕
#define XQ_ELEPH_RED    'B'    // 相
#define XQ_HORSE_RED    'N'    // 马
#define XQ_ROOK_RED     'R'    // 车
#define XQ_CANNON_RED   'C'    // 炮
#define XQ_PAWN_RED     'P'    // 兵

#define XQ_KING_BLK     'k'    // 将
#define XQ_ADV_BLK      'a'    // 士
#define XQ_ELEPH_BLK    'b'    // 象
#define XQ_HORSE_BLK    'n'    // 马
#define XQ_ROOK_BLK     'r'    // 车
#define XQ_CANNON_BLK   'c'    // 炮
#define XQ_PAWN_BLK     'p'    // 卒

// 评估常量
#define XQ_VALUE_KING    10000
#define XQ_VALUE_ADV      20
#define XQ_VALUE_ELEPH    20
#define XQ_VALUE_HORSE    40
#define XQ_VALUE_ROOK     90
#define XQ_VALUE_CANNON   45
#define XQ_VALUE_PAWN     10

// 搜索常量
#define XQ_MATE_LOWER    -32000
#define XQ_MATE_UPPER     32000
#define XQ_INFINITE_VALUE 32001

// 特殊移动标记
#define XQ_MOVE_CASTLE   0    // 易位（中国象棋无）
#define XQ_MOVE_PROMOTE   0    // 升变（中国象棋无）
#define XQ_MOVE_ENPASSANT 0    // 吃过路兵（中国象棋无）

// 坐标计算常量（11x12数组，带边界）
#define XQ_BORDER_WIDTH   1
#define XQ_ARRAY_WIDTH    12
#define XQ_ARRAY_HEIGHT   12

// 移动方向常量
#define XQ_DIR_K_RED     {-13,-12,-11,-1,1,11,12,13}    // 帅
#define XQ_DIR_A_RED     {-13,-11,-1,1,11,13}           // 仕
#define XQ_DIR_B_RED     {-22,-26,-34,-2,2,22,26,34}   // 相
#define XQ_DIR_N_RED     {-23,-25,-27,-14,-12,-10,10,12,14,23,25,27}  // 马
#define XQ_DIR_R_RED     {-12,-1,1,12}                  // 车
#define XQ_DIR_C_RED     {-12,-1,1,12}                  // 炮
#define XQ_DIR_P_RED     {-12,12}                      // 兵

#define XQ_DIR_K_BLK     {-13,-12,-11,-1,1,11,12,13}    // 将
#define XQ_DIR_A_BLK     {-13,-11,-1,1,11,13}           // 士
#define XQ_DIR_B_BLK     {-22,-26,-34,-2,2,22,26,34}   // 象
#define XQ_DIR_N_BLK     {-23,-25,-27,-14,-12,-10,10,12,14,23,25,27}  // 马
#define XQ_DIR_R_BLK     {-12,-1,1,12}                  // 车
#define XQ_DIR_C_BLK     {-12,-1,1,12}                  // 炮
#define XQ_DIR_P_BLK     {-12,12}                      // 卒

// 九宫格坐标（逻辑坐标，ICCS标准：行0=红方底线，行9=黑方底线）
#define XQ_PALACE_RED_MIN_R  0
#define XQ_PALACE_RED_MAX_R  2
#define XQ_PALACE_RED_MIN_C  3
#define XQ_PALACE_RED_MAX_C  5

#define XQ_PALACE_BLK_MIN_R  7
#define XQ_PALACE_BLK_MAX_R  9
#define XQ_PALACE_BLK_MIN_C  3
#define XQ_PALACE_BLK_MAX_C  5

// 河界坐标（逻辑坐标，ICCS标准）
#define XQ_RIVER_TOP     4
#define XQ_RIVER_BOTTOM  5

// 炮的特殊移动（跳过棋子）
#define XQ_CANNON_JUMP   TRUE

// ========================================
// 资源管理常量
// ========================================

// 资源路径
#define XQ_SKIN_BASE_DIR    hb_DirBase() + "skins" + hb_osPathSeparator()
#define XQ_SOUND_BASE_DIR   hb_DirBase() + "sounds/"

// 棋盘和棋子文件名
#define XQ_BOARD_FILE_NAME  "board.jpg"
#define XQ_RED_K_FILE       "rk.png"
#define XQ_RED_A_FILE       "ra.png"
#define XQ_RED_B_FILE       "rb.png"
#define XQ_RED_C_FILE       "rc.png"
#define XQ_RED_N_FILE       "rn.png"
#define XQ_RED_R_FILE       "rr.png"
#define XQ_RED_P_FILE       "rp.png"
#define XQ_BLACK_K_FILE     "bk.png"
#define XQ_BLACK_A_FILE     "ba.png"
#define XQ_BLACK_B_FILE     "bb.png"
#define XQ_BLACK_C_FILE     "bc.png"
#define XQ_BLACK_N_FILE     "bn.png"
#define XQ_BLACK_R_FILE     "br.png"
#define XQ_BLACK_P_FILE     "bp.png"

// ========================================
// 棋局保存/加载格式常量
// ========================================
#define XQ_FORMAT_PGN      1   // PGN 格式
#define XQ_FORMAT_FEN      2   // FEN 格式
#define XQ_FORMAT_XQF      3   // 象棋论坛格式（预留）
#define XQ_FORMAT_CHE      4   // CHE 格式（预留）
#define XQ_FORMAT_MXQ      5   // MXQ 格式（预留）

// ========================================
// AI 引擎常量
// ========================================
#define XQ_BEATKING        100000

// ========================================
// UCCI 通信常量
// ========================================
#define XQ_BUFSIZE         16384
#define XQ_CMD_ARGS_MAX    32
#define XQ_CMD_LINE_MAX    256
#define XQ_CMDLENGTH       4096

// ========================================
// GUI 颜色常量
// ========================================

// 基础颜色
#define XQ_CLR_WHITE        0xffffff
#define XQ_CLR_BLACK        0x000000
#define XQ_CLR_RED          0xFF0000
#define XQ_CLR_BLUE         0x0000FF
#define XQ_CLR_HEADER       0x1E90FF
#define XQ_CLR_PANEL_BG     0xF5F5F5
#define XQ_CLR_SELECTED     0xE0E0E0
#define XQ_CLR_TEXT_RED     0xC62828
#define XQ_CLR_TEXT_BLACK   0x555555

// 按钮颜色
#define XQ_CLR_BGRAY1       0x7b7680
#define XQ_CLR_BGRAY2       0x5b5760
#define XQ_CLR_GBROWN       0x3C3940
#define XQ_CLR_DBROWN       0x2F343F

// ========================================
// GUI 布局常量
// ========================================
#define XQ_HEA_HEIGHT       32
#define XQ_TOP_HEIGHT       36

// 主窗口尺寸（紧凑布局）
#define XQ_MAIN_WIDTH_NORMAL   890    // 主窗口宽度（正常模式：20+550+20+280+10+10）
#define XQ_MAIN_WIDTH_DEBUG    1200   // 主窗口宽度（调试模式：20+550+20+280+20+300+10）
#define XQ_MAIN_HEIGHT          770    // 主窗口高度（紧凑：600棋盘+10间距+60状态栏+100边距）

// 棋盘区域尺寸（保持核心尺寸）
#define XQ_BOARD_WIDTH       550    // 棋盘宽度
#define XQ_BOARD_HEIGHT      600    // 棋盘高度
#define XQ_BOARD_START_Y     46     // 棋盘起始Y坐标（顶部面板36 + 间距10）
#define XQ_BOARD_START_X     20     // 棋盘起始X坐标（左边距）

// 右侧窗口区域（美学优化比例）
// 布局：棋盘 | 记谱法(上) | 消息调试(右侧，调试模式)
//              | 引擎输出(下) |
#define XQ_RIGHT_START_X     590    // 右侧区域起始X（棋盘550 + 间距20）
#define XQ_RIGHT_COL1_WIDTH  280    // 记谱法窗口宽度
#define XQ_RIGHT_COL2_START  890    // 第二列起始X（590 + 280 + 20）
#define XQ_RIGHT_COL2_WIDTH  280    // 引擎输出窗口宽度
#define XQ_RIGHT_COL3_START  890    // 消息调试窗口起始X（与记谱法+引擎输出并列，调试模式）
#define XQ_RIGHT_COL3_WIDTH  300    // 消息调试窗口宽度（调试模式）

// 右侧窗口高度
#define XQ_RIGHT_TOP_HEIGHT  600    // 记谱法/引擎输出窗口高度（与棋盘同高）
#define XQ_RIGHT_BOTTOM_HEIGHT 290  // 记谱法/引擎输出窗口高度（600/2 - 10）

// 状态栏布局常量（紧凑布局）
// 状态栏宽度（正常模式）= 棋盘550 + 记谱法280 + 间距40 = 870
// 状态栏宽度（调试模式）= 棋盘550 + 记谱法280 + 调试300 + 间距60 = 1190
#define XQ_STATUSBAR_WIDTH_NORMAL    850    // 状态栏宽度（正常模式，与棋盘+记谱法总宽度一致）
#define XQ_STATUSBAR_WIDTH_DEBUG     1170   // 状态栏宽度（调试模式，包含消息调试窗口）
#define XQ_STATUSBAR_START_X         20     // 状态栏起始X（与棋盘对齐）
#define XQ_STATUSBAR_Y               656    // 状态栏起始Y坐标（棋盘底部646 + 间距10）
#define XQ_STATUSBAR_LINE1_HEIGHT    20     // 第一行高度（紧凑）
#define XQ_STATUSBAR_LINE2_HEIGHT    20     // 第二行高度（紧凑）
#define XQ_STATUSBAR_TRACE_HEIGHT    20     // 调试追踪高度（紧凑）
