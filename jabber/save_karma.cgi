#!/usr/local/bin/perl
# save_karma.cgi
# Save karma traffic control options

require './jabber-lib.pl';
&ReadParse();
&error_setup($text{'karma_err'});

$conf = &get_jabber_config();
$io = &find("io", $conf);
$karma = &find("karma", $io);

if (!$karma) {
	# Create a new empty karma block
	$karma = [ "karma", [ { } ] ];
	}

# Validate and store inputs
if ($in{'rate_def'}) {
	&save_directive($io, "rate");
	}
else {
	$in{'points'} =~ /^\d+$/ || &error($text{'karma_epoints'});
	$in{'time'} =~ /^\d+$/ || &error($text{'karma_etime'});
	&save_directive($io, "rate",
			[ [ "rate", [ { 'points' => $in{'points'},
					'time' => $in{'time'} } ] ] ] );
	}
if ($in{'mode'} == -1) {
	# Remove karma section entirely
	&save_directive($io, "karma");
	}
elsif ($in{'mode'} == 3) {
	# Check user karma inputs
	foreach $k ('heartbeat', 'init', 'max', 'dec', 'penalty', 'restore') {
		$in{$k} =~ /^\d+$/ || &error($text{"karma_e$k"});
		local $v = $k eq 'penalty' ? -$in{$k} : $in{$k};
		&save_directive($karma, $k, [ [ $k, [ { }, 0, $v ] ] ] );
		}
	}
else {
	# Use pre-defined karma
	$kp = $karma_presets[$in{'mode'}];
	foreach $k (keys %$kp) {
		&save_directive($karma, $k, [ [ $k, [ { }, 0, $kp->{$k} ] ] ] );
		}
	&save_directive($io, "karma", [ $karma ] );
	}
&save_jabber_config($conf);
&redirect("");

