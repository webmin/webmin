#!/usr/local/bin/perl
# XHR related routines

use strict;

our (%in, %gconfig, $root_directory, $remote_user, $current_theme);

sub xhr
{

my %data    = ();
my $output_json  = sub {
    my ($data) = @_;
    print "x-no-links: 1\n";
    print_json($data);
    };
my $error  = sub {
    my ($err) = @_;
    $data{'error'} = $err;
    &$output_json(\%data);
    exit;
    };

# Fetch actions
if ($in{'action'} eq "fetch") {
    # Download types
    if ($in{'type'} eq "download") {
        # Format Blob format
        if ($in{'subtype'} eq "blob") {
            # Download using giving URL
            my $url = $in{'url'};
            if ($url) {
                # Unescape possibly HTML escaped
                # image URL (LinkedIn and other)
                $url = &html_unescape($url);
                my ($host, $port, $page, $ssl) = &parse_http_url($url);
                my ($img, $err, $response_headers);
                &http_download($host, $port, $page, \$img, \$err, undef,
                               $ssl, undef, undef, 10, undef, undef,
                               undef, \$response_headers);
                # Check if download worked
                &$error("File download failed : $err")
                    if ($err);
                # Get MIME content type
                my $mime_type = $response_headers->{'content-type'};
                print "x-no-links: 1\n";
                print "Content-type: $mime_type;\n\n";
                print $img;
                exit;
                }
            &$error("File URL is missing")
            }
        &$error("Downloading file failed")
        }
    &$error("Fetching file failed");
    }
else {
    &$error("Unknown request");
    }
&$output_json(\%data);
}

1;
