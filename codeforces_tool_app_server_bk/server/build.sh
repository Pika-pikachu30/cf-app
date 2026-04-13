#!/usr/bin/env bash
# Exit on error
set -o errexit

pip install -r requirements.txt

# Run database migrations (create tables) if you haven't automated this in main.py
# If your main.py has `Base.metadata.create_all(bind=engine)`, you don't need a migration command here.