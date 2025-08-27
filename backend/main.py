import asyncio
import json
import datetime as dt
import tempfile
import pathlib
from typing import Dict, Any, AsyncGenerator
import logging
import os
from logging.handlers import RotatingFileHandler

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel


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
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except FileNotFoundError:
        logging.info(f"Config file not found at {config_path}, using defaults")
        config = default_config.copy()
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


from functions import download
from functions import server_interact



app = FastAPI(title="Predigten Uploader API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Logging Setup ---
log_dir = pathlib.Path(__file__).parent / "log"
log_dir.mkdir(exist_ok=True)
log_file = log_dir / "backend.log"
# Create a rotating file handler (1MB per file, keep 5 backups)
file_handler = RotatingFileHandler(log_file, maxBytes=1024*1024, backupCount=5)
file_handler.setFormatter(logging.Formatter(
    '%(asctime)s - %(levelname)s - %(name)s - %(message)s'
))

# Configure root logger and uvicorn loggers to use our file handler
# This will capture logs from your functions and from the web server itself.
logging.basicConfig(level=logging.INFO, handlers=[file_handler])
logging.getLogger("uvicorn.access").addHandler(file_handler)
logging.getLogger("uvicorn.error").addHandler(file_handler)
# --- End Logging Setup ---


# --- Pydantic Models ---

class PublicConfigModel(BaseModel):
    """Only non-sensitive configuration that can be exposed via API"""
    threshold_db: float
    ratio: float
    attack: float
    release: float
    website_exists: str
    website_url: str = ""

class ConfigUpdateModel(BaseModel):
    """Configuration updates that don't include sensitive data"""
    threshold_db: float
    ratio: float
    attack: float
    release: float

class FullConfigUpdateModel(BaseModel):
    """Full configuration including sensitive data - only for initial setup"""
    YOUTUBE_API_KEY: str
    channel_id: str
    server: str
    name: str
    password: str
    website_url: str = ""
    threshold_db: float
    ratio: float
    attack: float
    release: float

class LivestreamRequest(BaseModel):
    limit: int = 10

class ProcessAudioRequest(BaseModel):
    id: str # Video ID
    prediger: str
    titel: str
    datum: dt.date

class UploadFileRequest(BaseModel):
    file_path: str

async def run_sync_generator(gen):
    """Runs a synchronous generator in a thread-safe way."""
    for item in await asyncio.to_thread(list, gen):
        yield item
        await asyncio.sleep(0.01) # Yield control to event loop



# --- API Endpoints ---
@app.get("/status")
async def get_status():
    """Check if the backend is properly configured and working."""
    config = download.CONFIG
    status = {
        "backend_running": True,
        "config_loaded": bool(config),
        "youtube_api_configured": bool(config.get("YOUTUBE_API_KEY") and config.get("YOUTUBE_API_KEY") != "YOUR_API_KEY_HERE"),
        "channel_configured": bool(config.get("channel_id") and config.get("channel_id") != "YOUR_YOUTUBE_CHANNEL_ID_HERE"),
        "ftp_configured": bool(config.get("server") and config.get("server") != "ftp.example.com"),
    }
    status["fully_configured"] = all([
        status["youtube_api_configured"],
        status["channel_configured"],
        status["ftp_configured"]
    ])
    return status

@app.get("/config")
async def get_config():
    """Gets the current non-sensitive configuration."""
    config = download.CONFIG
    # Return only non-sensitive configuration
    return {
        "threshold_db": config.get("threshold_db", -12),
        "ratio": config.get("ratio", 2),
        "attack": config.get("attack", 200),
        "release": config.get("release", 1000),
        "website_exists": config.get("website_exists", "False"),
        "website_url": config.get("website_url", ""),
    }

@app.post("/config")
async def update_config(config: ConfigUpdateModel):
    """Updates the non-sensitive configuration and saves it to config.json."""
    try:
        config_path = pathlib.Path(__file__).parent / "config.json"
        
        # Load existing config
        with open(config_path, 'r') as f:
            existing_config = json.load(f)
        
        # Update only the non-sensitive values
        existing_config.update({
            "threshold_db": config.threshold_db,
            "ratio": config.ratio,
            "attack": config.attack,
            "release": config.release,
        })
        
        # Save back to file
        with open(config_path, 'w') as f:
            json.dump(existing_config, f, indent=2)
        
        # Reload the config in the functions module
        download.CONFIG = download.load_config()
        
        return {"status": "success", "message": "Configuration updated successfully"}
    except Exception as e:
        logging.error(f"Error updating config: {e}")
        return {"status": "error", "message": f"Failed to update config: {e}"}

@app.post("/config/setup")
async def setup_full_config(config: FullConfigUpdateModel):
    """Complete configuration setup - writes the full config.json file."""
    try:
        config_path = pathlib.Path(__file__).parent / "config.json"
        
        # Create the complete config.json structure
        full_config = {
            "config_json_not_empty": "True",
            "YOUTUBE_API_KEY": config.YOUTUBE_API_KEY,
            "channel_id": config.channel_id,
            "server": config.server,
            "name": config.name,
            "password": config.password,
            "website_exists": "False", 
            "website_url": config.website_url,
            "update_url": "",
            "threshold_db": config.threshold_db,
            "ratio": config.ratio,
            "attack": config.attack,
            "release": config.release,
        }
        
        # Write the complete configuration
        with open(config_path, 'w') as f:
            json.dump(full_config, f, indent=2)
        
        # Reload the config in functions module
        download.CONFIG = download.load_config()
        
        logging.info("✅ Complete configuration setup successful")
        return {"status": "success", "message": "Complete configuration setup successful"}
        
    except Exception as e:
        logging.error(f"❌ Error in complete config setup: {e}")
        return {"status": "error", "message": f"Configuration setup failed: {e}"}

@app.get("/youtube/livestreams")
async def get_livestreams(limit: int = 10):
    """Gets the last livestreams from the configured YouTube channel."""
    # Run the synchronous generator in a separate thread to avoid blocking
    livestreams = await asyncio.to_thread(list, download.get_last_livestream_data(limit))
    return livestreams

@app.post("/audio/process")
async def process_audio_stream(req: ProcessAudioRequest):
    """
    Processes an audio stream from a YouTube URL.
    This endpoint streams progress updates for each step.
    """

    logging.info(f"Received processing request: {req}")
    logging.info(f"Video ID: {req.id}, Prediger: {req.prediger}, Titel: {req.titel}, Datum: {req.datum}")
    
    video_url = f"https://www.youtube.com/watch?v={req.id}"
    
    async def processing_generator() -> AsyncGenerator[str, None]:
        with tempfile.TemporaryDirectory() as temp_dir:
            try:
                # 1. Download
                yield json.dumps({"step": "download", "status": "in_progress", "progress": "05", "message": "Starte Download..."}) + "\n"
                downloaded_path = await asyncio.to_thread(download.download_youtube, video_url, temp_dir)
                yield json.dumps({"step": "download", "status": "completed", "progress": "15", "message": "Download abgeschlossen."}) + "\n"

                # 2. Compress
                compressed_path = pathlib.Path(temp_dir) / "compressed.mp3"
                async for update in run_sync_generator(download.compress_audio(downloaded_path, str(compressed_path))):
                    update['step'] = 'compress'
                    update['progress'] = "60"
                    yield json.dumps(update) + "\n"

                # 3. Tag
                metadata = {
                    "title": req.titel,
                    "speaker": req.prediger,
                    "date": req.datum.strftime("%Y-%m-%d"),
                    "year": req.datum.strftime("%Y"),
                    "album": download.CONFIG.get("album_name", "Predigten aus Treffpunkt Leben Karlsruhe"),
                    "copyright": download.CONFIG.get("copyright_notice", "Treffpunkt Leben Karlsruhe - alle Rechte vorbehalten"),
                    "genre": "Predigt Online"
                }
                async for update in run_sync_generator(download.generate_id3_tags(str(compressed_path), metadata)):
                    update['step'] = 'tags'
                    update['progress'] = "80"
                    yield json.dumps(update) + "\n"

                # 4. Rename
                final_name = f"{req.datum.strftime('%Y-%m-%d')} - {req.titel}.mp3"
                yield json.dumps({"step": "finalize", "status": "in_progress", "progress": "90", "message": f"Renaming file to {final_name}..."}) + "\n"
                final_path = await asyncio.to_thread(download.rename_file, str(compressed_path), final_name)
                
                yield json.dumps({
                    "step": "complete", 
                    "status": "completed", 
                    "progress": "100",
                    "message": "Verarbeitung abgeschlossen!",
                    "final_path": final_path
                }) + "\n"

            except Exception as e:
                logging.error(f"Error in processing stream: {e}", exc_info=True)
                yield json.dumps({"step": "error", "status": "failed", "message": f"Ein Fehler ist aufgetreten: {e}"}) + "\n"

    return StreamingResponse(processing_generator(), media_type="application/x-ndjson")

@app.post("/server/upload")
async def upload_file_to_server(req: UploadFileRequest):
    """Upload a file to the FTP server with proper renaming."""
    try:
        logging.info(f"Uploading file to server: {req.file_path}")
        
        # Check if file exists locally first
        if not pathlib.Path(req.file_path).exists():
            return {
                "status": "error", 
                "message": f"File not found: {req.file_path}"
            }
        
        # Extract date from the original filename (format: YYYY-MM-DD - Title.mp3)
        original_filename = pathlib.Path(req.file_path).name
        try:
            # Extract date part before the first " - "
            date_part = original_filename.split(' - ')[0]
            # Validate date format
            dt.datetime.strptime(date_part, '%Y-%m-%d')
            datum = date_part
        except (ValueError, IndexError):
            return {
                "status": "error", 
                "message": f"Could not extract valid date from filename: {original_filename}"
            }
        
        # Create new filename with the required structure
        new_filename = f"predigt-{datum}_Treffpunkt_Leben_Karlsruhe.mp3"
        
        # 1. First: Rename the file locally (in temp directory)
        temp_dir = pathlib.Path(req.file_path).parent
        new_file_path = temp_dir / new_filename
        
        # Rename the file locally
        pathlib.Path(req.file_path).rename(new_file_path)
        logging.info(f"File renamed locally from {req.file_path} to {new_file_path}")
        
        # 2. Second: Upload the renamed file to server
        await asyncio.to_thread(server_interact.send_file_to_server, str(new_file_path))
        logging.info(f"File uploaded to server: {new_filename}")
        
        # 3. Third: Send update request
        await asyncio.to_thread(server_interact.send_update_request)
        logging.info("Update request sent to server")
        
        return {
            "status": "success", 
            "message": f"File uploaded successfully as: {new_filename}",
            "uploaded_filename": new_filename
        }
    
    except Exception as e:
        logging.error(f"Error uploading file to server: {e}")
        return {
            "status": "error", 
            "message": f"Upload failed: {str(e)}"
        }

@app.post("/server/check-file")
async def check_file_on_server(req: UploadFileRequest):
    """Check if a file exists on the FTP server."""
    try:
        exists = await asyncio.to_thread(server_interact.check_if_file_on_server, req.file_path)
        return {
            "status": "success",
            "file_exists": exists,
            "file_name": pathlib.Path(req.file_path).name
        }
    except Exception as e:
        logging.error(f"Error checking file on server: {e}")
        return {
            "status": "error", 
            "message": f"Check failed: {str(e)}"
        }

@app.get("/website/themes")
async def get_predigt_themes():
    """Get themes from the website."""
    try:
        themes = await asyncio.to_thread(server_interact.get_themes_of_predigten)
        return {
            "status": "success",
            "themes": themes
        }
    except Exception as e:
        logging.error(f"Error getting themes from website: {e}")
        return {
            "status": "error", 
            "message": f"Failed to get themes: {str(e)}"
        }
@app.get("/server/files")
async def list_server_files():
    """List all files on the FTP server."""
    try:
        files = await asyncio.to_thread(server_interact.list_files_on_server)
        return {
            "status": "success",
            "files": files
        }
    except Exception as e:
        logging.error(f"Error listing server files: {e}")
        return {
            "status": "error", 
            "message": f"Failed to list files: {str(e)}"
        }

@app.post("/website/update")
async def send_website_update():
    """Send update request to the website."""
    try:
        await asyncio.to_thread(server_interact.send_update_request)
        return {
            "status": "success", 
            "message": "Update request sent successfully"
        }
    except Exception as e:
        logging.error(f"Error sending update request: {e}")
        return {
            "status": "error", 
            "message": f"Update request failed: {str(e)}"
        }