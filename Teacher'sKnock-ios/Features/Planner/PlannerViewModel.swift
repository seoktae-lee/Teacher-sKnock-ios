import Foundation
import SwiftData
import SwiftUI
import Combine

class PlannerViewModel: ObservableObject {
    
    // 뷰에서 선택된 날짜를 관리
    @Published var selectedDate: Date = Date()
    
    // 1. 일정 추가 로직 (뷰는 이 함수만 부르면 됨)
    func addSchedule(
        title: String,
        details: String,
        startDate: Date,
        endDate: Date,
        hasReminder: Bool,
        ownerID: String,
        context: ModelContext // 뷰에서 컨텍스트를 넘겨받음
    ) {
        let newItem = ScheduleItem(
            title: title,
            details: details,
            startDate: startDate,
            endDate: endDate,
            isCompleted: false,
            hasReminder: hasReminder,
            ownerID: ownerID,
            isPostponed: false
        )
        
        // 1. 내 폰에 저장 (SwiftData)
        context.insert(newItem)
        
        // 2. 서버에 백업 (Firestore) - ViewModel이 알아서 처리
        FirestoreSyncManager.shared.saveSchedule(newItem)
        
        print("PlannerVM: 일정 저장 완료 - \(title)")
    }
    
    // 2. 일정 삭제 로직
    func deleteSchedule(_ item: ScheduleItem, context: ModelContext) {
        context.delete(item)
        // 추후 서버 삭제 로직도 여기에 추가하면 됨
    }
}
