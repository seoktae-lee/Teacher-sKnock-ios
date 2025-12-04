import SwiftUI
import SwiftData
import FirebaseAuth
import Combine

struct GoalListView: View {
    @Query private var goals: [Goal]
    
    @State private var showingAddGoalSheet = false
    @State private var showingCharacterDetail = false
    @State private var selectedGoal: Goal?
    
    // 리포트 화면 이동을 위한 상태 변수
    @State private var showingReportList = false
    
    @State private var todayQuote: Quote = Quote(text: "오늘의 명언을 불러오는 중...", author: "")
    
    @EnvironmentObject var authManager: AuthManager
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    init(userId: String) {
        _goals = Query(filter: #Predicate<Goal> { goal in
            goal.ownerID == userId
        }, sort: \.targetDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 명언 카드
                QuoteCard(quote: todayQuote)
                    .padding()
                
                // 2. 목표 리스트
                if goals.isEmpty {
                    ContentUnavailableView {
                        Label("목표가 없습니다", systemImage: "target")
                    } description: {
                        Text("우측 상단 + 버튼을 눌러\n시험 목표를 추가해보세요.")
                    }
                } else {
                    List {
                        ForEach(goals) { goal in
                            Button(action: {
                                selectedGoal = goal
                                showingCharacterDetail = true
                            }) {
                                GoalRow(goal: goal, userId: currentUserId)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteGoals)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(authManager.userNickname)님의 D-day")
            .toolbar {
                // ✨ [수정됨] 좌측 상단: 리포트 버튼 (문서 아이콘)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingReportList = true }) {
                        Image(systemName: "doc.text.image") // 👈 여기서 아이콘 변경됨!
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                }
                
                // 우측 상단: 목표 추가 버튼
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGoalSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(brandColor)
                    }
                }
            }
            // 리포트 화면 연결
            .navigationDestination(isPresented: $showingReportList) {
                ReportListView()
            }
            .sheet(isPresented: $showingAddGoalSheet) {
                AddGoalView()
            }
            .sheet(item: $selectedGoal) { goal in
                VStack(spacing: 30) {
                    Text("나의 성장 기록")
                        .font(.title2).bold().padding(.top, 30)
                    Text(goal.title).font(.headline).foregroundColor(.gray)
                    CharacterView(userId: currentUserId).padding()
                    Spacer()
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                loadQuote()
            }
        }
    }
    
    func loadQuote() {
        if todayQuote.text != "오늘의 명언을 불러오는 중..." { return }
        
        QuoteManager.shared.fetchQuote { quote in
            if let quote = quote {
                withAnimation {
                    self.todayQuote = quote
                }
            } else {
                self.todayQuote = Quote(text: "실패는 성공의 어머니이다.", author: "에디슨")
            }
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    private func deleteGoals(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
    }
}

// MARK: - Subviews (기존 코드 유지)

struct QuoteCard: View {
    let quote: Quote
    @State private var displayedText: String = ""
    @State private var typingTimer: Timer?
    private let chalkboardGreen = Color(red: 0.15, green: 0.35, blue: 0.2)
    private let woodBrown = Color(red: 0.55, green: 0.35, blue: 0.15)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "quote.opening").font(.title2).foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            Text(displayedText)
                .font(.custom("ChalkboardSE-Bold", size: 20))
                .foregroundColor(.white)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 60, alignment: .topLeading)
                .animation(.none, value: displayedText)
            HStack {
                Spacer()
                Text("- \(quote.author) -")
                    .font(.custom("ChalkboardSE-Light", size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 5)
            }
            
            HStack(spacing: 15) {
                Spacer()
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.9)).frame(width: 40, height: 8).rotationEffect(.degrees(-5))
                VStack(spacing: 0) {
                    Rectangle().fill(woodBrown).frame(width: 35, height: 8)
                    Rectangle().fill(Color.gray).frame(width: 35, height: 12)
                }
                .cornerRadius(3)
            }
            .padding(.top, 15)
        }
        .padding(20).background(chalkboardGreen)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(woodBrown, lineWidth: 6))
        .cornerRadius(15).shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
        .onAppear { if displayedText.isEmpty { startTypewriter() } }
        .onChange(of: quote.text) { _, _ in startTypewriter() }
    }
    
    func startTypewriter() {
        typingTimer?.invalidate()
        displayedText = ""
        var charIndex = 0
        let chars = Array(quote.text)
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if charIndex < chars.count { displayedText.append(chars[charIndex]); charIndex += 1 } else { timer.invalidate() }
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    let userId: String
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    @Query private var records: [StudyRecord]
    @Query private var scheduleItems: [ScheduleItem]
    
    init(goal: Goal, userId: String) {
        self.goal = goal
        self.userId = userId
        _records = Query(filter: #Predicate<StudyRecord> { record in record.ownerID == userId })
        _scheduleItems = Query(filter: #Predicate<ScheduleItem> { item in item.ownerID == userId })
    }
    
    var currentEmoji: String {
        let calendar = Calendar.current
        let timerDays = records.map { calendar.startOfDay(for: $0.date) }
        let plannerDays = scheduleItems.filter { $0.isCompleted }.map { calendar.startOfDay(for: $0.startDate) }
        let uniqueDays = Set(timerDays + plannerDays).count
        return CharacterLevel.getLevel(currentDays: uniqueDays, totalGoalDays: goal.totalDays).emoji
    }
    
    var dDay: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: goal.targetDate)
        let components = calendar.dateComponents([.day], from: today, to: target)
        if let days = components.day {
            if days == 0 { return "D-Day" } else if days > 0 { return "D-\(days)" } else { return "D+\(-days)" }
        }
        return "Error"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goal.title).font(.title3).fontWeight(.bold).foregroundColor(.white)
                    if goal.hasCharacter {
                        Text(currentEmoji).font(.title3).padding(6).background(Color.white.opacity(0.2)).clipShape(Circle())
                    }
                }
                Text(goal.targetDate, style: .date).font(.caption).foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Text(dDay).font(.title).fontWeight(.black).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 6).background(Color.white.opacity(0.2)).cornerRadius(10)
        }
        .padding()
        .background(LinearGradient(gradient: Gradient(colors: [brandColor, brandColor.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(15).shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 5)
        .padding(.vertical, 5).listRowSeparator(.hidden)
    }
}
