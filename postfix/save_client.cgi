#!/usr/local/bin/perl
# Save SMTP authentication options

require './postfix-lib.pl';

&ReadParse();

$access{'client'} || &error($text{'opts_ecannot'});

&error_setup($text{'client_err'});

&lock_postfix_files();

if ($in{'client_def'}) {
	# Reset to default
	&set_current_value("smtpd_client_restrictions",
			   "__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__");
	}
else {
	# Save client options
	@opts = split(/[\s,]+/,&get_current_value("smtpd_client_restrictions"));
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
		# Find all current positions
		local @pos;
		for(my $i=0; $i<@opts; $i++) {
			push(@pos, $i) if ($opts[$i] eq $o);
			}

		# Make sure something was entered
		if ($newopts{$o}) {
			$in{"value_$o"} =~ /\S/ ||
			    &error(&text('client_evalue', $text{'sasl_'.$o}));
			}

		# Sync with values entered
		@v = split(/\s+/, $in{"value_$o"});
		for(my $i=0; $i<@pos || $i<@v; $i++) {
			if ($i<@pos && $i<@v) {
				# Updating a value
				$opts[$pos[$i]+1] = $v[$i];
				}
			elsif ($i<@pos && $i>=@v) {
				# Removing a value
				splice(@opts, $pos[$i], 2);
				}
			elsif ($i>=@pos && $i<@v) {
				# Adding a value, at the end
				push(@opts, $o, $v[$i]);
				}
			}
		}

	&set_current_value("smtpd_client_restrictions", join(" ", @opts));
	}

&unlock_postfix_files();

$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("client");
&redirect("");



