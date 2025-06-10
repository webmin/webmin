#!/usr/local/bin/perl
# Create, update or delete a log target

require './syslog-ng-lib.pl';
&ReadParse();
&error_setup($text{'log_err'});

# Get the old log
$conf = &get_config();
if (!$in{'new'}) {
	@logs = &find("log", $conf);
	($log) = grep { $_->{'index'} == $in{'idx'} } @logs;
	$log || &error($text{'log_egone'});
	$old = $log;
	}
else {
	$log = { 'name' => 'log',
		  'type' => 1,
		  'members' => [ ] };
	}

&lock_all_files($conf);
if ($in{'delete'}) {
	# Just delete it!
	&save_directive($conf, undef, $log, undef, 0);
	}
else {
	# Save sources
	@oldsources = &find("source", $log->{'members'});
	foreach $s (split(/\0/, $in{'source'})) {
		push(@newsources, { 'name' => 'source',
				    'type' => 0,
				    'values' => [ $s ] });
		}
	@newsources || &error($text{'log_esource'});
	&save_multiple_directives($conf, $log, \@oldsources, \@newsources, 1);

	# Save filters
	@oldfilters = &find("filter", $log->{'members'});
	foreach $s (split(/\0/, $in{'filter'})) {
		push(@newfilters, { 'name' => 'filter',
				    'type' => 0,
				    'values' => [ $s ] });
		}
	&save_multiple_directives($conf, $log, \@oldfilters, \@newfilters, 1);

	# Save destinations
	@olddestinations = &find("destination", $log->{'members'});
	foreach $s (split(/\0/, $in{'destination'})) {
		push(@newdestinations, { 'name' => 'destination',
				    'type' => 0,
				    'values' => [ $s ] });
		}
	&save_multiple_directives($conf, $log, \@olddestinations, \@newdestinations, 1);

	# Save flags
	@flags = ( );
	foreach $f (@log_flags) {
		if ($in{$f}) {
			push(@flags, $f, ",");
			}
		}
	$fdir = undef;
	if (@flags) {
		pop(@flags);  # remove last ,
		$fdir = { 'name' => 'flags',
			  'type' => 0,
			  'values' => \@flags };
		}
	&save_directive($conf, $log, 'flags', $fdir, 1);

	# Actually update the object
	&save_directive($conf, undef, $old, $log, 0);
	}

&unlock_all_files();
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'log');
&redirect("list_logs.cgi");

