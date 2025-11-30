## 🍎 Teacher's Knock

> "당신의 합격 순간까지 함께할, 교대생 맞춤형 학습 플래너" > 임용고시 준비생과 교육대학생을 위한 올인원 학습 관리 iOS 앱

![iOS](https://img.shields.io/badge/iOS-17.0%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Declarative-blue?logo=swift)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-yellow?logo=firebase)
![SwiftData](https://img.shields.io/badge/SwiftData-Local%20DB-lightgrey)

---
## 🧑‍💻 Teacher's Knock Developer
Name: Seoktae Lee

Role: iOS Developer

Contact: seoktae0526@naver.com

---

## 📖 프로젝트 소개 (Project Overview)

 Teacher's Knock App은 미래의 선생님을 꿈꾸는 교대생들의 효율적인 시간 관리와 목표 달성을 돕기 위해 개발되었습니다.  
복잡한 임용고시 일정 관리, 과목별 공부 시간 측정, 그리고 D-day 관리를 하나의 앱에서 직관적으로 해결합니다.

* 개발 기간: 2025.11.29 ~ 진행 중
* 개발 인원: 1인 개발
* 주요 타겟: 전국 교육대학교 재학생 및 초등 임용고시 수험생

---

## 🛠️ 기술 스택 (Tech Stack)

| 분류 | 기술 | 활용 내용 |
| :--- | :--- | :--- |
| **Language** | **Swift** | 안전하고 빠른 네이티브 앱 개발 |
| **Framework** | **SwiftUI** | 선언적 UI 구성을 통한 모던한 인터페이스 구현 |
| **Architecture** | **MVVM** | 뷰와 비즈니스 로직의 분리 (View - ViewModel - Model) |
| **Database** | **SwiftData** | 로컬 데이터 영구 저장 (목표, 일정, 공부 기록) |
| **Backend** | **Firebase** | 사용자 인증(Auth) 및 유저 정보 클라우드 저장(Firestore) |
| **Version Control** | **Git & GitHub** | 코드 버전 관리 및 이슈 트래킹 |

---

## ✨ 핵심 기능 및 구현 현황 (Key Features)

### 1. 🔐 완벽한 인증 시스템 (Authentication)
* **이메일/비밀번호 회원가입 & 로그인:** Firebase Auth 연동.
* **이메일 본인 인증 강제:** 가짜 계정 방지를 위해 인증 메일 링크 클릭 후 로그인 허용.
* **비밀번호 재설정:** 이메일을 통한 비밀번호 재설정 링크 발송 기능.
* **자동 로그인 & 세션 관리:** 앱 재실행 시 로그인 상태 유지 (`AuthManager` 활용).
* **데이터 분리:** 사용자 고유 ID(UID)를 기반으로 개인 데이터(`Goal`) 완벽 격리.

### 2. 🎯 목표 관리 (D-day)
* **목표 추가 및 관리:** 시험 명칭과 날짜를 설정하여 D-day 카드 생성.
* **SwiftData 연동:** 앱을 종료해도 목표 데이터가 유지되도록 로컬 DB 설계.
* **직관적인 UI:** 파스텔톤 그라데이션 카드 디자인 적용.

### 3. 📅 스터디 플래너 (Planner)
* **캘린더 뷰:** 날짜별 일정 확인 및 관리.
* **To-Do 리스트:** 체크박스를 통한 할 일 완료 처리.

### 4. ⏱️ 집중 타이머 (Timer)
* **과목별 타이머:** 교육학, 전공 등 과목을 선택하여 공부 시간 측정.
* **학습 기록 저장:** 측정된 시간을 `StudyRecord` 모델에 저장하여 통계 데이터로 활용.

---

## 📂 프로젝트 구조 (Directory Structure)

```text
Teacher'sKnock-ios
├── App
│   ├── Teacher_sKnock_iosApp.swift  // 앱 진입점 (Firebase 초기화)
│   └── AuthManager.swift            // 인증 상태 관리자 (ObservableObject)
├── Views
│   ├── RootView.swift               // 로그인/메인 화면 분기 처리
│   ├── SplashView.swift             // 앱 시작 애니메이션
│   ├── Login & Auth
│   │   ├── LoginView.swift          // 로그인 화면
│   │   └── SignUpView.swift         // 회원가입 (이메일 인증 포함)
│   └── Main
│       ├── MainTabView.swift        // 메인 탭 네비게이션
│       ├── GoalListView.swift       // D-day 목표 목록
│       ├── PlannerView.swift        // 플래너 화면
│       ├── TimerView.swift          // 타이머 화면
│       └── SettingsView.swift       // 설정 (회원 탈퇴 등)
└── Models (SwiftData)
    ├── Goal.swift                   // 목표 데이터 모델
    ├── ScheduleItem.swift           // 일정 데이터 모델
    └── StudyRecord.swift            // 공부 기록 모델
