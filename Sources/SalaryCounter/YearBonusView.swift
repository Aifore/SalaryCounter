import SwiftUI

private enum PiggyMetrics {
    static let width: CGFloat = 96
    static let height: CGFloat = 72
    static let inset: CGFloat = 2
    /// 简笔画的粗线条
    static let lineWidth: CGFloat = 2.2
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r, green: g, blue: b)
}

private enum PiggyPalette {
    static let ink = rgb(0.478, 0.180, 0.251)
    /// 还没存到的部分：浅粉
    static let track = rgb(0.988, 0.894, 0.918)
    /// 已存到的部分：上浅下深的粉色渐变
    static let fill = LinearGradient(
        colors: [rgb(1, 0.702, 0.765), rgb(0.949, 0.490, 0.596)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let blush = rgb(0.886, 0.282, 0.435).opacity(0.35)
    static let coin = rgb(1, 0.824, 0.290)
}

/// 设计坐标系 100 x 74（猪鼻子朝左），映射到实际绘制区域。
private struct PigCanvas {
    let rect: CGRect

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width / 100, y: rect.minY + y * rect.height / 74)
    }

    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(origin: p(x, y), size: CGSize(width: w * rect.width / 100, height: h * rect.height / 74))
    }
}

/// 一笔画的小猪轮廓：猪鼻子 → 下巴 → 前腿 → 肚子 → 后腿 → 屁股 → 后背 → 耳朵 → 额头，回到鼻子。
private struct PigOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(13, 32))
        // 猪鼻子
        path.addCurve(to: c.p(13, 46), control1: c.p(11, 36), control2: c.p(11, 42))
        path.addCurve(to: c.p(22, 47), control1: c.p(16, 48), control2: c.p(20, 48))
        // 下巴到前腿
        path.addCurve(to: c.p(26, 58), control1: c.p(22, 52), control2: c.p(24, 56))
        path.addLine(to: c.p(26, 66))
        path.addCurve(to: c.p(33, 66), control1: c.p(26, 69), control2: c.p(33, 69))
        path.addLine(to: c.p(33, 61))
        // 肚子
        path.addCurve(to: c.p(66, 61), control1: c.p(44, 64), control2: c.p(56, 64))
        // 后腿
        path.addLine(to: c.p(66, 66))
        path.addCurve(to: c.p(73, 66), control1: c.p(66, 69), control2: c.p(73, 69))
        path.addLine(to: c.p(73, 58))
        // 屁股和后背
        path.addCurve(to: c.p(89, 37), control1: c.p(84, 54), control2: c.p(90, 46))
        path.addCurve(to: c.p(54, 14), control1: c.p(88, 22), control2: c.p(72, 14))
        path.addCurve(to: c.p(38, 17), control1: c.p(47, 14), control2: c.p(42, 15))
        // 耳朵
        path.addCurve(to: c.p(29, 7), control1: c.p(37, 12), control2: c.p(33, 8))
        path.addCurve(to: c.p(26, 22), control1: c.p(27, 11), control2: c.p(26, 17))
        // 额头回到鼻子
        path.addCurve(to: c.p(13, 32), control1: c.p(21, 24), control2: c.p(16, 28))
        path.closeSubpath()
        return path
    }
}

/// 卷卷的小尾巴，从屁股上接出来
private struct PigTail: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(89.3, 34))
        path.addCurve(to: c.p(94, 26), control1: c.p(95, 33), control2: c.p(97, 27))
        path.addCurve(to: c.p(95.5, 30), control1: c.p(91, 25.5), control2: c.p(91, 30))
        return path
    }
}

/// 鼻孔和投币口：各一短横
private struct PigDashes: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(16, 37.5))
        path.addLine(to: c.p(16, 40.5))
        path.move(to: c.p(51, 20))
        path.addLine(to: c.p(62, 20))
        return path
    }
}

private struct PigEye: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).box(26.7, 26.7, 4.6, 4.6))
    }
}

private struct PigBlush: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).box(30, 37.7, 8, 4.6))
    }
}

/// 投币口上方的金币
private struct PigCoin: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).box(51.7, 1.2, 9.6, 9.6))
    }
}

/// 从底部到“水位线”的区域，用来遮罩填充色。
/// 0% 时在脚底（y=69），100% 时漫过耳朵尖（y=6）。
private struct PigFillLevel: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        let y = c.p(0, 69 - 63 * CGFloat(progress)).y
        return Path(CGRect(x: rect.minX, y: y, width: rect.width, height: rect.maxY - y))
    }
}

struct PiggyBankFigure: View {
    var progress: Double
    var filled: Bool

    var body: some View {
        let fraction = progress.isFinite ? min(max(progress, 0), 1) : 0
        let level = filled ? fraction : 0
        let stroke = StrokeStyle(lineWidth: PiggyMetrics.lineWidth, lineCap: .round, lineJoin: .round)

        ZStack {
            PigOutline().fill(PiggyPalette.track)
            PigOutline().fill(PiggyPalette.fill)
                .mask { PigFillLevel(progress: level) }
            PigBlush().fill(PiggyPalette.blush)
            PigOutline().stroke(PiggyPalette.ink, style: stroke)
            PigTail().stroke(PiggyPalette.ink, style: stroke)
            PigDashes().stroke(PiggyPalette.ink, style: stroke)
            PigEye().fill(PiggyPalette.ink)
            if filled {
                PigCoin().fill(PiggyPalette.coin)
            }
        }
        .padding(PiggyMetrics.inset)
        .frame(width: PiggyMetrics.width, height: PiggyMetrics.height)
        .accessibilityHidden(true)
    }
}

struct YearBonusSection: View {
    let monthlySalary: Double
    let bonusMonths: Double
    let currencySymbol: String
    let decimals: Int
    let now: Date

    private var estimate: YearBonusEstimate {
        YearBonus.estimate(monthlySalary: monthlySalary, bonusMonths: bonusMonths, at: now)
    }

    var body: some View {
        let item = estimate
        HStack(alignment: .center, spacing: 12) {
            PiggyBankFigure(progress: item.progress, filled: item.configured)
            VStack(alignment: .leading, spacing: 3) {
                Text("年终存钱罐")
                    .font(.subheadline.weight(.semibold))
                if item.configured {
                    Text(estimateText(item))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                } else {
                    Text("到「设置」填写年终奖月数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(item))
    }

    private func estimateText(_ item: YearBonusEstimate) -> String {
        let accumulated = Fmt.money(item.accumulated, symbol: currencySymbol, decimals: decimals)
        let target = Fmt.money(item.target, symbol: currencySymbol, decimals: decimals)
        return "预估 \(accumulated) / \(target)"
    }

    private func accessibilityText(_ item: YearBonusEstimate) -> String {
        if item.configured {
            return "年终存钱罐，\(estimateText(item))"
        }
        return "年终存钱罐，到设置填写年终奖月数"
    }
}
