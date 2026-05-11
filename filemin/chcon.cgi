#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

my $recursive;
if ($in{'recursive'} eq 'true') {
	$recursive = '-R';
	}
else {
	$recursive = '';
	}

my @errors;

if (!$in{'label'}) {
	push @errors, "$text{'context_label_error'}";
	}

if (scalar(@errors) > 0) {
	print_errors(@errors);
	}
else {
	foreach my $file (split(/\0/, $in{'name'})) {
		my $full = &validate_filename_path($file);
		if (system_logged(
			"chcon $recursive ".
			quotemeta($in{'label'}).
			" ".quotemeta($full)
			) != 0) {
			push @errors,
				(html_escape($file).
				 " - $text{'context_label_error_proc'}: $?");
			}
		}

	if (scalar(@errors) > 0) {
		print_errors(@errors);
		}
	else {
		&redirect(
			"index.cgi?path=".&urlize($path));
		}
	}
