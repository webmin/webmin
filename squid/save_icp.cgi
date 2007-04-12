#!/usr/local/bin/perl
# save_icp.cgi
# Save cache options

require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'sicp_ftsco'};

if ($squid_version < 2) {
	&save_list("local_domain", undef, $conf);
	&save_address("local_ip", $conf);
	&save_list("inside_firewall", undef, $conf);
	&save_address("firewall_ip", $conf);
	}
&save_list("hierarchy_stoplist", undef, $conf);
if ($squid_version < 2) {
	&save_choice("single_parent_bypass", "off", $conf);
	&save_choice("source_ping", "off", $conf);
	&save_opt("neighbor_timeout", \&check_timeout, $conf);
	}
else {
	&save_opt("icp_query_timeout", \&check_timeout, $conf);
	&save_opt("mcast_icp_query_timeout", \&check_timeout, $conf);
	&save_opt("dead_peer_timeout", \&check_timeout, $conf);
	}
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("icp", undef, undef, \%in);
&redirect("");

sub check_timeout
{
return $_[0] =~ /^\d+$/ ? undef : &text('sicp_emsg1',$_[0]);
}

