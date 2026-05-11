#!/usr/local/bin/perl

require './filemin-lib.pl';
use Cwd 'abs_path';
&ReadParse();

get_paths();

open(my $fh, "<".&get_paste_buffer_file())
	or die "Error: $!";
my @arr = <$fh>;
close($fh);
my $act = $arr[0];
my $dir = $arr[1];
chomp($act);
chomp($dir);
$from = abs_path($base.$dir);
if (!defined($from)) {
	print_errors($text{'error_pasting_nonsence'});
	}
elsif ($cwd eq $from) {
	print_errors($text{'error_pasting_nonsence'});
	}
else {
	&check_allowed_path($from);
	my @errors;
	for (my $i = 2; $i <= scalar(@arr) - 1; $i++) {
		chomp($arr[$i]);
		my $name = $arr[$i];
		my $source;
		{
		local $cwd = $from;
		$source = &validate_filename_path($name);
		}
		my ($target_name) = fileparse($source);
		my $target = &validate_filename_path($target_name);
		if ($act eq "copy") {
			if (-e $target) {
				push @errors,
					"$target " .
					"$text{'error_exists'}";
				}
			else {
				system("cp -r ".
					quotemeta($source).
					" ".quotemeta($cwd)
					) == 0 ||
				push @errors,
					"$source " .
					"$text{'error_copy'}" .
					" $!";
				}
			}
		elsif ($act eq "cut") {
			if (!can_move($source, $from, $cwd)) {
				push @errors,
					"$source" .
					" - " .
					"$text{'error_move'}";
				}
			elsif (-e $target) {
				push @errors,
					"$target " .
					"$text{'error_exists'}";
				}
			else {
				system("mv ".
					quotemeta($source).
					" ".quotemeta($cwd)
					) == 0 ||
				push @errors,
					"$source " .
					"$text{'error_cut'}" .
					" $!";
				}
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
