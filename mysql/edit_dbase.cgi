#!/usr/local/bin/perl
# edit_dbase.cgi
# Show database tables and indexes

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
@titles = grep { &can_edit_db($_) } &list_databases();
$desc = "<tt>$in{'db'}</tt>";
if (@titles == 1 && $module_info{'usermin'}) {
	# Single-DB mode
	&ui_print_header($desc, $text{'dbase_title'}, "", "edit_dbase", 1, 1);
	$single = 1;
	}
else {
	&ui_print_header($desc, $text{'dbase_title'}, "", "edit_dbase");
	}
@titles = &list_tables($in{'db'});
if ($access{'indexes'}) {
	@indexes = &list_indexes($in{'db'});
	}
if (&supports_views() && $access{'views'}) {
	@views = &list_views($in{'db'});
	}

if ($in{'search'}) {
	# Limit to those matching search
	@titles = grep { /\Q$in{'search'}\E/i } @titles;
	@indexes = grep { /\Q$in{'search'}\E/i } @indexes;
	@views = grep { /\Q$in{'search'}\E/i } @views;
	print "<table width=100%><tr>\n";
	print "<td> <b>",&text('dbase_showing',
		"<tt>$in{'search'}</tt>"),"</b></td>\n";
	print "<td align=right><a href='edit_dbase.cgi?db=$in{'db'}'>",
		"$text{'view_searchreset'}</a></td>\n";
	print "</tr></table>\n";
	}

if (@titles+@indexes+@views > $max_dbs && !$in{'search'}) {
	# Too many tables to show .. display search and jump forms
	print &ui_form_start("edit_dbase.cgi");
	print &ui_hidden("db", $in{'db'}),"\n";
	print $text{'dbase_toomany'},"\n";
	print &ui_textbox("search", undef, 20),"\n";
	print &ui_submit($text{'index_search'}),"<br>\n";
	print &ui_form_end();

	print &ui_form_start("edit_table.cgi");
	print $text{'dbase_jump'},"\n";
	print &ui_hidden("db", $in{'db'}),"\n";
	print &ui_select("table", undef, [ map { [ $_ ] } @titles ]),"\n";
	print &ui_submit($text{'index_jumpok'}),"<br>\n";
	print &ui_form_end();
	}
elsif (@titles || @indexes) {
	@icons = ( ( map { "images/table.gif" } @titles ),
		   ( map { "images/index.gif" } @indexes ),
		   ( map { "images/view.gif" } @views ),
		 );
	@links = ( ( map { "edit_table.cgi?db=$in{'db'}&table=".&urlize($_) }
		     	 @titles ),
		   ( map { "edit_index.cgi?db=$in{'db'}&index=".&urlize($_) }
                         @indexes ),
		   ( map { "edit_view.cgi?db=$in{'db'}&view=".&urlize($_) }
                         @views ),
		 );
	#&show_buttons();
	print &ui_form_start("drop_tables.cgi");
	print &ui_hidden("db", $in{'db'});
	@rowlinks = ( &select_all_link("d", $form),
		      &select_invert_link("d", $form) );
	print &ui_links_row(\@rowlinks);
	@checks = ( ( @titles ),
		    ( map { "!".$_ } @indexes ),
		    ( map { "*".$_ } @views ),
		  );
	if ($config{'style'}) {
		foreach $t (@titles) {
			local $c = &execute_sql($in{'db'},
					"select count(*) from ".quotestr($t));
			push(@rows, $c->{'data'}->[0]->[0]);
			local @str = &table_structure($in{'db'}, $t);
			push(@fields, scalar(@str));
			}
		foreach $t (@indexes) {
			$str = &index_structure($in{'db'}, $t);
			push(@rows, "<i>$text{'dbase_index'}</i>");
			push(@fields, scalar(@{$str->{'cols'}}));
			}
		foreach $v (@indexes) {
			push(@rows, "<i>$text{'dbase_view'}</i>");
			push(@fields, undef);
			}
		@dtitles = map { &html_escape($_) }
			       ( @titles, @indexes, @views );
		&split_table([ "", $text{'dbase_table'}, $text{'dbase_rows'},
			       $text{'dbase_cols'} ],
			     \@checks, \@links, \@dtitles,
			     \@rows, \@fields) if (@titles);
		}
	else {
		@checks = map { &ui_checkbox("d", $_) } @checks;
		@titles = map { &html_escape($_) } ( @titles, @indexes, @views);
		&icons_table(\@links, \@titles, \@icons, 5, undef, undef, undef,
			     \@checks);
		}
	print &ui_links_row(\@rowlinks);
	if (!$access{'edonly'}) {
		print &ui_form_end([ [ "delete", @indexes ? $text{'dbase_delete2'} : $text{'dbase_delete'} ] ]);
		}
	else {
		print &ui_form_end();
		}
	}
else {
	if ($in{'search'}) {
		print "<b>$text{'dbase_none2'}</b> <p>\n";
		}
	else {
		print "<b>$text{'dbase_none'}</b> <p>\n";
		}
	}
&show_buttons();

if ($single) {
	&ui_print_footer("/", $text{'index'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

sub show_buttons
{
if (!$access{'edonly'}) {
	$count = 2;
	$count++ if ($access{'delete'});
	$count++ if ($access{'buser'});
	$count++ if ($mysql_version >= 5);
	$pct = int(100/$count);

	print "<table width=100%> <tr>\n";

	# Add a new table
	print "<form action=table_form.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<td width=$pct% nowrap><input type=submit ",
	      "value='$text{'dbase_add'}'>\n";
	print $text{'dbase_fields'},"\n";
	print "<input name=fields size=4 value='4'></td>\n";
	print "</form>\n";
	$form++;

	# Add a new view
	if (&supports_views() && $access{'views'}) {
		print "<form action=edit_view.cgi>\n";
		print "<input type=hidden name=db value='$in{'db'}'>\n";
		print "<input type=hidden name=new value=1>\n";
		print "<td align=middle width=$pct%><input type=submit ",
		      "value='$text{'dbase_addview'}'></td></form>\n";
		$form++;
		}

	if ($access{'delete'}) {
		print "<form action=drop_dbase.cgi>\n";
		print "<input type=hidden name=db value='$in{'db'}'>\n";
		print "<td align=middle width=$pct%><input type=submit ",
		      "value='$text{'dbase_drop'}'></td></form>\n";
		$form++;
		}

	if ($access{'buser'}) {
		print "<form action=backup_form.cgi>\n";
		print "<input type=hidden name=db value='$in{'db'}'>\n";
		print "<td align=middle width=$pct%><input type=submit ",
		      "value='$text{'dbase_backup'}'></td></form>\n";
		$form++;
		}

	print "<form action=exec_form.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<td align=right width=$pct%><input type=submit ",
	      "value='$text{'dbase_exec'}'></td>\n";
	print "</form>\n";
	$form++;
	print "</tr> </table></form>\n";
	}
}

