#!/usr/local/bin/perl
# save_defaults.cgi
# Save default options

require './xinetd-lib.pl';
&ReadParse();
&error_setup($text{'defs_err'});
&lock_file($config{'xinetd_conf'});
@conf = &get_xinetd_config();
foreach $c (@conf) {
	if ($c->{'name'} eq 'defaults') {
		$defs = $c;
		$found++;
		}
	}
if (!$found) {
	$defs = { 'name' => 'defaults',
		  'members' => [ ] };
	}

# Parse and save inputs
&set_member_value($defs, 'only_from', $in{'from_def'} ? undef :
		  $in{'from'} ? split(/\s+/, $in{'from'}) : ("") );
&set_member_value($defs, 'no_access', $in{'access_def'} ? undef :
		  $in{'access'} ? split(/\s+/, $in{'access'}) : ("") );
if ($in{'log_mode'} == 0) {
	&set_member_value($defs, 'log_type');
	}
elsif ($in{'log_mode'} == 1) {
	&set_member_value($defs, 'log_type', 'SYSLOG', $in{'facility'},
			  $in{'level'} ? ( $in{'level'} ) : ( ) );
	}
elsif ($in{'log_mode'} == 2) {
	$in{'file'} =~ /^\S+$/ || &error($text{'defs_efile'});
	$in{'soft'} =~ /^\d*$/ || &error($text{'defs_esoft'});
	$in{'hard'} =~ /^\d*$/ || &error($text{'defs_ehard'});
	&set_member_value($defs, 'log_type', 'FILE', $in{'file'},
		  $in{'soft'} ? ( $in{'soft'}*$in{'soft_units'} ) : ( ),
		  $in{'hard'} ? ( $in{'hard'}*$in{'hard_units'} ) : ( ) );
	}
&set_member_value($defs, 'log_on_success', split(/\0/, $in{'success'}));
&set_member_value($defs, 'log_on_failure', split(/\0/, $in{'failure'}));
if ($found) {
	&modify_xinet($defs);
	}
else {
	&create_xinet($defs);
	}
&unlock_file($config{'xinetd_conf'});
&webmin_log("defaults", undef, undef, $defs->{'quick'});
&redirect("");

