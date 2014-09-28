#!/usr/local/bin/perl
# Create, update or delete a target

use strict;
use warnings;
require './iscsi-tgtd-lib.pl';
our (%text, %in, %config);
&ReadParse();
&error_setup($text{'target_err'});
my $conf = &get_tgtd_config();

# Get the target
my $target;
my $addfile;
if ($in{'new'}) {
	$target = { 'name' => 'target',
		    'type' => 1,
		    'members' => [ ] };
	if (-d $config{'add_file'}) {
		$addfile = $config{'add_file'}."/".$in{'name'}.".conf";
		}
	elsif ($config{'add_file'}) {
		$addfile = $config{'add_file'};
		}
	}
else {
	($target) = grep { $_->{'value'} eq $in{'oldname'} }
			 &find($conf, "Target");
	$target || &error($text{'target_egone'});
	}
my $lockfile = $target->{'file'} || $addfile;
&lock_file($lockfile);

if ($in{'delete'}) {
	# Delete the target
	&save_directive($conf, $target, undef);
	&delete_if_empty($target->{'file'});
	}
else {
	# Validate and save directives, starting with target name
	my $host;
	if ($in{'new'}) {
		$host = &find_host_name($conf) || &generate_host_name();
		}
	else {
		($host) = split(/:/, $target->{'value'});
		}
	$in{'name'} =~ /^[a-z0-9\.\_\-]+$/i || &error($text{'target_ename'});
	$target->{'value'} = $host.":".$in{'name'};

	# Validate logical units
	my @luns = (&find($target->{'members'}, "backing-store"),
		    &find($target->{'members'}, "direct-store"));
	@luns = sort { $a->{'file'} <=> $b->{'file'} } @luns;
	my (@backluns, @directluns);
	for(my $i=0; defined($in{"mode".$i}); $i++) {
		my $path;
		if ($in{"mode".$i} eq "none") {
			# Nothing to do
			next;
			}
		elsif ($in{"mode".$i} eq "part") {
			# Regular partition
			$path = $in{"part".$i};
			}
		elsif ($in{"mode".$i} eq "raid") {
			# RAID device
			$path = $in{"raid".$i};
			}
		elsif ($in{"mode".$i} eq "lvm") {
			# LVM logical volume
			$path = $in{"lvm".$i};
			}
		elsif ($in{"mode".$i} eq "other") {
			# Some other file
			$in{"other".$i} =~ /^\/\S+$/ && -r $in{"other".$i} ||
				&error(&text('target_eother', $i+1));
			$path = $in{"other".$i};
			}
		my $newlun = $i >= @luns ? { } : $luns[$i];
		$newlun->{'name'} = $in{"type".$i};
		$newlun->{'value'} = $path;
		my $cache = $in{"cache".$i} ? { 'name' => 'write-cache',
						'value' => $in{"cache".$i} }
					    : undef;
		&save_directive($conf, "write-cache", $cache, $newlun);
		if ($newlun->{'name'} eq "backing-store") {
			push(@backluns, $newlun);
			}
		else {
			push(@directluns, $newlun);
			}
		}
	&save_multiple_directives($conf, "backing-store", \@backluns, $target);
	&save_multiple_directives($conf, "direct-store", \@directluns,$target);

	# Validate incoming user(s)
	my @iusers;
	if (!$in{"iuser_def"}) {
		for(my $i=0; defined($in{"uname_$i"}); $i++) {
			next if (!$in{"uname_$i"});
			$in{"uname_$i"} =~ /^\S+$/ ||
				&error(&text('target_eiuser', $i+1));
			$in{"upass_$i"} =~ /^\S+$/ ||
				&error(&text('target_eipass', $i+1));
			push(@iusers,
			    { 'name' => 'incominguser',
			      'value' => $in{"uname_$i"}." ".$in{"upass_$i"} });
			}
		@iusers || &error($text{'target_eiusernone'});
		}
	&save_multiple_directives($conf, "incominguser", \@iusers, $target);

	# Validate outgoing user(s)
	if (!$in{"ouser_def"}) {
                $in{"ouser"} =~ /^\S+$/ || &error($text{'target_eouser'});
                $in{"opass"} =~ /^\S+$/ || &error($text{'target_eopass'});
		my $ouser = { 'name' => "outgoinguser",
			      'value' => $in{"ouser"}." ".$in{"opass"} };
		&save_directive($conf, "outgoinguser", $ouser, $target);
		}
	else {
		&save_directive($conf, "outgoinguser", undef, $target);
		}

	# Save allowed IPs
	my @addrs;
	if (!$in{"iaddress_def"}) {
		foreach my $a (split(/\s+/, $in{"iaddress"})) {
			&check_ipaddress($a) || &error($text{'target_eaddr'});
			push(@addrs, { 'name' => "initiator-address",
				       'value' => $a });
			}
		}
	&save_multiple_directives($conf, "initiator-address", \@addrs, $target);

	# Save allowed initiators
	my @names;
	if (!$in{"iname_def"}) {
		foreach my $a (split(/\s+/, $in{"iname"})) {
			$a =~ /^[:a-z0-9\.\_\-]+$/i ||
				&error($text{'target_eaname'});
			push(@names, { 'name' => "initiator-name",
				       'value' => $a });
			}
		}
	&save_multiple_directives($conf, "initiator-name", \@names, $target);

	# Save the target
	if ($in{'new'}) {
		&save_directive($conf, undef, $target, undef, $addfile);
		}
	else {
		&save_directive($conf, $target, $target);
		}
	}

&flush_file_lines();
&unlock_file($lockfile);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'target', $target->{'value'});
&redirect("");
