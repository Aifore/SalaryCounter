import SwiftUI

private enum PiggyMetrics {
    static let width: CGFloat = 96
    static let height: CGFloat = 72
    static let inset: CGFloat = 2
}

private enum PiggyPalette {
    static let body = Color(red: 0.93, green: 0.45, blue: 0.52)
    static let track = Color(red: 0.93, green: 0.45, blue: 0.52).opacity(0.20)
    static let ink = Color(red: 0.42, green: 0.16, blue: 0.22)
}

/// 侧视存钱罐：身体、头、鼻、耳、脚和尾巴连成一个固定轮廓。
private struct PiggyBankShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: box(24, 8, 16, 18, in: rect))
        path.addEllipse(in: box(12, 22, 34, 30, in: rect))
        path.addEllipse(in: box(2, 34, 16, 14, in: rect))
        path.addEllipse(in: box(26, 16, 62, 46, in: rect))
        path.addEllipse(in: box(82, 24, 16, 14, in: rect))
        path.addRoundedRect(
            in: box(40, 52, 14, 18, in: rect),
            cornerSize: scaled(6, 6, in: rect)
        )
        path.addRoundedRect(
            in: box(68, 52, 14, 18, in: rect),
            cornerSize: scaled(6, 6, in: rect)
        )
        return path
    }
}

/// 眼睛、鼻孔和投币口。画在填充上面，轮廓不随进度改变。
private struct PiggyBankMarks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: box(22, 32, 5, 5, in: rect))
        path.addEllipse(in: box(6, 38, 2.4, 3, in: rect))
        path.addEllipse(in: box(10.5, 38, 2.4, 3, in: rect))
        path.addRoundedRect(
            in: box(48, 20, 20, 3.2, in: rect),
            cornerSize: scaled(1.6, 1.6, in: rect)
        )
        return path
    }
}

private func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, in rect: CGRect) -> CGRect {
    let sx = rect.width / 100
    let sy = rect.height / 74
    return CGRect(x: rect.minX + x * sx, y: rect.minY + y * sy, width: width * sx, height: height * sy)
}

private func scaled(_ width: CGFloat, _ height: CGFloat, in rect: CGRect) -> CGSize {
    CGSize(width: width * rect.width / 100, height: height * rect.height / 74)
}

struct PiggyBankFigure: View {
    var progress: Double
    var filled: Bool

    var body: some View {
        let fraction = progress.isFinite ? min(max(progress, 0), 1) : 0
        let innerHeight = PiggyMetrics.height - PiggyMetrics.inset * 2
        let fillHeight = filled ? innerHeight * CGFloat(fraction) : 0
        let emptyHeight = innerHeight - fillHeight
        let stroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)

        ZStack {
            PiggyBankShape()
                .fill(PiggyPalette.track)
            PiggyBankShape()
                .fill(PiggyPalette.body)
                .mask {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: emptyHeight)
                        Rectangle().frame(height: fillHeight)
                    }
                }
            PiggyBankShape()
                .stroke(PiggyPalette.ink, style: stroke)
            PiggyBankMarks()
                .stroke(PiggyPalette.ink, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
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
