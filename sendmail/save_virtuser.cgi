#!/usr/local/bin/perl
# save_virtuser.cgi
# Save, create or delete an address mapping

require './sendmail-lib.pl';
require './virtusers-lib.pl';
&ReadParse();
$access{'vmode'} > 0 || &error($text{'vsave_ecannot'});
$conf = &get_sendmailcf();
$vfile = &virtusers_file($conf);
&lock_file($vfile);
($vdbm, $vdbmtype) = &virtusers_dbm($conf);
@virts = &list_virtusers($vfile);
foreach $vu (@virts) { $already{$vu->{'from'}}++; }
if (!$in{'new'}) {
	$v = $virts[$in{'num'}];
	&can_edit_virtuser($v) || &error($text{'vsave_ecannot2'});
	}
elsif ($access{'vmax'}) {
	local @cvirts =
		grep { $access{"vedit_".&virt_type($_->{'to'})} } @virts;
	if ($access{'vmode'} == 2) {
		@cvirts = grep { $_->{'from'} =~ /$access{'vaddrs'}/ } @cvirts;
		}
	elsif ($access{'vmode'} == 3) {
		@cvirts = grep { $_->{'from'} =~ /^$remote_user\@/ } @cvirts;
		}
	&error(&text('vsave_emax', $access{'vmax'}))
		if (@cvirts >= $access{'vmax'});
	}

if ($in{'delete'}) {
	# delete some mapping
	$logv = $v;
	&delete_virtuser($v, $vfile, $vdbm, $vdbmtype);
	}
else {
	# Saving or creating.. check inputs
	&error_setup($text{'vsave_err'});
	if ($in{'from_type'} == 0 || !$access{'vcatchall'}) {
		$in{'from_addr'} =~ /^(\S+)\@(\S+)$/ ||
			&error(&text('vsave_efrom', $in{'from_addr'}));
		$from = $in{'from_addr'};
		if ($already{$from} && ($in{'new'} || $v->{'from'} ne $from)) {
			&error(&text('vsave_efromdup', $in{'from_addr'}));
			}
		}
	else {
		$in{'from_dom'} =~ /^([^\@ ]+)$/ ||
			&error(&text('vsave_edom', $in{'from_dom'}));
		$from = "\@$in{'from_dom'}";
		if ($already{$from} && ($in{'new'} || $v->{'from'} ne $from)) {
			&error(&text('vsave_edomdup', $in{'from_dom'}));
			}
		}
	if ($access{'vmode'} == 2) {
		$from =~ /$access{'vaddrs'}/ ||
			&error(&text('vsave_ematch', $access{'vaddrs'}));
		}
	elsif ($access{'vmode'} == 3) {
		$from =~ /^$remote_user\@/ || &error($text{'vsave_esame'});
		}
	if ($in{'to_type'} == 2) {
		$access{"vedit_2"} ||
			&error($text{'vsave_ecannot3'});
		$in{'to_addr'} =~ /^([^\s,]+)$/ ||
			&error(&text('vsave_eaddr', $in{'to_addr'}));
		$to = $in{'to_addr'};
		}
	elsif ($in{'to_type'} == 1) {
		$access{"vedit_1"} ||
			&error($text{'vsave_ecannot4'});
		$in{'to_dom'} =~ /^([^\@ ]+)$/ ||
			&error(&text('vsave_edom', $in{'to_dom'}));
		$in{'from_type'} == 1 ||
			&error($text{'vsave_edomdom'});
		$to = "\%1\@$in{'to_dom'}";
		}
	else {
		$access{"vedit_0"} ||
			&error($text{'vsave_ecannot5'});
		$to = "error:$in{'to_code'} $in{'to_error'}";
		}

	$newv{'from'} = $from;
	$newv{'to'} = $to;
	$newv{'cmt'} = $in{'cmt'};
	if ($in{'new'}) { &create_virtuser(\%newv, $vfile, $vdbm, $vdbmtype); }
	else { &modify_virtuser($v, \%newv, $vfile, $vdbm, $vdbmtype); }
	$logv = \%newv;
	}
&unlock_file($vfile);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "virtuser", $logv->{'from'}, $logv);
&redirect("list_virtusers.cgi");

