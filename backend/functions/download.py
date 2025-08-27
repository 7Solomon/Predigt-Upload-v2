import os
import json
import logging
from pathlib import Path
from typing import Generator, Dict, Any

from main import load_config
from utils.setup_ffmpeg import get_ffmpeg_path
import googleapiclient.discovery
import isodate
import yt_dlp
import ffmpeg
from mutagen.mp3 import MP3
from mutagen.id3 import TIT2, TPE1, TALB, TPE2, COMM, TDRC, TRCK, TCON, TCOP, TYER, TLEN

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

CONFIG = load_config()

def get_last_livestream_data(limit: int = 10) -> Generator[Dict[str, Any], None, None]:
    """Fetches the last livestream data from a YouTube channel."""
    try:
        api_service_name = "youtube"
        api_version = "v3"
        youtube = googleapiclient.discovery.build(
            api_service_name, api_version, developerKey=CONFIG["YOUTUBE_API_KEY"])

        request = youtube.search().list(
            part="snippet",
            channelId=CONFIG["channel_id"],
            maxResults=limit * 2,  # Get more to filter
            order="date",
            type="video"
        )
        response = request.execute()

        video_ids = [item['id']['videoId'] for item in response.get('items', [])]
        if not video_ids:
            logging.warning("No videos found")
            return

        video_request = youtube.videos().list(
            part="contentDetails,snippet,liveStreamingDetails",  # Add liveStreamingDetails
            id=",".join(video_ids)
        )
        video_response = video_request.execute()
        
        livestream_count = 0
        for item in video_response.get('items', []):
            # Check if it's a livestream
            if 'liveStreamingDetails' not in item:
                continue  # Skip non-livestreams
                
            if livestream_count >= limit:
                break
                
            video_id = item['id']
            video_title = item['snippet']['title']
            video_thumbnail = item['snippet']['thumbnails']['high']['url']
            duration_iso = item['contentDetails']['duration']
            duration_seconds = isodate.parse_duration(duration_iso).total_seconds()

            yield {
                "id": video_id,
                "title": video_title,
                "url": video_thumbnail,
                "length": int(duration_seconds * 1000)
            }
            
            livestream_count += 1
            
    except Exception as e:
        logging.error(f"Error fetching YouTube livestreams: {e}")
        return


def download_youtube(video_url: str, temp_dir: str) -> str:
    """Downloads audio from a YouTube URL and returns the file path."""
    
    file_path = os.path.join(temp_dir, 'temp_audio.mp3')
    
    try:
        ffmpeg_location = get_ffmpeg_path()
        print(f"FFmpeg location: {ffmpeg_location}")
    except FileNotFoundError as e:
        logging.error(f"FFmpeg setup failed: {e}")
        raise

    ydl_opts = {
        'format': 'bestaudio/best',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
        'outtmpl': os.path.join(temp_dir, 'temp_audio'),
        'nocheckcertificate': True,
    }
    
    if ffmpeg_location:
        ydl_opts['ffmpeg_location'] = ffmpeg_location

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            ydl.download([video_url])
            logging.info(f"Download complete: {file_path}")
            return file_path
        except Exception as e:
            logging.error(f"Error in yt_dlp download: {e}")
            raise

def compress_audio(file_path: str, output_path: str) -> Generator[Dict[str, Any], None, None]:
    """Compresses audio using ffmpeg-python."""
    yield {
        "step": "Compressing",
        "status": "in_progress",
        "message": "Applying audio compression..."
    }
    try:
        ffmpeg_location = get_ffmpeg_path()
        print(f"FFmpeg location: {ffmpeg_location}")

        ffmpeg_cmd = ffmpeg.input(file_path)
        if ffmpeg_location:
            # Use bundled FFmpeg
            ffmpeg_executable = str(Path(ffmpeg_location) / 'ffmpeg.exe')
            (
                ffmpeg_cmd
                .output(output_path, acodec='libmp3lame', audio_bitrate='128k',
                        af=f'acompressor=threshold={CONFIG["threshold_db"]}dB:ratio={CONFIG["ratio"]}:attack={CONFIG["attack"]}:release={CONFIG["release"]}')
                .overwrite_output()
                .run(cmd=ffmpeg_executable, capture_stdout=True, capture_stderr=True)
            )
        else:
            # Use system FFmpeg
            (
                ffmpeg_cmd
                .output(output_path, acodec='libmp3lame', audio_bitrate='128k',
                        af=f'acompressor=threshold={CONFIG["threshold_db"]}dB:ratio={CONFIG["ratio"]}:attack={CONFIG["attack"]}:release={CONFIG["release"]}')
                .overwrite_output()
                .run(capture_stdout=True, capture_stderr=True)
            )
        
        yield {
            "step": "Compressing",
            "progress": "60",
            "status": "completed",
            "message": "Audio compression successful."
        }
    except ffmpeg.Error as e:
        error_msg = e.stderr.decode() if e.stderr else str(e)
        logging.error(f"FFmpeg Error: {error_msg}")
        yield {
            "step": "Compressing",
            "status": "failed",
            "message": f"FFmpeg error: {error_msg}. You may need to install FFmpeg manually."
        }
        raise
    except FileNotFoundError as e:
        logging.error(f"FFmpeg not found: {e}")
        yield {
            "step": "Compressing",
            "status": "failed",
            "message": "FFmpeg not found. Please install FFmpeg or check the setup."
        }
        raise
    except Exception as e:
        logging.error(f"Unexpected error in audio compression: {e}")
        yield {
            "step": "Compressing",
            "status": "failed",
            "message": f"Compression error: {e}"
        }
        raise

def generate_id3_tags(file_path: str, metadata: Dict[str, str]) -> Generator[Dict[str, Any], None, None]:
    """Generates and applies ID3 tags to an MP3 file."""
    yield {
        "step": "Tagging",
        "status": "in_progress",
        "message": "Generating and applying ID3 tags..."
    }
    try:
        audio = MP3(file_path)
        
        audio['TIT2'] = TIT2(encoding=3, text=metadata.get("title", ""))
        audio['TPE1'] = TPE1(encoding=3, text=metadata.get("speaker", ""))
        audio['TDRC'] = TDRC(encoding=3, text=metadata.get("date", "")) # YYYY-MM-DD
        audio['TYER'] = TYER(encoding=3, text=metadata.get("year", ""))

        # Set static tags
        audio['TALB'] = TALB(encoding=3, text=metadata.get("album", "Predigten aus Treffpunkt Leben Karlsruhe"))
        audio['TCON'] = TCON(encoding=3, text=metadata.get("genre", "Predigt Online"))
        audio['TCOP'] = TCOP(encoding=3, text=metadata.get("copyright", "Treffpunkt Leben Karlsruhe - alle Rechte vorbehalten"))

        # Calculate and set duration
        duration_ms = int(audio.info.length * 1000)
        audio['TLEN'] = TLEN(encoding=3, text=str(duration_ms))
        
        audio.save()
        yield {
            "step": "Tagging",
            "status": "completed",
            "message": "ID3 tags applied successfully."
        }
    except Exception as e:
        logging.error(f"Error applying ID3 tags: {e}")
        yield {
            "step": "Tagging",
            "status": "failed",
            "message": f"Error applying ID3 tags: {e}"
        }
        raise

def rename_file(original_path: str, new_name: str) -> str:
    """Renames the file to its final name and returns the new path."""
    try:
        directory = os.path.dirname(original_path)
        final_path = os.path.join(directory, new_name)
        if os.path.exists(final_path):
            os.remove(final_path)
        os.rename(original_path, final_path)
        logging.info(f"File renamed to: {final_path}")
        return final_path
    except Exception as e:
        logging.error(f"Error renaming file: {e}")
        raise
