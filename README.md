# 工资计数器 SalaryCounter

一个 macOS 菜单栏小工具：填入月薪和上下班时间，一到上班时间，菜单栏上的数字就开始实时上涨。

- **菜单栏**：只显示一个数字，比如 `¥312.48`，每 0.1 秒刷新
- **点击数字**：弹出面板
  - 概览：今日已赚、今日进度、距下班倒计时、本月已赚、日薪/时薪/每秒
  - 设置：月薪、计薪天数、工作日、上下班时间、午休、货币符号、小数位、开机启动
- **桌面窗口**：毛玻璃小窗，可拖动、可置顶、所有桌面空间都显示；鼠标移上去右上角有关闭按钮，右键有更多选项

## 计算方式

```
日薪     = 月薪 ÷ 每月计薪天数（默认 21.75）
每秒工资 = 日薪 ÷ 每天实际工作秒数（上下班之间，扣除午休）
今日已赚 = 今天已工作秒数 × 每秒工资       （非工作日为 0，下班后停在日薪）
本月已赚 = 本月今天之前的工作日数 × 日薪 + 今日已赚
```

## 构建与运行

需要 macOS 13 (Ventura) 或更新版本，并安装 Xcode 或 Command Line Tools（`xcode-select --install`）。

```bash
./build.sh
```

```bash
open build/SalaryCounter.app
```

想长期使用，就把它复制到“应用程序”里，再到设置里打开“开机自动启动”：

```bash
cp -R build/SalaryCounter.app /Applications/
```

开发调试也可以直接 `swift run`，或者 `open Package.swift` 用 Xcode 打开。

> 第一次打开如果提示“无法验证开发者”，在 Finder 里右键 App → 打开，或者到 系统设置 → 隐私与安全性 里点“仍要打开”。

## 文件结构

```
Package.swift
Resources/Info.plist          # LSUIElement=true：不在 Dock 显示
Sources/SalaryCounter/
  SalaryCounterApp.swift      # 入口，MenuBarExtra 菜单栏数字
  Model.swift                 # 设置存储、计时器、工资计算、格式化
  MenuContentView.swift       # 弹出面板：概览 + 设置
  DesktopWindow.swift         # 桌面悬浮窗
build.sh                      # 打包成 .app
```
