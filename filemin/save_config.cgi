#!/usr/local/bin/perl

require './filemin-lib.pl';
require '../config-lib.pl';
&ReadParse();

get_paths();

$columns = $in{'columns'};
$columns =~ s/\0/,/g;
&error("$text{'config_per_page'} $text{'error_numeric'}") unless($in{'per_page'} eq int($in{'per_page'}));
%config = (
    'columns' => $columns,
    'per_page' => $in{'per_page'},
    'config_portable_module_filemanager_editor_detect_encoding' => $in{'config_portable_module_filemanager_editor_detect_encoding'},
    'config_portable_module_filemanager_show_dot_files' => $in{'config_portable_module_filemanager_show_dot_files'},
);
my $max_allowed = $in{'max_allowed'};
if($max_allowed) {
    $config{'max_allowed'} = $max_allowed;
}

&write_file("$confdir/.config", \%config);
&save_module_preferences($module_name, \%config);

$bookmarks = $in{'bookmarks'};
$bookmarks =~ s/\r\n/\n/g;
open(BOOK, ">", "$confdir/.bookmarks") or $info = $!;
print BOOK $bookmarks;
close BOOK;

&redirect("index.cgi?path=".&urlize($path));
