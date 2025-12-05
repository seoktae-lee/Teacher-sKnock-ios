import Foundation
import SwiftData
import SwiftUI
import Combine

class DailyTimelineViewModel: ObservableObject {
    
    let startHour = 0
    let endHour = 24
    
    // MARK: - Layout Logic
    
    // ✨ 날짜(date)를 인자로 받아서 계산
    func calculateLayout(for items: [ScheduleItem], on date: Date) -> [PersistentIdentifier: (Int, Int)] {
        let activeItems = items.filter { getEffectiveRange(for: $0, on: date) != nil }
        
        let sorted = activeItems.sorted {
            let range1 = getEffectiveRange(for: $0, on: date)!
            let range2 = getEffectiveRange(for: $1, on: date)!
            return range1.start < range2.start
        }
        
        var map: [PersistentIdentifier: (Int, Int)] = [:]
        if sorted.isEmpty { return map }
        
        var clusters: [[ScheduleItem]] = []
        var currentCluster: [ScheduleItem] = [sorted[0]]
        var clusterEnd = getEffectiveRange(for: sorted[0], on: date)!.end
        
        for i in 1..<sorted.count {
            let item = sorted[i]
            let range = getEffectiveRange(for: item, on: date)!
            
            if range.start < clusterEnd {
                currentCluster.append(item)
                if range.end > clusterEnd {
                    clusterEnd = range.end
                }
            } else {
                clusters.append(currentCluster)
                currentCluster = [item]
                clusterEnd = range.end
            }
        }
        clusters.append(currentCluster)
        
        for cluster in clusters {
            var columns: [[ScheduleItem]] = []
            
            for item in cluster {
                var placed = false
                let itemRange = getEffectiveRange(for: item, on: date)!
                
                for (colIndex, col) in columns.enumerated() {
                    var fits = true
                    for existing in col {
                        let existingRange = getEffectiveRange(for: existing, on: date)!
                        if itemRange.start < existingRange.end && existingRange.start < itemRange.end {
                            fits = false
                            break
                        }
                    }
                    if fits {
                        columns[colIndex].append(item)
                        placed = true
                        break
                    }
                }
                
                if !placed {
                    columns.append([item])
                }
            }
            
            let totalColsInCluster = columns.count
            for (colIndex, col) in columns.enumerated() {
                for item in col {
                    map[item.id] = (colIndex, totalColsInCluster)
                }
            }
        }
        
        return map
    }
    
    // MARK: - Helpers
    
    // 오늘 화면에 그릴 유효 범위 계산 (00:00 ~ 24:00 자르기)
    func getEffectiveRange(for item: ScheduleItem, on date: Date) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        
        let itemEnd = item.endDate ?? item.startDate.addingTimeInterval(3600)
        
        let effectiveStart = max(item.startDate, dayStart)
        let effectiveEnd = min(itemEnd, dayEnd)
        
        if effectiveStart >= effectiveEnd { return nil }
        
        return (effectiveStart, effectiveEnd)
    }
    
    func calculateCenterY(for item: ScheduleItem, hourHeight: CGFloat, on date: Date) -> CGFloat {
        guard let range = getEffectiveRange(for: item, on: date) else { return 0 }
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        let startOffset = range.start.timeIntervalSince(dayStart)
        let duration = range.end.timeIntervalSince(range.start)
        
        let topOffset = (CGFloat(startOffset) / 3600.0) * hourHeight
        let visualHeight = max(CGFloat(duration / 3600.0) * hourHeight, 30)
        
        return topOffset + (visualHeight / 2)
    }
    
    func getVisualHeight(for item: ScheduleItem, hourHeight: CGFloat, on date: Date) -> CGFloat {
        guard let range = getEffectiveRange(for: item, on: date) else { return 0 }
        let duration = range.end.timeIntervalSince(range.start)
        
        let height = max(CGFloat(duration / 3600.0) * hourHeight, 30)
        return height > 2 ? height - 1 : height
    }
    
    // ✨ 어제에서 이어지는가? (시작 시간이 오늘 0시보다 전이면 True)
    func isContinuingFromYesterday(_ item: ScheduleItem, on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return item.startDate < dayStart
    }
    
    // ✨ 내일로 이어지는가? (종료 시간이 내일 0시보다 후이면 True)
    func isContinuingToTomorrow(_ item: ScheduleItem, on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        // dayEnd = 내일 00:00
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        
        let itemEnd = item.endDate ?? item.startDate.addingTimeInterval(3600)
        
        // 24:00를 넘어가면 True
        return itemEnd > dayEnd
    }
    
    func getBlockStyle(isCompleted: Bool, isPostponed: Bool) -> (opacity: Double, saturation: Double, strokeOpacity: Double) {
        let opacity = isPostponed ? 0.15 : (isCompleted ? 0.2 : 0.45)
        let saturation = (isCompleted || isPostponed) ? 0.0 : 1.0
        let strokeOpacity = isPostponed ? 0.2 : (isCompleted ? 0.3 : 0.8)
        return (opacity, saturation, strokeOpacity)
    }
}
