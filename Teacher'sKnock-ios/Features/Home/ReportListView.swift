import SwiftUI
import SwiftData

struct ReportListView: View {
    // DB에서 모든 공부 기록을 최신순으로 가져옴
    @Query(sort: \StudyRecord.date, order: .reverse) private var records: [StudyRecord]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0 // 0: 주간, 1: 월간
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 탭 선택기
            Picker("기간", selection: $selectedTab) {
                Text("주간 리포트").tag(0)
                Text("월간 리포트").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color.white)
            
            // 2. 리포트 목록
            ScrollView {
                LazyVStack(spacing: 15) {
                    if records.isEmpty {
                        emptyView
                    } else if selectedTab == 0 {
                        // ✨ 주간 리포트 (클릭 시 상세 화면 이동)
                        ForEach(weeklyGroups, id: \.id) { group in
                            NavigationLink(destination: WeeklyReportDetailView(
                                title: group.title,
                                startDate: group.startDate,
                                endDate: group.endDate
                            )) {
                                ReportCard(
                                    title: group.title,
                                    dateRange: group.rangeString,
                                    totalTime: group.totalSeconds,
                                    isNew: isRecent(group.endDate)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // ✨ [수정됨] 월간 리포트 (클릭 시 상세 화면 이동 연결됨)
                        ForEach(monthlyGroups, id: \.id) { group in
                            NavigationLink(destination: MonthlyReportDetailView(
                                title: group.title,
                                startDate: group.startDate,
                                endDate: group.endDate
                            )) {
                                ReportCard(
                                    title: group.title,
                                    dateRange: group.rangeString,
                                    totalTime: group.totalSeconds,
                                    isNew: isRecent(group.endDate)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6))
        }
        .navigationTitle("학습 리포트")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 데이터가 없을 때 표시
    private var emptyView: some View {
        VStack(spacing: 15) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("아직 생성된 리포트가 없어요.")
                .font(.headline)
                .foregroundColor(.gray)
            Text("공부를 기록하면 리포트가 쌓입니다!")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // 최근(7일 이내) 리포트인지 확인
    private func isRecent(_ date: Date) -> Bool {
        let diff = Calendar.current.dateComponents([.day], from: date, to: Date())
        return (diff.day ?? 100) < 7
    }
    
    // MARK: - Data Logic
    
    struct ReportGroup: Identifiable {
        let id = UUID()
        let title: String
        let rangeString: String
        let totalSeconds: Int
        let startDate: Date
        let endDate: Date
    }
    
    // ✨ 주간 그룹화 (목요일 기준 로직 적용)
    var weeklyGroups: [ReportGroup] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // 월요일 시작
        calendar.minimumDaysInFirstWeek = 4 // ISO 8601 (목요일 포함 기준)
        
        // '주(WeekOfYear)' 단위로 기록 그룹화
        let grouped = Dictionary(grouping: records) { record in
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.date)
            return "\(components.yearForWeekOfYear!)-\(components.weekOfYear!)"
        }
        
        let sortedKeys = grouped.keys.sorted(by: >)
        
        return sortedKeys.compactMap { key -> ReportGroup? in
            guard let items = grouped[key], let first = items.first else { return nil }
            
            // 1. 해당 주차의 월요일(시작일) 계산
            guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: first.date)) else { return nil }
            
            // 2. 일요일(종료일) 계산 = 월요일 + 6일
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            
            // 3. 목요일을 기준으로 '월'과 '주차' 이름 결정
            if let thursday = calendar.date(byAdding: .day, value: 3, to: startOfWeek) {
                let month = calendar.component(.month, from: thursday)
                let weekOfMonth = calendar.component(.weekOfMonth, from: thursday)
                
                let total = items.reduce(0) { $0 + $1.durationSeconds }
                let range = "\(formatDate(startOfWeek)) ~ \(formatDate(endOfWeek))"
                
                return ReportGroup(
                    title: "\(month)월 \(weekOfMonth)주차 리포트",
                    rangeString: range,
                    totalSeconds: total,
                    startDate: startOfWeek,
                    endDate: endOfWeek
                )
            }
            return nil
        }
    }
    
    // ✨ 월간 그룹화
    var monthlyGroups: [ReportGroup] {
        let grouped = Dictionary(grouping: records) { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return "\(components.year!)-\(components.month!)"
        }
        
        let sortedKeys = grouped.keys.sorted(by: >)
        
        return sortedKeys.compactMap { key -> ReportGroup? in
            guard let items = grouped[key], let first = items.first else { return nil }
            
            let calendar = Calendar.current
            let month = calendar.component(.month, from: first.date)
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: first.date))!
            let range = calendar.dateInterval(of: .month, for: startOfMonth)
            
            let total = items.reduce(0) { $0 + $1.durationSeconds }
            let endStr = range != nil ? formatDate(range!.end.addingTimeInterval(-86400)) : ""
            
            return ReportGroup(
                title: "\(month)월 월간 분석",
                rangeString: "\(formatDate(startOfMonth)) ~ \(endStr)",
                totalSeconds: total,
                startDate: startOfMonth,
                endDate: range?.end ?? Date()
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: date)
    }
}

// 리포트 카드 UI
struct ReportCard: View {
    let title: String
    let dateRange: String
    let totalTime: Int
    let isNew: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isNew {
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
                
                Text(dateRange)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("총 학습 시간: \(formatTime(totalTime))")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)시간 \(minutes)분" : "\(minutes)분"
    }
}
