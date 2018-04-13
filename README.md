Webmin Version 1.881
--------------------
Webmin is a web-based interface for system administration for Unix. 
Using any browser that supports tables and forms, you can setup user
accounts, Apache, internet services, DNS, file sharing and so on. 

Webmin consists of a simple web server, and a number of CGI programs
which directly update system files like /etc/inetd.conf and /etc/passwd.
The web server and all CGI programs are written in Perl version 5, and use
only the standard perl modules. 

Webmin can be installed in two different ways :

1) By just running the setup.sh script in the same directory as this README
   file, with no arguments. You will be asked a series of questions such as
   the configuration directory, your chosen login name and password, and
   possibly your operating system. For questions where a default is shown
   in square brackets, you can just hit enter to accept the default (which
   is usually correct).

   If the configuration directory you enter is the same as that used by
   a previous install of Webmin, it will be automatically upgraded with all
   configurable settings preserved.

   This will set up Webmin to run directly from this directory. After running
   setup.sh, do not delete the directory as it contains all the scripts and
   programs that will be used by Webmin when it is running. Unlike in the second
   installation method, the Webmin scripts do not get copied to another
   location when installing.

2) By running the setup.sh script in this directory, but with a command-line
   argument such as /usr/local/webmin . When a directory like this is provided,
   Webmin's scripts will be copied to the chosen directory and it will be
   configured to run from that location.

   The exact same questions will be asked by setup.sh when it is run with
   a directory argument, and upgrading will work in the same way. If you
   are upgrading an old install, you should enter the same directory argument
   so that the new files overwrite the old in order to save disk space.

   After Webmin has been installed to a specific directory using this method,
   the directory extracted from the tar.gz file can be safely deleted.

If you are installing Webmin on a Windows system, you must run the command
perl setup.pl instead, as shell scripts will not typically run on a Windows
system. The Windows version depends on several programs and modules that may
not be part of the standard distribution. You will need the process.exe
commmand, the sc.exe command and the Win32::Daemon Perl module.

For more information, see http://www.webmin.com/

For documentation, see http://doxfer.webmin.com/

Jamie Cameron
jcameron@webmin.com


# Maintainers

Our current list of [Maintainers](MAINTAINERS.md).

# Contributors

Webmin exists thanks to [all the people who contribute](https://github.com/webmin/webmin/graphs/contributors).

[How To Contribute](CONTRIBUTING.rst).

<a href="https://github.com/webmin/webmin/graphs/contributors"><img src="https://opencollective.com/webmin/contributors.svg?width=890" /></a>


# Backers

Thank you to all our backers!   [Become a backer](https://opencollective.com/webmin#backer)

<a href="https://opencollective.com/webmin#backers" target="_blank"><img src="https://opencollective.com/webmin/backers.svg?width=890"></a>


# Sponsors

Support Webmin by becoming a sponsor. Your logo will show up here with a link to your website.

[Become A Sponsor of Webmin.](https://opencollective.com/webmin#sponsor)

<a href="https://opencollective.com/webmin/sponsor/0/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/1/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/2/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/3/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/4/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/5/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/6/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/7/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/8/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/webmin/sponsor/9/website" target="_blank"><img src="https://opencollective.com/webmin/sponsor/9/avatar.svg"></a>


