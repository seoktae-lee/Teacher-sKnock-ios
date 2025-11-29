//
//  Teacher_sKnock_iosApp.swift
//  Teacher'sKnock-ios
//
//  Created by 이석태 on 11/29/25.
//

import SwiftUI
import SwiftData
import Firebase // Firebase SDK를 사용하기 위해 필요합니다.
import FirebaseAuth // AuthManager에서 사용되므로 안전을 위해 임포트

@main
struct Teacher_sKnock_iosApp: App {
    
    // 1. 앱 전체의 인증 상태를 관리할 'AuthManager' 객체 생성
    @StateObject var authManager = AuthManager()
    
    // 2. 앱 시작 시 Firebase를 초기화하는 함수
    init() {
        FirebaseApp.configure()
    }
    
    // 기존의 SwiftData 모델 컨테이너 코드
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // 3. RootView를 시작점으로 설정하고, AuthManager를 환경 객체로 전달합니다.
            RootView()
                .environmentObject(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
