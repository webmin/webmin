#!/usr/local/bin/perl
# Delete multiple mailcap entries

require './mailcap-lib.pl';
&ReadParse();
$mode = $in{'delete'} ? 'delete' :
        $in{'disable'} ? 'disable' : 'enable';
&error_setup($text{$mode.'_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});
@mailcap = &list_mailcap();

# Do the delete
&lock_file($mailcap_file);
foreach $d (@d) {
	($mailcap) = grep { $_->{'index'} == $d } @mailcap;
	$mailcap || &error($text{'edit_egone'});
	if ($mode eq 'delete') {
	        &delete_mailcap($mailcap);
		}
	elsif ($mode eq 'disable' && $mailcap->{'enabled'} == 1) {
	        $mailcap->{'enabled'} = 0;
	        &modify_mailcap($mailcap);
		}
	elsif ($mode eq 'enable' && $mailcap->{'enabled'} == 0) {
	        #($clash) = grep { $_->{'type'} eq $mailcap->{'type'} &&
		#		  $_->{'enabled'} == 1 } @mailcap;
	        #$clash && &error(&text('enable_eclash', $type));
	        $mailcap->{'enabled'} = 1;
	        &modify_mailcap($mailcap);
		}
	}
&unlock_file($mailcap_file);
&webmin_log($mode, "mailcaps", scalar(@d));

&redirect("");

