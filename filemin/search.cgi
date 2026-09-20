#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

$query = $in{'query'};

&ui_print_header(
	undef,
	$text{'search_results'} . " '" .
	&html_escape($query) . "'", "");

print $head;
if ($in{'caseins'}) {
	$criteria = '-iname';
	}
else {
	$criteria = '-name'
	}
@list = split('\n', &backquote_logged(
	"find ".quotemeta($cwd).
	" $criteria ".
	quotemeta("*$in{'query'}*")));
if (&test_allowed_paths()) {
	my @alist;
	foreach my $path (@allowed_paths) {
		my $slashed = $path;
		$slashed .= "/" if ($slashed !~ /\/$/);
		push(@alist, grep { $_ eq $path ||
			       $_ =~ /^\Q$slashed\E/ } @list);
		}
	@list = &unique(@alist);
	}
@list = map {
	[$_, stat($_), &clean_mimetype($_), -d $_]
	} @list;

print_interface();

&ui_print_footer(
	"index.cgi?path=".&urlize($path),
	$text{'previous_page'});
