#!/usr/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

if(!$in{'name'}) {
    &redirect("index.cgi?path=$path");
}

if (-e "$cwd/$in{'name'}") {
    print_errors("$in{'name'} $text{'error_exists'}");
} else {
    if( mkdir ("$cwd/$in{'name'}", oct(755)) ) {
        &redirect("index.cgi?path=$path");
    } else {
        print_errors("$text{'error_create'} $in{'name'}: $!");
    }
}
