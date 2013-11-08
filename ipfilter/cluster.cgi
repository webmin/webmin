#!/usr/local/bin/perl
# Show hosts in firewall cluster

require './ipfilter-lib.pl';
&foreign_require("servers", "servers-lib.pl");
&ReadParse();
&ui_print_header(undef, $text{'cluster_title'}, undef, "cluster");

# Show existing servers
@servers = &list_cluster_servers();
if (@servers) {
	print "<form action=cluster_delete.cgi>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td width=10><br></td> ",
	      "<td><b>$text{'cluster_host'}</b></td> ",
	      "<td><b>$text{'cluster_desc'}</b></td> ",
	      "<td><b>$text{'cluster_os'}</b></td> </tr>\n";
	foreach $s (@servers) {
		print "<tr $cb>\n";
		print "<td width=10><input type=checkbox name=d value=$s->{'id'}></td>\n";
		print "<td>",$s->{'host'},"</td>\n";
		print "<td>",$s->{'desc'} || "<br>","</td>\n";
		foreach $t (@servers::server_types) {
			if ($t->[0] eq $s->{'type'}) {
				print "<td>$t->[1]</td>\n";
				}
			}
		print "</tr>\n";
		}
	print "</table>\n";
	print "<input type=submit value='$text{'cluster_delete'}'></form>\n";
	}
else {
	print "<b>$text{'cluster_none'}</b><p>\n";
	}

# Show buttons to add
print "<form action=cluster_add.cgi>\n";
print "<table width=100%><tr>\n";
@allservers = grep { $_->{'user'} } &servers::list_servers();
%gothost = map { $_->{'id'}, 1 } @servers;
@addservers = grep { !$gothost{$_->{'id'}} } @allservers;
if (@addservers) {
	print "<td><input type=submit name=add value='$text{'cluster_add'}'>\n";
	print "<select name=server>\n";
	foreach $s (@addservers) {
		print "<option value=$s->{'id'}>",
			$s->{'desc'} ? $s->{'desc'} : $s->{'host'},"</option>\n";
		}
	print "</select></td>\n";
	}
@groups = &servers::list_all_groups(\@allservers);
if (@groups) {
	print "<td align=right><input type=submit name=gadd ",
	      "value='$text{'cluster_gadd'}'>\n";
	print "<select name=group>\n";
	foreach $g (@groups) {
		print "<option>$g->{'name'}</option>\n";
		}
	print "</select></td>\n";
	}
print "</tr></table></form>\n";
if (!@allservers) {
	print "<b>$text{'cluster_need'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

