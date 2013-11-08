#!/usr/local/bin/perl
# list_hosts.cgi
# Display other webmin servers to which the configuration should be copied
# and run.

require './cfengine-lib.pl';
&foreign_require("servers", "servers-lib.pl");
&ui_print_header(undef, $text{'hosts_title'}, "", "hosts");

# Show existing servers
print &ui_subheading($text{'hosts_hosts'});
@servers = &list_servers();
@hosts = &list_cfengine_hosts();
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	next if (!$s);
	push(@titles, &server_name($s));
	push(@links, "edit_host.cgi?id=$h->{'id'}");
	push(@icons, "$gconfig{'webprefix'}/servers/images/$s->{'type'}.gif");
	$gothost{$h->{'id'}}++;
	}
if (@links) {
	&icons_table(\@links, \@titles, \@icons);
	}
else {
	print "<b>$text{'hosts_nohosts'}</b><p>\n";
	}

# Display adding form
print "<form action=add.cgi>\n";
print "<table width=100%><tr>\n";
@addservers = grep { !$gothost{$_->{'id'}} } @servers;
if (@addservers) {
	print "<td><input type=submit name=add value='$text{'hosts_add'}'>\n";
	print "<select name=server>\n";
	foreach $s (@addservers) {
		print "<option value=$s->{'id'}>",&server_name($s),"</option>\n";
		}
	print "</select></td>\n";
	}
@groups = &servers::list_all_groups(\@servers);
if (@groups) {
	print "<td align=right><input type=submit name=gadd ",
	      "value='$text{'hosts_gadd'}'>\n";
	print "<select name=group>\n";
	foreach $g (@groups) {
		print "<option>$g->{'name'}</option>\n";
		}
	print "</select></td>\n";
	}
print "</tr></table></form>\n";

# Display run form
if (@hosts) {
	print &ui_hr();
	print "<form action=cluster.cgi>\n";
	print "<table width=100%>\n";
	print "<tr> <td><input type=submit value='$text{'hosts_run'}'></td>\n";
	print "<td>$text{'hosts_rundesc'}</td> </tr>\n";
	print "<tr> <td><input type=submit name=copy ",
	      "value='$text{'hosts_copy'}'></td>\n";
	print "<td>$text{'hosts_copydesc'}</td> </tr>\n";
	print "</table>\n";

	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'hosts_opts'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	&show_run_form();
	print "</table></td></tr></table>\n";
	print "</form>\n";
	}

&ui_print_footer("", $text{'index_return'});

