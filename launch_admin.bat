@echo off
title Expenso Admin Dashboard
set "project_dir=c:\Users\rishi\Documents\GitHub\Expenso"

cd /d "%project_dir%"

echo.
echo ========================================
echo   🚀 STARTING EXPENSO ADMIN DASHBOARD
echo ========================================
echo.
echo [1/2] Opening browser to http://localhost:7171...
start "" "http://localhost:7171"

echo [2/2] Starting Local Server...
echo (Keep this window open while using the dashboard)
echo.

python -m http.server 7171 --directory "admin"

if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: Failed to start the server. 
    echo Make sure Python is installed and no other app is using port 7171.
    pause
)
