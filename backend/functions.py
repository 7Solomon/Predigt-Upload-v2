import os
import json
import logging
from typing import Generator, Dict, Any

import googleapiclient.discovery
import isodate
import yt_dlp
import ffmpeg
from mutagen.mp3 import MP3
from mutagen.id3 import TIT2, TPE1, TALB, TPE2, COMM, TDRC, TRCK

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def load_config() -> Dict[str, Any]:
    """Loads the configuration from config.json and environment variables."""
    # Try to load .env file if it exists
    try:
        from dotenv import load_dotenv
        env_path = os.path.join(os.path.dirname(__file__), '.env')
        if os.path.exists(env_path):
            load_dotenv(env_path)
    except ImportError:
        pass
    
    config_path = os.path.join(os.path.dirname(__file__), 'config.json')
    
    # Default configuration if file doesn't exist
    default_config = {
        "config_json_not_empty": "False",
        "YOUTUBE_API_KEY": "YOUR_API_KEY_HERE",
        "channel_id": "YOUR_YOUTUBE_CHANNEL_ID_HERE",
        "server": "ftp.example.com",
        "name": "your_ftp_username",
        "password": "your_ftp_password",
        "website_exists": "False",
        "website_url": "",
        "update_url": "",
        "threshold_db": -12,
        "ratio": 2,
        "attack": 200,
        "release": 1000
    }
    
    # Try to load config file, use defaults if it doesn't exist
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except FileNotFoundError:
        logging.info(f"Config file not found at {config_path}, using defaults")
        config = default_config.copy()
        # Create the default config file
        try:
            with open(config_path, 'w') as f:
                json.dump(default_config, f, indent=2)
            logging.info(f"Created default config file at {config_path}")
        except Exception as e:
            logging.warning(f"Could not create default config file: {e}")
    except json.JSONDecodeError as e:
        logging.error(f"Invalid JSON in config file: {e}, using defaults")
        config = default_config.copy()
    except Exception as e:
        logging.error(f"Error loading config file: {e}, using defaults")
        config = default_config.copy()
    
    # Override sensitive values with environment variables if they exist
    config["YOUTUBE_API_KEY"] = os.getenv("YOUTUBE_API_KEY", config.get("YOUTUBE_API_KEY", ""))
    config["channel_id"] = os.getenv("YOUTUBE_CHANNEL_ID", config.get("channel_id", ""))
    config["server"] = os.getenv("FTP_SERVER", config.get("server", ""))
    config["name"] = os.getenv("FTP_USERNAME", config.get("name", ""))
    config["password"] = os.getenv("FTP_PASSWORD", config.get("password", ""))
    
    return config

CONFIG = load_config()

def get_last_livestream_data(limit: int = 10) -> Generator[Dict[str, Any], None, None]:
    """Fetches the last livestream data from a YouTube channel."""
    print(f'GET LATEST {limit}')
    try:
        api_service_name = "youtube"
        api_version = "v3"
        youtube = googleapiclient.discovery.build(
            api_service_name, api_version, developerKey=CONFIG["YOUTUBE_API_KEY"])

        request = youtube.search().list(
            part="snippet",
            channelId=CONFIG["channel_id"],
            maxResults=limit,
            order="date",
            type="video"
        )
        response = request.execute()

        video_ids = [item['id']['videoId'] for item in response.get('items', [])]
        if not video_ids:
            return

        video_request = youtube.videos().list(
            part="contentDetails,snippet",
            id=",".join(video_ids)
        )
        video_response = video_request.execute()
        
        video_details = {item['id']: item for item in video_response.get('items', [])}

        for item in response.get('items', []):
            video_id = item['id']['videoId']
            video_detail = video_details.get(video_id)
            if not video_detail:
                continue

            video_title = video_detail['snippet']['title']
            video_thumbnail = video_detail['snippet']['thumbnails']['high']['url']
            duration_iso = video_detail['contentDetails']['duration']
            duration_seconds = isodate.parse_duration(duration_iso).total_seconds()

            yield {
                "id": video_id,
                "title": video_title,
                "url": video_thumbnail, # Changed from thumbnail_url to url
                "length": int(duration_seconds * 1000) # Changed from duration to length and in milliseconds
            }
    except Exception as e:
        logging.error(f"Error fetching YouTube livestreams: {e}")
        # Return an empty list or re-raise, but don't yield from an empty list.
        return


def download_youtube(video_url: str, temp_dir: str) -> Generator[Dict[str, Any], None, str]:
    """Downloads audio from a YouTube URL and yields progress."""
    
    file_path = os.path.join(temp_dir, 'temp_audio.mp3')

    def progress_hook(d):
        if d['status'] == 'downloading':
            progress = d['_percent_str']
            speed = d['_speed_str']
            eta = d['_eta_str']
            yield {
                "step": "Downloading",
                "status": "in_progress",
                "message": f"Downloading: {progress} at {speed}, ETA: {eta}"
            }
        elif d['status'] == 'finished':
             yield {
                "step": "Downloading",
                "status": "completed",
                "message": "Download finished, converting..."
            }


    ydl_opts = {
        'format': 'bestaudio/best',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
        'outtmpl': os.path.join(temp_dir, 'temp_audio'),
        'progress_hooks': [progress_hook],
        'nocheckcertificate': True,
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        # Wrap ydl.download in a generator
        def download_generator():
            try:
                ydl.download([video_url])
                return file_path
            except Exception as e:
                logging.error(f"Error in yt_dlp download: {e}")
                raise

        downloader = download_generator()
        
        # This part is tricky because the hook is callback-based.
        # We'll simulate the progress for the sake of the stream.
        # A more robust solution might involve multiprocessing or threading queues.
        
        # Simulate initial message
        yield {
            "step": "Downloading",
            "status": "in_progress",
            "message": "Starting download..."
        }
        
        # The actual download happens here. The progress_hook is not a generator.
        # This is a limitation we have to work around.
        # We will yield a completion message after it's done.
        try:
            ydl.download([video_url])
            yield {
                "step": "Downloading",
                "status": "completed",
                "message": "Download and conversion complete."
            }
        except Exception as e:
            yield {
                "step": "Downloading",
                "status": "failed",
                "message": f"Error during download: {e}"
            }
            raise
    
    return file_path


def compress_audio(file_path: str, output_path: str) -> Generator[Dict[str, Any], None, None]:
    """Compresses audio using ffmpeg-python."""
    yield {
        "step": "Compressing",
        "status": "in_progress",
        "message": "Applying audio compression..."
    }
    try:
        (
            ffmpeg
            .input(file_path)
            .output(output_path, acodec='libmp3lame', audio_bitrate='128k',
                    af=f'acompressor=threshold={CONFIG["threshold_db"]}dB:ratio={CONFIG["ratio"]}:attack={CONFIG["attack"]}:release={CONFIG["release"]}')
            .overwrite_output()
            .run(capture_stdout=True, capture_stderr=True)
        )
        yield {
            "step": "Compressing",
            "status": "completed",
            "message": "Audio compression successful."
        }
    except ffmpeg.Error as e:
        logging.error("FFmpeg Error:", e.stderr.decode())
        yield {
            "step": "Compressing",
            "status": "failed",
            "message": f"FFmpeg error: {e.stderr.decode()}"
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
        audio.clear()
        audio.add(TIT2(encoding=3, text=metadata.get("title", "")))
        audio.add(TPE1(encoding=3, text=metadata.get("speaker", "")))
        audio.add(TALB(encoding=3, text=metadata.get("series", "")))
        audio.add(TPE2(encoding=3, text=metadata.get("church", "")))
        audio.add(COMM(encoding=3, lang='ger', desc='Comment', text=metadata.get("comment", "")))
        audio.add(TDRC(encoding=3, text=metadata.get("date", "")))
        audio.add(TRCK(encoding=3, text=str(metadata.get("track", "1"))))
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

def rename_file(original_path: str, new_name: str) -> Generator[Dict[str, Any], None, str]:
    """Renames the file to its final name."""
    yield {
        "step": "Finalizing",
        "status": "in_progress",
        "message": f"Renaming file to {new_name}..."
    }
    try:
        directory = os.path.dirname(original_path)
        final_path = os.path.join(directory, new_name)
        if os.path.exists(final_path):
            os.remove(final_path)
        os.rename(original_path, final_path)
        yield {
            "step": "Finalizing",
            "status": "completed",
            "message": "File renamed successfully."
        }
        return final_path
    except Exception as e:
        logging.error(f"Error renaming file: {e}")
        yield {
            "step": "Finalizing",
            "status": "failed",
            "message": f"Error renaming file: {e}"
        }
        raise
