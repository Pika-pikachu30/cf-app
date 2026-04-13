from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import engine, Base
from routes import router
from fastapi import FastAPI, HTTPException
import requests
from bs4 import BeautifulSoup
import re
import cloudscraper
# Create DB tables
Base.metadata.create_all(bind=engine)

app = FastAPI()
# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # allow all origins (dev only)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(router)
scraper = cloudscraper.create_scraper(
    browser={
        'browser': 'chrome',
        'platform': 'windows',
        'desktop': True
    }
)

def get_editorial_url(contest_id):
    """Finds the 'Tutorial' or 'Editorial' link on the contest page using Cloudscraper."""
    url = f"https://codeforces.com/contest/{contest_id}"
    
    try:
        # Use scraper.get instead of requests.get
        res = scraper.get(url)
        if res.status_code != 200:
            print(f"Failed to load contest page: {res.status_code}")
            return None
            
        soup = BeautifulSoup(res.text, 'html.parser')
        
        # DEBUG: Print the page title to confirm we bypassed Cloudflare
        page_title = soup.title.string if soup.title else "No Title"
        print(f"Loaded Page: {page_title}") 
        
        if "Just a moment" in page_title:
            print("Still blocked by Cloudflare.")
            return None

        # Broadened strategy: search for multiple keyword variants (including some Russian words)
        keywords = [
            "tutorial", "editorial", "tutorials", "editorials",
            "solution", "solutions", "разбор", "обзор", "решение", "решения"
        ]
        kw_re = re.compile(r"(" + "|".join(map(re.escape, keywords)) + r")", re.IGNORECASE)

        # Prefer sidebar / materials links first
        sidebar = soup.find('div', {'id': 'sidebar'})
        if sidebar:
            links = sidebar.find_all('a', href=True)
            for link in links:
                text = link.get_text().strip()
                href = link['href']
                href_lower = href.lower()

                # Match by href pattern (blog entries) or by keyword in text/href
                if '/blog/entry/' in href_lower or kw_re.search(text) or kw_re.search(href_lower):
                    if href.startswith('http'):
                        return href
                    return "https://codeforces.com" + href

        # Fallback: search the whole page for blog entries or keyword matches
        all_links = soup.find_all('a', href=True)
        for link in all_links:
            href = link['href']
            text = link.get_text().strip()
            href_lower = href.lower()
            if '/blog/entry/' in href_lower or kw_re.search(text) or kw_re.search(href_lower):
                if href.startswith('http'):
                    return href
                return "https://codeforces.com" + href
                
    except Exception as e:
        print(f"Scraper Error: {e}")
        return None
    
    return None

@app.get("/get_tutorial")
async def get_tutorial(contestId: int, index: str):
    print(f"Attempting to fetch tutorial for Contest: {contestId}, Problem: {index}")
    
    blog_url = get_editorial_url(contestId)
    
    if not blog_url:
        print("No editorial URL found.")
        # Return empty tutorial instead of crashing
        return {"tutorial": "", "error": "Editorial link not found"}

    print(f"Found Editorial URL: {blog_url}")
    
    try:
        res = scraper.get(blog_url) # Use scraper here too!
        soup = BeautifulSoup(res.text, 'html.parser')
        
        content = soup.find('div', {'class': 'ttypography'})
        if not content:
            return {"tutorial": "", "error": "Could not parse blog content"}

        # Robust Parsing Logic (Iterate Headers)
        found_text = []
        is_recording = False
        
        for element in content.recursiveChildGenerator():
            if element.name in ['h1', 'h2', 'h3', 'h4', 'strong', 'b']:
                text = element.get_text().strip()
                # Matches "C.", "Problem C", "Task C"
                if re.search(rf"\b{index}\b", text, re.IGNORECASE): 
                    is_recording = True
                    continue 
                elif is_recording:
                    # Stop if we hit the next problem (e.g., "Problem D")
                    if re.search(r"\b(Problem|Task)\b", text) or re.match(r"^[A-Z]\.$", text):
                        break
            
            if is_recording:
                if isinstance(element, str):
                    found_text.append(element)
                elif element.name == 'br':
                    found_text.append("\n")

        full_tutorial = "".join(found_text).strip()
        
        # Fallback if parsing failed (Regex Dump)
        if len(full_tutorial) < 50:
             print("Header parsing failed, trying regex fallback...")
             text_dump = content.get_text(separator='\n')
             # Regex to find the problem letter followed by text
             pattern = f"(?:Problem|{contestId})?\\s*{index}\\b"
             match = re.search(pattern, text_dump, re.IGNORECASE)
             if match:
                 start = match.start()
                 full_tutorial = text_dump[start:start + 2500]

        return {
            "contestId": contestId,
            "index": index,
            "url": blog_url,
            "tutorial": full_tutorial
        }
        
    except Exception as e:
        print(f"Tutorial Fetch Error: {e}")
        return {"tutorial": "", "error": str(e)}