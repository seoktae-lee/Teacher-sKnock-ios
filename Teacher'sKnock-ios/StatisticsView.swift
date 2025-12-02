import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var records: [StudyRecord]
    
    // 상세 화면 전달용 ID
    let userId: String
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    init(userId: String) {
        self.userId = userId
        // 내 데이터만, 최신순 정렬
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        }, sort: \.date, order: .reverse)
    }
    
    // 데이터 구조체
    struct SubjectData: Identifiable {
        let id = UUID()
        let subject: String
        let totalSeconds: Int
    }
    
    // ✨ 오늘 공부한 시간만 필터링 (오늘 공부량 확인용)
    var todaySeconds: Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    // 전체 누적 시간
    var totalSecondsAll: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    // 차트 데이터 (전체 기준)
    var chartData: [SubjectData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    // 시간 포맷팅 함수 (분 단위까지만 표시)
    func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)시간 \(m)분"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. ✨ 시간 요약 카드 (오늘 vs 전체)
                    HStack(spacing: 15) {
                        // 오늘 공부 시간 (강조)
                        VStack(spacing: 5) {
                            Text("오늘 공부")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formatTime(seconds: todaySeconds))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(brandColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        
                        // 전체 누적 시간
                        VStack(spacing: 5) {
                            Text("총 누적")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formatTime(seconds: totalSecondsAll))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 2. 과목별 파이 차트
                    if !chartData.isEmpty {
                        VStack(alignment: .leading) {
                            Text("과목별 공부 비중 (전체)")
                                .font(.headline)
                                .padding(.leading)
                                .padding(.top)
                            
                            Chart(chartData) { item in
                                let percentage = Double(item.totalSeconds) / Double(totalSecondsAll) * 100
                                
                                SectorMark(
                                    angle: .value("시간", item.totalSeconds),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1.0
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("과목", item.subject))
                                .annotation(position: .overlay) {
                                    if percentage >= 5 {
                                        Text(String(format: "%.0f%%", percentage))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.4), radius: 1, x: 1, y: 1)
                                    }
                                }
                            }
                            .frame(height: 250)
                            .padding()
                        }
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                        
                        // 3. 상세 리스트
                        VStack(alignment: .leading, spacing: 0) {
                            Text("과목별 상세 기록")
                                .font(.headline)
                                .padding()
                            
                            ForEach(chartData) { item in
                                // 기존에 있는 SubjectDetailView로 연결 (이제 충돌 없음!)
                                NavigationLink(destination: SubjectDetailView(subjectName: item.subject, userId: userId)) {
                                    HStack {
                                        Text(item.subject)
                                            .bold()
                                            .foregroundColor(.primary)
                                        Spacer()
                                        
                                        Text(formatTime(seconds: item.totalSeconds))
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.leading, 5)
                                    }
                                    .padding()
                                    .background(Color.white)
                                }
                                Divider()
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                        
                    } else {
                        // 데이터 없을 때 (Empty State)
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20)
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.2))
                            Text("아직 공부 기록이 없습니다.\n오늘의 첫 공부를 시작해보세요!")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                                .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("학습 통계")
        }
    }
}

#Preview {
    StatisticsView(userId: "preview_user")
        .modelContainer(for: StudyRecord.self, inMemory: true)
}
