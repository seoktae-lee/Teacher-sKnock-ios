import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class SettingsManager: ObservableObject {
    
    // 1. 선호 과목
    @Published var favoriteSubjects: [StudySubject] = []
    
    // 2. 맞춤 정보 (변경 시 '현재 유저' 기준으로 자동 저장)
    @Published var myUniversity: University? {
        didSet { saveUserSetting(value: myUniversity, key: "myUniversity", field: "university") }
    }
    @Published var targetOffice: OfficeOfEducation? {
        didSet { saveUserSetting(value: targetOffice, key: "targetOffice", field: "targetOffice") }
    }
    
    private let db = Firestore.firestore()
    private let settingsCollectionName = "settings"
    private let favoriteSubjectsDocument = "favorite_subjects"
    
    init() {
        // 앱 켜질 때는 아무것도 로드하지 않음 (로그인 후 AuthManager가 로드 명령을 내림)
    }
    
    // MARK: - ✨ 핵심: 사용자별 데이터 저장 로직
    
    private func saveUserSetting<T: Codable>(value: T?, key: String, field: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return } // 로그인 안 했으면 저장 안 함
        
        // 1. 로컬 저장 (Key에 UID를 붙여서 사용자 분리!)
        let uniqueKey = "\(key)_\(uid)"
        if let value = value, let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: uniqueKey)
        } else {
            UserDefaults.standard.removeObject(forKey: uniqueKey)
        }
        
        // 2. 서버 저장 (Firestore 유저 문서 업데이트)
        // University나 Office 같은 복잡한 객체는 문자열(raw value/name)로 변환해서 저장
        var valueToSave: Any? = nil
        if let univ = value as? University { valueToSave = univ.name }
        if let office = value as? OfficeOfEducation { valueToSave = office.rawValue }
        
        if let finalValue = valueToSave {
            db.collection("users").document(uid).updateData([field: finalValue]) { error in
                if let error = error { print("설정 저장 실패: \(error.localizedDescription)") }
            }
        }
    }
    
    // MARK: - ✨ 로그인 시 데이터 복구 (AuthManager가 호출)
    
    func loadSettings(for uid: String) {
        print("SettingsManager: \(uid)의 설정을 불러옵니다.")
        
        // 1. 과목 불러오기 (기존 로직)
        fetchFavoriteSubjects(uid: uid)
        
        // 2. 대학교 & 교육청 불러오기 (Firestore User 정보 + 로컬 캐시)
        // 로컬 캐시 우선 확인 (속도)
        if let data = UserDefaults.standard.data(forKey: "myUniversity_\(uid)"),
           let univ = try? JSONDecoder().decode(University.self, from: data) {
            self.myUniversity = univ
        }
        if let data = UserDefaults.standard.data(forKey: "targetOffice_\(uid)"),
           let office = try? JSONDecoder().decode(OfficeOfEducation.self, from: data) {
            self.targetOffice = office
        }
        
        // 서버 데이터로 최신화 (AuthManager가 fetchUserData로 이미 닉네임 등을 가져오고 있을 것임)
        // 여기서는 생략하거나, 확실하게 하려면 한 번 더 fetch 가능
    }
    
    // MARK: - 대학교 자동 설정 (로그인 직후 호출용)
    func setUniversity(fromName name: String) {
        if let foundUniv = University.find(byName: name) {
            // 값이 같으면 굳이 업데이트(저장)하지 않음 (무한 루프 방지)
            if self.myUniversity?.name != foundUniv.name {
                DispatchQueue.main.async {
                    self.myUniversity = foundUniv
                    print("SettingsManager: 대학교 자동 설정 -> \(name)")
                }
            }
        }
    }
    
    // ✨ 교육청 자동 설정
    func setOffice(fromName name: String) {
        if let foundOffice = OfficeOfEducation(rawValue: name) {
            if self.targetOffice != foundOffice {
                DispatchQueue.main.async {
                    self.targetOffice = foundOffice
                    print("SettingsManager: 교육청 자동 설정 -> \(name)")
                }
            }
        }
    }
    
    // MARK: - 초기화
    func reset() {
        print("SettingsManager: 데이터 초기화")
        self.favoriteSubjects = []
        self.myUniversity = nil
        self.targetOffice = nil
    }
    
    // MARK: - 과목 관리 (기존 유지)
    
    func addSubject(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return }
        if !favoriteSubjects.contains(where: { $0.name == trimmedName }) {
            let newSubject = StudySubject(name: trimmedName)
            favoriteSubjects.append(newSubject)
            if let uid = Auth.auth().currentUser?.uid {
                saveFavoriteSubjects(uid: uid, favoriteSubjects)
            }
        }
    }
    
    func removeSubject(at offsets: IndexSet) {
        favoriteSubjects.remove(atOffsets: offsets)
        if let uid = Auth.auth().currentUser?.uid {
            saveFavoriteSubjects(uid: uid, favoriteSubjects)
        }
    }
    
    private func fetchFavoriteSubjects(uid: String) {
        let docRef = db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument)
        docRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            if let document = document, document.exists, let data = document.data(),
               let subjectStrings = data["subjects"] as? [String] {
                let loadedSubjects = subjectStrings.map { StudySubject(name: $0) }
                DispatchQueue.main.async { self.favoriteSubjects = loadedSubjects }
            } else {
                DispatchQueue.main.async {
                    self.favoriteSubjects = self.defaultSubjects()
                    self.saveFavoriteSubjects(uid: uid, self.favoriteSubjects)
                }
            }
        }
    }
    
    func saveFavoriteSubjects(uid: String, _ subjects: [StudySubject]) {
        self.favoriteSubjects = subjects
        let subjectStrings = subjects.map { $0.name }
        let dataToSave: [String: Any] = ["subjects": subjectStrings, "lastUpdated": Timestamp(date: Date())]
        db.collection("users").document(uid).collection(settingsCollectionName).document(favoriteSubjectsDocument).setData(dataToSave)
    }
    
    private func defaultSubjects() -> [StudySubject] {
        return [StudySubject(name: "교육학"), StudySubject(name: "전공"), StudySubject(name: "한국사")]
    }
}
