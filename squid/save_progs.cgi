#!/usr/local/bin/perl
# save_progs.cgi
# Save helper program options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'hprogs'} || &error($text{'eprogs_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'sprog_ftshpo'});

if ($squid_version < 2) {
	&save_opt("ftpget_program", \&check_prog, $conf);
	&save_opt("ftpget_options", \&check_opts, $conf);
	}
else {
	&save_opt("ftp_list_width", \&check_width, $conf);
	}
&save_opt("ftp_user", \&check_ftpuser, $conf);
&save_opt("cache_dns_program", \&check_prog, $conf);
&save_opt("dns_children", \&check_children, $conf);
&save_choice("dns_defnames", "off", $conf);
if ($squid_version >= 2) {
	&save_opt("dns_nameservers", \&check_dnsservers, $conf);
	}
&save_opt("unlinkd_program", \&check_prog, $conf);
&save_choice("pinger_enable", "on", $conf);
&save_opt("pinger_program", \&check_prog, $conf);
if ($squid_version >= 2.6) {
	&save_opt("url_rewrite_program", \&check_prog, $conf);
	if ($in{'url_rewrite_children_def'}) {
		&save_directive($conf, 'url_rewrite_children', [ ]);
		}
	else {
		my @w;
		$in{'url_rewrite_children'} =~ /^\d+$/ ||
			&error(&text('sprog_emsg5', $in{'url_rewrite_children'}));
		push(@w, $in{'url_rewrite_children'});
		foreach my $o ("startup", "idle", "concurrency") {
			next if ($in{"url_rewrite_".$o."_def"});
			$in{"url_rewrite_".$o} =~ /^[1-9]\d*$/ ||
				&error($text{'sprog_echildren'});
			push(@w, $o."=".$in{"url_rewrite_".$o});
			}
		my $dir = { 'name' => 'url_rewrite_children', 'values' => \@w };
		&save_directive($conf, $dir->{'name'}, [ $dir ]);
		}
	}
else {
	&save_opt("redirect_program", \&check_prog, $conf);
	&save_opt("redirect_children", \&check_children, $conf);
	}

&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("progs", undef, undef, \%in);
&redirect("");

sub check_opts
{
return $_[0] =~ /\S/ ? undef : $text{'sprog_emsg1'};
}

sub check_prog
{
$_[0] =~ /^(\/\S+)/ || return &text('sprog_emsg2', $_[0]);
return -x $1 ? undef : &text('sprog_emsg3',$_[0]); 
}

sub check_ftpuser
{
return $_[0] =~ /^\S+@\S*$/ ? undef : &text('sprog_emsg4',$_[0]);
}

sub check_width
{
return $_[0] =~ /^\d+$/ ? undef : &text('sprog_emsg6',$_[0]);
}

sub check_dnsservers
{
my @dns = split(/\s+/, $_[0]);
return $text{'sprog_emsg7'} if (!@dns);
foreach my $dns (@dns) {
	&check_ipaddress($dns) || return &text('sprog_emsg8',$dns);
	}
return undef;
}

sub check_children
{
return $_[0] =~ /^\d+$/ ? undef : &text('sprog_emsg5',$_[0]);
}
