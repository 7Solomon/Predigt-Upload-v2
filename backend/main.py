import asyncio
import json
import datetime as dt
import tempfile
import pathlib
from typing import AsyncGenerator
import logging
from logging.handlers import RotatingFileHandler

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

# Import your actual functions
import functions

app = FastAPI(title="Predigten Uploader API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Logging Setup ---
log_file = pathlib.Path(__file__).parent / "backend.log"
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
    serie: str
    datum: dt.date

# --- Helper for running sync generators in async context ---

async def run_sync_generator(gen):
    """Runs a synchronous generator in a thread-safe way."""
    for item in await asyncio.to_thread(list, gen):
        yield item
        await asyncio.sleep(0.01) # Yield control to event loop

# --- API Endpoints ---

@app.get("/status")
async def get_status():
    """Check if the backend is properly configured and working."""
    config = functions.CONFIG
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
    config = functions.CONFIG
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
        functions.CONFIG = functions.load_config()
        
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
            "website_exists": "False",  # Keep as string for compatibility
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
        functions.CONFIG = functions.load_config()
        
        logging.info("✅ Complete configuration setup successful")
        return {"status": "success", "message": "Complete configuration setup successful"}
        
    except Exception as e:
        logging.error(f"❌ Error in complete config setup: {e}")
        return {"status": "error", "message": f"Configuration setup failed: {e}"}

@app.get("/youtube/livestreams")
async def get_livestreams(limit: int = 10):
    """Gets the last livestreams from the configured YouTube channel."""
    # Run the synchronous generator in a separate thread to avoid blocking
    livestreams = await asyncio.to_thread(list, functions.get_last_livestream_data(limit))
    return livestreams

@app.post("/audio/process")
async def process_audio_stream(req: ProcessAudioRequest):
    """
    Processes an audio stream from a YouTube URL.
    This endpoint streams progress updates for each step.
    """
    video_url = f"https://www.youtube.com/watch?v={req.id}"
    
    async def processing_generator() -> AsyncGenerator[str, None]:
        with tempfile.TemporaryDirectory() as temp_dir:
            try:
                # 1. Download
                # The yt_dlp progress hook is not suitable for async streaming.
                # We will yield a generic message instead.
                yield json.dumps({"step": "Download", "status": "in_progress", "message": "Starte Download..."}) + "\n"
                downloaded_path = await asyncio.to_thread(functions.download_youtube, video_url, temp_dir)
                yield json.dumps({"step": "Download", "status": "completed", "message": "Download abgeschlossen."}) + "\n"

                # 2. Compress
                compressed_path = pathlib.Path(temp_dir) / "compressed.mp3"
                async for update in run_sync_generator(functions.compress_audio(downloaded_path, str(compressed_path))):
                    yield json.dumps(update) + "\n"

                # 3. Tag
                metadata = {
                    "title": req.titel,
                    "speaker": req.prediger,
                    "series": req.serie,
                    "church": functions.CONFIG.get("church_name", "FeG Lörrach"),
                    "date": req.datum.strftime("%Y-%m-%d"),
                }
                async for update in run_sync_generator(functions.generate_id3_tags(str(compressed_path), metadata)):
                    yield json.dumps(update) + "\n"

                # 4. Rename
                final_name = f"{req.datum.strftime('%Y-%m-%d')} - {req.titel}.mp3"
                final_path = await asyncio.to_thread(functions.rename_file, str(compressed_path), final_name)
                
                yield json.dumps({
                    "step": "Complete", 
                    "status": "completed", 
                    "message": "Verarbeitung abgeschlossen!",
                    "final_path": final_path
                }) + "\n"

            except Exception as e:
                yield json.dumps({"step": "Error", "status": "failed", "message": f"Ein Fehler ist aufgetreten: {e}"}) + "\n"

    return StreamingResponse(processing_generator(), media_type="application/x-ndjson")