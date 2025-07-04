#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
안전한 메모장 앱 완전 자동화 배포 스크립트
버전 업데이트 → 빌드 → 구글 드라이브 업로드 → 링크 업데이트 → GitHub 릴리즈

사용법:
  python auto_deploy.py patch      # 1.0.3 → 1.0.4
  python auto_deploy.py minor      # 1.0.3 → 1.1.0
  python auto_deploy.py major      # 1.0.3 → 2.0.0
  python auto_deploy.py --current  # 현재 버전으로 재배포
"""

import os
import sys
import re
import argparse
import subprocess
import json
from datetime import datetime
from pathlib import Path

# 현재 디렉터리를 스크립트 파일 위치로 변경
script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)

def run_command(command, check=True, capture_output=False):
    """명령어 실행 및 결과 반환"""
    try:
        print(f"🔧 실행: {command}")
        if capture_output:
            result = subprocess.run(command, shell=True, check=check, 
                                  capture_output=True, text=True, encoding='utf-8')
            return result.stdout.strip() if result.stdout else ""
        else:
            result = subprocess.run(command, shell=True, check=check)
            return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"❌ 명령어 실행 실패: {command}")
        print(f"❌ 에러: {e}")
        return False

def get_current_version():
    """pubspec.yaml에서 현재 버전 정보 추출"""
    try:
        with open('pubspec.yaml', 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 버전 패턴 검색
        match = re.search(r'version:\s*(.+)', content)
        if match:
            version_info = match.group(1).strip()
            # 버전과 빌드 번호 분리
            if '+' in version_info:
                version, build = version_info.split('+')
                return version.strip(), int(build.strip())
            else:
                return version_info.strip(), 1
        
        return None, None
        
    except Exception as e:
        print(f"❌ 버전 정보 추출 실패: {e}")
        return None, None

def update_version(version_type):
    """버전 업데이트"""
    current_version, current_build = get_current_version()
    
    if not current_version:
        print("❌ 현재 버전을 찾을 수 없습니다.")
        return None, None
    
    # 현재 버전 파싱
    try:
        major, minor, patch = map(int, current_version.split('.'))
    except ValueError:
        print(f"❌ 잘못된 버전 형식: {current_version}")
        return None, None
    
    # 새 버전 계산
    if version_type == 'major':
        major += 1
        minor = 0
        patch = 0
    elif version_type == 'minor':
        minor += 1
        patch = 0
    elif version_type == 'patch':
        patch += 1
    elif version_type == 'current':
        # 현재 버전 유지
        pass
    else:
        print(f"❌ 잘못된 버전 타입: {version_type}")
        return None, None
    
    new_version = f"{major}.{minor}.{patch}"
    new_build = current_build + 1 if version_type != 'current' else current_build
    
    print(f"🔄 버전 업데이트: {current_version}+{current_build} → {new_version}+{new_build}")
    
    # pubspec.yaml 업데이트
    try:
        with open('pubspec.yaml', 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 버전 정보 업데이트
        old_version_line = f"version: {current_version}+{current_build}"
        new_version_line = f"version: {new_version}+{new_build}"
        
        updated_content = content.replace(old_version_line, new_version_line)
        
        with open('pubspec.yaml', 'w', encoding='utf-8') as f:
            f.write(updated_content)
        
        print("✅ pubspec.yaml 업데이트 완료")
        return new_version, new_build
        
    except Exception as e:
        print(f"❌ pubspec.yaml 업데이트 실패: {e}")
        return None, None

def update_changelog(version, build):
    """CHANGELOG.md 업데이트"""
    changelog_path = 'CHANGELOG.md'
    
    if not os.path.exists(changelog_path):
        print("⚠️ CHANGELOG.md 파일이 없습니다. 새로 생성합니다.")
        changelog_content = "# 변경사항\n\n"
    else:
        with open(changelog_path, 'r', encoding='utf-8') as f:
            changelog_content = f.read()
    
    # 새 버전 항목 추가
    new_entry = f"""## v{version}+{build} ({datetime.now().strftime('%Y-%m-%d')})

### 추가된 기능
- [여기에 새로운 기능을 추가하세요]

### 개선사항
- [여기에 개선사항을 추가하세요]

### 버그 수정
- [여기에 버그 수정사항을 추가하세요]

---

"""
    
    # 기존 내용 앞에 새 항목 추가
    if "# 변경사항" in changelog_content:
        updated_content = changelog_content.replace(
            "# 변경사항\n\n", 
            f"# 변경사항\n\n{new_entry}"
        )
    else:
        updated_content = f"# 변경사항\n\n{new_entry}{changelog_content}"
    
    with open(changelog_path, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    
    print("✅ CHANGELOG.md 업데이트 완료")

def flutter_build():
    """Flutter APK 빌드"""
    print("🏗️ Flutter APK 빌드 시작...")
    
    # 의존성 업데이트
    if not run_command("flutter pub get"):
        return False
    
    # 릴리즈 APK 빌드
    if not run_command("flutter build apk --release"):
        return False
    
    # 빌드 파일 확인
    apk_path = "build/app/outputs/flutter-apk/app-release.apk"
    if not os.path.exists(apk_path):
        print(f"❌ APK 파일을 찾을 수 없습니다: {apk_path}")
        return False
    
    # 파일 크기 확인
    file_size = os.path.getsize(apk_path)
    print(f"✅ APK 빌드 완료: {file_size / 1024 / 1024:.1f}MB")
    
    return True

def upload_to_google_drive(version):
    """Google Drive에 APK 업로드"""
    print("☁️ Google Drive 업로드 시작...")
    
    # google_drive_uploader.py 스크립트 실행
    upload_command = f"python google_drive_uploader.py --version {version}"
    
    if not run_command(upload_command):
        print("❌ Google Drive 업로드 실패")
        return False
    
    print("✅ Google Drive 업로드 완료")
    return True

def git_commit_and_push(version, build):
    """Git 커밋 및 푸시"""
    print("📝 Git 커밋 및 푸시 시작...")
    
    # 변경사항 추가
    if not run_command("git add ."):
        return False
    
    # 커밋
    commit_message = f"🚀 Release v{version}+{build} - 자동 배포"
    if not run_command(f'git commit -m "{commit_message}"'):
        return False
    
    # 푸시
    if not run_command("git push origin main"):
        return False
    
    print("✅ Git 커밋 및 푸시 완료")
    return True

def create_github_release(version, build, google_drive_link=None):
    """GitHub 릴리즈 생성"""
    print("🏷️ GitHub 릴리즈 생성 시작...")
    
    # GitHub CLI 설치 확인
    if not run_command("gh --version", capture_output=True):
        print("❌ GitHub CLI가 설치되지 않았습니다.")
        print("💡 https://cli.github.com/ 에서 GitHub CLI를 설치하세요.")
        return False
    
    # Google Drive 링크가 없으면 README.md에서 추출 시도
    if not google_drive_link:
        try:
            with open('README.md', 'r', encoding='utf-8') as f:
                readme_content = f.read()
            
            # Google Drive 링크 추출
            import re
            pattern = r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)/[^)\s]*'
            match = re.search(pattern, readme_content)
            if match:
                google_drive_link = match.group(0)
                print(f"📋 README.md에서 Google Drive 링크 추출: {google_drive_link}")
            else:
                print("⚠️ Google Drive 링크를 찾을 수 없습니다.")
        except Exception as e:
            print(f"⚠️ README.md 읽기 실패: {e}")
    
    # 릴리즈 노트 생성
    download_section = ""
    if google_drive_link:
        download_section = f"""### 📱 **APK 다운로드**
**[📱 APK 다운로드 (Google Drive)]({google_drive_link})**

"""
    
    release_notes = f"""## 🚀 v{version}+{build} 릴리즈

{download_section}### ✨ **새로운 기능**
- 🔍 **메모 검색 기능** - 카테고리명, 메모 제목, 내용 검색 지원
- 🔄 **메모 정렬 옵션** - 생성일, 수정일, 제목, 내용별 정렬 (오름차순/내림차순)
- 🎨 **다크/라이트 테마** - 시스템 설정 연동 또는 수동 선택
- 📝 **폰트 크기 조정** - 4단계 폰트 크기 (작게/보통/크게/매우 크게)
- 🏷️ **메모 태그 기능** - 태그 추가, 태그별 필터링, 태그 관리

### 🔧 **기술 정보**
- **버전**: v{version}+{build}
- **빌드 날짜**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **최소 Android 버전**: Android 5.0 (API 21+)
- **파일 크기**: 약 60MB

### 📋 **설치 방법**
1. 위 Google Drive 링크에서 APK 파일 다운로드
2. Android 설정에서 "알 수 없는 소스" 허용
3. 다운로드한 APK 파일 실행하여 설치

### 🔒 **보안 주의사항**
- PIN 코드를 분실하면 모든 데이터가 삭제됩니다
- 정기적으로 중요한 메모를 백업하세요

---
💡 **문제가 있으신가요?** [GitHub Issues](https://github.com/jiwoosoft/android-memo/issues)에 문의해주세요!
"""
    
    # GitHub 릴리즈 생성
    release_command = f'gh release create v{version} --title "v{version} - 자동 배포" --notes "{release_notes}"'
    
    if not run_command(release_command):
        print("❌ GitHub 릴리즈 생성 실패")
        return False
    
    print("✅ GitHub 릴리즈 생성 완료")
    return True

def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(description='안전한 메모장 앱 자동 배포')
    parser.add_argument('version_type', nargs='?', default='patch',
                       choices=['major', 'minor', 'patch', 'current'],
                       help='버전 업데이트 타입 (기본: patch)')
    parser.add_argument('--current', action='store_true',
                       help='현재 버전으로 재배포')
    parser.add_argument('--no-upload', action='store_true',
                       help='Google Drive 업로드 건너뛰기')
    parser.add_argument('--no-git', action='store_true',
                       help='Git 커밋/푸시 건너뛰기')
    parser.add_argument('--no-release', action='store_true',
                       help='GitHub 릴리즈 생성 건너뛰기')
    
    args = parser.parse_args()
    
    # 현재 버전 재배포인지 확인
    if args.current:
        version_type = 'current'
    else:
        version_type = args.version_type
    
    print("🚀 안전한 메모장 앱 자동 배포 시작")
    print(f"🏷️  버전 타입: {version_type}")
    print("=" * 50)
    
    # 1단계: 버전 업데이트
    if version_type != 'current':
        new_version, new_build = update_version(version_type)
        if not new_version:
            print("❌ 버전 업데이트 실패")
            return False
        
        # CHANGELOG.md 업데이트
        update_changelog(new_version, new_build)
    else:
        # 현재 버전 정보 가져오기
        new_version, new_build = get_current_version()
        if not new_version:
            print("❌ 현재 버전을 찾을 수 없습니다.")
            return False
        print(f"🔄 현재 버전으로 재배포: {new_version}+{new_build}")
    
    # 2단계: Flutter 빌드
    if not flutter_build():
        print("❌ Flutter 빌드 실패")
        return False
    
    # 3단계: Google Drive 업로드
    if not args.no_upload:
        if not upload_to_google_drive(new_version):
            print("❌ Google Drive 업로드 실패")
            return False
    else:
        print("⏭️ Google Drive 업로드 건너뛰기")
    
    # 4단계: Git 커밋 및 푸시
    if not args.no_git:
        if not git_commit_and_push(new_version, new_build):
            print("❌ Git 커밋/푸시 실패")
            return False
    else:
        print("⏭️ Git 커밋/푸시 건너뛰기")
    
    # 5단계: GitHub 릴리즈 생성
    if not args.no_release:
        # Google Drive 링크 추출 (google_drive_uploader.py 실행 후 README.md에서 가져옴)
        google_drive_link = None
        try:
            with open('README.md', 'r', encoding='utf-8') as f:
                readme_content = f.read()
            
            import re
            pattern = r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)/[^)\s]*'
            match = re.search(pattern, readme_content)
            if match:
                google_drive_link = match.group(0)
                print(f"📋 README.md에서 Google Drive 링크 추출: {google_drive_link}")
        except Exception as e:
            print(f"⚠️ README.md 읽기 실패: {e}")
        
        if not create_github_release(new_version, new_build, google_drive_link):
            print("❌ GitHub 릴리즈 생성 실패")
            return False
    else:
        print("⏭️ GitHub 릴리즈 생성 건너뛰기")
    
    print("=" * 50)
    print("🎉 자동 배포 완료!")
    print(f"📱 새 버전: v{new_version}+{new_build}")
    print(f"🔗 GitHub 릴리즈: https://github.com/jiwoosoft/android-memo/releases/tag/v{new_version}")
    print(f"📥 다운로드: README.md 참조")
    
    return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1) 