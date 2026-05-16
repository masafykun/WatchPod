import SwiftUI

struct WeatherView: View {
    @EnvironmentObject var weather: WeatherManager

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "H時"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // 現在の気象
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: weather.currentConditionSymbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weather.currentTemp)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text("湿度 \(weather.currentHumidity)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    Text(weather.locationName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    Divider()

                    // 1時間ごと予報
                    if weather.hourly.isEmpty {
                        VStack {
                            if weather.isLoading {
                                ProgressView()
                            } else if let err = weather.errorMessage {
                                Text(err)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("予報なし")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("再取得") { weather.refresh() }
                                .font(.caption2)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(weather.hourly) { entry in
                            HStack {
                                Text(Self.hourFormatter.string(from: entry.date))
                                    .font(.caption)
                                    .frame(width: 36, alignment: .leading)
                                    .monospacedDigit()
                                Image(systemName: entry.symbol)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.body)
                                    .frame(width: 24)
                                Spacer()
                                Text(entry.temp)
                                    .font(.caption)
                                    .monospacedDigit()
                                Text(entry.humidity)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 36, alignment: .trailing)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("天気")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        weather.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

#Preview {
    WeatherView()
        .environmentObject(WeatherManager())
}
