#!/usr/local/bin/perl
# Create, update or delete an autoreply filter

require './filter-lib.pl';
&ReadParse();

# Find existing autoreply filter object
&lock_file($procmail::procmailrc);
@filters = &list_filters();
($old) = grep { $_->{'actionreply'} } @filters;
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
	($froms, $doms) = &mailbox::list_from_addresses();
	$filter->{'reply'}->{'from'} = $froms->[0];

	# File
	$filter->{'reply'}->{'autoreply'} ||=
		"$remote_user_info[7]/autoreply.$filter->{'index'}.txt";

	# Reply period
	if ($in{'period_def'}) {
		# No autoreply period
		delete($filter->{'reply'}->{'replies'});
		delete($filter->{'reply'}->{'period'});
		}
	else {
		# Set reply period and tracking file
		$in{'period'} =~ /^\d+$/ ||
			&error($text{'save_eperiod'});
		$filter->{'reply'}->{'period'} = $in{'period'}*60;
		$filter->{'reply'}->{'replies'} ||=
			"$user_module_config_directory/replies";
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

