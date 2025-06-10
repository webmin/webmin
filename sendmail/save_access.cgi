#!/usr/local/bin/perl
# save_access.cgi
# Save, create or delete an access rule

require './sendmail-lib.pl';
require './access-lib.pl';
&ReadParse();
$access{'access'} || &error($text{'access_ecannot'});
$conf = &get_sendmailcf();
$afile = &access_file($conf);
&lock_file($afile);
($adbm, $adbmtype) = &access_dbm($conf);
@accs = &list_access($afile);
if (!$in{'new'}) {
	$a = $accs[$in{'num'}];
	&can_edit_access($a) ||
		&error($text{'sform_ecannot'});
	}

if ($in{'delete'}) {
	# delete some rule
	$loga = $a;
	&delete_access($a, $afile, $adbm, $adbmtype);
	}
else {
	# Saving or creating.. check inputs
	$whatfailed = "Failed to save spam control rule";
	$from = $in{'from'};
	$in{'from_type'} == 0 && $from !~ /^[^\@ ]+\@[A-z0-9\.\-]+$/ &&
		&error(&text('ssave_etype0', $from));
	$in{'from_type'} == 1 && $from !~ /^[0-9\.]+$/ &&
		&error(&text('ssave_etype1', $from));
	$in{'from_type'} == 2 && $from !~ /^[^\@ ]+$/ &&
		&error(&text('ssave_etype2', $from));
	$in{'from_type'} == 3 && $from !~ /^[A-z0-9\.\-]+$/ &&
		&error(&text('ssave_etype3', $from));
	$from .= '@' if ($in{'from_type'} == 2);

	if ($in{'new'} || uc($from) ne uc($a->{'from'}) ||
	    $in{'tag'} ne $a->{'tag'}) {
		# Is this name taken?
		local ($same) = grep { uc($_->{'from'}) eq uc($from) &&
				       $_->{'tag'} eq $in{'tag'} } @accs;
		$same && &error(&text('ssave_ealready', $from));
		}

	if ($in{'action'}) { $action = $in{'action'}; }
	else {
		$in{'err'} =~ /^\d\d\d$/ ||
			&error(&text('ssave_ecode', $in{'err'}));
		$action = "$in{'err'} $in{'msg'}";
		}

	%newa = ( 'from', $from,
		  'action', $action,
		  'tag', $in{'tag'},
		  'cmt', $in{'cmt'} );
	&can_edit_access(\%newa) ||
		&error($text{'ssave_ecannot2'});
	if ($in{'new'}) { &create_access(\%newa, $afile, $adbm, $adbmtype); }
	else { &modify_access($a, \%newa, $afile, $adbm, $adbmtype); }
	$loga = \%newa;
	}
&unlock_file($afile);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "access", $loga->{'from'}, $loga);
&redirect("list_access.cgi");

