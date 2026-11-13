import SwiftUI

private enum PiggyMetrics {
    static let width: CGFloat = 96
    static let height: CGFloat = 72
    static let inset: CGFloat = 2
    /// 卡通风格的粗描边
    static let lineWidth: CGFloat = 2.1
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r, green: g, blue: b)
}

/// 一个部位的配色：还没存到时的浅色底 + 存到后的渐变色
private struct PigFillStyle {
    let track: Color
    let fill: LinearGradient
    let fillOpacity: Double

    static let body = PigFillStyle(
        track: rgb(0.988, 0.894, 0.918),
        fill: LinearGradient(colors: [rgb(1, 0.702, 0.765), rgb(0.949, 0.490, 0.596)], startPoint: .top, endPoint: .bottom),
        fillOpacity: 1
    )
    /// 后面的两条腿稍暗，显出前后层次
    static let far = PigFillStyle(
        track: rgb(0.965, 0.827, 0.859),
        fill: PigFillStyle.body.fill,
        fillOpacity: 0.75
    )
    /// 猪鼻子比身体深一号，一眼就能看出来
    static let snout = PigFillStyle(
        track: rgb(0.976, 0.776, 0.824),
        fill: LinearGradient(colors: [rgb(1, 0.592, 0.682), rgb(0.910, 0.376, 0.498)], startPoint: .top, endPoint: .bottom),
        fillOpacity: 1
    )
}

private enum PiggyPalette {
    static let ink = rgb(0.478, 0.180, 0.251)
    static let innerEar = rgb(0.851, 0.290, 0.439).opacity(0.45)
    static let blush = rgb(0.886, 0.282, 0.435).opacity(0.38)
    static let coin = rgb(1, 0.824, 0.290)
    static let coinEdge = rgb(0.757, 0.541, 0.071)
}

/// 设计坐标系 100 x 74（猪鼻子朝左），映射到实际绘制区域。
private struct PigCanvas {
    let rect: CGRect

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width / 100, y: rect.minY + y * rect.height / 74)
    }

    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(origin: p(x, y), size: size(w, h))
    }

    func size(_ w: CGFloat, _ h: CGFloat) -> CGSize {
        CGSize(width: w * rect.width / 100, height: h * rect.height / 74)
    }
}

/// 小猪的各个部位。按 allCases 的顺序从后往前画，后画的盖住先画的。
private enum PigPart: CaseIterable {
    case farEar, farBackLeg, farFrontLeg, body, nearFrontLeg, nearBackLeg, nearEar, snout

    var style: PigFillStyle {
        switch self {
        case .farBackLeg, .farFrontLeg: return .far
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
        case .farEar:
            path.move(to: c.p(41, 19))
            path.addCurve(to: c.p(49, 5.5), control1: c.p(41, 12), control2: c.p(44, 6.5))
            path.addCurve(to: c.p(51, 20), control1: c.p(52, 9.5), control2: c.p(52, 15))
            path.closeSubpath()
        case .farFrontLeg: addLeg(to: &path, c, x: 44, top: 58, bottom: 66, width: 10, round: 4.5)
        case .farBackLeg: addLeg(to: &path, c, x: 78, top: 56, bottom: 64.5, width: 10, round: 4.5)
        case .body:
            // 圆滚滚的一整条轮廓
            path.move(to: c.p(18, 40))
            path.addCurve(to: c.p(54, 12), control1: c.p(18, 21), control2: c.p(34, 12))
            path.addCurve(to: c.p(92, 40), control1: c.p(76, 12), control2: c.p(92, 24))
            path.addCurve(to: c.p(54, 65), control1: c.p(92, 56), control2: c.p(76, 65))
            path.addCurve(to: c.p(18, 40), control1: c.p(33, 65), control2: c.p(18, 58))
            path.closeSubpath()
        case .nearFrontLeg: addLeg(to: &path, c, x: 29, top: 58, bottom: 67, width: 11, round: 5)
        case .nearBackLeg: addLeg(to: &path, c, x: 63, top: 58, bottom: 67, width: 11, round: 5)
        case .nearEar:
            path.move(to: c.p(28, 22))
            path.addCurve(to: c.p(36, 4), control1: c.p(26, 13), control2: c.p(29, 6))
            path.addCurve(to: c.p(41, 21), control1: c.p(41, 9), control2: c.p(43, 15))
            path.closeSubpath()
        case .snout:
            // 椭圆形猪鼻子，一半贴在脸上
            path.addEllipse(in: c.box(11, 32.5, 18, 15))
        }
        return path
    }

    /// 圆头小短腿，上端藏在身体后面
    private func addLeg(to path: inout Path, _ c: PigCanvas, x: CGFloat, top: CGFloat, bottom: CGFloat, width: CGFloat, round: CGFloat) {
        path.move(to: c.p(x, top))
        path.addLine(to: c.p(x, bottom))
        path.addCurve(to: c.p(x + width, bottom), control1: c.p(x, bottom + round), control2: c.p(x + width, bottom + round))
        path.addLine(to: c.p(x + width, top))
        path.closeSubpath()
    }
}

/// 耳朵内侧
private struct PigInnerEar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(31, 19))
        path.addCurve(to: c.p(35.5, 7.5), control1: c.p(30, 13), control2: c.p(32, 9))
        path.addCurve(to: c.p(38, 19), control1: c.p(38, 11), control2: c.p(39, 15))
        path.closeSubpath()
        return path
    }
}

/// 卷卷的小尾巴
private struct PigTail: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(91.5, 36))
        path.addCurve(to: c.p(96, 27), control1: c.p(98, 35), control2: c.p(100, 28))
        path.addCurve(to: c.p(97.5, 32), control1: c.p(92.5, 26.5), control2: c.p(92.5, 32))
        return path
    }
}

/// 背上的一道反光
private struct PigShine: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(70, 18.5))
        path.addCurve(to: c.p(86.5, 31), control1: c.p(78, 20), control2: c.p(84, 25))
        return path
    }
}

/// 投币口、鼻孔、两只大眼睛（实心深色）
private struct PigInkMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addRoundedRect(in: c.box(54, 15.5, 15, 3.6), cornerSize: c.size(1.8, 1.8))
        path.addEllipse(in: c.box(15.2, 37.4, 3.2, 5.2))
        path.addEllipse(in: c.box(21.6, 37.4, 3.2, 5.2))
        for x in [31.0, 43.0] as [CGFloat] {
            path.addEllipse(in: c.box(x - 2.9, 26.2, 5.8, 7.6))
        }
        return path
    }
}

/// 眼睛里一大一小两个高光
private struct PigEyeHighlights: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        for x in [31.0, 43.0] as [CGFloat] {
            path.addEllipse(in: c.box(x - 0.25, 27.35, 2.5, 2.5))
            path.addEllipse(in: c.box(x - 1.45, 31.05, 1.1, 1.1))
        }
        return path
    }
}

private struct PigBlush: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).box(33.8, 43.1, 8.4, 4.8))
    }
}

private struct PigSmile: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(29.5, 49.5))
        path.addQuadCurve(to: c.p(35.5, 49.5), control: c.p(32.5, 52.5))
        return path
    }
}

/// 投币口上方的金币
private struct PigCoin: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).box(56.1, 1.1, 10.8, 10.8))
    }
}

private struct PigCoinMark: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(61.5, 3.8))
        path.addLine(to: c.p(61.5, 9.2))
        return path
    }
}

/// 从底部到“水位线”的区域，用来遮罩填充色。
/// 0% 时在脚底（y=71），100% 时漫过耳朵尖（y=4）。
private struct PigFillLevel: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        let y = c.p(0, 71 - 67 * CGFloat(progress)).y
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
            ForEach(PigPart.allCases, id: \.self) { part in
                let shape = PigPartShape(part: part)
                let style = part.style
                ZStack {
                    shape.fill(style.track)
                    shape.fill(style.fill)
                        .opacity(style.fillOpacity)
                        .mask { PigFillLevel(progress: level) }
                    shape.stroke(PiggyPalette.ink, style: stroke)
                }
            }
            PigInnerEar().fill(PiggyPalette.innerEar)
            PigTail().stroke(PiggyPalette.ink, style: stroke)
            PigShine().stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            PigBlush().fill(PiggyPalette.blush)
            PigInkMarks().fill(PiggyPalette.ink)
            PigEyeHighlights().fill(Color.white)
            PigSmile().stroke(PiggyPalette.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            if filled {
                PigCoin().fill(PiggyPalette.coin)
                PigCoin().stroke(PiggyPalette.coinEdge, lineWidth: 1.3)
                PigCoinMark().stroke(PiggyPalette.coinEdge, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
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
