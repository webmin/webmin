#!/usr/local/bin/perl
# Create, update or delete a mailcap entry

require './mailcap-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});
@mailcap = &list_mailcap();

if (!$in{'new'}) {
	($mailcap) = grep { $_->{'index'} == $in{'index'} } @mailcap;
	$mailcap || &error($text{'edit_egone'});
	}
else {
	$mailcap = { 'args' => { } };
	}

&lock_file($mailcap_file);
if ($in{'delete'}) {
	# Just trash one
	&delete_mailcap($mailcap);
	}
else {
	# Validate inputs
	$in{'type'} =~ /([a-z0-9\-]+)\/([a-z0-9\-\*]+)/ ||
		&error($text{'save_etype'});
	#if (($in{'new'} || $in{'old'} ne $in{'type'}) && $in{'enabled'}) {
	#    ($clash) = grep { $_->{'type'} eq $in{'type'} &&
	#		      $_->{'enabled'} == 1 } @mailcap;
	#    $clash && &error($text{'save_eclash'});
	#    }
        $mailcap->{'type'} = $in{'type'};
        $mailcap->{'enabled'} = $in{'enabled'};
	$in{'program'} ||
		&error($text{'save_eprogram'});
        $mailcap->{'program'} = $in{'program'};
	$in{'cmt'} =~ s/\r//g;
	$in{'cmt'} =~ s/\s*$//g;
	$mailcap->{'cmt'} = $in{'cmt'};

	# Save extra args
	$args = $mailcap->{'args'};
	if ($in{'test_def'}) {
		delete($args->{'test'});
		}
	else {
		$in{'test'} =~ /\S/ && $in{'test'} !~ /;/ ||
			&error($text{'save_etest'});
		$args->{'test'} = $in{'test'};
		}
	if ($in{'term'}) {
		$args->{'needsterminal'} = '';
		}
	else {
		delete($args->{'needsterminal'});
		}
	if ($in{'copious'}) {
		$args->{'copiousoutput'} = '';
		}
	else {
		delete($args->{'copiousoutput'});
		}
	if ($in{'desc_def'}) {
		delete($args->{'description'});
		}
	else {
		$in{'desc'} !~ /;/ || &error($text{'save_edesc'});
		$args->{'description'} = $in{'desc'};
		}
	
	# Update in file
	if ($in{'new'}) {
	      &create_mailcap($mailcap);
	      }
	else {
	      &modify_mailcap($mailcap);
	      }
	}
&unlock_file($mailcap_file);
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "mailcap", $in{'old'} || $in{'type'});
&redirect("");

