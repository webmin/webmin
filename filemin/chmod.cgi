#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

my @errors;

# The directory ACL limits which paths can be selected. On those paths,
# chmod may set any mode the effective Unix user is allowed to set. A root
# grant therefore includes setuid and setgid even with a directory limit.
# Shared directories use setgid so new files inherit the directory's group.
my $perms = $in{'perms'};
my @names = split(/\0/, $in{'name'});
my @files;
foreach my $name (@names) {
	push(@files, [ $name, &validate_filename_path($name) ]);
	}

# Selected directories and files only
if ($in{'applyto'} eq '1') {
	foreach my $file (@files) {
		my ($name, $full) = @$file;
		if (system_logged(
			"chmod " . quotemeta($perms) . " " .
			quotemeta($full)) != 0) {
			push @errors,
				&html_escape($name)." - ".
				"$text{'error_chmod'}: $?";
			}
		}
	}

# Selected files and directories and files in
# selected directories
if ($in{'applyto'} eq '2') {
	foreach my $file (@files) {
		my ($name, $full) = @$file;
		if (system_logged(
			"chmod " . quotemeta($perms) . " " .
			quotemeta($full)) != 0) {
			push @errors,
				&html_escape($name)." - ".
				"$text{'error_chmod'}: $?";
			}
		if (-d $full) {
			if (system_logged(
				"find " .
				quotemeta($full) .
				" -maxdepth 1 -type f" .
				" -exec chmod " .
				quotemeta($perms) .
				" {} \\;") != 0) {
				push @errors,
					&html_escape($name)." - " .
					"$text{'error_chmod'}: $?";
				}
			}
		}
	}

# All (recursive)
if ($in{'applyto'} eq '3') {
	foreach my $file (@files) {
		my ($name, $full) = @$file;
		if (system_logged(
			"chmod -R " . quotemeta($perms) .
			" " .
			quotemeta($full)) != 0) {
			push @errors,
				&html_escape($name)." - ".
				"$text{'error_chmod'}: $?";
			}
		}
	}

# Selected files and files under selected directories
# and subdirectories
if ($in{'applyto'} eq '4') {
	foreach my $file (@files) {
		my ($name, $full) = @$file;
		if (-f $full) {
			if (system_logged(
				"chmod " .
				quotemeta($perms) . " " .
				quotemeta($full)) != 0) {
				push @errors,
					&html_escape($name)." - " .
					"$text{'error_chmod'}: $?";
				}
			}
		else {
			if (system_logged(
				"find " .
				quotemeta($full) .
				" -type f -exec chmod " .
				quotemeta($perms) .
				" {} \\;") != 0) {
				push @errors,
					&html_escape($name)." - " .
					"$text{'error_chmod'}: $?";
				}
			}
		}
	}

# Selected directories and subdirectories
if ($in{'applyto'} eq '5') {
	foreach my $file (@files) {
		my ($name, $full) = @$file;
		if (-d $full) {
			if (system_logged(
				"chmod " .
				quotemeta($perms) . " " .
				quotemeta($full)) != 0) {
				push @errors,
					&html_escape($name)." - " .
					"$text{'error_chmod'}: $?";
				}
			if (system_logged(
				"find " .
				quotemeta($full) .
				" -type d -exec chmod " .
				quotemeta($perms) .
				" {} \\;") != 0) {
				push @errors,
					&html_escape($name)." - " .
					"$text{'error_chmod'}: $?";
				}
			}
		}
	}

if (scalar(@errors) > 0) {
	print_errors(@errors);
	}
else {
	&redirect("index.cgi?path=" . &urlize($path));
	}
