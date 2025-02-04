Running Websockify as a Windows service
=======================================

Installation and configuration
------------------------------

Download the following software:

 * Python, from https://www.python.org/downloads/windows/
 * SrvAny, from http://simpleauto.byethost8.com/Zip/SrvAny.zip

Note that there is [a modern alternative for SrvAny](https://github.com/rwmjones/rhsrvany),
but that project does not provide binaries.

Install Python for all users, not just the current one. Extract Websockify
into a directory, e.g. `C:\Program Files\websockify`, so that e.g.
`README.md` ends up there. Extract the `SrvAny.zip` archive, copy the
`WIN7\SrvAny.exe` file into `C:\Program Files\websockify`.

Then create a batch file, `C:\Program Files\websockify\run.bat`, that runs
Websockify from its directory with the correct options under the correct
Python interpreter:

```
C:
cd "\Program Files\websockify"
"C:\Program Files\Python39\python.exe" -m websockify 5901 127.0.0.1:5900
```

Run it by hand once so that Windows asks you about a firewall exception.
After confirming the exception, press `Ctrl+C` to terminate the script.

Then create a Windows service for Websockify (use an Administrator command
prompt for that). For paths with spaces, like in this example, double-escaping
is needed: once for `cmd.exe` and once for `SrvAny.exe`.

```
C:
cd "\Program Files\websockify"
SrvAny.exe -install Websockify 10s \\\"C:\Program Files\websockify\run.bat\\\"
```

In the Windows Control Panel, under Services, a new "Websockify" service will
appear. In its properties dialog, you can change the startup type, e.g. make
it start automatically at boot. Or, you can start the service manually.

Uninstallation
--------------

If you want to remove the service, first set its startup type to Manual, then
reboot the PC. Then run this command using the Administrator command prompt:

```
C:
cd "\Program Files\websockify"
SrvAny.exe -remove Websockify
```

After that, you will be able to remove the `C:\Program Files\websockify`
directory completely.

