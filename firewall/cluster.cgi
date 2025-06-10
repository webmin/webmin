#!/usr/local/bin/perl
# Show hosts in firewall cluster

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
$access{'cluster'} || &error($text{'ecluster'});
&foreign_require("servers", "servers-lib.pl");
&ui_print_header($text{"index_title_v${ipvx}"}, $text{'cluster_title'}, undef, "cluster");

# Show existing servers
@servers = &list_cluster_servers();
if (@servers) {
	print &ui_form_start("cluster_delete.cgi", "post");
        print &ui_hidden("version", ${ipvx_arg});
	print &ui_columns_start([ "",
				  $text{'cluster_host'},
				  $text{'cluster_desc'},
				  $text{'cluster_os'} ], 100);
	foreach $s (@servers) {
		($t) = grep { $_->[0] eq $s->{'type'} } @servers::server_types;
		print &ui_checked_columns_row([
			&html_escape($s->{'host'}),
			&html_escape($s->{'desc'}),
			$t->[1],
			], undef, "d", $s->{'id'});
		}
	print &ui_columns_end();
	print &ui_form_end([ [ undef, $text{'cluster_delete'} ] ]);
	}
else {
	print "<b>$text{'cluster_none'}</b><p>\n";
	}

# Show buttons to add
print "<form action=cluster_add.cgi>\n";
print &ui_hidden("version", ${ipvx_arg});
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

&ui_print_footer("index.cgi?version=${ipvx_arg}", $text{'index_return'});

