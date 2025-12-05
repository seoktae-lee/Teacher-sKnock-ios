import Foundation
import SwiftData
import SwiftUI
import Combine

class DailyDetailViewModel: ObservableObject {
    private var modelContext: ModelContext?
    let userId: String
    let targetDate: Date
    
    @Published var schedules: [ScheduleItem] = []
    @Published var records: [StudyRecord] = []
    
    struct ChartData: Identifiable {
        let id = UUID()
        let subject: String
        let seconds: Int
        var color: Color {
            if let matched = SubjectName.allCases.first(where: { $0.rawValue == subject }) { return matched.color }
            return .gray
        }
    }
    
    init(userId: String, targetDate: Date) {
        self.userId = userId
        self.targetDate = targetDate
    }
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        fetchData()
    }
    
    func fetchData() {
        guard let context = modelContext else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let scheduleDescriptor = FetchDescriptor<ScheduleItem>(
            predicate: #Predicate { item in
                item.ownerID == userId &&
                item.startDate < endOfDay &&
                (item.endDate ?? item.startDate) > startOfDay
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        
        let recordDescriptor = FetchDescriptor<StudyRecord>(
            predicate: #Predicate { record in
                record.ownerID == userId && record.date >= startOfDay && record.date < endOfDay
            }
        )
        
        do {
            self.schedules = try context.fetch(scheduleDescriptor)
            self.records = try context.fetch(recordDescriptor)
        } catch {
            print("데이터 로드 실패: \(error)")
        }
    }
    
    var pieData: [ChartData] {
        var dict: [String: Int] = [:]
        for record in records { dict[record.areaName, default: 0] += record.durationSeconds }
        return dict.map { ChartData(subject: $0.key, seconds: $0.value) }
    }
    
    var totalActualSeconds: Int { pieData.reduce(0) { $0 + $1.seconds } }
    
    var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 (EEEE)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: targetDate)
    }
    
    // MARK: - 비즈니스 로직
    
    func duplicateToTomorrow(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        
        let oneDaySeconds: TimeInterval = 86400
        let newStart = item.startDate.addingTimeInterval(oneDaySeconds)
        let newEnd = item.endDate?.addingTimeInterval(oneDaySeconds)
        
        let newItem = ScheduleItem(
            title: item.title,
            details: item.details,
            startDate: newStart,
            endDate: newEnd,
            isCompleted: false,
            hasReminder: item.hasReminder,
            ownerID: item.ownerID,
            isPostponed: false
        )
        
        context.insert(newItem)
        FirestoreSyncManager.shared.saveSchedule(newItem)
        
        // 원본 상태 변경 (미뤄짐 처리)
        item.isPostponed = true
        item.isCompleted = false
        
        saveContext()
        fetchData()
    }
    
    // ✨ [추가됨] 미루기 취소 (다시 오늘 할 일로 복구)
    func cancelPostpone(_ item: ScheduleItem) {
        // 미뤄짐 상태 해제
        item.isPostponed = false
        // (선택 사항) 복구 시 완료 상태는 false로 두는 것이 일반적
        // item.isCompleted = false
        
        // *주의: 이미 내일로 복제된 일정은 자동으로 삭제되지 않습니다.
        // (사용자가 내일 일정을 이미 수정했을 수도 있기 때문)
        
        saveContext()
        fetchData()
    }
    
    func deleteSchedule(_ item: ScheduleItem) {
        guard let context = modelContext else { return }
        context.delete(item)
        saveContext()
        fetchData()
    }
    
    func toggleComplete(_ item: ScheduleItem) {
        if !item.isPostponed {
            item.isCompleted.toggle()
            saveContext()
        }
    }
    
    private func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            print("저장 실패: \(error)")
        }
    }
}
