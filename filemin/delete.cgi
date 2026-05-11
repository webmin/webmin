#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

my @errors;

foreach $name (split(/\0/, $in{'name'})) {
	my $full = &validate_filename_path($name);
	if (!can_write($full)) {
		push @errors,
			"$name - $text{'error_write'}";
		next;
		}
	if (!&unlink_file($full)) {
		push @errors,
			"$name - $text{'error_delete'}: $!";
		}
	}

if (scalar(@errors) > 0) {
	print_errors(@errors);
	}
else {
	&redirect("index.cgi?path=".&urlize($path));
	}
