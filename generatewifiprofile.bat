@echo off
setlocal

:: Set file paths
set name_file=%~dp0pc_name.txt
set site_info_file=%~dp0site_info.txt

:: Ensure script is run as Administrator
net session >nul 2>&1
if not %errorLevel% == 0 (
    echo "This script requires administrator privileges. Please run as administrator."
    pause
    exit /b
)

:choose_network
echo Select the network:
echo 1. ncpsp
echo 2. DOEGuest
set /p choice=Enter your choice (1 or 2): 

if "%choice%"=="1" (
    set network_name=ncpsp
    set network_hex=6e63707370
) else if "%choice%"=="2" (
    set network_name=DOEGuest
    set network_hex=444F454775657374
) else (
    echo Invalid choice. Please select 1 or 2.
    goto choose_network
)

:find_existing_xml
rem Check for existing .xml files for the selected network on the USB drives

for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%d:\%network_name%.xml set found_file=%%d:\%network_name%.xml
)

if defined found_file (
    echo Found existing XML file: %found_file%.
    set xml_path=%found_file%
    goto confirm_connection
) else (
    goto ask_password
)

:confirm_connection
echo Do you want to use the existing XML file to connect to %network_name%?
echo 1. Yes
echo 2. No
set /p connect_choice=Enter your choice (1 or 2): 

if "%connect_choice%"=="1" (
    goto install_profile
) else if "%connect_choice%"=="2" (
    goto ask_password
) else (
    echo Invalid choice. Please select 1 or 2.
    goto confirm_connection
)

:ask_password
set /p password=Enter the network password: 

rem If ncpsp network is selected and no name file exists, proceed to rename the computer
if "%network_name%"=="ncpsp" if not exist "%name_file%" goto rename_computer

:list_usb_drives
echo Available USB drives:
wmic logicaldisk where "drivetype=2" get deviceid, volumename, description
echo.

:ask_drive
set /p drive_letter=Enter the USB drive letter (e.g., E): 
set drive_letter=%drive_letter:~0,1%
if not exist %drive_letter%:\ (
    echo Drive %drive_letter% does not exist. Please enter a valid drive letter.
    goto ask_drive
)

:create_xml
set xml_path=%drive_letter%:\%network_name%.xml
(
echo ^<?xml version="1.0"?^>
echo ^<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1"^>
echo     ^<name^>%network_name%^</name^>
echo     ^<SSIDConfig^>
echo         ^<SSID^>
echo             ^<hex^>%network_hex%^</hex^>
echo             ^<name^>%network_name%^</name^>
echo         ^</SSID^>
echo     ^</SSIDConfig^>
echo     ^<connectionType^>ESS^</connectionType^>
echo     ^<connectionMode^>auto^</connectionMode^>
echo     ^<MSM^>
echo         ^<security^>
echo             ^<authEncryption^>
echo                 ^<authentication^>WPA2PSK^</authentication^>
echo                 ^<encryption^>AES^</encryption^>
echo                 ^<useOneX^>false^</useOneX^>
echo             ^</authEncryption^>
echo             ^<sharedKey^>
echo                 ^<keyType^>passPhrase^</keyType^>
echo                 ^<protected^>false^</protected^>
echo                 ^<keyMaterial^>%password%^</keyMaterial^>
echo             ^</sharedKey^>
echo         ^</security^>
echo     ^</MSM^>
echo     ^<MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3"^>
echo         ^<enableRandomization^>false^</enableRandomization^>
echo     ^</MacRandomization^>
echo ^</WLANProfile^>
) > "%xml_path%"

echo XML file "%network_name%.xml" has been created successfully on drive %drive_letter%.

goto install_profile

:install_profile
echo Adding the profile to the system...
netsh wlan add profile filename="%xml_path%" user=all

:connect_network
echo Connecting to %network_name%...
netsh wlan connect name=%network_name%
timeout /t 10 >nul

:check_connection
set connected_ssid=
for /f "tokens=2 delims=:" %%a in ('netsh wlan show interfaces ^| findstr /r /c:"SSID.*:"') do set connected_ssid=%%a
set connected_ssid=%connected_ssid:~1%
if /i "%connected_ssid%"=="%network_name%" (
    echo Successfully connected to %network_name%.
) else (
    echo Failed to connect to %network_name%. Connected to "%connected_ssid%" instead.
    echo Please check the credentials and try again.
)

pause
goto end

:check_existing_name
set /p current_name=<"%name_file%"
echo The current computer name is %current_name%.
set /p confirm_name=Is this name correct? (Y/N): 
if /i "%confirm_name%"=="Y" (
    echo Name confirmed. Proceeding with network connection...
    goto list_usb_drives
) else (
    echo Name rejected. Proceeding with renaming process...
    del "%name_file%" 2>nul
    goto rename_computer
)

:rename_computer
rem Proceed to rename the computer based on ncpsp password
set last_six=%password:~-6%

if "%last_six:~4,1%"=="B" (
    set last_six=%last_six:~0,4%K%last_six:~5,1%
)

echo Renaming the computer to match the last 6 characters of the ncpsp password...
WMIC ComputerSystem where Name="%ComputerName%" call Rename Name="%last_six%-%~1"
echo %last_six% > "%name_file%"
echo Computer successfully renamed to "%last_six%-%~1"
goto list_usb_drives

:end
echo Script completed. Press any key to close.
pause >nul
