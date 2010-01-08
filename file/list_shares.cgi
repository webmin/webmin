#!/usr/local/bin/perl
# list_shares.cgi
# Output info about samba shares

require './file-lib.pl';
print "Content-type: text/plain\n\n";
if ($access{'uid'}) {
	# User has no access to samba
	print "0\n";
	exit;
	}

%minfo = &get_module_info("samba");
&read_acl(\%acl, undef);
if (!%minfo || !&check_os_support(\%minfo) ||
    !$acl{$base_remote_user,'samba'}) {
	# Samba module not installed or supported
	print "0\n";
	exit;
	}

&foreign_require("samba", "samba-lib.pl");
%sconfig = &foreign_config("samba");
if (!-r $sconfig{'smb_conf'} || !&has_command($sconfig{'samba_server'})) {
	# Samba not installed
	print "0\n";
	exit;
	}

print "1\n";
foreach $s (&foreign_call("samba", "list_shares")) {
	&foreign_call("samba", "get_share", $s);
	if ($s ne 'global' && $s ne 'homes' && $s ne 'printers' &&
	    $samba::share{'path'} =~ /^\/[^\%\s\:]*$/ &&
	    $samba::share{'printable'} !~ /true|yes/i) {
		printf "%s:%s:%s:%s:%s\n",
			$samba::share{'path'},
			$samba::share{'available'} =~ /no|false/i ? 0 : 1,
			$samba::share{'writable'} =~ /yes|true/i ||
			 $samba::share{'writeable'} =~ /yes|true/i ? 1 : 0,
			$samba::share{'guest only'} =~ /yes|true/i ? 2 :
			$samba::share{'public'} =~ /yes|true/i ? 1 : 0,
			$samba::share{'comment'};
		}
	}

