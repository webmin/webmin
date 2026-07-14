#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();
get_paths();

if (!$in{'link'}) {
	&redirect("index.cgi?path=".&urlize($path));
	return;
	}

my $mode;
my @errors;

my ($host, $port, $page, $ssl) =
	&parse_http_url($in{'link'});
if (!$host) {
	# Not an HTTP or FTP URL
	push(@errors, $text{'error_invalid_uri'});
	}
else {
	# Looks like a valid URL
	my $file = $page;
	$file =~ s/^.*\///;
	$file ||= "index.html";
	my $full = &validate_filename_path($file);

	if (-e $full) {
		push @errors,
			"<i>$file</i> " .
			"$text{'file_already_exists'} " .
			"<i>$path</i>";
		}
	else {
		&ui_print_header(
			undef,
			$text{'http_downloading'}, "");

		$progress_callback_url = $in{'link'};
		my @st = stat($cwd);
		my $address_checker = &get_download_address_callback(
			$access{'download_address_mode'} || 'public',
			$access{'download_allowed_addresses'});
		my $download_callback = sub {
			if ($_[0] == 7 && defined($_[1]) && $address_checker) {
				my $address_error = &$address_checker(
					$host, [ $_[1] ]);
				&error(&html_escape($address_error)) if ($address_error);
				}
			&progress_callback(@_);
			};
		if ($ssl == 0 || $ssl == 1) {
			# HTTP or HTTPS download
			&http_download(
				$host, $port, $page,
				$full, undef,
				$download_callback,
				$ssl, $in{'username'},
				$in{'password'});
			}
		else {
			# Actually an FTP download
			&ftp_download(
				$host, $page, $full,
				undef,
				$download_callback,
				$in{'username'},
				$in{'password'}, $port);
			}
		&set_ownership_permissions(
			$st[4], $st[5], undef, $full);
		@st = stat($cwd);
		print &text('http_done',
			&nice_size($st[7]),
			"<tt>".&html_escape($full).
			"</tt>"),"<p>\n";
		&ui_print_footer(
			"index.cgi?path=".&urlize($path),
			$text{'previous_page'});
		}
	}

if (scalar(@errors) > 0) {
	print_errors(@errors);
	}
