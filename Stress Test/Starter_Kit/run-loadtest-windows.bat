@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if "%~1"=="" goto :usage
set "PROFILE=%~1"

if not "%PROFILE%"=="40" if not "%PROFILE%"=="60" if not "%PROFILE%"=="80" if not "%PROFILE%"=="100" (
    echo [ERROR] Profil %PROFILE% tidak tersedia.
    echo Pilihan: 40, 60, 80, 100
    exit /b 1
)

if not defined JMETER_HOME (
    echo [ERROR] JMETER_HOME belum diatur.
    echo Contoh:
    echo set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"
    exit /b 1
)

set "JMETER=%JMETER_HOME%\bin\jmeter.bat"
set "TEST_PLAN=test-plan.jmx"
set "TEMPLATE=scenario-%PROFILE%.properties.template"
set "PROPERTIES=scenario-%PROFILE%.properties"

if not exist "%JMETER%" (
    echo [ERROR] jmeter.bat tidak ditemukan:
    echo %JMETER%
    exit /b 1
)

if not exist "%TEST_PLAN%" (
    echo [ERROR] File JMX tidak ditemukan:
    echo %TEST_PLAN%
    exit /b 1
)

if not exist "%TEMPLATE%" (
    echo [ERROR] Template properties tidak ditemukan:
    echo %TEMPLATE%
    exit /b 1
)

if not exist "%PROPERTIES%" (
    copy /Y "%TEMPLATE%" "%PROPERTIES%" >nul
    echo [INFO] File %PROPERTIES% telah dibuat.
    echo [ACTION] Isi token dan data uji, lalu jalankan kembali.
    start "" notepad "%PROPERTIES%"
    exit /b 0
)

findstr /C:"<TOKEN_MASKED>" "%PROPERTIES%" >nul
if not errorlevel 1 (
    echo [ERROR] Token pada %PROPERTIES% masih berupa placeholder.
    start "" notepad "%PROPERTIES%"
    exit /b 1
)

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TIMESTAMP=%%I"

set "RESULT_DIR=results\scenario-%PROFILE%-%TIMESTAMP%"
set "REPORT_DIR=reports\scenario-%PROFILE%-%TIMESTAMP%"
set "JTL=%RESULT_DIR%\scenario-%PROFILE%.jtl"
set "LOG=%RESULT_DIR%\scenario-%PROFILE%-jmeter.log"

mkdir "%RESULT_DIR%" >nul 2>&1

echo =============================================
echo LOAD TEST APLIKASI INTERNAL
echo Profil     : %PROFILE% virtual users
echo Test plan  : %TEST_PLAN%
echo Properties : %PROPERTIES%
echo Result     : %RESULT_DIR%
echo Report     : %REPORT_DIR%
echo =============================================

call "%JMETER%" -n ^
  -t "%TEST_PLAN%" ^
  -q "%PROPERTIES%" ^
  -l "%JTL%" ^
  -j "%LOG%" ^
  -e -o "%REPORT_DIR%"

if errorlevel 1 (
    echo [ERROR] Pengujian gagal.
    echo Periksa log:
    echo %LOG%
    exit /b 1
)

echo [OK] Pengujian selesai.
echo [OK] Report:
echo %REPORT_DIR%\index.html

start "" "%REPORT_DIR%\index.html"
exit /b 0

:usage
echo Cara menggunakan:
echo run-loadtest-windows.bat 40
echo run-loadtest-windows.bat 60
echo run-loadtest-windows.bat 80
echo run-loadtest-windows.bat 100
exit /b 1
