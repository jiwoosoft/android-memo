# 📤 Google Drive API 설정 가이드

> **자동 APK 업로드 및 링크 업데이트 기능 사용을 위한 설정 가이드**

## 🎯 **개요**

이 가이드는 `google_drive_uploader.py`와 `auto_deploy.py` 스크립트에서 Google Drive API를 사용하여 APK 파일을 자동으로 업로드하고 README.md 파일의 다운로드 링크를 자동으로 업데이트하는 기능을 설정하는 방법을 설명합니다.

## 📋 **필요한 준비물**

- Google 계정
- Google Cloud Console 접근 권한
- Python 환경 (이미 설치됨)

## 🔧 **단계별 설정**

### 1단계: Google Cloud Console 프로젝트 생성

1. **Google Cloud Console 접속**
   - 브라우저에서 https://console.cloud.google.com/ 접속
   - Google 계정으로 로그인

2. **새 프로젝트 생성**
   - 상단의 "프로젝트 선택" 드롭다운 클릭
   - "새 프로젝트" 클릭
   - **프로젝트 이름**: `SecureMemo-AutoUpload`
   - **조직**: 선택사항 (개인 계정이면 비워두기)
   - "만들기" 클릭

3. **프로젝트 선택**
   - 생성된 프로젝트가 자동으로 선택되었는지 확인
   - 상단 프로젝트 이름이 "SecureMemo-AutoUpload"인지 확인

### 2단계: Google Drive API 활성화

1. **API 및 서비스 접속**
   - 좌측 메뉴에서 "API 및 서비스" > "라이브러리" 클릭

2. **Google Drive API 검색**
   - 검색창에 "Google Drive API" 입력
   - "Google Drive API" 클릭

3. **API 활성화**
   - "사용 설정" 버튼 클릭
   - 활성화 완료 대기

### 3단계: 서비스 계정 생성

1. **서비스 계정 생성**
   - 좌측 메뉴에서 "API 및 서비스" > "사용자 인증 정보" 클릭
   - "사용자 인증 정보 만들기" > "서비스 계정" 클릭

2. **서비스 계정 정보 입력**
   - **서비스 계정 이름**: `securememo-uploader`
   - **서비스 계정 설명**: `SecureMemo APK 자동 업로드`
   - "만들기 및 계속" 클릭

3. **역할 할당**
   - "역할 선택" 드롭다운 클릭
   - "기본" > "편집자" 선택 (또는 "Drive" > "Drive 파일 소유자")
   - "완료" 클릭

### 4단계: 인증 키 다운로드

1. **키 생성**
   - 생성된 서비스 계정의 이메일 주소 클릭
   - 상단의 "키" 탭 클릭
   - "키 추가" > "새 키 만들기" 클릭

2. **키 형식 선택**
   - **키 유형**: JSON 선택
   - "만들기" 클릭

3. **키 파일 저장**
   - 자동으로 다운로드된 JSON 파일을 프로젝트 루트 디렉터리로 이동
   - 파일명을 `credentials.json`으로 변경
   - ⚠️ **중요**: 이 파일은 절대 GitHub에 업로드하지 말 것!

### 5단계: Python 라이브러리 설치

프로젝트 루트 디렉터리에서 다음 명령어 실행:

```bash
pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib
```

### 6단계: .gitignore 설정

프로젝트 루트의 `.gitignore` 파일에 다음 내용 추가:

```
# Google Drive API 인증 파일
credentials.json
token.json

# 자동 생성된 인증 토큰
*.json
```

### 7단계: 테스트 실행

1. **스크립트 실행**
   ```bash
   python google_drive_uploader.py
   ```

2. **첫 실행 시 인증**
   - 브라우저가 자동으로 열림
   - Google 계정으로 로그인
   - 권한 허용 클릭
   - 성공 메시지 확인

3. **테스트 결과**
   - APK 파일이 Google Drive에 업로드됨
   - 공유 링크가 생성됨
   - README.md 파일이 자동으로 업데이트됨

## 📁 **파일 구조**

설정 완료 후 프로젝트 루트에 다음 파일들이 생성됩니다:

```
memo_app/
├── credentials.json          # Google API 인증 파일 (비공개)
├── token.json               # 자동 생성된 인증 토큰 (비공개)
├── google_drive_uploader.py # Google Drive 업로드 스크립트
├── auto_deploy.py           # 완전 자동화 배포 스크립트
└── .gitignore              # Git 제외 파일 목록
```

## 🚀 **사용 방법**

### 기본 사용법

1. **단순 업로드**
   ```bash
   python google_drive_uploader.py
   ```

2. **특정 버전으로 업로드**
   ```bash
   python google_drive_uploader.py --version 1.0.4
   ```

3. **완전 자동화 배포**
   ```bash
   python auto_deploy.py patch  # 버전 업데이트 + 빌드 + 업로드 + 배포
   ```

### 고급 사용법

1. **현재 버전 재배포**
   ```bash
   python auto_deploy.py --current
   ```

2. **부분 배포 (업로드 제외)**
   ```bash
   python auto_deploy.py patch --no-upload
   ```

3. **테스트 빌드 (Git 제외)**
   ```bash
   python auto_deploy.py patch --no-git --no-release
   ```

## 🔧 **설정 최적화**

### 폴더 구조 최적화

Google Drive에서 다음과 같은 폴더 구조가 자동으로 생성됩니다:

```
📁 SecureMemo_APK/
├── 📱 SecureMemo_v1.0.3.apk
├── 📱 SecureMemo_v1.0.4.apk
└── 📱 SecureMemo_v1.0.5.apk
```

### 권한 설정

- **서비스 계정**: Drive 파일 소유자 권한
- **공유 설정**: 링크가 있는 모든 사용자 읽기 권한
- **보안**: 인증 파일은 로컬에만 저장

## ⚠️ **보안 주의사항**

1. **인증 파일 보안**
   - `credentials.json` 파일을 절대 공개하지 말 것
   - `.gitignore`에 반드시 추가
   - 정기적으로 키 교체 권장

2. **권한 최소화**
   - 필요한 최소 권한만 부여
   - Drive API 파일 생성/읽기/쓰기 권한만 사용

3. **토큰 관리**
   - `token.json` 파일도 비공개로 유지
   - 만료 시 자동 갱신됨

## 🐛 **문제 해결**

### 자주 발생하는 오류

1. **"credentials.json을 찾을 수 없습니다"**
   - 인증 파일이 프로젝트 루트에 있는지 확인
   - 파일명이 정확한지 확인

2. **"권한이 거부되었습니다"**
   - Google Cloud Console에서 API 활성화 확인
   - 서비스 계정 권한 확인

3. **"할당량 초과"**
   - Google Drive API 할당량 확인
   - 잠시 후 다시 시도

### 로그 확인

스크립트 실행 시 상세한 로그가 출력됩니다:

```
🔐 Google Drive 인증 진행 중...
✅ Google Drive API 인증 완료
📁 기존 폴더 사용: SecureMemo_APK
📤 업로드 시작: SecureMemo_v1.0.4.apk (58.8MB)
📈 업로드 진행률: 25%
📈 업로드 진행률: 50%
📈 업로드 진행률: 75%
📈 업로드 진행률: 100%
✅ 업로드 완료
🔗 공유 링크 생성: https://drive.google.com/file/d/...
🔄 기존 다운로드 링크 업데이트
✅ README.md 업데이트 완료
🎉 모든 작업이 완료되었습니다!
```

## 📞 **지원**

문제가 발생하거나 추가 도움이 필요한 경우:

1. **로그 확인**: 스크립트 실행 시 출력되는 상세 로그 확인
2. **설정 재확인**: 이 가이드의 단계를 다시 확인
3. **Google Cloud Console**: API 활성화 상태 및 서비스 계정 권한 확인

---

**🎉 설정이 완료되면 한 번의 명령어로 완전 자동화된 배포가 가능합니다!** 