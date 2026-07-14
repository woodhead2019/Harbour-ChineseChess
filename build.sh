1| #!/bin/bash
2| #
3| # build.sh - 中国象棋项目构建脚本
4| # 支持本地构建和 Windows 交叉编译（使用 Zig 编译器）
5| #
6| 
7| # ==================== 配置区域 - 根据你的环境修改这里 ====================
8| 
9| # Harbour 编译器路径
10| HBMK2="/opt/harbour/bin/hbmk2"
11| HB_HOST_BIN="/opt/harbour/bin"
12| 
13| # HwGUI 库路径（仅用于信息显示，实际路径在 xq.hbp 和 xq.hbc 中配置）
14| HWGUI_INCLUDE_DIR="/opt/hwgui/include"
15| HWGUI_LIB_LINUX="/opt/hwgui/lib/linux/gcc"
16| HWGUI_LIB_WINDOWS="/opt/hwgui/lib/win/mingw64"
17| 
18| # Zig 编译器路径（使用zig来做Windows 交叉编译时使用）
19| #ZIG_PATH="/opt/zig"
20| #ZIG="${ZIG_PATH}/zig"
21| 
22| #使用zig做 Windows 交叉编译配置
23| #HB_ZIG_TARGET="x86_64-windows-gnu"
24| #HB_CPU="x86_64"
25| #HB_PLATFORM="win"
26| #HB_COMPILER="zig"
27| 
28| #使用mingw64做 Windows 交叉编译配置
29| HB_PLATFORM="win"
30| HB_COMPILER="mingw64"
31| 
32| #使用mingw64做 Windows 交叉编译配置
33| 
34| # ==================== 以下是脚本逻辑，通常不需要修改 ====================
35| 
36| # 日志目录
37| LOG_DIR="logs"
38| mkdir -p "$LOG_DIR"
39| 
40| # 检查 hbmk2 是否存在 -- 改为更鲁棒的检测：先检查指定路径，若不存在再尝试 PATH
41| if [ ! -f "$HBMK2" ]; then
42|     if command -v hbmk2 >/dev/null 2>&1; then
43|         HBMK2="$(command -v hbmk2)"
44|         echo "使用 PATH 中的 hbmk2: $HBMK2"
45|     else
46|         echo "错误: 找不到 hbmk2: $HBMK2"
47|         echo "请确认前面的 Harbour 构建步骤是否成功并已安装 /opt/harbour/bin/hbmk2，或修改本文件开头的 HBMK2 变量指向有效的 hbmk2 可执行文件。"
48|         echo "当前 PATH=$PATH"
49|         echo "列出 /opt 目录以便诊断："
50|         ls -l /opt || true
51|         echo "列出 /opt/harbour（若存在）："
52|         ls -l /opt/harbour || true
53|         exit 1
54|     fi
55| fi
56| 
57| # ==================== 颜色和工具函数 ====================
58| GREEN='\033[0;32m'
59| RED='\033[0;31m'
60| YELLOW='\033[1;33m'
61| BLUE='\033[0;34m'
62| NC='\033[0m'
63| 
64| print_info() { echo -e "${GREEN}✓${NC} $1"; }
65| print_error() { echo -e "${RED}✗${NC} $1"; }
66| print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
67| print_info2() { echo -e "${BLUE}ℹ${NC} $1"; }
68| 
69| # ==================== 检查 Zig 编译器 ====================
70| check_zig() {
71|     if [ -f "$ZIG" ]; then
72|         return 0
73|     else
74|         return 1
75|     fi
76| }
77| 
78| # ==================== 检查 Mingw64 编译器 ====================
79| check_mingw64() {
80|     # 检查传统的 mingw64 编译器
81|     if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
82|         return 0
83|     fi
84|     # 检查 ucrt64 编译器
85|     if command -v x86_64-w64-mingw32ucrt-gcc &> /dev/null; then
86|         return 0
87|     fi
88|     return 1
89| }
90| 
91| # ==================== 设置 Windows 交叉编译环境 ====================
92| setup_windows_env() {
93|     export HB_HOST_BIN="${HB_HOST_BIN}"
94|     export HB_PLATFORM="${HB_PLATFORM}"
95|     export HB_COMPILER="${HB_COMPILER}"
96|     
97|     if [ "$HB_COMPILER" = "zig" ]; then
98|         export PATH="$PATH:${ZIG_PATH}"
99|         export HB_ZIG_TARGET="${HB_ZIG_TARGET}"
100|         export HB_CPU="${HB_CPU}"
101|     elif [ "$HB_COMPILER" = "mingw64" ]; then
102|         # 检查是否使用 ucrt64 编译器
103|         if command -v x86_64-w64-mingw32ucrt-gcc &> /dev/null; then
104|             # ucrt64 编译器不支持 -mwindows 选项，使用 -Wl,--subsystem,windows
105|             export HB_LD_ADD="-Wl,--subsystem,windows"
106|         fi
107|     fi
108|     # mingw64 不需要额外设置环境变量，hbmk2 会自动检测
109| }
110| 
111| # ==================== 构建 GUI 版本 ====================
112| build_gui() {
113|     local platform=$1
114|     local timestamp
115|     local log_file
116|     local hbp_file
117|     local output_name
118| 
119|     timestamp=$(date +"%Y%m%d_%H%M%S")
120|     log_file="${LOG_DIR}/gui_${platform}_${timestamp}.log"
121|     
122|     if [ "$platform" = "windows" ]; then
123|         hbp_file="xq.hbp"
124|         output_name="xq.exe"
125|         
126|         # 根据配置的编译器类型检查编译器是否可用
127|         if [ "$HB_COMPILER" = "zig" ]; then
128|             check_zig || { print_error "未找到 Zig 编译器: $ZIG"; return 1; }
129|         elif [ "$HB_COMPILER" = "mingw64" ]; then
130|             check_mingw64 || { print_error "未找到 Mingw64 编译器 (x86_64-w64-mingw32-gcc 或 x86_64-w64-mingw32ucrt-gcc)"; return 1; }
131|         else
132|             print_error "不支持的编译器类型: $HB_COMPILER"; return 1
133|         fi
134|         
135|         setup_windows_env
136|     else
137|         hbp_file="xq.hbp"
138|         output_name="xq"
139|     fi
140| 
141|     echo ""
142|     echo "=========================================="
143|     print_info2 "开始构建 $platform GUI 版本"
144|     echo "=========================================="
145|     print_info2 "日志文件: $log_file"
146|     print_info2 "时间戳: $(date)"
147|     print_info2 "输出文件: $output_name"
148|     echo "=========================================="
149| 
150|     # 构建命令（所有路径和标志已在 xq.hbp 和 xq.hbc 中配置）
151|     local build_cmd
152|     local use_ucrt64=0
153|     
154|     if [ "$platform" = "windows" ]; then
155|         if [ "$HB_COMPILER" = "zig" ]; then
156|             build_cmd="$HBMK2 -plat=win -comp=zig $hbp_file"
157|         else
158|             # 检查是否使用 ucrt64 编译器
159|             if command -v x86_64-w64-mingw32ucrt-gcc &> /dev/null; then
160|                 use_ucrt64=1
161|                 # ucrt64 编译器需要手动指定链接器选项
162|                 build_cmd="$HBMK2 -plat=win -comp=mingw64 $hbp_file -ldflag=-Wl,--subsystem,windows -ldflag=-Wl,--entry=mainCRTStartup"
163|             else
164|                 # 传统的 mingw64 编译器
165|                 build_cmd="$HBMK2 -plat=win -comp=mingw64 $hbp_file"
166|             fi
167|         fi
168|     else
169|         build_cmd="$HBMK2 $hbp_file"
170|     fi
171| 
172|     echo "构建命令: $build_cmd"
173|     echo ""
174| 
175|     # 如果使用 ucrt64 编译器，创建临时包装脚本移除 -mconsole 选项
176|     if [ "$use_ucrt64" = "1" ]; then
177|         local wrapper_script="/tmp/hbmk_gcc_wrapper_$$"
178|         cat > "$wrapper_script" << 'EOF'
179| #!/bin/bash
180| # 移除 -mconsole 选项（ucrt64 编译器不支持）
181| # 检测是否是链接命令（有 .o 文件参数）
182| is_linking=0
183| for arg in "$@"; do
184|     if [[ "$arg" == *.o ]]; then
185|         is_linking=1
186|         break
187|     fi
188| done
189| 
190| filtered_args=()
191| for arg in "$@"; do
192|     if [ "$arg" != "-mconsole" ]; then
193|         filtered_args+=("$arg")
194|     fi
195| done
196| 
197| exec x86_64-w64-mingw32ucrt-gcc "${filtered_args[@]}"
198| EOF
199|         chmod +x "$wrapper_script"
200|         
201|         # 创建一个临时目录，包含包装脚本
202|         local tmpdir="/tmp/hbmk_wrapper_$$"
203|         mkdir -p "$tmpdir"
204|         cp "$wrapper_script" "$tmpdir/gcc"
205|         chmod +x "$tmpdir/gcc"
206|         
207|         # 临时设置 PATH 以使用包装脚本
208|         export PATH="$tmpdir:$PATH"
209|         
210|         # 执行构建命令
211|         $build_cmd 2>&1 | tee "$log_file"
212|         local build_result=${PIPESTATUS[0]}
213|         
214|         # 清理临时目录和脚本
215|         rm -rf "$tmpdir"
216|         rm -f "$wrapper_script"
217|         
218|         if [ $build_result -eq 0 ]; then
219|             echo ""
220|             echo "=========================================="
221|             print_info "$platform GUI 版本构建成功"
222|             echo "=========================================="
223|             print_info2 "输出文件: $output_name"
224|             
225|             if [ -f "$output_name" ]; then
226|                 print_info2 "文件大小: $(ls -lh "$output_name" | awk '{print $5}')"
227|                 print_info2 "文件类型: $(file "$output_name" | cut -d: -f2-)"
228|             fi
229|             
230|             echo "=========================================="
231|             echo "日志文件: $log_file"
232|             echo "日志行数: $(wc -l < "$log_file")"
233|             echo "警告数量: $(grep -i "warning" "$log_file" | wc -l)"
234|             echo "错误数量: $(grep -i "error" "$log_file" | wc -l)"
235|             echo "=========================================="
236|             return 0
237|         else
238|             echo ""
239|             echo "=========================================="
240|             print_error "$platform GUI 版本构建失败"
241|             echo "=========================================="
242|             return 1
243|         fi
244|     else
245|         # 非编译器类型，直接执行构建命令
246|         if $build_cmd 2>&1 | tee "$log_file"; then
247|             echo ""
248|             echo "=========================================="
249|             print_info "$platform GUI 版本构建成功"
250|             echo "=========================================="
251|             print_info2 "输出文件: $output_name"
252|             
253|             if [ -f "$output_name" ]; then
254|                 print_info2 "文件大小: $(ls -lh "$output_name" | awk '{print $5}')"
255|                 print_info2 "文件类型: $(file "$output_name" | cut -d: -f2-)"
256|             fi
257|             
258|             echo "=========================================="
259|             echo "日志文件: $log_file"
260|             echo "日志行数: $(wc -l < "$log_file")"
261|             echo "警告数量: $(grep -i "warning" "$log_file" | wc -l)"
262|             echo "错误数量: $(grep -i "error" "$log_file" | wc -l)"
263|             echo "=========================================="
264|             return 0
265|         else
266|             echo ""
267|             echo "=========================================="
268|             print_error "$platform GUI 版本构建失败"
269|             echo "=========================================="
270|             return 1
271|         fi
272|     fi
273| }
274| 
275| # ==================== 构建控制台版本 ====================
276| build_console() {
277|     local platform=$1
278|     local timestamp
279|     local log_file
280|     local hbp_file
281|     local output_name
282| 
283|     timestamp=$(date +"%Y%m%d_%H%M%S")
284|     log_file="${LOG_DIR}/console_${platform}_${timestamp}.log"
285|     
286|     if [ "$platform" = "windows" ]; then
287|         hbp_file="xq_con.hbp"
288|         output_name="xq_con.exe"
289|         
290|         # 根据配置的编译器类型检查编译器是否可用
291|         if [ "$HB_COMPILER" = "zig" ]; then
292|             check_zig || { print_error "未找到 Zig 编译器: $ZIG"; return 1; }
293|         elif [ "$HB_COMPILER" = "mingw64" ]; then
294|             check_mingw64 || { print_error "未找到 Mingw64 编译器 (x86_64-w64-mingw32-gcc 或 x86_64-w64-mingw32ucrt-gcc)"; return 1; }
295|         else
296|             print_error "不支持的编译器类型: $HB_COMPILER"; return 1
297|         fi
298|         
299|         setup_windows_env
300|     else
301|         hbp_file="xq_con.hbp"
302|         output_name="xq_con"
303|     fi
304| 
305|     echo ""
306|     echo "=========================================="
307|     print_info2 "开始构建 $platform 控制台版本"
308|     echo "=========================================="
309|     print_info2 "日志文件: $log_file"
310|     print_info2 "时间戳: $(date)"
311|     print_info2 "输出文件: $output_name"
312|     echo "=========================================="
313| 
314|     # 构建命令
315|     local build_cmd
316|     local use_ucrt64=0
317|     
318|     if [ "$platform" = "windows" ]; then
319|         if [ "$HB_COMPILER" = "zig" ]; then
320|             build_cmd="$HBMK2 -plat=win -comp=zig $hbp_file"
321|         else
322|             # 检查是否使用 ucrt64 编译器
323|             if command -v x86_64-w64-mingw32ucrt-gcc &> /dev/null; then
324|                 use_ucrt64=1
325|                 # ucrt64 编译器
326|                 build_cmd="$HBMK2 -plat=win -comp=mingw64 $hbp_file"
327|             else
328|                 # 传统的 mingw64 编译器
329|                 build_cmd="$HBMK2 -plat=win -comp=mingw64 $hbp_file"
330|             fi
331|         fi
332|     else
333|         build_cmd="$HBMK2 $hbp_file"
334|     fi
335| 
336|     echo "构建命令: $build_cmd"
337|     echo ""
338| 
339|     # 如果使用 ucrt64 编译器，创建临时包装脚本移除 -mconsole 选项
340|     if [ "$use_ucrt64" = "1" ]; then
341|         local wrapper_script="/tmp/hbmk_gcc_wrapper_$$"
342|         cat > "$wrapper_script" << 'EOF'
343| #!/bin/bash
344| # 移除 -mconsole 选项（ucrt64 编译器不支持）
345| filtered_args=()
346| for arg in "$@"; do
347|     if [ "$arg" != "-mconsole" ]; then
348|         filtered_args+=("$arg")
349|     fi
350| done
351| exec x86_64-w64-mingw32ucrt-gcc "${filtered_args[@]}"
352| EOF
353|         chmod +x "$wrapper_script"
354|         
355|         # 创建一个临时目录，包含包装脚本
356|         local tmpdir="/tmp/hbmk_wrapper_$$"
357|         mkdir -p "$tmpdir"
358|         cp "$wrapper_script" "$tmpdir/gcc"
359|         chmod +x "$tmpdir/gcc"
360|         
361|         # 临时设置 PATH 以使用包装脚本
362|         export PATH="$tmpdir:$PATH"
363|         
364|         # 执行构建命令
365|         $build_cmd 2>&1 | tee "$log_file"
366|         local build_result=${PIPESTATUS[0]}
367|         
368|         # 清理临时目录和脚本
369|         rm -rf "$tmpdir"
370|         rm -f "$wrapper_script"
371|         
372|         if [ $build_result -eq 0 ]; then
373|             echo ""
374|             echo "=========================================="
375|             print_info "$platform 控制台版本构建成功"
376|             echo "=========================================="
377|             print_info2 "输出文件: $output_name"
378|             
379|             if [ -f "$output_name" ]; then
380|                 print_info2 "文件大小: $(ls -lh "$output_name" | awk '{print $5}')"
381|                 print_info2 "文件类型: $(file "$output_name" | cut -d: -f2-)"
382|             fi
383|             
384|             echo "=========================================="
385|             echo "日志文件: $log_file"
386|             echo "日志行数: $(wc -l < "$log_file")"
387|             echo "警告数量: $(grep -i "warning" "$log_file" | wc -l)"
388|             echo "错误数量: $(grep -i "error" "$log_file" | wc -l)"
389|             echo "=========================================="
390|             return 0
391|         else
392|             echo ""
393|             echo "=========================================="
394|             print_error "$platform 控制台版本构建失败"
395|             echo "=========================================="
396|             return 1
397|         fi
398|     else
399|         # 非编译器类型，直接执行构建命令
400|         if $build_cmd 2>&1 | tee "$log_file"; then
401|             echo ""
402|             echo "=========================================="
403|             print_info "$platform 控制台版本构建成功"
404|             echo "=========================================="
405|             print_info2 "输出文件: $output_name"
406|             
407|             if [ -f "$output_name" ]; then
408|                 print_info2 "文件大小: $(ls -lh "$output_name" | awk '{print $5}')"
409|                 print_info2 "文件类型: $(file "$output_name" | cut -d: -f2-)"
410|             fi
411|             
412|             echo "=========================================="
413|             echo "日志文件: $log_file"
414|             echo "日志行数: $(wc -l < "$log_file")"
415|             echo "警告数量: $(grep -i "warning" "$log_file" | wc -l)"
416|             echo "错误数量: $(grep -i "error" "$log_file" | wc -l)"
417|             echo "=========================================="
418|             return 0
419|         else
420|             echo ""
421|             echo "=========================================="
422|             print_error "$platform 控制台版本构建失败"
423|             echo "=========================================="
424|             return 1
425|         fi
426|     fi
427| }
428| 
429| # ==================== 清理函数 ====================
430| clean() {
431|     local platform=$1
432|     
433|     echo ""
434|     print_info "清理构建文件..."
435|     
436|     if [ "$platform" = "all" ] || [ "$platform" = "linux" ]; then
437|         rm -rf .hbmk xq xq_con xq.exe xq_con.exe 2>/dev/null
438|         rm -f *.pdb 2>/dev/null
439|         print_info "已清理所有构建文件"
440|     elif [ "$platform" = "windows" ]; then
441|         rm -f xq.exe xq_con.exe 2>/dev/null
442|         print_info "已清理 Windows 构建文件"
443|     fi
444|     
445|     # 清理日志文件
446|     if [ -d "$LOG_DIR" ]; then
447|         rm -f "${LOG_DIR}"/*.log 2>/dev/null
448|         print_info "已清理日志文件"
449|     fi
450| }
451| 
452| # ==================== 显示帮助 ====================
453| show_help() {
454|     cat << EOF
455| 中国象棋项目 - 构建脚本
456| 
457| 用法: $0 <命令> [平台]
458| 
459| 命令:
460|   gui           构建 GUI 版本
461|   console       构建控制台版本
462|   all           构建所有版本
463|   clean         清理构建文件
464| 
465| 平台:
466|   linux         Linux 平台（默认）
467|   windows       Windows 平台（需要 Zig 或 Mingw64 编译器）
468|   all           所有平台
469| 
470| 示例:
471|   $0                    # 显示帮助
472|   $0 gui linux          # 构建 Linux GUI 版本
473|   $0 gui windows        # 构建 Windows GUI 版本
474|   $0 console linux      # 构建 Linux 控制台版本
475|   $0 all linux          # 构建所有 Linux 版本
476|   $0 all                # 构建所有版本
477|   $0 clean              # 清理所有构建文件
478|   $0 clean windows      # 清理 Windows 构建文件
479| 
480| 配置:
481|   所有路径配置都在此文件开头的"配置区域"
482|   
483|   Windows 交叉编译器选择:
484|   - Zig 编译器: 设置 HB_COMPILER="zig"（需取消注释 ZIG 相关配置）
485|   - Mingw64 编译器: 设置 HB_COMPILER="mingw64"（需安装 x86_64-w64-mingw32-gcc）
486|   
487|   根据你的环境修改开头的路径变量和编译器选择
488| 
489| EOF
490| }
491| 
492| # ==================== 主逻辑 ====================
493| TARGET="${1:-help}"
494| PLATFORM="${2:-linux}"
495| 
496| case "$TARGET" in
497|     gui)
498|         build_gui "$PLATFORM"
499|         ;;
500|     console)
501|         build_console "$PLATFORM"
502|         ;;
503|     all)
504|         if [ $# -eq 1 ]; then
505|             # 未指定平台参数，构建所有平台
506|             print_info2 "构建所有平台的所有版本..."
507|             build_gui linux || exit 1
508|             build_console linux || exit 1
509|             
510|             # 根据配置的编译器类型检查是否可用
511|             if [ "$HB_COMPILER" = "zig" ]; then
512|                 if check_zig; then
513|                     build_gui windows || exit 1
514|                     build_console windows || exit 1
515|                 else
516|                     print_warning "跳过 Windows 版本（未找到 Zig 编译器）"
517|                 fi
518|             elif [ "$HB_COMPILER" = "mingw64" ]; then
519|                 if check_mingw64; then
520|                     build_gui windows || exit 1
521|                     build_console windows || exit 1
522|                 else
523|                     print_warning "跳过 Windows 版本（未找到 Mingw64 编译器）"
524|                 fi
525|             fi
526|             
527|             print_info "所有版本构建完成"
528|             echo ""
529|             echo "生成的文件："
530|             ls -lh xq xq_con 2>/dev/null | grep -E "^-"
531|             ls -lh xq.exe xq_con.exe 2>/dev/null | grep -E "^-"
532|         else
533|             # 指定了具体平台，构建该平台的所有版本
534|             print_info2 "构建 $PLATFORM 平台的所有版本..."
535|             build_gui "$PLATFORM" || exit 1
536|             build_console "$PLATFORM" || exit 1
537|             print_info "$PLATFORM 平台所有版本构建完成"
538|         fi
539|         ;;
540|     clean)
541|         clean "$PLATFORM"
542|         ;;
543|     help|--help|-h)
544|         show_help
545|         ;;
546|     *)
547|         echo "错误: 未知命令 '$TARGET'"
548|         echo ""
549|         show_help
550|         exit 1
551|         ;;
552| esac
553| 
