#!/bin/bash
# TypeBack 运行脚本

cd "$(dirname "$0")"

echo "正在构建 TypeBack..."
swift build

if [ $? -eq 0 ]; then
    echo "构建成功！"
    echo "正在运行 TypeBack..."
    .build/debug/TypeBack
else
    echo "构建失败，请检查错误信息"
fi