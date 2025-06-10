#!/usr/local/bin/perl
# delete_all.cgi
# Delete a subnet, shared network or host

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
if ($in{'cancel'}) {
	&redirect("");
	exit;
	}
&lock_all_files();
$par = &get_parent_config();
foreach $i ($in{'sidx'}, $in{'uidx'}) {
	if ($i ne "") {
		$par = $par->{'members'}->[$i];
		}
	}
$parconf = $par->{'members'};
$to_del = $parconf->[$in{'idx'}];
@host = &find("host", $to_del->{'members'});
@group = &find("group", $to_del->{'members'});
@subn = &find("subnet", $to_del->{'members'});

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($to_del->{'name'} eq "group") {
	&error("$text{'eacl_np'} $text{'eacl_pdg'}")
		if !&can('rw', \%access, $to_del, 1);
	}
elsif ($to_del->{'name'} eq "subnet") {
	$type = 'sub';
	&error("$text{'eacl_np'} $text{'eacl_pds'}")
		if !&can('rw', \%access, $to_del, 1);
	foreach $g (@group) {
		&error("$text{'eacl_np'} $text{'eacl_pdg'}")
			if !&can('rw', \%access, $g, 1);
		}
	}
elsif ($to_del->{'name'} eq "shared-network") {
	&error("$text{'eacl_np'} $text{'eacl_pdn'}")
		if !&can('rw', \%access, $to_del, 1);
	foreach $s (@subn) {
		&error("$text{'eacl_np'} $text{'eacl_pds'}")
			if !&can('rw', \%access, $s, 1);
		}
	foreach $g (@group) {
		&error("$text{'eacl_np'} $text{'eacl_pdg'}")
			if !&can('rw', \%access, $g, 1);
		}
	}
else {
	&error($text{'cdel_eunknown'});
	}

foreach $h (@host) {
	&error("$text{'eacl_np'} $text{'eacl_pdh'}")
		if !&can('rw', \%access, $h, 1);
	}

if ($type) {
	&drop_dhcpd_acl($type, \%access, $to_del);
	}
&save_directive($par, [ $to_del ], [ ], 0);
&flush_file_lines();
&unlock_all_files();
if ($to_del->{'name'} eq "group") {
	@count = &find("host", $group->{'members'});
	&webmin_log('delete', 'group', join(",", map { $_->{'values'}->[0] } @count), \%in);
	}
elsif ($to_del->{'name'} eq "subnet") {
	&webmin_log('delete', 'subnet', "$sub->{'values'}->[0]/$sub->{'values'}->[2]", \%in);
	}
elsif ($to_del->{'name'} eq "shared") {
	&webmin_log('delete', 'shared', $sha->{'values'}->[0], \%in);
	}

&redirect("");
