#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Google Drive APK 자동 업로드 및 링크 업데이트 스크립트
사용법: python google_drive_uploader.py [APK파일경로]
"""

import os
import sys
import json
import re
import argparse
from datetime import datetime
import subprocess
from pathlib import Path

try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload
    from googleapiclient.errors import HttpError
except ImportError:
    print("❌ Google API 라이브러리가 설치되지 않았습니다.")
    print("📦 다음 명령어로 설치하세요:")
    print("pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib")
    sys.exit(1)

# Google Drive API 스코프 설정
SCOPES = ['https://www.googleapis.com/auth/drive.file']

class GoogleDriveUploader:
    def __init__(self, credentials_path='credentials.json', token_path='token.json'):
        """
        Google Drive 업로더 초기화
        
        Args:
            credentials_path (str): Google Cloud Console에서 다운로드한 credentials.json 파일 경로
            token_path (str): 인증 토큰 저장 파일 경로
        """
        self.credentials_path = credentials_path
        self.token_path = token_path
        self.service = None
        self.folder_id = None
        
    def authenticate(self):
        """Google Drive API 인증 처리"""
        creds = None
        
        # 기존 토큰 파일이 있으면 로드
        if os.path.exists(self.token_path):
            creds = Credentials.from_authorized_user_file(self.token_path, SCOPES)
        
        # 유효하지 않은 인증 정보라면 새로 인증
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                print("🔄 인증 토큰 갱신 중...")
                creds.refresh(Request())
            else:
                if not os.path.exists(self.credentials_path):
                    print(f"❌ 인증 파일을 찾을 수 없습니다: {self.credentials_path}")
                    print("📋 Google Cloud Console에서 credentials.json을 다운로드하세요.")
                    return False
                
                print("🔐 Google Drive 인증 진행 중...")
                flow = InstalledAppFlow.from_client_secrets_file(
                    self.credentials_path, SCOPES)
                creds = flow.run_local_server(port=0)
            
            # 토큰 저장
            with open(self.token_path, 'w') as token:
                token.write(creds.to_json())
        
        self.service = build('drive', 'v3', credentials=creds)
        print("✅ Google Drive API 인증 완료")
        return True
    
    def create_folder(self, folder_name, parent_id=None):
        """Google Drive에 폴더 생성 (이미 존재하면 기존 폴더 사용)"""
        try:
            # 기존 폴더 검색
            query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder'"
            if parent_id:
                query += f" and parents in '{parent_id}'"
            
            results = self.service.files().list(q=query).execute()
            items = results.get('files', [])
            
            if items:
                folder_id = items[0]['id']
                print(f"📁 기존 폴더 사용: {folder_name} (ID: {folder_id})")
                return folder_id
            
            # 새 폴더 생성
            folder_metadata = {
                'name': folder_name,
                'mimeType': 'application/vnd.google-apps.folder'
            }
            if parent_id:
                folder_metadata['parents'] = [parent_id]
            
            folder = self.service.files().create(body=folder_metadata, fields='id').execute()
            folder_id = folder.get('id')
            print(f"📁 새 폴더 생성: {folder_name} (ID: {folder_id})")
            return folder_id
            
        except HttpError as error:
            print(f"❌ 폴더 생성 실패: {error}")
            return None
    
    def upload_file(self, file_path, folder_id=None, file_name=None):
        """
        파일을 Google Drive에 업로드
        
        Args:
            file_path (str): 업로드할 파일 경로
            folder_id (str): 업로드할 폴더 ID (선택사항)
            file_name (str): 업로드할 파일명 (선택사항)
        
        Returns:
            str: 업로드된 파일 ID
        """
        try:
            if not os.path.exists(file_path):
                print(f"❌ 파일을 찾을 수 없습니다: {file_path}")
                return None
            
            # 파일 정보 설정
            file_name = file_name or os.path.basename(file_path)
            file_size = os.path.getsize(file_path)
            print(f"📤 업로드 시작: {file_name} ({file_size / 1024 / 1024:.1f}MB)")
            
            # 파일 메타데이터 설정
            file_metadata = {'name': file_name}
            if folder_id:
                file_metadata['parents'] = [folder_id]
            
            # 미디어 업로드 설정
            media = MediaFileUpload(file_path, resumable=True)
            
            # 파일 업로드 실행
            request = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id'
            )
            
            response = None
            while response is None:
                status, response = request.next_chunk()
                if status:
                    print(f"📈 업로드 진행률: {int(status.progress() * 100)}%")
            
            file_id = response.get('id')
            print(f"✅ 업로드 완료: {file_name} (ID: {file_id})")
            return file_id
            
        except HttpError as error:
            print(f"❌ 업로드 실패: {error}")
            return None
    
    def make_file_public(self, file_id):
        """파일을 공개로 설정하고 공유 링크 생성"""
        try:
            # 파일을 공개로 설정
            self.service.permissions().create(
                fileId=file_id,
                body={'role': 'reader', 'type': 'anyone'}
            ).execute()
            
            # 공유 링크 생성
            file_info = self.service.files().get(fileId=file_id, fields='webViewLink').execute()
            share_link = file_info.get('webViewLink')
            
            print(f"🔗 공유 링크 생성: {share_link}")
            return share_link
            
        except HttpError as error:
            print(f"❌ 공유 링크 생성 실패: {error}")
            return None
    
    def upload_apk_and_get_link(self, apk_path, version=None):
        """APK 파일 업로드 및 공유 링크 반환"""
        if not self.authenticate():
            return None
        
        # APK 폴더 생성 또는 기존 폴더 사용
        folder_name = "SecureMemo_APK"
        folder_id = self.create_folder(folder_name)
        
        if not folder_id:
            print("❌ 폴더 생성 실패")
            return None
        
        # APK 파일명 설정 (버전 포함)
        if version:
            file_name = f"SecureMemo_v{version}.apk"
        else:
            file_name = "SecureMemo_latest.apk"
        
        # APK 업로드
        file_id = self.upload_file(apk_path, folder_id, file_name)
        
        if not file_id:
            return None
        
        # 공유 링크 생성
        share_link = self.make_file_public(file_id)
        
        if share_link:
            print(f"🎉 APK 업로드 완료!")
            print(f"📱 APK 파일: {file_name}")
            print(f"🔗 다운로드 링크: {share_link}")
            return share_link
        
        return None

def update_readme_download_link(share_link, version=None):
    """README.md 파일의 다운로드 링크 업데이트"""
    readme_path = 'README.md'
    
    if not os.path.exists(readme_path):
        print(f"❌ README.md 파일을 찾을 수 없습니다: {readme_path}")
        return False
    
    try:
        # README.md 파일 읽기
        with open(readme_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 다운로드 링크 패턴 검색 및 업데이트
        # 패턴: [다운로드](https://drive.google.com/file/d/...)
        pattern = r'\[다운로드\]\(https://drive\.google\.com/file/d/[^)]+\)'
        new_link = f'[다운로드]({share_link})'
        
        if re.search(pattern, content):
            # 기존 링크 업데이트
            updated_content = re.sub(pattern, new_link, content)
            print("🔄 기존 다운로드 링크 업데이트")
        else:
            print("⚠️ 기존 다운로드 링크 패턴을 찾을 수 없습니다.")
            return False
        
        # 버전 정보 업데이트 (선택사항)
        if version:
            # 버전 패턴 검색 및 업데이트
            version_pattern = r'v\d+\.\d+\.\d+'
            if re.search(version_pattern, updated_content):
                updated_content = re.sub(version_pattern, f'v{version}', updated_content)
                print(f"🔄 버전 정보 업데이트: v{version}")
        
        # 파일 쓰기
        with open(readme_path, 'w', encoding='utf-8') as f:
            f.write(updated_content)
        
        print("✅ README.md 업데이트 완료")
        return True
        
    except Exception as e:
        print(f"❌ README.md 업데이트 실패: {e}")
        return False

def get_current_version():
    """pubspec.yaml에서 현재 버전 정보 추출"""
    try:
        with open('pubspec.yaml', 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 버전 패턴 검색
        match = re.search(r'version:\s*(.+)', content)
        if match:
            version_full = match.group(1).strip()
            # 버전 번호만 추출 (빌드 번호 제외)
            version = version_full.split('+')[0]
            return version
        
        return None
        
    except Exception as e:
        print(f"❌ 버전 정보 추출 실패: {e}")
        return None

def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(description='Google Drive APK 업로더')
    parser.add_argument('apk_path', nargs='?', 
                       default='build/app/outputs/flutter-apk/app-release.apk',
                       help='APK 파일 경로 (기본: build/app/outputs/flutter-apk/app-release.apk)')
    parser.add_argument('--version', help='버전 번호 (선택사항)')
    parser.add_argument('--no-readme', action='store_true', 
                       help='README.md 업데이트 건너뛰기')
    
    args = parser.parse_args()
    
    # APK 파일 존재 확인
    if not os.path.exists(args.apk_path):
        print(f"❌ APK 파일을 찾을 수 없습니다: {args.apk_path}")
        print("💡 먼저 'flutter build apk --release' 명령어로 APK를 빌드하세요.")
        return False
    
    # 버전 정보 가져오기
    version = args.version or get_current_version()
    
    print("🚀 Google Drive APK 업로더 시작")
    print(f"📱 APK 파일: {args.apk_path}")
    if version:
        print(f"🏷️  버전: v{version}")
    
    # Google Drive 업로더 초기화
    uploader = GoogleDriveUploader()
    
    # APK 업로드 및 링크 생성
    share_link = uploader.upload_apk_and_get_link(args.apk_path, version)
    
    if not share_link:
        print("❌ APK 업로드 실패")
        return False
    
    # README.md 업데이트
    if not args.no_readme:
        success = update_readme_download_link(share_link, version)
        if not success:
            print("⚠️ README.md 업데이트 실패 (수동으로 링크를 업데이트하세요)")
    
    print("\n🎉 모든 작업이 완료되었습니다!")
    print(f"🔗 다운로드 링크: {share_link}")
    
    return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1) 