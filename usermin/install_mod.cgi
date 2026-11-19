#!/usr/local/bin/perl
# install_mod.cgi
# Download and install a usermin module

require './usermin-lib.pl';
$access{'umods'} || &error($text{'acl_ecannot'});
if ($ENV{REQUEST_METHOD} eq "POST") { &ReadParseMime(); }
else { &ReadParse(); $no_upload = 1; }

$| = 1;
$theme_no_table = 1 if ($in{'source'} == 2);
&ui_print_header(undef, $text{'install_title'}, "");

if ($in{'source'} == 0) {
	# from local file
	&error_setup(&text('install_err1', $in{'file'}));
	$file = $in{'file'};
	if (!(-r $file)) { &inst_error($text{'install_efile'}); }
	}
elsif ($in{'source'} == 1) {
	# from uploaded file
	&error_setup($text{'install_err2'});
	$file = &transname();
	$need_unlink = 1;
	if ($no_upload) {
                &inst_error($text{'install_ebrowser'});
                }
	&open_tempfile(MOD, ">$file", 0, 1);
	&print_tempfile(MOD, $in{'upload'});
	&close_tempfile(MOD);
	}
elsif ($in{'source'} == 2) {
	# from ftp or http url
	&error_setup(&text('install_err3', $in{'url'}));
	$file = &transname();
	$need_unlink = 1;
	local $error;
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
		&ftp_download($host, $ffile, $file, \$error, \&progress_callback);
		}
	else { &inst_error($text{'install_eurl'}); }
	&inst_error($error) if ($error);
	}

# Install the module(s)
$rv = &install_usermin_module($file, $need_unlink, $in{'nodeps'});
if (ref($rv)) {
        @mdescs = @{$rv->[0]};
        @mdirs = @{$rv->[1]};
        @msizes = @{$rv->[2]};
        }
else {
        &inst_error($rv);
        }

# Display something nice for the user
print "$text{'install_desc'} <p>\n";
print "<ul>\n";
for($i=0; $i<@mdescs; $i++) {
	$mdirs[$i] =~ /\/([^\/]+)$/;
	if (%minfo = &get_usermin_module_info($1)) {
		# Installed a module
		local $cat = $text{"category_".$minfo{'category'}};
		$cat = $text{"category_"} if (!$cat);
		print &text($minfo{'hidden'} ? 'install_line3' :
				'install_line2', "<b>$mdescs[$i]</b>",
			    "<tt>$mdirs[$i]</tt>", $msizes[$i], $cat),
			    "<br>\n";
		}
	elsif (%tinfo = &get_usermin_theme_info($1)) {
		# Installed a theme
		print &text('themes_line', "<b>$mdescs[$i]</b>",
			    "<tt>$mdirs[$i]</tt>", $msizes[$i]),
			    "<br>\n";
		}
	}
print "</ul><p>\n";
&ui_print_footer("edit_mods.cgi?mode=install", $text{'mods_return'},
		 "", $text{'index_return'});

sub inst_error
{
print "<b>$whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

