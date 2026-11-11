//
//  ViewsHat.swift
//  10PM Supper Club
//
//  The club's cap, from the merch: a baseball cap, three-quarters on, with "10 PM" over a rule and
//  "SUPPER CLUB" embroidered on the front panel. Drawn in a 100 × 80 box, scaled to `width`.
//  Pure SwiftUI (no UIKit) so it can also be rendered on a Mac for previews.
//

import SwiftUI

struct ClubHat: View {
    var width: CGFloat = 56
    /// The cap's fabric, its outline and stitching, and the embroidery.
    var fabric: Color
    var line: Color
    var thread: Color

    var body: some View {
        let unit = width / 100
        ZStack {
            HatCrown().fill(fabric)
            HatSeam().stroke(line.opacity(0.4), lineWidth: 0.8 * unit)
            HatCrown().stroke(line, lineWidth: 1.4 * unit)
            HatBrim().fill(fabric)
            HatBrim().stroke(line, lineWidth: 1.4 * unit)
            HatBrimStitch().stroke(line.opacity(0.55), style: StrokeStyle(lineWidth: 0.8 * unit, dash: [2.2 * unit, 1.6 * unit]))
            Circle()
                .fill(fabric)
                .stroke(line, lineWidth: 1.2 * unit)
                .frame(width: 6 * unit, height: 6 * unit)
                .position(x: 45 * unit, y: 8.5 * unit)
            VStack(spacing: 1.6 * unit) {
                Text("10 PM")
                    .font(.custom("Baskerville-SemiBold", fixedSize: 14.5 * unit))
                    .kerning(-0.3 * unit)
                    .fixedSize()
                    .padding(.horizontal, 1.5 * unit)
                    .overlay(alignment: .bottom) {
                        Rectangle().frame(height: max(0.5, 1 * unit)).offset(y: 1.6 * unit)
                    }
                Text("SUPPER CLUB")
                    .font(.custom("Baskerville-SemiBold", fixedSize: 4.9 * unit))
                    .kerning(1.05 * unit)
                    .fixedSize()
                    .padding(.top, 1.2 * unit)
            }
            .foregroundStyle(thread)
            .position(x: 51 * unit, y: 38 * unit)
        }
        .frame(width: width, height: 80 * unit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("10 PM Supper Club cap")
    }
}

/// The 100 × 80 box the cap is drawn in, scaled to `rect`.
private func hatPoint(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    CGPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 80 * rect.height)
}

/// The crown, seen three-quarters on: a dome, back on the left, front (and bill) on the right.
private struct HatCrown: Shape {
    func path(in rect: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in hatPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(5, 60))
        path.addCurve(to: p(45, 9), control1: p(3, 30), control2: p(20, 9))
        path.addCurve(to: p(86, 55), control1: p(68, 9), control2: p(86, 30))
        path.addQuadCurve(to: p(5, 60), control: p(44, 65))
        path.closeSubpath()
        return path
    }
}

/// The seam between the side and the front panel, clear of the embroidery.
private struct HatSeam: Shape {
    func path(in rect: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in hatPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(45, 10))
        path.addQuadCurve(to: p(17, 61), control: p(13, 24))
        return path
    }
}

/// The bill, curving out toward you from the front of the crown.
private struct HatBrim: Shape {
    func path(in rect: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in hatPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(30, 61))
        path.addQuadCurve(to: p(86, 55), control: p(60, 61))
        path.addQuadCurve(to: p(99, 63), control: p(97, 56))
        path.addQuadCurve(to: p(30, 61), control: p(72, 80))
        path.closeSubpath()
        return path
    }
}

/// Stitching along the bill.
private struct HatBrimStitch: Shape {
    func path(in rect: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in hatPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(40, 64))
        path.addQuadCurve(to: p(94, 63), control: p(74, 74))
        return path
    }
}
