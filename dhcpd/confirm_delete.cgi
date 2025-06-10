#!/usr/local/bin/perl
# save_shared.cgi
# Update, create or delete a shared network

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$par = &get_parent_config();
foreach $i ($in{'sidx'}, $in{'uidx'}, $in{'idx'}) {
	if ($i ne "") {
		$par = $par->{'members'}->[$i];
		}
	}

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});

@host = &find("host", $par->{'members'});
@group = &find("group", $par->{'members'});
@subn = &find("subnet", $par->{'members'});
if ($in{'type'} == 0) {
	&error("$text{'eacl_np'} $text{'eacl_pdn'}")
		if !&can('rw', \%access, $par, 1);
	}
elsif ($in{'type'} == 1) {
	&error("$text{'eacl_np'} $text{'eacl_pds'}")
		if !&can('rw', \%access, $par, 1);
	}
elsif ($in{'type'} == 2) {
	&error("$text{'eacl_np'} $text{'eacl_pdg'}")
		if !&can('rw', \%access, $par, 1);
	}
if ($in{'type'} == 0) {
	foreach $s (@subn) {
		&error("$text{'eacl_np'} $text{'eacl_pds'}")
			if !&can('rw', \%access, $s, 1);
		}
	}
if ($in{'type'} < 2) {
	foreach $g (@group) {
		&error("$text{'eacl_np'} $text{'eacl_pdg'}")
			if !&can('rw', \%access, $g, 1);
		}
	}
foreach $h (@host) {
	&error("$text{'eacl_np'} $text{'eacl_pdh'}")
		if !&can('rw', \%access, $h, 1);
	}

if ($in{'type'} == 0) {
	$name = $par->{'values'}->[0];
	}
elsif ($in{'type'} == 1) {
	$name = $par->{'values'}->[0]."/".$par->{'values'}->[2];
	}
elsif ($in{'type'} == 2) {
	local $gm = @host;
	$name = &group_name($gm, $par);
	}
else {
	&error($text{'cdel_eunknown'});
	}

&ui_print_header(undef, $text{'cdel_header'}, "");
@types1 = ($text{'cdel_shared1'}, $text{'cdel_subnet1'}, $text{'cdel_group1'});
@types2 = ($text{'cdel_shared2'}, $text{'cdel_subnet2'}, $text{'cdel_group2'});
print &text('cdel_txt', $types1[$in{'type'}], $name), "<br><br>\n";

if (@host > 0) {
	print ((@host > 1) ? $text{'cdel_hosts'} : $text{'cdel_host'});
	print ": ";
	$start = 1;
	foreach $i (@host) {
		if ($start) { $start = 0; }
		else { print ", " }
		print $i->{'values'}->[0];
		}
	print "<br>\n";
	}
if (@group > 0) {
	print ((@group > 1) ? $text{'cdel_groups'} : $text{'cdel_group'});
	print ":";
	$start = 1;
	foreach $i (@group) {
		local (@ghosts, $gm);
		if ($start) { $start = 0; }
		else { print ", " }
		@ghosts = &find("host", $i->{'members'});
		$gm = @ghosts;
		print &group_name($gm, $i);
		}
	print "<br>\n";
	}
if (@subn > 0) {
	print ((@subn > 1) ? $text{'cdel_subnets'} : $text{'cdel_subnet'});
	print ": ";
	$start = 1;
	foreach $i (@subn) {
		if ($start) { $start = 0; }
		else { print ", " }
		print $i->{'values'}->[0], "/", $i->{'values'}->[2];
		}
	print "<br>\n";
	}

print "<form action=delete_all.cgi>\n";
print "<input name=idx value=\"$in{'idx'}\" type=hidden>\n";
print "<input name=uidx value=\"$in{'uidx'}\" type=hidden>\n";
print "<input name=sidx value=\"$in{'sidx'}\" type=hidden>\n";

print "<b>", text('cdel_confirm', $types2[$in{'type'}]), "</b>\&nbsp;\&nbsp;\&nbsp;";
print "<input type=submit name=delete value=\"$text{'yes'}\">\n";
print "<input type=submit name=cancel value=\"$text{'no'}\">\n";
print "</form>\n";

&ui_print_footer("", $text{'cdel_return'});

