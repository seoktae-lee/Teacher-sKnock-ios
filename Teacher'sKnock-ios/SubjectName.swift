import Foundation

// 초등 임용고시 과목을 정의하는 Enum
enum SubjectName: String, Codable, CaseIterable, Identifiable {
    case education = "교육학"
    case teachingEssay = "교직논술"
    case korean = "국어"
    case math = "수학"
    case socialStudies = "사회"
    case science = "과학"
    case english = "영어"
    case ethics = "도덕"
    case pe = "체육"
    case music = "음악"
    case art = "미술"
    case practicalArts = "실과"
    case rightLiving = "바른생활"
    case wiseLiving = "슬기로운생활"
    case pleasantLiving = "즐거운생활"
    case generalCreative = "총론/창의적체험활동"
    case secondRound = "2차 면접/실연"
    case selfStudy = "자율선택"

    var id: String { self.rawValue }
    var localizedName: String { return self.rawValue }

    // 기본 과목 목록 (최초 설정 시 사용)
    static var defaultSubjects: [SubjectName] {
        return [.education, .teachingEssay, .korean, .math, .socialStudies, .science, .english, .generalCreative]
    }
}
