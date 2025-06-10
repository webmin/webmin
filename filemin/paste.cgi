#!/usr/local/bin/perl

require './filemin-lib.pl';
use Cwd 'abs_path';
&ReadParse();

get_paths();

open(my $fh, "<".&get_paste_buffer_file()) or die "Error: $!";
my @arr = <$fh>;
close($fh);
my $act = $arr[0];
my $dir = $arr[1];
chomp($act);
chomp($dir);
$from = abs_path($base.$dir);
if ($cwd eq $from) {
    print_errors($text{'error_pasting_nonsence'});
} else {
    my @errors;
    for(my $i = 2;$i <= scalar(@arr)-1;$i++) {
        chomp($arr[$i]);
        if ($act eq "copy") {
            if (-e "$cwd/$arr[$i]") {
                push @errors, "$cwd/$arr[$i] $text{'error_exists'}";
            } else {
                system("cp -r ".quotemeta("$from/$arr[$i]").
		       " ".quotemeta($cwd)) == 0 or push @errors, "$from/$arr[$i] $text{'error_copy'} $!";
            }
        }
        elsif ($act eq "cut") {
            if (!can_move("$from/$arr[$i]", $cwd, $from)) {
                push @errors, "$from/$arr[$i] - $text{'error_move'}";
            }
            elsif (-e "$cwd/$arr[$i]") {
                push @errors, "$cwd/$arr[$i] $text{'error_exists'}";
            } else {
                system("mv ".quotemeta("$from/$arr[$i]").
		       " ".quotemeta($cwd)) == 0 or push @errors, "$from/$arr[$i] $text{'error_cut'} $!";
            }
        }
    }
    if (scalar(@errors) > 0) {
        print_errors(@errors);
    } else {
        &redirect("index.cgi?path=".&urlize($path));
    }
}
