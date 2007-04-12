#!/usr/local/bin/perl
# save_auth.cgi
# Save commands and allowed users

require './mon-lib.pl';
&ReadParse();
&error_setup($text{'auth_err'});

@types = &unique(split(/\s+/, $in{'types'}), &list_auth_types());
foreach $t (@types) {
	local $m = $in{"${t}_mode"};
	if ($m == 2) {
		$out .= "$t:\n";
		}
	elsif ($m == 1) {
		$out .= "$t:\tall\n";
		}
	elsif ($m == 0) {
		local @users = split(/\s+/, $in{$t});
		@users || &error(&text('auth_eusers', $t));
		$out .= "$t:\t".join(",", @users)."\n";
		}
	}

$file = &mon_auth_file();
&open_tempfile(FILE, ">$file");
&print_tempfile(FILE, $out);
&close_tempfile(FILE);

&redirect("");

