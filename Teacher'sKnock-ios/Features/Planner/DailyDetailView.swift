import SwiftUI
import SwiftData
import FirebaseAuth

struct DailyDetailView: View {
    let date: Date
    let userId: String
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @Query private var schedules: [ScheduleItem]
    @Query private var records: [StudyRecord]
    
    @State private var showingAddSheet = false
    
    // 통계 계산
    var totalStudyTime: Int { records.reduce(0) { $0 + $1.durationSeconds } }
    var completedCount: Int { schedules.filter { $0.isCompleted }.count }
    var progress: Double { schedules.isEmpty ? 0 : Double(completedCount) / Double(schedules.count) }
    
    init(date: Date, userId: String) {
        self.date = date
        self.userId = userId
        
        let start = Calendar.current.startOfDay(for: date)
        
        // ✨ [오류 해결] 끝에 느낌표(!)를 붙여서 Optional을 강제로 해제합니다.
        // "Value of optional type 'Date?' must be unwrapped" 오류 해결됨
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        
        _schedules = Query(filter: #Predicate<ScheduleItem> {
            $0.ownerID == userId && $0.startDate >= start && $0.startDate < end
        }, sort: \.startDate)
        
        _records = Query(filter: #Predicate<StudyRecord> {
            $0.ownerID == userId && $0.date >= start && $0.date < end
        })
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. 헤더
            HStack {
                VStack(alignment: .leading) {
                    Text(date.formatted(.dateTime.month().day()))
                        .font(.largeTitle).fontWeight(.bold)
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.headline).foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // 2. 상세 리포트 버튼 (세련된 카드형)
            NavigationLink(destination: DailyReportView(date: date, userId: userId)) {
                HStack(spacing: 15) {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.1)).frame(width: 48, height: 48)
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.title3).foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("오늘의 학습 리포트").font(.headline).foregroundColor(.primary)
                        if totalStudyTime > 0 {
                            Text("총 \(formatTime(totalStudyTime)) 학습 • 달성률 \(Int(progress * 100))%")
                                .font(.caption).foregroundColor(.gray)
                        } else {
                            Text("학습 기록이 없습니다").font(.caption).foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5))
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.05), lineWidth: 1))
            }
            .padding(.horizontal)
            .buttonStyle(.plain)
            
            // 3. 일정 리스트
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Time Table").font(.title3).fontWeight(.bold)
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                if schedules.isEmpty {
                    Spacer()
                    ContentUnavailableView {
                        Label("일정이 없습니다", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("우측 상단 + 버튼을 눌러\n오늘의 계획을 세워보세요!")
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(schedules) { item in
                            ScheduleRow(item: item)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete(perform: deleteSchedule)
                    }
                    .listStyle(.plain)
                }
            }
        }
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSheet) {
            // ✨ 2번 파일(AddScheduleView)이 수정되어서 이제 오류가 나지 않습니다.
            AddScheduleView(selectedDate: date)
                .presentationDetents([.medium])
        }
    }
    
    private func deleteSchedule(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(schedules[index]) }
    }
    
    private func formatTime(_ s: Int) -> String {
        let h = s/3600; let m = (s%3600)/60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
}

// 하위 컴포넌트
struct ScheduleRow: View {
    let item: ScheduleItem
    @Environment(\.modelContext) var context
    
    var body: some View {
        HStack {
            Button(action: { item.isCompleted.toggle(); try? context.save() }) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title3).foregroundColor(item.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading) {
                Text(item.title).strikethrough(item.isCompleted, color: .gray).foregroundColor(item.isCompleted ? .gray : .primary)
                Text("\(formatDate(item.startDate)) ~ \(formatDate(item.endDate))").font(.caption2).foregroundColor(.gray)
            }
            Spacer()
            // 1번 파일(Model)이 수정되어야 여기서 subject 접근 가능
            Text(item.subject).font(.caption2).fontWeight(.bold).padding(.horizontal, 8).padding(.vertical, 4)
                .background(SubjectName.color(for: item.subject).opacity(0.1))
                .foregroundColor(SubjectName.color(for: item.subject))
                .cornerRadius(8)
        }
        .padding().background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.01), radius: 1, x: 0, y: 1)
    }
    func formatDate(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d) }
}

struct DailyReportView: View {
    let date: Date
    let userId: String
    var body: some View { Text("상세 분석 화면 (준비 중)") }
}
