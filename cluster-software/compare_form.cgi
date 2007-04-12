#!/usr/local/bin/perl
# Show form for comparing packages on multiple servers

require './cluster-software-lib.pl';
&ui_print_header(undef, $text{'compare_title'}, "");

print "$text{'compare_desc'}<p>\n";

print &ui_form_start("compare.cgi", "post");
print "<table>\n";

# Hosts to compare
print "<tr> <td valign=top><b>$text{'compare_hosts'}</b></td> <td>\n";
print &ui_radio("all", 1, [ [ 1, $text{'compare_all'} ],
			    [ 0, $text{'compare_sel'} ] ]),"<br>\n";
%smap = map { $_->{'id'}, $_ } &list_servers();
@sel = map { [ $_->{'id'}, &server_name($smap{$_->{'id'}}) ] }
	   &list_software_hosts();
@groups = &servers::list_all_groups();
push(@sel, map { [ "group_".$_->{'name'}, &text('edit_group', $_->{'name'}) ] }
	       @groups);
print &ui_select("hosts", undef, \@sel, 5, 1);
print "</td> </tr>\n";

# Show all, or just mismatches?
print "<tr> <td><b>$text{'compare_showall'}</b></td> <td>\n";
print &ui_radio("showall", 0, [ [ 1, $text{'compare_showall1'} ],
				[ 0, $text{'compare_showall0'} ] ]);
print "</td> </tr>\n";

print "</table>\n";
print &ui_submit($text{'compare_ok'});
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});
