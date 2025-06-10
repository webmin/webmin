#!/usr/local/bin/perl
# save_file.cgi
# Save a manually edited file

require './sendmail-lib.pl';
&error_setup($text{'file_err'});
$access{'manual'} || &error($text{'file_ecannot'});
&ReadParseMime();
$conf = &get_sendmailcf();
if ($in{'mode'} eq 'aliases') {
	require './aliases-lib.pl';
	$file = &aliases_file($conf)->[$in{'idx'}];
	$return = "list_aliases.cgi";
	$post = "newaliases";
	$access{'amode'} == 1 && $access{'aedit_1'} && $access{'aedit_2'} &&
	    $access{'aedit_3'} && $access{'aedit_4'} && $access{'aedit_5'} &&
	    $access{'amax'} == 0 && $access{'apath'} eq '/' ||
	    &error($text{'file_ealiases'});
	$log = "alias";
	$fmt = "alias";
	}
elsif ($in{'mode'} eq 'virtusers') {
	require './virtusers-lib.pl';
	$file = &virtusers_file($conf);
	($vdbm, $vdbmtype) = &virtusers_dbm($conf);
	$return = "list_virtusers.cgi";
	$post = "$config{'makemap_path'} $vdbmtype $vdbm <$file";
	$access{'vmode'} == 1 && $access{'vedit_0'} && $access{'vedit_1'} &&
	    $access{'vedit_2'} && $access{'vmax'} == 0 ||
	    &error($text{'file_evirtusers'});
	$log = "virtuser";
	$fmt = "tab";
	}
elsif ($in{'mode'} eq 'mailers') {
	require './mailers-lib.pl';
	$file = &mailers_file($conf);
	($mdbm, $mdbmtype) = &mailers_dbm($conf);
	$return = "list_mailers.cgi";
	$post = "$config{'makemap_path'} $mdbmtype $mdbm <$file";
	$access{'mailers'} || &error($text{'file_emailers'});
	$log = "mailer";
	$fmt = "tab";
	}
elsif ($in{'mode'} eq 'generics') {
	require './generics-lib.pl';
	$file = &generics_file($conf);
	($gdbm, $gdbmtype) = &generics_dbm($conf);
	$return = "list_generics.cgi";
	$post = "$config{'makemap_path'} $gdbmtype $gdbm <$file";
	$access{'omode'} == 1 || &error($text{'file_egenerics'});
	$log = "generic";
	$fmt = "tab";
	}
elsif ($in{'mode'} eq 'domains') {
	require './domain-lib.pl';
	$file = &domains_file($conf);
	($ddbm, $ddbmtype) = &domains_dbm($conf);
	$return = "list_domains.cgi";
	$post = "$config{'makemap_path'} $ddbmtype $ddbm <$file";
	$access{'domains'} || &error($text{'file_edomains'});
	$log = "domain";
	$fmt = "tab";
	}
elsif ($in{'mode'} eq 'access') {
	require './access-lib.pl';
	$file = &access_file($conf);
	($adbm, $adbmtype) = &access_dbm($conf);
	$return = "list_access.cgi";
	$post = "$config{'makemap_path'} $adbmtype $adbm <$file";
	$access{'access'} || &error($text{'file_eaccess'});
	$log = "access";
	$fmt = "tab";
	}
else { &error($text{'file_emode'}); }

# Validate format
$in{'text'} =~ s/\r//g;
@lines = split(/\n+/, $in{'text'});
foreach my $l (@lines) {
	$l =~ s/#.*$//;
	next if ($l !~ /\S/);
	if ($fmt eq "alias") {
		$l =~ /^\s*(\S+):\s*(\S.*)$/ ||
			&error(&text('file_ealias',
				     "<tt>".&html_escape($l)."</tt>"));
		}
	elsif ($fmt eq "tab") {
		$l =~ /^\s*(\S+)\s+(\S.*)$/ ||
			&error(&text('file_etab',
				     "<tt>".&html_escape($l)."</tt>"));
		}
	}

# Write out the file
&open_lock_tempfile(FILE, ">$file");
&print_tempfile(FILE, $in{'text'});
&close_tempfile(FILE);
&webmin_log("manual", $log, $file);

if (!&rebuild_map_cmd($file)) {
	&system_logged("$post >/dev/null 2>&1") if ($post);
	}
&redirect($return);

