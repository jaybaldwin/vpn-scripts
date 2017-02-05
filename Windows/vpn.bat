@SETLOCAL EnableExtensions EnableDelayedExpansion
@echo off

::-------------------------------------------------------
::-- Jay Baldwin's VPN Script
::-- 2017-02-05 10:26 AM
::-- 
::-- Copyright (C) 2017.  All rights reserved.
::-------------------------------------------------------



::-------------------------------------------------------
::-- CONFIGURATION
::-------------------------------------------------------

:: Gets the script name dynamically from the command prompt.
SET SCRIPT_NAME=%~f0

:: DEFAULT: Put your a file called "vpn-default-credentials" in the same folder as the script with
:: "username password" as the contents.  (No quotes.)
SET CREDENTIAL_FILE=vpn-default-credentials

:: Change this if you don't want the directory that holds the credentials to be the same directory 
:: in which the script resides.
SET CREDENTIAL_PATH=%~dp0



::-------------------------------------------------------
::-- INLINE OPERATION.  DO NOT EDIT PAST THIS LINE.
::-------------------------------------------------------

:: Begin console output
echo.
echo /***************************************************************
echo ** Jay Baldwin's VPN Script.  Built 2017-02-05 @ 10:26 AM **
echo ***************************************************************/


:: Isolate Filname

For %%A in ("%SCRIPT_NAME%") do (
    SET SCRIPT_PATH=%%~dpA
    SET SCRIPT_NAME=%%~nxA
)


:: Set global variables for IPaddy and lenIP.   
:: We use this to initially determine if the VPN is active.
call :getConnectionIP CONNECTION_NAME IPaddy
call :strlen lenIP IPaddy


:: Process arguments
IF [%1] == [] (
	GOTO vpn_help
	goto:eof
)
IF [%1] == [help] (
	GOTO vpn_help
	goto:eof
)

SET CONNECTION_NAME=%2

IF [%CONNECTION_NAME%] == [] (
	echo.
	echo [ERROR] No VPN_name specified. Exiting...
	goto:eof
)

IF [%1] == [echoip] GOTO echo_IP
IF [%1] == [stop] GOTO vpn_disable
IF [%1] == [start] (
	SET CONNECTION_NAME=%2
	call :vpn_enable %3 %4
	goto:eof
)



::-------------------------------------------------------
::-- ERROR: Invalid argument provided.
::-------------------------------------------------------
:error_invalid_argument
	echo.
	echo [ERROR] Invalid argument provided
	GOTO vpn_help
goto:eof



::-------------------------------------------------------
::-- Help / Usage
::-------------------------------------------------------
:vpn_help
	echo.
	echo Usage: 
	echo.
	echo    %SCRIPT_NAME% start [VPN_name] [username] [password]
	echo    or 
	echo    %SCRIPT_NAME% start [VPN_name] [path_to_credential_file]
	echo.
	echo    %SCRIPT_NAME% stop [VPN_name]
	echo    %SCRIPT_NAME% echoip [VPN_name]
	echo    %SCRIPT_NAME% help
	echo.
	echo NOTE: If using a credential file, order should be "[username] [password]".
	echo.
goto:eof



::-------------------------------------------------------
::-- Error that you need credentials
::-------------------------------------------------------
:error_need_credentials
echo.
	echo [ERROR] Please provide a USERNAME and PASSWORD or a credential file path.
	call :vpn_help
goto:eof



::-------------------------------------------------------
::-- Enable the VPN
::-------------------------------------------------------
:vpn_enable
(
	:: Check to see if credentials were passed in
	SET "USERNAME=%1"
	SET "PASSWORD=%2"
	
	
	:: If credentials are empty, set them to UNSET, for future checks. 
	IF [!USERNAME!] == [] SET "USERNAME=UNSET"
	IF [!PASSWORD!] == [] SET "PASSWORD=UNSET"
	
	
	:: Is it possible the USERNAME is a path to a credential file?
	IF [!CREDENTIALS!] == [] IF [!PASSWORD!] == [UNSET] IF [!USERNAME!] NEQ [UNSET] (
	
		echo Checking to see if credential file exists at "!USERNAME!"...
		IF EXIST !USERNAME! SET /p CREDENTIALS=<!USERNAME!
		
		IF [!CREDENTIALS!] == [] (
			echo Checking to see if credential file exists at "%CREDENTIAL_PATH%!USERNAME!"...
			IF EXIST %CREDENTIAL_PATH%!USERNAME! SET /p CREDENTIALS=<%CREDENTIAL_PATH%!USERNAME!
		)
	)
	
	:: Is there a default credential file?
	IF [!CREDENTIALS!] == [] IF EXIST %CREDENTIAL_FILE% (
		SET /p CREDENTIALS=<%CREDENTIAL_FILE%
	)
	
	IF [!CREDENTIALS!] == [] IF EXIST %CREDENTIAL_PATH%%CREDENTIAL_FILE% (
		SET /p CREDENTIALS=<%CREDENTIAL_PATH%%CREDENTIAL_FILE%
	)

	
	
	setlocal
	IF %lenIP% GTR 0 (
		echo.
		echo [ERROR] The VPN "%CONNECTION_NAME%" is already up^^!
	 	goto:eof
	)
		
	IF [!USERNAME!] == [UNSET] IF [!CREDENTIALS!] == [] GOTO error_need_credentials
	IF [!PASSWORD!] == [UNSET] IF [!CREDENTIALS!] == [] GOTO error_need_credentials
	
	echo.
	echo Preparing to start VPN "%CONNECTION_NAME%"...
	
	
	:: Connect!	
	echo.	
	IF [!CREDENTIALS!] == [] rasdial %CONNECTION_NAME% !USERNAME! !PASSWORD!
	IF [!CREDENTIALS!] NEQ [] rasdial %CONNECTION_NAME% !CREDENTIALS!
	echo.
	
	call :getConnectionIP CONNECTION_NAME connIPaddy
	call :strlen lenConnIP connIPaddy
	
	IF !lenConnIP! EQU 0 (
		echo [ERROR] The connection could not be made.  Exiting...
		goto:eof
	)
	
	echo Connected to VPN "%CONNECTION_NAME%" with IP address: !connIPaddy!
	
	IF [%CONNECTION_NAME%] == [WHC] call :vpn_whc_onconnect
)
(
	endlocal
	exit /b
)
goto:eof



::-------------------------------------------------------
::-- Disable the VPN
::-------------------------------------------------------
:vpn_disable
	IF %lenIP% EQU 0 (
		echo.
		echo [ERROR] The VPN "%CONNECTION_NAME%" is not up^^!
	 	goto:eof
	)
	
	echo.
	echo Preparing to stop VPN "%CONNECTION_NAME%"...
	
	echo.
	rasdial %CONNECTION_NAME% /disconnect

	:: These seem to happen automatically.
	::route delete 40.139.246.39
	::route delete 40.139.246.62

	exit /b
goto:eof



::-------------------------------------------------------
::-- Echo the VPN IP Address
::-------------------------------------------------------
:echo_IP
(
	setlocal
	IF %lenIP% EQU 0 (
		echo.
		echo [ERROR] The VPN "%CONNECTION_NAME%" is not up^^!
	 	goto:eof
	)
	
	call :getConnectionIP CONNECTION_NAME connIPaddy
	
	echo.
	echo Connected to VPN "%CONNECTION_NAME%" with IP address: !connIPaddy!
)
(
	endlocal
	exit /b
)
goto:eof



::-------------------------------------------------------
::-- Gets the IP address from the VPN connection "WHC"
::-------------------------------------------------------
:getConnectionIP <vpnName> <resultVar>
(
	setlocal EnableDelayedExpansion
	set "conn=!%~1!"
	
	:: Get the IP address LINE from ipconfig after the :
	for /f "tokens=2 delims=:" %%g in ('netsh interface ip show address "!conn!" ^| findstr "IP"') do set IPaddy=%%g

	:: Trim
	for /f "tokens=1-5 delims=," %%A in ("!IPaddy!") do (
	  call :Trim "%%A" IPaddy
	)
)
(
	endlocal
	set "%~2=%IPaddy%"
	exit /b
)
goto:eof



::-------------------------------------------------------
::-- Standard TRIM function
::-------------------------------------------------------
:Trim "input-string" <resultVar> 
	set s=%~1
	for /F "tokens=* delims= " %%A in ("%s%") do set s=%%A
	for /L %%A in (1,1,50) do if "!s:~-1!"==" " set s=!s:~0,-1!
	set %~2=%s%
exit /b

goto:eof



::-------------------------------------------------------
::-- Gets the character length of a string.  Returns int.
::-------------------------------------------------------
:strLen <resultVar> <stringVar>
(   
    setlocal EnableDelayedExpansion
    set "s=!%~2!#"
    set "len=0"
    for %%P in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
        if "!s:~%%P,1!" NEQ "" ( 
            set /a "len+=%%P"
            set "s=!s:~%%P!"
        )
    )
)
( 
    endlocal
    set "%~1=%len%"
    exit /b
)
goto:eof



::-------------------------------------------------------
::-- OnConnect script for the WHC network.
::-------------------------------------------------------
:vpn_whc_onconnect
(
	call :getConnectionIP CONNECTION_NAME connIPaddy
	call :strlen lenConnIP connIPaddy
	
	echo.
	echo Adding static route for [whciis.rodparsley.com] (40.139.246.39^)...
	route add 40.139.246.39 !connIPaddy!

	echo.
	echo Adding static route for [websql.rodparsley.com] (40.139.246.38^)...
	route add 40.139.246.38 !connIPaddy!

	echo.
	echo Adding static route for the WHC Network (10.1.4.0, 10.1.1.0, 10.1.10.0^)...
	route add 10.1.4.0 !connIPaddy!
	route add 10.1.1.0 !connIPaddy!
	route add 10.1.10.0 !connIPaddy!
)
goto:eof