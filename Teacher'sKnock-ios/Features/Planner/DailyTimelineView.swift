import SwiftUI
import SwiftData // ✨ 필수!

struct DailyTimelineView: View {
    let schedules: [ScheduleItem]
    var draftSchedule: ScheduleItem? = nil
    var onItemTap: ((ScheduleItem) -> Void)? = nil
    
    private let startHour = 0
    private let endHour = 24
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height > 0 ? geometry.size.height : 600
            let hourHeight = totalHeight / CGFloat(endHour - startHour)
            let totalWidth = geometry.size.width
            
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        HStack(spacing: 0) {
                            let isMajor = hour % 6 == 0
                            let showLabel = hour % 2 == 0
                            Text(showLabel ? "\(hour)" : "")
                                .font(.system(size: isMajor ? 11 : 10, weight: isMajor ? .bold : .medium))
                                .foregroundColor(isMajor ? .black.opacity(0.7) : .gray.opacity(0.6))
                                .frame(width: 25, alignment: .trailing).padding(.trailing, 5).offset(y: -6)
                            VStack { Divider().background(isMajor ? Color.gray.opacity(0.3) : .clear) }
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }
                
                let layoutMap = calculateLayout(for: schedules)
                ForEach(schedules) { item in
                    let color = SubjectName.color(for: item.title)
                    let (index, totalCols) = layoutMap[item.id] ?? (0, 1)
                    let blockWidth = (totalWidth - 35) / CGFloat(totalCols)
                    let xOffset = 35 + (blockWidth * CGFloat(index))
                    
                    scheduleBlock(for: item, color: color, hourHeight: hourHeight, width: blockWidth)
                        .position(x: xOffset + blockWidth/2, y: calculateCenterY(for: item, hourHeight: hourHeight))
                        .onTapGesture { onItemTap?(item) }
                }
                
                if let draft = draftSchedule {
                    let blockWidth = totalWidth - 35
                    scheduleBlock(for: draft, color: .orange, hourHeight: hourHeight, width: blockWidth)
                        .position(x: 35 + blockWidth/2, y: calculateCenterY(for: draft, hourHeight: hourHeight))
                        .opacity(0.85).zIndex(100)
                }
            }
            .contentShape(Rectangle())
        }
        .padding(.vertical, 10)
    }
    
    private func calculateCenterY(for item: ScheduleItem, hourHeight: CGFloat) -> CGFloat {
        let cal = Calendar.current
        let startHour = cal.component(.hour, from: item.startDate)
        let startMin = cal.component(.minute, from: item.startDate)
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        
        let topOffset = (CGFloat(startHour - self.startHour) * hourHeight) + (CGFloat(startMin) / 60.0 * hourHeight)
        let visualHeight = max(CGFloat(duration / 3600.0) * hourHeight, 30)
        return topOffset + (visualHeight / 2)
    }
    
    private func scheduleBlock(for item: ScheduleItem, color: Color, hourHeight: CGFloat, width: CGFloat) -> some View {
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let duration = end.timeIntervalSince(item.startDate)
        let visualHeight = max(CGFloat(duration / 3600.0) * hourHeight, 30)
        let isCompleted = item.isCompleted
        let isPostponed = item.isPostponed
        
        let opacity = isPostponed ? 0.15 : (isCompleted ? 0.2 : 0.45)
        let saturation = (isCompleted || isPostponed) ? 0.0 : 1.0
        let strokeOpacity = isPostponed ? 0.2 : (isCompleted ? 0.3 : 0.8)
        
        return AnyView(
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(opacity)).saturation(saturation)
                    .overlay(
                        HStack(spacing: 0) {
                            Rectangle().fill(color).saturation(saturation).frame(width: 3)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.title.isEmpty ? "(새 일정)" : item.title)
                                    .font(.system(size: 10, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                                    .strikethrough(isCompleted || isPostponed)
                                    .foregroundColor(.primary.opacity((isCompleted || isPostponed) ? 0.5 : 0.9))
                                if visualHeight > 35 {
                                    Text("\(item.startDate.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 8)).foregroundColor(.secondary.opacity((isCompleted || isPostponed) ? 0.5 : 1.0))
                                }
                            }
                            .padding(.leading, 4).padding(.vertical, 1)
                            Spacer()
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(strokeOpacity), lineWidth: 1).saturation(saturation))
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(color)
                        .background(Circle().fill(.white).padding(1)).shadow(radius: 1)
                } else if isPostponed {
                    Image(systemName: "arrow.turn.up.right").font(.title3).foregroundColor(.gray)
                        .padding(4).background(Circle().fill(.white.opacity(0.8))).shadow(radius: 1)
                }
            }
            .padding(.horizontal, 1).frame(width: width, height: visualHeight).contentShape(Rectangle())
        )
    }
    
    private func calculateLayout(for items: [ScheduleItem]) -> [PersistentIdentifier: (Int, Int)] {
        let sorted = items.sorted { $0.startDate < $1.startDate }
        var map: [PersistentIdentifier: (Int, Int)] = [:]
        var columns: [[ScheduleItem]] = []
        
        for item in sorted {
            var placed = false
            for (i, col) in columns.enumerated() {
                if let last = col.last {
                    let lastEnd = last.endDate ?? last.startDate.addingTimeInterval(3600)
                    if item.startDate >= lastEnd {
                        columns[i].append(item); placed = true; break
                    }
                }
            }
            if !placed { columns.append([item]) }
        }
        for (i, col) in columns.enumerated() {
            for item in col { map[item.id] = (i, columns.count) }
        }
        return map
    }
}
