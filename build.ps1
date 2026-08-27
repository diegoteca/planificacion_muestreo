# Detener la ejecucion si ocurre un error critico
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 1. Compilando version Typst (PDF)..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
quarto render --to typst

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 2. Compilando version HTML (--no-clean)..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
# Uso --no-clean para evitar que se elimine el PDF generado previamente por Typst
quarto render --to html --no-clean

Write-Host "==========================================" -ForegroundColor Green
Write-Host " 3. Sincronizando con GitHub..." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
git add .
$status = git status --porcelain
if ($status) {
    $commitMsg = "Compilacion y publicacion automatica: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    git commit -m $commitMsg
    git push origin main
    Write-Host " Cambios publicados exitosamente en GitHub." -ForegroundColor Green
} else {
    Write-Host " No hay cambios pendientes para commitear." -ForegroundColor Yellow
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host " Proceso finalizado." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
