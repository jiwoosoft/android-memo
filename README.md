# 📝 Android 메모장 앱 (Memo App)

## 📋 프로젝트 소개

Flutter로 개발된 다크모드 지원 메모장 앱입니다. 간단하고 직관적인 UI로 메모를 작성, 저장, 삭제할 수 있는 기능을 제공합니다.

## ✨ 주요 기능

### 🌟 핵심 기능
- **메모 작성**: 텍스트 입력을 통한 메모 작성
- **메모 목록 보기**: 작성된 모든 메모를 리스트 형태로 확인
- **메모 삭제**: 길게 누르기로 메모 삭제 (확인 다이얼로그 포함)
- **데이터 저장**: SharedPreferences를 통한 로컬 데이터 저장
- **다크모드**: 눈에 편한 다크 테마 적용

### 🎨 UI/UX 특징
- **Material Design 3**: 최신 머티리얼 디자인 적용
- **다크 테마**: 블랙 배경과 틸(Teal) 포인트 컬러
- **직관적인 네비게이션**: 플로팅 액션 버튼으로 메모 추가
- **사용자 친화적 인터페이스**: 간단하고 깔끔한 디자인

## 🛠️ 기술 스택

### 프레임워크 & 언어
- **Flutter**: 4.0+ (크로스 플랫폼 앱 개발)
- **Dart**: 3.8+ (프로그래밍 언어)

### 주요 라이브러리
- **shared_preferences**: ^2.2.2 (로컬 데이터 저장)
- **material_design**: Material Design 3 컴포넌트
- **cupertino_icons**: ^1.0.8 (iOS 스타일 아이콘)

### 개발 도구
- **Flutter SDK**: 최신 안정 버전
- **Android Studio / VS Code**: 개발 환경
- **Gradle**: Android 빌드 시스템

## 📱 스크린샷

### 메인 화면 (메모 리스트)
- 작성된 메모들이 카드 형태로 표시
- 틸 컬러 노트 아이콘으로 시각적 구분
- 상단 앱바에 앱 제목 표시

### 메모 작성 화면
- 다중 줄 텍스트 입력 필드
- 저장 버튼 (아이콘 + 텍스트)
- 다크 테마 적용된 입력 필드

### 삭제 확인 다이얼로그
- 메모 삭제 전 확인 과정
- 취소/삭제 버튼 제공

## 🚀 설치 및 실행

### 사전 요구사항
- Flutter SDK 3.8.1 이상
- Android Studio 또는 VS Code
- Android SDK (안드로이드 앱 빌드용)

### 1. 프로젝트 클론
```bash
git clone https://github.com/jiwoosoft/android-memo.git
cd android-memo
```

### 2. 의존성 설치
```bash
flutter pub get
```

### 3. 앱 실행
```bash
# 디버그 모드로 실행
flutter run

# 또는 특정 디바이스에서 실행
flutter run -d <device_id>
```

### 4. APK 빌드
```bash
# 릴리즈 APK 생성
flutter build apk --release

# 분할 APK 생성 (파일 크기 최적화)
flutter build apk --split-per-abi
```

## 📁 프로젝트 구조

```
memo_app/
├── lib/
│   └── main.dart                 # 메인 애플리케이션 코드
├── android/                      # Android 플랫폼 코드
│   ├── app/
│   │   ├── build.gradle.kts      # Android 빌드 설정
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── kotlin/
│   └── gradle/                   # Gradle 설정
├── build/                        # 빌드 산출물
│   └── app/outputs/flutter-apk/
│       └── app-release.apk      # 배포용 APK
├── pubspec.yaml                  # Flutter 의존성 설정
├── pubspec.lock                  # 의존성 버전 잠금
└── README.md                     # 프로젝트 문서
```

## 🏗️ 아키텍처

### 앱 구조
```
MyApp (루트 위젯)
├── MaterialApp (앱 설정)
├── MemoListScreen (메모 리스트 화면)
│   ├── AppBar (상단 바)
│   ├── ListView.builder (메모 리스트)
│   └── FloatingActionButton (메모 추가 버튼)
└── AddMemoScreen (메모 작성 화면)
    ├── AppBar (상단 바)
    ├── TextField (텍스트 입력)
    └── ElevatedButton (저장 버튼)
```

### 데이터 흐름
1. **메모 작성**: AddMemoScreen에서 텍스트 입력 → 저장 버튼 클릭
2. **데이터 저장**: SharedPreferences에 문자열 리스트로 저장
3. **목록 갱신**: MemoListScreen의 상태 업데이트
4. **메모 삭제**: 길게 누르기 → 확인 다이얼로그 → 삭제 및 저장

## 🎯 사용 방법

### 메모 작성하기
1. 메인 화면에서 **+** 버튼 클릭
2. 텍스트 입력 필드에 메모 내용 작성
3. **저장** 버튼 클릭
4. 메인 화면으로 돌아가 저장된 메모 확인

### 메모 삭제하기
1. 메인 화면에서 삭제할 메모를 **길게 누르기**
2. 삭제 확인 다이얼로그에서 **삭제** 버튼 클릭
3. 메모가 목록에서 제거됨

## 📊 성능 최적화

### 최적화 포인트
- **SharedPreferences 사용**: 빠른 로컬 데이터 저장/로드
- **ListView.builder**: 대용량 리스트 효율적 렌더링
- **StatefulWidget**: 필요한 부분만 상태 관리
- **Material Design**: 시스템 최적화된 UI 컴포넌트

### APK 크기 최적화
- **Tree-shaking**: 사용하지 않는 코드 제거
- **Asset 최적화**: 아이콘 파일 최적화
- **Proguard**: 코드 난독화 및 최적화

## 🔧 커스터마이징

### 색상 테마 변경
```dart
// lib/main.dart의 darkTheme 설정
darkTheme: ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.blue,     // 원하는 색상으로 변경
  scaffoldBackgroundColor: Colors.grey[900],
  // ... 기타 테마 설정
),
```

### 폰트 변경
```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: MyCustomFont
      fonts:
        - asset: fonts/MyCustomFont.ttf
```

## 🐛 알려진 이슈

### 현재 제한사항
- **메모 편집 기능 없음**: 한 번 작성한 메모는 수정 불가
- **메모 검색 기능 없음**: 많은 메모에서 특정 메모 찾기 어려움
- **카테고리 기능 없음**: 메모 분류 기능 부재
- **백업 기능 없음**: 클라우드 동기화 미지원

### 향후 개선 계획
- [ ] 메모 편집 기능 추가
- [ ] 메모 검색 기능 구현
- [ ] 카테고리/태그 시스템 도입
- [ ] 클라우드 백업 기능 추가
- [ ] 메모 공유 기능 구현

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 👨‍💻 개발자 정보

**개발자**: jiwoosoft  
**GitHub**: https://github.com/jiwoosoft  
**프로젝트 저장소**: https://github.com/jiwoosoft/android-memo  

## 🤝 기여하기

1. 이 저장소를 Fork하기
2. 새로운 기능 브랜치 생성 (`git checkout -b feature/amazing-feature`)
3. 변경사항 커밋 (`git commit -m 'Add amazing feature'`)
4. 브랜치에 Push (`git push origin feature/amazing-feature`)
5. Pull Request 생성

## 📞 문의 및 지원

- **이슈 보고**: GitHub Issues 탭에서 버그 리포트
- **기능 요청**: GitHub Issues에서 enhancement 레이블로 요청
- **일반 문의**: GitHub Discussion 활용

---

**⭐ 이 프로젝트가 도움이 되었다면 스타를 눌러주세요!**
