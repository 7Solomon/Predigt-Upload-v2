import sys
import os
import logging
import requests

sys.path.append(os.path.dirname(__file__))

from setup_ffmpeg import get_latest_ffmpeg_url, download_ffmpeg

# Set up logging to see what's happening
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

def test_url_fetching():
    """Test URL fetching step by step"""
    print("=== Testing URL Fetching ===")
    
    try:
        # Use the actual function from setup_ffmpeg.py
        print("Testing get_latest_ffmpeg_url() function...")
        url = get_latest_ffmpeg_url()
        print(f"✓ Found working URL: {url}")
        return url
        
    except Exception as e:
        print(f"❌ URL fetching failed: {e}")
        return None

def test_full_download():
    """Test the full download process"""
    print("\n=== Testing Full Download ===")
    
    try:
        # First test URL fetching
        url = test_url_fetching()
        if not url:
            print("❌ Cannot proceed - no working download URL found")
            return
        
        print(f"\n3. Testing download from: {url}")
        download_ffmpeg()
        print("✓ Download completed successfully!")
        
    except Exception as e:
        print(f"❌ Download failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_url_fetching()
    
    response = input("\nDo you want to test the full download? (y/n): ")
    if response.lower() == 'y':
        test_full_download()