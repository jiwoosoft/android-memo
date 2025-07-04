# 📱 안전한 메모장 앱 - 프로젝트 상태 보고서

> **생성일**: 2025.01.07  
> **목적**: 새로운 대화창에서 AI가 프로젝트를 이어서 작업할 수 있도록 현재 상태 정리

---

## 🎯 **프로젝트 개요**

### 기본 정보
- **앱 이름**: 안전한 메모장 (Secure Memo)
- **현재 버전**: **v1.0.3+4**
- **패키지명**: `com.jiwoosoft.secure_memo`
- **플랫폼**: Android (Flutter)
- **개발자**: jiwoosoft (Powered by HaneulCCM)

### 핵심 기능
- **4자리 PIN 기반 보안 시스템**
- **카테고리별 메모 분류 및 관리**
- **XOR 암호화 기반 데이터 보호**
- **GitHub API 연동 자동 업데이트 확인**
- **오프라인 로컬 저장** (개인정보 보호)

---

## 📊 **현재 상태 (v1.0.3)**

### ✅ 최근 완료된 작업 (v1.0.3 업데이트)
1. **📄 라이선스 시스템 구축**
   - LICENSE 파일에 영문/한글 라이선스 추가
   - README.md 라이선스 섹션 영문/한글 버전 포함
   - 앱 내 라이선스 화면 (`LicenseScreen`) 추가
   - 설정 → 라이선스 메뉴 연동

2. **©️ 전체 페이지 카피라이트 적용**
   - **적용된 화면**: 스플래시, PIN 설정, 로그인, 메인, 설정, PIN 변경, 라이선스
   - **카피라이트 텍스트**: "Copyright (c) 2025 jiwoosoft. Powered by HaneulCCM."
   - **적용 방식**: bottomNavigationBar 또는 하단 Container

3. **🚀 버전 관리**
   - pubspec.yaml: 1.0.2+3 → 1.0.3+4 업데이트
   - CHANGELOG.md v1.0.3 변경사항 상세 기록
   - GitHub v1.0.3 릴리즈 생성 완료

### 📱 APK 빌드 정보
- **최신 APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **파일 크기**: 58.8MB
- **빌드 상태**: ✅ 성공
- **Google Drive 링크**: https://drive.google.com/file/d/1gXsyINdyKcwLZdf10KB4RuQVQGH1rmQd/view?usp=sharing

### 🌐 GitHub 저장소 상태
- **저장소**: https://github.com/jiwoosoft/android-memo
- **브랜치**: main
- **최신 커밋**: v1.0.3 라이선스 및 카피라이트 업데이트
- **릴리즈**: v1.0.3 (Latest)
- **푸시 상태**: ✅ 최신 상태

---

## 🛠️ **기술적 세부사항**

### 핵심 의존성 (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.3.4      # 로컬 데이터 저장
  crypto: ^3.0.6                  # PIN 해시 및 암호화
  pinput: ^4.0.0                  # PIN 입력 UI
  expandable: ^5.0.1              # 확장 가능한 카테고리 리스트
  package_info_plus: ^8.0.4       # 앱 버전 정보
  http: ^1.3.0                    # GitHub API 통신
  url_launcher: ^6.5.2            # 외부 링크 열기
```

### 주요 클래스 구조
```dart
// 데이터 관리
- DataService: SharedPreferences 기반 데이터 저장/로드
- SecurityService: XOR 암호화 및 보안 기능
- UpdateService: GitHub API 연동 업데이트 확인

// 모델
- Category: 카테고리 정보 (id, name, icon, memos)
- Memo: 메모 정보 (id, title, content, createdAt, updatedAt)
- ReleaseInfo: GitHub 릴리즈 정보
- UpdateCheckResult: 업데이트 확인 결과

// 화면
- SplashScreen: 앱 시작 화면
- PinSetupScreen: PIN 설정 화면
- LoginScreen: PIN 로그인 화면
- CategoryListScreen: 메인 화면 (카테고리 목록)
- SettingsScreen: 설정 화면
- ChangePinScreen: PIN 변경 화면
- LicenseScreen: 라이선스 화면 (v1.0.3 신규)
```

### 보안 기능
```dart
// PIN 보안
- SHA-256 해시로 PIN 암호화 저장
- 세션 기반 PIN 관리 (앱 백그라운드 시 자동 클리어)

// 데이터 암호화
- XOR 기반 메모 데이터 암호화
- PIN을 키로 사용한 대칭 암호화

// Android 보안 설정
- android:allowBackup="false"
- 네트워크 보안 설정
- 듀얼 메신저 기능 비활성화
```

---

## 📁 **주요 파일 구조**

```
memo_app/
├── lib/
│   ├── main.dart                 # 메인 앱 코드 (모든 클래스 포함)
│   └── update_service.dart       # GitHub API 업데이트 서비스
├── android/
│   ├── app/
│   │   ├── build.gradle.kts      # Android 빌드 설정
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # 앱 권한 및 설정
│   │       └── res/xml/
│   │           ├── data_extraction_rules.xml
│   │           └── network_security_config.xml
├── pubspec.yaml                  # Flutter 의존성 및 버전 (v1.0.3+4)
├── README.md                     # 프로젝트 문서 (v1.0.3 링크 업데이트)
├── CHANGELOG.md                  # 버전별 변경사항 기록
├── LICENSE                       # MIT 라이선스 (영문/한글)
├── VERSION_MANAGEMENT.md         # 버전 관리 가이드
└── update_version.py             # 자동 버전 업데이트 스크립트
```

---

## 🔄 **업데이트 확인 시스템**

### GitHub API 연동
- **엔드포인트**: `https://api.github.com/repos/jiwoosoft/android-memo/releases/latest`
- **기능**: 앱 내에서 최신 버전 자동 확인
- **UI**: 설정 → 앱 정보 → '업데이트 확인' 버튼

### 버전 비교 로직
- **Semantic Versioning** 지원 (major.minor.patch)
- **빌드 번호** 비교 (예: +4)
- **동적 링크 추출**: 릴리즈 노트에서 Google Drive 링크 자동 파싱

### 다운로드 연동
- **Google Drive 연동**: 릴리즈 노트에서 링크 추출
- **URL Launcher**: 외부 브라우저로 다운로드 페이지 연결

---

## 🧪 **테스트 가능한 기능**

### 1. 업데이트 확인 테스트
```
현재 상황: v1.0.2 APK → v1.0.3 릴리즈 감지
테스트 방법:
1. 이전 v1.0.2 APK 설치
2. 설정 → 앱 정보 → '업데이트 확인' 클릭
3. "새로운 업데이트가 있습니다!" 다이얼로그 확인
4. Google Drive 다운로드 링크 작동 확인
```

### 2. 라이선스 화면 테스트
```
테스트 방법:
1. 설정 → 라이선스 메뉴 선택
2. 영문/한글 라이선스 내용 확인
3. 개발자 정보 섹션 확인
4. 하단 카피라이트 표시 확인
```

### 3. 카피라이트 표시 테스트
```
확인 대상: 모든 화면 하단
- 스플래시 화면
- PIN 설정/로그인 화면
- 메인 화면 (bottomNavigationBar)
- 설정 화면 (bottomNavigationBar)
- PIN 변경 화면 (bottomNavigationBar)
- 라이선스 화면 (bottomNavigationBar)
```

---

## 📋 **데이터 유지 정보**

### SharedPreferences 키
```dart
_pinKey = 'app_pin'              // PIN 해시 (SHA-256)
_categoriesKey = 'categories'    // 암호화된 메모 데이터
_isFirstLaunchKey = 'is_first_launch'  // 첫 실행 여부
```

### 업데이트 시 데이터 유지
- ✅ **덮어쓰기 설치**: 모든 데이터 유지
- ❌ **삭제 후 재설치**: 모든 데이터 삭제
- ✅ **사이드로딩**: 데이터 유지 (동일 패키지명)

---

## 🚀 **다음 작업을 위한 가이드**

### 개발 환경 설정
```bash
# 프로젝트 클론 (이미 있음)
cd F:\FlutterProjects\memo_app

# 의존성 설치
flutter pub get

# Google Drive API 라이브러리 설치 (자동화 기능용)
pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib

# 빌드 확인
flutter build apk --release
```

### 🤖 **완전 자동화 배포 시스템 (신규 추가)**

#### 자동화 기능 설정
```bash
# 1. Google Drive API 설정 (최초 1회만)
# GOOGLE_DRIVE_SETUP.md 파일 참조

# 2. 인증 파일 설정
# credentials.json 파일을 프로젝트 루트에 배치
```

#### 자동화 배포 명령어
```bash
# 🚀 완전 자동화 배포 (권장)
python auto_deploy.py patch    # 1.0.3 → 1.0.4 (버전 업데이트 + 빌드 + 업로드 + 배포)
python auto_deploy.py minor    # 1.0.3 → 1.1.0 (마이너 업데이트)
python auto_deploy.py major    # 1.0.3 → 2.0.0 (메이저 업데이트)
python auto_deploy.py --current  # 현재 버전 재배포

# 🔧 부분 배포 옵션
python auto_deploy.py patch --no-upload   # 업로드 제외
python auto_deploy.py patch --no-git      # Git 푸시 제외
python auto_deploy.py patch --no-release  # 릴리즈 생성 제외
```

#### 수동 업로드만 실행
```bash
# Google Drive 업로드만 실행
python google_drive_uploader.py
python google_drive_uploader.py --version 1.0.4
```

### 기존 수동 방식 (참고용)
```bash
# 수동 버전 업데이트
python update_version.py patch  # 1.0.3 → 1.0.4
python update_version.py minor  # 1.0.3 → 1.1.0
python update_version.py major  # 1.0.3 → 2.0.0

# 수동 릴리즈 생성
gh release create v1.0.4 --title "v1.0.4 - 새로운 기능" --notes "릴리즈 노트"
```

### GitHub 작업
```bash
# 현재 상태 확인
git status
git log --oneline -5

# 새로운 작업 시
git pull origin main
git checkout -b feature/새기능명
```

---

## 🔗 **중요 링크**

- **GitHub 저장소**: https://github.com/jiwoosoft/android-memo
- **최신 릴리즈**: https://github.com/jiwoosoft/android-memo/releases/tag/v1.0.3
- **APK 다운로드**: https://drive.google.com/file/d/1gXsyINdyKcwLZdf10KB4RuQVQGH1rmQd/view?usp=sharing
- **개발자 연락처**: webmaster@jiwoosoft.com

---

## 🤖 **새로운 자동화 기능 (v1.0.4 예정)**

### 완전 자동화 배포 시스템 추가
1. **📤 Google Drive API 연동**
   - APK 파일 자동 업로드 기능
   - 공유 링크 자동 생성
   - README.md 다운로드 링크 자동 업데이트

2. **🚀 원클릭 배포**
   - 버전 업데이트 → 빌드 → 업로드 → 배포까지 한 번에 실행
   - `python auto_deploy.py patch` 명령어로 모든 과정 자동화

3. **📁 새로운 파일 구조**
   - `google_drive_uploader.py`: Google Drive 업로드 전용 스크립트
   - `auto_deploy.py`: 완전 자동화 배포 스크립트
   - `GOOGLE_DRIVE_SETUP.md`: Google Drive API 설정 가이드
   - `README_AUTOMATION.md`: 자동화 기능 사용 가이드

4. **🔧 고급 기능**
   - 부분 배포 옵션 (`--no-upload`, `--no-git`, `--no-release`)
   - 현재 버전 재배포 (`--current`)
   - 진행률 표시 및 상세 로그

## ⚠️ **주의사항**

1. **메모리에 저장**: 새로운 대화창에서는 이 문서를 참조하여 프로젝트 상태를 파악할 것
2. **APK 빌드**: 새로운 기능 추가 시 반드시 버전 업데이트 후 빌드
3. **🤖 자동화 우선**: 새로운 자동화 시스템을 우선 사용하고, 필요시 수동 방식 사용
4. **🔐 보안**: Google Drive API 인증 파일(`credentials.json`)은 절대 GitHub에 업로드하지 말 것
5. **라이선스**: MIT 라이선스 하에 배포되므로 라이선스 조건 준수
6. **보안**: PIN 및 암호화 관련 코드 수정 시 기존 데이터 호환성 확인 필요

---

**📝 이 문서는 새로운 대화창에서 AI가 프로젝트를 이어서 작업할 수 있도록 현재까지의 모든 중요 정보를 포함하고 있습니다.** 