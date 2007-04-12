#!/usr/local/bin/perl
# save_ips.cgi
# Save allowed and denied IP addresses

require './jabber-lib.pl';
&ReadParse();
&error_setup($text{'ips_err'});

$conf = &get_jabber_config();
$io = &find("io", $conf);
@oldallow = &find("allow", $io);
@olddeny = &find("deny", $io);

# Validate and store inputs
if (!$in{'allow_def'}) {
	foreach $a (split(/\s+/, $in{'allow'})) {
		push(@allow, &check_addr($a, "allow"));
		}
	}
if (!$in{'deny_def'}) {
	foreach $a (split(/\s+/, $in{'deny'})) {
		push(@deny, &check_addr($a, "deny"));
		}
	}
&save_directive($io, "allow", \@allow);
&save_directive($io, "deny", \@deny);
&save_jabber_config($conf);
&redirect("");

sub check_addr
{
if (&check_ipaddress($_[0])) {
	return [ $_[1], [ {}, "ip", [ { }, "0", $_[0] ] ] ];
	}
elsif ($_[0] =~ /^(\S+)\/(\S+)$/ &&
       &check_ipaddress($1) && &check_ipaddress($2)) {
	return [ $_[1], [ {}, "ip", [ { }, "0", $1 ],
			      "mask", [ { }, "0", $2 ] ] ];
	}
else {
	&error(&text('ips_eaddr', $_[0]));
	}
}
