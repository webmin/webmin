#!/usr/local/bin/perl
# save_domain.cgi
# Save, create or delete an address mapping

require './sendmail-lib.pl';
require './domain-lib.pl';
&ReadParse();
$access{'domains'} || &error($text{'dsave_ecannot'});
$conf = &get_sendmailcf();
$dfile = &domains_file($conf);
&lock_file($dfile);
($ddbm, $ddbmtype) = &domains_dbm($conf);
@doms = &list_domains($dfile);
if (!$in{'new'}) { $d = $doms[$in{'num'}]; }
foreach $du (@doms) { $already{$du->{'from'}}++; }

if ($in{'delete'}) {
	# delete some mapping
	$logd = $d;
	&delete_domain($d, $dfile, $ddbm, $ddbmtype);
	}
else {
	# Saving or creating.. check inputs
	&error_setup($text{'dsave_err'});
	$in{'from'} =~ /^[A-z0-9\.\-]+$/ ||
		&error(&text('dsave_edomain', $in{'from'}));
	$in{'to'} =~ /^[A-z0-9\.\-]+$/ ||
		&error(&text('dsave_edomain', $in{'to'}));
	if ($in{'new'} || lc($in{'from'}) ne lc($d->{'from'})) {
		($same) = grep { lc($_->{'from'}) eq lc($in{'from'}) }
			       @doms;
		$same && &error(&text('dsave_ealready', $in{'from'}));
		}
	$newd{'from'} = $in{'from'};
	$newd{'to'} = $in{'to'};
	$newd{'cmt'} = $in{'cmt'};
	if ($in{'new'}) { &create_domain(\%newd, $dfile, $ddbm, $ddbmtype); }
	else { &modify_domain($d, \%newd, $dfile, $ddbm, $ddbmtype); }
	$logd = \%newd;
	}
&unlock_file($dfile);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "domain", $logd->{'from'}, $logd);
&redirect("list_domains.cgi");

