#!/usr/local/bin/perl
# save_share.cgi
# Create, update or delete a samba share

require './file-lib.pl';
$disallowed_buttons{'sharing'} && &error($text{'ebutton'});
&ReadParse();
print "Content-type: text/plain\n\n";
if ($access{'ro'} || $access{'uid'}) {
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
&lock_file($sconfig{'smb_conf'});
@shares = &foreign_call("samba", "list_shares");

if ($in{'delete'}) {
	# Deleting an old share
	foreach $s (@shares) {
		&foreign_call("samba", "get_share", $s);
		if ($samba::share{'path'} &&
		    $samba::share{'path'} eq $in{'path'}) {
			&foreign_call("samba", "delete_share", $s);
			last;
			}
		}
	print "1\n";
	}
elsif ($in{'new'}) {
	# Creating a new share
	map { $taken{$_}++ } @shares;
	if ($in{'path'} =~ /\/([^\/]+)$/) {
		$base = $1;
		}
	else {
		$base = "root";
		}
	if ($taken{$base}) {
		for($i=2; $taken{$base.$i}; $i++) { }
		$base = $base.$i;
		}
	$samba::share{'path'} = $in{'path'};
	$samba::share{'available'} = $in{'available'} ? 'yes' : 'no';
	$samba::share{'writeable'} = $in{'writable'} ? 'yes' : 'no';
	$samba::share{'comment'} = $in{'comment'};
	if ($in{'guest'} == 2) {
		$samba::share{'public'} = 'yes';
		$samba::share{'guest only'} = 'yes';
		}
	elsif ($in{'guest'} == 1) {
		$samba::share{'public'} = 'yes';
		}
	&foreign_call("samba", "create_share", $base);
	print "1\n";
	}
else {
	# Updating an existing share
	foreach $s (@shares) {
		&foreign_call("samba", "get_share", $s);
		if ($samba::share{'path'} &&
		    $samba::share{'path'} eq $in{'path'}) {
			# found the share to update
			$samba::share{'available'} = $in{'available'} ? 'yes'
								      : 'no';
			$samba::share{'writeable'} = $in{'writable'} ? 'yes'
								    : 'no';
			$samba::share{'comment'} = $in{'comment'};
			if ($in{'guest'} == 2) {
				$samba::share{'public'} = 'yes';
				$samba::share{'guest only'} = 'yes';
				}
			elsif ($in{'guest'} == 1) {
				$samba::share{'public'} = 'yes';
				delete($samba::share{'guest only'});
				}
			else {
				delete($samba::share{'public'});
				delete($samba::share{'guest only'});
				}
			&foreign_call("samba", "modify_share", $s, $s);
			last;
			}
		}
	print "1\n";
	}
&unlock_file($sconfig{'smb_conf'});
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'share', $in{'path'});

