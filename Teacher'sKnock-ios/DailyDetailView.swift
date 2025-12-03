import SwiftUI
import SwiftData
import Charts

// [1] 겉포장지: 스와이프 기능을 담당하는 메인 뷰
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
                
                DailyReportContent(date: targetDate, userId: userId)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedIndex = 0
        }
    }
}

// [2] 내용물: 실제 데이터와 통계를 보여주는 뷰
struct DailyReportContent: View {
    let date: Date
    let userId: String
    
    @Query private var schedules: [ScheduleItem]
    @Query private var records: [StudyRecord]
    
    @State private var selectedSchedule: ScheduleItem? = nil
    
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
    
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        var color: Color {
            if let matched = SubjectName.allCases.first(where: { $0.rawValue == subject }) {
                return matched.color
            }
            return .gray
        }
    }
    
    var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records { dict[record.areaName, default: 0] += record.durationSeconds }
        return dict.map { ChartData(subject: $0.key, seconds: $0.value) }
    }
    
    var totalSeconds: Int {
        pieData.reduce(0) { $0 + $1.seconds }
    }
    
    // ✨ [NEW] 날짜 포맷팅 헬퍼 함수
    private func formatKoreanDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 (EEEE)" // 예: 2025년 12월 3일 (수요일)
        formatter.locale = Locale(identifier: "ko_KR") // 한국어 강제 설정
        return formatter.string(from: date)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 1. ✨ [수정됨] 날짜 헤더 (한국어 포맷 적용)
                HStack {
                    Text(formatKoreanDate(date))
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // 2. To-Do List
                HStack {
                    Text("To-Do List").font(.headline)
                    Spacer()
                    Text("\(schedules.filter { $0.isCompleted }.count) / \(schedules.count) 완료")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                VStack(spacing: 0) {
                    if schedules.isEmpty {
                        Text("등록된 일정이 없습니다.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(schedules) { item in
                            HStack {
                                Button(action: { toggleComplete(item) }) {
                                    Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                        .foregroundColor(item.isCompleted ? .green : .gray)
                                        .font(.title3)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .strikethrough(item.isCompleted)
                                        .foregroundColor(item.isCompleted ? .gray : .primary)
                                    if let end = item.endDate {
                                        Text("\(item.startDate.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Circle()
                                    .fill(SubjectName.color(for: item.title))
                                    .frame(width: 8, height: 8)
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSchedule = item
                            }
                            Divider()
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(15)
                .padding(.horizontal)
                
                Divider()
                
                // 3. 타임테이블
                HStack {
                    Text("타임테이블").font(.headline)
                    Spacer()
                    Text("일정을 누르면 수정할 수 있어요")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                DailyTimelineView(schedules: schedules, onItemTap: { item in
                    selectedSchedule = item
                })
                .frame(height: 550)
                .background(Color.white)
                .cornerRadius(15)
                .padding(.horizontal)
                
                Divider()
                
                // 4. 오늘의 공부 통계
                if !pieData.isEmpty {
                    VStack {
                        Text("과목별 학습 비중").font(.headline).padding(.top)
                        
                        Chart(pieData) { item in
                            let percentage = Double(item.seconds) / Double(totalSeconds) * 100
                            
                            SectorMark(
                                angle: .value("시간", item.seconds),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.0
                            )
                            .foregroundStyle(item.color)
                            .annotation(position: .overlay) {
                                if percentage >= 5 {
                                    Text(String(format: "%.0f%%", percentage))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 0)
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                            ForEach(pieData) { item in
                                HStack(spacing: 4) {
                                    Circle().fill(item.color).frame(width: 8, height: 8)
                                    Text(item.subject).font(.caption).lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
            }
        }
        .sheet(item: $selectedSchedule) { item in
            EditScheduleView(item: item)
        }
    }
    
    private func toggleComplete(_ item: ScheduleItem) {
        item.isCompleted.toggle()
    }
}
