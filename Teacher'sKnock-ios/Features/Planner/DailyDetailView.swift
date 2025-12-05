import SwiftUI
import SwiftData
import Charts

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
        .onAppear { selectedIndex = 0 }
    }
}

struct DailyReportContent: View {
    @StateObject private var viewModel: DailyDetailViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedSchedule: ScheduleItem? = nil
    
    init(date: Date, userId: String) {
        _viewModel = StateObject(wrappedValue: DailyDetailViewModel(userId: userId, targetDate: date))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 날짜 헤더
                HStack {
                    Text(viewModel.formattedDateString)
                        .font(.title2).bold().foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal).padding(.top)
                
                // To-Do 헤더
                HStack {
                    Text("To-Do List").font(.headline)
                    Spacer()
                    Text("\(viewModel.schedules.filter { $0.isCompleted }.count) / \(viewModel.schedules.count) 완료")
                        .font(.caption).foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                // 안내 문구
                if !viewModel.schedules.isEmpty {
                    Text("💡 일정을 꾹 누르면 내일로 미루거나 삭제할 수 있어요.")
                        .font(.caption2).foregroundColor(.gray.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                
                // To-Do 리스트
                VStack(spacing: 0) {
                    if viewModel.schedules.isEmpty {
                        Text("등록된 일정이 없습니다.").foregroundColor(.gray).padding()
                    } else {
                        ForEach(viewModel.schedules) { item in
                            scheduleRow(item)
                            Divider()
                        }
                    }
                }
                .background(Color.white).cornerRadius(15).padding(.horizontal)
                
                Divider()
                
                // 타임테이블
                HStack {
                    Text("타임테이블").font(.headline)
                    Spacer()
                    Text("일정을 누르면 수정할 수 있어요").font(.caption).foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                DailyTimelineView(
                    date: viewModel.targetDate,
                    schedules: viewModel.schedules,
                    onItemTap: { item in
                        selectedSchedule = item
                    }
                )
                .frame(height: 650)
                .background(Color.white).cornerRadius(15)
                .padding(.horizontal)
                
                Divider()
                
                // 차트 영역
                if !viewModel.pieData.isEmpty {
                    chartSection
                }
            }
        }
        .sheet(item: $selectedSchedule) { item in
            EditScheduleView(item: item)
                .onDisappear {
                    viewModel.fetchData()
                }
        }
        .onAppear {
            viewModel.setContext(modelContext)
        }
    }
    
    // MARK: - Subviews
    
    private func scheduleRow(_ item: ScheduleItem) -> some View {
        HStack {
            // 체크 버튼 (미뤄진 상태면 클릭 불가 + 주황색 아이콘)
            Button(action: { viewModel.toggleComplete(item) }) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : (item.isPostponed ? "arrow.turn.up.right.square" : "square"))
                    .foregroundColor(item.isCompleted ? .green : (item.isPostponed ? .orange : .gray))
                    .font(.title3)
            }
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .strikethrough(item.isCompleted || item.isPostponed)
                    .foregroundColor((item.isCompleted || item.isPostponed) ? .gray : .primary)
                
                if let end = item.endDate {
                    Text("\(item.startDate.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // 미뤄짐 뱃지
            if item.isPostponed {
                Text("미뤄짐")
                    .font(.caption2).foregroundColor(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1)).cornerRadius(4)
            }
            
            Circle().fill(SubjectName.color(for: item.title)).frame(width: 8, height: 8)
        }
        .padding().contentShape(Rectangle())
        .contextMenu {
            // ✨ [수정됨] 상태에 따라 다른 메뉴 표시
            if item.isPostponed {
                // 이미 미룬 경우 -> '취소' 버튼
                Button {
                    viewModel.cancelPostpone(item)
                } label: {
                    Label("미루기 취소", systemImage: "arrow.uturn.backward")
                }
            } else {
                // 안 미룬 경우 -> '내일 하기' 버튼
                Button {
                    viewModel.duplicateToTomorrow(item)
                } label: {
                    Label("내일 하기", systemImage: "arrow.turn.up.right")
                }
            }
            
            Button { selectedSchedule = item } label: { Label("수정하기", systemImage: "pencil") }
            Button(role: .destructive) { viewModel.deleteSchedule(item) } label: { Label("삭제하기", systemImage: "trash") }
        }
        .onTapGesture { selectedSchedule = item }
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("일일 분석 리포트").font(.headline).padding(.top)
            
            VStack(alignment: .leading) {
                Text("과목별 학습 비중").font(.subheadline).foregroundColor(.gray).padding(.leading)
                
                Chart(viewModel.pieData) { item in
                    let percentage = Double(item.seconds) / Double(viewModel.totalActualSeconds) * 100
                    SectorMark(
                        angle: .value("시간", item.seconds),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.0
                    )
                    .foregroundStyle(item.color)
                    .annotation(position: .overlay) {
                        if percentage >= 5 {
                            Text(String(format: "%.0f%%", percentage))
                                .font(.caption).fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 1)
                        }
                    }
                }
                .frame(height: 200).padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                    ForEach(viewModel.pieData) { item in
                        HStack(spacing: 4) {
                            Circle().fill(item.color).frame(width: 8, height: 8)
                            Text(item.subject).font(.caption).lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 20)
        .background(Color.white).cornerRadius(15).shadow(radius: 2)
        .padding(.horizontal).padding(.bottom, 50)
    }
}
