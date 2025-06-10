#!/usr/local/bin/perl
# Add or update a server or group from the webmin servers module
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'slaves'} || &error($text{'slaves_ecannot'});
&ReadParse();
&foreign_require("servers", "servers-lib.pl");
my @allservers = grep { $_->{'user'} } &servers::list_servers();
my @add;
my $msg;
my $group;

if ($in{'server'} =~ /^group_(\S+)/) {
	# Add all from a group
	($group) = grep { $_->{'name'} eq $1 }
			&servers::list_all_groups(\@allservers);
	foreach my $m (@{$group->{'members'}}) {
		push(@add, grep { $_->{'host'} eq $m } @allservers);
		}
	&error_setup($text{'add_gerr'});
	$msg = &text('add_gmsg', $group->{'name'});
	$in{'name_def'} || &error($text{'add_egname'});
	}
else {
	# Add a single host
	@add = grep { $_->{'id'} eq $in{'server'} } @allservers;
	&error_setup($text{'add_err'});
	$msg = &text('add_msg', &server_name($add[0]));
	$in{'name_def'} || &valdnsname($in{'name'}) ||
		&error($text{'add_ename'});
	}
$in{'view_def'} || $in{'view'} =~ /\S/ || &error($text{'add_eview'});
my $myip = $config{'this_ip'} || &to_ipaddress(&get_system_hostname());
$myip && $myip ne "127.0.0.1" ||
	&error($text{'add_emyip'});

&ui_print_header(undef, $text{'add_title'}, "");
print "<b>$msg</b><p>\n";

# Setup error handler for down hosts
my $add_error_msg;
sub add_error
{
$add_error_msg = join("", @_);
}
&remote_error_setup(\&add_error);

# Build map from zone names to configs
my $conf = &get_config();
my %zmap = ( );
my @zoneconfs = &find("zone", $conf);
my @views = &find("view", $conf);
foreach my $v (@views) {
	push(@zoneconfs, &find("zone", $v->{'members'}));
	}
foreach my $z (@zoneconfs) {
	my $type = &find_value("type", $z->{'members'});
	if ($type eq "master" || $type eq "primary") {
		$zmap{$z->{'value'}} = $z;
		}
	}

# Make sure each host is set up for BIND
my @zones = grep { $_->{'type'} eq 'master' } &list_zone_names();
foreach my $s (@add) {
	$s->{'bind8_view'} = $in{'view_def'} == 1 ? undef :
			     $in{'view_def'} == 2 ? "*" : $in{'view'};
	my $add_error_msg = undef;
	my $bind8 = &remote_foreign_check($s, "bind8");
	if ($add_error_msg) {
		print "$add_error_msg<p>\n";
		next;
		}
	if (!$bind8) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	&remote_foreign_require($s, "bind8", "bind8-lib.pl");
	my $inst = &remote_foreign_call($s, "bind8",
					   "foreign_installed", "bind8", 1);
	if (!$inst) {
		print &text('add_emissing', $s->{'host'}),"<p>\n";
		next;
		}

	# Check for non-IP name
	if (&check_ipaddress($s->{'host'}) && $in{'name_def'}) {
		print &text('add_eipaddr', $s->{'host'}),"<p>\n";
		next;
		}
	if (!$in{'name_def'} && &check_ipaddress($in{'name'})) {
	print &text('add_eipaddr', $s->{'host'}),"<p>\n";
		next;
		}

	my @rzones = grep { $_->{'type'} ne 'view' }
		       &remote_foreign_call($s, "bind8", "list_zone_names");
	print &text('add_ok', $s->{'host'}, scalar(@rzones)),"<p>\n";
	$s->{'sec'} = $in{'sec'};
	$s->{'nsname'} = $in{'name_def'} ? undef : $in{'name'};
	&add_slave_server($s);
	my %rgot = map { $_->{'name'}, 1 } @rzones;

	if ($in{'sync'}) {
		# Add all master zones from this server to the slave
		my $zcount = 0;
		my $zerr = 0;
		my $sip = &to_ipaddress($s->{'host'});
		my %zerrs;
		foreach my $zone (grep { !$rgot{$_->{'name'}} } @zones) {
			my ($slaveerr) = &create_on_slaves($zone->{'name'},
			  $myip, undef, [ $s->{'host'} ], $zone->{'view'});
			if ($slaveerr) {
				$zerrs{$slaveerr->[0]->{'host'}} ||=
					$slaveerr->[1];
				$zerr++;
				}
			else {
				$zcount++;
				}
			}

		# Restart the slave
		if ($zcount) {
			&remote_foreign_call($s, "bind8", "restart_bind");
			}

		# Add slave IP to master zone allow-transfer and also-notify
		# blocks
		my $dchanged = 0;
		foreach my $zone (@zones) {
			my $z = $zmap{$zone->{'name'}};
			next if (!$z || !$sip);
			foreach my $d ("also-notify", "allow-transfer") {
				my $n = &find($d, $z->{'members'});
				if ($n) {
					# Block already exists
					my ($got) =
					    grep { $_->{'name'} eq $sip }
						 @{$n->{'members'}};
					next if ($got);
					push(@{$n->{'members'}},
					     { 'name' => $sip });
					}
				else {
					# Need to add block
					$n = { 'name' => $d,
					       'type' => 1,
					       'members' => [
						     { 'name' => $sip },
					       ] };
					}
				&lock_file($z->{'file'});
				&save_directive($z, $d, [ $n ], 1);
				&flush_file_lines();
				$dchanged++;
				}
			}
		if ($dchanged) {
			&unlock_all_files();
			&restart_bind();
			}

		# Tell the user
		if ($zerr) {
			print &text('add_createerr', $s->{'host'},
				    $zcount, $zerr),"<br>\n";
			foreach my $k (keys %zerrs) {
				print "$k : $zerrs{$k}<br>\n";
				}
			print "<p>\n";
			}
		else {
			print &text('add_createok', $s->{'host'},
				    $zcount),"<p>\n";
			}
		}
	}
&remote_finished();
if ($in{'add'}) {
	&webmin_log("add", "host", $add[0]->{'host'});
	}
else {
	&webmin_log("add", "group", $group->{'name'});
	}

&ui_print_footer("list_slaves.cgi", $text{'slaves_return'});

