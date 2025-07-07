#!/usr/bin/env python3
"""
Flutter 앱 전체 자동화 스크립트:
 - 버전 증가 (patch/minor/major/build)
 - pubspec.yaml, README.md, CHANGELOG.md 자동 수정
 - Flutter APK 빌드
 - Git 커밋, 태그, 푸시
 - Google Drive에 APK 자동 업로드 (Service Account 사용)
사용: python update_version.py patch
"""

import re
import sys
import subprocess
import os
from datetime import datetime
from pathlib import Path
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2 import service_account
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials

GITHUB_REPO = "jiwoosoft/android-memo"
APK_PATH = "build/app/outputs/flutter-apk/app-release.apk"
GOOGLE_FOLDER_ID = "13jxledEKCK4WV1t-eADQPScIvgfcTFVY"


def read_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(filepath, content):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def get_current_version():
    content = read_file('pubspec.yaml')
    match = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)', content)
    return tuple(map(int, match.groups())) if match else None

def update_pubspec_version(major, minor, patch, build):
    content = read_file('pubspec.yaml')
    new_version = f"version: {major}.{minor}.{patch}+{build}"
    updated_content = re.sub(r'version:\s*\d+\.\d+\.\d+\+\d+', new_version, content)
    write_file('pubspec.yaml', updated_content)
    return f"{major}.{minor}.{patch}"

def update_readme_version(version, link):
    today = datetime.now().strftime('%Y.%m.%d')
    for file in ['README.md', 'releases/README.md']:
        if os.path.exists(file):
            content = read_file(file)

            if "### 🚀 다운로드 히스토리" not in content:
                content += "\n\n### 🚀 다운로드 히스토리\n"

            history_entry = f"- v{version} (최신) - {today} → [다운로드 링크]({link})"
            content = re.sub(r'(### 🚀 다운로드 히스토리\n)', r'\1' + history_entry + '\n', content)

            content = re.sub(r'### 🚀 최신 버전 \(v\d+\.\d+\.\d+\)', f'### 🚀 최신 버전 (v{version})', content)
            content = re.sub(r'v\d+\.\d+\.\d+ \(최신\)', f'v{version} (최신)', content)
            content = re.sub(r'- \*\*최종 업데이트\*\*: \d{4}\.\d{2}\.\d{2}', f'- **최종 업데이트**: {today}', content)
            content = re.sub(r'\[다운로드 링크\]\(https://drive.google.com/.+?\)', f'[다운로드 링크]({link})', content)
            write_file(file, content)

def create_release_entry(version, build, link):
    today = datetime.now().strftime('%Y.%m.%d')
    entry = f"""
## 📦 v{version} - {today}

### 🆕 새로운 기능
-

### 🔧 개선사항
-

### 🐛 버그 수정
-

### 📱 기술적 변경사항
- 빌드 번호: {build}
- 패키지: com.jiwoosoft.secure_memo
- [다운로드 링크]({link})

---
"""
    changelog = 'CHANGELOG.md'
    if os.path.exists(changelog):
        content = read_file(changelog)
        new_content = entry + content
    else:
        header = "# 📜 변경 로그\n\n"
        new_content = header + entry
    write_file(changelog, new_content)

def run_flutter():
    try:
        subprocess.run(['flutter', 'pub', 'get'], check=True)
        result = subprocess.run(['flutter', 'build', 'apk', '--release'], capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"APK 빌드 실패: {result.stderr}")
        print("✅ flutter build apk 성공")
    except FileNotFoundError:
        print("⚠️ Flutter가 설치되지 않았거나 PATH에 없습니다.")

def git_commit_tag_push(version, update_type):
    subprocess.run(['git', 'add', '.'], check=True)
    msg = f"🚀 Release v{version} - {update_type} 업데이트"
    subprocess.run(['git', 'commit', '-m', msg], check=True)
    subprocess.run(['git', 'tag', '-a', f'v{version}', '-m', f'Release v{version}'], check=True)
    subprocess.run(['git', 'push', 'origin', 'main'], check=True)
    subprocess.run(['git', 'push', '--tags'], check=True)

def upload_to_google_drive(apk_path, folder_id):
    SCOPES = ['https://www.googleapis.com/auth/drive.file']
    creds = None

    # token.json이 존재하면 불러오기
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)

    # 없거나 만료되었으면 새로 로그인 진행
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                'client_id.json', SCOPES)
            creds = flow.run_local_server(port=0)

        # 로그인 정보 저장
        with open('token.json', 'w') as token:
            token.write(creds.to_json())

    # 구글 드라이브 서비스 생성
    service = build('drive', 'v3', credentials=creds)

    file_metadata = {
        'name': os.path.basename(apk_path),
        'parents': [folder_id]
    }

    media = MediaFileUpload(apk_path, mimetype='application/vnd.android.package-archive')
    file = service.files().create(
        body=file_metadata,
        media_body=media,
        fields='id, webViewLink'
    ).execute()

    print(f"✅ Google Drive 업로드 완료 → 링크: {file.get('webViewLink')}")
    return file.get('webViewLink')

def main():
    if len(sys.argv) != 2:
        sys.exit("사용법: python update_version.py [patch|minor|major|build]")

    update_type = sys.argv[1].lower()
    if update_type not in ['patch', 'minor', 'major', 'build']:
        sys.exit("업데이트 타입은 patch, minor, major, build 중 하나여야 합니다.")

    current = get_current_version()
    if not current:
        sys.exit("❌ pubspec.yaml에서 버전 정보를 찾을 수 없습니다.")

    major, minor, patch, build = current
    if update_type == 'major': major += 1; minor = patch = 0; build += 1
    elif update_type == 'minor': minor += 1; patch = 0; build += 1
    elif update_type == 'patch': patch += 1; build += 1
    elif update_type == 'build': build += 1

    version = update_pubspec_version(major, minor, patch, build)
    print(f"📋 현재 버전: {'.'.join(map(str, current[:3]))}+{current[3]}")
    print(f"🆕 새 버전: {version}+{build}")
    confirm = input(f"버전을 {version}+{build}로 업데이트하시겠습니까? (y/N): ").strip().lower()
    if confirm != 'y':
        print("🚫 업데이트가 취소되었습니다.")
        return

    print("🔄 버전 업데이트 시작...")
    update_pubspec_version(major, minor, patch, build)
    print("✅ pubspec.yaml 업데이트 완료:", f"{version}+{build}")

    run_flutter()

    if not os.path.exists(APK_PATH):
        sys.exit(f"❌ APK 파일을 찾을 수 없습니다: {APK_PATH}")

    link = upload_to_google_drive(APK_PATH, GOOGLE_FOLDER_ID)
    update_readme_version(version, link)
    print("✅ README.md 버전 정보 업데이트 완료")

    create_release_entry(version, build, link)
    print(f"✅ CHANGELOG.md에 v{version} 항목 추가 완료")

    try:
        git_commit_tag_push(version, update_type)
    except Exception as e:
        print(f"⚠️ Git 명령 실행 실패: {e}")

    print(f"\n🎉 버전 업데이트 완료!")
    print(f"\n📋 업데이트 정보:")
    print(f"- 이전 버전: {'.'.join(map(str, current[:3]))}+{current[3]}")
    print(f"- 새 버전: {version}+{build}")
    print(f"- 업데이트 타입: {update_type}")
    print("\n📝 다음 단계:")
    print("1. CHANGELOG.md에서 릴리즈 노트 작성")
    print("2. APK 파일을 Google Drive에 업로드")
    print("3. README.md의 Google Drive 링크 확인")
    print(f"4. Git 푸시: git push origin main && git push origin v{version}")

if __name__ == "__main__":
    main()
