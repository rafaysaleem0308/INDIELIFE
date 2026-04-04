@echo off
REM Start MongoDB with local data folder

set MONGO_DATA_PATH=D:\Semester 8\INDIELIFE-main\backend\mongo_data
set MONGO_PORT=27017

echo.
echo ========================================
echo   Starting MongoDB...
echo ========================================
echo.
echo Data Path: %MONGO_DATA_PATH%
echo Port:      %MONGO_PORT%
echo.

REM Check if mongo_data folder exists
if not exist "%MONGO_DATA_PATH%" (
    echo ERROR: mongo_data folder not found at %MONGO_DATA_PATH%
    pause
    exit /b 1
)

REM Start MongoDB
mongod --dbpath "%MONGO_DATA_PATH%" --port %MONGO_PORT%

if errorlevel 1 (
    echo.
    echo ERROR: Failed to start MongoDB
    echo Make sure MongoDB is installed and mongod is in your PATH
    echo.
    pause
    exit /b 1
)

pause
