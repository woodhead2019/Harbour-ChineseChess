#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""
将二进制文件转换为Harbour代码格式
符合xq_resdata.prg的格式要求

格式说明：
   function xq_GetEmbeddedResources()
      local arr := { ;
         {"ba", "bmp", e"\x42\x4d\xfe\x08..."}, ;  <-- 每行：{"name","ext",e"..."}, ;
         {"bb", "bmp", e"\x42\x4d\xfe\x08..."}, ;
         ...
         {"rr", "bmp", e"\x42\x4d\xfe\x08..."};    <-- 最后一行：{"name","ext",e"..."}; （只有分号，没有逗号）
         }
   return arr

注意：每行结尾是逗号加换行，然后单独一行有一个分号
"""

import os
import sys
from pathlib import Path

def bin_to_hex_str(data):
    r"""将二进制数据转换为e"..."格式"""
    hex_str = ''.join(f'\\x{b:02x}' for b in data)
    return f'e"{hex_str}"'

def process_file(filepath):
    """处理单个文件，返回名称、扩展名和hex字符串"""
    filename = os.path.basename(filepath)
    name, ext = os.path.splitext(filename)
    ext = ext.lstrip('.')  # 去掉点号

    with open(filepath, 'rb') as f:
        data = f.read()

    hex_str = bin_to_hex_str(data)
    return name, ext, hex_str

def main():
    # eleeye资源目录
    eleeye_dir = '/home/woodhead/cchess/skins/eleeye'

    # 要处理的文件列表（按字母顺序）
    files_to_process = [
        'ba.bmp', 'bb.bmp', 'bc.bmp', 'bk.bmp', 'bn.bmp', 'bp.bmp', 'br.bmp',
        'board.jpg',
        'ra.bmp', 'rb.bmp', 'rc.bmp', 'rk.bmp', 'rn.bmp', 'rp.bmp', 'rr.bmp'
    ]

    # 输出文件
    output_file = '/home/woodhead/cchess/xq_resdata_new.txt'

    # 开始生成代码
    output_lines = []
    output_lines.append('// 中国象棋棋子资源 - 来自eleeye')
    output_lines.append('// 生成时间: 2026-03-08')
    output_lines.append('//')
    output_lines.append('//--------------------------------------------------------------------------------')
    output_lines.append('function xq_GetEmbeddedResources()')
    output_lines.append('   local arr := { ;')

    # 处理每个文件
    for i, filename in enumerate(files_to_process):
        filepath = os.path.join(eleeye_dir, filename)
        if not os.path.exists(filepath):
            print(f'警告: 文件不存在: {filepath}', file=sys.stderr)
            continue

        name, ext, hex_str = process_file(filepath)

        # 判断是否是最后一个文件
        is_last = (i == len(files_to_process) - 1)

        if is_last:
            # 最后一行：只有分号，没有逗号
            output_lines.append(f'      {{\"{name}\", \"{ext}\", {hex_str}}};')
        else:
            # 其他行：有逗号和分号
            output_lines.append(f'      {{\"{name}\", \"{ext}\", {hex_str}}}, ;')

    # 添加数组和函数结束
    output_lines.append('      }')
    output_lines.append('return arr')

    # 写入文件
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(output_lines))

    print(f'成功生成文件: {output_file}')
    print(f'处理了 {len(files_to_process)} 个文件')

if __name__ == '__main__':
    main()