#!/usr/local/bin/perl
# show.cgi
# Output some file for the browser

$trust_unknown_referers = 1;
require './file-lib.pl';
&ReadParse();
use POSIX;
$p = $ENV{'PATH_INFO'};
($p =~ /^\s*\|/ || $p =~ /\|\s*$/ || $p =~ /\0/) &&
	&error_exit($text{'view_epathinfo'});
if ($in{'type'}) {
	# Use the supplied content type
	$type = $in{'type'};
	$download = 1;
	}
elsif ($in{'format'} == 1) {
	# Type comes from compression format
	$type = "application/zip";
	}
elsif ($in{'format'} == 2) {
	$type = "application/x-gzip";
	}
elsif ($in{'format'} == 3) {
	$type = "application/x-tar";
	}
else {
	# Try to guess type from filename
	$type = &guess_mime_type($p, undef);
	if (!$type) {
		# No idea .. use the 'file' command
		$out = &backquote_command("file ".
					  quotemeta(&resolve_links($p)), 1);
		if ($out =~ /text|script/) {
			$type = "text/plain";
			}
		else {
			$type = "application/unknown";
			}
		}
	}

# Dump the file
&switch_acl_uid();
$temp = &transname();
if (!&can_access($p)) {
	# ACL rules prevent access to file
	&error_exit(&text('view_eaccess', &html_escape($p)));
	}
$p = &unmake_chroot($p);

if ($in{'format'}) {
	# An archive of a directory was requested .. create it
	$archive || &error_exit($text{'view_earchive'});
	if ($in{'format'} == 1) {
		$p =~ s/\.zip$//;
		}
	elsif ($in{'format'} == 2) {
		$p =~ s/\.tgz$//;
		}
	elsif ($in{'format'} == 3) {
		$p =~ s/\.tar$//;
		}
	-d $p || &error_exit($text{'view_edir'}." ".&html_escape($p));
	if ($archive == 2 && $archmax > 0) {
		# Check if directory is too large to archive
		local $kb = &disk_usage_kb($p);
		if ($kb*1024 > $archmax) {
			&error_exit(&text('view_earchmax', $archmax));
			}
		}

	# Work out the base directory and filename
	if ($p =~ /^(.*\/)([^\/]+)$/) {
		$pdir = $1;
		$pfile = $2;
		}
	else {
		$pdir = "/";
		$pfile = $p;
		}

	# Work out the command to run
	if ($in{'format'} == 1) {
		&has_command("zip") || &error_exit(&text('view_ecmd', "zip"));
		$cmd = "zip -r $temp ".quotemeta($pfile);
		}
	elsif ($in{'format'} == 2) {
		&has_command("tar") || &error_exit(&text('view_ecmd', "tar"));
		&has_command("gzip") || &error_exit(&text('view_ecmd', "gzip"));
		$cmd = "tar cf - ".quotemeta($pfile)." | gzip -c >$temp";
		}
	elsif ($in{'format'} == 3) {
		&has_command("tar") || &error_exit(&text('view_ecmd', "tar"));
		$cmd = "tar cf $temp ".quotemeta($pfile);
		}

	if ($in{'test'}) {
		# Don't actually do anything if in test mode
		&ok_exit();
		}

	# Run the command, and send back the resulting file
	local $qpdir = quotemeta($pdir);
	local $out = `cd $qpdir ; ($cmd) 2>&1 </dev/null`;
	if ($?) {
		unlink($temp);
		&error_exit(&text('view_ecomp', &html_escape($out)));
		}
	local @st = stat($temp);
	print "Content-length: $st[7]\n";
	print "Content-type: $type\n\n";
	open(FILE, $temp);
	unlink($temp);
	while(read(FILE, $buf, 1000*1024)) {
		print $buf;
		}
	close(FILE);
	}
else {
	if (!open(FILE, "<", $p)) {
		# Unix permissions prevent access
		&error_exit(&text('view_eopen', $p, $!));
		}

	if ($in{'test'}) {
		# Don't actually do anything if in test mode
		close(FILE);
		&ok_exit();
		}

	@st = stat($p);
	print "X-no-links: 1\n";
	print "Content-length: $st[7]\n";
	($fn = $p) =~ s/^.*\///;
	print "Content-Disposition: Attachment filename=\"$fn\"\n" if ($download);
	print "X-Content-Type-Options: nosniff\n";
	&print_content_type($type);
	if ($type =~ /^text\/html/i && !$in{'edit'}) {
		while(read(FILE, $buf, 1000*1024)) {
			$data .= $buf;
			}
		print &filter_javascript($data);
		}
	else {
		while(read(FILE, $buf, 1000*1024)) {
			print $buf;
			}
		}
	close(FILE);
	}

sub error_exit
{
print "Content-type: text/plain\n";
print "Content-length: ",length($_[0]),"\n\n";
print $_[0];
exit;
}

sub ok_exit
{
print "Content-type: text/plain\n\n";
print "\n";
exit;
}

