#!/usr/local/bin/perl
# list_grants.cgi
# Display all granted privileges

require './postgresql-lib.pl';
$access{'users'} || &error($text{'grant_ecannot'});
&ui_print_header(undef, $text{'grant_title'}, "", "list_grants");
&ReadParse();

# Check for down databases
@str = &table_structure($config{'basedb'}, "pg_catalog.pg_database");
foreach $f (@str) {
	$hasconn++ if ($f->{'field'} eq 'datallowconn');
	}
if ($hasconn) {
	$rv = &execute_sql_safe($config{'basedb'}, "select datname,datallowconn from pg_database");
	foreach $r (@{$rv->{'data'}}) {
		$dbup{$r->[0]} = ($r->[1] =~ /^(t|1)/i);
		}
	}

# Build a list of tables
@dblist = &list_databases();
foreach $d (@dblist) {
	next if (!$dbup{$d} && $hasconn);
	if (&supports_schemas($d)) {
		$s = &execute_sql_safe($d, "select relname,relacl,pg_namespace.nspname,reltype,relkind,relhasrules,\'$d\' from pg_class, pg_namespace where relnamespace = pg_namespace.oid and (relkind = \'r\' OR relkind = \'S\') and relname !~ \'^pg_\' order by relname");
		}
	else {
		$s = &execute_sql_safe($d, "select relname,relacl,\'public\',reltype,relkind,relhasrules,\'$d\' from pg_class where (relkind = \'r\' OR relkind = \'S\') and relname !~ \'^pg_\' order by relname");
		}
	push(@tables, @{$s->{'data'}});
	}

if ($in{'search'}) {
	# Limit to those matching search
	@tables = grep { $_->[0] =~ /\Q$in{'search'}\E/i ||
			 $_->[6] =~ /\Q$in{'search'}\E/i } @tables;
	print "<table width=100%><tr>\n";
	print "<td> <b>",&text('grant_showing',
		"<tt>$in{'search'}</tt>"),"</b></td>\n";
	print "<td align=right><a href='list_grants.cgi'>",
		"$text{'view_searchreset'}</a></td>\n";
	print "</tr></table>\n";
	}

if (@tables > $max_dbs && !$in{'search'}) {
	# If too many, show a search form
	print &ui_form_start("list_grants.cgi");
	print $text{'grant_toomany'},"\n";
	print &ui_textbox("search", undef, 20),"\n";
	print &ui_submit($text{'index_search'}),"<br>\n";
	print &ui_form_end();
	}
elsif (@tables) {
	# Show the results
	@tds = ( "width=5" );
	print &ui_form_start("delete_grants.cgi", "post");
	print &ui_hidden("search", $in{'search'});
	@rowlinks = ( &select_all_link("d"),
		      &select_invert_link("d") );
	print &ui_links_row(\@rowlinks);
	print &ui_columns_start([ "",
				  $text{'grant_tvi'},
				  $text{'grant_type'},
				  $text{'grant_db'},
				  $text{'grant_users'} ], 100, 0, \@tds);
	foreach $g (@tables) {
		$type = $g->[4] eq 'r' && $g->[5] eq 't' ? 'v' : $g->[4];
		$tname = $g->[2] eq "public" ? $g->[0] : $g->[2].".".$g->[0];
		$d = $g->[6];
		local @cols;
		push(@cols, "<a href='edit_grant.cgi?db=$d&table=$g->[0]&".
		      "ns=$g->[2]&type=$type&search=".&urlize($in{'search'}).
		      "'>".&html_escape($tname)."</a>");
		push(@cols, $text{"grant_$type"});
		push(@cols, &html_escape($d));
		my @gr = &extract_grants($g->[1]);
		local $gstr;
		foreach $gr (@gr) {
			$gstr .= "&nbsp;|&nbsp;" if ($gr ne $gr[0]);
			if ($gr->[0] eq "") {
				$gstr .= $text{'grant_public'};
				}
			elsif ($gr->[0] =~ /^group\s+(\S+)/) {
				$gstr .= &text('grant_group',
					"<tt>".&html_escape($1)."</tt>");
				}
			else {
				$gstr .= "<tt>".&html_escape($gr->[0])."</tt>";
				}
			}
		push(@cols, $gstr);
		print &ui_checked_columns_row(\@cols, \@tds, "d",
			join("/", $d, $g->[0], $g->[2], $type));
		}
	print &ui_columns_end();
	print &ui_links_row(\@rowlinks);
	print &ui_form_end([ [ "delete", $text{'grant_delete'} ] ]);
	}
else {
	print "<b>$text{'grant_none'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

