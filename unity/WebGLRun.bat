@echo off
cd /d %~dp0
start "Web Server" cmd /k python -m http.server 8000
timeout /t 2
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" "http://localhost:8000"