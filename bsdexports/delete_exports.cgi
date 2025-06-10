#!/usr/local/bin/perl
# Delete multiple exports

require './bsdexports-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

&lock_file($config{'exports_file'});
@exps = &list_exports();
foreach $d (sort { $b <=> $a } @d) {
	&delete_export($exps[$d]);
	}
&unlock_file($config{'exports_file'});
&redirect("");

