#!/usr/local/bin/perl
# Create, update or delete an autoreply filter

require './filter-lib.pl';
&ReadParse();
&error_setup($text{'auto_err'});
use Time::Local;

# Find existing autoreply filter object
&lock_file($procmail::procmailrc);
@filters = &list_filters();
($old) = grep { $_->{'actionreply'} && $_->{'nocond'} } @filters;
$filter = $old;

if ($filter && !$in{'enabled'}) {
	# Just delete
	&delete_filter($filter);
	}
elsif ($in{'enabled'}) {
	# Create or update
	if (!$filter) {
		$filter = { 'actionreply' => 1,
			    'body' => 0,
			    'continue' => 1 };
		}
	$in{'reply'} =~ /\S/ || &error($text{'save_ereply'});
	$in{'reply'} =~ s/\r//g;
	$filter->{'reply'}->{'autotext'} = $in{'reply'};

	# From address (automatic)
	$filter->{'reply'}->{'from'} = &mailbox::get_preferred_from_address();

	# File
	$idx = defined($filter->{'index'}) ? $filter->{'index'}
					   : scalar(@filters);
	$filter->{'reply'}->{'autoreply'} ||=
		"$remote_user_info[7]/autoreply.$idx.txt";

	# Reply period
	if ($config{'reply_force'}) {
		# Forced to minimum
		$min = $config{'reply_min'} || 60;
		$filter->{'reply'}->{'period'} = $min*60;
		$filter->{'reply'}->{'replies'} ||=
			"$user_module_config_directory/replies";
		}
	elsif ($in{'period_def'}) {
		# No autoreply period
		delete($filter->{'reply'}->{'replies'});
		delete($filter->{'reply'}->{'period'});
		}
	else {
		# Set reply period and tracking file
		$in{'period'} =~ /^\d+$/ ||
			&error($text{'save_eperiod'});
		if ($config{'reply_min'} &&
		    $in{'period'} < $config{'reply_min'}) {
			&error(&text('save_eperiodmin', $config{'reply_min'}));
			}
		$filter->{'reply'}->{'period'} = $in{'period'}*60;
		$filter->{'reply'}->{'replies'} ||=
			"$user_module_config_directory/replies";
		}

	# Save character set
	if ($in{'charset_def'} == 1) {
		delete($filter->{'reply'}->{'charset'});
		}
	elsif ($in{'charset_def'} == 2) {
		$filter->{'reply'}->{'charset'} = &get_charset();
		}
	else {
		$in{'charset'} =~ /^[a-z0-9\.\-\_]+$/i ||
			error($text{'save_echarset'});
		$filter->{'reply'}->{'charset'} = $in{'charset'};
		}

	# Save subject
	if ($in{'subject_def'}) {
		delete($filter->{'reply'}->{'subject'});
		}
	else {
		$filter->{'reply'}->{'subject'} = $in{'subject'};
		}

	# Save autoreply start and end
	foreach $p ('start', 'end') {
		local ($s, $m, $h) = $p eq 'start' ? (0, 0, 0) :
					(59, 59, 23);
		if (!$in{$p.'_def'}) {
			eval {
				$tm = timelocal($s, $m, $h, $in{'d'.$p},
				    $in{'m'.$p}-1, $in{'y'.$p}-1900);
				};
			$tm || &error($text{'save_e'.$p});
			$filter->{'reply'}->{'autoreply_'.$p} = $tm;
			}
		else {
			delete($filter->{'reply'}->{'autoreply_'.$p});
			}
		}

	if ($old) {
		&modify_filter($filter);
		}
	else {
		&insert_filter($filter);
		}
	}

&unlock_file($procmail::procmailrc);
&redirect("");

