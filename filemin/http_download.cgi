#!/usr/bin/perl

require './filemin-lib.pl';
use lib './lib';

&ReadParse();
get_paths();

if(!$in{'link'}) {
    &redirect("index.cgi?path=$path");
}

my $mode;
my @errors;

my ($host, $port, $page, $ssl) = &parse_http_url($in{'link'});
if (!$host) {
    # Not an HTTP or FTP URL
    push @errors, $text{'error_invalid_uri'};
} else {
    # Looks like a valid URL
    my $file = $page;
    $file =~ s/^.*\///;
    $file ||= "index.html";

    if(-e "$cwd/$file") {
        push @errors, "<i>$file</i> $text{'file_already_exists'} <i>$path</i>";
    } else {
        &ui_print_header(undef, "$text{'http_downloading'} $file", "");
	if ($ssl == 0 || $ssl == 1) {
	    # HTTP or HTTPS download
	    &http_download($host, $port, $page, "$cwd/$file", undef,
			   \&progress_callback, $ssl,
			   $in{'username'}, $in{'password'});
	} else {
	    # Actually an FTP download
	    &ftp_download($host, $page, "$cwd/$file", undef,
			  \&progress_callback,
			  $in{'username'}, $in{'password'}, $port);
	}
        &ui_print_footer("index.cgi?path=$path", $text{'previous_page'});
   }
}

if (scalar(@errors) > 0) {
    print_errors(@errors);
}