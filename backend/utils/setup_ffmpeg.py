import os
import requests
import zipfile
import shutil
import json
from pathlib import Path
import logging

def get_ffmpeg_path():
    """Get the path to bundled FFmpeg or system FFmpeg."""
    backend_dir = Path(__file__).parent.parent  # Go up from utils/ to backend/
    bundled_ffmpeg = backend_dir / 'ffmpeg' / 'ffmpeg.exe'
    bundled_ffprobe = backend_dir / 'ffmpeg' / 'ffprobe.exe'
    
    # Check if bundled FFmpeg exists
    if bundled_ffmpeg.exists() and bundled_ffprobe.exists():
        return str(backend_dir / 'ffmpeg')
    
    # Check if system FFmpeg exists
    if shutil.which('ffmpeg') and shutil.which('ffprobe'):
        return None  # Use system PATH
    
    # FFmpeg not found - try to download it automatically
    logging.info("FFmpeg not found. Attempting to download...")
    try:
        download_ffmpeg()  # Call directly, no import needed
        
        # Check again after download
        if bundled_ffmpeg.exists() and bundled_ffprobe.exists():
            return str(backend_dir / 'ffmpeg')
    except Exception as e:
        logging.error(f"Failed to auto-download FFmpeg: {e}")
    
    raise FileNotFoundError(
        "FFmpeg not found. Please install FFmpeg or place ffmpeg.exe and ffprobe.exe in the backend/ffmpeg/ directory."
    )

def get_latest_ffmpeg_url():
    """Get the latest FFmpeg download URL from working sources."""
    print("DEBUG: Starting URL search...")
    
    fallback_urls = [
        # BtbN builds - most reliable
        "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip",
        # Essentials build (smaller)
        "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip",
        # Alternative gyan.dev URL format
        "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
        # Backup static link
        "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2023-08-20-12-46/ffmpeg-master-latest-win64-gpl.zip"
    ]
    
    # Test each URL
    for i, url in enumerate(fallback_urls):
        try:
            print(f"DEBUG: Testing URL {i+1}: {url}")
            
            # Allow redirects for GitHub URLs
            response = requests.head(url, timeout=15, allow_redirects=True)
            print(f"DEBUG: URL {i+1} response: {response.status_code}")
            
            if response.status_code == 200:
                print(f"DEBUG: Success! Using URL: {url}")
                
                # Additional check: verify content-length exists (means it's a real file)
                content_length = response.headers.get('content-length')
                if content_length and int(content_length) > 1000000:  # At least 1MB
                    print(f"DEBUG: File size looks good: {int(content_length)/1024/1024:.1f} MB")
                    return url
                else:
                    print(f"DEBUG: File too small or no content-length, trying next...")
                    
        except Exception as e:
            print(f"DEBUG: URL {i+1} failed: {e}")
            continue
    
    print("DEBUG: All URLs failed!")
    raise Exception("Could not find a valid FFmpeg download URL")

def download_ffmpeg():
    """Download and extract FFmpeg for Windows."""
    backend_dir = Path(__file__).parent.parent  # Go up from utils/ to backend/
    ffmpeg_dir = backend_dir / 'ffmpeg'
    
    # Check if FFmpeg already exists
    if ffmpeg_dir.exists() and (ffmpeg_dir / 'ffmpeg.exe').exists():
        print("FFmpeg already exists.")
        return
    
    try:
        print("Getting latest FFmpeg download URL...")
        download_url = get_latest_ffmpeg_url()
        print(f"Downloading FFmpeg from: {download_url}")
        
        # Download with progress and redirects allowed
        response = requests.get(download_url, stream=True, allow_redirects=True, timeout=30)
        response.raise_for_status()
        
        zip_path = backend_dir / 'ffmpeg_download.zip'
        total_size = int(response.headers.get('content-length', 0))
        
        print(f"Total download size: {total_size/1024/1024:.1f} MB")
        
        with open(zip_path, 'wb') as f:
            downloaded = 0
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        print(f"\rDownload progress: {percent:.1f}%", end='', flush=True)
        
        print("\nExtracting FFmpeg...")
        
        # Extract
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(backend_dir / 'ffmpeg_temp')
        
        # Find and move executables
        ffmpeg_dir.mkdir(exist_ok=True)
        temp_dir = backend_dir / 'ffmpeg_temp'
        
        # Look for ffmpeg.exe and ffprobe.exe in extracted folders
        executables_found = False
        for root, dirs, files in os.walk(temp_dir):
            print(f"DEBUG: Checking directory: {root}")
            print(f"DEBUG: Files found: {files}")
            
            # Look for both files
            ffmpeg_path = None
            ffprobe_path = None
            
            for file in files:
                if file == 'ffmpeg.exe':
                    ffmpeg_path = Path(root) / file
                elif file == 'ffprobe.exe':
                    ffprobe_path = Path(root) / file
            
            # If we found both, copy them
            if ffmpeg_path and ffprobe_path:
                shutil.copy2(ffmpeg_path, ffmpeg_dir)
                shutil.copy2(ffprobe_path, ffmpeg_dir)
                print(f"Found and copied FFmpeg executables from: {root}")
                executables_found = True
                break
        
        if not executables_found:
            # List all .exe files to debug
            print("DEBUG: All .exe files found in archive:")
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    if file.endswith('.exe'):
                        print(f"  {root}/{file}")
            raise Exception("Could not find ffmpeg.exe and ffprobe.exe in the downloaded archive")
        
        # Cleanup
        shutil.rmtree(temp_dir)
        zip_path.unlink()
        
        print("FFmpeg setup complete!")
        
        # Verify installation
        if (ffmpeg_dir / 'ffmpeg.exe').exists() and (ffmpeg_dir / 'ffprobe.exe').exists():
            print("✓ FFmpeg installation verified")
        else:
            raise Exception("FFmpeg installation verification failed")
            
    except Exception as e:
        print(f"Error setting up FFmpeg: {e}")
        # Cleanup on failure
        try:
            if (backend_dir / 'ffmpeg_download.zip').exists():
                (backend_dir / 'ffmpeg_download.zip').unlink()
            if (backend_dir / 'ffmpeg_temp').exists():
                shutil.rmtree(backend_dir / 'ffmpeg_temp')
        except:
            pass
        raise

if __name__ == "__main__":
    download_ffmpeg()