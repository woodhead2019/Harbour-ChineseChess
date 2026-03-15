#!/bin/bash
#
# build.sh - 中国象棋项目构建脚本
# 支持本地构建和 Windows 交叉编译（使用 Zig 编译器）
#

# ==================== 配置区域 - 根据你的环境修改这里 ====================

# Harbour 编译器路径
HBMK2="/opt/harbour/bin/hbmk2"
HB_HOST_BIN="/opt/harbour/bin"

# HwGUI 库路径（仅用于信息显示，实际路径在 xq.hbp 和 xq.hbc 中配置）
HWGUI_INCLUDE_DIR="/opt/hwgui/include"
HWGUI_LIB_LINUX="/opt/hwgui/lib/linux/gcc"
HWGUI_LIB_WINDOWS="/opt/hwgui/lib/win/mingw64"

# Zig 编译器路径（使用zig来做Windows 交叉编译时使用）
#ZIG_PATH="/opt/zig"
#ZIG="${ZIG_PATH}/zig"

#使用zig做 Windows 交叉编译配置
#HB_ZIG_TARGET="x86_64-windows-gnu"
#HB_CPU="x86_64"
#HB_PLATFORM="win"
#HB_COMPILER="zig"

#使用mingw64做 Windows 交叉编译配置
HB_PLATFORM="win"
HB_COMPILER="mingw64"

#使用mingw64做 Windows 交叉编译配置

# ==================== 以下是脚本逻辑，通常不需要修改 ====================

# 日志目录
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# 检查 hbmk2 是否存在
if [ ! -f "$HBMK2" ]; then
    echo "错误: 找不到 hbmk2: $HBMK2"
    echo "请修改此文件开头的 HBMK2 变量"
    exit 1
fi

# ==================== 颜色和工具函数 ====================
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info2() { echo -e "${BLUE}ℹ${NC} $1"; }

# ==================== 检查 Zig 编译器 ====================
check_zig() {
    if [ -f "$ZIG" ]; then
        return 0
    else
        return 1
    fi
}

# ==================== 检查 Mingw64 编译器 ====================
check_mingw64() {
    # 检查传统的 mingw64 编译器
    if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        return 0
    fi
    # 检查 ucrt64 编译器
    if command -v x86_64-w64-mingw32ucrt-gcc &> /dev/null; then
        return 0
    fi
    return 1
}

# ==================== 设置 Windows 交叉编译环境 ====================
setup_windows_env() {
    export HB_HOST_BIN="${HB_HOST_BIN}"
    export HB_PLATFORM="${HB_PLATFORM}"
    export HB_COMPILER="${HB_COMPILER}"
    
    if [ "$HB_COMPILER" = "zig" ]; then
        export PATH="$PATH:${ZIG_PATH}"
        export HB_ZIG_TARGET="${HB_ZIG_TARGET}"
        export HB_CPU="${HB_CPU}"
    elif [ "$HB_COMPILER" = "mingw64" ]; then
        # 检查是否使用 ucrt64 编译器
        if command -v x86_64-w64-mingw32ucrt-gcc &> /dev/null; then
            # ucrt64 编译器不支持 -mwindows 选项，使用 -Wl,--subsystem,windows
            export HB_LD_ADD="-Wl,--subsystem,windows"
        fi
    fi
    # mingw64 不需要额外设置环境变量，hbmk2 会自动检测
}

# ==================== 构建 GUI 版本 ====================
build_gui() {
    local platform=$1
    local timestamp
    local log_file
    local hbp_file
    local output_name

    timestamp=$(date +"%Y%m%d_%H%M%S")
    log_file="${LOG_DIR}/gui_${platform}_${timestamp}.log"
    
    if [ "$platform" = "windows" ]; then
        hbp_file="xq.hbp"
        output_name="xq.exe"
        
        # 根据配置的编译器类型检查编译器是否可用
        if [ "$HB_COMPILER" = "zig" ]; then
            check_zig || { print_error "未找到 Zig 编译器: $ZIG"; return 1; }
        elif [ "$HB_COMPILER" = "mingw64" ]; then
            check_mingw64 || { print_error "未找到 Mingw64 编译器 (x86_64-w64-mingw32-gcc 或 x86_64-w64-mingw32ucrt-gcc)"; return 1; }
        else
            print_error "不支持的编译器类型: $HB_COMPILER"; return 1
        fi
        
        setup_windows_env
    else
        hbp_file="xq.hbp"
        output_name="xq"
    fi

    echo ""
    echo "=========================================="
    print_info2 "开始构建 $platform GUI 版本"
    echo "=========================================="
    print_info2 "日志文件: $log_file"
    print_info2 "时间戳: $(date)"
    print_info2 "输出文件: $output_name"
    echo "=========================================="

    # 构建命令（所有路径和标志已在 xq.hbp 和 xq.hbc 中配置）
    local build_cmd
    local use_ucrt64=0
    
    if [ "$platform" = "windows" ]; then
        if [ "$HB_COMPILER" = "zig" ]; then
            build_cmd="$HBMK2 -plat=win -comp=zig $hbp_file"
        else
            # 检查是否使用 ucrt64 编译器
            if command -v x86_64-w64-mingw32ucrt-gcc &> /dev/null; then
                use_ucrt64=1
                # ucrt64 编译器需要手动指定链接器选项
                build_cmd="$HBMK2 -plat=win -comp=mingw64 $hbp_file -ldflag=-Wl,--subsystem,windows -ldflag=-Wl,--entry=mainCRTStartup"
            else
                # 传统的 mingw64 编译器
                build_cmd="$HBMK2 -plat=win -comp=mingw64 $hbp_file"
            fi
        fi
    else
        build_cmd="$HBMK2 $hbp_file"
    fi

    echo "构建命令: $build_cmd"
    echo ""

    # 如果使用 ucrt64 编译器，创建临时包装脚本移除 -mconsole 选项
    if [ "$use_ucrt64" = "1" ]; then
        local wrapper_script="/tmp/hbmk_gcc_wrapper_$$"
        cat > "$wrapper_script" << 'EOF'
#!/bin/bash
# 移除 -mconsole 选项（ucrt64 编译器不支持）
# 检测是否是链接命令（有 .o 文件参数）
is_linking=0
for arg in "$@"; do
    if [[ "$arg" == *.o ]]; then
        is_linking=1
        break
    fi
done

filtered_args=()
for arg in "$@"; do
    if [ "$arg" != "-mconsole" ]; then
        filtered_args+=("$arg")
    fi
done

exec x86_64-w64-mingw32ucrt-gcc "${filtered_args[@]}"
EOF
        chmod +x "$wrapper_script"
        
        # 创建一个临时目录，包含包装脚本
        local tmpdir="/tmp/hbmk_wrapper_$$"
        mkdir -p "$tmpdir"
        cp "$wrapper_script" "$tmpdir/gcc"
        chmod +x "$tmpdir/gcc"
        
        # 临时设置 PATH 以使用包装脚本
        export PATH="$tmpdir:$PATH"
        
        # 执行构建命令
        $build_cmd 2>&1 | tee "$log_file"
        local build_result=${PIPESTATUS[0]}
        
        # 清理临时目录和脚本
        rm -rf "$tmpdir"
        rm -f "$wrapper_script"
        
        if [ $build_result -eq 0 ]; then
            echo ""
            echo "=========================================="
            print_info "$platform GUI 版本构建成功"
            echo "=========================================="
            print_info2 "输出文件: $output_name"
            
            if [ -f "$output_name" ]; then
                print_info2 "文件大小: $(ls -lh "$output_name" | awk '{print $5}')"
                print_info2 "文件类型: $(file "$output_name" | cut -d: -f2-)"
            fi
            
            echo "=========================================="
            echo "日志文件: $log_file"
            echo "日志行数: $(wc -l < "$log_file")"
            echo "警告数量: $(grep -i "warning" "$log_file" | wc -l)"
            echo "错误数量: $(grep -i "error" "$log_file" | wc -l)"
            echo "=========================================="
            return 0
        else
            echo ""
            echo "=========================================="
            print_error "$platform GUI 版本构建失败"
            echo "=========================================="
            return 1
        fi
    else
        # 非编译器类型，直接执行构建命令
        if $build_cmd 2>&1 | tee "$log_file"; then
            echo ""
            echo "=========================================="
            print_info "$platform GUI 版本构建成功"
            echo "=========================================="
            print_info2 "输出文件: $output_name"
            
            if [ -f "$output_name" ]; then
                print_info2 "文件大小: $(ls -lh "$output_name" | awk '{print $5}')"
                print_info2 "文件类型: $(file "$output_name" | cut -d: -f2-)"
            fi
            
            echo "=========================================="
            echo "日志文件: $log_file"
            echo "日志行数: $(wc -l < "$log_file")"
            echo "警告数量: $(grep -i "warning" "$log_file" | wc -l)"
            echo "错误数量: $(grep -i "error" "$log_file" | wc -l)"
            echo "=========================================="
            return 0
        else
            echo ""
            echo "=========================================="
            print_error "$platform GUI 版本构建失败"
            echo "=========================================="
            return 1
        fi
    fi
}

# ==================== 构建控制台版本 ====================
build_console() {
    local platform=$1
    local timestamp
    local log_file
    local hbp_file
    local output_name

    timestamp=$(date +"%Y%m%d_%H%M%S")
    log_file="${LOG_DIR}/console_${platform}_${timestamp}.log"
    
    if [ "$platform" = "windows" ]; then
        hbp_file="xq_con.hbp"
        output_name="xq_con.exe"
        
        # 根据配置的编译器类型检查编译器是否可用
        if [ "$HB_COMPILER" = "zig" ]; then
            check_zig || { print_error "未找到 Zig 编译器: $ZIG"; return 1; }
        elif [ "$HB_COMPILER" = "mingw64" ]; then
            check_mingw64 || { print_error "未找到 Mingw64 编译器 (x86_64-w64-mingw32-gcc 或 x86_64-w64-mingw32ucrt-gcc)"; return 1; }
        else
            print_error "不支持的编译器类型: $HB_COMPILER"; return 1
        fi
        
        setup_windows_env
    else
        hbp_file="xq_con.hbp"
        output_name="xq_con"
    fi

    echo ""
    echo "=========================================="
    print_info2 "开始构建 $platform 控制台版本"
    echo "=========================================="
    print_info2 "日志文件: $log_file"
    print_info2 "时间戳: $(date)"
    print_info2 "输出文件: $output_name"
    echo "=========================================="

    # 构建命令
    local build_cmd
    local use_ucrt64=0
    
    if [ "$platform" = "windows" ]; then
        if [ "$HB_COMPILER" = "zig" ]; then
            build_cmd="$HBMK2 -plat=win -comp=zig $hbp_file"
        else
            # 检查是否使用 ucrt64 编译器
            if command -v x86_64-w64-mingw32ucrt-gcc &> /dev/null; then
                use_ucrt64=1
                # ucrt64 编译器
                build_cmd="$HBMK2 -plat=win -comp=mingw64 $hbp_file"
            else
                # 传统的 mingw64 编译器
                build_cmd="$HBMK2 -plat=win -comp=mingw64 $hbp_file"
            fi
        fi
    else
        build_cmd="$HBMK2 $hbp_file"
    fi

    echo "构建命令: $build_cmd"
    echo ""

    # 如果使用 ucrt64 编译器，创建临时包装脚本移除 -mconsole 选项
    if [ "$use_ucrt64" = "1" ]; then
        local wrapper_script="/tmp/hbmk_gcc_wrapper_$$"
        cat > "$wrapper_script" << 'EOF'
#!/bin/bash
# 移除 -mconsole 选项（ucrt64 编译器不支持）
filtered_args=()
for arg in "$@"; do
    if [ "$arg" != "-mconsole" ]; then
        filtered_args+=("$arg")
    fi
done
exec x86_64-w64-mingw32ucrt-gcc "${filtered_args[@]}"
EOF
        chmod +x "$wrapper_script"
        
        # 创建一个临时目录，包含包装脚本
        local tmpdir="/tmp/hbmk_wrapper_$$"
        mkdir -p "$tmpdir"
        cp "$wrapper_script" "$tmpdir/gcc"
        chmod +x "$tmpdir/gcc"
        
        # 临时设置 PATH 以使用包装脚本
        export PATH="$tmpdir:$PATH"
        
        # 执行构建命令
        $build_cmd 2>&1 | tee "$log_file"
        local build_result=${PIPESTATUS[0]}
        
        # 清理临时目录和脚本
        rm -rf "$tmpdir"
        rm -f "$wrapper_script"
        
        if [ $build_result -eq 0 ]; then
            echo ""
            echo "=========================================="
            print_info "$platform 控制台版本构建成功"
            echo "=========================================="
            print_info2 "输出文件: $output_name"
            
            if [ -f "$output_name" ]; then
                print_info2 "文件大小: $(ls -lh "$output_name" | awk '{print $5}')"
                print_info2 "文件类型: $(file "$output_name" | cut -d: -f2-)"
            fi
            
            echo "=========================================="
            echo "日志文件: $log_file"
            echo "日志行数: $(wc -l < "$log_file")"
            echo "警告数量: $(grep -i "warning" "$log_file" | wc -l)"
            echo "错误数量: $(grep -i "error" "$log_file" | wc -l)"
            echo "=========================================="
            return 0
        else
            echo ""
            echo "=========================================="
            print_error "$platform 控制台版本构建失败"
            echo "=========================================="
            return 1
        fi
    else
        # 非编译器类型，直接执行构建命令
        if $build_cmd 2>&1 | tee "$log_file"; then
            echo ""
            echo "=========================================="
            print_info "$platform 控制台版本构建成功"
            echo "=========================================="
            print_info2 "输出文件: $output_name"
            
            if [ -f "$output_name" ]; then
                print_info2 "文件大小: $(ls -lh "$output_name" | awk '{print $5}')"
                print_info2 "文件类型: $(file "$output_name" | cut -d: -f2-)"
            fi
            
            echo "=========================================="
            echo "日志文件: $log_file"
            echo "日志行数: $(wc -l < "$log_file")"
            echo "警告数量: $(grep -i "warning" "$log_file" | wc -l)"
            echo "错误数量: $(grep -i "error" "$log_file" | wc -l)"
            echo "=========================================="
            return 0
        else
            echo ""
            echo "=========================================="
            print_error "$platform 控制台版本构建失败"
            echo "=========================================="
            return 1
        fi
    fi
}

# ==================== 清理函数 ====================
clean() {
    local platform=$1
    
    echo ""
    print_info "清理构建文件..."
    
    if [ "$platform" = "all" ] || [ "$platform" = "linux" ]; then
        rm -rf .hbmk xq xq_con xq.exe xq_con.exe 2>/dev/null
        rm -f *.pdb 2>/dev/null
        print_info "已清理所有构建文件"
    elif [ "$platform" = "windows" ]; then
        rm -f xq.exe xq_con.exe 2>/dev/null
        print_info "已清理 Windows 构建文件"
    fi
    
    # 清理日志文件
    if [ -d "$LOG_DIR" ]; then
        rm -f "${LOG_DIR}"/*.log 2>/dev/null
        print_info "已清理日志文件"
    fi
}

# ==================== 显示帮助 ====================
show_help() {
    cat << EOF
中国象棋项目 - 构建脚本

用法: $0 <命令> [平台]

命令:
  gui           构建 GUI 版本
  console       构建控制台版本
  all           构建所有版本
  clean         清理构建文件

平台:
  linux         Linux 平台（默认）
  windows       Windows 平台（需要 Zig 或 Mingw64 编译器）
  all           所有平台

示例:
  $0                    # 显示帮助
  $0 gui linux          # 构建 Linux GUI 版本
  $0 gui windows        # 构建 Windows GUI 版本
  $0 console linux      # 构建 Linux 控制台版本
  $0 all linux          # 构建所有 Linux 版本
  $0 all                # 构建所有版本
  $0 clean              # 清理所有构建文件
  $0 clean windows      # 清理 Windows 构建文件

配置:
  所有路径配置都在此文件开头的"配置区域"
  
  Windows 交叉编译器选择:
  - Zig 编译器: 设置 HB_COMPILER="zig"（需取消注释 ZIG 相关配置）
  - Mingw64 编译器: 设置 HB_COMPILER="mingw64"（需安装 x86_64-w64-mingw32-gcc）
  
  根据你的环境修改开头的路径变量和编译器选择

EOF
}

# ==================== 主逻辑 ====================
TARGET="${1:-help}"
PLATFORM="${2:-linux}"

case "$TARGET" in
    gui)
        build_gui "$PLATFORM"
        ;;
    console)
        build_console "$PLATFORM"
        ;;
    all)
        if [ $# -eq 1 ]; then
            # 未指定平台参数，构建所有平台
            print_info2 "构建所有平台的所有版本..."
            build_gui linux || exit 1
            build_console linux || exit 1
            
            # 根据配置的编译器类型检查是否可用
            if [ "$HB_COMPILER" = "zig" ]; then
                if check_zig; then
                    build_gui windows || exit 1
                    build_console windows || exit 1
                else
                    print_warning "跳过 Windows 版本（未找到 Zig 编译器）"
                fi
            elif [ "$HB_COMPILER" = "mingw64" ]; then
                if check_mingw64; then
                    build_gui windows || exit 1
                    build_console windows || exit 1
                else
                    print_warning "跳过 Windows 版本（未找到 Mingw64 编译器）"
                fi
            fi
            
            print_info "所有版本构建完成"
            echo ""
            echo "生成的文件："
            ls -lh xq xq_con 2>/dev/null | grep -E "^-"
            ls -lh xq.exe xq_con.exe 2>/dev/null | grep -E "^-"
        else
            # 指定了具体平台，构建该平台的所有版本
            print_info2 "构建 $PLATFORM 平台的所有版本..."
            build_gui "$PLATFORM" || exit 1
            build_console "$PLATFORM" || exit 1
            print_info "$PLATFORM 平台所有版本构建完成"
        fi
        ;;
    clean)
        clean "$PLATFORM"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "错误: 未知命令 '$TARGET'"
        echo ""
        show_help
        exit 1
        ;;
esac
