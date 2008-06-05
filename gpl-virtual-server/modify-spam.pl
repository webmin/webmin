#!/usr/local/bin/perl
# Change the spam and virus delivery for some domains

package virtual_server;
if (!$module_name) {
	$main::no_acl_check++;
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
	if ($0 =~ /^(.*\/)[^\/]+$/) {
		chdir($1);
		}
	chop($pwd = `pwd`);
	$0 = "$pwd/modify-spam.pl";
	require './virtual-server-lib.pl';
	$< == 0 || die "modify-spam.pl must be run as root";
	}
@OLDARGV = @ARGV;
$config{'spam'} || &usage("Spam filtering is not enabled for Virtualmin");
&set_all_text_print();

# Parse command-line args
$spamlevel = undef;
while(@ARGV > 0) {
	local $a = shift(@ARGV);
	if ($a eq "--domain") {
		push(@dnames, shift(@ARGV));
		}
	elsif ($a eq "--all-domains") {
		$all_doms = 1;
		}
	elsif ($a =~ /^--(spam|virus)-delete$/) {
		$mode{$1} = 0;
		}
	elsif ($a =~ /^--(spam)-deliver$/) {
		$mode{$1} = 5;
		}
	elsif ($a =~ /^--(spam|virus)-normal$/) {
		$mode{$1} = 4;
		}
	elsif ($a =~ /^--(spam|virus)-maildir$/) {
		$mode{$1} = 6;
		}
	elsif ($a =~ /^--(spam|virus)-file$/) {
		$mode{$1} = 1;
		$dest{$1} = shift(@ARGV);
		$dest{$1} =~ /\S/ && $dest{$1} !~ /\.\./ &&
		    $dest{$1} !~ /^\// ||
			&usage("The $a option must be followed by a relative filename");
		}
	elsif ($a =~ /^--(spam|virus)-email$/) {
		$mode{$1} = 2;
		$dest{$1} = shift(@ARGV);
		$dest{$1} =~ /\@/ || &usage("The $a option must be followed by an email address");
		}
	elsif ($a =~ /^--(spam|virus)-dest$/) {
		$mode{$1} = 3;
		$dest{$1} = shift(@ARGV);
		$dest{$1} =~ /\S/ || &usage("The $a option must be followed by a mail file path");
		}
	elsif ($a eq "--spam-whitelist") {
		$spam_white = 1;
		}
	elsif ($a eq "--no-spam-whitelist") {
		$spam_white = 0;
		}
	elsif ($a =~ /^--use-(spamc|spamassassin)$/) {
		$spam_client = $1;
		}
	elsif ($a eq "--spamclear-none") {
		$auto = "";
		}
	elsif ($a eq "--spamclear-days") {
		$auto = { 'days' => shift(@ARGV) };
		$auto->{'days'} =~ /^\d+$/ ||
		  &usage("The $a option must be followed by a number of days");
		}
	elsif ($a eq "--spamclear-size") {
		$auto = { 'size' => shift(@ARGV) };
		$auto->{'size'} =~ /^\d+$/ ||
		  &usage("The $a option must be followed by a size in bytes");
		}
	elsif ($a eq "--spam-delete-level") {
		$spamlevel = shift(@ARGV);
		$spamlevel =~ /^[1-9]\d*$/ ||
		    &usage("--spam-delete-level must be followed by a number");
		}
	elsif ($a eq "--spam-no-delete-level") {
		$spamlevel = 0;
		}
	elsif ($a =~ /^--use-(clamscan|clamdscan)$/) {
		$virus_scanner = $1;
		}
	else {
		&usage();
		}
	}
@dnames || $all_doms || usage();
defined($mode{'spam'}) || defined($mode{'virus'}) || $spam_client ||
    $virus_scanner || defined($auto) || defined($spamlevel) ||
	 &usage("Nothing to do");

# Get domains to update
if ($all_doms) {
	@doms = grep { $_->{'spam'} } &list_domains();
	}
else {
	foreach $n (@dnames) {
		$d = &get_domain_by("dom", $n);
		$d || &usage("Domain $n does not exist");
		$d->{'spam'} || &usage("Virtual server $n does not have spam filtering enabled");
		push(@doms, $d);
		}
	}

# Do it for all domains
foreach $d (@doms) {
	&$first_print("Updating server $d->{'dom'} ..");
	&obtain_lock_spam($d);
	&obtain_lock_cron($d);
	&$indent_print();

	if ($config{'spam'} && $d->{'spam'} &&
	    (defined($mode{'spam'}) || defined($spamlevel))) {
		&save_domain_spam_delivery($d, $mode{'spam'}, $dest{'spam'},
					   $spamlevel, undef);
		}
	if ($config{'virus'} && $d->{'virus'} && defined($mode{'virus'})) {
		&save_domain_virus_delivery($d, $mode{'virus'}, $dest{'virus'});
		}
	if ($config{'spam'} && $d->{'spam'} && $spam_client) {
		&save_domain_spam_client($d, $spam_client);
		&modify_webmin($d, $d);
		}
	if (defined($spam_white)) {
		$d->{'spam_white'} = 1;
		&update_spam_whitelist($d);
		&save_domain($d);
		}
	if (defined($auto)) {
		&save_domain_spam_autoclear($d, $auto);
		}
	if (defined($virus_scanner)) {
		&save_domain_virus_scanner($d, $virus_scanner);
		}

	&$outdent_print();
	&release_lock_spam($d);
	&release_lock_cron($d);
	&$second_print(".. done");
	}

&run_post_actions();
&virtualmin_api_log(\@OLDARGV);

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Changes the spam and virus delivery modes for one or more domains.\n";
print "\n";
print "usage: modify-spam.pl [--domain name] | [--all-domains]\n";
print "                      [--spam-delete | --spam-deliver |\n";
print "                       --spam-normal | --spam-file file-under-home |\n";
print "                       --spam-email address | --spam-dest file |\n";
print "                       --spam-maildir ]\n";
print "                      [--spam-delete-level N | --spam-no-delete-level]\n";
print "                      [--virus-delete |\n";
print "                       --virus-normal | --virus-file file-under-home |\n";
print "                       --virus-email address | --virus-dest file\n";
print "                       --virus-maildir ]\n";
print "                      [--spam-whitelist | --no-spam-whitelist]\n";
print "                      [--use-spamassassin | --use-spamc]\n";
print "                      [--spamclear-none |\n";
print "                       --spamclear-days days\n";
print "                       --spamclear-size bytes]\n";
print "                      [--use-clamscan | --use-clamdscan]\n";
print "\n";
print "Warning - modifying the SpamAssassin or virus scanning client for\n";
print "individual domains is deprecated.\n";
exit(1);
}

