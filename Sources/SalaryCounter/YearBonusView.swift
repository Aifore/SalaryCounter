import SwiftUI

private enum PiggyMetrics {
    static let width: CGFloat = 96
    static let height: CGFloat = 72
    static let inset: CGFloat = 2
    static let lineWidth: CGFloat = 1.5
}

private enum PiggyPalette {
    /// 还没存到的部分：浅粉
    static let track = Color(red: 0.984, green: 0.890, blue: 0.910)
    /// 已存到的部分：上浅下深的粉色渐变
    static let fill = LinearGradient(
        colors: [Color(red: 0.976, green: 0.639, blue: 0.706), Color(red: 0.918, green: 0.435, blue: 0.537)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let ink = Color(red: 0.541, green: 0.227, blue: 0.298)
    static let blush = Color(red: 0.851, green: 0.310, blue: 0.447).opacity(0.4)
    static let coin = Color(red: 0.961, green: 0.773, blue: 0.259)
    static let coinEdge = Color(red: 0.722, green: 0.525, blue: 0.043)
}

/// 设计坐标系 100 x 74（左边是猪鼻子），映射到实际绘制区域。
private struct PigCanvas {
    let rect: CGRect

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width / 100, y: rect.minY + y * rect.height / 74)
    }

    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(origin: p(x, y), size: CGSize(width: w * rect.width / 100, height: h * rect.height / 74))
    }

    func size(_ w: CGFloat, _ h: CGFloat) -> CGSize {
        CGSize(width: w * rect.width / 100, height: h * rect.height / 74)
    }
}

/// 小猪的各个部位。按 allCases 的顺序从后往前画，后画的盖住先画的。
private enum PigPart: CaseIterable {
    case farBackLeg, farFrontLeg, nearBackLeg, nearFrontLeg, body, ear, snout

    var isFar: Bool { self == .farBackLeg || self == .farFrontLeg }
}

private struct PigPartShape: Shape {
    let part: PigPart

    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        switch part {
        case .farBackLeg: addLeg(to: &path, c, x: 76, bottom: 70)
        case .farFrontLeg: addLeg(to: &path, c, x: 40, bottom: 70)
        case .nearBackLeg: addLeg(to: &path, c, x: 66, bottom: 71)
        case .nearFrontLeg: addLeg(to: &path, c, x: 30, bottom: 71)
        case .body:
            // 一条连续的蛋形轮廓，前低后高
            path.move(to: c.p(22, 40))
            path.addCurve(to: c.p(58, 14), control1: c.p(22, 22), control2: c.p(38, 14))
            path.addCurve(to: c.p(93, 41), control1: c.p(80, 14), control2: c.p(93, 26))
            path.addCurve(to: c.p(58, 63), control1: c.p(93, 56), control2: c.p(80, 63))
            path.addCurve(to: c.p(22, 40), control1: c.p(36, 63), control2: c.p(22, 57))
            path.closeSubpath()
        case .ear:
            path.move(to: c.p(32, 22))
            path.addCurve(to: c.p(39, 7), control1: c.p(29, 14), control2: c.p(33, 7))
            path.addCurve(to: c.p(46, 19), control1: c.p(44, 8), control2: c.p(47, 13))
            path.closeSubpath()
        case .snout:
            path.move(to: c.p(12, 34))
            path.addCurve(to: c.p(17, 30), control1: c.p(12, 31), control2: c.p(14, 30))
            path.addLine(to: c.p(22, 30))
            path.addCurve(to: c.p(28, 39), control1: c.p(26, 30), control2: c.p(28, 34))
            path.addCurve(to: c.p(22, 48), control1: c.p(28, 44), control2: c.p(26, 48))
            path.addLine(to: c.p(17, 48))
            path.addCurve(to: c.p(12, 44), control1: c.p(14, 48), control2: c.p(12, 47))
            path.closeSubpath()
        }
        return path
    }

    /// 圆头小短腿，上端藏在身体后面
    private func addLeg(to path: inout Path, _ c: PigCanvas, x: CGFloat, bottom: CGFloat) {
        path.move(to: c.p(x, 56))
        path.addLine(to: c.p(x, bottom - 4))
        path.addQuadCurve(to: c.p(x + 4, bottom), control: c.p(x, bottom))
        path.addLine(to: c.p(x + 7, bottom))
        path.addQuadCurve(to: c.p(x + 11, bottom - 4), control: c.p(x + 11, bottom))
        path.addLine(to: c.p(x + 11, 56))
        path.closeSubpath()
    }
}

/// 卷卷的小尾巴，只描边
private struct PigTail: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(92.5, 37))
        path.addCurve(to: c.p(96, 29), control1: c.p(98, 36), control2: c.p(99.5, 30))
        path.addCurve(to: c.p(97, 33.5), control1: c.p(93, 28.5), control2: c.p(93, 33))
        return path
    }
}

/// 投币口、眼睛、鼻孔（实心深色）
private struct PigInkMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.addRoundedRect(in: c.box(51, 17, 15, 3.4), cornerSize: c.size(1.7, 1.7))
        path.addEllipse(in: c.box(32.4, 28.4, 5.2, 5.2))
        path.addEllipse(in: c.box(16.2, 36.9, 2.6, 4.2))
        path.addEllipse(in: c.box(21.2, 36.9, 2.6, 4.2))
        return path
    }
}

private struct PigEyeHighlight: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).box(35.1, 29.3, 1.6, 1.6))
    }
}

private struct PigBlush: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).box(32, 41.6, 8, 4.8))
    }
}

/// 投币口上方的金币
private struct PigCoin: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: PigCanvas(rect: rect).box(53.3, 1.8, 10.4, 10.4))
    }
}

private struct PigCoinMark: Shape {
    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        var path = Path()
        path.move(to: c.p(58.5, 4.3))
        path.addLine(to: c.p(58.5, 9.7))
        return path
    }
}

/// 从底部到“水位线”的区域，用来遮罩填充色。
/// 0% 时在脚底（y=71），100% 时漫过耳朵尖（y=6）。
private struct PigFillLevel: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = PigCanvas(rect: rect)
        let y = c.p(0, 71 - 65 * CGFloat(progress)).y
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
                ZStack {
                    shape.fill(PiggyPalette.track)
                    shape.fill(PiggyPalette.fill)
                        .opacity(part.isFar ? 0.8 : 1)
                        .mask { PigFillLevel(progress: level) }
                    shape.stroke(PiggyPalette.ink, style: stroke)
                }
            }
            PigTail().stroke(PiggyPalette.ink, style: stroke)
            PigBlush().fill(PiggyPalette.blush)
            PigInkMarks().fill(PiggyPalette.ink)
            PigEyeHighlight().fill(Color.white)
            if filled {
                PigCoin().fill(PiggyPalette.coin)
                PigCoin().stroke(PiggyPalette.coinEdge, lineWidth: 1.1)
                PigCoinMark().stroke(PiggyPalette.coinEdge, style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
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
