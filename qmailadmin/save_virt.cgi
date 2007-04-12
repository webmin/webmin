#!/usr/local/bin/perl
# save_virt.cgi
# Save or delete a new or existing virtual mapping

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'vsave_err'});

@virts = &list_virts();
$v = $virts[$in{'idx'}] if ($in{'idx'} ne '');

if ($in{'delete'}) {
	# delete some virt
	$logv = $v;
	&delete_virt($v);
	}
else {
	# saving or creating .. check inputs
	if ($in{'from_mode'} == 1) {
		$in{'domain'} =~ /^[A-Za-z0-9\.\-]+$/ ||
			&error(&text('vsave_edomain', $in{'domain'}));
		$newv{'domain'} = $in{'domain'};
		}
	elsif ($in{'from_mode'} == 2) {
		$in{'user'} =~ /^[^\@: ]+$/ ||
			&error(&text('vsave_euser', $in{'user'}));
		$in{'domain2'} =~ /^[A-Za-z0-9\.\-]+$/ ||
			&error(&text('vsave_edomain', $in{'domain2'}));
		$newv{'domain'} = $in{'domain2'};
		$newv{'user'} = $in{'user'};
		}
	if ($in{'prepend_mode'} == 1) {
		$in{'prepend'} =~ /^[^\@: ]+$/ ||
			&error(&text('vsave_eprepend', $in{'prepend'}));
		$newv{'prepend'} = $in{'prepend'};
		}
	elsif ($in{'prepend_mode'} == 0) {
		$in{'from_mode'} || &error($text{'vsave_eboth'});
		}
	elsif ($in{'prepend_mode'} == 2) {
		if ($in{'from_mode'} == 1) {
			$newv{'prepend'} = $in{'domain'};
			$newv{'prepend'} =~ s/\.(.*)$//;
			}
		elsif ($in{'from_mode'} == 2) {
			$newv{'prepend'} = $in{'domain2'};
			$newv{'prepend'} =~ s/\.(.*)$//;
			}
		else {
			$newv{'prepend'} = 'catchall';
			}
		}
	if ($in{'new'}) { &create_virt(\%newv); }
	else { &modify_virt($v, \%newv); }
	$logv = \%newv;
	}
&restart_qmail();
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "virt", $logv->{'user'} ? "$logv->{'user'}\@$logv->{'domain'}" :
		    $logv->{'domain'}, $logv);
&redirect("list_virts.cgi");

