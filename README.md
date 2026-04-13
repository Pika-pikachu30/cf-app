<div align="center">

# Codeforces Tool App (CP Mentor AI)

**An interactive, AI-powered companion for competitive programmers on Codeforces**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com/)
[![Gemini](https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)

</div>

---

## What We Built

Codeforces Tool App is a comprehensive, cross-platform application designed to be the ultimate companion for competitive programmers. It seamlessly integrates a Flutter frontend with a high-performance Python FastAPI backend. The app provides real-time contest tracking, highly accurate rating predictions (using FFT-based ELO simulations), and an intelligent AI mentor powered by Google's Gemini. Whether you need a subtle hint on a complex problem without seeing the full solution, want to analyze your lifetime performance, or compare stats with friends, this tool is built to enhance your algorithmic training journey.

---

## How to Run Locally

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable)
- [Python 3.9+](https://www.python.org/downloads/)
- [Gemini API Key](https://aistudio.google.com/)

### Steps

`ash
# 1. Clone the repository
git clone https://github.com/yourusername/codeforces_tool_app.git
cd codeforces_tool_app

# 2. Configure the Gemini API
# Open lib/api_service.dart and replace 'YOUR_GEMINI_API_KEY_HERE' 
# with your actual Gemini API key.

# 3. Install and start the backend
cd codeforces_tool_app_server_bk/server
pip install fastapi "uvicorn[standard]" sqlalchemy requests pydantic pydantic[email] passlib[bcrypt] pyjwt
uvicorn main:app --reload --port 8000
# Backend API will be available at http://127.0.0.1:8000

# 4. In a separate terminal, install and start the frontend
cd codeforces_tool_app
flutter pub get
flutter run
# To run specifically on the web: flutter run -d chrome
`

---

## Features

### AI-Powered Learning

| Feature | Purpose |
|------|---------|
| **AI Mentor** | Chat with Google's Gemini AI tailored specifically for competitive programming guidance. |
| **AI Hint** | Stuck on a complex problem? Receive structured hints without spoilers. |
| **Personalized Recommendations** | Get smart problem suggestions to boost your algorithmic skills based on your weak topics. |

---

### Contest & Performance Tracking

#### Analytics & Predictions
- **Dashboard**: Track your current Codeforces standing, rating changes, and quick stats.
- **Rating Calculator & Progress**: Simulate potential rating changes using FFT-based algorithms and view historical metrics.
- **Contest Analysis**: Deep dive into your recent contest performance with visual charts.
- **Topic Analysis**: Identify your strongest coding topics and areas needing improvement through aggregate submission data.

#### Social & History
- **Friends Comparison**: Add multiple Codeforces handles to compare rating progress side-by-side, view max ratings, and track solved problem counts.
- **Solved Problems Page**: An organized, searchable history of every problem you've cracked on the platform.
- **Codeforces Page**: Browse upcoming and past contests directly within the app.

---

### Additional Features

- **Multi-Platform Support**: Built natively on Flutter to seamlessly run on Android, iOS, Web, Windows, macOS, and Linux.
- **CORS Bypass Proxy**: The FastAPI backend proxies requests to Codeforces, bypassing default CORS restrictions for Web users.
- **Local Persistence**: Manages persistent auth and user configuration efficiently.

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | Flutter / Dart | Reactive, cross-platform native UI |
| Backend | Python FastAPI + Uvicorn | Async API, CORS proxy, and FFT rating engine |
| Database | SQLite + SQLAlchemy | Local user configuration, auth, and history |
| AI Integration | Google Generative AI | Gemini 3 Flash Preview for hints and mentorship |
| Platform Shells | Android, iOS, Web, Desktop | Native wrappers for respective operating systems |

---

## Project Structure

`	ext
codeforces_tool_app/
|-- android, ios, macos, windows, linux, web/  # Native build shells
|-- codeforces_tool_app_server_bk/             # Python backend server
|   |-- server/
|   |   |-- main.py                            # FastAPI entry point
|   |   +-- ...                                # Database & Rating algorithms
|-- lib/                                       # Core Flutter Codebase
|   |-- ai_hint_page.dart                      # Gemini hint UI
|   |-- ai_mentor_page.dart                    # Gemini chatbot UI
|   |-- api_service.dart                       # Backend proxy & API core
|   |-- codeforces_page.dart                   # Contests data view
|   |-- contest_analysis_page.dart             # Contest analytics charts
|   |-- friends_comparison_page.dart           # User sync & compare tool
|   |-- main.dart                              # Application launch loop
|   |-- recommendation_page.dart               # Problem suggestions logic
|   +-- rating_calculator.dart                 # Rating math engine UI
|-- test/                                      # Automated test suite
+-- pubspec.yaml                               # Flutter dependencies
`


## Acknowledgements & License

- Codeforces API handling based on the robust platform by [Mike Mirzayanov](https://codeforces.com/).
- Rating prediction logic adapts concepts from community tools like [Carrot](https://github.com/meooow25/carrot) and [TLE](https://github.com/cheran-senthil/TLE).

---

<div align="center">

Built to empower competitive programmers with actionable insights and AI assistance.

**[Star this repo](https://github.com/yourusername/codeforces_tool_app)** if you found it useful.

</div>
