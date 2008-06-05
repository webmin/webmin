#!/usr/local/bin/perl
# Change the spam and virus scanners for all domains

package virtual_server;
if (!$module_name) {
	$main::no_acl_check++;
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
	if ($0 =~ /^(.*\/)[^\/]+$/) {
		chdir($1);
		}
	chop($pwd = `pwd`);
	$0 = "$pwd/set-spam.pl";
	require './virtual-server-lib.pl';
	$< == 0 || die "set-spam.pl must be run as root";
	}
@OLDARGV = @ARGV;

$config{'spam'} || &usage("Spam filtering is not enabled for Virtualmin");
&set_all_text_print();

# Parse command-line args
while(@ARGV > 0) {
	local $a = shift(@ARGV);
	if ($a =~ /^--use-(spamc|spamassassin)$/) {
		$spam_client = $1;
		}
	elsif ($a eq "--spamc-host") {
		$spam_host = shift(@ARGV);
		}
	elsif ($a eq "--no-spamc-host") {
		$spam_host = "";
		}
	elsif ($a eq "--spamc-max") {
		$spam_max = shift(@ARGV);
		}
	elsif ($a eq "--no-spamc-max") {
		$spam_max = 0;
		}
	elsif ($a =~ /^--use-(clamscan|clamdscan)$/) {
		$virus_scanner = $1;
		}
	elsif ($a eq "--use-virus") {
		$virus_scanner = shift(@ARGV);
		}
	elsif ($a eq "--show") {
		$show = 1;
		}
	elsif ($a eq "--enable-clamd") {
		$clamd = 1;
		}
	elsif ($a eq "--disable-clamd") {
		$clamd = 0;
		}
	else {
		&usage();
		}
	}

# Validate inputs
$virus_scanner || $spam_client || $show || defined($clamd) ||
	&usage("Nothing to do");
if ($spam_client) {
	&has_command($spam_client) ||
	    &usage("SpamAssassin client program $spam_client does not exist");
	}
if ($virus_scanner) {
	local ($cmd, @args) = &split_quoted_string($virus_scanner);
	&has_command($cmd) ||
		&usage("Virus scanning command $cmd does not exist");
	if (!$clamd || $virus_scanner ne "clamdscan") {
		# Only test if we aren't enabling clamd anyway
		$err = &test_virus_scanner($virus_scanner);
		$err && &usage("Virus scanner failed : $err");
		}
	}
if (defined($clamd)) {
	$cs = &check_clamd_status();
	$cs >= 0 || &usage("Virtualmin does not know how to enable clamd on ".
			   "your system");
	}

&obtain_lock_spam_all();

if ($spam_client || $spam_host || $spam_max) {
	print "Updating all virtual servers with new SpamAssassin client ..\n";
	($old_spam_client, $old_spam_host, $old_spam_max) =
		&get_global_spam_client();
	$spam_client = $old_spam_client if (!defined($spam_client));
	$spam_host = $old_spam_host if (!defined($spam_host));
	$spam_max = $old_spam_max if (!defined($spam_max));
	&save_global_spam_client($spam_client, $spam_host, $spam_max);
	print ".. done\n\n";
	}

if (defined($clamd)) {
	if ($clamd) {
		print "Configuring and enabling clamd ..\n";
		&$indent_print();
		&enable_clamd();
		&$outdent_print();
		}
	else {
		print "Disabling clamd ..\n";
		&$indent_print();
		&disable_clamd();
		&$outdent_print();
		}
	}

if ($virus_scanner) {
	print "Updating all virtual servers with new virus scanner ..\n";
	&save_global_virus_scanner($virus_scanner);
	print ".. done\n\n";
	}

&release_lock_spam_all();

&run_post_actions();
&virtualmin_api_log(\@OLDARGV);

if ($show) {
	# Show current settings
	if ($config{'spam'}) {
		($client, $host, $max) = &get_global_spam_client();
		print "SpamAssassin client: $client\n";
		if ($host) {
			print "SpamAssassin spamc host: $host\n";
			}
		if ($max) {
			print "SpamAssassin spamc maximum size: $max\n";
			}
		}
	if ($config{'virus'}) {
		$scanner = &get_global_virus_scanner();
		print "Virus scanner: $scanner\n";
		}
	}

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Changes the spam and virus scanning programs for all domains.\n";
print "\n";
print "usage: set-spam.pl [--use-spamassassin | --use-spamc]\n";
print "                   [--spamc-host hostname | --no-spamc-host]\n";
print "                   [--spamc-max bytes | --no-spamc-max]\n";
print "                   [--use-clamscan | --use-clamdscan |\n";
print "                    --use-virus command]\n";
if (&check_clamd_status() >= 0) {
	print "                   [--enable-clamd | --disable-clamd]\n";
	}
print "                   [--show]\n";
exit(1);
}

