@echo off
setlocal EnableDelayedExpansion

rem --- Claude Code Profile Switcher ---
rem Swaps .claude directory and .claude.json between named profiles.
rem Profile names and detection strings are read from profiles.ini.
rem
rem Parked profiles are stored as: .claude-<name>  (e.g., .claude-work)
rem Parked JSON files as:          .claude.json.<name>

set "PROFILE=%~1"
set "HOME=%USERPROFILE%"
set "CLAUDE_DIR=%HOME%\.claude"
set "CLAUDE_JSON=%HOME%\.claude.json"
set "CLAUDE_JSON_BACKUP=%HOME%\.claude.json.backup"
set "INI=%~dp0profiles.ini"

if "%PROFILE%"=="" (
    echo Usage: claude-switch.bat [profile-name]
    exit /b 1
)

rem --- Read profile names from INI ---
set "PROFILE_COUNT=0"
for /f "usebackq tokens=1 delims=[]" %%A in (`findstr /r "^\[" "%INI%"`) do (
    set /a PROFILE_COUNT+=1
    set "PROFILE_!PROFILE_COUNT!=%%A"
)

rem --- Validate requested profile ---
set "VALID=0"
for /l %%i in (1,1,!PROFILE_COUNT!) do (
    if "%PROFILE%"=="!PROFILE_%%i!" set "VALID=1"
)
if "!VALID!"=="0" (
    echo Unknown profile: %PROFILE%
    echo Available profiles:
    for /l %%i in (1,1,!PROFILE_COUNT!) do echo   !PROFILE_%%i!
    exit /b 1
)

rem --- Detect current active profile ---
set "CURRENT=unknown"
if exist "%CLAUDE_DIR%\settings.json" (
    for /l %%i in (1,1,!PROFILE_COUNT!) do (
        set "P=!PROFILE_%%i!"
        set "DETECT="
        set "IN_SECTION=0"
        for /f "usebackq tokens=1,* delims==" %%K in ("%INI%") do (
            set "LINE=%%K"
            if "!LINE!"=="[!P!]" set "IN_SECTION=1"
            if "!IN_SECTION!"=="1" if "!LINE!"=="detect" set "DETECT=%%L"
            if "!LINE:~0,1!"=="[" if not "!LINE!"=="[!P!]" set "IN_SECTION=0"
        )
        if defined DETECT (
            findstr /c:"!DETECT!" "%CLAUDE_DIR%\settings.json" >nul 2>&1
            if !errorlevel! equ 0 (
                if "!CURRENT!"=="unknown" set "CURRENT=!P!"
            )
        )
    )
    if "!CURRENT!"=="unknown" set "CURRENT=!PROFILE_%PROFILE_COUNT%!"
)

rem --- If already the correct profile, exit early ---
if "%CURRENT%"=="%PROFILE%" (
    echo Already on %PROFILE% profile.
    exit /b 0
)

rem --- Determine the "other" profile (the one being parked) ---
set "OTHER="
for /l %%i in (1,1,!PROFILE_COUNT!) do (
    if not "%PROFILE%"=="!PROFILE_%%i!" set "OTHER=!PROFILE_%%i!"
)

rem --- Park current .claude ---
set "PARK_DIR=%HOME%\.claude-!OTHER!"
if exist "%CLAUDE_DIR%" (
    if exist "!PARK_DIR!" (
        echo ERROR: Both .claude and .claude-!OTHER! exist. Manual intervention needed.
        exit /b 2
    )
    call :ren_retry "%CLAUDE_DIR%" ".claude-!OTHER!"
    if errorlevel 1 (
        echo ERROR: Failed to rename .claude to .claude-!OTHER!. Files may be locked.
        exit /b 3
    )
)

rem --- Activate target profile ---
set "TARGET_DIR=%HOME%\.claude-!PROFILE!"
if exist "!TARGET_DIR!" (
    call :ren_retry "!TARGET_DIR!" ".claude"
    if errorlevel 1 (
        echo ERROR: Failed to rename .claude-!PROFILE! to .claude.
        exit /b 3
    )
) else (
    echo ERROR: .claude-!PROFILE! not found. Nothing to activate.
    exit /b 3
)

rem --- Swap .claude.json ---
if exist "%CLAUDE_JSON%" (
    move /y "%CLAUDE_JSON%" "%HOME%\.claude.json.!OTHER!" >nul
)
if exist "%CLAUDE_JSON_BACKUP%" (
    move /y "%CLAUDE_JSON_BACKUP%" "%HOME%\.claude.json.backup.!OTHER!" >nul
)
if exist "%HOME%\.claude.json.!PROFILE!" (
    move /y "%HOME%\.claude.json.!PROFILE!" "%CLAUDE_JSON%" >nul
)
if exist "%HOME%\.claude.json.backup.!PROFILE!" (
    move /y "%HOME%\.claude.json.backup.!PROFILE!" "%CLAUDE_JSON_BACKUP%" >nul
)

echo Switched to %PROFILE% profile.
exit /b 0

rem --- Retry a directory rename: handles can linger ~1s after a process exits ---
rem %1 = full source path, %2 = target name (same parent). Returns 0 on success, 1 on failure.
rem Success is verified by the target existing and the source being gone (ren's errorlevel
rem is unreliable for locked directories).
:ren_retry
setlocal EnableDelayedExpansion
set "SRC=%~1"
set "DST=%~2"
set "DSTFULL=%~dp1%~2"
set /a _tries=0
:ren_retry_loop
ren "!SRC!" "!DST!" 2>nul
if exist "!DSTFULL!" if not exist "!SRC!" ( endlocal & exit /b 0 )
set /a _tries+=1
if !_tries! geq 5 ( endlocal & exit /b 1 )
ping -n 2 127.0.0.1 >nul
goto ren_retry_loop
