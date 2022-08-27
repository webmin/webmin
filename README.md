[![Dependency](https://img.shields.io/librariesio/github/webmin/webmin)](https://libraries.io/github/webmin/webmin)
[![Packages versions](https://repology.org/badge/latest-versions/webmin.svg)](https://repology.org/metapackage/webmin/versions)
[![Packages](https://repology.org/badge/tiny-repos/webmin.svg)](https://repology.org/metapackage/webmin/versions)

## Contents
* [Changelog](https://github.com/webmin/webmin/blob/master/CHANGELOG.md)
* [About](#about)
* [Installation](#installation)[<img src="https://github.com/webmin-devel/webmin/blob/master/media/download-23x14-stable.png?raw=true" title="Stable Versions">](https://webmin.com/download.html)[<img src="https://github.com/webmin-devel/webmin/blob/master/media/download-23x14-devel.png?raw=true" title="Development Versions">](https://webmin.com/devel.html)
* [Documentation](#documentation)
* [Development](#development)
* [License](#license)

* [中文版](https://github.com/webmin/webmin/blob/master/README-zh.md)

## About

**Webmin** is a web-based system administration tool for Unix-like servers, and services with over _1,000,000_ installations worldwide. Using it, it is possible to configure operating system internals, such as users, disk quotas, services or configuration files, as well as modify, and control open-source apps, such as BIND DNS Server, Apache HTTP Server, PHP, MySQL, and [many more](https://doxfer.webmin.com/Webmin/Introduction). 

[![Quick UI overview 2021](https://user-images.githubusercontent.com/4426533/114315375-61a1c480-9b07-11eb-9aaf-4aa949a39ab7.png)](https://www.youtube.com/watch?v=daYG6O4AsEw)

Usability can be expanded by installing modules, which can be custom made. Aside from this, there are two other major projects that extend its functionality:

* [Virtualmin](https://www.virtualmin.com) is a powerful, flexible, most popular, and most comprehensive web-hosting control panel for Linux, and BSD systems, with over _150,000_ installations worldwide. It is available in an open-source community-supported version, and a more feature-filled version with premium support;
* [Usermin](https://github.com/webmin/usermin) presents and controls a subset of user-centred features, rather than administrator-level tasks.

Webmin includes _116_ [standard modules](https://doxfer.webmin.com/Webmin/Webmin_Modules), and there are at least as many third-party modules.


### Requirements
Perl 5.10 or higher.

## Installation
Webmin can be installed in two different ways:

 1. By downloading a pre-built package, available for different distributions (CentOS, Fedora, SuSE, Mandriva, Debian, Ubuntu, Solaris and [other](https://www.webmin.com/support.html)) under [latest release assets](https://github.com/webmin/webmin/releases/latest) or from our [download page](https://webmin.com/download.html);
  <kbd>Note: It is highly recommended to [add repository](https://doxfer.webmin.com/Webmin/Installation) to your system for having automatic updates.</kbd>

 2. By downloading, extracting [source file](https://prdownloads.sourceforge.net/webadmin/webmin-2.000.tar.gz), and running [_setup.sh_](https://www.webmin.com/tgz.html) script, with no arguments, which will setup to run it directly from this directory, or with a command-line argument, such as targeted directory.
  <kbd>Note: If you are installing Webmin [on Windows](https://www.webmin.com/windows.html) system, you must run the command `perl setup.pl` instead. The Windows version depends on several programs, and modules that may not be part of the standard distribution. You will need _process.exe_ command, _sc.exe_ command, and _Win32::Daemon_ Perl module.</kbd>

## Documentation
Complete set of documentation for Webmin and all of its modules can be found at out [Wiki page](https://doxfer.webmin.com/Webmin/Main_Page).

## Development

### Lead developer

* [Jamie Cameron](https://www.webmin.com/about.html) [![](https://github.com/webmin-devel/webmin/blob/master/media/linkedin-15x15.png?raw=true)](https://www.linkedin.com/in/jamiecameron2)

### Developers
* [Ilia Rostovtsev](https://github.com/iliajie)
* [Joe Cooper](https://github.com/swelljoe)

### Contributors
* [Kay Marquardt](https://github.com/gnadelwartz)
* [Nawawi Jamili](https://github.com/nawawi)
* [unknown10777](https://github.com/unknown10777) + [90 more..](https://github.com/webmin/webmin/graphs/contributors)

## License

Webmin is released under the [BSD License](https://github.com/webmin/webmin/blob/master/LICENCE).
