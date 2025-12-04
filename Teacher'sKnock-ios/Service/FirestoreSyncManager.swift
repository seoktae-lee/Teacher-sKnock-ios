import Foundation
import FirebaseFirestore
import SwiftData

class FirestoreSyncManager {
    static let shared = FirestoreSyncManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - 1. 데이터 저장 (백업)
    
    // 일정 저장
    func saveSchedule(_ item: ScheduleItem) {
        let data: [String: Any] = [
            "id": item.persistentModelID.hashValue.description,
            "title": item.title,
            "details": item.details,
            "startDate": Timestamp(date: item.startDate),
            "endDate": item.endDate != nil ? Timestamp(date: item.endDate!) : NSNull(),
            "isCompleted": item.isCompleted,
            "isPostponed": item.isPostponed,
            "hasReminder": item.hasReminder,
            "ownerID": item.ownerID
        ]
        
        db.collection("users").document(item.ownerID).collection("schedules").addDocument(data: data)
    }
    
    // 공부 기록 저장
    func saveRecord(_ record: StudyRecord) {
        let data: [String: Any] = [
            "durationSeconds": record.durationSeconds,
            "areaName": record.areaName,
            "date": Timestamp(date: record.date),
            "ownerID": record.ownerID,
            "studyPurpose": record.studyPurpose
        ]
        
        db.collection("users").document(record.ownerID).collection("study_records").addDocument(data: data)
    }
    
    // MARK: - 2. 데이터 복구 (로그인 시 호출)
    
    @MainActor
    func restoreData(context: ModelContext, uid: String, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        // (1) 일정 복구
        group.enter()
        db.collection("users").document(uid).collection("schedules").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                for doc in documents {
                    let data = doc.data()
                    
                    let title = data["title"] as? String ?? ""
                    let details = data["details"] as? String ?? ""
                    let startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
                    let endDate = (data["endDate"] as? Timestamp)?.dateValue()
                    let isCompleted = data["isCompleted"] as? Bool ?? false
                    let isPostponed = data["isPostponed"] as? Bool ?? false
                    let hasReminder = data["hasReminder"] as? Bool ?? false
                    
                    let newItem = ScheduleItem(
                        title: title,
                        details: details,
                        startDate: startDate,
                        endDate: endDate,
                        isCompleted: isCompleted,
                        hasReminder: hasReminder,
                        ownerID: uid,
                        isPostponed: isPostponed
                    )
                    context.insert(newItem)
                }
            }
            group.leave()
        }
        
        // (2) 공부 기록 복구
        group.enter()
        db.collection("users").document(uid).collection("study_records").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                for doc in documents {
                    let data = doc.data()
                    
                    let duration = data["durationSeconds"] as? Int ?? 0
                    let areaName = data["areaName"] as? String ?? ""
                    let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
                    let purpose = data["studyPurpose"] as? String ?? "강의수강"
                    
                    let newRecord = StudyRecord(
                        durationSeconds: duration,
                        areaName: areaName,
                        date: date,
                        ownerID: uid,
                        studyPurpose: purpose
                    )
                    context.insert(newRecord)
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("FirestoreSyncManager: 모든 데이터 복구 완료")
            completion()
        }
    }
}
