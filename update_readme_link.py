#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
README.md 다운로드 링크 업데이트 스크립트
사용법: python update_readme_link.py [구글드라이브링크]
"""

import re
import sys
import argparse
from pathlib import Path

def update_readme_download_link(share_link, version=None):
    """README.md 파일의 다운로드 링크 업데이트"""
    readme_path = 'README.md'
    
    if not Path(readme_path).exists():
        print(f"❌ README.md 파일을 찾을 수 없습니다: {readme_path}")
        return False
    
    try:
        # README.md 파일 읽기
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        print(f"🔍 기존 내용에서 다운로드 링크 검색 중...")
        
        # 다운로드 링크 패턴 검색 및 업데이트
        patterns = [
            r'\[다운로드\]\(https://drive\.google\.com/file/d/[^)]+\)',
            r'\[APK 다운로드\]\(https://drive\.google\.com/file/d/[^)]+\)',
            r'\[Download\]\(https://drive\.google\.com/file/d/[^)]+\)',
            r'\[📱 APK 다운로드 \(Google Drive\)\]\(https://drive\.google\.com/file/d/[^)]+\)'
        ]
        
        updated = False
        
        for pattern in patterns:
            if re.search(pattern, content):
                # 패턴에 맞는 적절한 링크 형식 생성
                if '📱 APK 다운로드' in pattern:
                    new_link = f'[📱 APK 다운로드 (Google Drive)]({share_link})'
                else:
                    new_link = f'[다운로드]({share_link})'
                
                content = re.sub(pattern, new_link, content)
                print(f"🔄 다운로드 링크 패턴 발견 및 업데이트: {pattern}")
                updated = True
                break
        
        if not updated:
            print("⚠️ 기존 다운로드 링크 패턴을 찾을 수 없습니다.")
            print("📝 수동으로 링크를 추가하시겠습니까? (y/n)")
            response = input().lower()
            if response == 'y':
                # README 끝에 다운로드 섹션 추가
                new_link = f"[📱 APK 다운로드 (Google Drive)]({share_link})"
                content += f"\n\n## 📥 다운로드\n\n{new_link}\n"
                updated = True
        
        if updated:
            # 버전 정보 업데이트 (선택사항)
            if version:
                version_pattern = r'v\d+\.\d+\.\d+'
                if re.search(version_pattern, content):
                    content = re.sub(version_pattern, f'v{version}', content)
                    print(f"🔄 버전 정보 업데이트: v{version}")
            
            # 파일 쓰기
            with open(readme_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print("✅ README.md 업데이트 완료!")
            print(f"🔗 새 다운로드 링크: {share_link}")
            return True
        else:
            print("❌ 업데이트되지 않았습니다.")
            return False
        
    except Exception as e:
        print(f"❌ README.md 업데이트 실패: {e}")
        return False

def get_current_version():
    """pubspec.yaml에서 현재 버전 정보 추출"""
    try:
        with open('pubspec.yaml', 'r', encoding='utf-8') as f:
            content = f.read()
        
        match = re.search(r'version:\s*(.+)', content)
        if match:
            version_full = match.group(1).strip()
            version = version_full.split('+')[0]
            return version
        return None
    except Exception:
        return None

def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(description='README.md 다운로드 링크 업데이트')
    parser.add_argument('link', nargs='?', help='Google Drive 공유 링크')
    parser.add_argument('--version', help='버전 번호 (선택사항)')
    
    args = parser.parse_args()
    
    # 링크가 제공되지 않은 경우 입력 요청
    if not args.link:
        print("📎 Google Drive 공유 링크를 입력하세요:")
        share_link = input().strip()
    else:
        share_link = args.link.strip()
    
    # 링크 유효성 검사
    if not share_link.startswith('https://drive.google.com/'):
        print("❌ 올바른 Google Drive 링크가 아닙니다.")
        print("💡 링크는 'https://drive.google.com/'으로 시작해야 합니다.")
        return False
    
    # 버전 정보 가져오기
    version = args.version or get_current_version()
    
    print("🔄 README.md 다운로드 링크 업데이트 시작")
    print(f"🔗 새 링크: {share_link}")
    if version:
        print(f"🏷️  버전: v{version}")
    
    # 링크 업데이트 실행
    success = update_readme_download_link(share_link, version)
    
    if success:
        print("\n🎉 README.md 업데이트 완료!")
    else:
        print("\n❌ 업데이트 실패")
    
    return success

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1) 