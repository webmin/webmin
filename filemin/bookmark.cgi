#!/usr/local/bin/perl

require './filemin-lib.pl';
use lib './lib';

&ReadParse();

&get_paths();

if(!-e "$confdir/.bookmarks") {
    utime time, time, "$configdir/.bookmarks";
}

$bookmarks = &read_file_lines($confdir.'/.bookmarks');
push @$bookmarks, $path;
&flush_file_lines("$confdir/.bookmarks");

&redirect("index.cgi?path=".&urlize($path));
