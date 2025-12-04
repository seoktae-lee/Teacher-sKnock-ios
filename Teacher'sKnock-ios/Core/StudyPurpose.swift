import Foundation

// 공부 목적을 정의하는 Enum
enum StudyPurpose: String, Codable, CaseIterable {
    case lectureWatching = "인강시청"
    case reviewOrganize = "복습/정리"
    case conceptMemorization = "개념공부"
    case problemSolving = "문제풀이"
    case mockTest = "모의고사"
    case errorNote = "오답노트"
    case etc = "기타"

    var localizedName: String { return self.rawValue }
    
    // UI 표시 순서 정의
    static var orderedCases: [StudyPurpose] {
        return [.lectureWatching, .reviewOrganize, .conceptMemorization, .problemSolving, .mockTest, .errorNote, .etc]
    }
}
