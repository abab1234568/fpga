---
name: md2html
description: 将 Markdown 文档转换为 HTML 网页。当用户提出：转网页、转html、生成html等关键词时使用。
---

# md2html — Markdown 转 HTML

## 适用场景

- 用户要求把 `.md` 转为 `.html`
- 用户说"转换"且目标格式为 html

## 输入约定

- 用户给出 Markdown 文件名或路径
- 若未给路径，默认在 `document` 目录查找
- 若只给文件基名，自动补全为 `.md`

## 执行步骤

1. 定位 md 文件：优先在 `FPGA_Prj/document/` 下查找
2. 执行转换：

```bash
python3 FPGA_Prj/app/md_convert.py <md文件路径> html
```

## 失败处理

- 文件不存在：明确提示并回显搜索路径
- 转换失败：回显错误信息
