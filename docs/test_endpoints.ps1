param (
    [string]$BaseUrl = "http://localhost:8080"
)

Write-Host "=== ТЕСТУВАННЯ ЕНДПОІНТІВ MANGODATA API (QA: ЖЕ) ===" -ForegroundColor Cyan

# 1. Реєстрація
Write-Host "`n1. POST /api/auth/register" -ForegroundColor Yellow
$regBody = @{ email = "qa_demo@kakatone.com"; password = "secret_password" } | ConvertTo-Json
try {
    $res = Invoke-RestMethod -Uri "$BaseUrl/api/auth/register" -Method Post -Body $regBody -ContentType "application/json"
    Write-Host " [OK] Зареєстровано:" ($res | ConvertTo-Json -Compress) -ForegroundColor Green
} catch {
    Write-Host " [WARN] Помилка або вже існує: $_" -ForegroundColor DarkYellow
}

# 2. Логін
Write-Host "`n2. POST /api/auth/login" -ForegroundColor Yellow
$token = ""
try {
    $res = Invoke-RestMethod -Uri "$BaseUrl/api/auth/login" -Method Post -Body $regBody -ContentType "application/json"
    $token = $res.token
    Write-Host " [OK] Токен отримано: $token" -ForegroundColor Green
} catch {
    Write-Host " [FAIL] Логін не вдався: $_" -ForegroundColor Red
}

# 3. GET /api/meta/dota
Write-Host "`n3. GET /api/meta/dota" -ForegroundColor Yellow
try {
    $meta = Invoke-RestMethod -Uri "$BaseUrl/api/meta/dota" -Method Get
    Write-Host " [OK] Отримано мета-героїв:" $meta.meta_heroes.Count -ForegroundColor Green
} catch {
    Write-Host " [FAIL] Помилка отримання мети: $_" -ForegroundColor Red
}

# 4. GET /api/dota/heroes/14
Write-Host "`n4. GET /api/dota/heroes/14" -ForegroundColor Yellow
try {
    $hero = Invoke-RestMethod -Uri "$BaseUrl/api/dota/heroes/14" -Method Get
    Write-Host " [OK] Герой:" $hero.name "| Білд від AI:" ($hero.ai_build.tactics) -ForegroundColor Green
} catch {
    Write-Host " [FAIL] Помилка героя: $_" -ForegroundColor Red
}

# 5. POST /admin/sync
Write-Host "`n5. POST /admin/sync" -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $token" }
    $sync = Invoke-RestMethod -Uri "$BaseUrl/admin/sync" -Method Post -Headers $headers
    Write-Host " [OK] Синхронізація виконана:" ($sync | ConvertTo-Json -Compress) -ForegroundColor Green
} catch {
    Write-Host " [FAIL] Помилка ручного синку: $_" -ForegroundColor Red
}

Write-Host "`n=== ТЕСТУВАННЯ ЗАВЕРШЕНО ===" -ForegroundColor Cyan
