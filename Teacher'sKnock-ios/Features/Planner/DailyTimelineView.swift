import SwiftUI
import SwiftData
import Combine

struct DailyTimelineView: View {
    @StateObject private var viewModel = DailyTimelineViewModel()
    
    // 이 뷰가 나타내는 날짜
    let date: Date
    let schedules: [ScheduleItem]
    var draftSchedule: ScheduleItem? = nil
    var onItemTap: ((ScheduleItem) -> Void)? = nil
    
    init(date: Date = Date(), schedules: [ScheduleItem], draftSchedule: ScheduleItem? = nil, onItemTap: ((ScheduleItem) -> Void)? = nil) {
        self.date = date
        self.schedules = schedules
        self.draftSchedule = draftSchedule
        self.onItemTap = onItemTap
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height > 0 ? geometry.size.height : 600
            let hourHeight = totalHeight / CGFloat(viewModel.endHour - viewModel.startHour)
            let totalWidth = geometry.size.width
            
            ZStack(alignment: .topLeading) {
                // 1. 배경 그리드
                drawGrid(totalWidth: totalWidth, hourHeight: hourHeight)
                
                // 2. 일정 블록
                // ✨ date를 직접 넘겨서 계산
                let layoutMap = viewModel.calculateLayout(for: schedules, on: date)
                
                ForEach(schedules) { item in
                    // 오늘 날짜에 그릴 부분이 있는 일정만 표시
                    if viewModel.getEffectiveRange(for: item, on: date) != nil {
                        drawScheduleBlock(item: item, layoutMap: layoutMap, totalWidth: totalWidth, hourHeight: hourHeight)
                            .onTapGesture { onItemTap?(item) }
                    }
                }
                
                // 3. 임시 일정 (작성 중)
                if let draft = draftSchedule, viewModel.getEffectiveRange(for: draft, on: date) != nil {
                    let blockWidth = totalWidth - 35
                    let centerY = viewModel.calculateCenterY(for: draft, hourHeight: hourHeight, on: date)
                    
                    scheduleBlock(for: draft, color: .orange, hourHeight: hourHeight, width: blockWidth)
                        .position(x: 35 + blockWidth/2, y: centerY)
                        .opacity(0.85).zIndex(100)
                }
            }
            .clipped()
            .contentShape(Rectangle())
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Subviews
    private func drawGrid(totalWidth: CGFloat, hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(viewModel.startHour..<viewModel.endHour, id: \.self) { hour in
                HStack(spacing: 0) {
                    let showLabel = hour % 2 == 0
                    Text(showLabel ? "\(hour)" : "")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                        .frame(width: 25, alignment: .trailing)
                        .padding(.trailing, 5)
                        .offset(y: -6)
                    VStack { Divider().background(hour % 6 == 0 ? Color.gray.opacity(0.5) : Color.gray.opacity(0.2)) }
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }
    
    private func drawScheduleBlock(item: ScheduleItem, layoutMap: [PersistentIdentifier: (Int, Int)], totalWidth: CGFloat, hourHeight: CGFloat) -> some View {
        let color = SubjectName.color(for: item.title)
        let (index, totalCols) = layoutMap[item.id] ?? (0, 1)
        
        let blockWidth = (totalWidth - 35) / CGFloat(totalCols)
        let xOffset = 35 + (blockWidth * CGFloat(index))
        // ✨ date 전달
        let centerY = viewModel.calculateCenterY(for: item, hourHeight: hourHeight, on: date)
        
        return scheduleBlock(for: item, color: color, hourHeight: hourHeight, width: blockWidth)
            .position(x: xOffset + blockWidth/2, y: centerY)
    }
    
    private func scheduleBlock(for item: ScheduleItem, color: Color, hourHeight: CGFloat, width: CGFloat) -> some View {
        let style = viewModel.getBlockStyle(isCompleted: item.isCompleted, isPostponed: item.isPostponed)
        // ✨ date 전달
        let visualHeight = viewModel.getVisualHeight(for: item, hourHeight: hourHeight, on: date)
        
        let startStr = timeFormatter.string(from: item.startDate)
        let end = item.endDate ?? item.startDate.addingTimeInterval(3600)
        let endStr = timeFormatter.string(from: end)
        let timeRangeString = "(\(startStr)-\(endStr))"
        
        // ✨ date 전달
        let continuesFromYesterday = viewModel.isContinuingFromYesterday(item, on: date)
        let continuesToTomorrow = viewModel.isContinuingToTomorrow(item, on: date)
        
        return ZStack {
            // 배경 모양 (이어지는 쪽은 모서리 직각 처리)
            UnevenRoundedRectangle(
                topLeadingRadius: continuesFromYesterday ? 0 : 6,
                bottomLeadingRadius: continuesToTomorrow ? 0 : 6,
                bottomTrailingRadius: continuesToTomorrow ? 0 : 6,
                topTrailingRadius: continuesFromYesterday ? 0 : 6
            )
            .fill(color.opacity(style.opacity))
            .saturation(style.saturation)
            // 텍스트 내용
            .overlay(
                HStack(spacing: 0) {
                    Rectangle().fill(color).saturation(style.saturation).frame(width: 3)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(item.title.isEmpty ? "(새 일정)" : item.title).fontWeight(.bold)
                            if width > 60 { Text(timeRangeString).fontWeight(.regular).opacity(0.8) }
                        }
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundColor(.primary.opacity(0.9))
                    }
                    .padding(.leading, 4).padding(.vertical, 2)
                    Spacer()
                }
            )
            // 테두리
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: continuesFromYesterday ? 0 : 6,
                    bottomLeadingRadius: continuesToTomorrow ? 0 : 6,
                    bottomTrailingRadius: continuesToTomorrow ? 0 : 6,
                    topTrailingRadius: continuesFromYesterday ? 0 : 6
                )
                .stroke(color.opacity(style.strokeOpacity), lineWidth: 1)
            )
            
            // ✨ [화살표] 상단 (어제에서 옴) - overlay로 고정
            .overlay(alignment: .top) {
                if continuesFromYesterday {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 8))
                        .foregroundColor(color)
                        .padding(.top, 2)
                }
            }
            
            // ✨ [화살표] 하단 (내일로 감) - overlay로 고정
            .overlay(alignment: .bottom) {
                if continuesToTomorrow {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                        .foregroundColor(color)
                        .padding(.bottom, 2)
                }
            }
        }
        .padding(.horizontal, 1)
        .frame(width: width, height: visualHeight)
        .contentShape(Rectangle())
    }
}
