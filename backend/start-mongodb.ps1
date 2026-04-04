# Start MongoDB with local data folder
$mongoDataPath = "D:\Semester 8\INDIELIFE-main\backend\mongo_data"
$mongoPort = 27017

Write-Host "🚀 Starting MongoDB..." -ForegroundColor Cyan
Write-Host "📁 Data Path: $mongoDataPath" -ForegroundColor Gray
Write-Host "🔌 Port: $mongoPort" -ForegroundColor Gray

# Check if mongo_data folder exists
if (-not (Test-Path $mongoDataPath)) {
    Write-Host "❌ mongo_data folder not found at $mongoDataPath" -ForegroundColor Red
    exit 1
}

# Start MongoDB
try {
    mongod --dbpath $mongoDataPath --port $mongoPort
    Write-Host "✅ MongoDB started successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to start MongoDB: $_" -ForegroundColor Red
    exit 1
}
