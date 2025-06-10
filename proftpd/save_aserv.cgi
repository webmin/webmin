#!/usr/local/bin/perl
# save_aserv.cgi
# Save anonymous section options

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'virt'}) {
	$virt = $conf->[$in{'virt'}];
	$vconf = $virt->{'members'};
	}
else {
	$vconf = $conf;
	}
&error_setup($text{'aserv_err'});

# Validate inputs
-d $in{'root'} || $in{'root'} =~ /^~/ || &error($text{'aserv_eroot'});
$in{'User_def'} || scalar(getpwnam($in{'User'})) ||
	&error($text{'aserv_euser'});
$in{'Group_def'} || scalar(getgrnam($in{'Group'})) ||
	&error($text{'aserv_egroup'});

if ($in{'init'}) {
	# Create a new <Anonymous> directive
	$l = $vconf->[@$vconf - 1];
	&lock_file($l->{'file'});
	&before_changing();
	$lref = &read_file_lines($l->{'file'});
	local @l = ( "<Anonymous $in{'root'}>" );
	push(@l, "User $in{'User'}") if (!$in{'User_def'});
	push(@l, "UserAlias anonymous $in{'User'}") if (!$in{'User_def'});
	push(@l, "Group $in{'Group'}") if (!$in{'Group_def'});
	push(@l, "</Anonymous>");
	splice(@$lref, $l->{'eline'}+1, 0, @l);
	&after_changing();
	&flush_file_lines();
	&unlock_file($l->{'file'});
	&webmin_log("anon", "create", $in{'root'}, \%in);
	}
else {
	# Update existing directive
	$anon = &find_directive_struct("Anonymous", $vconf);
	&lock_file($anon->{'file'});
	&before_changing();
	$lref = &read_file_lines($anon->{'file'});
	$lref->[$anon->{'line'}] = "<Anonymous $in{'root'}>";
	&save_directive("User", $in{'User_def'} ? [ ] : [ $in{'User'} ],
			$anon->{'members'}, $vconf);
	&save_directive("Group", $in{'Group_def'} ? [ ] : [ $in{'Group'} ],
			$anon->{'members'}, $vconf);
	&after_changing();
	&flush_file_lines();
	&unlock_file($anon->{'file'});
	&webmin_log("anon", "save", $anon->{'value'}, \%in);
	}
&redirect("anon_index.cgi?virt=$in{'virt'}");

