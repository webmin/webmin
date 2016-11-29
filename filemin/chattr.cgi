#!/usr/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

my $recursive;

if($in{'recursive'} eq 'true') { $recursive = '-R'; } else { $recursive = ''; }

my @errors;
if(!$in{'label'}) {
    push @errors, "$text{'attr_label_error'}";
}

my $label = quotemeta("$in{'label'}");
$label =~ s/\\-/-/g;
$label =~ s/\\+//g;
$label =~ tr/a-zA-Z\-\+ //dc;

if (scalar(@errors) > 0) {
        print_errors(@errors);
} else {
    foreach my $file (split(/\0/, $in{'name'})) {
        $file =~ s/\.\.//g;
        &simplify_path($file);
        if(
            system_logged(
                "chattr $recursive " . $label . " " . quotemeta("$cwd/$file")
                ) != 0) {
            push @errors, "$file - $text{'attr_label_error_proc'}: $?";
        }
    }

    if (scalar(@errors) > 0) {
        print_errors(@errors);
    } else {
        &redirect("index.cgi?path=$path");
    }
}
