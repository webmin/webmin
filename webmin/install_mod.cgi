#!/usr/local/bin/perl
# install_mod.cgi
# Download and install a webmin module

require './webmin-lib.pl';
if ($ENV{REQUEST_METHOD} eq "POST") { &ReadParseMime(); }
else { &ReadParse(); $no_upload = 1; }

$| = 1;
$theme_no_table = 1 if ($in{'source'} == 2 || $in{'source'} == 4);
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
	$need_unlink = 1;
	if ($no_upload) {
                &inst_error($text{'install_ebrowser'});
                }
	$file = &transname(&file_basename($in{'upload_filename'}));
	open(MOD, ">$file");
	binmode(MOD);
	print MOD $in{'upload'};
	close(MOD);
	}
elsif ($in{'source'} == 2 || $in{'source'} == 4) {
	# from ftp or http url (possible third-party)
	$url = $in{'source'} == 2 ? $in{'url'} : $in{'third'};
	&error_setup(&text('install_err3', $url));
	$file = &transname(&file_basename($url));
	$need_unlink = 1;
	my $error;
	$progress_callback_url = $url;
	if ($url =~ /^(http|https):\/\/([^\/]+)(\/.*)$/) {
		$ssl = $1 eq 'https';
		$host = $2; $page = $3; $port = $ssl ? 443 : 80;
		if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
		&http_download($host, $port, $page, $file, \$error,
			       \&progress_callback, $ssl);
		}
	elsif ($url =~ /^ftp:\/\/([^\/]+)(:21)?\/(.*)$/) {
		$host = $1; $ffile = $3;
		&ftp_download($host, $ffile, $file, \$error, \&progress_callback);
		}
	else {
		&inst_error($text{'install_eurl'});
		}
	if ($in{'checksig'} && !$error) {
		$error = &check_update_signature($host, $port, $page,
			$ssl, undef, undef, $file, 2);
		}
	&inst_error($error) if ($error);
	}
elsif ($in{'source'} == 3) {
	# from www.webmin.com
	&error_setup($text{'install_err4'});
	$in{'standard'} =~ /^\S+$/ || &error($text{'install_estandard'});
	$need_unlink = 1;
	my $error;

	# Find the URL of the package
	$mods = &list_standard_modules();
	ref($mods) || &error(&text('standard_failed', $error));
	local ($info) = grep { $_->[0] eq $in{'standard'} } @$mods;
	$info || &error($text{'install_emissing'});
	if ($config{'standard_url'}) {
		($host, $port, $page, $ssl) = &parse_http_url(
						$config{'standard_url'});
		$host || &error($text{'standard_eurl'});
		}
	else {
		($host, $port, $page, $ssl) = ($standard_host, $standard_port,
					       $standard_page, $standard_ssl);
		}
	($host, $port, $page, $ssl) = &parse_http_url(
		$info->[2], $host, $port, $page, $ssl);
	$progress_callback_url = $info->[2];
	$file = &transname($info->[2]);
	&http_download($host, $port, $page, $file, \$error,
		       \&progress_callback, $ssl);
	if ($in{'checksig'} && !$error) {
		$error = &check_update_signature($host, $port, $page,
			$ssl, undef, undef, $file, 2);
		}
	&inst_error($error) if ($error);
	}

# Install the module(s)
$rv = &install_webmin_module($file, $need_unlink, $in{'nodeps'},
		       $in{'grant'} ? undef : [ split(/\s+/, $in{'grantto'}) ]);
if (ref($rv)) {
	@mdescs = @{$rv->[0]};
	@mdirs = @{$rv->[1]};
	@msizes = @{$rv->[2]};
	}
else {
	&inst_error($rv);
	}

# Display something nice for the user
&read_file("$config_directory/webmin.catnames", \%catnames);
print "$text{'install_desc'} <p>\n";
print "<ul>\n";
for($i=0; $i<@mdescs; $i++) {
	$mdirs[$i] =~ /\/([^\/]+)$/;
	if (%minfo = &get_module_info($1)) {
		# Installed a module
		my $cat = $catnames{$minfo{'category'}};
		$cat = $text{"category_".$minfo{'category'}} if (!$cat);
		$cat = $text{"category_"} if (!$cat);
		print &text($minfo{'hidden'} ? 'install_line3' :
				'install_line2', "<b>$mdescs[$i]</b>",
			    "<tt>$mdirs[$i]</tt>", $msizes[$i], $cat,
			    "../$minfo{'dir'}/"),
			    "<br>\n";
		}
	elsif (%tinfo = &get_theme_info($1)) {
		# Installed a theme
		print &text('themes_line', "<b>$mdescs[$i]</b>",
			    "<tt>$mdirs[$i]</tt>", $msizes[$i]),
			    "<br>\n";
		}
	}
print "</ul><p>\n";

if (defined(&theme_post_change_modules)) {
	&theme_post_change_modules();
	}

&ui_print_footer("edit_mods.cgi?mode=install", $text{'mods_return'},
		 "", $text{'index_return'});

sub inst_error
{
print "<b>$main::whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}

