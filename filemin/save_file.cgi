#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

my @errors;

$file = &simplify_path($in{'file'});
my $error = 1;
for $allowed_path (@allowed_paths) {
	if (&is_under_directory($allowed_path, $file)) {
		$error = 0;
		}
	}
$error && &error(&text('notallowed', &html_escape($file),
		   &html_escape(join(" , ", @allowed_paths))));
$data = $in{'data'};
$data =~ s/\r\n/\n/g;

if ( $in{'encoding'} && lc( $in{'encoding'} ) ne "utf-8" ) {
    eval { $data = Encode::encode( $in{'encoding'}, Encode::decode( 'utf-8', $data ) ) };
}
open(SAVE, ">", $cwd.'/'.$file) or push @errors, "$text{'error_saving_file'} - $!";
print SAVE $data;
close SAVE;

if (scalar(@errors) > 0) {
    &ui_print_header(undef, $module_info{'name'}, "");
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
