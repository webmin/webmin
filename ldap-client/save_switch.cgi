#!/usr/local/bin/perl
# Update one LDAP switch

if (-r 'ldap-client-lib.pl') {
	require './ldap-client-lib.pl';
	}
else {
	require './nis-lib.pl';
	}
require './switch-lib.pl';
&ReadParse();
&error_setup($text{'eswitch_err'});

# Get the current service
&lock_file($nsswitch_config_file);
$conf = &get_nsswitch_config();
($switch) = grep { $_->{'name'} eq $in{'name'} } @$conf;
$switch || &error($text{'eswitch_egone'});

# Validate and store inputs
@srcs = ( );
for($i=0; defined($src = $in{"src_$i"}); $i++) {
	next if (!$src);
	$s = { 'src' => $src };
	foreach $st (&list_switch_statuses()) {
		if ($in{"status_".$st."_".$i}) {
			$s->{$st} = $in{"status_".$st."_".$i};
			}
		}
	push(@srcs, $s);
	}
@srcs || &error($text{'eswitch_enone'});
$switch->{'srcs'} = \@srcs;

# Save it
&save_nsswitch_config($switch);
&unlock_file($nsswitch_config_file);
&webmin_log("modify", "switch", $switch->{'name'});

&redirect("list_switches.cgi");

