#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

if (!$in{'name'}) {
	&redirect("index.cgi?path=".&urlize($path));
	return;
	}

my $full = "$cwd/$in{'name'}";
if (-e $full) {
	print_errors(&html_escape($in{'name'})." ".$text{'error_exists'});
	}
else {
	my @st = stat($cwd);
	if (open(my $fh, ">$full")) {
		close($fh);
		&set_ownership_permissions($st[4], $st[5], undef, $full);
		&redirect("index.cgi?path=".&urlize($path));
		}
	else {
		print_errors($text{'error_create'}." ".
			     &html_escape($in{'name'})." : ".$!);
		}
	}

