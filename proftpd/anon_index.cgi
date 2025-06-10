#!/usr/local/bin/perl
# anon_index.cgi
# Display a menu for anonymous section options

require './proftpd-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
$anonstr = &find_directive_struct("Anonymous", $conf);
if (!$anonstr) {
	# Go to the anon options page
	&redirect("edit_aserv.cgi?virt=$in{'virt'}&init=1");
	exit;
	}
$anon = $anonstr->{'members'};

# Display header and config icons
$desc = $in{'virt'} eq '' ? $text{'anon_header2'} :
	      &text('anon_header1', $v->{'value'});
&ui_print_header($desc, $text{'anon_title'}, "", undef, undef, undef, undef, &restart_button());

print "<h3>$text{'anon_opts'}</h3>\n";
$anon_icon = { "icon" => "images/anon.gif",
	       "name" => $text{'anon_anon'},
	       "link" => "edit_aserv.cgi?virt=$in{'virt'}" };
&config_icons("anon", "edit_anon.cgi?virt=$in{'virt'}&", $anon_icon);

# Display per-directory/limit options
@dir = ( &find_directive_struct("Directory", $anon) ,
	 &find_directive_struct("Limit", $anon) );
if (@dir) {
	print &ui_hr();
	print "<h3>$text{'virt_header'}</h3>\n";
	foreach $d (@dir) {
		if ($d->{'name'} eq 'Limit') {
			push(@links, "limit_index.cgi?virt=$in{'virt'}&".
				     "anon=1&limit=".&indexof($d, @$anon));
			push(@titles, &text('virt_limit', $d->{'value'}));
			push(@icons, "images/limit.gif");
			}
		else {
			push(@links, "dir_index.cgi?virt=$in{'virt'}&".
				     "anon=1&idx=".&indexof($d, @$anon));
			push(@titles, &text('virt_dir', $d->{'value'}));
			push(@icons, "images/dir.gif");
			}
		}
	&icons_table(\@links, \@titles, \@icons, 3);
	}
print "<p>\n";

print &ui_form_start("create_dirlimit.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_hidden("anon", 1);
print &ui_table_start($text{'index_dlheader'}, undef, 2);

print &ui_table_row($text{'index_dlmode'},
	&ui_radio_table("mode", 0,
		[ [ 0, $text{'virt_path'},
		    &ui_textbox("dir", undef, 50) ],
		  [ 1, $text{'virt_cmds'},
		    &ui_textbox("cmd", undef, 30) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
	"", $text{'index_return'});

