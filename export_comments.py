import json
import os
import re
from pathlib import Path
from urllib.parse import urlparse

import gspread
from google.oauth2.service_account import Credentials as SACredentials

# === CONFIGURATION ===
HUGO_COMMENTS_DIR = Path("data/comments")  # Hugo site data directory
SERVICE_ACCOUNT_FILE = os.getenv("GOOGLE_SERVICE_ACCOUNT_KEY_FILE")
SPREADSHEET_URL = "https://docs.google.com/spreadsheets/d/17pY9dLOOjJgwzoQzwp3Nk3DAiPTTfHuafg2L-0yy5xQ/edit"
SHEET_NAME = "Form responses 1"  # Note: match exact Sheet tab name (case-sensitive)

# === CONNECT TO GOOGLE SHEETS ===
scope = [
    "https://www.googleapis.com/auth/spreadsheets.readonly",
    "https://www.googleapis.com/auth/drive.readonly",
]

creds: SACredentials = SACredentials.from_service_account_file( # type: ignore
    SERVICE_ACCOUNT_FILE, scopes=scope
)

client = gspread.authorize(creds)
sheet = client.open_by_url(SPREADSHEET_URL).worksheet(SHEET_NAME)

# === LOAD DATA ===
records = sheet.get_all_records()
print(f"{len(records)} row(s) found")

# === HELPER: Extract slug from URL ===
def extract_slug_from_url(url: str) -> str:
    try:
        parsed = urlparse(url)
        path = parsed.path.rstrip("/")  # remove trailing slash
        slug = path.split("/")[-1]  # get last part of path

        # Optional: strip .html/.htm suffix if present
        slug = re.sub(r"\.html?$", "", slug)

        # Safe slug for filenames
        slug = re.sub(r"[^a-zA-Z0-9_-]", "", slug)
        return slug
    except Exception:
        return ""

# === PROCESS COMMENTS ===
comments_by_post: dict[str, list[dict[str, str]]] = {}

for row in records:
    print(row.get("Published", ""))
    if str(row.get("Published", "")).strip().upper() != "TRUE":
        continue

    url = str(row.get("Blog Post URL", "")).strip()
    print(url)
    slug = extract_slug_from_url(url)
    if not slug:
        print(f"⚠️ Skipping row with invalid URL: {url}")
        continue

    comment = {
        "name": str(row.get("Name", "Anonymous")).strip(),
        "text": str(row.get("Comment", "")).strip(),
        "date": str(row.get("Timestamp", "")).strip(),
    }

    comments_by_post.setdefault(slug, []).append(comment)

# === WRITE TO FILES ===
HUGO_COMMENTS_DIR.mkdir(parents=True, exist_ok=True)

for slug, comments in comments_by_post.items():
    out_file = HUGO_COMMENTS_DIR / f"{slug}.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(comments, f, indent=2, ensure_ascii=False)

    print(f"✅ Exported {len(comments)} comments to {out_file}")
