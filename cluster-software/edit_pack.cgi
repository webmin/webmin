#!/usr/local/bin/perl
# edit_pack.cgi
# Display details of a package

require './cluster-software-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'edit_title'}, "", "edit_pack");

# Find all hosts with the package
@hosts = &list_software_hosts();
@servers = &list_servers();
foreach $h (@hosts) {
	foreach $p (@{$h->{'packages'}}) {
		if ($p->{'name'} eq $in{'package'}) {
			local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
			push(@got, $s);
			$version{$s} = $p->{'version'};
			$pkg = $p if (!$pkg);
			$checkon = $s if (!$s->{'id'});
			}
		}
	}

# Get the details from this host, or the first in the list
$checkon = $got[0] if (!$checkon);
&remote_foreign_require($checkon->{'host'}, "software", "software-lib.pl");
@pinfo = &remote_foreign_call($checkon->{'host'}, "software", "package_info",
			      $in{'package'});

# Show package details
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('edit_details', $checkon->{'desc'} ?
	$checkon->{'desc'} : "<tt>$checkon->{'host'}</tt>"),"</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Description, if we have one
if ($pinfo[2]) {
	print "<tr> <td valign=top width=20%><b>$text{'edit_desc'}</b></td>\n";
	print "<td colspan=3><pre>",
	      &html_escape(&entities_to_ascii($pinfo[2])),
	      "</pre></td> </tr>\n";
	}

print "<tr> <td width=20%><b>$text{'edit_pack'}</b></td> <td>$pinfo[0]</td>\n";
print "<td width=20%><b>$text{'edit_class'}</b></td> <td>",
      $pinfo[1] ? $pinfo[1] : $text{'edit_none'},"</td> </tr>\n";

print "<tr> <td width=20%><b>$text{'edit_ver'}</b></td> <td>$pinfo[4]</td>\n";
print "<td width=20%><b>$text{'edit_vend'}</b></td> <td>$pinfo[5]</td> </tr>\n";

print "<tr> <td width=20%><b>$text{'edit_arch'}</b></td> <td>$pinfo[3]</td>\n";
print "<td width=20%><b>$text{'edit_inst'}</b></td> <td>$pinfo[6]</td> </tr>\n";
print "</table></td></tr></table><p>\n";

print "<table width=100%> <tr>\n";

# Show button to list files, if possible
if (!$pinfo[8]) {
	print "<form action=list_pack.cgi>\n";
	print "<input type=hidden name=package value=\"$pinfo[0]\">\n";
	print "<input type=hidden name=search value=\"$in{'search'}\">\n";
	print "<td align=left><input type=submit value=\"$text{'edit_list'}\">\n";
	print "<select name=server>\n";
	foreach $s (@got) {
		print "<option value='$s->{'id'}'>",
			$s->{'desc'} || $s->{'realhost'} || $s->{'host'},
			"</option>";
		}
	print "</select></td>\n";
	print "</form>\n";
	}

# Show button to un-install, if possible
if (!$pinfo[7]) {
	print "<form action=delete_pack.cgi>\n";
	print "<input type=hidden name=package value=\"$pinfo[0]\">\n";
	print "<input type=hidden name=search value=\"$in{'search'}\">\n";
	print "<td align=right>\n";
	print "<input type=submit value=\"$text{'edit_uninst'}\">\n";
	print "<select name=server>\n";
	print "<option value=-1>$text{'edit_all'}</option>\n";
	foreach $s (@got) {
		print "<option value='$s->{'id'}'>",
			$s->{'desc'} || $s->{'realhost'} || $s->{'host'},
			"</option>";
		}
	print "</select></td>\n";
	print "</form>\n";
	}

print "</tr> </table><p>\n";

# Show hosts with the package
print &ui_hr();
print &ui_subheading($text{'edit_hosts'});
@icons = map { "/servers/images/$_->{'type'}.gif" } @got;
@links = map { "edit_host.cgi?id=$_->{'id'}" } @got;
@titles = map { ($_->{'desc'} ? $_->{'desc'} :
		 $_->{'realhost'} ? "$_->{'realhost'}:$_->{'port'}" :
			      "$_->{'host'}:$_->{'port'}").
		($version{$_} ? "<br>$text{'edit_ver'} $version{$_}" : "") } @got;
&icons_table(\@links, \@titles, \@icons);

&remote_finished();
if ($in{'search'}) {
	&ui_print_footer("search.cgi?search=$in{'search'}", $text{'search_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}


