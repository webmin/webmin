#!/usr/local/bin/perl

require './filemin-lib.pl';
use lib './lib';

&ReadParse();
get_paths();

if (!$in{'link'}) {
	&redirect("index.cgi?path=".&urlize($path));
	return;
	}

my $mode;
my @errors;

my ($host, $port, $page, $ssl) = &parse_http_url($in{'link'});
if (!$host) {
	# Not an HTTP or FTP URL
	push(@errors, $text{'error_invalid_uri'});
	}
else {
	# Looks like a valid URL
	my $file = $page;
	$file =~ s/^.*\///;
	$file ||= "index.html";
	$full = "$cwd/$file";

	if (-e $full) {
		push @errors, "<i>$file</i> $text{'file_already_exists'} <i>$path</i>";
		}
	else {
		&ui_print_header(undef, $text{'http_downloading'}, "");

		$progress_callback_url = $in{'link'};
		my @st = stat($cwd);
		if ($ssl == 0 || $ssl == 1) {
			# HTTP or HTTPS download
			&http_download($host, $port, $page, $full, undef,
				       \&progress_callback, $ssl,
				       $in{'username'}, $in{'password'});
			}
		else {
			# Actually an FTP download
			&ftp_download($host, $page, $full, undef,
				      \&progress_callback,
				      $in{'username'}, $in{'password'}, $port);
			}
		&set_ownership_permissions($st[4], $st[5], undef, $full);
		@st = stat($cwd);
		print &text('http_done', &nice_size($st[7]),
			    "<tt>".&html_escape($full)."</tt>"),"<p>\n";
		&ui_print_footer("index.cgi?path=".&urlize($path),
				 $text{'previous_page'});
		}
	}

if (scalar(@errors) > 0) {
	print_errors(@errors);
	}
