@ECHO off
ECHO Helper Script to install Webmin on Windows
ECHO (c) gnadelwartz https:://gitbub.com/gnadelwartz
ECHO .

:: prepare unautenticated Setup
SET WEBMIN_download=https://sourceforge.net/projects/webadmin/
SET WRT_download=https://www.microsoft.com/download/details.aspx?id=17657
SET PROCESS_download=http://retired.beyondlogic.org/solutions/processutil/processutil.htm
SET PERL_download=https://www.activestate.com/activeperl/
SET perl_path32=C:\Perl
SET perl_path64=C:\Perl64
SET inst_dir=C:\webmin
SET tmp_dir=C:\tmp
SET wa_dir=%inst_dir%\webmin
SET config_directory=%inst_dir%\config
SET var_dir=%inst_dir%\var
SET port=10000
SET admin=10000
SET ssl=0
SET login=admin
SET password=admin
SET INSTALL=setup.pl

:: check if we are in webmin dir
IF NOT EXIST %INSTALL% (
	ECHO Webmin installation script not found!
	ECHO setup.bat must be executed inside the webmin source dir.
	ECHO .
	ECHO you can download latest Webmin Version from
	ECHO https://sourceforge.net/projects/webadmin/
	start "" %WEBMIN_download%
	ECHO .
	PAUSE
	EXIT
)

:: check if perl is installed
IF EXIST %perl_path32% (
    SET perl_path=%perl_path32%
    ECHO Perl detected
) ELSE (
   IF EXIST %perl_path64% (
	SET perl_path=%perl_path64%
	echo Perl64 detected
    ) ELSE (
	ECHO Perl is not installed! Please download it from
	ECHO %PERL_download% and install it!
	start "" %PERL_download%
	ECHO .
	SET INSTALL=false
    )
)

:: check if process.exe is installed
WHERE process >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
	ECHO Required process.exe is not installed! Please download it from
	ECHO %PROCESS_download% and xopy it to C:\Windows!
	start "" %PROCESS_download%
	ECHO .
	SET INSTALL=false
)

:: check if rescource kit is installed
WHERE sc >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
	ECHO Windows Resource Toolkit is not installed! Please download it from
	ECHO %WRT_download% and install it!
	start "" %WRT_download%
	ECHO .
	SET INSTALL=false
)

:: check if needed dir exist
IF NOT EXIST %tmp_dir% (
	ECHO Create Webmin temp dir
	MD %tmp_dir%
)
IF NOT EXIST %inst_dir% (
	ECHO Create Webmin Main dir
	MD %inst_dir%
)



IF EXIST %INSTALL% (
    :: install perl module win::deamon if not installed
    IF NOT EXIST %perl_path%\site\lib\Win32\Daemon.pm (
	ppm install Win32-Daemon
    )
    SET perl_path=%perl_path%\bin\perl.exe
    perl %INSTALL% %wa_dir%
) ELSE (
	ECHO Webmin can not installed becasue of missing depedencies!
)
ECHO .
PAUSE

