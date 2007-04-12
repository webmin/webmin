#!/usr/local/bin/perl
# list_assigns.cgi
# Displays a list of all user assignments

require './qmail-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'assigns_title'}, "");
print "$text{'assigns_desc'}<p>\n";

@assigns = &list_assigns();
&assign_form();

if ($in{'search'}) {
	# Restrict to search results
	@assigns = grep { $_->{'address'} =~ /$in{'search'}/ } @assigns;
	}
elsif ($config{'max_records'} && @assigns > $config{'max_records'}) {
	# Show search form
	print $text{'assigns_toomany'},"<br>\n";
	print "<form action=list_assigns.cgi>\n";
	print "<input type=submit value='$text{'assigns_go'}'>\n";
	print "<input name=search size=20></form>\n";
	undef(@assigns);
	}

if (@assigns) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@assigns = sort { lc($a->{'address'}) cmp lc($b->{'address'}) }
				@assigns;
		}

	# output table of assigns
        print &ui_form_start("delete_assigns.cgi", "post");
        print &select_all_link("d", 1),"\n";
        print &select_invert_link("d", 1),"<br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td width=5><br></td> ",
	      "<td><b>$text{'assigns_address'}</b></td> ",
	      "<td><b>$text{'assigns_user'}</b></td> ",
	      "<td><b>$text{'assigns_uid'}</b></td> ",
	      "<td><b>$text{'assigns_gid'}</b></td> ",
	      "<td><b>$text{'assigns_home'}</b></td> </tr>\n";
	foreach $a (@assigns) {
		print "<tr $cb>\n";
		print "<td width=5>",&ui_checkbox("d", $a->{'address'}),"</td>\n";
		print "<td><a href='edit_assign.cgi?idx=$a->{'idx'}'>",
		      ($a->{'mode'} eq '+' ? "$a->{'address'}*"
					   : &html_escape($a->{'address'})),
		      "</a></td>\n";
		print "<td>",&html_escape($a->{'user'}),"</td>\n";
		print "<td>",&html_escape($a->{'uid'}),"</td>\n";
		print "<td>",&html_escape($a->{'gid'}),"</td>\n";
		print "<td>",&html_escape($a->{'home'}),"</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
        print &select_all_link("d", 1),"\n";
        print &select_invert_link("d", 1),"<br>\n";
        print &ui_form_end([ [ "delete", $text{'assigns_delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});


