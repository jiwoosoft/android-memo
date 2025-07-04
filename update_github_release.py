#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GitHub 릴리즈 노트 업데이트 스크립트
Google Drive 링크를 릴리즈 노트에 추가합니다.

사용법:
python update_github_release.py v1.0.5 "https://drive.google.com/file/d/19Rm9Klj0L3Fy_SkEYwqL1vNAm46P0gWi/view?usp=drivesdk"
"""

import requests
import json
import sys
import os
from datetime import datetime

# GitHub 설정
GITHUB_OWNER = "jiwoosoft"
GITHUB_REPO = "android-memo"
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')  # 환경변수에서 토큰 가져오기

def get_release_by_tag(tag_name):
    """태그로 릴리즈 정보 가져오기"""
    url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/releases/tags/{tag_name}"
    
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github.v3+json',
    }
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"❌ 릴리즈 정보 가져오기 실패: {response.status_code}")
            print(f"응답: {response.text}")
            return None
    except Exception as e:
        print(f"❌ API 호출 오류: {e}")
        return None

def update_release_body(release_id, new_body):
    """릴리즈 노트 업데이트"""
    url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/releases/{release_id}"
    
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
    }
    
    data = {
        'body': new_body
    }
    
    try:
        response = requests.patch(url, headers=headers, json=data)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"❌ 릴리즈 업데이트 실패: {response.status_code}")
            print(f"응답: {response.text}")
            return None
    except Exception as e:
        print(f"❌ API 호출 오류: {e}")
        return None

def create_release_body(tag_name, google_drive_link):
    """릴리즈 노트 생성"""
    # 버전에서 +뒤의 빌드 번호 추출
    build_number = ""
    if '+' in tag_name:
        build_number = f"+{tag_name.split('+')[1]}"
    
    # 태그 기능 목록 (v1.0.5 기준)
    features = {
        "v1.0.5": [
            "🔍 **메모 검색 기능** - 카테고리명, 메모 제목, 내용 검색 지원",
            "🔄 **메모 정렬 옵션** - 생성일, 수정일, 제목, 내용별 정렬 (오름차순/내림차순)",
            "🎨 **다크/라이트 테마** - 시스템 설정 연동 또는 수동 선택",
            "📝 **폰트 크기 조정** - 4단계 폰트 크기 (작게/보통/크게/매우 크게)",
            "🏷️ **메모 태그 기능** - 태그 추가, 태그별 필터링, 태그 관리"
        ],
        "v1.0.4": [
            "🔍 **메모 검색 기능** - 카테고리명, 메모 제목, 내용 검색 지원",
            "🔄 **메모 정렬 옵션** - 생성일, 수정일, 제목, 내용별 정렬 (오름차순/내림차순)",
            "🎨 **다크/라이트 테마** - 시스템 설정 연동 또는 수동 선택",
            "📝 **폰트 크기 조정** - 4단계 폰트 크기 (작게/보통/크게/매우 크게)"
        ]
    }
    
    version_key = tag_name.split('+')[0]  # +뒤의 빌드 번호 제거
    feature_list = features.get(version_key, ["새로운 기능이 추가되었습니다."])
    
    release_body = f"""## 🚀 {tag_name} 릴리즈

### 📱 **APK 다운로드**
**[📱 APK 다운로드 (Google Drive)]({google_drive_link})**

### ✨ **새로운 기능**
"""
    
    for feature in feature_list:
        release_body += f"- {feature}\n"
    
    release_body += f"""
### 🔧 **기술 정보**
- **버전**: {tag_name}
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
💡 **문제가 있으신가요?** [GitHub Issues](https://github.com/{GITHUB_OWNER}/{GITHUB_REPO}/issues)에 문의해주세요!
"""
    
    return release_body

def main():
    if len(sys.argv) < 3:
        print("사용법: python update_github_release.py <태그명> <Google Drive 링크>")
        print("예시: python update_github_release.py v1.0.5 \"https://drive.google.com/file/d/19Rm9Klj0L3Fy_SkEYwqL1vNAm46P0gWi/view?usp=drivesdk\"")
        sys.exit(1)
    
    tag_name = sys.argv[1]
    google_drive_link = sys.argv[2]
    
    # GitHub 토큰 확인
    if not GITHUB_TOKEN:
        print("❌ GITHUB_TOKEN 환경변수가 설정되지 않았습니다.")
        print("GitHub Personal Access Token을 설정하세요:")
        print("Windows: set GITHUB_TOKEN=your_token_here")
        print("Linux/Mac: export GITHUB_TOKEN=your_token_here")
        sys.exit(1)
    
    print(f"🔍 GitHub 릴리즈 {tag_name} 정보 가져오는 중...")
    
    # 릴리즈 정보 가져오기
    release_info = get_release_by_tag(tag_name)
    if not release_info:
        print(f"❌ 릴리즈 {tag_name}을 찾을 수 없습니다.")
        sys.exit(1)
    
    print(f"✅ 릴리즈 정보 가져오기 성공: {release_info['name']}")
    print(f"📅 생성일: {release_info['created_at']}")
    print(f"🔗 현재 릴리즈 노트 길이: {len(release_info['body'])} 문자")
    
    # 새로운 릴리즈 노트 생성
    new_body = create_release_body(tag_name, google_drive_link)
    
    print(f"\n📝 새로운 릴리즈 노트 미리보기:")
    print("-" * 50)
    print(new_body[:500] + "..." if len(new_body) > 500 else new_body)
    print("-" * 50)
    
    # 사용자 확인
    confirm = input(f"\n🤔 릴리즈 노트를 업데이트하시겠습니까? (y/n): ")
    if confirm.lower() != 'y':
        print("❌ 업데이트 취소")
        sys.exit(0)
    
    # 릴리즈 업데이트
    print(f"🔄 GitHub 릴리즈 {tag_name} 업데이트 중...")
    updated_release = update_release_body(release_info['id'], new_body)
    
    if updated_release:
        print(f"✅ 릴리즈 노트 업데이트 성공!")
        print(f"🔗 릴리즈 URL: {updated_release['html_url']}")
        print(f"📱 Google Drive 링크: {google_drive_link}")
        
        # 업데이트된 내용 확인
        print(f"\n📊 업데이트 결과:")
        print(f"- 이전 노트 길이: {len(release_info['body'])} 문자")
        print(f"- 새 노트 길이: {len(updated_release['body'])} 문자")
        print(f"- 업데이트 시간: {updated_release['updated_at']}")
        
    else:
        print(f"❌ 릴리즈 노트 업데이트 실패")
        sys.exit(1)

if __name__ == "__main__":
    main() 