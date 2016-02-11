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

	# Table selector
	print &ui_form_start("edit_table.cgi");
	print $text{'dbase_jump'},"\n";
	print &ui_hidden("db", $in{'db'}),"\n";
	print &ui_select("table", undef, [ map { [ $_ ] } @titles ],
			 1, 0, 0, 0, "onChange='form.submit()'"),"\n";
	print &ui_submit($text{'index_jumpok'}),"<br>\n";
	print &ui_form_end();

	# View selector (if any)
	if (@views) {
		print &ui_form_start("edit_view.cgi");
		print $text{'dbase_vjump'},"\n";
		print &ui_hidden("db", $in{'db'}),"\n";
		print &ui_select("view", undef, [ map { [ $_ ] } @views ],
				 1, 0, 0, 0, "onChange='form.submit()'"),"\n";
		print &ui_submit($text{'index_jumpok'}),"<br>\n";
		print &ui_form_end();
		}

	# Index selector (if any)
	if (@indexes) {
		print &ui_form_start("edit_index.cgi");
		print $text{'dbase_ijump'},"\n";
		print &ui_hidden("db", $in{'db'}),"\n";
		print &ui_select("index", undef, [ map { [ $_ ] } @indexes ],
				 1, 0, 0, 0, "onChange='form.submit()'"),"\n";
		print &ui_submit($text{'index_jumpok'}),"<br>\n";
		print &ui_form_end();
		}
	print "<p>\n";
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
	@descs = ( ( map { "" } @titles ),
		   ( map { " ($text{'dbase_index'})" } @indexes),
		   ( map { " ($text{'dbase_view'})" } @views),
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
	if ($displayconfig{'style'} == 1) {
		# Show table names, fields and row counts
		foreach $t (@titles) {
			local $c = &execute_sql($in{'db'},
					"show create table ".quotestr($t));
			push(@types, &text('dbase_typetable',
				$c->{'data'}->[0]->[1] =~ /ENGINE=(\S+)/i ?
				  "$1" : "Unknown"));
			local $c = &execute_sql($in{'db'},
					"select count(*) from ".quotestr($t));
			push(@rows, $c->{'data'}->[0]->[0]);
			local @str = &table_structure($in{'db'}, $t);
			push(@fields, scalar(@str));
			}
		foreach $t (@indexes) {
			push(@types, $text{'dbase_typeindex'});
			$str = &index_structure($in{'db'}, $t);
			push(@rows, "<i>$text{'dbase_index'}</i>");
			push(@fields, scalar(@{$str->{'cols'}}));
			}
		foreach $v (@views) {
			push(@types, $text{'dbase_typeview'});
			push(@rows, undef);
			push(@fields, undef);
			}
		@dtitles = map { &html_escape($_) }
			       ( @titles, @indexes, @views );
		&split_table([ "", $text{'dbase_name'}, $text{'dbase_type'},
			           $text{'dbase_rows'}, $text{'dbase_cols'} ],
			     \@checks, \@links, \@dtitles, \@types,
			     \@rows, \@fields) if (@titles);
		}
	elsif ($displayconfig{'style'} == 2) {
		# Just show table names
		@grid = ( );
		@all = ( @titles, @indexes, @views );
		for(my $i=0; $i<@links; $i++) {
			push(@grid, &ui_checkbox("d", $checks[$i]).
			  " <a href='$links[$i]'>".
			  &html_escape($all[$i])." ".$descs[$i]."</a>");
			}
		print &ui_grid_table(\@grid, 4, 100, undef, undef,
				     $text{'dbase_header'});
		}
	else {
		# Show table icons
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
	&ui_print_footer(&get_databases_return_link($in{'db'}),
			 $text{'index_return'});
	}

sub show_buttons
{
if (!$access{'edonly'}) {
	print &ui_form_start("table_form.cgi");
	print &ui_hidden("db", $in{'db'});

	# Add a new table
	print &ui_submit($text{'dbase_add'})." ".$text{'dbase_fields'}.
			  " ".&ui_textbox("fields", 4, 4);
	print "&nbsp;\n";

	# Add a new view
	if (&supports_views() && $access{'views'}) {
		print &ui_submit($text{'dbase_addview'}, 'addview');
		print "&nbsp;\n";
		}

	# Delete this database
	if ($access{'delete'}) {
		print &ui_submit($text{'dbase_drop'}, 'dropdb');
		print "&nbsp;\n";
		}
	elsif (@titles) {
		print &ui_submit($text{'dbase_empty'}, 'dropdb');
		print "&nbsp;\n";
		}

	# Open backup form
	if ($access{'buser'}) {
		print &ui_submit($text{'dbase_backup'}, 'backupdb');
		print "&nbsp;\n";
		}

	# Execute SQL form
	print &ui_submit($text{'dbase_exec'}, 'exec');
	print "&nbsp;\n";

	print &ui_form_end();
	$form++;
	}
}

