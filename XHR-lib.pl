#!/usr/local/bin/perl
# A pile of XHR related routines

use strict;

our (%in, %gconfig, $root_directory, $remote_user, $current_theme);

sub xhr
{

my %data    = ();
my $output  = sub {
    my ($data) = @_;
    print "x-no-links: 1\n";
    print_json($data);
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
                my ($img, $response_headers);
                &http_download($host, $port, $page, \$img, undef, undef, $ssl, undef, undef, 10, undef, undef, undef, \$response_headers);
                # Get MIME content type
                my $mime_type = $response_headers->{'content-type'};
                if ($mime_type !~/image\//) {
                    eval "use File::MimeInfo";
                    my $img_tmp = &transname();
                    &write_file_contents($img_tmp, $img);
                    $mime_type = mimetype($img_tmp);
                    }
                print "x-no-links: 1\n";
                print "Content-type: $mime_type;\n\n";
                print $img;
                exit;
                }
            }
        }
    }
&$output(\%data);
}

1;
