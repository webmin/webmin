#!/usr/local/bin/perl
# Select which schema files are included

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'schema'} || &error($text{'schema_ecannot'});
&ui_print_header(undef, $text{'schema_title'}, "", "schema");

# Get included schemas
if (&get_config_type() == 1) {
	$conf = &get_config();
	foreach $i (&find_value("include", $conf)) {
		if ($i =~ /^(.*)\// && $1 eq $config{'schema_dir'}) {
			$incs{$i} = ++$n;
			}
		}
	$editable = 1;
	}

# Show a table of all known schema files, with checkboxes
print $text{'schema_pagedesc'},"<p>\n";
@tds = ( $editable ? ( "width=5" ) : ( ),
	 "width=20%", "width=65%", "width=10%", "width=5% nowrap" );
print &ui_form_start("save_schema.cgi", "post");
print &ui_columns_start([ $editable ? ( "" ) : ( ),
			  $text{'schema_file'},
			  $text{'schema_desc'},
			  $text{'schema_act'},
			  $editable ? ( $text{'schema_move'} ) : ( ) ],
			100, 0, \@tds);
@files = sort { &schema_sorter } &list_schema_files();
for($i=0; $i<@files; $i++) {
	$s = $files[$i];
	@acts = ( &ui_link("view_sfile.cgi?file=".&urlize($s->{'file'})."",$text{'schema_view'}),
		  &ui_link("edit_sfile.cgi?file=".&urlize($s->{'file'})."",$text{'schema_edit'}) );
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
	if ($editable) {
		# With move / enable checkbox
		print &ui_checked_columns_row(
			[ $s->{'name'},
			  $s->{'desc'} || $s->{'file'},
			  &ui_links_row(\@acts),
			  $mover,
			],
			\@tds, "d", $s->{'file'}, $incs{$s->{'file'}},
			$s->{'name'} eq 'core');
		}
	else {
		# View files only
		print &ui_columns_row(
			[ $s->{'name'},
                          $s->{'desc'} || $s->{'file'},
                          &ui_links_row(\@acts) ], \@tds);
		}
	}
print &ui_columns_end();
print &ui_form_end($editable ? [ [ undef, $text{'save'} ] ] : [ ]);

&ui_print_footer("", $text{'index_return'});

sub schema_sorter
{
return ($incs{$a->{'file'}} || 999) <=> ($incs{$b->{'file'}} || 999);
}

