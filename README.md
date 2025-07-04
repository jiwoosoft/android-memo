# 🔐 안전한 메모장 앱 (Secure Memo App)

## 📲 APK 다운로드

### 🚀 최신 버전 (v1.0.0)
**[📱 APK 다운로드](./releases/secure-memo-v1.0.0.apk)** | **[📋 릴리즈 노트](./releases/)**

- **파일 크기**: 57.3MB
- **Android 요구사항**: 5.0+ (API 21+)
- **패키지명**: `com.jiwoosoft.secure_memo`
- **최종 업데이트**: 2025.07.04

## 📋 프로젝트 소개

Flutter로 개발된 PIN 기반 보안 메모장 앱입니다. 6자리 PIN으로 앱을 보호하고, 카테고리별로 메모를 분류하여 체계적으로 관리할 수 있습니다.

## ✨ 주요 기능

### 🔒 보안 기능
- **PIN 로그인 시스템**: 6자리 숫자로 강력한 보안 인증
- **최초 설정**: 앱 설치 후 최초 실행 시 PIN 생성 가이드
- **PIN 변경**: 설정에서 언제든지 PIN 변경 가능
- **암호화 저장**: SHA-256 해시로 PIN 암호화 저장
- **자동 로그아웃**: 앱 재시작 시 자동 로그인 화면 표시

### 📂 카테고리 시스템
- **그룹화된 메모 관리**: 카테고리별 메모 분류
- **기본 카테고리 제공**: 거래처, 구매처, 개인메모
- **사용자 정의 카테고리**: 새로운 카테고리 자유롭게 추가
- **아이콘 선택**: 10가지 아이콘으로 카테고리 구분
- **확장 가능한 리스트**: 카테고리를 펼쳐서 메모 목록 확인

### 📝 메모 기능
- **메모 작성**: 제목과 내용으로 구성된 메모 작성
- **메모 수정**: 기존 메모 수정 및 업데이트
- **메모 삭제**: 확인 다이얼로그와 함께 안전한 삭제
- **메모 상세 보기**: 작성일, 수정일 포함한 상세 정보
- **실시간 저장**: SharedPreferences를 통한 즉시 저장

### 🎨 사용자 인터페이스
- **다크 테마**: 눈에 편한 어두운 테마 적용
- **Material Design 3**: 최신 머티리얼 디자인 가이드라인 준수
- **직관적인 네비게이션**: 스플래시 → 로그인 → 메인 화면
- **반응형 디자인**: 다양한 화면 크기에 최적화

## 🛠️ 기술 스택

### 프레임워크 & 언어
- **Flutter**: 4.0+ (크로스 플랫폼 앱 개발)
- **Dart**: 3.8+ (프로그래밍 언어)

### 주요 라이브러리
- **shared_preferences**: ^2.2.2 (로컬 데이터 저장)
- **crypto**: ^3.0.3 (PIN 암호화)
- **pinput**: ^4.0.0 (PIN 입력 UI)
- **expandable**: ^5.0.1 (확장 가능한 리스트)
- **cupertino_icons**: ^1.0.8 (iOS 스타일 아이콘)

## 📱 앱 구조

```
안전한 메모장
│
├── 🚀 스플래시 화면
│   ├── 앱 로고 및 로딩
│   └── 최초 실행 여부 확인
│
├── 🔐 인증 시스템
│   ├── PIN 설정 화면 (최초 실행)
│   ├── PIN 로그인 화면
│   └── PIN 변경 화면
│
├── 📁 메인 화면 (카테고리 목록)
│   ├── 카테고리별 메모 그룹화
│   ├── 확장 가능한 메모 리스트
│   └── 카테고리 추가 기능
│
├── 📝 메모 관리
│   ├── 메모 작성/수정 화면
│   ├── 메모 상세 보기
│   └── 메모 삭제 기능
│
└── ⚙️ 설정 화면
    ├── PIN 변경
    ├── 앱 정보
    └── 로그아웃
```

## 🚀 설치 및 실행

### 개발 환경 설정
1. Flutter SDK 설치 (4.0 이상)
2. Android Studio 또는 VS Code 설치
3. Android SDK 설치

### 프로젝트 실행
```bash
# 프로젝트 클론
git clone https://github.com/jiwoosoft/android-memo.git

# 디렉토리 이동
cd android-memo

# 의존성 설치
flutter pub get

# 앱 실행 (디버그 모드)
flutter run

# APK 빌드 (릴리즈 모드)
flutter build apk --release
```

## 📊 데이터 구조

### 카테고리 모델
```dart
class Category {
  String id;           // 고유 식별자
  String name;         // 카테고리 이름
  String icon;         // 아이콘 타입
  List<Memo> memos;    // 포함된 메모들
}
```

### 메모 모델
```dart
class Memo {
  String id;           // 고유 식별자
  String title;        // 메모 제목
  String content;      // 메모 내용
  DateTime createdAt;  // 생성일
  DateTime updatedAt;  // 수정일
}
```

## 🔐 보안 특징

### PIN 보안
- **해시 암호화**: SHA-256 해시로 PIN 암호화 저장
- **메모리 보호**: PIN 입력 시 마스킹 처리
- **로컬 저장**: PIN과 데이터 모두 로컬에만 저장

### 데이터 보안
- **오프라인 저장**: 모든 데이터 로컬 저장으로 개인정보 보호
- **암호화 저장**: SharedPreferences를 통한 보안 저장
- **접근 제어**: PIN 없이는 앱 접근 불가

## 📚 사용 방법

### 1. 최초 설정
1. 앱 설치 후 첫 실행
2. 6자리 PIN 설정
3. PIN 확인 입력
4. 설정 완료 후 메인 화면 진입

### 2. 메모 작성
1. 메인 화면에서 카테고리 선택
2. 카테고리의 + 버튼 클릭
3. 제목과 내용 입력
4. 저장 버튼 클릭

### 3. 카테고리 관리
1. 메인 화면 우하단 + 버튼 클릭
2. 카테고리 이름 입력
3. 아이콘 선택
4. 추가 버튼 클릭

### 4. 메모 관리
- **보기**: 메모 항목 클릭
- **수정**: 메모 옆 메뉴 → 수정 선택
- **삭제**: 메모 옆 메뉴 → 삭제 선택

### 5. 설정 변경
1. 메인 화면 우상단 설정 버튼
2. PIN 변경 / 앱 정보 확인
3. 로그아웃 시 다시 로그인 필요

## 🎨 커스터마이징

### 색상 테마
```dart
// 주요 색상
primaryColor: Colors.teal        // 메인 컬러
backgroundColor: Colors.black    // 배경 컬러
cardColor: Colors.grey[900]     // 카드 배경
```

### 아이콘 추가
```dart
// AddCategoryDialog의 _icons 리스트에 추가
{'name': 'new_icon', 'icon': Icons.new_icon}
```

## 📸 스크린샷

### 주요 화면
- **스플래시 화면**: 앱 로고와 로딩 표시
- **PIN 설정**: 6자리 PIN 입력 화면
- **메인 화면**: 카테고리별 메모 목록
- **메모 작성**: 제목과 내용 입력 화면

## 🛠️ 특별 기능

### 📱 갤럭시폰 호환성
- **듀얼 eSIM 지원**: 갤럭시폰 듀얼 eSIM 환경에서 중복 설치 방지
- **듀얼 메신저 비활성화**: 앱이 듀얼 메신저로 인식되지 않도록 설정
- **단일 앱 설치**: 런처에서 하나의 앱 아이콘만 표시
- **삼성 특화 설정**: Samsung One UI 환경 최적화

### ✏️ 개선된 UI/UX
- **메모 텍스트 정렬**: 내용 입력 시 상단부터 시작
- **리스트 최적화**: 메모 목록에서 제목만 표시 (내용 미리보기 제거)
- **카테고리 관리**: 이름 수정, 삭제, 순서 변경 기능
- **드래그 앤 드롭**: 카테고리 및 메모 순서 자유롭게 변경

## 🔄 업데이트 로그

### v1.2.0 (2024-12-23)
- 🔧 갤럭시폰 듀얼 메신저 기능 완전 비활성화
- 🎯 AndroidManifest.xml 특화 설정으로 중복 설치 방지
- ✏️ 메모 텍스트 입력 필드 상단 정렬로 개선
- 📱 삼성 갤럭시 듀얼 eSIM 환경 완벽 지원

### v1.1.0 (2024-12-22)
- 🔧 중복 앱 설치 문제 해결 (패키지명 변경)
- 🎨 메모 리스트 표시 방식 개선 (제목만 표시)
- ⚙️ 카테고리 고급 관리 기능 추가
- 🔄 드래그 앤 드롭 순서 변경 기능

### v1.0.0 (2024-12-21)
- ✅ PIN 기반 로그인 시스템 구현
- ✅ 카테고리별 메모 분류 기능 추가
- ✅ 확장 가능한 메모 리스트 구현
- ✅ 다크 테마 및 Material Design 3 적용
- ✅ 암호화된 로컬 데이터 저장
- ✅ 메모 CRUD 기능 완성

## 🛡️ 개인정보 보호

- **로컬 저장**: 모든 데이터는 사용자 기기에만 저장
- **네트워크 없음**: 인터넷 연결 불필요
- **데이터 수집 없음**: 개인정보 수집하지 않음
- **PIN 보호**: 앱 접근 시 PIN 인증 필수

## 📋 알려진 제한사항

- **백업 기능**: 현재 데이터 백업/복원 기능 미제공
- **동기화**: 여러 기기 간 데이터 동기화 미지원
- **검색 기능**: 메모 내용 검색 기능 미제공
- **첨부파일**: 이미지, 파일 첨부 기능 미제공

## 🚀 향후 계획

### v1.1.0 (계획)
- [ ] 메모 검색 기능 추가
- [ ] 메모 내 이미지 첨부 기능
- [ ] 백업/복원 기능 (파일 export/import)
- [ ] 지문 인증 지원

### v1.2.0 (계획)
- [ ] 메모 태그 기능
- [ ] 메모 정렬 옵션 (날짜, 제목, 내용)
- [ ] 다크/라이트 테마 선택
- [ ] 폰트 크기 조정 기능

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 있습니다.

```
MIT License

Copyright (c) 2024 jiwoosoft

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 👨‍💻 개발자 정보

- **개발자**: jiwoosoft
- **이메일**: [연락처 정보]
- **GitHub**: https://github.com/jiwoosoft
- **프로젝트 저장소**: https://github.com/jiwoosoft/android-memo

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 지원 및 문의

- **버그 리포트**: GitHub Issues 활용
- **기능 제안**: GitHub Issues 활용
- **일반 문의**: GitHub Discussions 활용

---

**⭐ 이 프로젝트가 도움이 되었다면 별표를 눌러주세요!**
