#!/usr/bin/env python3
"""
스플래시 로고 이미지에 여백을 추가하여 잘리는 문제를 해결하는 스크립트
"""

from PIL import Image, ImageDraw
import os

def resize_splash_logo():
    """현재 스플래시 로고에 여백을 추가하여 새로운 이미지 생성"""
    
    # 입력 파일 경로
    input_path = "assets/splash_logo.png"
    output_path = "assets/splash_logo_resized.png"
    
    try:
        # 원본 이미지 열기
        with Image.open(input_path) as img:
            print(f"원본 이미지 크기: {img.size}")
            
            # 원본 이미지 크기
            original_width, original_height = img.size
            
            # 새로운 캔버스 크기 (원본의 150% 크기로 여백 추가)
            new_size = max(original_width, original_height)
            canvas_size = int(new_size * 1.5)
            
            # 새로운 투명한 캔버스 생성
            new_img = Image.new('RGBA', (canvas_size, canvas_size), (255, 255, 255, 0))
            
            # 원본 이미지를 중앙에 배치
            x = (canvas_size - original_width) // 2
            y = (canvas_size - original_height) // 2
            
            # 이미지 합성
            new_img.paste(img, (x, y), img if img.mode == 'RGBA' else None)
            
            # 새로운 이미지 저장
            new_img.save(output_path, 'PNG')
            print(f"새로운 이미지 생성 완료: {output_path}")
            print(f"새로운 이미지 크기: {new_img.size}")
            
            # 원본 파일을 백업하고 새 파일로 교체
            backup_path = "assets/splash_logo_original.png"
            os.rename(input_path, backup_path)
            os.rename(output_path, input_path)
            
            print(f"원본 파일을 {backup_path}로 백업했습니다.")
            print(f"새로운 이미지를 {input_path}로 적용했습니다.")
            
    except Exception as e:
        print(f"오류 발생: {e}")

if __name__ == "__main__":
    resize_splash_logo() 