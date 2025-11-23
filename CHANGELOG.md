## Changelog

#### 2.610 (November 23, 2025)
* Fix to drop dependency on `IO::Pty` Perl module
* Fix `virtual-server` module server-side search to work correctly
* Update the Authentic theme to the latest version with various improvements and fixes:
  - Add a range slider to adjust content page margins more precisely
  - Add an option to enable rounded corners for content page
  - Add more customization options for pie charts
  - Fix to increase clickable area for checkboxes in File Manager
  - Fix to correct rotation of pin and unpin button for right side slider
  - Fix color of selected items in the multiselect dropdown
  - Fix to improve the visibility of disabled checkboxes
  - Fix to send saved params in the post body when saving theme configuration
    [More details...](https://github.com/webmin/authentic-theme/releases/tag/26.20)

#### 2.600 (November 9, 2025)
* Add an options to enable the slow query log in the MySQL/MariaDB module [#2560](https://github.com/webmin/webmin/issues/2560)
* Add ability to install multiple PHP extensions at once in the PHP Configuration module
* Add ability to show package URL in the Software Packages module [#1141](https://github.com/virtualmin/virtualmin-gpl/issues/1141)
* Add support to show Debian package install time in the Software Packages module
* Add support to show detailed Webmin server stats using new `webmin stats` CLI command [forum.virtualmin.com/t/135556](https://forum.virtualmin.com/t/is-this-memory-used-a-bit-high/135556/6?u=ilia)
* Add a major Authentic theme UI update with lots of visual and structural improvements for a smoother and more modern experience
[More details...](https://forum.virtualmin.com/t/authentic-theme-version-26-00-release-overview/135755?u=ilia)
* Fix EOL library fatal error for OS in development [#2121](https://github.com/webmin/webmin/issues/2121)
* Fix correctly saving jails with parameters containing quotes in the Fail2Ban module [#2572](https://github.com/webmin/webmin/issues/2572)
* Fix file is always renamed as the effective user in the Upload and Download module [#1054](https://github.com/webmin/webmin/issues/1054)

#### 2.520 (October 4, 2025)
* Fix to make sure the mail URL uses a well-known host name [security]
* Fix support for other Raspberry Pi sensors [#2545](https://github.com/webmin/webmin/issues/2545)
* Fix the printing of the bottom button row in the form column table
* Fix to recommend Perl `Sys::Syslog` module [#2557](https://github.com/webmin/webmin/issues/2557)
* Fix to avoid using short hostname in HTTPS redirects when an FQDN is available
* Fix to use _/proc_ sampler instead of `vmstat` for the same output with much lower overhead
* Fix to query specific fields in FreeBSD memory stats collection, cutting CPU use by 80%
* Fix to kill Webmin subprocesses during RC stop on FreeBSD and other systems
* Fix to correctly fetch command version in `PPTP VPN Client` module [#2567](https://github.com/webmin/webmin/issues/2567)
* Add a complete overhaul of `var_dump` subroutine, which is now fully portable
* Update the Authentic theme to the latest version with various fixes:
  - Fix the text color when reading email in the Read User Mail module [webmin#2555](https://github.com/webmin/webmin/issues/2555)
  - Fix to ensure the selected color palette is correctly stored when changed manually [webmin#2552](https://github.com/webmin/webmin/issues/2552)
  - Fix a bug when the Webmin version label was missing when copying to clipboard system information from the dashboard
  - Fix DNS query spike from network stats collection on FreeBSD [webmin#2556](https://github.com/webmin/webmin/issues/2556)
  - Fix to display the appropriate icon for proxy mode on new Bunny DNS
  - Fix spinner color in toast messages for dark palette
  - Fix other bugs and add various small improvements

#### 2.510 (September 16, 2025)
* Fix to ensure DNSSEC re-signing period is less than 30 days in the BIND DNS module
* Fix to treat 201 as a valid response code in the internal download function
* Update the Authentic theme to the latest version with various improvements and fixes:
  - Add optimizations to dashboard graphs with dynamic trimming to prevent page lagging
  - Add improvements to how the system cache for the dashboard is updated
  - Add support to correctly reload the page in proxy mode
  - Add an option to choose if default page should always load when switching navigation
  - Fix to ensure the color palette is preserved for the user [webmin#2537](https://github.com/webmin/webmin/issues/2537)
  - Fix algorithm for calculating rows per page in data table pagination
  - Fix the alert info box text color for dark mode
  - Fix critical lags and appearance of Custom Commands module 

#### 2.501 (September 10, 2025)
* Add support for Raspberry Pi sensors #2539 #2517
* Add Squid 7 support
* Update the Authentic theme to the latest version with the following fixes:
  - Fix broken editor in "Bootup and Shutdown" module

#### 2.500 (September 4, 2025)
* Add support for the Webmin webserver to work in both HTTP and HTTPS modes at the same time
* Add distinct warning to the login page if the connection is not secure
* Add support for timeouts in temporary rules in "FirewallD" module
* Add support for the new Dovecot version 2.4
* Add support for MariaDB version 12 #2522
* Add support for IMAP through a local command for Usermin
* Add latest SSLeay support for redirects to SSL work
* Add improvements to "Bootup and Shutdown" module for _systemd_ systems
* Add field for secondary server key in "BIND DNS Server" module
* Add reversible encryption helpers API
* Add API to display relative dates
* Add API to mask sensitive text, like displayed passwords, unless hovered over
* Add status monitor for PHP FPM #2499
* Add support for DNF5 format in the "Software Packages" module
* Add support for redirecting to the enforced domain when the `musthost_redirect` directive is set
* Add option to customize the SMTP login for scheduled background monitoring in the "System and Server Status" module
* Change to show relative dates in "Webmin Users: Current Login Sessions" and "Webmin Actions Log: Search Results" pages
* Change "Last Logins" on the dashboard to show usernames, relative dates, and all users from the past 3 days
* Change to always enable HSTS by default
* Fix MySQL/MariaDB to remove obsolete `set-variable` options that break modern config files #2497
* Fix download link in table rows in "MySQL/MariaDB Database Server" module
* Fix module not to fail on old MySQL 5.5
* Update the Authentic theme to the latest version with various improvements and fixes:
  - Add support to automatically set the color palette based on OS or browser preferences
  - Add improvements to tooltips in dark palette
  - Change the default shortcut key for toggling the light/dark palette
  - Change the default shortcut key for toggling right slider
  - Change wording to use "shortcut" instead of "hotkey"
  - Change the default maximum column width
  - Fix navigation menu load in proxy mode #2502
  - Fix navigation menu to always stay in sync with the product switch
  - Fix sporadic issue where the navigation menu disappeared and the content page was shifted
  - Fix info alert text color and button color in the dark palette
  - Fix styling of checkboxes and radios for backup and restore pages in Virtualmin
  - Fix styling for extra backup destinations in Virtualmin
  - Fix advanced schedule display in the cron chooser in Virtualmin
    [More details...](https://github.com/webmin/authentic-theme/releases/tag/25.00)

#### 2.402 (June 16, 2025)
* Update the Authentic theme to the latest version with various fixes and improvements
* Fix support for EL10-based systems

#### 2.401 (June 2, 2025)
* Add forgotten password recovery support for Virtualmin mailbox users
* Add forgotten password recovery support in Usermin
* Fix account lock status check in MySQL/MariaDB module that was blocking new database user creation #2484
* Fix to prevent safe users from sending emails
* Fix to always show password recovery link if enabled

#### 2.400 (May 25, 2025)
* Add built-in support for forgotten password recovery
* Add support for SSL certificates and DNS over TLS in the BIND module
* Add support to configure listen for any type of address in Dovecot module
* Add ability to manage available PHP packages directly from PHP Configuration module
* Add ability to configure and show proper branding logo on the login page
* Add display of the PHP binary and its version in the PHP Configuration module
* Add improvements to MySQL/MariaDB module when editing users and privileges
* Add support for AxoSyslog in System Logs NG module
* Add TOML as editable format in the File Manager module
* Add support for template variables in help pages
* Add support for enabling gender-neutral translations if supported by the language
* Improve security of single-use login links
* Fix to check if local version of `mysqldump` supports `--set-gtid-purged` flag
* Fix to respect option to copy new key and certificate to Webmin in the SSL Encryption module
* Fix to use new API for auxiliary remote QR code generation
* Fix to show human-readable timestamps for kernel log in the System Logs module
* Fix to respect reverse order flag in the System Logs module
* Fix to prefer JSON::XS over JSON::PP if available for better performance
* Fix bugs with IPv6 interface creation on systems using Network Manager
* Fix to address the security issue in the System Documentation module
* Fix to use fast PRC mode by default in the Webmin Servers Index module
* Fix Fail2Ban version detection
* Fix to follow German translation rules that most people already accept
* Fix to correctly read EOL cache data

#### 2.303 (March 14, 2025)
* Fix permissions error when attempting to open a temp file for writing
* Fix Network Configuration module to use `ip` command instead of `ifconfig` on Debian systems
* Fix to correctly save IPv6 nameservers in Network Configuration module
* Fix to run `man` as `nobody` to prevent section param misuse in System Documentation module
* Add support for Sendmail hash files ending with `.cdb`
* Update German translations

#### 2.302 (March 3, 2025)
* Add ability to preserve allow/deny IPs in Webmin Configuration module #2427
* Add enhancements to module config saving to ensure reliability under all conditions
* Fix to improve wording when applying network in Network Configuration module
* Fix regression in MySQL/MariaDB database user permission assignment
* Fix to clean up old code
* Update German translations

#### 2.301 (February 16, 2025)
* Fix to check correctly if ProFTPD is installed #2410
* Fix to properly escape HTML in date fields
* Fix the line height of plain-text email body

#### 2.300 (February 14, 2025)
* Add multiple improvements to SSH Server module to support contemporary systems
* Add support to configure SSH socket activation in SSH Server module in contemporary systems #2356
* Add support for managing PHP extensions in PHP Configuration module
* Add API to edit _systemd_ units in Bootup and Shutdown module
* Add rich-rule and direct-rule API to FirewallD module
* Add support for collecting bandwidth stats on systems with Journald in Bandwidth Monitoring module
* Add support for displaying translations aggregated and separate statistics using language manager script
* Add support for allowing a given IP temporarily or permanently in FirewallD module
* Add support for listing `deb822-style` repos on Debian and derivatives in Software Package Updates module
* Add support for openEuler Linux LTS and Innovation versions  
* Add support for setting up repos on SUSE distros using repo setup script
* Add a status monitor to check if a reboot is required in System and Server Status module
* Add support for displaying CPU and disk data in the latest macOS versions
* Add UI option to control if SSL client certificate provided by proxies can be trusted
* Add ACL option to set the allowed user based on the directory being accessed in File Manager module
* Add ability to resolve compatibility-level conditionals in Postfix module
* Add ability to use zoom window in/out using standard hotkeys in Terminal module
* Add service restart button in MySQL/MariaDB module
* Add DBI and DBD modules to the recommended list
* Fix to check first if delete, rename, paste, and save are allowed for safe user in File Manager
* Fix to stop trusting remote client IP address for Webmin logging unless it's allowed
* Fix to correctly set exit code on success when using force mode in Webmin `set-config` CLI command
* Fix to include zone name in deleted records log message in BIND DNS module
* Fix to ensure _systemd_ custom units are created in the correct directory in Bootup and Shutdown module
* Fix to create correct RC script on FreeBSD systems when Webmin is installed using the setup script
* Fix to improve how permissions are displayed in MySQL/MariaDB module
* Fix to show current hashed password if there is one in MySQL/MariaDB module
* Fix to place editable options at the top of the list in MySQL/MariaDB module #2319
* Fix to correctly quote usernames in `xfs_quota` command in Disk Quotas module
* Fix file locking in global generic file locking function
* Fix to clean up temporary Webmin PID-based lock directories
* Fix to bring back support for limits in last command in Users and Groups module
* Fix Postfix module incorrectly saving config files for some pages
* Fix to support multi-line mappings in Postfix module for virtual maps
* Fix to turn off autorenew for all Webmin-generated Let's Encrypt SSL certificates as renewals are handled internally
* Fix to prefer JSON::XS over JSON::PP if both are installed
* Fix to just lock the DNS zone file instead of the whole domain to prevent potential deadlocks
* Fix SPF record joining to avoid space separation in BIND DNS module
* Fix updating serial number in BIND DNS module
* Fix error message for salt field in BIND DNS module
* Fix for slave zones can now be called secondary in BIND DNS module #2257
* Fix not to save passwords in the password fields in Users and Groups module
* Fix not binding to an IP, add a `Listen` directive for a custom port if needed in Apache module #2341
* Fix Usermin manual installation using setup script
* Fix to enhance display support for Fetchmail module
* Fix WebSocket connections for _sudo_-capable users
* Rename Google Authenticator to just TOTP Authenticator
* Improve sorting for date-based columns in data tables  
* Drop `lynx` package from the recommended list
* Drop `Authen::OATH` module and all its dependencies in favor of a simpler implementation for TOTP authentication
* Updated Chinese translations
* Update German translations

#### 2.202 (August 12, 2024)
* Add support for importing schemas to the LDAP Server module
* Add support for displaying disk and network I/Os in FreeBSD on the dashboard
* Fix to automatically set the WebSocket URL webprefix correctly
* Fix to name downloaded backup file nicely in Backup Configuration Files module [#2239](https://github.com/webmin/webmin/issues/2239)
* Fix to optimize getting table index stats for large tables in MySQL/MariaDB module [pull#2234](https://github.com/webmin/webmin/pull/2234)
* Fix duplication of _systemd_ actions and init scripts [#2227](https://github.com/webmin/webmin/issues/2227)
* Fix BIND service name for Debian 12 and Ubuntu 24.04
* Update the Authentic theme to the latest version with various fixes and improvements

#### 2.201 (July 24, 2024)
* Fix real-time monitoring not updating graphs in the dashboard [#2222](https://github.com/webmin/webmin/issues/2222)
* Fix Terminal module to work correctly with _sudo_-capable users [#2223](https://github.com/webmin/webmin/issues/2223)

#### 2.200 (July 21, 2024)
* Add support for blocking a given IP temporarily or permanently in the FirewallD module
* Add support for parsing iCalendar event files in the Mailbox module
* Add support for tailing logs in real time in System Logs module
* Add ability to preserve original file ACLs when writing files [webmin/authentic-theme#1511](https://github.com/webmin/authentic-theme/discussions/1511#discussioncomment-9913902)
* Add a `patch` sub-command to the `webmin` command for easy application of patches
* Add a config option to display hostname and comment in the DHCP Server module [#2221](https://github.com/webmin/webmin/issues/2221)
* Add support for ED25519 and ED448 algorithms in BIND DNS module for DNSSEC
* Add support for larger ranger of authentication methods in Dovecot module
* Add improved support for displaying last logins in the Users and Groups module
* Fix to prevent duplicate `also-notify` and `allow-transfer` IPs in the BIND DNS module
* Fix issues with Terminal module to correct text display problems in editor mode
* Fix to store Terminal module logs in the `/var/webmin` directory
* Fix to display the Spam folder nicely in the Mailbox module
* Fix how modules are loaded in ProFTPd module
* Fix support for the Chrony service on Debian systems in the System Time module
* Fix to use static routes to set the default gateway in Network Configuration module
* Fix to correctly invalidate EOL cache on re-checks [#2139](https://github.com/webmin/webmin/issues/2139)
* Fix to change default monitor name based on database used MariaDB vs MySQL [#2139](https://github.com/virtualmin/virtualmin-gpl/issues/798)
* Fix to disable manual upgrades for systems installed from the repository
* Fix to preserve Webmin service state during package upgrades [#2133](https://github.com/webmin/webmin/issues/2133)
* Change to enforce _sudo_-capable logins as themselves in the Terminal module [docs/modules/terminal](https://webmin.com/docs/modules/terminal/#about)
* Rename "System Logs" module to "System Logs RS" and "System Logs Viewer" to "System Logs" for clarity

#### 2.111 (April 16, 2024)
* Fix EOL detection for unreleased Linux distributions

#### 2.110 (April 15, 2024)
* Add an API to check if the system is running or approaching its end of life (EOL)
* Add support for `systemd-timesyncd` and `chronyd` to the System Time module
* Add Ubuntu 24.04 support
* Add Squid 6 support
* Add latest Devuan Linux support
* Add an option to request Let's Encrypt certificates using `certbot` in standalone mode [forum.virtualmin.com/t/123696](http://forum.virtualmin.com/t/webmin-ssl-certificate-with-lets-encrypt-directly-obtain-certificate-without-requiring-apache-or-nginx/123696/)
* Add IMAP and SMTP monitors in the System and Server Status module
* Fix TLS connection to SMTP servers not working in some cases
* Fix ProFTPd module to use actual UI library
* Fix to using the `qrencode` command to generate QR codes locally instead of the remote Google Chart API
* Fix a number of various other issues

#### 2.105 (November 09, 2023)
* Fix param to read only headers [sourceforge.net/usermin-bugs#501](https://sourceforge.net/p/webadmin/usermin-bugs/501/)
* Fix not to set `reuse` flag on initial Let's Encrypt request
* Fix to correctly escape mail file names upon deletion
* Fix index field in cache file in BIND DNS module

#### 2.104 (October 16, 2023)
* Add support for numbered and bulleted lists in email HTML editor
* Add ability to display active file locks in `Webmin Configuration ⇾ File Locking` page
* Fix hostname detection on `systemd` systems to avoid excessive logging  [#2020](https://github.com/webmin/webmin/issues/2020)
* Fix Webmin version display [#2023](https://github.com/webmin/webmin/issues/2023)
* Fix to check if UI library is loaded before using it [#2021](https://github.com/webmin/webmin/issues/2021)
* Fix the absent init script for legacy systems after the initial installation
* Update the Authentic theme to the latest version with various fixes and improvements

#### 2.103 (October 08, 2023)
* Add support for hostname detection using `hostnamectl` command
* Add support for other ACME services
* Add ability to hide dotfiles in File Manager [#1578](https://github.com/webmin/authentic-theme/issues/1578)
* Add `xz`, `zstd` and plain `tar` support when creating archives in File Manager [#2009](https://github.com/webmin/webmin/issues/2009)
* Add support for English (United States) (military time) locale
* Fix to correctly switch key hash type with ACME services
* Fix bug when `backend` wasn't saved correctly in Fail2Ban module [#1992](https://github.com/webmin/webmin/issues/1992)
* Fix large files download in Upload and Download module
* Fix Google Authentication on RHEL systems derivatives
* Update the Authentic theme to the latest version with various fixes and improvements

#### 2.102 (August 23, 2023)
* Add support for Amazon Linux 2023
* Fix a bug in Network Configuration module when parsing network size [sourceforge.net/discussion#55377]( https://sourceforge.net/p/webadmin/discussion/55377/thread/78e5aa05f3)
* Fix Netplan related bugs in Network Configuration module
* Fix Terminal focus bug
* Fix to correctly compare Webmin semantic versions
* Fix to suppress output from `monitor.pl` command [#1984](https://github.com/webmin/webmin/issues/1984)

#### 2.101 (August 5, 2023)
* Add support for reading gzipped email messages
* Add `error_stderr` API
* Fix to show correct locale for sudo-capable users [webmin/authentic-theme#1663](https://github.com/webmin/authentic-theme/issues/1663)
* Fix new signing key import on Debian and derivatives
* Fix to check if password hash format is valid for `yescrypt` and `SHA512`
* Fix various XSS related issues
* Fix updating Webmin from repository if a package is available

#### 2.100 (July 22, 2023)
* Add support for showing defaults for options in PHP Configuration module
* Add significant improvements to email display, reply and compose
* Add support for WebGL in the Terminal module
* Add screen reader support in Terminal module
* Add full support for NetworkManager in Network Configuration module
* Fix correctly displaying bridges with Netplan in Network Configuration module
* Fix displaying active network interfaces in Network Configuration module
* Fix to consider current drive temperature in `smartctl` output #1881
* Fix to properly stop Usermin https://github.com/webmin/usermin/issues/89
* Fix no to add hashed password to the old password list if it's already in there https://github.com/virtualmin/virtualmin-pro/issues/35
* Fix displaying placeholder on input to reflect strftime-style format
* Update the Authentic theme to the latest version adding new vertical column layout

#### 2.021 (March 19, 2023)
* Add ability to set locale in Webmin Users module for consistency
* Fix an error when `make_date` is called on undefined value #1860
* Fix clearing packages caches before checking for updates in status collection #1863
* Update the Authentic theme to the latest version

#### 2.020 (March 08, 2023)
* Add full locale support
* Add slave zone file format option in BIND DNS module
* Add support for editing ACLs in File Manager
* Add support to configure SSL connection for MySQL/MariaDB module
* Add support for compressed backups in PostgreSQL module
* Add support for displaying inodes too in Disk Usage in the dashboard
* Add better support for CloudLinux
* Fix to always default to RSA key type in Let's Encrypt requests
* Fix setup repository script for Oracle
* Fix shutdown timeout to avoid termination of running processes
* Fix support for SpamAssassin 4
* Fix to use system default hashing format for `htpasswd` file
* Fix FastRPC issues
* Update the Authentic theme to the latest version, with sped-up dashboard performance

#### 2.013 (January 19, 2023)
* Fix Authentic theme issue with error handling
* Fix Framed theme to respect selected mode in left menu
* Fix search bar in left menu in Framed theme

#### 2.012 (January 18, 2023)
* Fix to set the correct algorithm when setting up RNDC #1817
* Fix the loop bug when sourcing other network configs in Debian
* Fix to include all Debian network config files in backups
* Fix to stop doing expensive package re-fetch on upgrades
* Add support for defining hostname for WebSocket connection
* Add Debian 12 support

#### 2.011 (January 10, 2023)
* Add ability to set shell character encoding and set `TERM` environmental variable in the new Terminal module
* Add support for editing network interfaces in include files for Debian systems
* Add various improvements to the old good Framed Theme
* Fix to change Gray Framed Theme name to Framed Theme
* Fix to verify and close WebSocket session, if parent session was closed
* Fix to remove `RC4` from the list of strong ciphers
* Fix don't fail LDAP user or group deletion, if they have already been deleted
* Fix error handling in MySQL/MariaDB Database server module when executing SQL commands
* Fix adding an extra server attachment field and other bugs in Read User Mail module
* Fix the link to release notes for Rocky Linux
* Fix issues with freezing and thawing dynamic reverse zones in BIND DNS Server module
* Fix bugs for modules granting anonymous access
* Fix `mailbox_idle_check_interval` option related bugs in Dovecot module [sourceforge.net#5602](https://sourceforge.net/p/webadmin/bugs/5602/)
* Fix to use correct extension for package file when upgrading Webmin [webmin/authentic-theme#1633](https://github.com/webmin/authentic-theme/issues/1633)
* Update the Authentic theme to the latest version

#### 2.010 (November 27, 2022)
* Add a new Terminal module (interactive shell)
* Add a new `setup-repos.sh` script to setup Webmin repos
* Add to replace old Gray Theme with Virtualmin Framed Theme
* Add _systemd_ improvements
* Add proper support for openSUSE Leap and Tumbleweed
* Add Linux Lite support
* Fix connecting to external IPv6 LDAP server
* Fix self-signed certificate generation
* Fix setting hostname using `hostnamectl` command on _systemd_ systems
* Fix to exclude sensors with unknown temperatures
* Fix for FreeBSD to support Let's Encrypt certificates requests
* Fix to support attachment filenames with slash in them

#### 2.001 (September 18, 2022)
* Fix missing origins and action for direct rules in FirewallD module
* Removed the need for a full restart when updating SSH keys
* Improved the Javascript for redirects to HTTPS

#### 2.000 (August 21, 2022)
* Add to enforce HTTP Strict Transport Security (HSTS) policy in SSL enabled mode
* Add better `http` to `https` redirects when SSL is enabled
* Add support for installing multiple versions of Webmin on `systemd` systems
* Add support for AMD CPU thermisters #1714
* Add better support for Webmin minor (release) versions upgrades
* Add Webmin and Usermin configuration modules display minor (release) version
* Add Mint Linux support
* Add latest Authentic 20.00 [theme update](https://github.com/webmin/authentic-theme/releases/tag/20.00) with number of bug fixes
* Fix to also restart dependent services (i.e. `fail2ban`) upon `firewalld` restart
* Fix to preserve service state for Webmin and Usermin upon package upgrades (i.e. don't start stopped)
* Fix Bind module config incorrectly updated upon Webmin upgrades on CentOS 7

#### 1.999 (August 4, 2022)
* Fix to allow IPv6 addresses for slaves in BIND module
* Fix to send `HUP` signal on reload with `systemd`
* Fix icons in Servers Index module for newer distros (Alma and Rocky)
* Fix to remove depricated option `UsePrivilegeSeparation` with OpenSSH 7.5+
* Fix Oracle Linux support
* Fix Ubuntu release notes links
* Add Webmin release note message
* Add latest Authentic [theme update](https://github.com/webmin/authentic-theme/releases/tag/19.99) with number of bug fixes

#### 1.998 (July 25, 2022)
* Fix Apache, BIND, MySQL, ProFTPd and other modules configs on newest distros for new installs
* Fix to use Cron default path when run from UI
* Fix post uninstall cleanups
* Fix version detection bug for Log File Rotation module
* Add improvements to Partitions on Local Disks module
* Add better support for CentOS Stream Linux for new installs
* Add improvements for searching and naming global PHP configs files
* Add support for unix extensions option for Samba module https://github.com/webmin/webmin/issues/1695
* Add latest Authentic [theme update](https://github.com/webmin/authentic-theme/releases/tag/19.98) with various bug fixes and small improvements

#### 1.997 (July 12, 2022)
* Add support for mirror and RAID volumes in LVM module
* Add latest Authentic [theme update](https://github.com/webmin/authentic-theme/releases/tag/19.97) with nice new features in File Manager and other fixes
* Fix more issues with restart when Webmin is upgraded from UI

#### 1.996 (July 4, 2022)
* Fix issues with `systemd` restarting Webmin on upgrade found in 1.995

#### 1.995 (June 23, 2022)
  * Add improvements to stability for `systemd` systems
  * Add native support to default to system default hashing format
  * Add support to `yescrypt` password hashing scheme
  * Add new _System Logs Viewer_ (logviewer) module
  * Add new `webmin server` sub-command
  * Add to set environmental variables in Filesystem Backup module
  * Fix upload tracker issues with large uploads
  * Fix NVMe drives status support
  * Fix AlmaLinux support
  * Fix BIND config for FreeBSD 12 on initial setup

#### Version 1.994 (May 22, 2022)
This release fixes a security issue in versions 1.991 and below. All systems with less-privileged Webmin users are recommended to upgrade as soon as possible.

#### Version 1.991 (April 18, 2022)
This is mainly a bugfix release for issues found since 1.990.

#### Version 1.990 (March 3, 2022)
This release contains a critical security fix, an updated theme, and a bunch of other small features and improvements. We recommend that all systems with untrusted Webmin users upgrade immediately!

#### Version 1.983 (December 26, 2021)
This release is mostly bugfixes for issues found in 1.983.

#### Version 1.983 (December 4, 2021)
These releases are mostly bugfixes for issues found in 1.982.

#### Version 1.982 (November 26, 2021)
This release includes the latest Authentic theme, support for archive extraction and folder uploads in the File Manager module, automatic formatting of the Apache config, translation updates, and many more small features and bugfixes.

#### Version 1.981 (August 28, 2021)
This is just a bugfix for issues found in version 1.980.

#### Version 1.980 (August 22, 2021)
This release includes numerous small bugfixes, a theme update, translation fixes, support for Rocky and Alma Linuxes, and a new API for changing password.

#### Version 1.979 (June 15, 2021)
This release fixes several bugs found in 1.974, updates the Authentic theme, adds 2FA support in Usermin, and fixes a security bug in the Network Configuration module.

#### Version 1.974 (May 1, 2021)
Mostly a bugfix release, but it also contains a security for users who installed using the `setup.pl` script (which is not common).

#### Version 1.972 (March 1, 2021)
This is mainly a bugfix release for issues with Let's Encrypt and a few other modules.

#### Version 1.970 (January 6, 2021)
This release updates the theme, fixes a Windows security issue, updates the CA cert for Let's Encrypt, and improves translations.

#### Version 1.962 (November 11, 2020)
These are bugfix releases for 2-factor signin and other small issues.

#### Version 1.960 (October 19, 2020)
This release improves MySQL user management, updates the theme UI, fixes parsing of complex Netplan configs, removes the dependency on apt-show-versions and much much more.

#### Version 1.953 (July 5, 2020)
This release adds automatic translations for all languages in UTF-8, updates the Authentic theme, adds support for Postfix SNI certs and Chrony, caching for LDAP lookups, and a huge number of bugfixes and minor features.

#### Version 1.941 (January 16, 2020)
This release updates the built-in Let's Encrypt client, adds support for creating "safe-mode" Webmin users, support for CAA records in the BIND module, and the ability to search Postfix maps. It also updates the Authentic theme to the latest version, which includes numerous improvements to the File Manager and overall UI.

#### Version 1.930 (August 18, 2019)
These updates fix a [security vulnerability](http://webmin.com/security.html) and should be installed IMMEDIATELY by all users. Although it is not exploitable in a Webmin install with the default configuration, upgrading is strongly recommended.

#### Version 1.920 (July 04, 2019)
This update includes the latest theme version, translation updates, the ability to disable hosts file entries, easier monitoring of bootup actions, and a bunch of bugfixes.

#### Version 1.910 (May 09, 2019)
This release includes theme and translation updates, a page for editing package repositories, cron and status module improvements, and a bunch of other bugfixes and small improvements.

#### Version 1.900 (November 19, 2018)
This version includes wildcard Let's Encrypt SSL cert support, theme and translation updates, support for announcements to Webmin users, and a bunch of other bugfixes and small improvements.

#### Version 1.890 (July 19, 2018)
This version includes Ubuntu 18 network config support, translation updates, multiple theme and file manager updates, BIND freeze/thaw support, support for more Linux distributuions, and a bunch of other bugfixes and small improvements.

#### Version 1.880 (March 16, 2018)
This version includes German, Catalan and Bulgarian translation updates, a new version of the Authentic theme, support for directly editing the MySQL and PostgreSQL config files, Let's Encrypt bugfixes, more control over system status email notifications, and more.

#### Version 1.870 (December 08, 2018)
This release includes many translation updates, fixes for Let's Encrypt support, UI cleanups, and most importantly a new major version of the Authentic theme.

#### Version 1.860 (October 10, 2017)
This release includes Let's Encrypt DNS fixes, Majordomo module improvements, XSS security bugfixes, translation updates, a new version of the theme, and more.

#### Version 1.850 (June 28, 2017)
This release includes Let's Encrypt fixes, Majordomo module improvements, FirewallD forwarding support, translation updates, an update to the Authentic theme, and a bunch of other bugfixes.

#### Version 1.840 (May 08, 2017)
This major release includes a large theme update, XSS security fixes, per-domain SSL cert support, thin-provisioned LVM support, Let's Encrypt improvements, translation updates, and the usual gang of bugfixes. Also available is Usermin 1.710, which contains many of the same updates.

#### Version 1.830 (December 29, 2016)
This is mainly a bugfix release, but also contains some translation updates, the latest version of the Authentic theme, fixes related to Let's Encrypt and LDAP client support, and SElinux and file attribute support in the file manager.

#### Version 1.820 (October 3, 2016)
This updated includes a bunch of bugfixes (particularly in the BIND module), translation updates, the ability to download a MySQL backup, Let's Encrypt improvements, and more.

#### Version 1.810 (August 8, 2016)
This updated includes the latest Authentic theme, a new IPv6 Firewall module for Linux, Webmin actions logging improvements, Let's Encrypt API fixes and a bunch of other small updates and bugfixes.

#### Version 1.800
* German translation updates, thanks to Raymond Vetter.
* Catalan translation updates from Jaume Badiella.
* Bulgarian translations from Grigor Gatchev.
* Added Support for Synology NAS and opkg/ipkg Community Package Manager, Kay Marquardt
* Added Support for configuring spam filtering when amvisd is used, Kay Marquardt


#### Version 1.790
* Added a recent logins section to the System Information page.
* Major rework of majordomo module, Kay Marquardt


#### Version 1.760
* For new installs, switched the location of data files in many modules to /var/webmin instead of /etc/webmin.

#### Version 1.750
* Norwegian updates, thanks to Stein-Aksel Basma.
* Catalan translation updates from Jaume Badiella.
* More German translation updates, thanks to Raymond Vetter.
* Fixed an XSS bug that allowed xmlrpc.cgi to be abused by a malicious link.

#### Version 1.740
* Norwegian updates, thanks to Stein-Aksel Basma.
* Catalan translation updates from Jaume Badiella.
* More German translation updates, thanks to Raymond Vetter.

#### Version 1.730
* More German translation updates, thanks to Raymond Vetter.
* Norwegian updates, thanks to Stein-Aksel Basma.
* The awesome new Authentic Theme by @iliajie is now included in the Webmin package.
* Catalan translation updates from Jaume Badiella.

#### Version 1.720
* Deprecated the old blue-theme in favor of the new gray-theme.
* Catalan translation updates from Jaume Badiella.
* More German translation updates, thanks to Raymond Vetter.

#### Version 1.710
* SSL v2 and v3 are now disabled by default at Webmin install time, to block the POODLE attack. They can be re-enabled on the SSL Encryption page of the Webmin Configuration module.

#### Version 1.700
* More German translation updates, thanks to Raymond Vetter.
* Catalan updates, thanks to Jaume Badiella.
* Added additional protected against Shellshock exploits made via the Webmin webserver.

#### Version 1.690
* More German translation updates, thanks to Raymond Vetter.
* Support for RHEL 7, CentOS 7 and other derivatives in multiple modules.

#### Version 1.670
* More German translation updates, thanks to Raymond Vetter.
* Norwegian updates, thanks to Stein-Aksel Basma.
* Catalan updates, thanks to Jaume Badiella.
* Security fixes for XSS attacks in `user_chooser.cgi` and other scripts.

#### Version 1.660
* More German translation updates, thanks to Raymond Vetter.
* Norwegian updates, thanks to Stein-Aksel Basma.
* Catalan updates, thanks to Jaume Badiella.
* IPv6 access control now match an address exactly, unless a network size is entered.
* FTP uploads and downloads to IPv6-only servers now work properly, thanks to support for the EPSV protocol command.
* Added a Bahasa Malaysia translation, thanks to Nawawi Jamili, Nizam Adnan and Weldan Jamili.
* Added filtering for lists in the user, group and file chooser popups, thanks to a patch from Nawawi Jamili.

#### Version 1.650
* More German translation updates, thanks to Raymond Vetter.
* Norwegian updates, thanks to Stein-Aksel Basma.

#### Version 1.620
* More German translation updates, thanks to Raymond Vetter.
* Polish translation updates from Piotr Kozica.
* Norwegian updates, thanks to Stein-Aksel Basma.
* Improved FreeBSD 8 and 9 support across multiple modules.
* Hungarian translation updates from Balázs Zoltán.

#### Version 1.610
* Norwegian updates, thanks to Stein-Aksel Basma.
* Catalan updates, thanks to Jaume Badiella.
* Yet more German translation updates, thanks to Raymond Vetter.
* Polish translation updates from Piotr Kozica.

#### Version 1.600
* Even more German translation updates, thanks to Raymond Vetter.
* Catalan updates, thanks to Jaume Badiella.

#### Version 1.590
* Even more German translation updates, thanks to Raymond Vetter.
* Norwegian updates, thanks to Stein-Aksel Basma.
* Dutch translation updates, thanks to Gandyman.
* Switch order of command and mode in debug logs to make it clear that "mode=X" is part of the log, not part of the command.
* Added the new Gray Framed Theme, and made it the default for new installs.

#### Version 1.580
* Even more German translation updates, thanks to Raymond Vetter.
* More Dutch updates, thanks to Gandyman.
* Catalan updates, thanks to Jaume Badiella.
* Norwegian updates, thanks to Stein-Aksel Basma.
* All languages now have UTF-8 encoded variants, as well as their native character sets.
* Added support for Ubuntu 12.04.

#### Version 1.570
* Even more German translation updates, thanks to Raymond Vetter.
* Added UTF-8 encodings for languages using the iso-8859-2, like Czech and Polish.
* Catalan updates, thanks to Jaume Badiella.
* Norwegian translation updates, thanks to Stein-Aksel Basma.
* The MySQL, PostgreSQL, Filesystem Backup and Backup Configuration Files modules now all support the use of Webmin variable substitutions in backup paths (like $HOSTNAME) via a new Module Config option.

#### Version 1.560
* More German translation updates, thanks to Raymond Vetter.
* More French translation updates, thanks to ButterflyOfFire.

#### Version 1.550
* Catalan updates, thanks to Jaume Badiella.
* Italian translation updates, thanks to Andrea Oliveri.
* Major German translation updates, thanks to Raymond Vetter.

#### Version 1.530
* Speed up the loading of language files by pre-caching them in memory when Webmin is started, and not performing sub-string substitutions in most modules.
* Added support for Pardus Linux, thanks to Kaan Ozdincer.
* Major Dutch updates, thanks to Gandyman.
* Majoe French translation update, thanks to ButterflyOfFire.
* Allow per-language language overrides to be defined, in custom-lang.$code files.
* Updated numerous modules to improve support for Debian 6 and Ubuntu 10.10.
* If a browser asks for gzip compression, Webmin can now return compressed content either generated dynamically or from a pre-compressed .gz file in the same directory. Dynamic compression depends on the Compress::Zlib perl module.
* Added support for Amazon Linux.

#### Version 1.520
* Catalan translation updates by Jaume Badiella.

#### Version 1.510
* Dutch translation updates, thanks to Gandyman.
* Polish translation updates, thanks to Dariusz Dêbowski.

#### Version 1.500
* Czech translation updates, thanks to Karel Hudan.
* The Webmin RPM now preserves the /etc/webmin directory when un-installed and then re-installed.
* Added a robots.txt file to block indexing of Webmin by search engines.
* The Webmin search box can now be disabled in the Webmin Users module, under "Permissions for all modules".
* Brazillian Portuguese translation updates for several modules, thanks to Djavan Fagundes.

#### Version 1.480
* Catalan translation updates by Jaume Badiella.
* Dutch translation updates, thanks to Gandyman.
* Beginnings of a Basque translation, thanks to Mireia Lezea.

#### Version 1.470
* Catalan translation updates by Jaume Badiella.
* Added an UTF-8 encoding of the Russian translation, thanks to shavlukov@gmail.com.
* French translation updates by ButterflyOfFire.
* Dutch translation updates by Gandyman.
* Dramatically improved Webmin's search function, to include links to pages that help or UI text comes from. Also changed the layout of results to a more Webmin-ish style.

#### Version 1.450
* Added a language option for UK english, and converted words in the default Webmin language to US english.
* Major Dutch translation updates, thanks to Gandyman.
* Catalan translation updates by Jaume Badiella.
* Converted all core modules to use the new WebminCore perl module instead of `web-lib.pl`. This significantly improves memory use and load time in code that uses functions from multiple modules, asssuming they have all been converted.

#### Version 1.440
* Russian translation updates, thanks to Anton Statutov.
* Webmin's serialization functions can now handle objects, which allows them to be passed as parameters to remote function calls. Both caller and recipient must have the object's class installed though.
* Converted commands in the core `web-lib-funcs.pl` API file to POD format, and added more details about each function.

#### Version 1.430
* A large Croatian translation update, thanks to Domagoj Bikic.
* When a user whose password is close to expiry or has already expired logs in, a warning will be displayed on Webmin's first page.
* Many Japanese translation updates, thanks to Kazuya Masuda.

#### Version 1.420
* Many Greek translation updates, thanks to Vagelis Koutsomitros.
* Catalan translation updates by Jaume Badiella.
* Many Dutch translation contributions by Gandyman.

#### Version 1.410
* Many Korean updates, thanks to JoungKyun Kim.
* More Dutch updates, thanks to Gandyman.
* Added a debugging log file, which records all files read and written, commands run and more. This can be enabled in the Webmin Configuration module.

#### Version 1.400
* Big Czech translation updates, thanks to Petr Vanek and the Czech translation team.
* All popups in Webmin are now XSS-safe, and thus do not need protection from unknown referers which prevented them from working in some browsers.
* All Webmin session IDs are now stored MD5 hashed, to prevent sessions from being captured if the sessiondb DBM is somehow read by an attacker.
* Many Dutch updates, thanks to Gandyman.
* MD5 encryption for Webmin and Unix passwords can be used on systems that have either the MD5 or Digest::MD5 perl module, or support it in the crypt() function.

#### Version 1.390
* Links from unknown referers are now blocked by default, to prevent XSS attacks. This may break browsers that don't supply a Referer: HTTP header.

#### Version 1.380
* Added a search box to the left frame of the blue theme, for finding modules, config options, help pages and text.
* All images, CSS and other static content served by Webmin has an HTTP Expires for 1 week in the future, to improve cachability.
* Lock files are automatically removed when the process creating them exits.
* NetBSD 4.0 support.
* Italian and Catalan translations contributed for many modules, thanks to Giovanni and Jaume Badiella.
* Changed the error message that appears when Webmin detects a link from another web page, and removed the button to allow the link (which was unreliable anyway).

#### Version 1.370
* Hid the Jabber and Security Sentries modules by default, as the underlying software is no longer supported.
* On Linux systems, sped up the function for finding processes so that it no longer has to launch 'ps' - instead, it reads /proc directly.
* When `read_file_lines` is used to read a file, the Unix or Windows newlines will be preserved when it is written out.

#### Version 1.340
* Added Redhat Enterprise release 5 support.
* Requests to the /unauthenticated URL can never execute CGI programs, to provide an extra layer of security against URL escaping attacks.
* Fixed XSS bugs in `pam_login.cgi`.

#### Version 1.330
* Added more `ui-lib.pl` functions for hidden page sections.
* Fixed another XSS bug in chooser.cgi.
* The Webmin function to get the system's hostname now reads a file instead of calling the hostname comment, which is faster.
* Added an ACL option to the file chooser for additional directories to allow access to.
* Changed the way sizes are displayed, to use a format like 1.32 GB or 8 kB.
* Removed letter images (used by the old theme), and forced the standard header function to always use text titles.
* Added support for Slam64 Linux.

#### Version 1.320
* Fixed XSS bugs in chooser.cgi.
* If the operating system is upgraded after Webmin is installed, a button is displayed on the main page to update Webmin's view of the current OS.
* Improved the tabs API to add an option to put a box around the visible tab, and whitespace around tabs.
* If listening on all specified IP addresses fails, Webmin will fall back to accepting connections on any address.
* All Module Config pages are now generating using new `ui-lib.pl` code, for easier theming.
* Added a global access control option to set the Unix user the file browser lists directories as.

#### Version 1.310
* Module configuration files can now be named based on the real operating system types, such as config-Ubuntu-Linux, which would be used in preference to config-debian-linux.
* When a large file is uploaded, it is no longer read into memory by `miniserv.pl`.
* Update the code that fetches mirror sites from Sourceforge, to handle their new website design.
* Changed the default theme for all installs to the new framed blue theme.
* Updated all rows of links (like select all, invert selection, add something) above tables to use a separator between links.
* Added caching for sudo capable user checks, to avoid excessive slow calls to sudo.
* Fixed a memory leak when running under ActiveState Perl on Windows.

#### Version 1.300
* Fixed the rare bug about renaming the .webmintmp file.

#### Version 1.290
* SELinux security contexts are preserved on files safely modified by Webmin's write-and-rename code.
* Added xmlrpc.cgi program, which provides an XML-RPC interface to all Webmin module functions.
* Tested and improved support for Fedora 5.

#### Version 1.280
* Fixed security holes that allow remote read access to any file on the server for which the path is known.

#### Version 1.270
* Updated almost all modules that use tables to use the new `ui_columns` functions. This allows themes to do highlighting when a row is moved over or selected.
* Added a new 'Simple Blue' theme, which uses fewer images and does table row highlighting.
* Changed the way that Webmin log diff files are stored, so that they are categorized by action and not all in one huge directory.

#### Version 1.260
* Proxy settings made in the Webmin Configuration module are passed on to programs Webmin calls via the `http_proxy` and `ftp_proxy` environment variables.
* Added automatically created UTF-8 translations for simplified and traditional Chinese.

#### Version 1.240
* Fixed a possible security hole caused by a bug in Perl.

#### Version 1.230
* Replaced all calls to the crypt() function with new code that will use the Crypt::UnixCrypt Perl modules on systems for with crypt() is broken.

#### Version 1.220
* Added basic support for running Webmin on Windows system with ActiveState Perl installed. The new `setup.pl` install script must be used, as the setup.sh shell script cannot run on Windows.
* Fixed a bug that could allow a remote attack if the option to use full PAM conversations is enabled.
* Improved the Webmin RPM to not lose the /etc/webmin directory when upgrading from an RPM by another vendor (like Mandrake or DAG).

#### Version 1.210
* Added a new Global ACL control option to limit a user to read-only mode. This does not yet support all modules, but in those that are supported any changes the user makes will simply not take effect.
* Restarting of Webmin is now much faster in some modules that do not need a full configuration reload, due to the addition of a function that justs tells `miniserv.pl` to re-read its config file.

#### Version 1.200
* On Solaris systems that support RBAC, available modules and access rights can now be derived from RBAC for selected users. This can be enabled on a per-user or per-module basic in the Webmin Users module.

#### Version 1.180
* All subheadings have been reduced in size when using the default MSC theme.
* All modules now use a new API for writing to configuration files, which ensures that the file does not get written to or truncated if the system is out of disk space.

#### Version 1.170
* When installing a module from the command line, by it will be granted to the same users who receive new modules when Webmin is upgraded. By default, this is root and admin.
* Added basic support for multiple root directories, so that Webmin modules can be separated into core and third-party on the filesystem.
* When installing or upgrading Webmin, password timeouts are now enabled by default. This protects against brute-force password guessing attacks.

#### Version 1.160
* Added support for Solaris 10.
* Included several additional translations for various languages and modules.
* Added support for config- files that allow a range of OS version numbers, and used this to reduce the number of standard config files.

#### Version 1.150
* Updated the setup.sh script to use MD5 password encryption by default, on systems where Perl supports it.
* Fixed a security hole in the `maketemp.pl` script, used to create the /tmp/.webmin directory at install time. If an un-trusted user creates this directory before Webmin is installed, he could create in it a symbolic link pointing to a critical file on the system, which would be overwritten when Webmin writes to the link filename (CVE bug CAN-2004-0559).
* When PAM is used for Unix authentication, expired passwords are now detected and the user is prompted to select a new password (if this feature is enabled on the Webmin Configuration module).
* Make all functions in `ui-lib.pl` themable, allowing themes to have more detailed control over modules that make use of this library.
* Updated all modules to call `ui_print_header` instead of calling header and printing `<hr>`, so that themes can avoid the `<hr>`. Also updated the MSC theme to do this.

#### Version 1.140
* Fixed a security hole that allowed any user to view the configuration of any module, even those that they should not have access to.
* Fixed a security hole that could allow an attacker to lock valid users by sending a bogus username or password.

