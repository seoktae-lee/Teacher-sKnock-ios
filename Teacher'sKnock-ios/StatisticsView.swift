import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    // 저장된 공부 기록 불러오기
    @Query private var records: [StudyRecord]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 생성자: 내 ID에 해당하는 공부 기록만 필터링
    init(userId: String) {
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId
        }, sort: \.date, order: .reverse)
    }
    
    struct SubjectData: Identifiable {
        let id = UUID()
        let subject: String
        let totalSeconds: Int
    }
    
    // 차트 데이터 계산
    var chartData: [SubjectData] {
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        return dict.map { SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    // 전체 총 공부 시간 (초 단위)
    var totalSecondsAll: Int {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
    
    // 표시용 문자열
    var totalStudyTimeString: String {
        let h = totalSecondsAll / 3600
        let m = (totalSecondsAll % 3600) / 60
        return "\(h)시간 \(m)분"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    
                    // 1. 총 공부 시간 요약 카드
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
                            
                            // ✨ 차트 영역
                            Chart(chartData) { item in
                                // 퍼센트 계산
                                let percentage = Double(item.totalSeconds) / Double(totalSecondsAll) * 100
                                
                                SectorMark(
                                    angle: .value("시간", item.totalSeconds),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1.0
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("과목", item.subject))
                                // ✨ 퍼센트 텍스트 (크기 확대 및 그림자 강화)
                                .annotation(position: .overlay) {
                                    if percentage >= 5 { // 5% 이상일 때만 표시
                                        Text(String(format: "%.0f%%", percentage))
                                            .font(.headline) // caption -> headline으로 키움
                                            .fontWeight(.heavy) // 굵기도 더 굵게
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1) // 그림자 진하게
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
                        
                        // 3. 상세 리스트
                        VStack(alignment: .leading, spacing: 15) {
                            Text("과목별 상세 기록")
                                .font(.headline)
                                .padding(.leading)
                                .padding(.top)
                            
                            ForEach(chartData) { item in
                                HStack {
                                    Text(item.subject)
                                        .bold()
                                    Spacer()
                                    let h = item.totalSeconds / 3600
                                    let m = (item.totalSeconds % 3600) / 60
                                    Text("\(h)시간 \(m)분")
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                                Divider()
                            }
                            .padding(.bottom)
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
