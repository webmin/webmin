#!/usr/local/bin/perl
# Select which schema files are included

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
&ui_print_header(undef, $text{'schema_title'}, "", "schema");
&ReadParse();

# Get included schemas
$conf = &get_config();
foreach $i (&find_value("include", $conf)) {
	if ($i =~ /^(.*)\// && $1 eq $config{'schema_dir'}) {
		$incs{$i} = ++$n;
		}
	}

# Show a table of all known schema files, with checkboxes
print $text{'schema_pagedesc'},"<p>\n";
@tds = ( "width=5", "width=20%", "width=65%", "width=10%", "width=5% nowrap" );
print &ui_form_start("save_schema.cgi", "post");
print &ui_columns_start([ "",
			  $text{'schema_file'},
			  $text{'schema_desc'},
			  $text{'schema_act'},
			  $text{'schema_move'} ], 100, 0, \@tds);
@files = sort { &schema_sorter } &list_schema_files();
for($i=0; $i<@files; $i++) {
	$s = $files[$i];
	@acts = ( "<a href='view_sfile.cgi?file=".&urlize($s->{'file'})."'>".
		  "$text{'schema_view'}</a>",
		  "<a href='edit_sfile.cgi?file=".&urlize($s->{'file'})."'>".
                  "$text{'schema_edit'}</a>" );
	if ($incs{$s->{'file'}}) {
		$mover = &ui_up_down_arrows(
			"up_schema.cgi?file=".&urlize($s->{'file'}),
			"down_schema.cgi?file=".&urlize($s->{'file'}),
			$i > 1,
			$i && $i < @files-1 && $incs{$files[$i+1]->{'file'}});
		}
	else {
		$mover = "";
		}
	print &ui_checked_columns_row(
		[ $s->{'name'},
		  $s->{'desc'} || $s->{'file'},
		  &ui_links_row(\@acts),
		  $mover,
		],
		\@tds, "d", $s->{'file'}, $incs{$s->{'file'}},
		$s->{'name'} eq 'core');
	}
print &ui_columns_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

sub schema_sorter
{
return ($incs{$a->{'file'}} || 999) <=> ($incs{$b->{'file'}} || 999);
}

