#!/usr/local/bin/perl
# XHR related routines

use strict;

our (%in, %gconfig, %access, %global_access, $root_directory, $remote_user,
     $current_theme);

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
                my $address_checker = &get_download_address_callback(
                    $global_access{'download_address_mode'},
                    $global_access{'download_allowed_addresses'});
                my $download_callback = sub {
                    if ($_[0] == 7 && defined($_[1]) && $address_checker) {
                        my $address_error = &$address_checker(
                            $host, [ $_[1] ]);
                        &error(&html_escape($address_error))
                            if ($address_error);
                        }
                    };
                &http_download($host, $port, $page, \$img, \$err,
                               $download_callback,
                               $ssl, undef, undef, 10, undef, undef,
                               undef, \$response_headers);
                # Check if download worked
                &$error("File download failed : $err")
                    if ($err);
                # Only known raster image types can be displayed inline.
                my ($type) = lc($response_headers->{'content-type'} || '') =~
                    m{^\s*(image/(?:gif|jpeg|png|webp|bmp|avif|x-icon|vnd\.microsoft\.icon))\s*(?:;|$)};
                print "x-no-links: 1\n";
                print "X-Content-Type-Options: nosniff\n";
                print "Content-Security-Policy: sandbox; default-src 'none'\n";
                print "Content-Disposition: attachment\n" if (!$type);
                print "Content-type: ".($type || 'application/octet-stream')."\n\n";
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
