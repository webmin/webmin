#!/usr/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

my @errors;

$file = $in{'file'};
$data = $in{'data'};
$data =~ s/\r\n/\n/g;
open(SAVE, ">", $cwd.'/'.$file) or push @errors, "$text{'error_saving_file'} - $!";
print SAVE $data;
close SAVE;

if (scalar(@errors) > 0) {
    &ui_print_header(undef, "Filemin", "");
    print $text{'errors_occured'};
    print "<ul>";
    foreach $error(@errors) {
        print("<li>$error</li>");
    }
    print "<ul>";
    &ui_print_footer("javascript:history.back();", $text{'previous_page'});
} elsif ($in{'save_close'}) {
    &redirect("index.cgi?path=$path");
} else {
    &redirect("edit_file.cgi?path=$path&file=$in{'file'}");
}
