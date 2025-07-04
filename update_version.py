#!/usr/bin/env python3
"""
Flutter 앱 버전 업데이트 자동화 스크립트

사용법:
python update_version.py patch    # 1.0.0 -> 1.0.1
python update_version.py minor    # 1.0.0 -> 1.1.0
python update_version.py major    # 1.0.0 -> 2.0.0
python update_version.py build    # 빌드 번호만 증가
"""

import re
import sys
import subprocess
import os
from datetime import datetime

def read_file(filepath):
    """파일 읽기"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(filepath, content):
    """파일 쓰기"""
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def get_current_version():
    """pubspec.yaml에서 현재 버전 가져오기"""
    content = read_file('pubspec.yaml')
    match = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)', content)
    if match:
        major, minor, patch, build = map(int, match.groups())
        return major, minor, patch, build
    return None

def update_pubspec_version(major, minor, patch, build):
    """pubspec.yaml 버전 업데이트"""
    content = read_file('pubspec.yaml')
    new_version = f"version: {major}.{minor}.{patch}+{build}"
    updated_content = re.sub(r'version:\s*\d+\.\d+\.\d+\+\d+', new_version, content)
    write_file('pubspec.yaml', updated_content)
    return f"{major}.{minor}.{patch}"

def update_readme_version(version_string):
    """README.md 파일들 버전 업데이트"""
    files_to_update = ['README.md', 'releases/README.md']
    
    for filepath in files_to_update:
        if os.path.exists(filepath):
            content = read_file(filepath)
            
            # 버전 정보 업데이트
            content = re.sub(
                r'### 🚀 최신 버전 \(v\d+\.\d+\.\d+\)',
                f'### 🚀 최신 버전 (v{version_string})',
                content
            )
            content = re.sub(
                r'v\d+\.\d+\.\d+ \(최신\)',
                f'v{version_string} (최신)',
                content
            )
            
            # 업데이트 날짜 변경
            today = datetime.now().strftime('%Y.%m.%d')
            content = re.sub(
                r'- \*\*최종 업데이트\*\*: \d{4}\.\d{2}\.\d{2}',
                f'- **최종 업데이트**: {today}',
                content
            )
            
            write_file(filepath, content)
            print(f"✅ {filepath} 버전 정보 업데이트 완료")

def create_release_entry(version_string, build_number):
    """새 릴리즈 항목 생성"""
    today = datetime.now().strftime('%Y.%m.%d')
    release_entry = f"""
## 📦 v{version_string} - {today}

### 🆕 새로운 기능
- 추가된 기능들을 여기에 기록하세요

### 🔧 개선사항
- 개선된 사항들을 여기에 기록하세요

### 🐛 버그 수정
- 수정된 버그들을 여기에 기록하세요

### 📱 기술적 변경사항
- 빌드 번호: {build_number}
- 패키지: com.jiwoosoft.secure_memo

---
"""
    
    # CHANGELOG.md가 있으면 추가, 없으면 생성
    changelog_file = 'CHANGELOG.md'
    if os.path.exists(changelog_file):
        content = read_file(changelog_file)
        # 맨 위에 새 릴리즈 항목 추가
        lines = content.split('\n')
        header_end = 0
        for i, line in enumerate(lines):
            if line.startswith('## '):
                header_end = i
                break
        
        new_content = '\n'.join(lines[:header_end]) + release_entry + '\n'.join(lines[header_end:])
        write_file(changelog_file, new_content)
    else:
        # 새 CHANGELOG.md 파일 생성
        header = """# 📜 변경 로그

안전한 메모장 앱의 버전별 변경사항을 기록합니다.

"""
        write_file(changelog_file, header + release_entry)
    
    print(f"✅ CHANGELOG.md에 v{version_string} 항목 추가 완료")

def run_flutter_commands():
    """Flutter 관련 명령 실행"""
    try:
        print("📦 패키지 의존성 업데이트 중...")
        subprocess.run(['flutter', 'pub', 'get'], check=True)
        
        print("🔧 APK 빌드 중...")
        result = subprocess.run(['flutter', 'build', 'apk', '--release'], 
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ APK 빌드 성공!")
            # APK 파일 크기 확인
            apk_path = 'build/app/outputs/flutter-apk/app-release.apk'
            if os.path.exists(apk_path):
                size_mb = os.path.getsize(apk_path) / (1024 * 1024)
                print(f"📱 APK 파일 크기: {size_mb:.1f}MB")
        else:
            print(f"❌ APK 빌드 실패: {result.stderr}")
            
    except subprocess.CalledProcessError as e:
        print(f"❌ Flutter 명령 실행 실패: {e}")
    except FileNotFoundError:
        print("⚠️ Flutter가 설치되지 않았거나 PATH에 없습니다.")

def git_commit_and_tag(version_string, update_type):
    """Git 커밋 및 태그 생성"""
    try:
        # Git 상태 확인
        subprocess.run(['git', 'add', '.'], check=True)
        
        # 커밋 메시지 생성
        commit_msg = f"🚀 Release v{version_string} - {update_type} 업데이트"
        subprocess.run(['git', 'commit', '-m', commit_msg], check=True)
        
        # 태그 생성
        tag_msg = f"Release v{version_string}"
        subprocess.run(['git', 'tag', '-a', f'v{version_string}', '-m', tag_msg], check=True)
        
        print(f"✅ Git 커밋 및 태그 생성 완료: v{version_string}")
        print("📤 원격 저장소에 푸시하려면:")
        print(f"   git push origin main")
        print(f"   git push origin v{version_string}")
        
    except subprocess.CalledProcessError as e:
        print(f"⚠️ Git 명령 실행 실패: {e}")

def main():
    if len(sys.argv) != 2:
        print("사용법: python update_version.py [patch|minor|major|build]")
        sys.exit(1)
    
    update_type = sys.argv[1].lower()
    if update_type not in ['patch', 'minor', 'major', 'build']:
        print("업데이트 타입은 patch, minor, major, build 중 하나여야 합니다.")
        sys.exit(1)
    
    # 현재 버전 가져오기
    current = get_current_version()
    if not current:
        print("❌ pubspec.yaml에서 버전 정보를 찾을 수 없습니다.")
        sys.exit(1)
    
    major, minor, patch, build = current
    print(f"📋 현재 버전: {major}.{minor}.{patch}+{build}")
    
    # 버전 업데이트
    if update_type == 'major':
        major += 1
        minor = 0
        patch = 0
        build += 1
    elif update_type == 'minor':
        minor += 1
        patch = 0
        build += 1
    elif update_type == 'patch':
        patch += 1
        build += 1
    elif update_type == 'build':
        build += 1
    
    new_version = f"{major}.{minor}.{patch}"
    print(f"🆕 새 버전: {new_version}+{build}")
    
    # 확인
    response = input(f"버전을 {new_version}+{build}로 업데이트하시겠습니까? (y/N): ")
    if response.lower() != 'y':
        print("❌ 업데이트가 취소되었습니다.")
        sys.exit(0)
    
    # 버전 업데이트 실행
    print("🔄 버전 업데이트 시작...")
    
    # 1. pubspec.yaml 업데이트
    update_pubspec_version(major, minor, patch, build)
    print(f"✅ pubspec.yaml 업데이트 완료: {new_version}+{build}")
    
    # 2. README.md 파일들 업데이트
    update_readme_version(new_version)
    
    # 3. CHANGELOG.md 업데이트
    create_release_entry(new_version, build)
    
    # 4. Flutter 명령 실행
    run_flutter_commands()
    
    # 5. Git 커밋 및 태그
    git_commit_and_tag(new_version, update_type)
    
    print(f"""
🎉 버전 업데이트 완료!

📋 업데이트 정보:
- 이전 버전: {current[0]}.{current[1]}.{current[2]}+{current[3]}
- 새 버전: {new_version}+{build}
- 업데이트 타입: {update_type}

📝 다음 단계:
1. CHANGELOG.md에서 릴리즈 노트 작성
2. APK 파일을 Google Drive에 업로드
3. README.md의 Google Drive 링크 확인
4. Git 푸시: git push origin main && git push origin v{new_version}
""")

if __name__ == "__main__":
    main() 