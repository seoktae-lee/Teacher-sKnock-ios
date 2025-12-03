import SwiftUI
import SwiftData
import Charts

// ✨ [1] 겉포장지: 스와이프 기능을 담당하는 메인 뷰
struct DailyDetailView: View {
    let userId: String
    let initialDate: Date
    
    // 현재 보고 있는 페이지 번호 (0: 선택한 날짜, -1: 어제, +1: 내일)
    @State private var selectedIndex: Int = 0
    
    init(date: Date, userId: String) {
        self.initialDate = date
        self.userId = userId
    }
    
    var body: some View {
        // ✨ TabView의 'Page' 스타일을 이용해 스와이프 구현
        TabView(selection: $selectedIndex) {
            // 앞뒤로 넉넉하게 1년치(365일) 정도 범위를 생성
            // (TabView는 Lazy하게 로딩하므로 성능 문제 없음)
            ForEach(-365...365, id: \.self) { offset in
                let targetDate = Calendar.current.date(byAdding: .day, value: offset, to: initialDate) ?? initialDate
                
                // 실제 내용을 보여주는 뷰 호출
                DailyReportContent(date: targetDate, userId: userId)
                    .tag(offset) // 중요: 이 태그가 페이지 번호가 됨
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never)) // 페이지 점(인디케이터) 숨김
        .background(Color(.systemGray6)) // 전체 배경색
        .navigationBarTitleDisplayMode(.inline)
        // 화면이 나타날 때 현재 페이지(0번)로 확실하게 맞춤
        .onAppear {
            selectedIndex = 0
        }
    }
}

// ✨ [2] 내용물: 실제 데이터와 통계를 보여주는 뷰 (기존 DailyDetailView 코드)
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
        
        // 해당 날짜 데이터 쿼리
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 1. 날짜 헤더
                HStack {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.title2)
                        .bold()
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
