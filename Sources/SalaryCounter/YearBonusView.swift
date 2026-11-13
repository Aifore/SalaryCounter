import SwiftUI

private enum PiggyMetrics {
    /// 设计坐标系是 100 x 84，这里按同样的比例显示
    static let width: CGFloat = 86
    static let height: CGFloat = 72
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r, green: g, blue: b)
}

/// 一个部位的配色：还没存到时的浅色底 + 存到后的渐变色
private struct PigFillStyle {
    let track: Color
    let fill: LinearGradient

    init(track: Color, top: Color, bottom: Color) {
        self.track = track
        self.fill = LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    static let body = PigFillStyle(
        track: rgb(0.992, 0.914, 0.933),
        top: rgb(1, 0.800, 0.831),
        bottom: rgb(0.984, 0.671, 0.733)
    )
    /// 小脚比身体深一点
    static let foot = PigFillStyle(
        track: rgb(0.980, 0.851, 0.882),
        top: rgb(1, 0.698, 0.769),
        bottom: rgb(0.976, 0.498, 0.616)
    )
    /// 猪鼻子再深一点，在脸上一眼能看出来
    static let snout = PigFillStyle(
        track: rgb(0.984, 0.827, 0.867),
        top: rgb(1, 0.639, 0.725),
        bottom: rgb(0.969, 0.463, 0.604)
    )
}

private enum PiggyPalette {
    static let line = rgb(0.831, 0.286, 0.435)
    static let ink = rgb(0.357, 0.137, 0.200)
    static let blush = rgb(1, 0.361, 0.541).opacity(0.35)
    static let coin = rgb(1, 0.831, 0.369)
}

/// 设计坐标系 100 x 84（正面小猪，左右对称），映射到实际绘制区域。
private struct PigCanvas {
    let rect: CGRect

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width / 100, y: rect.minY + y * rect.height / 84)
    }

    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(origin: p(x, y), size: size(w, h))
    }

    func size(_ w: CGFloat, _ h: CGFloat) -> CGSize {
        CGSize(width: w * rect.width / 100, height: h * rect.height / 84)
    }

    /// 以 (cx, cy) 为圆心的椭圆
    func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
        box(cx - rx, cy - ry, rx * 2, ry * 2)
    }
}

private enum PigPart {
    case leftEar, rightEar, leftFoot, rightFoot, body, snout

    var style: PigFillStyle {
        switch self {
        case .leftFoot, .rightFoot: return .foot
        case .snout: return .snout
        default: return .body
        }
    }
}

private struct PigPartShape: Shape {
    let part: PigPart

    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        switch part {
        case .leftEar:
            path.move(to: c.p(22, 38))
            path.addCurve(to: c.p(21, 18), control1: c.p(16, 28), control2: c.p(15, 16))
            path.addCurve(to: c.p(39, 30), control1: c.p(28, 17), control2: c.p(35, 22))
            path.closeSubpath()
        case .rightEar:
            path.move(to: c.p(78, 38))
            path.addCurve(to: c.p(79, 18), control1: c.p(84, 28), control2: c.p(85, 16))
            path.addCurve(to: c.p(61, 30), control1: c.p(72, 17), control2: c.p(65, 22))
            path.closeSubpath()
        case .leftFoot: addFoot(to: &path, c, x: 27)
        case .rightFoot: addFoot(to: &path, c, x: 58)
        case .body:
            path.addEllipse(in: c.oval(50, 50, 37, 29))
        case .snout:
            path.addEllipse(in: c.oval(50, 56, 13, 9))
        }
        return path
    }

    /// 圆圆的小脚，上半截藏在身体后面
    private func addFoot(to path: inout Path, _ c: PigCanvas, x: CGFloat) {
        path.move(to: c.p(x, 68))
        path.addLine(to: c.p(x, 76.5))
        path.addCurve(to: c.p(x + 15, 76.5), control1: c.p(x, 83.5), control2: c.p(x + 15, 83.5))
        path.addLine(to: c.p(x + 15, 68))
        path.closeSubpath()
    }
}

/// 投币口和两个鼻孔（玫红色）
private struct PigLineMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addRoundedRect(in: c.box(42, 28, 16, 3), cornerSize: c.size(1.8, 1.8))
        path.addEllipse(in: c.oval(45.5, 56, 1.6, 2.2))
        path.addEllipse(in: c.oval(54.5, 56, 1.6, 2.2))
        return path
    }
}

private struct PigEyes: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addEllipse(in: c.oval(33, 45, 2.3, 2.8))
        path.addEllipse(in: c.oval(67, 45, 2.3, 2.8))
        return path
    }
}

private struct PigBlush: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addEllipse(in: c.oval(25.5, 54, 4.5, 2.5))
        path.addEllipse(in: c.oval(74.5, 54, 4.5, 2.5))
        return path
    }
}

private struct PigCoin: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).oval(50, 10, 6, 6))
    }
}

/// 从底部到“水位线”的区域，用来遮罩填充色。
/// 0% 时在脚底（y=82），100% 时漫过耳朵尖（y=17）。
private struct PigFillLevel: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        let y = c.p(0, 82 - 65 * CGFloat(progress)).y
        return Path(CGRect(x: rect.minX, y: y, width: rect.width, height: rect.maxY - y))
    }
}

private struct PigPartLayer: View {
    let part: PigPart
    let level: Double

    var body: some View {
        let shape = PigPartShape(part: part)
        let style = part.style
        ZStack {
            shape.fill(style.track)
            shape.fill(style.fill)
                .mask { PigFillLevel(progress: level) }
        }
    }
}

struct PiggyBankFigure: View {
    var progress: Double
    var filled: Bool

    var body: some View {
        let fraction = progress.isFinite ? min(max(progress, 0), 1) : 0
        let level = filled ? fraction : 0

        ZStack {
            PigPartLayer(part: .leftEar, level: level)
            PigPartLayer(part: .rightEar, level: level)
            PigPartLayer(part: .leftFoot, level: level)
            PigPartLayer(part: .rightFoot, level: level)
            PigPartLayer(part: .body, level: level)
            PigBlush().fill(PiggyPalette.blush)
            PigPartLayer(part: .snout, level: level)
            PigLineMarks().fill(PiggyPalette.line)
            PigEyes().fill(PiggyPalette.ink)
            if filled {
                PigCoin().fill(PiggyPalette.coin)
            }
        }
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
