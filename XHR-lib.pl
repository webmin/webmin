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
            # Using pre-saved temp link
            if ($in{'kind'} eq "templink") {
                my $bfile = &tempname($in{'file'});
                if (-r $bfile) {
                    my $url = &read_file_contents($bfile);
                    &unlink_file($bfile);
                    my ($host, $port, $page, $ssl) = &parse_http_url($url);
                    my $img;
                    &http_download($host, $port, $page, \$img, undef, undef, $ssl, undef, undef, 10);
                    print "Content-type: @{[&guess_mime_type($url)]};\n\n";
                    print $img;
                    exit;
                    }
                }
            # Print Blob

            }
        }
    }
&$output(\%data);
}

1;
