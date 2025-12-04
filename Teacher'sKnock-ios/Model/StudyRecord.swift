import Foundation
import SwiftData

@Model
final class StudyRecord {
    // 공부한 시간 (초 단위)
    var durationSeconds: Int
    
    // 공부한 과목/영역 이름 (예: 교육학)
    var areaName: String
    
    // 기록 날짜
    var date: Date
    
    // 주인 이름표 (누가 공부했는지 저장)
    var ownerID: String
    
    // ✨ 새로 추가된 필드: 공부 목적 (StudyPurpose.rawValue 저장)
    var studyPurpose: String

    init(durationSeconds: Int, areaName: String, date: Date = Date(), ownerID: String, studyPurpose: String) {
        self.durationSeconds = durationSeconds
        self.areaName = areaName
        self.date = date
        self.ownerID = ownerID
        self.studyPurpose = studyPurpose // 초기화에 추가
    }
}
