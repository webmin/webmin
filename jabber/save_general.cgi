#!/usr/local/bin/perl
# save_general.cgi
# Save general jabber server options

require './jabber-lib.pl';
&ReadParse();
&error_setup($text{'general_err'});

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$host = &find("host", $session);
$hostname = &find_by_tag("jabberd:cmdline", "flag", "h", $host);
$jsm = &find("jsm", $session);
$update = &find("update", $jsm);
$updatename = &find_by_tag("jabberd:cmdline", "flag", "h", $update);
$elogger = &find_by_tag("log", "id", "elogger", $conf);
$rlogger = &find_by_tag("log", "id", "rlogger", $conf);
$pidfile = &find_value("pidfile", $conf);

# Validate and store inputs
$in{'host'} =~ /^[a-z0-9\.\-]+$/ || &error($text{'general_ehost'});
&save_directive($hostname, "0", [ [ 0, $in{'host'} ] ]);
&save_directive($updatename, "0", [ [ 0, $in{'host'} ] ]) if ($updatename);
$in{'elog'} =~ /^\S+$/ || &error($text{'general_eelog'});
$in{'elogfmt'} =~ /\S/ || &error($text{'general_eelogfmt'});
if ($elogger) {
	&save_directive($elogger, "file",
			[ [ 'file', [ { }, 0, $in{'elog'} ] ] ] );
	&save_directive($elogger, "format",
			[ [ 'format', [ { }, 0, $in{'elogfmt'} ] ] ] );
	}
$in{'rlog'} =~ /^\S+$/ || &error($text{'general_erlog'});
$in{'rlogfmt'} =~ /\S/ || &error($text{'general_erlogfmt'});
if ($rlogger) {
	&save_directive($rlogger, "file",
			[ [ 'file', [ { }, 0, $in{'rlog'} ] ] ] );
	&save_directive($rlogger, "format",
			[ [ 'format', [ { }, 0, $in{'rlogfmt'} ] ] ] );
	}
$in{'pidfile'} =~ /^\S+$/ || &error($text{'general_epidfile'});
&save_directive($conf, "pidfile",
		[ [ 'pidfile', [ { }, 0, $in{'pidfile'} ] ] ] );
$spool = $config{'jabber_spool'} ? $config{'jabber_spool'}
				 : "$config{'jabber_dir'}/spool";
mkdir("$spool/$in{'host'}", 0755);

&save_jabber_config($conf);
&redirect("");

