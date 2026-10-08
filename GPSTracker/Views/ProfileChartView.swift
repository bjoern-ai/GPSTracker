import SwiftUI
import Charts

/// Altitude and speed profile over the distance traveled, using Swift Charts.
struct ProfileChartView: View {
    let points: [TrackPoint]

    private struct Sample: Identifiable {
        let id: Int
        let km: Double
        let altitude: Double
        let speedKmh: Double
    }

    /// Averages consecutive points into at most `maxCount` samples. This keeps
    /// long tracks fast to render and smooths out GPS jitter.
    private static func samples(from points: [TrackPoint], maxCount: Int = 200) -> [Sample] {
        guard points.count > 1 else { return [] }
        var distances = [0.0]
        distances.reserveCapacity(points.count)
        for i in 1..<points.count {
            distances.append(distances[i - 1] + points[i].clLocation.distance(from: points[i - 1].clLocation))
        }

        let bucketSize = max(1, Int((Double(points.count) / Double(maxCount)).rounded(.up)))
        return stride(from: 0, to: points.count, by: bucketSize).enumerated().map { index, start in
            let range = start..<min(start + bucketSize, points.count)
            let n = Double(range.count)
            return Sample(
                id: index,
                km: range.reduce(0) { $0 + distances[$1] } / n / 1000,
                altitude: range.reduce(0) { $0 + points[$1].altitude } / n,
                speedKmh: range.reduce(0) { $0 + max(points[$1].speed, 0) } / n * 3.6
            )
        }
    }

    var body: some View {
        let samples = Self.samples(from: points)
        let maxKm = max(samples.last?.km ?? 0, 0.1)

        VStack(alignment: .leading, spacing: 24) {
            altitudeChart(samples, maxKm: maxKm)
            speedChart(samples, maxKm: maxKm)
        }
    }

    private func altitudeChart(_ samples: [Sample], maxKm: Double) -> some View {
        let altitudes = samples.map(\.altitude)
        let low = altitudes.min() ?? 0
        let high = altitudes.max() ?? 0
        let padding = max((high - low) * 0.2, 5)
        let floor = low - padding

        return VStack(alignment: .leading, spacing: 8) {
            header("Höhenprofil", summary: "\(Int(low.rounded()))–\(Int(high.rounded())) m")
            Chart(samples) { sample in
                AreaMark(
                    x: .value("Distanz", sample.km),
                    yStart: .value("Basis", floor),
                    yEnd: .value("Höhe", sample.altitude)
                )
                .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.4), .blue.opacity(0.05)],
                                                startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)

                LineMark(x: .value("Distanz", sample.km), y: .value("Höhe", sample.altitude))
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: floor...(high + padding))
            .chartXScale(domain: 0...maxKm)
            .chartXAxis { distanceAxis }
            .chartYAxis { valueAxis(unit: "m") }
            .frame(height: 160)
        }
    }

    private func speedChart(_ samples: [Sample], maxKm: Double) -> some View {
        let speeds = samples.map(\.speedKmh)
        let top = max((speeds.max() ?? 0) * 1.15, 5)
        let average = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)

        return VStack(alignment: .leading, spacing: 8) {
            header("Geschwindigkeitsprofil", summary: "Ø \(average.formatted(.number.precision(.fractionLength(1)))) km/h")
            Chart(samples) { sample in
                AreaMark(x: .value("Distanz", sample.km), y: .value("Geschwindigkeit", sample.speedKmh))
                    .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.35), .orange.opacity(0.05)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)

                LineMark(x: .value("Distanz", sample.km), y: .value("Geschwindigkeit", sample.speedKmh))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...top)
            .chartXScale(domain: 0...maxKm)
            .chartXAxis { distanceAxis }
            .chartYAxis { valueAxis(unit: "km/h") }
            .frame(height: 160)
        }
    }

    private func header(_ title: String, summary: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var distanceAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 5)) { value in
            AxisGridLine()
            AxisValueLabel {
                if let km = value.as(Double.self) {
                    Text("\(km.formatted(.number.precision(.fractionLength(0...1)))) km")
                }
            }
        }
    }

    private func valueAxis(unit: String) -> some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
            AxisGridLine()
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text("\(Int(number.rounded())) \(unit)")
                }
            }
        }
    }
}
