@ECHO off
:: (c) gnadelwartz https:://gitbub.com/gnadelwartz
ECHO UNOFFICIAL helper script to guide less experienced users on Windows
ECHO for information on installing webmin on Windows manually see:
ECHO http://www.webmin.com/windows.html
ECHO .
ECHO NOTE: Webmin on Windows is community provided and not supported officially!
ECHO last reported working insallations was on Windows 8.1
ECHO .

:: prepare unautenticated Setup
SET WEBMIN_download=https://sourceforge.net/projects/webadmin/
SET WRT_download=https://www.microsoft.com/download/details.aspx?id=17657
SET PROCESS_download=https://web.archive.org/web/20180105215524/http://retired.beyondlogic.org/solutions/processutil/processutil.htm
SET PERL_download=https://platform.activestate.com/ActiveState/ActivePerl-5.26
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
SET nostart=nostart
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
ECHO Check for Webmin  prerequisites ...
IF EXIST %perl_path32% (
    SET perl_path=%perl_path32%
    ECHO Perl detected
) ELSE (
   IF EXIST %perl_path64% (
	SET perl_path=%perl_path64%
	echo Perl64 detected
    ) ELSE (
	ECHO No Perl detected! Please adjust perl_path or download active state perl
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
	ECHO %PROCESS_download% and copy it to C:\Windows!
	start "" %PROCESS_download%
	ECHO .
	SET INSTALL=false
)

:: check if resource kit is installed
WHERE sc >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
	ECHO Windows Resource Toolkit is not installed you may not able to run Webmin as a Service!
	ECHO Please download from %WRT_download% and install it!
	start "" %WRT_download%
	ECHO .
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
    :: install perl module win::daemon if not installed
    IF NOT EXIST %perl_path%\site\lib\Win32\Daemon.pm (
	ppm install Win32-Daemon
    )
    SET perl_path=%perl_path%\bin\perl.exe
    perl %INSTALL% %wa_dir%
) ELSE (
	ECHO Webmin can not installed because of missing  prerequisites!
	ECHO see http://www.webmin.com/windows.html for manual installation instructions
	ECHO .
	ECHO If you are able to improve/fix installation on newer Windows Versions report them pls
)
ECHO .
PAUSE

