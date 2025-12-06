import SwiftUI
import SwiftData
import Charts

struct MonthlyReportDetailView: View {
    let title: String
    let startDate: Date
    let endDate: Date
    let userId: String
    
    // ✨ @Query 제거 -> @State로 변경 (렉 방지 및 안전성 확보)
    @State private var records: [StudyRecord] = []
    @Environment(\.modelContext) private var modelContext
    
    // 차트용 데이터 구조체
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        var color: Color { SubjectName.color(for: subject) }
    }
    
    init(title: String, startDate: Date, endDate: Date, userId: String) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.userId = userId
        // init에서는 데이터를 가져오지 않음 (가볍게 유지)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 1. 헤더
                headerSection
                
                Divider()
                
                // 2. 학습 습관 캘린더 (잔디 심기)
                VStack(alignment: .leading, spacing: 10) {
                    Text("📅 월간 학습 습관")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    StudyHeatmapView(startDate: startDate, endDate: endDate, records: records)
                        .padding(.horizontal)
                }
                
                Divider()
                
                // 3. 과목별 분석
                if !pieData.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("📊 과목별 학습 분석")
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
                        
                        Divider().padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(pieData.enumerated()), id: \.element.id) { index, item in
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.caption2).bold()
                                        .frame(width: 20, height: 20)
                                        .background(index < 3 ? item.color.opacity(0.2) : Color.gray.opacity(0.1))
                                        .foregroundColor(index < 3 ? item.color : .gray)
                                        .clipShape(Circle())
                                    
                                    Text(item.subject)
                                        .font(.subheadline)
                                        .frame(width: 80, alignment: .leading)
                                        .lineLimit(1)
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.gray.opacity(0.1))
                                            Capsule().fill(item.color)
                                                .frame(width: geo.size.width * (Double(item.seconds) / Double(maxSeconds)))
                                        }
                                    }
                                    .frame(height: 8)
                                    
                                    Text(formatTimeShort(item.seconds))
                                        .font(.caption).foregroundColor(.gray)
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                } else {
                    Text("이 달에는 공부 기록이 없습니다.")
                        .font(.caption).foregroundColor(.gray)
                        .padding(.vertical, 30)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6))
        // ✨ 화면이 뜰 때 데이터 로드
        .task {
            fetchData()
        }
    }
    
    // ✨ 데이터 로드 함수 (사용자 분리 적용)
    private func fetchData() {
        let descriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate<StudyRecord> { $0.ownerID == userId }
        )
        
        do {
            let allR = try modelContext.fetch(descriptor)
            
            // 날짜 범위 필터링 (메모리에서 수행)
            let rangeEnd = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
            
            self.records = allR.filter { $0.date >= startDate && $0.date < rangeEnd }
            
        } catch {
            print("월간 리포트 로드 실패: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private var totalSeconds: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    private var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { ChartData(subject: $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
    }
    
    private var maxSeconds: Int {
        pieData.map { $0.seconds }.max() ?? 1
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("이번 달 총 학습")
                .font(.subheadline).foregroundColor(.gray)
            Text(formatTime(totalSeconds))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.blue)
            
            Text("\(formatDate(startDate)) ~ \(formatDate(endDate))")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
    
    private func formatTimeShort(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// ✨ [필수] 잔디 심기 뷰 (파일 내 포함)
struct StudyHeatmapView: View {
    let startDate: Date
    let endDate: Date
    let records: [StudyRecord]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var days: [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        var current = startDate
        while current <= endDate {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return dates
    }
    
    var studyMap: [Date: Int] {
        var map: [Date: Int] = [:]
        let calendar = Calendar.current
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            map[day, default: 0] += record.durationSeconds
        }
        return map
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                    Text(day).font(.caption2).foregroundColor(.gray)
                }
                
                let firstWeekday = Calendar.current.component(.weekday, from: startDate)
                ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                    Color.clear
                }
                
                ForEach(days, id: \.self) { date in
                    let seconds = studyMap[Calendar.current.startOfDay(for: date)] ?? 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(getColor(seconds: seconds))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
    
    func getColor(seconds: Int) -> Color {
        if seconds == 0 { return Color.gray.opacity(0.1) }
        if seconds < 3600 { return Color.blue.opacity(0.2) }
        if seconds < 10800 { return Color.blue.opacity(0.5) }
        if seconds < 18000 { return Color.blue.opacity(0.8) }
        return Color.blue
    }
}
