#!/usr/local/bin/perl
# save_export.cgi
# Update, create or delete an NFS export

require './file-lib.pl';
$disallowed_buttons{'sharing'} && &error($text{'ebutton'});
&ReadParse();
print "Content-type: text/plain\n\n";
if ($access{'ro'} || $access{'uid'}) {
	# User has no access to NFS
	print "0\n";
	exit;
	}

&read_acl(\%acl, undef);
%einfo = &get_module_info("exports");
%dinfo = &get_module_info("dfsadmin");
%binfo = &get_module_info("bsdexports");

if (%einfo && &check_os_support(\%einfo)) {
	# Linux NFS exports
	&module_check("exports");
	&foreign_require("exports", "exports-lib.pl");
	%econfig = &foreign_config("exports");
	&lock_file($econfig{'exports_file'});
	foreach $e (&foreign_call("exports", "list_exports")) {
		push(@{$exp{$e->{'dir'}}}, $e);
		}
	if ($in{'delete'}) {
		# Delete all exports for some dir
		foreach $e (reverse(@{$exp{$in{'path'}}})) {
			&foreign_call("exports", "delete_export", $e);
			}
		}
	else {
		# Adding or updating an export
		if (!$in{'new'}) {
			# Updating, so delete old exports first
			foreach $e (reverse(@{$exp{$in{'path'}}})) {
				$host{$e->{'host'}} = $e;
				&foreign_call("exports", "delete_export", $e);
				}
			}
		for($i=0; $in{"host$i"}; $i++) {
			$h = $in{"host$i"} eq '*' ? '' : $in{"host$i"};
			$e = $host{$h};
			$e = { 'active' => 1,
			       'host' => $h,
			       'dir' => $in{'path'} } if (!$e);
			delete($e->{'options'}->{'ro'});
			if ($in{"ro$i"}) {
				$e->{'options'}->{'ro'} = '';
				}
			delete($e->{'options'}->{'all_squash'});
			delete($e->{'options'}->{'no_root_squash'});
			if ($in{"squash$i"} == 0) {
				$e->{'options'}->{'all_squash'} = '';
				}
			elsif ($in{"squash$i"} == 2) {
				$e->{'options'}->{'no_root_squash'} = '';
				}
			&foreign_call("exports", "create_export", $e);
			}
		}
	&unlock_file($econfig{'exports_file'});

	# Apply configuration
	&exports::restart_mountd();

	&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
		    'export', $in{'path'});
	print "1\n";
	}
elsif (%dinfo && &check_os_support(\%dinfo)) {
	# Solaris NFS shares
	&module_check("dfsadmin");
	&foreign_require("dfsadmin", "dfs-lib.pl");
	%iconfig = &foreign_config("dfsadmin");
	&lock_file($iconfig{'dfstab_file'});
	@shlist = &foreign_call("dfsadmin", "list_shares");
	foreach $s (@shlist) {
		$share = $s if ($s->{'dir'} eq $in{'path'});
		}
	if ($in{'delete'}) {
		# Delete existing share
		&foreign_call("dfsadmin", "delete_share", $share);
		}
	elsif ($in{'new'}) {
		# Create new share
		foreach $r ('ro', 'rw', 'root') {
			if ($in{$r} ne '-') {
				$in{$r} =~ s/\s+/:/g;
				$opts->{$r} = $in{$r};
				}
			}
		$share->{'dir'} = $in{'path'};
		$share->{'desc'} = $in{'desc'};
		$share->{'opts'} =
			&foreign_call("dfsadmin", "join_options", $opts);
		&foreign_call("dfsadmin", "create_share", $share);
		}
	else {
		# Update existing share
		$opts = &foreign_call("dfsadmin", "parse_options",
				      $share->{'opts'});
		foreach $r ('ro', 'rw', 'root') {
			if ($in{$r} eq '-') { delete($opts->{$r}); }
			else {
				$in{$r} =~ s/\s+/:/g;
				$opts->{$r} = $in{$r};
				}
			}
		$share->{'dir'} = $in{'path'};
		$share->{'desc'} = $in{'desc'};
		$share->{'opts'} =
			&foreign_call("dfsadmin", "join_options", $opts);
		&foreign_call("dfsadmin", "modify_share", $share);
		}
	&unlock_file($iconfig{'dfstab_file'});

	# Apply changes to NFS daemon
	&dfsadmin::apply_configuration();

	&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
		    'export', $in{'path'});
	print "1\n";
	}
elsif (%binfo && &check_os_support(\%binfo)) {
	# BSD NFS exports
	&module_check("bsdexports");
	}
else {
	# No NFS modules installed or supported
	print "0\n";
	}

sub module_check
{
if (!$acl{$base_remote_user,$_[0]}) {
	print "0\n";
	exit;
	}
}

