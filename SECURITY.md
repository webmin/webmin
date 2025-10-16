
> [!WARNING]
> **Found a bug?** If you’ve found a new security-related issue, email
> [security@webmin.com](mailto:security@webmin.com).

### Webmin 2.510 and below [October 9, 2025]
#### Host header injection vulnerability in the password reset feature [CVE-2025-61541]

- If the password reset feature is enabled, an attacker can use a specially
  crafted host header to cause the password reset email to contain a link to a
  malicious site.

  > Thanks to Nyein Chan Aung and Mg Demon for reporting this.

### Webmin 2.202 and below [February 26, 2025]
#### SSL certificates from clients may be trusted unexpectedly

- If Webmin is configured to trust remote IP addresses provided by a proxy *and*
  you have users authenticating using client SSL certificates, a browser
  connecting directly (not via the proxy) can provide a forged header to fake
  the client certificate.

- Upgrade to Webmin 2.301 or later, and if there is any chance of direct
  requests by clients disable this at **Webmin ⇾ Webmin Configuration ⇾ IP
  Access Control** page using **Trust level for proxy headers** option.

  > Thanks to Keigo YAMAZAKI from LAC Co., Ltd. for reporting this.

### Webmin 2.105 and below [April 15, 2024]
#### Privilege escalation by non-root users [CVE-2024-12828]

- A less-privileged Webmin user can execute commands as root via a vulnerability in the shell autocomplete feature.

- All Virtualmin admins and Webmin admins who have created additional accounts should upgrade to version 2.111 as soon as possible!

  > Thanks to Trend Micro’s Zero Day Initiative for finding and reporting this issue.

### Webmin 1.995 and Usermin 1.850 and below [June 30, 2022]
#### XSS vulnerability in the HTTP Tunnel module

- If a less-privileged Webmin user is given permission to edit the configuration of the HTTP Tunnel module, he/she could use this to introduce a vulnerability that captures cookies belonging to other Webmin users that use the module.

  > Thanks to [BLACK MENACE][2] and [PYBRO][3] for reporting this issue.

- An HTML email crafted by an attacker could capture browser cookies when opened.

  > Thanks to [ly1g3][4] for reporting this bug.

### Webmin 1.991 and below [April 18, 2022]
#### Privilege escalation exploit [CVE-2022-30708]
- Less privileged Webmin users (excluding those created by Virtualmin and Cloudmin) can modify arbitrary files with root privileges, and so run commands as root. All systems with additional untrusted Webmin users should upgrade immediately.

  > Thanks to [esp0xdeadbeef][5] and [V1s3r1on][6] for finding and reporting this issue!

### Webmin 1.984 and below [December 26, 2021]
#### File Manager privilege exploit [CVE-2022-0824 and CVE-2022-0829]

- Less privileged Webmin users who do not have any File Manager module restrictions configured can access files with root privileges, if using the default Authentic theme. All systems with additional untrusted Webmin users should upgrade immediately. Note that Virtualmin systems are not effected by this bug, due to the way domain owner Webmin users are configured.

  > Thanks to Faisal Fs ([faisalfs10x][7]) from [NetbyteSEC][8] for finding and reporting this issue!

### Virtualmin Procmail wrapper version 1.0
#### Privilege escalation exploit
- Version 1.0 of the `procmail-wrapper` package installed with Virtualmin has a vulnerability that can be used by anyone with SSH access to gain `root` privileges. To prevent this, all Virtualmin users should upgrade to version 1.1 or later immediately.

### Webmin 1.973 and below [March 7, 2021]
#### XSS vulnerabilities if Webmin is installed using the `setup.pl` script [CVE-2021-31760, CVE-2021-31761 and CVE-2021-31762]

- If Webmin is installed using the non-recommended `setup.pl` script, checking for unknown referers is not enabled by default. This opens the system up to XSS and CSRF attacks using malicious links. Fortunately the standard `rpm`, `deb`, `pkg` and `tar` packages do not use this script and so are not vulnerable. If you did install using the `setup.pl` script, the vulnerability can be fixed by adding the line `referers_none=1` to `/etc/webmin/config` file.

 > Thanks to Meshal ( Mesh3l\_911 ) [@Mesh3l\_911][9] and Mohammed ( Z0ldyck ) [@electronicbots][10] for finding and reporting this issue!

### Webmin 1.941 and below [January 16, 2020]
#### XSS vulnerability in the Command Shell module [CVE-2020-8820 and CVE-2020-8821]

- A user with privileges to create custom commands could exploit other users via unescaped HTML.

 > Thanks to Mauro Caseres for reporting this and the following issue.

### Webmin 1.941 and below [January 16, 2020]
#### XSS vulnerability in the Read Mail module [CVE-2020-12670]
- Saving a malicious HTML attachment could trigger and XSS vulnerability.

### Webmin 1.882 to 1.921 [July 6, 2019]
#### Remote Command Execution [CVE-2019-15231]
- Webmin releases between these versions contain a vulnerability that allows remote command execution! Version 1.890 is vulnerable in a default install and should be upgraded immediately - other versions are only vulnerable if changing of expired passwords is enabled, which is not the case by default.

  Either way, upgrading to version 1.930 is strongly recommended. Alternately, if running versions 1.900 to 1.920, edit `/etc/webmin/miniserv.conf`, remove the `passwd_mode=` line, then run `/etc/webmin/restart` command.
{{< details-start post-indent-details "More details.."  >}}
    Webmin version 1.890 was released with a backdoor that could allow anyone with knowledge of it to execute commands as root. Versions 1.900 to 1.920 also contained a backdoor using similar code, but it was not exploitable in a default Webmin install. Only if the admin had enabled the feature at **Webmin ⇾ Webmin Configuration ⇾ Authentication** to allow changing of expired passwords could it be used by an attacker.

    Neither of these were accidental bugs - rather, the Webmin source code had been maliciously modified to add a non-obvious vulnerability. It appears that this happened as follows :

    - At some time in April 2018, the Webmin development build server was exploited and a vulnerability added to the `password_change.cgi` script. Because the timestamp on the file was set back, it did not show up in any Git diffs. This was included in the Webmin 1.890 release.
    - The vulnerable file was reverted to the checked-in version from GitHub, but sometime in July 2018 the file was modified again by the attacker. However, this time the exploit was added to code that is only executed if changing of expired passwords is enabled. This was included in the Webmin 1.900 release.
    - On September 10th 2018, the vulnerable build server was decommissioned and replaced with a newly installed server running CentOS 7. However, the build directory containing the modified file was copied across from backups made on the original server.
    - On August 17th 2019, we were informed that a 0-day exploit that made use of the vulnerability had been released. In response, the exploit code was removed and Webmin version 1.930 created and released to all users.

    In order to prevent similar attacks in future, we're doing the following :

    - Updating the build process to use only checked-in code from GitHub, rather than a local directory that is kept in sync.
    - Rotated all passwords and keys accessible from the old build system.
    - Auditing all GitHub commits over the past year to look for commits that may have introduced similar vulnerabilities.
{{< details-end >}}

### Webmin 1.900 [November 19, 2018]
#### Remote Command Execution (Metasploit)

- This is _not_ a workable exploit as it requires that the attacker already know the root password. Hence there is no fix for it in Webmin.

### Webmin 1.900 and below [November 19, 2018]
#### Malicious HTTP headers in downloaded URLs

 - If the Upload and Download or File Manager module is used to fetch an un-trusted URL. If a Webmin user downloads a file from a malicious URL, HTTP headers returned can be used exploit an XSS vulnerability.

 > Thanks to independent security researcher, John Page aka hyp3rlinx, who reported this vulnerability to Beyond Security's SecuriTeam Secure Disclosure program.

### Webmin 1.800 and below [May 26, 2016]
#### Authentic theme configuration page vulnerability
 - Only an issue if your system has un-trusted users with Webmin access and is using the new Authentic theme. A non-root Webmin user could use the theme configuration page to execute commands as root.

#### Authentic theme remote access vulnerability
 - Only if the Authentic theme is enabled globally. An attacker could execute commands remotely as root, as long as there was no firewall blocking access to Webmin's port 10000.

### Webmin 1.750 and below [May 12, 2015]
#### XSS (cross-site scripting) vulnerability in `xmlrpc.cgi` script [CVE-2015-1990]
 - A malicious website could create links or JavaScript referencing the `xmlrpc.cgi` script, triggered when a user logged into Webmin visits the attacking site.

 > Thanks to Peter Allor from IBM for finding and reporting this issue.

### Webmin 1.720 and below [November 24, 2014]
#### Read Mail module vulnerable to malicious links
 - If un-trusted users have both SSH access and the ability to use Read User Mail module (as is the case for Virtualmin domain owners), a malicious link could be created to allow reading any file on the system, even those owned by _root_.

 > Thanks to Patrick William from RACK911 labs for finding this bug.

### Webmin 1.700 and below [August 11, 2014]
#### Shellshock vulnerability
 - If your _bash_ shell is vulnerable to _shellshock_, it can be exploited by attackers who have a Webmin login to run arbitrary commands as _root_. Updating to version 1.710 (or updating _bash_) will fix this issue.

### Webmin 1.590 and below [June 30, 2012]
#### XSS (cross-site scripting) security hole
 - A malicious website could create links or JavaScript referencing the File Manager module that allowed execution of arbitrary commands via Webmin when the website is viewed by the victim. See [CERT vulnerability note VU#788478][12] for more details. Thanks to Jared Allar from the American Information Security Group for reporting this problem.

#### Referer checks don't include port
- If an attacker has control over `http://example.com/` then he/she could create a page with malicious JavaScript that could take over a Webmin session at `https://example.com:10000/` when `http://example.com/` is viewed by the victim.

 > Thanks to Marcin Teodorczyk for finding this issue.

### Webmin 1.540 and below [April 20, 2011]
#### XSS (cross-site scripting) security hole
 - This vulnerability can be triggered if an attacker changes his Unix username via a tool like `chfn`, and a page listing usernames is then viewed by the root user in Webmin.

 > Thanks to Javier Bassi for reporting this bug.

### Virtualmin 3.70 and below [June 23, 2009]
#### Unsafe file writes in Virtualmin
 - This bug allows a virtual server owner to read or write to arbitrary files on the system by creating malicious symbolic links and then having Virtualmin perform operations on those links. Upgrading to version 3.70 is strongly recommended if your system has un-trusted domain owners.

### Webmin 1.390 and below, Usermin 1.320 and below [February 8, 2008]
#### XSS (cross-site scripting) security hole
 - This attack could open users who visit un-trusted websites while having Webmin open in the same browser up to having their session cookie captured, which could then allow an attacker to login to Webmin without a password. The quick fix is to go to the **Webmin Configuration** module, click on the **Trusted Referers** icon, set **Referrer checking enabled?** to **Yes**, and un-check the box **Trust links from unknown referrers**. Webmin 1.400 and Usermin 1.330 will make these settings the defaults.

### Webmin 1.380 and below [November 3, 2007]
#### Windows-only command execution bug
 - Any user logged into Webmin can execute any command using special URL parameters. This could be used by less-privileged Webmin users to raise their level of access.
 
 > Thanks for Keigo Yamazaki of Little eArth Corporation for finding this bug.

### Webmin 1.374 and below, Usermin 1.277 and below
#### XSS bug in `pam_login.cgi` script
 - A malicious link to Webmin `pam_login.cgi` script can be used to execute JavaScript within the Webmin server context, and perhaps steal session cookies.

### Webmin 1.330 and below, Usermin 1.260 and below
#### XSS bug in `chooser.cgi` script
 - When using Webmin or Usermin to browse files on a system that were created by an attacker, a specially crafted filename could be used to inject arbitrary JavaScript into the browser.

### Webmin 1.296 and below, Usermin 1.226 and below
#### Remote source code access
- An attacker can view the source code of Webmin CGI and Perl programs using a specially crafted URL. Because the source code for Webmin is freely available, this issue should only be of concern to sites that have custom modules for which they want the source to remain hidden.
#### XSS bug
- The XSS bug makes use of a similar technique to craft a URL that can allow arbitrary JavaScript to be executed in the user's browser if a malicious link is clicked on.
 
 > Thanks for Keigo Yamazaki of Little eArth Corporation for finding this bug.

### Webmin 1.290 and below, Usermin 1.220 and below
#### Arbitrary remote file access
 - An attacker without a login to Webmin can read the contents of any file on the server using a specially crafted URL. All users should upgrade to version 1.290 as soon as possible, or setup IP access control in Webmin.
 
 > Thanks to Kenny Chen for bringing this to my attention.

### Webmin 1.280 and below
#### Windows arbitrary file access
 - If running Webmin on Windows, an attacker can remotely view the contents of any file on your system using a specially crafted URL. This does not affect other operating systems, but if you use Webmin on Windows you should upgrade to version 1.280 or later.
 
 > Thanks to Keigo Yamazaki of Little eArth Corporation for discovering this bug.

### Webmin 1.250 and below, Usermin 1.180 and below
#### Perl syslog input attack
 - When logging of failing login attempts via `syslog` is enabled, an attacker can crash and possibly take over the Webmin webserver, due to un-checked input being passed to Perl's `syslog` function. Upgrading to the latest release of Webmin is recommended.
 
 > Thanks to Jack at Dyad Security for reporting this problem to me.

### Webmin 1.220 and below, Usermin 1.150 and below
#### Full PAM conversations' mode remote attack
 - Affects systems when the option **Support full PAM conversations?** is enabled on the **Webmin ⇾ Webmin Configuration ⇾ Authentication** page. When this option is enabled in Webmin or Usermin, an attacker can gain remote access to Webmin without needing to supply a valid login or password. Fortunately this option is not enabled by default and is rarely used unless you have a PAM setup that requires more than just a username and password, but upgrading is advised anyway. <br />
 
 > Thanks to Keigo Yamazaki of Little eArth Corporation and [JPCERT/CC][13] for discovering and notifying me of this bug.

### Webmin 1.175 and below, Usermin 1.104 and below
#### Brute force password guessing attack
 - Prior Webmin and Usermin versions do not have password timeouts turned on by default, so an attacker can try every possible password for the _root_ or admin user until he/she finds the correct one.  
The solution is to enable password timeouts, so that repeated attempts to login as the same user will become progressively slower. This can be done by following these steps :

    * Go to the **Webmin Configuration** module.
    * Click on the **Authentication** icon.
    * Select the **Enable password timeouts** button.
    * Click the **Save** button at the bottom of the page.
 
   This problem is also present in Usermin, and can be prevented by following the same steps in the **Usermin Configuration** module.

### Webmin 1.150 and below, Usermin 1.080 and below
#### XSS vulnerability
 - When viewing HTML email, several potentially dangerous types of URLs can be passed through. This can be used to perform malicious actions like executing commands as the logged-in Usermin user.

#### Module configurations are visible
- Even if a Webmin user does not have access to a module, he/she can still view it's Module Config page by entering a URL that calls `config.cgi` with the module name as a parameter.

#### Account lockout attack
- By sending a specially constructed password, an attacker can lock out other users if password timeouts are enabled.

  [2]: https://github.com/bl4ckmenace
  [3]: https://github.com/Pybro09
  [4]: https://github.com/ly1g3
  [5]: https://github.com/esp0xdeadbeef
  [6]: https://github.com/V1s3r1on
  [7]: https://github.com/faisalfs10x/
  [8]: https://www.netbytesec.com/
  [9]: https://twitter.com/Mesh3l_911
  [10]: https://twitter.com/electronicbots
  [12]: http://www.kb.cert.org/vuls/id/788478
  [13]: http://www.jpcert.or.jp/
