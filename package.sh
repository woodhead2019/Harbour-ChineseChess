#!/bin/bash
#
# package.sh - 中国象棋项目打包脚本
# 为 Linux 和 Windows 平台创建发布包
#

# ==================== 配置区域 ====================

# 版本号
VERSION="1.0.1"
DATE=$(date +%Y%m%d)

# 发布目录
RELEASE_DIR="release"
mkdir -p "$RELEASE_DIR"

# 项目名称
PROJECT_NAME="cchess"

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

# ==================== 函数 ====================

# 打包 Linux 版本
package_linux() {
   local package_name="${PROJECT_NAME}-${VERSION}-linux-x86_64"
   local package_dir="${RELEASE_DIR}/${package_name}"
   
   echo ""
   echo "=========================================="
   echo "打包 Linux 版本"
   echo "=========================================="
   
   # 创建临时目录
   rm -rf "$package_dir"
   mkdir -p "$package_dir"
   
   # 复制可执行文件
   if [ -f "xq" ]; then
      cp xq "$package_dir/"
      print_info "复制可执行文件: xq"
   else
      print_error "找不到可执行文件: xq"
      return 1
   fi
   
   # 复制配置文件
   if [ -f "cchess.ini" ]; then
      cp cchess.ini "$package_dir/"
      print_info "复制配置文件: cchess.ini"
   fi
   
   # 复制皮肤资源
   if [ -d "skins" ]; then
      cp -r skins "$package_dir/"
      print_info "复制皮肤资源: skins/"
   fi
   
   # 复制声音文件
   if [ -d "sounds" ]; then
      cp -r sounds "$package_dir/"
      print_info "复制声音文件: sounds/"
   fi
   
   # 注意：引擎文件不包含在发布包中
   # 用户需要自行下载并配置引擎
   
   # 复制文档
   if [ -f "README.md" ]; then
      cp README.md "$package_dir/"
      print_info "复制 README"
   fi
   
   if [ -f "LICENSE" ]; then
      cp LICENSE "$package_dir/"
      print_info "复制 LICENSE"
   fi
   
   # 复制 ElephantEye 许可证
   if [ -f "eleeye_hb/LICENSE.ELEPHANTEYE" ]; then
      cp eleeye_hb/LICENSE.ELEPHANTEYE "$package_dir/"
      print_info "复制 ElephantEye LICENSE"
   fi
   
   # 复制 Pikafish 许可证
   if [ -f "engines/pikafish/Copying.txt" ]; then
      cp engines/pikafish/Copying.txt "$package_dir/engines/pikafish_LICENSE.txt"
      print_info "复制 Pikafish LICENSE"
   fi
   
   # 创建版本信息文件
   cat > "$package_dir/VERSION" << EOF
项目名称: 中国象棋 GUI
版本: $VERSION
发布日期: $DATE
平台: Linux x86_64
编译器: Harbour + GCC
EOF
   print_info "创建版本信息文件"
   
   # 创建 tar.gz 压缩包
   cd "$RELEASE_DIR"
   tar czf "${package_name}.tar.gz" "$package_name"
   cd ..
   
   print_info "创建压缩包: ${package_name}.tar.gz"
   
   # 显示包大小
   local package_size=$(du -h "${RELEASE_DIR}/${package_name}.tar.gz" | cut -f1)
   print_info2 "压缩包大小: $package_size"
   
   echo ""
   print_info "Linux 版本打包完成！"
   echo ""
}

# 打包 Windows 版本
package_windows() {
   local package_name="${PROJECT_NAME}-${VERSION}-windows-x86_64"
   local package_dir="${RELEASE_DIR}/${package_name}"
   
   echo ""
   echo "=========================================="
   echo "打包 Windows 版本"
   echo "=========================================="
   
   # 创建临时目录
   rm -rf "$package_dir"
   mkdir -p "$package_dir"
   
   # 复制可执行文件
   if [ -f "xq.exe" ]; then
      cp xq.exe "$package_dir/"
      print_info "复制可执行文件: xq.exe"
   else
      print_error "找不到可执行文件: xq.exe"
      return 1
   fi
   
   # 复制控制台版本
   if [ -f "xq_con.exe" ]; then
      cp xq_con.exe "$package_dir/"
      print_info "复制控制台版本: xq_con.exe"
   fi
   
   # 复制配置文件
   if [ -f "cchess.ini" ]; then
      cp cchess.ini "$package_dir/"
      print_info "复制配置文件: cchess.ini"
   fi
   
   # 复制皮肤资源
   if [ -d "skins" ]; then
      cp -r skins "$package_dir/"
      print_info "复制皮肤资源: skins/"
   fi
   
   # 复制声音文件
   if [ -d "sounds" ]; then
      cp -r sounds "$package_dir/"
      print_info "复制声音文件: sounds/"
   fi
   
   # 注意：引擎文件不包含在发布包中
   # 用户需要自行下载并配置引擎
   
   # 复制文档
   if [ -f "README.md" ]; then
      cp README.md "$package_dir/"
      print_info "复制 README"
   fi
   
   if [ -f "LICENSE" ]; then
      cp LICENSE "$package_dir/"
      print_info "复制 LICENSE"
   fi
   
   # 复制 ElephantEye 许可证
   if [ -f "eleeye_hb/LICENSE.ELEPHANTEYE" ]; then
      cp eleeye_hb/LICENSE.ELEPHANTEYE "$package_dir/"
      print_info "复制 ElephantEye LICENSE"
   fi
   
   # 创建版本信息文件
   cat > "$package_dir/VERSION" << EOF
项目名称: 中国象棋 GUI
版本: $VERSION
发布日期: $DATE
平台: Windows x86_64
编译器: Harbour + MinGW64 (ucrt64)
EOF
   print_info "创建版本信息文件"
   
   # 创建 zip 压缩包
   cd "$RELEASE_DIR"
   zip -r "${package_name}.zip" "$package_name"
   cd ..
   
   print_info "创建压缩包: ${package_name}.zip"
   
   # 显示包大小
   local package_size=$(du -h "${RELEASE_DIR}/${package_name}.zip" | cut -f1)
   print_info2 "压缩包大小: $package_size"
   
   echo ""
   print_info "Windows 版本打包完成！"
   echo ""
}

# 创建源代码包
package_source() {
   local package_name="${PROJECT_NAME}-${VERSION}-source"
   local package_dir="${RELEASE_DIR}/${package_name}"
   
   echo ""
   echo "=========================================="
   echo "打包源代码"
   echo "=========================================="
   
   # 创建临时目录
   rm -rf "$package_dir"
   mkdir -p "$package_dir"
   
   # 使用 git archive 创建源代码包
   if git rev-parse --git-dir > /dev/null 2>&1; then
      git archive --format=tar --prefix="${package_name}/" HEAD | tar -x -C "$RELEASE_DIR"
      print_info "从 Git 仓库创建源代码包"
   else
      print_warning "不是 Git 仓库，手动复制源代码"
      # 复制所有 .prg, .hbp, .hbc 文件
      mkdir -p "$package_dir"
      cp *.prg *.hbp *.hbc *.ch "$package_dir/" 2>/dev/null
      cp -r xqengine.prg "$package_dir/" 2>/dev/null
   fi
   
   # 创建 tar.gz 压缩包
   cd "$RELEASE_DIR"
   tar czf "${package_name}.tar.gz" "$package_name"
   cd ..
   
   print_info "创建压缩包: ${package_name}.tar.gz"
   
   # 显示包大小
   local package_size=$(du -h "${RELEASE_DIR}/${package_name}.tar.gz" | cut -f1)
   print_info2 "压缩包大小: $package_size"
   
   echo ""
   print_info "源代码打包完成！"
   echo ""
}

# 显示帮助信息
show_help() {
   cat << EOF
用法: $0 [选项]

选项:
  linux        只打包 Linux 版本
  windows      只打包 Windows 版本
  source       只打包源代码
  all          打包所有版本（默认）
  clean        清理发布目录
  help         显示此帮助信息

示例:
  $0 all        # 打包所有版本
  $0 linux      # 只打包 Linux 版本
  $0 windows    # 只打包 Windows 版本
  $0 clean      # 清理发布目录

EOF
}

# 清理发布目录
clean() {
   echo ""
   echo "=========================================="
   echo "清理发布目录"
   echo "=========================================="
   
   rm -rf "$RELEASE_DIR"
   print_info "清理完成"
   echo ""
}

# 主函数
main() {
   local option="${1:-all}"
   
   case "$option" in
      linux)
         package_linux
         ;;
      windows)
         package_windows
         ;;
      source)
         package_source
         ;;
      all)
         package_linux
         package_windows
         package_source
         
         echo ""
         echo "=========================================="
         echo "所有版本打包完成！"
         echo "=========================================="
         echo ""
         print_info2 "发布目录: $RELEASE_DIR"
         echo ""
         ls -lh "$RELEASE_DIR"
         ;;
      clean)
         clean
         ;;
      help|--help|-h)
         show_help
         ;;
      *)
         print_error "未知选项: $option"
         echo ""
         show_help
         exit 1
         ;;
   esac
}

# 执行主函数
main "$@"