@echo off
setlocal EnableDelayedExpansion
:: =============================================================================
:: firebase_update — Test Runner (Windows)
::
:: Usage:
::   run_tests.bat                        interactive
::   run_tests.bat -d <device-id>         pre-select device by id or 1-based index
::   run_tests.bat -d <id> --live         also run live RC test without prompting
::   run_tests.bat --no-device            skip all device tests
::
:: Examples:
::   run_tests.bat -d macos --live
::   run_tests.bat -d 00120647H011016 --live
:: =============================================================================

:: ── Resolve package root ─────────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PKG_ROOT=%CD%"
set "EXAMPLE_DIR=%PKG_ROOT%\example"
set "LOG_DIR=%PKG_ROOT%\.test_logs"
if not exist "!LOG_DIR!" mkdir "!LOG_DIR!"

:: ── Colours ──────────────────────────────────────────────────────────────────
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "R=!ESC![0;31m" & set "G=!ESC![0;32m" & set "Y=!ESC![1;33m"
set "C=!ESC![0;36m" & set "B=!ESC![1m"    & set "D=!ESC![2m" & set "N=!ESC![0m"
set "SEP2=!C!!B!════════════════════════════════════════════════!N!"

:: ── Parse CLI flags ───────────────────────────────────────────────────────────
set "CLI_DEVICE="
set "CLI_LIVE=false"
set "CLI_NO_DEVICE=false"

:parse_args
if "%~1"=="" goto :parse_done
if /i "%~1"=="-d"         ( set "CLI_DEVICE=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="--device"   ( set "CLI_DEVICE=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="--live"     ( set "CLI_LIVE=true"  & shift & goto :parse_args )
if /i "%~1"=="--no-device"( set "CLI_NO_DEVICE=true" & shift & goto :parse_args )
echo Unknown flag: %~1 >&2 & exit /b 1
:parse_done

:: ── State ────────────────────────────────────────────────────────────────────
set /a PASS=0
set /a FAIL=0
set "FAIL_LABELS="

:: =============================================================================
:: SUB: run_suite — args: label logfile cmd...
:: =============================================================================
goto :main

:run_suite
  set "_LABEL=%~1"
  set "_LOG=%~2"
  shift & shift
  set "_CMD="
  :arg_loop
    if "%~1"=="" goto :arg_done
    set "_CMD=!_CMD! %1"
    shift
    goto :arg_loop
  :arg_done

  <nul set /p "=  !_LABEL!"
  set "_PAD=!_LABEL!"
  :pad_loop
    if "!_PAD:~52!"=="" set "_PAD=!_PAD! " & goto :pad_loop
  <nul set /p "=!_PAD:~52,2!"

  cmd /c "!_CMD!" > "!_LOG!" 2>&1
  set "_CODE=!ERRORLEVEL!"

  if !_CODE! equ 0 (
    set "_COUNT="
    for /f "tokens=2 delims=+" %%L in ('findstr /r " +[0-9]*:" "!_LOG!" 2^>nul') do (
      for /f "tokens=1 delims=:" %%N in ("%%L") do set "_COUNT=%%N"
    )
    echo   !G!!B!+ passed!N! !D!^(!_COUNT! tests^)!N!
    set /a PASS+=1
  ) else (
    set "_SUM="
    for /f "delims=" %%L in ('findstr /r "^+[0-9]" "!_LOG!" 2^>nul') do set "_SUM=%%L"
    echo   !R!!B!x FAILED!N! !D!!_SUM!!N!
    set /a FAIL+=1
    if "!FAIL_LABELS!"=="" ( set "FAIL_LABELS=!_LABEL!" ) else ( set "FAIL_LABELS=!FAIL_LABELS!|!_LABEL!" )
    for /f "delims=" %%L in ('findstr /c:"Error:" /c:"Expected:" /c:"Actual:" "!_LOG!" 2^>nul') do (
      echo      !R!^| %%L!N!
    )
    echo      !D!log ^> !_LOG!!N!
  )
goto :eof

:: =============================================================================
:main
:: =============================================================================

echo !SEP2!
echo !C!!B!  firebase_update ^· Test Runner!N!
echo !SEP2!
echo.

set "DEVICE_ID="
set "DEVICE_NAME="

if "!CLI_NO_DEVICE!"=="true" (
  echo   !D!--no-device: skipping all device tests.!N!
  goto :tests_start
)

echo !B!  Detecting available devices...!N!
echo.

:: Collect devices
set /a DEV_COUNT=0
for /f "tokens=1,* delims=•" %%A in ('flutter devices 2^>nul ^| findstr "•"') do (
  set "_NAME=%%A"
  for /f "tokens=1 delims=•" %%X in ("%%B") do set "_ID=%%X"
  for /f "tokens=* delims= " %%T in ("!_NAME!") do set "_NAME=%%T"
  for /f "tokens=* delims= " %%T in ("!_ID!")   do set "_ID=%%T"
  if not "!_ID!"=="" (
    set "DEV_ID[!DEV_COUNT!]=!_ID!"
    set "DEV_NAME[!DEV_COUNT!]=!_NAME!"
    set /a DEV_COUNT+=1
  )
)

if not "!CLI_DEVICE!"=="" (
  :: Match by 1-based index or id substring
  set /a "CLI_IDX=!CLI_DEVICE!-1" 2>nul
  set "_MATCHED=false"
  if !CLI_IDX! geq 0 if !CLI_IDX! lss !DEV_COUNT! (
    set "DEVICE_ID=!DEV_ID[%CLI_IDX%]!"
    set "DEVICE_NAME=!DEV_NAME[%CLI_IDX%]!"
    set "_MATCHED=true"
  )
  if "!_MATCHED!"=="false" (
    :: Try substring match on id
    for /l %%I in (0,1,!DEV_COUNT!) do (
      if not "!DEV_ID[%%I]!"=="" (
        echo !DEV_ID[%%I]!|findstr /i "!CLI_DEVICE!" >nul 2>&1
        if not errorlevel 1 (
          set "DEVICE_ID=!DEV_ID[%%I]!"
          set "DEVICE_NAME=!DEV_NAME[%%I]!"
          set "_MATCHED=true"
        )
      )
    )
  )
  if "!DEVICE_ID!"=="" (
    echo   !R!Device '!CLI_DEVICE!' not found. Skipping device tests.!N!
  ) else (
    echo   !G!Running on:!N! !B!!DEVICE_NAME!!N! !D!^(!DEVICE_ID!^)!N!
  )
) else if !DEV_COUNT! equ 0 (
  echo   !Y!No devices found. Example integration tests will be skipped.!N!
) else (
  echo   !B!Select a device for example integration tests:!N!
  echo.
  for /l %%I in (0,1,!DEV_COUNT!) do (
    if not "!DEV_ID[%%I]!"=="" (
      set /a "_NUM=%%I+1"
      echo   !C!!B![!_NUM!]!N!  !DEV_NAME[%%I]!  !D!^(!DEV_ID[%%I]!^)!N!
    )
  )
  echo.
  set /p "CHOICE=  Choice [1-!DEV_COUNT!, or 0 to skip device tests]: "
  if "!CHOICE!"=="0" (
    echo.
    echo   !D!Skipping example integration tests.!N!
  ) else (
    set /a "IDX=!CHOICE!-1"
    set "DEVICE_ID=!DEV_ID[%IDX%]!"
    set "DEVICE_NAME=!DEV_NAME[%IDX%]!"
    echo.
    echo   !G!Running on:!N! !B!!DEVICE_NAME!!N! !D!^(!DEVICE_ID!^)!N!
  )
)

echo.

:tests_start
:: =============================================================================
echo !SEP2!
echo !C!!B!  [1/3]  Package Tests!N!  !D!(no device)!N!
echo !SEP2!
echo.

cd /d "!PKG_ROOT!"
call :run_suite "firebase_update_test.dart" "!LOG_DIR!\firebase_update_test.log" flutter test test\firebase_update_test.dart --reporter=compact
call :run_suite "firebase_update_flow_integration_test.dart" "!LOG_DIR!\firebase_update_flow_integration_test.log" flutter test test\firebase_update_flow_integration_test.dart --reporter=compact

echo.

:: =============================================================================
echo !SEP2!
echo !C!!B!  [2/3]  Example App Tests!N!  !D!(no device)!N!
echo !SEP2!
echo.

cd /d "!EXAMPLE_DIR!"
call :run_suite "example\test\widget_test.dart" "!LOG_DIR!\example_widget_test.log" flutter test test\widget_test.dart --reporter=compact

echo.

:: =============================================================================
echo !SEP2!
echo !C!!B!  [3/3]  Example Integration Tests!N!  !D!(on device)!N!
echo !SEP2!
echo.

if "!DEVICE_ID!"=="" (
  echo   !D!Skipped -- no device selected.!N!
) else (
  cd /d "!EXAMPLE_DIR!"
  call :run_suite "integration_test\update_flow_test.dart" "!LOG_DIR!\integration_update_flow.log" flutter test integration_test\update_flow_test.dart -d !DEVICE_ID! --reporter=compact
  call :run_suite "integration_test\priority_sequence_test.dart" "!LOG_DIR!\integration_priority_sequence.log" flutter test integration_test\priority_sequence_test.dart -d !DEVICE_ID! --reporter=compact

  echo.
  set "SA_JSON=!PKG_ROOT!\test\firebase_config\service-account.json"
  if not exist "!SA_JSON!" (
    echo   !D!live_rc_test.dart skipped -- service-account.json not found at:!N!
    echo   !D!  test\firebase_config\service-account.json!N!
  ) else (
    echo   !D!live_rc_test.dart hits the Firebase REST API using test\firebase_config\service-account.json!N!
    if "!CLI_LIVE!"=="true" (
      set "RUN_LIVE=y"
    ) else (
      set /p "RUN_LIVE=  Run it? [y/N]: "
    )
    if /i "!RUN_LIVE!"=="y" (
      :: Extract key with literal \n — avoids --dart-define-from-file Android build chain bug
      set "SA_KEY="
      for /f "delims=" %%K in ('python -c "import json; sa=json.load(open(r\"!SA_JSON!\")); print(sa[\"private_key\"].replace(\"\n\",\"\\n\"), end=\"\")" 2^>nul') do set "SA_KEY=%%K"
      if "!SA_KEY!"=="" (
        echo   !R!Could not read private_key from service-account.json -- skipping.!N!
      ) else (
        call :run_suite "integration_test\live_rc_test.dart" "!LOG_DIR!\integration_live_rc.log" flutter test integration_test\live_rc_test.dart -d !DEVICE_ID! --reporter=compact "--dart-define=SA_PRIVATE_KEY=!SA_KEY!"
      )
    ) else (
      echo   !D!live_rc_test.dart skipped.!N!
    )
  )
)

echo.

:: =============================================================================
echo !SEP2!
echo !C!!B!  Results!N!
echo !SEP2!
echo.

set /a TOTAL=!PASS!+!FAIL!
echo   !B!Total suites:  !TOTAL!!N!
echo   !G!!B!Passed:        !PASS!!N!

if !FAIL! gtr 0 (
  echo   !R!!B!Failed:        !FAIL!!N!
  echo.
  echo   !R!!B!Failed:!N!
  set "REMAINING=!FAIL_LABELS!"
  :print_fail_loop
  if "!REMAINING!"=="" goto :print_fail_done
  for /f "tokens=1* delims=|" %%A in ("!REMAINING!") do (
    echo     !R!x  %%A!N!
    set "REMAINING=%%B"
  )
  goto :print_fail_loop
  :print_fail_done
  echo.
  echo   !R!!B!Fix the failures above before shipping.!N!
) else (
  echo.
  echo   !G!!B!+  All clear -- you're good to go!!N!
  echo   !G!   Good job, developer. Ship it.!N!
)

echo.
echo !SEP2!
echo.

if !FAIL! gtr 0 exit /b 1
exit /b 0
