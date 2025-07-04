# 📝 버전 관리 가이드

## 🎯 개요

안전한 메모장 앱의 체계적인 버전 관리를 위한 가이드입니다.

## 📋 버전 체계

### 버전 번호 구조
```
major.minor.patch+build
예: 1.2.3+45
```

- **major**: 주요 변경사항 (호환성 파괴)
- **minor**: 새로운 기능 추가
- **patch**: 버그 수정
- **build**: 빌드 번호 (자동 증가)

## 🚀 자동 버전 업데이트

### 1. 스크립트 사용법

```bash
# 패치 버전 업데이트 (버그 수정)
python update_version.py patch

# 마이너 버전 업데이트 (새 기능)
python update_version.py minor

# 메이저 버전 업데이트 (큰 변경)
python update_version.py major

# 빌드 번호만 증가
python update_version.py build
```

### 2. 자동 실행 과정

1. **버전 번호 업데이트**
   - `pubspec.yaml` 버전 변경
   - `README.md` 파일들 업데이트
   - `CHANGELOG.md` 항목 추가

2. **Flutter 빌드**
   - 패키지 의존성 업데이트
   - APK 릴리즈 빌드

3. **Git 관리**
   - 변경사항 커밋
   - 버전 태그 생성

## 📱 앱 내 버전 표시

### 설정 화면에서 확인
- 동적 버전 정보 표시
- 빌드 번호 포함
- 패키지명 정보

### 코드 구현
```dart
import 'package:package_info_plus/package_info_plus.dart';

final packageInfo = await PackageInfo.fromPlatform();
print('Version: ${packageInfo.version}');
print('Build: ${packageInfo.buildNumber}');
```

## 📦 릴리즈 프로세스

### 1. 개발 완료 후
```bash
# 기능 개발 완료 후 버전 업데이트
python update_version.py minor

# 또는 버그 수정의 경우
python update_version.py patch
```

### 2. CHANGELOG.md 편집
생성된 템플릿에 실제 변경사항 기록:
```markdown
## 📦 v1.1.0 - 2025.07.04

### 🆕 새로운 기능
- 메모 데이터 암호화 기능 추가
- 앱 생명주기 보안 관리

### 🔧 개선사항
- 설정 화면 UI 개선
- 동적 버전 정보 표시

### 🐛 버그 수정
- PIN 입력 시 키보드 가림 현상 해결
```

### 3. APK 배포
```bash
# APK 파일 확인
ls -la build/app/outputs/flutter-apk/app-release.apk

# Google Drive에 업로드
# README.md의 다운로드 링크 확인
```

### 4. Git 푸시
```bash
# 원격 저장소에 푸시
git push origin main
git push origin v1.1.0
```

## 🔄 수동 버전 업데이트

자동 스크립트를 사용할 수 없는 경우:

### 1. pubspec.yaml 수정
```yaml
version: 1.1.0+2  # 이전: 1.0.0+1
```

### 2. README.md 수정
```markdown
### 🚀 최신 버전 (v1.1.0)
- **최종 업데이트**: 2025.07.04
```

### 3. Flutter 빌드
```bash
flutter pub get
flutter build apk --release
```

### 4. Git 커밋
```bash
git add .
git commit -m "🚀 Release v1.1.0 - minor 업데이트"
git tag -a v1.1.0 -m "Release v1.1.0"
```

## 📊 버전 이력 관리

### CHANGELOG.md 구조
```markdown
# 📜 변경 로그

## 📦 v1.1.0 - 2025.07.04
### 🆕 새로운 기능
### 🔧 개선사항
### 🐛 버그 수정

## 📦 v1.0.0 - 2025.07.04
### 🆕 새로운 기능
### 🔧 개선사항
### 🐛 버그 수정
```

### Git 태그 관리
```bash
# 모든 태그 확인
git tag

# 특정 태그 정보
git show v1.0.0

# 태그 삭제 (필요시)
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
```

## 🚨 주의사항

### 1. 호환성 고려
- **major** 업데이트: 데이터 구조 변경 시 마이그레이션 코드 필요
- **minor** 업데이트: 기존 기능에 영향 없이 새 기능 추가
- **patch** 업데이트: 버그 수정만, 새 기능 추가 금지

### 2. APK 배포
- Google Drive에 새 APK 업로드 후 이전 버전 삭제
- README.md의 파일 크기 정보 업데이트
- 다운로드 링크 테스트

### 3. 버전 롤백
```bash
# 잘못된 버전 태그 삭제
git tag -d v1.1.0
git push origin :refs/tags/v1.1.0

# 이전 커밋으로 복원
git reset --hard HEAD~1
```

## 📈 버전별 체크리스트

### 🔧 patch (버그 수정)
- [ ] 버그 수정 코드 완료
- [ ] 테스트 완료
- [ ] `python update_version.py patch`
- [ ] CHANGELOG.md 편집
- [ ] APK Google Drive 업로드
- [ ] Git 푸시

### 🆕 minor (새 기능)
- [ ] 새 기능 개발 완료
- [ ] UI/UX 테스트 완료
- [ ] `python update_version.py minor`
- [ ] CHANGELOG.md 편집
- [ ] 스크린샷 업데이트 (필요시)
- [ ] APK Google Drive 업로드
- [ ] Git 푸시

### 🚀 major (큰 변경)
- [ ] 큰 변경사항 개발 완료
- [ ] 하위 호환성 검토
- [ ] 데이터 마이그레이션 코드 (필요시)
- [ ] 전체 테스트 완료
- [ ] `python update_version.py major`
- [ ] CHANGELOG.md 상세 편집
- [ ] README.md 전체 검토
- [ ] APK Google Drive 업로드
- [ ] Git 푸시
- [ ] 릴리즈 공지

---

**💡 팁**: 정기적인 버전 업데이트를 통해 사용자에게 지속적인 개선사항을 제공하세요! 