#!/usr/local/bin/perl
# save_assign.cgi
# Save or delete a mail user assignment

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'ssave_err'});

@assigns = &list_assigns();
$a = $assigns[$in{'idx'}] if (defined($in{'idx'}));

if ($in{'delete'}) {
	# delete some assign
	$loga = $a;
	&delete_assign($a);
	}
else {
	# saving or creating .. check inputs
	if ($in{'mode'} eq '=') {
		$in{'address0'} =~ /^[^:\s]+$/ || &error($text{'ssave_eaddress'});
		}
	else {
		$in{'address1'} =~ /^[^:\s]*$/ || &error($text{'ssave_eaddress'});
		}
	scalar(getpwnam($in{'user'})) || &error($text{'ssave_euser'});
	$in{'uid'} =~ /^\d+$/ || &error($text{'ssave_euid'});
	$in{'gid'} =~ /^\d+$/ || &error($text{'ssave_egid'});
	-d $in{'home'} || &error($text{'ssave_ehome'});
	$newa{'mode'} = $in{'mode'};
	$newa{'address'} = $in{'mode'} eq '=' ? $in{'address0'} : $in{'address1'};
	$newa{'user'} = $in{'user'};
	$newa{'uid'} = $in{'uid'};
	$newa{'gid'} = $in{'gid'};
	$newa{'home'} = $in{'home'};
	if ($a) {
		# Just keep these as before
		$newa{'dash'} = $a->{'dash'};
		$newa{'preext'} = $a->{'preext'};
		}

	if ($in{'new'}) { &create_assign(\%newa); }
	else { &modify_assign($a, \%newa); }
	$loga = \%newa;
	}
&system_logged("$qmail_bin_dir/qmail-newu");
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "assign", $loga->{'mode'}.$loga->{'address'}, $loga);
&redirect("list_assigns.cgi");

