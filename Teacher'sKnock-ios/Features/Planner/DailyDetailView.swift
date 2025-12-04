import SwiftUI
import SwiftData
import Charts

// [1] 겉포장지
struct DailyDetailView: View {
    let userId: String
    let initialDate: Date
    @State private var selectedIndex: Int = 0
    
    init(date: Date, userId: String) {
        self.initialDate = date
        self.userId = userId
    }
    
    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(-365...365, id: \.self) { offset in
                let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: initialDate) ?? initialDate
                DailyReportContent(date: targetDate, userId: userId).tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedIndex = 0 }
    }
}

// [2] 내용물
struct DailyReportContent: View {
    let date: Date
    let userId: String
    
    @Environment(\.modelContext) private var modelContext
    
    @Query private var schedules: [ScheduleItem]
    @Query private var records: [StudyRecord]
    
    @State private var selectedSchedule: ScheduleItem? = nil
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _schedules = Query(filter: #Predicate<ScheduleItem> { item in
            item.ownerID == userId && item.startDate >= startOfDay && item.startDate < endOfDay
        }, sort: \.startDate)
        
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId && record.date >= startOfDay && record.date < endOfDay
        })
    }
    
    // 데이터 로직 생략 (기존과 동일)
    // ... Pie Data 계산 등 ...
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        var color: Color {
            if let matched = SubjectName.allCases.first(where: { $0.rawValue == subject }) { return matched.color }
            return .gray
        }
    }
    
    var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records { dict[record.areaName, default: 0] += record.durationSeconds }
        return dict.map { ChartData(subject: $0.key, seconds: $0.value) }
    }
    
    var totalActualSeconds: Int { pieData.reduce(0) { $0 + $1.seconds } }
    
    private func formatKoreanDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 (EEEE)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
    
    // ✨ 내일로 미루기 수정
    private func duplicateToTomorrow(_ item: ScheduleItem) {
        let oneDaySeconds: TimeInterval = 86400
        let newStart = item.startDate.addingTimeInterval(oneDaySeconds)
        let newEnd = item.endDate?.addingTimeInterval(oneDaySeconds)
        
        let newItem = ScheduleItem(
            title: item.title,
            details: item.details,
            startDate: newStart,
            endDate: newEnd,
            isCompleted: false,
            hasReminder: item.hasReminder,
            ownerID: item.ownerID,
            isPostponed: false
        )
        
        // 1. 로컬 저장
        modelContext.insert(newItem)
        
        // 2. ✨ 서버 저장
        FirestoreSyncManager.shared.saveSchedule(newItem)
        
        // 원본 상태 변경
        item.isPostponed = true
        item.isCompleted = false
    }
    
    private func deleteSchedule(_ item: ScheduleItem) {
        modelContext.delete(item)
        // 삭제 동기화는 복잡도가 높으므로 1차 버전에서는 생략 (추후 구현 가능)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                HStack { Text(formatKoreanDate(date)).font(.title2).bold().foregroundColor(.primary); Spacer() }
                    .padding(.horizontal).padding(.top)
                
                HStack { Text("To-Do List").font(.headline); Spacer(); Text("\(schedules.filter { $0.isCompleted }.count) / \(schedules.count) 완료").font(.caption).foregroundColor(.gray) }
                    .padding(.horizontal)
                
                if !schedules.isEmpty {
                    Text("💡 일정을 꾹 누르면 내일로 미루거나 삭제할 수 있어요.").font(.caption2).foregroundColor(.gray.opacity(0.8)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                }
                
                VStack(spacing: 0) {
                    if schedules.isEmpty {
                        Text("등록된 일정이 없습니다.").foregroundColor(.gray).padding()
                    } else {
                        ForEach(schedules) { item in
                            HStack {
                                Button(action: { toggleComplete(item) }) {
                                    Image(systemName: item.isCompleted ? "checkmark.square.fill" : (item.isPostponed ? "arrow.turn.up.right.square" : "square"))
                                        .foregroundColor(item.isCompleted ? .green : (item.isPostponed ? .orange : .gray)).font(.title3)
                                }
                                VStack(alignment: .leading) {
                                    Text(item.title).strikethrough(item.isCompleted || item.isPostponed).foregroundColor((item.isCompleted || item.isPostponed) ? .gray : .primary)
                                    if let end = item.endDate {
                                        Text("\(item.startDate.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                if item.isPostponed { Text("미뤄짐").font(.caption2).foregroundColor(.orange).padding(.horizontal, 6).padding(.vertical, 2).background(Color.orange.opacity(0.1)).cornerRadius(4) }
                                Circle().fill(SubjectName.color(for: item.title)).frame(width: 8, height: 8)
                            }
                            .padding().contentShape(Rectangle())
                            .contextMenu {
                                Button { duplicateToTomorrow(item) } label: { Label("내일 하기", systemImage: "arrow.turn.up.right") }
                                Button { selectedSchedule = item } label: { Label("수정하기", systemImage: "pencil") }
                                Button(role: .destructive) { deleteSchedule(item) } label: { Label("삭제하기", systemImage: "trash") }
                            }
                            .onTapGesture { selectedSchedule = item }
                            Divider()
                        }
                    }
                }
                .background(Color.white).cornerRadius(15).padding(.horizontal)
                
                Divider()
                
                HStack { Text("타임테이블").font(.headline); Spacer(); Text("일정을 누르면 수정할 수 있어요").font(.caption).foregroundColor(.gray) }.padding(.horizontal)
                
                DailyTimelineView(schedules: schedules, onItemTap: { item in selectedSchedule = item })
                    .frame(height: 650).background(Color.white).cornerRadius(15).padding(.horizontal)
                
                Divider()
                
                if !pieData.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("일일 분석 리포트").font(.headline).padding(.top)
                        VStack(alignment: .leading) {
                            Text("과목별 학습 비중").font(.subheadline).foregroundColor(.gray).padding(.leading)
                            Chart(pieData) { item in
                                let percentage = Double(item.seconds) / Double(totalActualSeconds) * 100
                                SectorMark(angle: .value("시간", item.seconds), innerRadius: .ratio(0.5), angularInset: 1.0)
                                    .foregroundStyle(item.color)
                                    .annotation(position: .overlay) {
                                        if percentage >= 5 { Text(String(format: "%.0f%%", percentage)).font(.caption).fontWeight(.bold).foregroundColor(.white).shadow(color: .black.opacity(0.4), radius: 1) }
                                    }
                            }
                            .frame(height: 200).padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                                ForEach(pieData) { item in
                                    HStack(spacing: 4) { Circle().fill(item.color).frame(width: 8, height: 8); Text(item.subject).font(.caption).lineLimit(1) }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20).background(Color.white).cornerRadius(15).shadow(radius: 2).padding(.horizontal).padding(.bottom, 50)
                }
            }
        }
        .sheet(item: $selectedSchedule) { item in EditScheduleView(item: item) }
    }
    
    private func toggleComplete(_ item: ScheduleItem) {
        if !item.isPostponed { item.isCompleted.toggle() }
    }
}
