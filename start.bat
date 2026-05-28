@echo off
echo ===================================================
echo   QORT PALEIDIMAS (HTML REZIMAS - BE MIRGEJIMO)
echo ===================================================
echo.
echo Valomas projektas...
call flutter clean
echo.
echo Siunciamos bibliotekos...
call flutter pub get
echo.
echo Paleidziama Chrome su HTML nustatymais...
flutter run -d chrome --web-renderer html
pause