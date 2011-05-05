#!/usr/local/bin/perl
# save_mailer.cgi
# Save, create or delete a mailertable entry

require './sendmail-lib.pl';
require './mailers-lib.pl';
&ReadParse();
$access{'mailers'} || &error($text{'msave_ecannot'});
$conf = &get_sendmailcf();
$mfile = &mailers_file($conf);
&lock_file($mfile);
($mdbm,$mdbmtype) = &mailers_dbm($conf);
@mailers = &list_mailers($mfile);
foreach $ml (@mailers) { $already{$ml->{'domain'}}++; }
if (!$in{'new'}) { $m = $mailers[$in{'num'}]; }

if ($in{'delete'}) {
	# delete some mailer entry
	$logm = $m;
	&delete_mailer($m, $mfile, $mdbm, $mdbmtype);
	}
else {
	# Saving or creating.. check inputs
	&error_setup($text{'msave_err'});
	$domain = $in{'from_type'} == 1 ? ".".$in{'from_dom'} :
		  $in{'from_type'} == 2 ? $in{'from_all'} : $in{'from_host'};
	$domain =~ /^[A-z0-9\-\.]+$/ ||
		&error(&text('msave_edomain', $domain));
	if ($already{$domain} && ($in{'new'} || $m->{'domain'} ne $domain)) {
		&error(&text('msave_edup', $domain));
		}
	if ($in{'new'} && $in{'from_type'} == 2 &&
	    $already{".".$in{'from_all'}}) {
		&error(&text('msave_edup', $domain));
		}
	$mailer = $in{'mailer'};
	$dest = $in{'dest'};
	$dest =~ s/\s+/:/g;

	$newm{'domain'} = $domain;
	$newm{'mailer'} = $mailer;
	if ($in{'nomx'} && $mailer =~ /smtp|relay/) {
		$dest = join(":", map { "[".$_."]" } split(/:/, $dest));
		}
	$newm{'dest'} = $dest;
	$newm{'cmt'} = $in{'cmt'};
	if ($in{'new'}) {
		&create_mailer(\%newm, $mfile, $mdbm, $mdbmtype);
		if ($in{'from_type'} == 2) {
			# Add extra for hosts in domain
			$newm{'domain'} = ".".$in{'from_all'};
			&create_mailer(\%newm, $mfile, $mdbm, $mdbmtype);
			}
		}
	else {
		&modify_mailer($m, \%newm, $mfile, $mdbm, $mdbmtype);
		}
	$logm = \%newm;
	}
&unlock_file($mfile);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "mailer", $logm->{'domain'}, $logm);
&redirect("list_mailers.cgi");

