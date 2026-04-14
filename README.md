<div align="center">

# Codeforces Tool App (CP Mentor AI)

**An interactive, AI-powered companion for competitive programmers on Codeforces**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com/)
[![Gemini](https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)

</div>

---

## What We Built

Codeforces Tool App is a comprehensive, cross-platform application designed to be the ultimate companion for competitive programmers. It seamlessly integrates a Flutter frontend with a high-performance Python FastAPI backend.

The app provides:
- Real-time contest tracking  
- Highly accurate rating predictions (using FFT-based ELO simulations)  
- An intelligent AI mentor powered by Google's Gemini  

Whether you need a subtle hint on a complex problem without seeing the full solution, want to analyze your lifetime performance, or compare stats with friends, this tool enhances your algorithmic training workflow.

---

## How to Run Locally

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable)
- [Python 3.9+](https://www.python.org/downloads/)
- [Gemini API Key](https://aistudio.google.com/)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/codeforces_tool_app.git
cd codeforces_tool_app

# 2. Configure the Gemini API
# Open lib/api_service.dart and replace:
# 'YOUR_GEMINI_API_KEY_HERE'
# with your actual Gemini API key.

# 3. Install and start the backend
cd codeforces_tool_app_server_bk/server
pip install fastapi "uvicorn[standard]" sqlalchemy requests pydantic pydantic[email] passlib[bcrypt] pyjwt
uvicorn main:app --reload --port 8000
# Backend API will be available at http://127.0.0.1:8000

# 4. In a separate terminal, install and start the frontend
cd ../../
flutter pub get
flutter run
# To run on web:
# flutter run -d chrome
```

---

## Features

### AI-Powered Learning

| Feature | Purpose |
|--------|--------|
| **AI Mentor** | Chat with Gemini AI tailored for competitive programming guidance |
| **AI Hint** | Receive structured hints without spoilers |
| **Personalized Recommendations** | Get problem suggestions based on weak topics |

---

### Contest & Performance Tracking

#### Analytics & Predictions
- Dashboard with rating, stats, and quick insights  
- Rating calculator using FFT-based algorithms  
- Contest performance analytics with charts  
- Topic-wise strength and weakness analysis  

#### Social & History
- Compare multiple Codeforces users side-by-side  
- Track solved problems with search functionality  
- Browse contests directly inside the app  

---

### Additional Features

- Multi-platform support (Android, iOS, Web, Windows, macOS, Linux)  
- FastAPI proxy to bypass CORS issues  
- Local persistence for user configuration and auth  

---

## Tech Stack

| Layer | Technology | Purpose |
|------|-----------|--------|
| Frontend | Flutter / Dart | Cross-platform UI |
| Backend | FastAPI + Uvicorn | Async API, proxy, rating engine |
| Database | SQLite + SQLAlchemy | Local storage |
| AI | Google Gemini | Mentorship & hints |
| Platforms | Android, iOS, Web, Desktop | Native builds |

---

## Project Structure

```text
codeforces_tool_app/
├── android, ios, macos, windows, linux, web/   # Platform builds
├── codeforces_tool_app_server_bk/
│   └── server/
│       ├── main.py                             # FastAPI entry
│       └── ...                                 # Backend logic
├── lib/
│   ├── ai_hint_page.dart
│   ├── ai_mentor_page.dart
│   ├── api_service.dart
│   ├── codeforces_page.dart
│   ├── contest_analysis_page.dart
│   ├── friends_comparison_page.dart
│   ├── recommendation_page.dart
│   ├── rating_calculator.dart
│   └── main.dart
├── test/
└── pubspec.yaml
```

---

## Acknowledgements & License

- Codeforces platform by Mike Mirzayanov  
- Rating logic inspired by Carrot and TLE projects  

---

<div align="center">

Built to empower competitive programmers with AI-driven insights.

**Star this repository if you found it useful**

</div>
