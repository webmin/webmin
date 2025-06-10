#!/usr/local/bin/perl
# install_theme.cgi
# Download and install a usermin theme

require './usermin-lib.pl';
$access{'themes'} || &error($text{'acl_ecannot'});
if ($ENV{REQUEST_METHOD} eq "POST") { &ReadParseMime(); }
else { &ReadParse(); $no_upload = 1; }

$| = 1;
$theme_no_table = 1 if ($in{'source'} == 2);
&ui_print_header(undef, $text{'install_title'}, "");

if ($in{'source'} == 0) {
	# from local file
	&error_setup(&text('themes_err1', $in{'file'}));
	$file = $in{'file'};
	if (!(-r $file)) { &inst_error($text{'themes_efile'}); }
	}
elsif ($in{'source'} == 1) {
	# from uploaded file
	&error_setup($text{'themes_err2'});
	$file = &transname();
	$need_unlink = 1;
	if ($no_upload) {
                &inst_error($text{'themes_ebrowser'});
                }
	&open_tempfile(MOD, ">$file", 0, 1);
	&print_tempfile(MOD, $in{'upload'});
	&close_tempfile(MOD);
	}
elsif ($in{'source'} == 2) {
	# from ftp or http url
	&error_setup(&text('themes_err3', $in{'url'}));
	$file = &transname();
	$need_unlink = 1;
	$progress_callback_url = $in{'url'};
	if ($in{'url'} =~ /^(http|https):\/\/([^\/]+)(\/.*)$/) {
		$ssl = $1 eq 'https';
		$host = $2; $page = $3; $port = $ssl ? 443 : 80;
		if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
		&http_download($host, $port, $page, $file, \$error,
			       \&progress_callback, $ssl);
		}
	elsif ($in{'url'} =~ /^ftp:\/\/([^\/]+)(:21)?\/(.*)$/) {
		$host = $1; $ffile = $3;
		&ftp_download($host, $ffile, $file, \$error,
			      \&progress_callback);
		}
	else { &inst_error($text{'themes_eurl'}); }
	&inst_error($error) if ($error);
	}

# Install the theme(s)
$rv = &install_usermin_module($file, $need_unlink, 0);
if (ref($rv)) {
        @mdescs = @{$rv->[0]};
        @mdirs = @{$rv->[1]};
        @msizes = @{$rv->[2]};
        }
else {
        &inst_error($rv);
        }

# Display something nice for the user
print "$text{'themes_done'} <p>\n";
print "<ul>\n";
for($i=0; $i<@mdescs; $i++) {
	print &text('themes_line', "<b>$mdescs[$i]</b>",
		    "<tt>$mdirs[$i]</tt>", $msizes[$i]),"<p>\n";
	}
print "</ul><p>\n";
&ui_print_footer("", $text{'index_return'});

sub inst_error
{
print "<br><b>$whatfailed : $_[0]</b> <p>\n";
print &ui_hr();
&ui_print_footer("", $text{'index_return'});
exit;
}

