#!/usr/bin/perl

require './filemin-lib.pl';
&ReadParse();

if(!$in{'name'}) {
    &redirect("index.cgi?path=$path");
}

get_paths();
if (-e "$cwd/$in{'name'}") {
    print_errors("$in{'name'} $text{'error_exists'}");
} else {
    if(&rename_file($cwd.'/'.$in{'file'}, $cwd.'/'.$in{'name'})) {
        &redirect("index.cgi?path=$path");
    } else {
        print_errors("$text{'error_rename'} $in{'file'}: $!");
    }
}
