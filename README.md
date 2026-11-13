# 工资计数器 SalaryCounter

一个 macOS 菜单栏小工具：填入月薪和上下班时间，一到上班时间，菜单栏上的数字就开始实时上涨。

- **菜单栏**：只显示一个数字，比如 `¥312.48`，每 0.1 秒刷新
- **点击数字**：弹出面板
  - 概览：今日已赚、今日进度、距下班倒计时、本月已赚、日薪/时薪/每秒，以及年终存钱罐
  - 设置：月薪、年终奖月数、计薪天数、工作日、上下班时间、午休、货币符号、小数位、开机启动
- **桌面窗口**：毛玻璃小窗，可拖动、可置顶、所有桌面空间都显示；鼠标移上去右上角有关闭按钮，右键有更多选项

## 计算方式

```
日薪     = 月薪 ÷ 每月计薪天数（默认 21.75）
每秒工资 = 日薪 ÷ 每天实际工作秒数（上下班之间，扣除午休）
今日已赚 = 今天已工作秒数 × 每秒工资       （非工作日为 0，下班后停在日薪）
本月已赚 = 本月今天之前的工作日数 × 日薪 + 今日已赚
年终目标 = 月薪 × 年终奖月数（0 表示不设置，可以是小数）
预估已存 = 年终目标 × 今年已经过的比例
```

年终奖只出现在概览的「年终存钱罐」里。进度是本地日历年从 1 月 1 日 0 点到下一年 1 月 1 日 0 点已经过的时间，和出勤无关，跨年自动从 0 开始，闰年按 366 天计算。它不加进今日已赚、本月已赚、日薪、时薪、每秒，也不进菜单栏和桌面窗口。

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

> 只装 Command Line Tools、没有完整 Xcode 也能编译（代码里刻意没用 `@State` 宏）。

> 第一次打开如果提示“无法验证开发者”，在 Finder 里右键 App → 打开，或者到 系统设置 → 隐私与安全性 里点“仍要打开”。

## 用 make 更新并重启

除了上面的编译器，还需要 `git` 和 `make`。三条命令都在仓库根目录执行，并且都调用 `bash build.sh`（不依赖 `build.sh` 的可执行位）：

```bash
make build    # 只编译 build/SalaryCounter.app
make run      # 先编译，成功后再重启本地这份 App
make update   # 快进当前分支，编译成功后再重启
```

`make update` 跟着**当前分支自己的上游**走，不会切到别的分支。发布后的日常使用停在 `main` 上运行；要试功能分支，就先切到那个分支并让它跟踪自己的上游，例如 `git branch -u origin/功能分支`。

它只会做快进（`git pull --no-rebase --ff-only`）。不会合并、变基、暂存、提交、推送，也不会改写本地提交。下面这些情况会直接停下来，并说明原因：

- 工作区有未提交的改动（包括已暂存和未忽略的新文件）。`build/` 这类已被 git 忽略的生成文件不算改动，不会挡更新。
- 当前是游离 HEAD，或者当前分支没有上游。
- 本地和上游已经分叉，或上游拉不下来。
- 编译失败。这时**不会退出正在运行的 SalaryCounter**，原来的程序继续留着。

编译成功之后，才会退出正在运行的 `SalaryCounter.app`（不管它是不是 `/Applications` 里的那一份），然后用刚编译出来的 `build/SalaryCounter.app` 打开一份。它按程序路径识别进程，不会按名字大范围结束进程。如果系统仍然按 bundle id 打开了「应用程序」文件夹里的旧副本，命令会失败并退出那个旧副本，避免更新看起来成功、实际跑的却是旧包。

## 文件结构

```
Package.swift
Makefile                      # make build / run / update
Resources/Info.plist          # LSUIElement=true：不在 Dock 显示
Sources/SalaryCounter/
  SalaryCounterApp.swift      # 入口，MenuBarExtra 菜单栏数字
  Model.swift                 # 设置存储、计时器、工资计算、格式化
  YearBonus.swift             # 年终奖月数、全年进度、预估金额
  YearBonusView.swift         # 年终存钱罐：一笔画小猪，粉色从脚底往上涨到耳朵尖
  MenuContentView.swift       # 弹出面板：概览 + 设置
  DesktopWindow.swift         # 桌面悬浮窗
scripts/update.sh             # 快进当前分支并在编译成功后重启
scripts/restart-app.sh        # 只重启本地 build 出来的 App
build.sh                      # 打包成 .app
```
