import SwiftUI
import SwiftData
import Charts
import FirebaseAuth // ✨ [추가] 유저 ID 확인을 위해 필요

struct WeeklyReportDetailView: View {
    let title: String
    let startDate: Date
    let endDate: Date
    
    @Query private var allRecords: [StudyRecord]
    @Query private var allSchedules: [ScheduleItem]
    
    // 차트용 데이터 구조
    struct ChartData: Identifiable {
        let id = UUID()
        let label: String
        let seconds: Int
        var color: Color
    }
    
    // 현재 로그인한 유저 ID 가져오기
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 1. 요약 카드 (총 시간 + MVP)
                summaryCard
                
                // 2. 요일별 공부량 막대 그래프
                VStack(alignment: .leading, spacing: 15) {
                    Text("📊 요일별 학습 흐름")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Chart(dailyChartData) { item in
                        BarMark(
                            x: .value("요일", item.label),
                            y: .value("시간", item.seconds)
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(4)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisTick()
                            if let seconds = value.as(Int.self) {
                                AxisValueLabel("\(seconds / 3600)h")
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }
                
                Divider()
                
                // 3. ✨ [수정됨] 플래너 vs 수행 비교 (클릭 시 상세 이동)
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("📅 일별 상세 기록")
                            .font(.headline)
                        Spacer()
                        Text("날짜를 누르면 플래너로 이동")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(getDaysInWeek(), id: \.self) { date in
                            // ✨ 클릭하면 그날의 플래너(DailyDetailView)로 이동!
                            NavigationLink(destination: DailyDetailView(date: date, userId: currentUserId)) {
                                DailyPerformanceRow(
                                    date: date,
                                    schedules: getSchedules(for: date),
                                    records: getRecords(for: date)
                                )
                            }
                            .buttonStyle(.plain) // 버튼 디자인 제거 (리스트 스타일 유지)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // 4. 주간 과목 비중 (원형 차트)
                if !pieData.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("🧩 과목별 비중")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart(pieData) { item in
                            SectorMark(
                                angle: .value("시간", item.seconds),
                                innerRadius: .ratio(0.55),
                                angularInset: 1.5
                            )
                            .foregroundStyle(item.color)
                        }
                        .frame(height: 220)
                        
                        // 범례
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                            ForEach(pieData) { item in
                                HStack(spacing: 4) {
                                    Circle().fill(item.color).frame(width: 8, height: 8)
                                    Text(item.label).font(.caption).lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Components (이전과 동일)
    
    private var summaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("총 학습 시간")
                    .font(.caption).foregroundColor(.gray)
                Text(formatTimeShort(totalSeconds))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.blue)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("🔥 이번 주 MVP")
                    .font(.caption).foregroundColor(.gray)
                if let best = pieData.first {
                    Text(best.label)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(best.color)
                } else {
                    Text("-")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // MARK: - Helpers (이전과 동일)
    
    private var filteredRecords: [StudyRecord] {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
        return allRecords.filter { $0.date >= startDate && $0.date < end }
    }
    
    private var totalSeconds: Int {
        filteredRecords.reduce(0) { $0 + $1.durationSeconds }
    }
    
    private var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in filteredRecords {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { ChartData(label: $0.key, seconds: $0.value, color: SubjectName.color(for: $0.key)) }
            .sorted { $0.seconds > $1.seconds }
    }
    
    private var dailyChartData: [ChartData] {
        let days = getDaysInWeek()
        return days.map { date in
            let records = getRecords(for: date)
            let total = records.reduce(0) { $0 + $1.durationSeconds }
            let dayLabel = date.formatted(.dateTime.weekday(.abbreviated))
            let color = total > 0 ? Color.blue : Color.gray.opacity(0.3)
            return ChartData(label: dayLabel, seconds: total, color: color)
        }
    }
    
    private func getDaysInWeek() -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }
        return days
    }
    
    private func getSchedules(for date: Date) -> [ScheduleItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return allSchedules.filter {
            $0.startDate >= start && $0.startDate < end
        }
    }
    
    private func getRecords(for date: Date) -> [StudyRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return allRecords.filter {
            $0.date >= start && $0.date < end
        }
    }
    
    private func formatTimeShort(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
}

// ✨ 요일별 수행도 리스트 행 (화살표 추가)
struct DailyPerformanceRow: View {
    let date: Date
    let schedules: [ScheduleItem]
    let records: [StudyRecord]
    
    var completedCount: Int { schedules.filter { $0.isCompleted }.count }
    var totalStudyTime: Int { records.reduce(0) { $0 + $1.durationSeconds } }
    
    var body: some View {
        HStack {
            // 날짜 (월 12.04)
            VStack {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2).bold().foregroundColor(.gray)
                Text(date.formatted(.dateTime.day()))
                    .font(.caption).bold()
            }
            .frame(width: 40)
            
            Divider().frame(height: 30)
            
            // 플래너 달성률
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(schedules.isEmpty ? .gray : (completedCount == schedules.count ? .green : .orange))
                    Text(schedules.isEmpty ? "일정 없음" : "\(completedCount)/\(schedules.count) 완료")
                        .font(.caption).bold()
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.1))
                        if !schedules.isEmpty {
                            Capsule()
                                .fill(completedCount == schedules.count ? Color.green : Color.orange)
                                .frame(width: geo.size.width * CGFloat(completedCount) / CGFloat(schedules.count))
                        }
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            // 실제 공부 시간
            if totalStudyTime > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("학습 시간")
                        .font(.caption2).foregroundColor(.gray)
                    Text(formatTime(totalStudyTime))
                        .font(.caption).bold().foregroundColor(.blue)
                }
            } else {
                Text("-")
                    .font(.caption).foregroundColor(.gray.opacity(0.5))
            }
            
            // ✨ 이동 가능하다는 힌트 (Chevron)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.leading, 5)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
