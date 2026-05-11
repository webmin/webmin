#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

if (!$in{'name'}) {
	&redirect("index.cgi?path=".&urlize($path));
	}

get_paths();
my $file = $in{'file'};
my $name = $in{'name'};
my $from = &validate_filename_path($file);
my $to = &validate_filename_path($name);
if (-e $to) {
	print_errors("$name $text{'error_exists'}");
	}
else {
	my $from_dir = $from;
	my $to_dir = $to;
	$from_dir =~ s/\/[^\/]*$//;
	$to_dir =~ s/\/[^\/]*$//;
	$from_dir ||= "/";
	$to_dir ||= "/";
	if (!can_move($from, $from_dir, $to_dir)) {
		print_errors(
			"$file - $text{'error_move'}");
		}
	elsif (&rename_file($from, $to)) {
		&redirect("index.cgi?path=".
			&urlize($path));
		}
	else {
		print_errors(
			"$text{'error_rename'} $file: $!");
		}
	}
