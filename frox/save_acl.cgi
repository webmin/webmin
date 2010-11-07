#!/usr/local/bin/perl
# Save access control options

require './frox-lib.pl';
&ReadParse();
&error_setup($text{'acl_err'});
$conf = &get_config();

&save_opt_textbox($conf, "Timeout", \&check_timeout);
&save_opt_textbox($conf, "MaxForks", \&check_forks);
&save_opt_textbox($conf, "MaxForksPerHost", \&check_forks);
&save_opt_textbox($conf, "MaxTransferRate", \&check_rate);
&save_yesno($conf, "DoNTP");
&save_opt_textbox($conf, "NTPAddress", \&check_ntp);

for($i=0; defined($in{"action_$i"}); $i++) {
	next if (!$in{"action_$i"});
	local @val;
	push(@val, $in{"action_$i"});
	if ($in{"src_${i}_def"}) {
		push(@val, "*");
		}
	else {
		&valid_srcdest($in{"src_$i"}) ||
			&error(&text('acl_esrc', $i+1));
		push(@val, $in{"src_$i"});
		}
	push(@val, "-");
	if ($in{"dest_${i}_def"}) {
		push(@val, "*");
		}
	else {
		&valid_srcdest($in{"dest_$i"}) ||
			&error(&text('acl_edest', $i+1));
		push(@val, $in{"dest_$i"});
		}
	if (!$in{"ports_${i}_def"}) {
		foreach $p (split(/,/, $in{"ports_$i"})) {
			$p =~ /^\d+$/ || $p =~ /^\d+\-\d+$/ ||
				&error(&text('acl_eports', $i+1));
			}
		push(@val, $in{"ports_$i"});
		}
	push(@acl, join(" ", @val));
	}
@acl || &error($text{'acl_enone'});
&save_directive($conf, "ACL", \@acl);

&lock_file($config{'frox_conf'});
&flush_file_lines();
&unlock_file($config{'frox_conf'});
&webmin_log("acl");
&redirect("");

sub check_timeout
{
return $_[0] =~ /^\d+$/ ? undef : $text{'acl_etimeout'};
}

sub check_forks
{
return $_[0] =~ /^\d+$/ ? undef : $text{'acl_eforks'};
}

sub check_rate
{
return $_[0] =~ /^\d+$/ ? undef : $text{'acl_erate'};
}

sub check_ntp
{
return $_[0] =~ /^(\S+):(\d+)$/ && &to_ipaddress("$1") ? undef
						     : $text{'acl_entp'};
}


sub valid_srcdest
{
return &to_ipaddress($_[0]) ||
	   ($_[0] =~ /^([0-9\.]+)\/(\d+)$/ &&
	    &check_ipaddress($1) && $2 > 0 && $2 <= 32) ||
	   ($_[0] =~ /^([0-9\.]+)\/([0-9\.]+)$/ &&
	    &check_ipaddress($1) && &check_ipaddress($2));
}

