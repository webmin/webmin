#!/usr/local/bin/perl
# save_generic.cgi
# Save, create or delete an outgoing address mapping

require './sendmail-lib.pl';
require './generics-lib.pl';
&ReadParse();
$access{'omode'} || &error($text{'gsave_ecannot'});
$conf = &get_sendmailcf();
$gfile = &generics_file($conf);
&lock_file($gfile);
($gdbm, $gdbmtype) = &generics_dbm($conf);
@gens = &list_generics($gfile);
if (!$in{'new'}) {
	$g = $gens[$in{'num'}];
	&can_edit_generic($g) ||
		&error($text{'gsave_ecannot2'});
	}

if ($in{'delete'}) {
	# delete some mapping
	$logg = $g;
	&delete_generic($g, $gfile, $gdbm, $gdbmtype);
	}
else {
	# Saving or creating.. check inputs
	&error_setup($text{'gsave_err'});
	$in{'from'} =~ /^\S+$/ ||
		&error(&text('gsave_efrom', $in{'from'}));
	$access{'omode'} == 1 || $in{'from'} =~ /$access{'oaddrs'}/ ||
		&error(&text('gsave_ematch', $access{'oaddrs'}));
	$in{'to'} =~ /^\S+\@[a-z0-9\.\-\_]+$/i ||
		&error(&text('gsave_eto', $in{'to'}));
	if ($in{'new'} || lc($in{'from'}) ne lc($g->{'from'})) {
		($same) = grep { lc($_->{'from'}) eq lc($in{'from'}) }
			       @gens;
		$same && &error(&text('gsave_ealready', $in{'from'}));
		}
	$newg{'from'} = $in{'from'};
	$newg{'to'} = $in{'to'};
	$newg{'cmt'} = $in{'cmt'};
	&can_edit_generic(\%newg) ||
		&error($text{'gsave_ecannot3'});
	if ($in{'new'}) {
		&create_generic(\%newg, $gfile, $gdbm, $gdbmtype);
		}
	else {
		&modify_generic($g, \%newg, $gfile, $gdbm, $gdbmtype);
		}
	$logg = \%newg;
	}
&unlock_file($gfile);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "generic", $logg->{'from'}, $logg);
&redirect("list_generics.cgi");

