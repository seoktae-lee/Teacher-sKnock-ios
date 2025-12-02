import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var records: [StudyRecord]
    
    // ✨ 상세 화면 전달용 ID 저장
    let userId: String
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 생성자
    init(userId: String) {
        self.userId = userId
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        }, sort: \.date, order: .reverse)
    }
    
    struct SubjectData: Identifiable {
        let id = UUID()
        let subject: String
        let totalSeconds: Int
    }
    
    var chartData: [SubjectData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    var totalSecondsAll: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var totalStudyTimeString: String {
        let h = totalSecondsAll / 3600
        let m = (totalSecondsAll % 3600) / 60
        return "\(h)시간 \(m)분"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    
                    // 1. 총 공부 시간 요약
                    VStack {
                        Text("총 누적 공부 시간")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text(totalStudyTimeString)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(brandColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    .padding(.horizontal)
                    
                    // 2. 과목별 파이 차트
                    if !chartData.isEmpty {
                        VStack(alignment: .leading) {
                            Text("과목별 비중")
                                .font(.title2)
                                .bold()
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
                                            .font(.headline)
                                            .fontWeight(.heavy)
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                                    }
                                }
                            }
                            .frame(height: 300)
                            .padding()
                        }
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                        
                        // 3. 상세 리스트 (클릭 가능하도록 수정됨 ✨)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("과목별 상세 기록")
                                .font(.headline)
                                .padding()
                            
                            ForEach(chartData) { item in
                                // ✨ 네비게이션 링크 추가
                                NavigationLink(destination: SubjectDetailView(subjectName: item.subject, userId: userId)) {
                                    HStack {
                                        Text(item.subject)
                                            .bold()
                                            .foregroundColor(.primary)
                                        Spacer()
                                        
                                        let h = item.totalSeconds / 3600
                                        let m = (item.totalSeconds % 3600) / 60
                                        Text("\(h)시간 \(m)분")
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.leading, 5)
                                    }
                                    .padding()
                                    .background(Color.white) // 터치 영역 확보
                                }
                                Divider()
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                        
                    } else {
                        // 데이터 없음
                        VStack(spacing: 20) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.3))
                            Text("아직 공부 기록이 없습니다.\n타이머를 실행해서 기록을 쌓아보세요!")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                        }
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.1), radius: 5)
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .background(Color(.systemGray6))
            .navigationTitle("학습 통계")
        }
    }
}

#Preview {
    StatisticsView(userId: "test_user")
}
