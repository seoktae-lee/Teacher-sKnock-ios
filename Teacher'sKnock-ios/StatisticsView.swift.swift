import SwiftUI
import SwiftData
import Charts // ✨ 차트 기능을 위해 필수!

struct StatisticsView: View {
    // 저장된 공부 기록 불러오기 (최신순 정렬)
    @Query(sort: \StudyRecord.date, order: .reverse) private var records: [StudyRecord]
    
    // 브랜드 색상
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    // 차트에 들어갈 데이터 구조체
    struct SubjectData: Identifiable {
        let id = UUID()
        let subject: String
        let totalSeconds: Int
    }
    
    // 공부 기록을 과목별로 합산하는 계산 로직
    var chartData: [SubjectData] {
        // 1. 과목별로 시간 합치기 (Dictionary 사용)
        var dict: [String: Int] = [:]
        for record in records {
            dict[record.areaName, default: 0] += record.durationSeconds
        }
        
        // 2. 차트용 데이터 배열로 변환 및 공부 시간 순 정렬
        return dict.map { SubjectData(subject: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds }
    }
    
    // 총 공부 시간 계산 문자열
    var totalStudyTime: String {
        let totalSeconds = records.reduce(0) { $0 + $1.durationSeconds }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return "\(hours)시간 \(minutes)분"
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
                        Text(totalStudyTime)
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
                                SectorMark(
                                    angle: .value("시간", item.totalSeconds),
                                    innerRadius: .ratio(0.5), // 도넛 모양
                                    angularInset: 1.5 // 조각 간격
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("과목", item.subject))
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
                                    // 초 단위를 시간 분으로 변환 표시
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
                        // 데이터가 없을 때 표시
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
            .background(Color(.systemGray6)) // 전체 배경색
            .navigationTitle("학습 통계")
        }
    }
}

#Preview {
    StatisticsView()
}
