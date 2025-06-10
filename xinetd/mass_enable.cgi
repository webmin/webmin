#!/usr/local/bin/perl
# Enable or disable a bunch of services
# XXX what about line changes due to modifications??
# XXX changelog / ideas

require './xinetd-lib.pl';
&ReadParse();

@conf = &get_xinetd_config();
@ids = split(/\0/, $in{'serv'});
($defs) = grep { $_->{'name'} eq 'defaults' } @conf;
foreach $m (@{$defs->{'members'}}) {
	$ddisable{$m->{'value'}} = $m if ($m->{'name'} eq 'disabled');
	}

&lock_file($config{'xinetd_conf'});
if ($in{'enable'}) {
	# Enable all selected
	foreach $id (@ids) {
		@conf = &get_xinetd_config();
		$xinet = $conf[$id];
		&lock_file($xinet->{'file'});
		$q = $xinet->{'quick'};
		$dis = $q->{'disable'}->[0] eq 'yes' || $ddisable{$id};
		if ($dis) {
			&set_member_value($xinet, 'disable', 'no');
			&modify_xinet($xinet);
			if ($ddisable{$oldid}) {
				# Take out old global disabled
				&delete_xinet($ddisable{$oldid});
				}
			push(@servs, $xinet->{'value'});
			}
		}
	}
else {
	# Disable all selected
	foreach $id (@ids) {
		@conf = &get_xinetd_config();
		$xinet = $conf[$id];
		&lock_file($xinet->{'file'});
		$q = $xinet->{'quick'};
		$dis = $q->{'disable'}->[0] eq 'yes' || $ddisable{$id};
		if (!$dis) {
			&set_member_value($xinet, 'disable', 'yes');
			&modify_xinet($xinet);
			push(@servs, $xinet->{'value'});
			}
		}
	}

&unlock_all_files();
&webmin_log($in{'enable'} ? "enable" : "disable", undef, scalar(@ids),
	    { 'servs' => \@servs });
&redirect("");

