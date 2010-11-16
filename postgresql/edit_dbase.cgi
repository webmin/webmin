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

	# Sequence selector (if any)
	if (@seqs) {
		print &ui_form_start("edit_seq.cgi");
		print $text{'dbase_sjump'},"\n";
		print &ui_hidden("db", $in{'db'}),"\n";
		print &ui_select("seq", undef, [ map { [ $_ ] } @seqs ],
				 1, 0, 0, 0, "onChange='form.submit()'"),"\n";
		print &ui_submit($text{'index_jumpok'}),"<br>\n";
		print &ui_form_end();
		}
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
			local $c;
			eval {
				local $main::error_must_die = 1;
				$c = &execute_sql($in{'db'},
				    "select count(*) from ".quote_table($t));
				};
			$c ||= { 'data' => [ [ "-" ] ] };
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

# Check if the user is from Virtualmin, and if so link back to his DB list
if (&foreign_check("virtual-server")) {
	$virtual_server::no_virtualmin_plugins = 1;
	&foreign_require("virtual-server", "virtual-server-lib.pl");
	if (!&virtual_server::master_admin() &&
	    !&virtual_server::reseller_admin()) {
		# Is a domain owner .. which domain is this DB in?
		foreach my $d (grep { &virtual_server::can_edit_domain($_) }
				    &virtual_server::list_domains()) {
			@dbs = &virtual_server::domain_databases($d);
			($got) = grep { $_->{'name'} eq $in{'db'} &&
					$_->{'type'} eq 'postgres' } @dbs;
			if ($got) {
				$virtualmin = $d->{'id'};
				}
			}
		}
	}

if ($virtualmin) {
	&ui_print_footer("../virtual-server/list_databases.cgi?dom=$virtualmin",
			 $text{'index_return'});
	}
elsif ($single) {
	&ui_print_footer("/", $text{'index'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

# Display buttons for adding tables, views and so on
sub show_buttons
{
print "<table><tr>\n";
if ($access{'tables'}) {
	# Add a new table
	print &ui_form_start("table_form.cgi");
	print &ui_hidden("db", $in{'db'});
	print "<td>",&ui_submit($text{'dbase_add'})." ".$text{'dbase_fields'}.
		     " ".&ui_textbox("fields", 4, 4),"</td>\n";
	print &ui_form_end();
	$form++;

	# Add a new view
	if (&supports_views() && $access{'views'}) {
		print &ui_form_start("edit_view.cgi");
		print &ui_hidden("db", $in{'db'});
		print &ui_hidden("new", 1);
		print "<td>",&ui_submit($text{'dbase_vadd'}),"</td>\n";
		print &ui_form_end();
		$form++;
		}

	# Add a new sequence
	if (&supports_sequences() && $access{'seqs'}) {
		print &ui_form_start("edit_seq.cgi");
		print &ui_hidden("db", $in{'db'});
		print &ui_hidden("new", 1);
		print "<td>",&ui_submit($text{'dbase_sadd'}),"</td>\n";
		print &ui_form_end();
		$form++;
		}
	}

# Drop database button
if ($access{'delete'}) {
	print &ui_form_start("drop_dbase.cgi");
	print &ui_hidden("db", $in{'db'});
	print "<td>",&ui_submit($text{'dbase_drop'}),"</td>\n";
	print &ui_form_end();
	$form++;
	}

# Backup and restore buttons
if (&get_postgresql_version() >= 7.2) {
	if ($access{'backup'}) {
		print &ui_form_start("backup_form.cgi");
		print &ui_hidden("db", $in{'db'});
		print "<td>",&ui_submit($text{'dbase_bkup'}),"</td>\n";
		print &ui_form_end();
		$form++;
		}
	if ($access{'restore'}) {
		print &ui_form_start("restore_form.cgi");
		print &ui_hidden("db", $in{'db'});
		print "<td>",&ui_submit($text{'dbase_rstr'}),"</td>\n";
		print &ui_form_end();
		$form++;
		}
	}

# Execute SQL form
print &ui_form_start("exec_form.cgi");
print &ui_hidden("db", $in{'db'});
print "<td>",&ui_submit($text{'dbase_exec'}),"</td>\n";
print &ui_form_end();
$form++;

print "</tr></table>\n";
}

