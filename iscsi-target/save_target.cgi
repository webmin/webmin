#!/usr/local/bin/perl
# Create, update or delete a target

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text, %in, %config);
&ReadParse();
&error_setup($text{'target_err'});
&lock_file($config{'config_file'});
my $pconf = &get_iscsi_config_parent();
my $conf = $pconf->{'members'};

# Get the target
my $target;
if ($in{'new'}) {
	$target = { 'name' => 'Target',
		    'members' => [ ] };
	}
else {
	($target) = grep { $_->{'value'} eq $in{'oldname'} }
			 &find($conf, "Target");
	$target || &error($text{'target_egone'});
	}

if ($in{'delete'}) {
	# Delete the target
	&save_directive($conf, $pconf, [ $target ], [ ]);
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
	my @luns = &find_value($target->{'members'}, "Lun");
	my @newluns;
	my $lastlunid = 0;
	for(my $i=0; defined($in{"mode".$i}); $i++) {
		my ($lunid, $lunstr) = split(/\s+/, $luns[$i]);
		$lunid ||= ($lastlunid + 1);
		$lastlunid = $lunid;
		my %lunopts = map { split(/=/, $_) } split(/,/, $lunstr);

		# Clear variables that we will set below
		delete($lunopts{"Path"});
		delete($lunopts{"Type"});
		delete($lunopts{"Sectors"});

		if ($in{"mode".$i} eq "none") {
			# Nothing to do
			next;
			}
		elsif ($in{"mode".$i} eq "part") {
			# Regular partition
			$lunopts{"Path"} = $in{"part".$i};
			}
		elsif ($in{"mode".$i} eq "raid") {
			# RAID device
			$lunopts{"Path"} = $in{"raid".$i};
			}
		elsif ($in{"mode".$i} eq "lvm") {
			# LVM logical volume
			$lunopts{"Path"} = $in{"lvm".$i};
			}
		elsif ($in{"mode".$i} eq "other") {
			# Some other file
			$in{"other".$i} =~ /^\/\S+$/ && -r $in{"other".$i} ||
				&error(&text('target_eother', $i+1));
			$lunopts{"Path"} = $in{"other".$i};
			}
		elsif ($in{"mode".$i} eq "null") {
			# Null-IO device
			$lunopts{"Type"} = "nullio";
			$in{"null".$i} =~ /^\d+$/ && $in{"null".$i} > 0 ||
				&error(&text('target_esectors', $i+1));
			$lunopts{"Sectors"} = $in{"null".$i};
			}

		if ($in{"mode".$i} ne "null") {
			# Save IO mode
			$lunopts{"Type"} = $in{"type".$i};
			$lunopts{"IOMode"} = $in{"iomode".$i};
			}

		push(@newluns, $lunid." ".
			       join(",", map { $_."=".$lunopts{$_} }
					     grep { $lunopts{$_} ne "" }
						  (keys %lunopts)));
		}
	&save_directive($conf, $target, "Lun", \@newluns);

	# Validate incoming user(s)
	my @iusers;
	if (!$in{"iuser_def"}) {
		for(my $i=0; defined($in{"uname_$i"}); $i++) {
			next if (!$in{"uname_$i"});
			$in{"uname_$i"} =~ /^\S+$/ ||
				&error(&text('target_eiuser', $i+1));
			$in{"upass_$i"} =~ /^\S+$/ ||
				&error(&text('target_eipass', $i+1));
			push(@iusers, $in{"uname_$i"}." ".$in{"upass_$i"});
			}
		@iusers || &error($text{'target_eiusernone'});
		}
	&save_directive($conf, $target, "IncomingUser", \@iusers);

	# Validate outgoing user
	if ($in{"ouser_def"}) {
		&save_directive($conf, $target, "OutgoingUser", [ ]);
		}
	else {
		$in{"ouser"} =~ /^\S+$/ || &error($text{'target_eouser'});
		$in{"opass"} =~ /^\S+$/ || &error($text{'target_eopass'});
		&save_directive($conf, $target, "OutgoingUser",
			[ $in{"ouser"}." ".$in{"opass"} ]);
		}

	# Save alias
	if ($in{'alias_def'}) {
		&save_directive($conf, $target, "Alias", [ ]);
		}
	else {
		$in{'alias'} =~ /^[a-z0-9\.\_\-]+$/i ||
			&error($text{'target_ealias'});
		&save_directive($conf, $target, "Alias", [ $in{'alias'} ]);
		}

	# Save digest modes
	&save_directive($conf, $target, "HeaderDigest",
			$in{'hdigest'} ? [ $in{'hdigest'} ] : [ ]);
	&save_directive($conf, $target, "DataDigest",
			$in{'ddigest'} ? [ $in{'ddigest'} ] : [ ]);

	# Save the target
	&save_directive($conf, $pconf, $in{'new'} ? [ ] : [ $target ],
			[ $target ]);
	}

&flush_file_lines($config{'config_file'});
&unlock_file($config{'config_file'});
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'target', $target->{'value'});
&redirect("");
