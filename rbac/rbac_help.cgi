#!/usr/local/bin/perl
# Show an RBAC help page

require './rbac-lib.pl';
&ReadParse();

$hf = $in{'help'};
&is_under_directory($config{'auth_help_dir'}, $hf) ||
  &is_under_directory($config{'prof_help_dir'}, $hf) ||
  &error($text{'help_epath'});

&PrintHeader();
open(HELP, "<$hf");
while(<HELP>) {
	print $_;
	}
close(HELP);

