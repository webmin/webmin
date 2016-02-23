#!/usr/bin/perl

require './filemin-lib.pl';
use lib './lib';

&ReadParse();

get_paths();

$confdir = "$remote_user_info[7]/.filemin";
if(!-e $confdir) {
    mkdir $confdir or &error("$text{'error_creating_conf'}: $!");
}

if(!-e "$confdir/.bookmarks") {
    utime time, time, "$configdir/.bookmarks";
}

$bookmarks = &read_file_lines($confdir.'/.bookmarks');
push @$bookmarks, $path;
&flush_file_lines("$confdir/.bookmarks");

&redirect("index.cgi?path=$path");
