@echo off
echo ========================================
echo   DEPLOYING FINZOBILLING TO WEB
echo ========================================
echo.
echo [1/3] Building...
flutter build web --release --base-href "/finzobilling/"
echo.
echo [2/3] Deploying...
cd build\web
git init
git add .
git commit -m "Update FinzoBilling - %date%"
git push -f https://github.com/YerraAvinashRao/finzobilling.git main:gh-pages
cd ..\..
echo.
echo [3/3] Done!
echo ========================================
echo   WEBSITE UPDATED!
echo ========================================
echo Visit: https://yerraavinashrao.github.io/finzobilling/
pause
