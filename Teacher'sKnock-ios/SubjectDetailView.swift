import SwiftUI
import SwiftData
import Charts

struct SubjectDetailView: View {
    let subjectName: String
    let userId: String
    
    // 해당 과목의 기록만 가져오기
    @Query private var records: [StudyRecord]
    
    private let brandColor = Color(red: 0.35, green: 0.65, blue: 0.95)
    
    init(subjectName: String, userId: String) {
        self.subjectName = subjectName
        self.userId = userId
        
        // 필터링: 내 아이디 && 선택한 과목
        _records = Query(filter: #Predicate<StudyRecord> { record in
            record.ownerID == userId && record.areaName == subjectName
        })
    }
    
    // 목적별 데이터 구조체
    struct PurposeData: Identifiable {
        let id = UUID()
        let purpose: String
        let totalSeconds: Int
    }
    
    // 목적별 합산 로직
    var purposeData: [PurposeData] {
        var dict: [String: Int] = [:]
        for record in records {
            // 저장된 studyPurpose가 없거나 비어있으면 "기타"로 분류
            let purpose = record.studyPurpose.isEmpty ? "기타" : record.studyPurpose
            dict[purpose, default: 0] += record.durationSeconds
        }
        return dict.map { PurposeData(purpose: $0.key, totalSeconds: $0.value) }
                   .sorted { $0.totalSeconds > $1.totalSeconds } // 시간순 정렬
    }
    
    var totalTime: String {
        let total = records.reduce(0) { $0 + $1.durationSeconds }
        let h = total / 3600
        let m = (total % 3600) / 60
        return "\(h)시간 \(m)분"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // 1. 헤더 (총 시간)
                VStack(spacing: 5) {
                    Text(subjectName)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("총 \(totalTime)")
                        .font(.headline)
                        .foregroundColor(brandColor)
                }
                .padding(.top, 20)
                
                if !purposeData.isEmpty {
                    // 2. 목적별 막대 그래프 (Bar Chart)
                    VStack(alignment: .leading) {
                        Text("학습 유형 분석")
                            .font(.headline)
                            .padding(.bottom, 10)
                        
                        Chart(purposeData) { item in
                            BarMark(
                                x: .value("시간", item.totalSeconds),
                                y: .value("목적", item.purpose)
                            )
                            .foregroundStyle(brandColor.gradient)
                            .cornerRadius(5)
                            .annotation(position: .trailing) {
                                let h = item.totalSeconds / 3600
                                let m = (item.totalSeconds % 3600) / 60
                                Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(height: 250)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    .padding(.horizontal)
                    
                    // 3. 상세 리스트
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(purposeData) { item in
                            HStack {
                                Text(item.purpose)
                                    .fontWeight(.medium)
                                Spacer()
                                let h = item.totalSeconds / 3600
                                let m = (item.totalSeconds % 3600) / 60
                                Text("\(h)시간 \(m)분")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            Divider()
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: .gray.opacity(0.1), radius: 5)
                    .padding(.horizontal)
                    
                } else {
                    Text("기록이 없습니다.")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
    }
}
