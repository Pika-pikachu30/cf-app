from fastapi import FastAPI, HTTPException
import requests
from bs4 import BeautifulSoup
import re

app = FastAPI()
