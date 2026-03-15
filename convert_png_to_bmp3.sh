#!/bin/bash
# 将 woods 皮肤的 PNG 转换为干净的 BMP 格式
# 使用颜色量化清理边缘杂色

echo "Converting woods PNG to clean BMP format..."

cd /home/woodhead/cchess/skins/woods

# 转换所有 PNG 文件
for file in *.png; do
    if [ -f "$file" ]; then
        base="${file%.png}"

        # 转换步骤：
        # 1. 设置黑色透明背景
        # 2. 移除 alpha 通道
        # 3. 使用颜色量化（256色）清理杂色
        # 4. 使用 dithering（抖动）减少伪影
        # 5. 使用 -mattecolor 指定边距颜色
        convert "$file" \
            -background black \
            -alpha remove \
            -alpha off \
            -colors 256 \
            -dither FloydSteinberg \
            -define bmp:format=bmp3 \
            "$base.bmp"

        # 检查转换结果
        if [ -f "$base.bmp" ]; then
            # 验证格式
            format=$(file "$base.bmp" | grep -o "Windows 3.x" || echo "Wrong format")
            depth=$(file "$base.bmp" | grep -o "[0-9]* bit" || echo "Unknown")
            echo "Converted $file -> $base.bmp ($format, $depth)"
        else
            echo "Failed to convert $file"
        fi
    fi
done

echo ""
echo "Conversion complete!"
echo ""
echo "Files created:"
ls -lh *.bmp