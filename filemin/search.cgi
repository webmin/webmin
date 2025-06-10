#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

$query = $in{'query'};

&ui_print_header(undef, $text{'search_results'}." '".
			&html_escape($query)."'", "");

print $head;
if($in{'caseins'}) {
    $criteria = '-iname';
} else {
    $criteria = '-name'
}
@list = split('\n', &backquote_logged(
                "find ".quotemeta($cwd)." $criteria ".quotemeta("*$in{'query'}*")));
@list = map { [ $_, stat($_), &clean_mimetype($_), -d $_ ] } @list;

print_interface();

&ui_print_footer("index.cgi?path=".&urlize($path), $text{'previous_page'});
