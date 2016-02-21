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
    if (open my $fh, "> $cwd/$in{'name'}") {
        close($fh);
        &redirect("index.cgi?path=$path");
    } else {
        print_errors("$in{'name'} - $text{'error_create'} $!");
    }
}
