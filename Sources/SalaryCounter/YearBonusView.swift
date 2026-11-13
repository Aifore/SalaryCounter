import SwiftUI

private enum PiggyMetrics {
    /// 设计坐标系是 100 x 84，这里按同样的比例显示
    static let width: CGFloat = 86
    static let height: CGFloat = 72
    static let lineWidth: CGFloat = 2
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
        top: rgb(1, 0.769, 0.824),
        bottom: rgb(1, 0.573, 0.678)
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
    /// 轮廓、投币口、鼻孔：玫红色
    static let line = rgb(0.831, 0.286, 0.435)
    /// 眼睛和嘴：深梅色
    static let ink = rgb(0.357, 0.137, 0.200)
    static let innerEar = rgb(0.831, 0.286, 0.435).opacity(0.35)
    static let blush = rgb(1, 0.361, 0.541).opacity(0.35)
    static let coin = rgb(1, 0.831, 0.369)
    static let coinEdge = rgb(0.898, 0.659, 0.137)
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
            path.move(to: c.p(19, 38))
            path.addCurve(to: c.p(18, 18.5), control1: c.p(14, 31), control2: c.p(14, 23))
            path.addCurve(to: c.p(37, 26), control1: c.p(25, 17), control2: c.p(32, 20))
            path.closeSubpath()
        case .rightEar:
            path.move(to: c.p(81, 38))
            path.addCurve(to: c.p(82, 18.5), control1: c.p(86, 31), control2: c.p(86, 23))
            path.addCurve(to: c.p(63, 26), control1: c.p(75, 17), control2: c.p(68, 20))
            path.closeSubpath()
        case .leftFoot: addFoot(to: &path, c, x: 27)
        case .rightFoot: addFoot(to: &path, c, x: 58)
        case .body:
            // 胖乎乎的圆身体，比椭圆更方一点
            path.move(to: c.p(12, 50))
            path.addCurve(to: c.p(50, 22), control1: c.p(12, 32), control2: c.p(28, 22))
            path.addCurve(to: c.p(88, 50), control1: c.p(72, 22), control2: c.p(88, 32))
            path.addCurve(to: c.p(50, 78), control1: c.p(88, 68), control2: c.p(72, 78))
            path.addCurve(to: c.p(12, 50), control1: c.p(28, 78), control2: c.p(12, 68))
            path.closeSubpath()
        case .snout:
            path.move(to: c.p(38.5, 53))
            path.addCurve(to: c.p(50, 44.5), control1: c.p(38.5, 47.5), control2: c.p(43, 44.5))
            path.addCurve(to: c.p(61.5, 53), control1: c.p(57, 44.5), control2: c.p(61.5, 47.5))
            path.addCurve(to: c.p(50, 61.5), control1: c.p(61.5, 58.5), control2: c.p(57, 61.5))
            path.addCurve(to: c.p(38.5, 53), control1: c.p(43, 61.5), control2: c.p(38.5, 58.5))
            path.closeSubpath()
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

/// 两只耳朵的内侧
private struct PigInnerEars: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(21.5, 33))
        path.addCurve(to: c.p(20.5, 22), control1: c.p(19, 28.5), control2: c.p(19, 24.5))
        path.addCurve(to: c.p(31, 26.5), control1: c.p(24.5, 21.5), control2: c.p(28, 23))
        path.closeSubpath()
        path.move(to: c.p(78.5, 33))
        path.addCurve(to: c.p(79.5, 22), control1: c.p(81, 28.5), control2: c.p(81, 24.5))
        path.addCurve(to: c.p(69, 26.5), control1: c.p(75.5, 21.5), control2: c.p(72, 23))
        path.closeSubpath()
        return path
    }
}

/// 投币口和两个鼻孔（玫红色）
private struct PigLineMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addRoundedRect(in: c.box(41, 27.5, 18, 3.6), cornerSize: c.size(1.8, 1.8))
        path.addEllipse(in: c.oval(45.8, 53, 1.8, 2.7))
        path.addEllipse(in: c.oval(54.2, 53, 1.8, 2.7))
        return path
    }
}

private struct PigEyes: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addEllipse(in: c.oval(32, 44, 3.3, 3.3))
        path.addEllipse(in: c.oval(68, 44, 3.3, 3.3))
        return path
    }
}

private struct PigEyeHighlights: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addEllipse(in: c.oval(33.1, 42.8, 1.1, 1.1))
        path.addEllipse(in: c.oval(69.1, 42.8, 1.1, 1.1))
        return path
    }
}

private struct PigBlush: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addEllipse(in: c.oval(24.5, 54, 5, 3))
        path.addEllipse(in: c.oval(75.5, 54, 5, 3))
        return path
    }
}

private struct PigSmile: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(46.5, 66.5))
        path.addQuadCurve(to: c.p(53.5, 66.5), control: c.p(50, 69.3))
        return path
    }
}

/// 投币口上方的金币；radius 换成小一点的值就是金币上的内圈
private struct PigCoin: Shape {
    var radius: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).oval(50, 10, radius, radius))
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

/// 一个部位：浅色底 + 涨到水位线的填充 + 轮廓
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
            shape.stroke(
                PiggyPalette.line,
                style: StrokeStyle(lineWidth: PiggyMetrics.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

struct PiggyBankFigure: View {
    var progress: Double
    var filled: Bool

    var body: some View {
        let fraction = progress.isFinite ? min(max(progress, 0), 1) : 0
        let level = filled ? fraction : 0

        // 从后往前画：耳朵和脚在身体后面，身体盖住它们的根部，所以看到的只有一圈外轮廓
        ZStack {
            PigPartLayer(part: .leftEar, level: level)
            PigPartLayer(part: .rightEar, level: level)
            PigInnerEars().fill(PiggyPalette.innerEar)
            PigPartLayer(part: .leftFoot, level: level)
            PigPartLayer(part: .rightFoot, level: level)
            PigPartLayer(part: .body, level: level)
            PigBlush().fill(PiggyPalette.blush)
            PigPartLayer(part: .snout, level: level)
            PigLineMarks().fill(PiggyPalette.line)
            PigEyes().fill(PiggyPalette.ink)
            PigEyeHighlights().fill(Color.white)
            PigSmile().stroke(PiggyPalette.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            if filled {
                PigCoin().fill(PiggyPalette.coin)
                PigCoin().stroke(PiggyPalette.coinEdge, lineWidth: 1.5)
                PigCoin(radius: 3.6).stroke(PiggyPalette.coinEdge.opacity(0.7), lineWidth: 1.1)
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
