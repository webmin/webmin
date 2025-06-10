#!/usr/local/bin/perl
# Create, update or delete a forwarding filter

require './filter-lib.pl';
&ReadParse();
&error_setup($text{'forward_err'});

# Find existing forwarding filter object
&lock_file($procmail::procmailrc);
@filters = &list_filters();
($old) = grep { $_->{'actiontype'} eq '!' && $_->{'nocond'} } @filters;
$filter = $old;

if ($filter && !$in{'enabled'}) {
	# Just delete
	&delete_filter($filter);
	}
elsif ($in{'enabled'}) {
	# Create or update
	if (!$filter) {
		$filter = { 'actiontype' => '!',
			    'body' => 0,
			    'nobounce' => 1 };
		}
	$filter->{'continue'} = $in{'continue'};
	$in{'forward'} =~ /\S/ || &error($text{'save_eforward'});
	$in{'forward'} =~ s/^\s+//;
	$in{'forward'} =~ s/\s+$//;
	$in{'forward'} =~ s/\s+/,/g;
	$filter->{'action'} = $in{'forward'};

	if ($old) {
		&modify_filter($filter);
		}
	else {
		# Forwarding should go last
		&create_filter($filter);
		}
	}

&unlock_file($procmail::procmailrc);
&redirect("");

