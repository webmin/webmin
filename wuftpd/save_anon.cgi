#!/usr/local/bin/perl
# save_anon.cgi
# Save anonymous FTP

require './wuftpd-lib.pl';
&error_setup($text{'anon_err'});
&ReadParse();
&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();

# save anonymous-root options
for($i=0; defined($dir = $in{"dir_$i"}); $i++) {
	next if (!$dir);
	-d $dir || &error(&text('anon_edir', $dir));
	push(@aroot, { 'name' => 'anonymous-root',
		       'values' => [ $dir, $in{"class_$i"} ] } );
	}
&save_directive($conf, 'anonymous-root', \@aroot);

#save guest-root options
for($i=0; defined($dir = $in{"gdir_$i"}); $i++) {
	next if (!$dir);
	-d $dir || &error(&text('anon_edir', $dir));
	push(@groot, { 'name' => 'guest-root',
		       'values' => [ $dir, $in{"uids_$i"} ] } );
	}
&save_directive($conf, 'guest-root', \@groot);

# save autogroup options
for($i=0; defined($agroup = $in{"agroup_$i"}); $i++) {
	next if (!$agroup);
	defined(getgrnam($agroup)) || &error(&text('anon_egroup', $agroup));
	push(@agroup, { 'name' => 'autogroup',
			'values' => [ $agroup,
				      split(/\0/, $in{"aclass_$i"}) ] } );
	}
&save_directive($conf, 'autogroup', \@agroup);

# save other options
if ($in{'passwd_def'}) {
	&save_directive($conf, 'passwd-check', [ ]);
	}
else {
	&save_directive($conf, 'passwd-check',
			[ { 'name' => 'passwd-check',
			    'values' => [ $in{'level'}, $in{'action'} ] } ] );
	}
foreach $a (split(/\s+/, $in{'email'})) {
	push(@email, { 'name' => 'deny-email', 'values' => [ $a ] } );
	}
&save_directive($conf, 'deny-email', \@email);

&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("anon", undef, undef, \%in);
&redirect("");
