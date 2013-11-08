#!/usr/local/bin/perl
# edit_part.cgi
# Edit an existing partition

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
$d = $ARGV[0]; $p = $ARGV[1];
@dlist = &list_disks();
$dinfo = $dlist[$d];
&can_edit_disk($dinfo->{'device'}) || &error($text{'edit_ecannot'});
&ui_print_header(undef, $text{'edit_title'}, "");
print "<table width=100%><tr> <td valign=top>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<form action=save_part.cgi><tr $cb><td><table>\n";
print "<input type=hidden name=disk value=$d>\n";
print "<input type=hidden name=part value=$p>\n";
@plist = &list_partitions($dinfo->{'device'});
$pinfo = $plist[$p];
$new = !$pinfo->{'end'};

$dinfo->{'device'} =~ /c(\d+)t(\d+)d(\d+)/;
print "<tr> <td><b>$text{'edit_location'}</b></td>\n";
print "<td>$pinfo->{'desc'}</td> </tr>\n";

$dev = $pinfo->{'device'};
print "<tr> <td><b>$text{'edit_dev'}</b></td> <td><tt>$dev</tt></td> </tr>\n";

print "<tr> <td><b>$text{'edit_type'}</b></td> <td><select name=tag>\n";
foreach $t (&list_tags()) {
	printf "<option %s>$t</option>\n", $t eq $pinfo->{'tag'} ? "selected" : "";
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'edit_flags'}</b></td>\n";
printf "<td nowrap><input type=checkbox name=writable value=1 %s> %s\n",
	$pinfo->{'flag'} =~ /^w.$/ ? "checked" : "", $text{'edit_w'};
printf "<input type=checkbox name=mountable value=1 %s> %s</td> </tr>\n",
	$pinfo->{'flag'} =~ /^.m$/ ? "checked" : "", $text{'edit_m'};

print "<tr> <td><b>$text{'edit_extent'}</b></td>\n";
printf "<td nowrap><input name=start size=6 value=\"%s\"> - \n",
	$pinfo->{'end'} ? $pinfo->{'start'} : "";
printf "<input name=end size=6 value=\"%s\">\n",
	$pinfo->{'end'} ? $pinfo->{'end'} : "";
print "of $dinfo->{'cyl'}</td> </tr>\n";

if ($pinfo->{'end'}) {
	print "<tr> <td><b>$text{'edit_stat'}</b></td>\n";
	@stat = &device_status($dev);
	if ($stat[1] eq "meta") {
		print "<td>$text{'edit_meta'}</td> </tr>\n";
		}
	elsif ($stat[1] eq "metadb") {
		print "<td>$text{'edit_metadb'}</td> </tr>\n";
		}
	elsif (@stat) {
		local $msg = $stat[2] ? 'edit_mount' : 'edit_umount';
		$msg .= 'vm' if ($stat[1] eq 'swap');
		print "<td>",&text($msg, "<tt>$stat[0]</tt>",
				   "<tt>$stat[1]</tt>"),"</td> </tr>\n";
		}
	else { print "<td>$text{'edit_nouse'}</td> </tr>\n"; }

	if ($stat[1] !~ /^meta/) {
		print "<tr> <td><b>$text{'edit_fs'}</b></td>\n";
		$fs = &filesystem_type($dev);
		printf "<td>%s</td> </tr>\n", $fs ? &fstype_name($fs) : "None";
		}
	}

print "</table></td></tr></table><p>\n";
if (@stat) { print "<b>$text{'edit_inuse'}</b>.\n"; }
elsif ($new) {
	print "<input type=submit value=\"$text{'edit_setup'}\">\n";
	}
else {
	print "<input type=submit value=\"$text{'edit_change'}\">\n";
	print "<input type=submit name=delete value=\"$text{'delete'}\">\n";
	}
print "</form>\n";

print "</td> <td valign=top>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td colspan=2><b>$text{'edit_tasks'}</b></td> </tr>\n";

print "<tr $cb> <form action=newfs_form.cgi>\n";
print "<td valign=top nowrap><b>$text{'edit_newfs'}</b><br>\n";
if (!$new && (!@stat || $stat[2] == 0)) {
	print "<input type=hidden name=dev value=$dev>\n";
	print "<input type=submit value=\"$text{'create'}\"></td>\n";
	print "<td>$text{'edit_newdesc1'}</td>\n";
	}
elsif ($new) {
	print "</td> <td>$text{'edit_newdesc2'}</td>\n";
	}
else {
	print "</td> <td>$text{'edit_newdesc3'}</td>\n";
	}
print "</form> </tr>\n";


print "<tr $cb> <form action=fsck_form.cgi>\n";
print "<td valign=top><b>$text{'edit_fsckfs'}</b><br>\n";
if (!$new && (!@stat || $stat[2] == 0) && $fs eq "ufs") {
	print "<input type=hidden name=dev value=$dev>\n";
	print "<input type=submit value=\"$text{'edit_fsck'}\"></td>\n";
	print "<td>$text{'edit_fsckdesc1'}</td>\n";
	}
elsif ($new) {
	print "</td> <td>$text{'edit_fsckdesc2'}</td>\n";
	}
elsif (@stat && $stat[2]) {
	print "</td> <td>$text{'edit_fsckdesc3'}</td>\n";
	}
elsif (!$fs) {
	print "</td> <td>$text{'edit_fsckdesc4'}</td>\n";
	}
else {
	print "</td> <td>$text{'edit_fsckdesc5'}</td>\n";
	}
print "</form> </tr>\n";

print "<tr $cb> <form action=tunefs_form.cgi>\n";
print "<td valign=top><b>$text{'edit_tunefs'}</b><br>\n";
if (!$new && (!@stat || $stat[2] == 0) && $fs eq "ufs") {
	print "<input type=hidden name=dev value=$dev>\n";
	print "<input type=submit value=\"$text{'edit_tune'}\"></td>\n";
	print "<td>$text{'edit_tunedesc1'}</td>\n";
	}
elsif ($new) {
	print "</td> <td>$text{'edit_tunedesc2'}</td>\n";
	}
elsif (@stat && $stat[2]) {
	print "</td> <td>$text{'edit_tunedesc3'}</td>\n";
	}
elsif (!$fs) {
	print "</td> <td>$text{'edit_tunedesc4'}</td>\n";
	}
elsif ($fs ne "ufs") {
	print "</td> <td>$text{'edit_tunedesc5'}</td>\n";
	}
print "</form> </tr>\n";

print "</table>\n";
print "</td></tr></table>\n";
&ui_print_footer("", $text{'index_return'});

