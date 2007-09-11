#!/usr/local/bin/perl
# Add or update a server or group from the webmin servers module

require './bind8-lib.pl';
$access{'slaves'} || &error($text{'slaves_ecannot'});
&ReadParse();
&foreign_require("servers", "servers-lib.pl");
@allservers = grep { $_->{'user'} } &servers::list_servers();

if ($in{'add'}) {
	# Add a single host
	@add = grep { $_->{'id'} eq $in{'server'} } @allservers;
	&error_setup($text{'add_err'});
	$msg = &text('add_msg', &server_name($add[0]));
	$in{'name_def'} || &valdnsname($in{'name'}) ||
		&error($text{'add_ename'});
	}
else {
	# Add all from a group
	($group) = grep { $_->{'name'} eq $in{'group'} }
			&servers::list_all_groups(\@allservers);
	foreach $m (@{$group->{'members'}}) {
		push(@add, grep { $_->{'host'} eq $m } @allservers);
		}
	&error_setup($text{'add_gerr'});
	$msg = &text('add_gmsg', $in{'group'});
	$in{'name_def'} || &error($text{'add_egname'});
	}
$in{'view_def'} || $in{'view'} =~ /^\S+$/ || &error($text{'add_eview'});
$myip = $config{'this_ip'} || &to_ipaddress(&get_system_hostname());
$myip && $myip ne "127.0.0.1" ||
	&error($text{'add_emyip'});

&ui_print_header(undef, $text{'add_title'}, "");
print "<b>$msg</b><p>\n";

# Setup error handler for down hosts
sub add_error
{
$add_error_msg = join("", @_);
}
&remote_error_setup(\&add_error);

# Make sure each host is set up for BIND
@zones = grep { $_->{'type'} eq 'master' } &list_zone_names();
foreach $s (@add) {
	$s->{'bind8_view'} = $in{'view_def'} ? undef : $in{'view'};
	$add_error_msg = undef;
	local $bind8 = &remote_foreign_check($s, "bind8");
	if ($add_error_msg) {
		print "$add_error_msg<p>\n";
		next;
		}
	if (!$bind8) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	&remote_foreign_require($s, "bind8", "bind8-lib.pl");
	local $inst = &remote_foreign_call($s, "bind8",
					   "foreign_installed", "bind8", 1);
	if (!$inst) {
		print &text('add_emissing', $s->{'host'}),"<p>\n";
		next;
		}
	if (&remote_foreign_call($s, "bind8",
				 "get_webmin_version") < 1.202) {
		print &text('add_eversion', $s->{'host'}, 1.202),"<p>\n";
		next;
		}

	@rzones = grep { $_->{'type'} ne 'view' }
		       &remote_foreign_call($s, "bind8", "list_zone_names");
	print &text('add_ok', $s->{'host'}, scalar(@rzones)),"<p>\n";
	$s->{'sec'} = $in{'sec'};
	$s->{'nsname'} = $in{'name_def'} ? undef : $in{'name'};
	&add_slave_server($s);
	%rgot = map { $_->{'name'}, 1 } @rzones;

	if ($in{'sync'}) {
		# Add all master zones from this server to the slave
		$zcount = 0;
		$zerr = 0;
		foreach $zone (grep { !$rgot{$_->{'name'}} } @zones) {
			($slaveerr) = &create_on_slaves($zone->{'name'}, $myip,
						       undef, [ $s->{'host'} ]);
			if ($slaveerr) {
				$zerrs{$slaveerr->[0]->{'host'}} ||= $slaveerr->[1];
				$zerr++;
				}
			else {
				$zcount++;
				}
			}

		# Restart the slave too
		if ($zcount) {
			&remote_foreign_call($s, "bind8", "restart_bind");
			}

		# Tell the user
		if ($zerr) {
			print &text('add_createerr', $s->{'host'}, $zcount, $zerr),"<br>\n";
			foreach $k (keys %zerrs) {
				print "$k : $zerrs{$k}<br>\n";
				}
			print "<p>\n";
			}
		else {
			print &text('add_createok', $s->{'host'}, $zcount),"<p>\n";
			}
		}
	}
&remote_finished();
if ($in{'add'}) {
	&webmin_log("add", "host", $add[0]->{'host'});
	}
else {
	&webmin_log("add", "group", $in{'group'});
	}

&ui_print_footer("list_slaves.cgi", $text{'slaves_return'});

