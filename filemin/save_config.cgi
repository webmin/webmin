#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

$columns = $in{'columns'};
$columns =~ s/\0/,/g;
&error("$text{'config_per_page'} $text{'error_numeric'}") unless($in{'per_page'} eq int($in{'per_page'}));
%config = (
    'columns' => $columns,
    'per_page' => $in{'per_page'},
    'disable_pagination' => $in{'disable_pagination'},
    'menu_style' => $in{'menu_style'}
);

&write_file("$confdir/.config", \%config);

$bookmarks = $in{'bookmarks'};
$bookmarks =~ s/\r\n/\n/g;
open(BOOK, ">", "$confdir/.bookmarks") or $info = $!;
print BOOK $bookmarks;
close BOOK;

&redirect("index.cgi?path=".&urlize($path));
