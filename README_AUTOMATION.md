# 🤖 자동화 배포 시스템 사용 가이드

> **한 번의 명령어로 완전 자동화된 배포 시스템**

## 🎯 **개요**

이 자동화 시스템은 다음 과정을 한 번에 수행합니다:
1. 버전 자동 업데이트
2. Flutter APK 빌드
3. Google Drive 자동 업로드
4. README.md 다운로드 링크 업데이트
5. Git 커밋 및 푸시
6. GitHub 릴리즈 자동 생성

## 🚀 **빠른 시작**

### 1. 설치 및 설정

```bash
# 1. Python 라이브러리 설치
pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib

# 2. Google Drive API 설정 (최초 1회만)
# GOOGLE_DRIVE_SETUP.md 파일 참조
```

### 2. 기본 사용법

```bash
# 패치 버전 업데이트 (1.0.3 → 1.0.4)
python auto_deploy.py patch

# 마이너 버전 업데이트 (1.0.3 → 1.1.0)
python auto_deploy.py minor

# 메이저 버전 업데이트 (1.0.3 → 2.0.0)
python auto_deploy.py major

# 현재 버전 재배포
python auto_deploy.py --current
```

## 📋 **실행 과정**

### 자동 실행 단계

1. **🔄 버전 업데이트**
   - pubspec.yaml 버전 자동 증가
   - CHANGELOG.md 새 항목 추가

2. **🏗️ Flutter 빌드**
   - `flutter pub get` 실행
   - `flutter build apk --release` 실행

3. **☁️ Google Drive 업로드**
   - APK 파일 자동 업로드
   - 공유 링크 생성

4. **📝 문서 업데이트**
   - README.md 다운로드 링크 자동 업데이트
   - 버전 정보 업데이트

5. **📤 Git 배포**
   - 모든 변경사항 커밋
   - GitHub 저장소 푸시

6. **🏷️ 릴리즈 생성**
   - GitHub 릴리즈 자동 생성
   - 릴리즈 노트 자동 작성

## 🔧 **고급 사용법**

### 부분 배포 옵션

```bash
# 업로드 제외 (로컬 빌드만)
python auto_deploy.py patch --no-upload

# Git 푸시 제외 (로컬 작업만)
python auto_deploy.py patch --no-git

# 릴리즈 생성 제외
python auto_deploy.py patch --no-release

# 테스트 빌드 (Git 및 릴리즈 제외)
python auto_deploy.py patch --no-git --no-release
```

### 수동 업로드만 실행

```bash
# 현재 APK 파일 업로드
python google_drive_uploader.py

# 특정 버전으로 업로드
python google_drive_uploader.py --version 1.0.4

# README 업데이트 제외
python google_drive_uploader.py --no-readme
```

## 📊 **실행 결과 예시**

### 성공적인 배포 로그

```
🚀 안전한 메모장 앱 자동 배포 시작
🏷️  버전 타입: patch
==================================================
🔄 버전 업데이트: 1.0.3+4 → 1.0.4+5
✅ pubspec.yaml 업데이트 완료
✅ CHANGELOG.md 업데이트 완료
🏗️ Flutter APK 빌드 시작...
🔧 실행: flutter pub get
🔧 실행: flutter build apk --release
✅ APK 빌드 완료: 58.8MB
☁️ Google Drive 업로드 시작...
🔐 Google Drive 인증 진행 중...
✅ Google Drive API 인증 완료
📁 기존 폴더 사용: SecureMemo_APK
📤 업로드 시작: SecureMemo_v1.0.4.apk (58.8MB)
📈 업로드 진행률: 100%
✅ 업로드 완료
🔗 공유 링크 생성: https://drive.google.com/file/d/...
🔄 기존 다운로드 링크 업데이트
✅ README.md 업데이트 완료
✅ Google Drive 업로드 완료
📝 Git 커밋 및 푸시 시작...
✅ Git 커밋 및 푸시 완료
🏷️ GitHub 릴리즈 생성 시작...
✅ GitHub 릴리즈 생성 완료
==================================================
🎉 자동 배포 완료!
📱 새 버전: v1.0.4+5
🔗 GitHub 릴리즈: https://github.com/jiwoosoft/android-memo/releases/tag/v1.0.4
📥 다운로드: README.md 참조
```

## 🛠️ **생성되는 파일들**

### 자동 업데이트 파일들

- `pubspec.yaml`: 버전 번호 자동 증가
- `CHANGELOG.md`: 새 버전 항목 추가
- `README.md`: 다운로드 링크 자동 업데이트
- `build/app/outputs/flutter-apk/app-release.apk`: 새 APK 파일

### Google Drive 구조

```
📁 SecureMemo_APK/
├── 📱 SecureMemo_v1.0.3.apk
├── 📱 SecureMemo_v1.0.4.apk
├── 📱 SecureMemo_v1.0.5.apk
└── 📱 SecureMemo_latest.apk
```

## ⚠️ **주의사항**

### 필수 조건

1. **Google Drive API 설정 완료**
   - `credentials.json` 파일 필요
   - `GOOGLE_DRIVE_SETUP.md` 가이드 참조

2. **GitHub CLI 설치**
   - `gh --version` 명령어로 확인
   - https://cli.github.com 에서 설치

3. **Flutter 환경 설정**
   - `flutter doctor` 명령어로 확인
   - Android SDK 설치 필요

### 실행 전 확인사항

- [ ] 현재 프로젝트 상태가 안정적인지 확인
- [ ] Git 저장소 상태 확인 (`git status`)
- [ ] 인터넷 연결 상태 확인
- [ ] Google Drive 저장 공간 확인

## 🐛 **문제 해결**

### 자주 발생하는 문제

1. **빌드 실패**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. **업로드 실패**
   - 인터넷 연결 확인
   - `credentials.json` 파일 확인
   - Google Drive 용량 확인

3. **Git 푸시 실패**
   - `git status` 확인
   - 충돌 해결 후 재시도

4. **릴리즈 생성 실패**
   - GitHub CLI 로그인 확인: `gh auth login`
   - 저장소 권한 확인

## 📞 **지원**

문제가 발생하면:
1. 로그 메시지 확인
2. 각 단계별 수동 실행으로 문제 구간 파악
3. 설정 파일 재확인

---

**🎉 한 번의 명령어로 완전 자동화된 배포를 경험해보세요!**

```bash
python auto_deploy.py patch
``` 