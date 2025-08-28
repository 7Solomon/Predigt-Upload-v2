from datetime import datetime
import os
import ftplib
import re
import requests
import logging
from bs4 import BeautifulSoup 

from main import load_config 

CONFIG = load_config()

def send_file_to_server(path):
    file_name = os.path.basename(path)

    server = CONFIG.get('server')
    name = CONFIG.get('name')
    password = CONFIG.get('password')

    session = ftplib.FTP(server, name, password)
    file = open(path, 'rb')
    session.storbinary(f'STOR {file_name}', file)     
    file.close()
    session.quit()

def check_if_file_on_server(path):
    file_name = os.path.basename(path)

    server = CONFIG.get('server')
    name = CONFIG.get('name')
    password = CONFIG.get('password')
    try:
        session = ftplib.FTP(server, name, password)
        files_on_server = session.nlst()
        
        if file_name in files_on_server:
            session.quit()
            return True
        else:
            session.quit()
            return False
        
    except ftplib.all_errors as e:
        logging.error(f"Error: {e}")
        return False
    
def list_files_on_server():
    """List all files on the FTP server."""
    server = CONFIG.get('server')
    name = CONFIG.get('name')
    password = CONFIG.get('password')
    try:
        session = ftplib.FTP(server, name, password)
        files = session.nlst()
        session.quit()

        actual_files = [f for f in files if f not in ['.', '..', '.empty']]

        date_regexes = [
            re.compile(r'^predigt-(\d{4}-\d{2}-\d{2})_'),          # predigt-YYYY-MM-DD_
            re.compile(r'^(\d{4}-\d{2}-\d{2})\s*-'),               # YYYY-MM-DD - 
        ]

        def extract_date_from_filename(filename):
            for rx in date_regexes:
                m = rx.search(filename)
                if m:
                    try:
                        return datetime.strptime(m.group(1), '%Y-%m-%d')
                    except ValueError:
                        pass
            return datetime(1900, 1, 1)

        sorted_files = sorted(
            actual_files,
            key=extract_date_from_filename,
            reverse=True
        )[:15]

        return sorted_files
    except ftplib.all_errors as e:
        logging.error(f"Error listing files on server: {e}")
        return []
       

def get_themes_of_predigten():
    url = CONFIG.get('website_url')

    if not url:
        return []
    
    response = requests.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Find table
    table = soup.select_one("#predigt_main > table")
    themen = []
    if table:
        # Process the table
        rows = table.find_all('tr')
        for row in rows[1:7]:  # Skip header row, get next 3 rows
            columns = row.find_all('td')
            if len(columns) > 1:  # Ensure there's a theme column
                thema = columns[1].text.strip()
                thema = thema.replace("Thema:", "").strip()  # Remove some stuff
                themen.append(thema)  # Assuming theme is in the second column

    else:
        logging.warning("Table not found")

    return themen



def send_update_request():
    url = CONFIG.get('update_url')

    if url:
        response = requests.get(url)
        if response.status_code == 200:
            logging.info("Update request was successful!")
            logging.info("Response content:")
            logging.info(response.text)  # Print the content of the response
        else:
            logging.error(f"Failed to retrieve data. Status code: {response.status_code}")



