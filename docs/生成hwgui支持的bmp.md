# 生成 HwGUI 支持的 BMP 格式

## 问题背景

在开发中国象棋 GUI 项目时，发现 Windows 下 HwGUI 对 BMP 格式有严格要求。使用 ImageMagick 默认转换的 BMP 文件在 Windows 下无法正确显示，但 Linux 下可以正常显示。

## BMP 格式差异

### BMP3 (Windows 3.x) - HwGUI 支持
- **格式**: PC bitmap, Windows 3.x format
- **bits offset**: 1078
- **适用**: Windows GDI+ 正确加载
- **示例**: eleeye 皮肤的 BMP 文件

```
file eleeye/rk.bmp
PC bitmap, Windows 3.x format, 34 x 34 x 8, image size 1224,
resolution 3780 x 3780 px/m, cbSize 2302, bits offset 1078
```

### BMP4 (Windows 98/2000) - HwGUI 不支持
- **格式**: PC bitmap, Windows 98/2000 and newer format
- **bits offset**: 1162
- **问题**: Windows GDI+ 无法正确加载
- **原因**: ImageMagick 默认生成 BMP4 格式

```
file woods/ba.bmp (错误格式)
PC bitmap, Windows 98/2000 and newer format, 57 x 57 x 8,
cbSize 5458, bits offset 1162
```

## 正确的转换命令

### 基本命令

```bash
convert input.png \
    -background magenta \      # 设置透明背景为洋红色
    -alpha remove \            # 移除 alpha 通道
    -alpha off \               # 关闭 alpha
    -colors 256 \              # 限制为256色（8-bit调色板）
    -define bmp:format=bmp3 \  # 指定 BMP3 格式（关键！）
    output.bmp
```

### 转换脚本

创建 `convert_png_to_bmp3.sh`:

```bash
#!/bin/bash
# 将 PNG 转换为 BMP3 格式（Windows 3.x）

cd /home/woodhead/cchess/skins/woods

for file in *.png; do
    if [ -f "$file" ]; then
        base="${file%.png}"

        convert "$file" \
            -background magenta \
            -alpha remove \
            -alpha off \
            -colors 256 \
            -define bmp:format=bmp3 \
            "$base.bmp"

        # 验证转换结果
        format=$(file "$base.bmp" | grep -o "Windows 3.x" || echo "Wrong format")
        echo "Converted $file -> $base.bmp ($format)"
    fi
done
```

### Python 脚本（需要 Pillow 库）

```python
#!/usr/bin/env python3
from PIL import Image

def convert_png_to_bmp3(input_file, output_file):
    """将 PNG 转换为 BMP3 格式"""
    img = Image.open(input_file)

    # 处理 alpha 通道
    if img.mode == 'RGBA':
        background = Image.new('RGBA', img.size, (255, 0, 255, 255))
        img = Image.alpha_composite(background, img)

    # 转换为调色板模式
    if img.mode != 'P':
        img = img.convert('RGB')

    # 保存为 BMP3 格式
    img.save(output_file, 'BMP')
```

## 关键参数说明

| 参数 | 说明 |
|------|------|
| `-background magenta` | 设置透明背景为洋红色 (0xFF00FF) |
| `-alpha remove` | 移除 alpha 通道，与背景混合 |
| `-alpha off` | 完全关闭 alpha 通道 |
| `-colors 256` | 限制为256色（8-bit调色板） |
| `-define bmp:format=bmp3` | **最关键**：指定 BMP3 格式 |

## 验证方法

### 使用 file 命令

```bash
# 检查格式
file output.bmp

# 正确输出应包含：
# "Windows 3.x format"
# "bits offset 1078"
```

### 对比验证

```bash
# 对比正确和错误的格式
file eleeye/rk.bmp    # 正确格式
file woods/ba.bmp     # 检查是否正确
```

## 透明色处理

### HwGUI 透明色要求

- **颜色**: 洋红色 (Magenta, RGB: 255, 0, 255)
- **十六进制**: 0xFF00FF
- **用途**: 指定透明区域

### 绘制函数

```harbour
// BMP 格式使用透明绘制
hwg_DrawTransparentBitmap( hDC, hBitmap, x, y, 0xFF00FF )
```

## 常见问题

### 1. Windows 下棋子不显示

**原因**: BMP 格式错误（BMP4 而非 BMP3）

**解决**: 使用 `-define bmp:format=bmp3` 参数

### 2. Linux 下正常，Windows 下不正常

**原因**: Windows GDI+ 对 BMP 格式要求更严格

**解决**: 确保使用 BMP3 格式

### 3. 透明色不生效

**原因**: Alpha 通道未正确处理

**解决**: 使用 `-alpha remove -alpha off` 参数

## 参考资料

- ImageMagick BMP 格式文档: https://imagemagick.org/script/formats.php#bmp
- BMP 文件格式规范: https://en.wikipedia.org/wiki/BMP_file_format
- HwGUI 绘图函数: `hwg_DrawTransparentBitmap()`

## 版本信息

- ImageMagick: 7.1.1-43
- HwGUI: 支持标准 BMP3 格式
- 测试平台: Linux, Windows

---

**创建时间**: 2026-03-08
**适用项目**: 中国象棋 GUI (cchess)