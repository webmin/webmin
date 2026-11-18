#!/usr/local/bin/perl
# view_log.cgi
# Display the report for some log file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %config, %gconfig, %access, $module_name, %in, $remote_user);
require './webalizer-lib.pl';
&ReadParse();

# A /raw/ part before the file name requests the report itself, for use in a
# sandboxed frame. Relative links in the report keep that part.
my ($escaped, $raw, $file, $log);
if ($ENV{'PATH_INFO'} =~ /^\/([^\/]+)(\/raw)?(\/[^\/]*)$/) {
	# Proper path escaping
	$escaped = $1;
	$raw = $2;
	$file = $3;
	$log = &un_urlize($escaped);
	}
elsif ($ENV{'PATH_INFO'} =~ /^(\/.*?)(\/raw)?(\/[^\/]*)$/) {
	# Path has been decode somehow, perhaps by proxy.. deal
	$log = $1;
	$raw = $2;
	$file = $3;
	}
else {
	&error($text{'view_epath'});
	}

($file =~ /\.\./ || $file =~ /\<|\>|\||\0/) && &error($text{'view_efile'});
&can_edit_log($log) || &error($text{'view_ecannot'});

my $lconf = &get_log_config($log) ||
	&error($text{'view_elog'}." : ".&html_escape($log));
my $full = $lconf->{'dir'}.$file;
# Resolve symlinks before removing .. from either path.
my $dir = &simplify_path(&resolve_links($lconf->{'dir'}));
my $path = &simplify_path(&resolve_links($full));
$dir && $path && &is_under_directory($dir, $path) ||
	&error($text{'view_ecanpath'});
my $fh;
my $data = &eval_as_unix_user($lconf->{'user'} || 'root',
		sub { &read_file_contents($full) });
$data || &error($text{'view_eopen'}." : ".&html_escape($full));

# Display HTML reports in a sandboxed frame on a themed page. The report
# markup comes from the log owner and must never become part of a Webmin page.
if ($full =~ /\.(html|htm)$/i && !$raw && !$config{'naked'}) {
	my ($title) = $data =~ /<TITLE>(.*?)<\/TITLE>/is;
	$title = &html_escape($title) if (defined($title));
	&ui_print_header(undef, $title || $text{'view_title'}, "");
	my $src = &get_webprefix()."/$module_name/view_log.cgi/".
		  &urlize(&urlize($log))."/raw/".&urlize(substr($file, 1));
	print "<iframe src=\"".&quote_escape($src)."\" ".
	      "sandbox=\"allow-popups\" ".
	      "title=\"".&quote_escape($text{'view_title'})."\" ".
	      "style=\"display:block;width:100%;height:80vh;min-height:480px;".
	      "border:0\"></iframe>\n";
	if ($access{'view'}) {
		&ui_print_footer("", $text{'index_return'});
		}
	else {
		&ui_print_footer(
			"/$module_name/edit_log.cgi?file=".&urlize($log),
			$text{'edit_return'},
			"", $text{'index_return'});
		}
	}
elsif ($ENV{'HTTP_X_REQUESTED_WITH'} && $full !~ /\.(png|gif|jpg|jpeg)$/i) {
	# Ajax page loads insert HTML or text into the Webmin page and ignore
	# the sandbox below. An empty response makes Authentic open the URL as
	# a normal page instead.
	print "Content-type: text/html; Charset=UTF-8\n";
	print "Cache-Control: private, no-store\n\n";
	}
else {
	# Send the file itself. The sandbox stops report markup from running
	# scripts or submitting forms, even when the URL is opened directly.
	my @self = ( "'self'" );
	if ($ENV{'HTTP_HOST'} =~ /^[A-Za-z0-9\.\-\:\[\]]+\z/) {
		# 'self' may not match in a sandboxed document, so also name
		# the server that the browser used
		push(@self, (uc($ENV{'HTTPS'}) eq 'ON' ? 'https' : 'http').
			    "://".$ENV{'HTTP_HOST'});
		}
	print "Content-Security-Policy: sandbox allow-popups; ".
	      "default-src 'none'; img-src @self data:; ".
	      "style-src @self 'unsafe-inline'; base-uri 'none'; ".
	      "form-action 'none'\n";
	print "X-Content-Type-Options: nosniff\n";
	print "Content-type: ",$full =~ /\.png$/i ? "image/png" :
			       $full =~ /\.gif$/i ? "image/gif" :
			       $full =~ /\.(jpg|jpeg)$/i ? "image/jpeg" :
			       $full =~ /\.(html|htm)$/i ? "text/html" :
							   "text/plain","\n";
	print "\n";
	print $data;
	}

