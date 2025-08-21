# Configuration Setup

## Quick Setup (Recommended)

1. **Copy the template**: Copy `config-template.json` to `my-config.json`
2. **Fill in your details** in `my-config.json`:
   - `YOUTUBE_API_KEY`: Your YouTube Data API v3 key
   - `channel_id`: Your YouTube channel ID
   - `server`: Your FTP server address
   - `name`: Your FTP username
   - `password`: Your FTP password
   - `website_url`: Your website URL (optional)
3. **Drag & Drop**: Simply drag `my-config.json` into the Flutter app
4. **Done!** Both Flutter and Backend are now configured

## What happens when you drop the JSON file?

1. ✅ **Flutter**: Config saved to local device storage
2. ✅ **Backend**: Config written to `backend/config.json`
3. ✅ **APIs**: YouTube and FTP APIs immediately available
4. ✅ **Cross-device**: Copy the same JSON file to other devices

## Security Notes

- The JSON file contains sensitive information (API keys, passwords)
- Never commit this file to version control
- Keep it secure and only share with trusted team members
- Consider using environment variables in production

## Troubleshooting

If the backend configuration fails:
- Make sure the backend server is running
- Check the backend logs in `backend/backend.log`
- Verify your JSON file format matches the template
