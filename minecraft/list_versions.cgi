#!/usr/local/bin/perl
# Show available server versions

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config, $download_page_url);

&ui_print_header(undef, $text{'versions_title'}, "");

my @vers = &list_installed_versions();
my $cur = &get_minecraft_jar();
if (@vers) {
	my @tds = ( "width=5" );
	my ($pid, undef, $runjar) = &is_any_minecraft_server_running();
	print &ui_form_start("change_version.cgi");
	print &ui_columns_start([ "",
				  $text{'versions_file'},
				  $text{'versions_desc'},
				  $text{'versions_size'},
				  $text{'versions_run'} ], 100, 0, \@tds);
	foreach my $v (@vers) {
		my @st = stat($v->{'path'});
		print &ui_radio_columns_row([
			$v->{'file'},
			$v->{'desc'},
			&nice_size($st[9]),
			$v->{'path'} eq $runjar ?
				"<font color=green>$text{'yes'}</font>" :
				"<font color=red>$text{'no'}</font>",
			], \@tds, "ver", $v->{'file'},
			&same_file($v->{'path'}, $cur));
		}
	print &ui_columns_end();
	print &ui_form_end([
		[ undef, $text{'versions_save'} ],
		$pid ? ( [ 'restart', $text{'versions_restart'} ] ) : ( ) ]);
	}
else {
	print "<b>$text{'versions_none'}</b><p>\n";
	}

# Show form to download / add one
print &ui_hr();
print &ui_form_start("add_version.cgi", "form-data");
print &ui_table_start($text{'versions_header'}, undef, 2);

# Source for new package
my (undef, $ver) = &get_server_jar_url();
print &ui_table_row($text{'versions_src'},
	&ui_radio_table("mode", 0,
		[ [ 0, $text{'versions_src0'}, &ui_textbox("url", undef, 60) ],
		  [ 1, $text{'versions_src1'}, &ui_upload("jar") ],
		  [ 2, &text('versions_src2', $ver,
		     &ui_link($download_page_url, $download_page_url,
			      undef, "target=_blank")) ] ]));

# Version number
print &ui_table_row($text{'versions_newver'},
	&ui_opt_textbox("newver", undef, 10, $text{'versions_newsame'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'versions_all'} ] ]);

&ui_print_footer("", $text{'index_return'});
