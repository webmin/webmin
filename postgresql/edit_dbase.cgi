#!/usr/local/bin/perl
# edit_dbase.cgi
# Show database tables

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
@titles = grep { &can_edit_db($_) } &list_databases();
$desc = "<tt>$in{'db'}</tt>";
if (@titles == 1 && $module_info{'usermin'}) {
	# Single-database mode
	&ui_print_header($desc, $text{'dbase_title'}, "", "edit_dbase", 1, 1);
	$single = 1;
	}
else {
	&ui_print_header($desc, $text{'dbase_title'}, "", "edit_dbase");
	}

# Is this database accepting connections?
if (!&accepting_connections($in{'db'})) {
	print "$text{'dbase_noconn'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

@titles = &list_tables($in{'db'});
if (&supports_indexes() && $access{'indexes'}) {
	@indexes = &list_indexes($in{'db'});
	}
if (&supports_views() && $access{'views'}) {
	@views = &list_views($in{'db'});
	}
if (&supports_sequences() && $access{'seqs'}) {
	@seqs = &list_sequences($in{'db'});
	}

if ($in{'search'}) {
	# Limit to those matching search
	@titles = grep { /\Q$in{'search'}\E/i } @titles;
	@indexes = grep { /\Q$in{'search'}\E/i } @indexes;
	@views = grep { /\Q$in{'search'}\E/i } @views;
	@seqs = grep { /\Q$in{'search'}\E/i } @seqs;
	print "<table width=100%><tr>\n";
	print "<td> <b>",&text('dbase_showing',
		"<tt>$in{'search'}</tt>"),"</b></td>\n";
	print "<td align=right><a href='edit_dbase.cgi?db=$in{'db'}'>",
		"$text{'view_searchreset'}</a></td>\n";
	print "</tr></table>\n";
	}

if (@titles+@indexes+@views+@seqs > $max_dbs && !$in{'search'}) {
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
elsif (@titles || @indexes || @views || @seqs) {
	@icons = ( ( map { "images/table.gif" } @titles ),
		   ( map { "images/index.gif" } @indexes ),
		   ( map { "images/view.gif" } @views ),
		   ( map { "images/seq.gif" } @seqs ),
		 );
	@links = ( ( map { "edit_table.cgi?db=$in{'db'}&table=".&urlize($_) }
		     	 @titles ),
		   ( map { "edit_index.cgi?db=$in{'db'}&index=".&urlize($_) }
                         @indexes ),
		   ( map { "edit_view.cgi?db=$in{'db'}&view=".&urlize($_) }
                         @views ),
		   ( map { "edit_seq.cgi?db=$in{'db'}&seq=".&urlize($_) }
                         @seqs ),
		 );
        @descs = ( ( map { "" } @titles ),
                   ( map { " ($text{'dbase_index'})" } @indexes),
                   ( map { " ($text{'dbase_view'})" } @views),
                   ( map { " ($text{'dbase_seq'})" } @seqs),
                 );
	#&show_buttons();
	@rowlinks = ( );
	if ($access{'tables'}) {
		print &ui_form_start("drop_tables.cgi");
		print &ui_hidden("db", $in{'db'});
		push(@rowlinks, &select_all_link("d", $form),
				&select_invert_link("d", $form) );
		@checks = ( ( @titles ),
			    ( map { "!".$_ } @indexes ),
			    ( map { "*".$_ } @views ),
			    ( map { "/".$_ } @seqs ),
			   );
		}
	print &ui_links_row(\@rowlinks);
	@dtitles = map { &html_escape($_) } ( @titles, @indexes, @views,@seqs );
	if ($displayconfig{'style'} == 1) {
		# Show as table
		foreach $t (@titles) {
			local $c = &execute_sql($in{'db'},
				"select count(*) from ".quote_table($t));
			push(@rows, $c->{'data'}->[0]->[0]);
			local @str = &table_structure($in{'db'}, $t);
			push(@fields, scalar(@str));
			}
		foreach $t (@indexes) {
			$str = &index_structure($in{'db'}, $t);
			push(@rows, "<i>$text{'dbase_index'}</i>");
			push(@fields, scalar(@{$str->{'cols'}}));
			}
		foreach $t (@views) {
			push(@rows, "<i>$text{'dbase_view'}</i>");
			push(@fields, undef);
			}
		foreach $t (@seqs) {
			$str = &sequence_structure($in{'db'}, $t);
			push(@rows, "<i>$text{'dbase_seq'}</i>");
			push(@fields, $str->{'last_value'});
			}
		&split_table([ "", $text{'dbase_table'}, $text{'dbase_rows'},
			       $text{'dbase_cols'} ],
			     \@checks, \@links, \@dtitles,
			     \@rows, \@fields) if (@titles);
		}
        elsif ($displayconfig{'style'} == 2) {
                # Just show table names
                @grid = ( );
                @all = ( @titles, @indexes, @views, @seqs );
                for(my $i=0; $i<@links; $i++) {
                        push(@grid, &ui_checkbox("d", $checks[$i]).
                          " <a href='$links[$i]'>".
                          &html_escape($all[$i])." ".$descs[$i]."</a>");
                        }
                print &ui_grid_table(\@grid, 4, 100, undef, undef,
				     $text{'dbase_header'});
                }
	else {
		# Show as icons
		@checks = map { &ui_checkbox("d", $_) } @checks;
		&icons_table(\@links, \@dtitles, \@icons, 5, undef, undef,undef,
			     @checks ? \@checks : undef);
		}
	print &ui_links_row(\@rowlinks);
	if ($access{'tables'}) {
		print &ui_form_end([ [ "delete", $text{'dbase_delete'} ] ]);
		}
	}
else {
	print "<b>$text{'dbase_none'}</b> <p>\n";
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
# Create table, view and sequence buttons
if ($access{'tables'}) {
	print "<table width=100%> <tr>\n";
	print "<form action=table_form.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<td width=33% nowrap><input type=submit value='$text{'dbase_add'}'>\n";
	print $text{'dbase_fields'},"\n";
	print "<input name=fields size=4 value='4'></td>\n";
	print "</form>\n";

	if (&supports_views() && $access{'views'}) {
		print "<form action=edit_view.cgi>\n";
		print "<input type=hidden name=db value='$in{'db'}'>\n";
		print "<input type=hidden name=new value=1>\n";
		print "<td width=33% nowrap align=center><input type=submit value='$text{'dbase_vadd'}'></td>\n";
		print "</form>\n";
		}

	if (&supports_sequences() && $access{'seqs'}) {
		print "<form action=edit_seq.cgi>\n";
		print "<input type=hidden name=db value='$in{'db'}'>\n";
		print "<input type=hidden name=new value=1>\n";
		print "<td width=33% nowrap align=right><input type=submit value='$text{'dbase_sadd'}'></td>\n";
		print "</form>\n";
		}

	print "</tr></table>\n";
	}
print "<table width=100%> <tr>\n";

# Drop database button
if ($access{'delete'}) {
	print "<form action=drop_dbase.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<td align=left valign=top width=20%><input type=submit ",
	      "value='$text{'dbase_drop'}'></td></form>\n";
	}
else {
	print "<td align=left valign=top width=20%></td>\n";
	}

# Backup and restore buttons
if ( &get_postgresql_version() >= 7.2 ) {
	if ($access{'backup'}) {
	    print "<form action=backup_form.cgi>\n" ;
	    print "<input type=hidden name=db value='$in{'db'}'>\n" ;
	    print "<td align=right valign=top width=20%><input type=submit " ,
		  "value='$text{'dbase_bkup'}'></td></form>\n"  ;
	}

	if ($access{'restore'}) {
	    print "<form action=restore_form.cgi>\n" ;
	    print "<input type=hidden name=db value='$in{'db'}'>\n" ;
	    print "<td align=left valign=top width=20%><input type=submit " ,
		  "value='$text{'dbase_rstr'}'></td></form>\n" ;
	}
}

print "<form action=exec_form.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<td align=right valign=top width=20%><input type=submit ",
      "value='$text{'dbase_exec'}'></td>\n";
print "</form>\n";
print "</tr> </table></form>\n";
}

