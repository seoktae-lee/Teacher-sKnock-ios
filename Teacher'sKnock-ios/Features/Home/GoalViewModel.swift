import Foundation
import SwiftData
import SwiftUI
import Combine

class GoalViewModel: ObservableObject {
    
    // 뷰에서 입력받을 데이터들
    @Published var title: String = ""
    @Published var targetDate: Date = Date()
    @Published var useCharacter: Bool = true
    
    // 목표 저장 로직
    func addGoal(ownerID: String, context: ModelContext) {
        // 유효성 검사 (제목이 비어있으면 저장 안 함)
        if title.isEmpty { return }
        
        // 모델 생성
        let newGoal = Goal(
            title: title,
            targetDate: targetDate,
            ownerID: ownerID,
            hasCharacter: useCharacter
        )
        
        // 1. 로컬 저장 (SwiftData)
        context.insert(newGoal)
        
        // 2. 서버 저장? (아직 구현 안 했지만 자리는 만들어둠)
        // FirestoreSyncManager.shared.saveGoal(newGoal) <- 나중에 추가 가능
        
        print("GoalVM: 목표 저장 완료 - \(title)")
    }
}
