import Foundation
import FirebaseFirestore

struct Quote: Identifiable, Codable {
    var id: String? // Firestore 문서 ID (자동 생성된 문자열)
    let text: String
    let author: String
}

class QuoteManager {
    static let shared = QuoteManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // ✨ [수정됨] 전체 목록 중 랜덤 하나 가져오기
    func fetchQuote(completion: @escaping (Quote?) -> Void) {
        // 'quotes' 컬렉션의 모든 문서를 가져옴
        db.collection("quotes").getDocuments { snapshot, error in
            if let error = error {
                print("🔥 명언 가져오기 실패: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("⚠️ 저장된 명언이 없습니다.")
                completion(nil)
                return
            }
            
            // ✨ 앱 내에서 랜덤으로 하나 선택
            let randomDoc = documents.randomElement()!
            let data = randomDoc.data()
            
            let text = data["text"] as? String ?? "오늘도 파이팅!"
            let author = data["author"] as? String ?? "T-No"
            
            // 문서 ID(자동생성된 문자열)를 id로 사용
            let quote = Quote(id: randomDoc.documentID, text: text, author: author)
            
            print("✅ 명언 로드 성공: \(text)")
            completion(quote)
        }
    }
}
