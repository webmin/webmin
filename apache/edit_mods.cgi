#!/usr/local/bin/perl
# Show Apache modules that are enabled by the distro config files

require './apache-lib.pl';
&ReadParse();
$access{'global'} == 1 || &error($text{'mods_ecannot'});
&ui_print_header(undef, $text{'mods_title'}, "");

print $text{'mods_desc'},"<p>\n";

# Show a table of modules, in two columns
print &ui_form_start("save_mods.cgi", "post");
@mods = &list_configured_apache_modules();

$sp = int(@mods/2);
foreach my $ms ([ @mods[0..$sp] ], [ @mods[$sp+1..$#mods] ]) {
	@tds = ( "width=5" );
	$g = &ui_columns_start([ "",
				 $text{'mods_mod'},
				 $text{'mods_state'} ], undef, 0, \@tds);
	foreach $m (@$ms) {
		$g .= &ui_checked_columns_row([
			$m->{'mod'},
			$m->{'enabled'} ? $text{'mods_enabled'} :
			 $m->{'disabled'} ? $text{'mods_disabled'} :
					    $text{'mods_available'}
			], \@tds, "m", $m->{'mod'}, $m->{'enabled'});
		}
	$g .= &ui_columns_end();
	push(@grid, $g);
	}
print &ui_grid_table(\@grid, 2, 100);
print &ui_form_end([ [ undef, $text{'mods_save'} ] ]);

&ui_print_footer("index.cgi?mode=global", $text{'index_return2'});

