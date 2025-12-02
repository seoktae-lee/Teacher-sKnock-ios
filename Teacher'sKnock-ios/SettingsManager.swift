import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

class SettingsManager: ObservableObject {
    
    // UI에 보여줄 선호 과목 리스트 (기본값은 빈 배열)
    @Published var favoriteSubjects: [SubjectName] = []
    
    private let db = Firestore.firestore()
    private let settingsCollectionName = "settings"
    private let favoriteSubjectsDocument = "favorite_subjects"
    
    init() {}
    
    // ✨ [보안] 로그아웃 시 메모리만 비우는 함수 (서버 데이터는 안전함)
    func reset() {
        print("SettingsManager: 메모리 초기화 (다른 계정 데이터 혼용 방지)")
        self.favoriteSubjects = SubjectName.defaultSubjects
    }
    
    // ✨ [복구] 로그인 시 서버에서 내 설정 불러오기
    func fetchSettings(uid: String) {
        print("SettingsManager: 서버에서 설정 불러오는 중... (UID: \(uid))")
        
        let docRef = db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument)
        
        docRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let document = document, document.exists, let data = document.data() {
                // 1. 서버에 저장된 데이터가 있으면 가져와서 적용 (복구 성공!)
                if let subjectStrings = data["subjects"] as? [String] {
                    let loadedSubjects = subjectStrings.compactMap { SubjectName(rawValue: $0) }
                    DispatchQueue.main.async {
                        self.favoriteSubjects = loadedSubjects
                        print("SettingsManager: 설정 복구 완료 (\(loadedSubjects.count)개 과목)")
                    }
                }
            } else {
                // 2. 저장된 게 없으면(첫 사용자) 기본값 적용
                print("SettingsManager: 저장된 설정 없음 -> 기본값 적용")
                DispatchQueue.main.async {
                    self.favoriteSubjects = SubjectName.defaultSubjects
                    // 기본값을 서버에도 한번 저장해주는 것이 좋음
                    self.saveFavoriteSubjects(uid: uid, self.favoriteSubjects)
                }
            }
        }
    }
    
    // ✨ [저장] 변경 즉시 서버에 영구 저장
    func saveFavoriteSubjects(uid: String, _ subjects: [SubjectName]) {
        // UI 먼저 업데이트 (반응 속도 향상)
        self.favoriteSubjects = subjects
        
        let subjectStrings = subjects.map { $0.rawValue }
        let dataToSave: [String: Any] = [
            "subjects": subjectStrings,
            "lastUpdated": Timestamp(date: Date())
        ]
        
        // 사용자별(UID) 경로에 저장 -> 계정간 데이터 분리 확실함
        db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument).setData(dataToSave) { error in
            if let error = error {
                print("SettingsManager: 서버 저장 실패 - \(error.localizedDescription)")
            } else {
                print("SettingsManager: 서버 저장 성공 (영구 보관)")
            }
        }
    }
}
