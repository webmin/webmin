#!/usr/local/bin/perl
# Save SMTP authentication options

require './postfix-lib.pl';

&ReadParse();

$access{'client'} || &error($text{'opts_ecannot'});

&error_setup($text{'client_err'});

&lock_postfix_files();

# Save client options
@opts = split(/[\s,]+/, &get_current_value("smtpd_client_restrictions"));
%oldopts = map { $_, 1 } @opts;
%newopts = map { $_, 1 } split(/\0/, $in{'client'});

# Save boolean options
foreach $o (&list_client_restrictions()) {
	if ($newopts{$o} && !$oldopts{$o}) {
		push(@opts, $o);
		}
	elsif (!$newopts{$o} && $oldopts{$o}) {
		@opts = grep { $_ ne $o } @opts;
		}
	}

# Save options with values
foreach $o (&list_multi_client_restrictions()) {
	$idx = &indexof($o, @opts);
	if ($newopts{$o}) {
		$in{"value_$o"} =~ /^\S+$/ ||
			&error(&text('client_evalue', $text{'sasl_'.$o}));
		}
	if ($newopts{$o} && !$oldopts{$o}) {
		# Add to end
		push(@opts, $o, $in{"value_$o"});
		}
	elsif ($newopts{$o} && $oldopts{$o}) {
		# Update value
		$opts[$idx+1] = $in{"value_$o"};
		}
	elsif (!$newopts{$o} && $oldopts{$o}) {
		# Remove and value
		splice(@opts, $idx, 2);
		}
	}

&set_current_value("smtpd_client_restrictions", join(" ", &unique(@opts)));

&unlock_postfix_files();

&reload_postfix();

&webmin_log("client");
&redirect("");



