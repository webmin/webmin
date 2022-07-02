#!/usr/local/bin/perl
# save_cache_host.cgi
# Save, create or delete a cache_host directive

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my $cache_host = $squid_version >= 2 ? "cache_peer" : "cache_host";
my @ch = &find_config($cache_host, $conf);
my @chd = &find_config($cache_host."_domain", $conf);

my $dom = $ch[$in{'num'}]->{'values'}->[0];
my $dir;
if ($in{'delete'}) {
	# delete some directive
	$dir = $ch[$in{'num'}];
	splice(@ch, $in{'num'}, 1);

	# delete any cache_host directives as well
	for(my $i=0; $i<@chd; $i++) {
		if ($chd[$i]->{'values'}->[0] eq $dom) {
			splice(@chd, $i--, 1);
			}
		}
	}
else {
	# validate inputs
	&error_setup($text{'schost_ftsc'});
	&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
		&error(&text('schost_emsg1',$in{'host'}));
	$in{'proxy'} =~ /^\d+$/ ||
		&error(&text('schost_emsg2',$in{'proxy'}));
	$in{'icp'} =~ /^\d+$/ ||
		&error(&text('schost_emsg3',$in{'icp'}));
	$in{'ttl'} =~ /^\d*$/ ||
		&error(&text('schost_emsg4',$in{'ttl'}));
	$in{'weight'} =~ /^\d*$/ ||
		&error(&text('schost_emsg5',$in{'weight'}));

	my @vals = ($in{'host'}, $in{'type'}, $in{'proxy'}, $in{'icp'});
	my @optlist = ("proxy-only", "weight", "ttl", "no-query", "default",
                       "round-robin", "multicast-responder",
		       "closest-only", "no-digest",	# squid 2+
		       "no-netdb-exchange", "no-delay",
		       "connect-timeout", "digest-url",	# squid 3+
		       "allow-miss", "max-conn", "htcp", "forceddomain",
		       "originserver", "ssl");
	foreach my $o (@optlist) {
		my $def = $in{$o."_def"};
		if (defined($def)) {
			if (!$def) { push(@vals, "$o=$in{$o}"); }
			}
		elsif ($in{$o}) { push(@vals, $o); }
		}
	if ($in{'login'} == 1) {
		push(@vals, "login=".$in{'login_user'}.":".$in{'login_pass'});
		}
	elsif ($in{'login'} == 2) {
		push(@vals, "login=PASS");
		}
	elsif ($in{'login'} == 3) {
		push(@vals, "login=*:".$in{'login_pass2'});
		}

	# Add any old options that are not supported
	if (!$in{'new'}) {
		my %supported = map { $_, 1 } @optlist;
		$supported{'login'} = 1;
		my @ech = @{$ch[$in{'num'}]->{'values'}};
		for(my $i=4; $i<@ech; $i++) {
			if ($ech[$i] =~ /^(\S+)=(\S+)$/ ||
			    $ech[$i] =~ /^(\S+)$/) {
				if (!$supported{$1}) {
					push(@vals, $ech[$i]);
					}
				}
			}
		}

	$dir = { 'name' => $cache_host, 'values' => \@vals };
	my @chdl = split(/\s+/, $in{'doq'});
	foreach my $dontq (split(/\s+/, $in{'dontq'})) {
		push(@chdl, "!$dontq");
		}
	if ($in{'new'}) {
		# adding a new cache_host and domains
		push(@ch, $dir);
		if (@chdl) {
			push(@chd, { 'name' => $cache_host."_domain",
				     'values' => [ $vals[0], @chdl ] });
			}
		}
	else {
		# updating existing cache_host and domains
		$ch[$in{'num'}] = $dir;
		if (@chdl) {
			# replace the first cache_host_domain directive
			# for this host and remove the rest
			my $newv = { 'name' => $cache_host."_domain",
				     'values' => [ $vals[0], @chdl ] };
			my $already = 0;
			for(my $i=0; $i<@chd; $i++) {
				if ($chd[$i]->{'values'}->[0] eq $dom) {
					if ($already) {
						splice(@chd, $i--, 1);
						}
					else {
						$chd[$i] = $newv;
						$already++;
						}
					}
				}
			if (!$already) { push(@chd, $newv); }
			}
		elsif (@chd) {
			# remove all the old cache_host_domain directives
			# for this host
			@chd = grep { $_->{'values'}->[0] ne $dom } @chd;
			}
		}
	}
&save_directive($conf, $cache_host, \@ch);
&save_directive($conf, $cache_host."_domain", \@chd);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "host", $dir->{'values'}->[0], \%in);
&redirect("edit_icp.cgi");

