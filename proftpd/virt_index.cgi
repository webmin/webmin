#!/usr/local/bin/perl
# virt_index.cgi
# Display a menu for some specific virtual server, or the default server

require './proftpd-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
$desc = $in{'virt'} eq '' ? $text{'virt_header2'} :
	      &text('virt_header1', $v->{'value'});
&ui_print_header($desc, $text{'virt_title'}, "",
	undef, undef, undef, undef, &restart_button());

# Display header and icons
print "<h3>$text{'virt_opts'}</h3>\n";
$anon_icon = { "icon" => "images/anon.gif",
	       "name" => $text{'virt_anon'},
	       "link" => "anon_index.cgi?virt=$in{'virt'}" };
$virt_icon = { "icon" => "images/virt.gif",
	       "name" => $text{'virt_virt'},
	       "link" => "edit_vserv.cgi?virt=$in{'virt'}" };
$ed_icon = { "icon" => "images/edit.gif",
	     "name" => $text{'virt_edit'},
	     "link" => "manual_form.cgi?virt=$in{'virt'}" };
&config_icons("virtual", "edit_virt.cgi?virt=$in{'virt'}&",
	      $anon_icon, $in{'virt'} ? ( $virt_icon, $ed_icon ) : ( ) );

# Display per-directory/limit options
@dir = ( &find_directive_struct("Directory", $conf) ,
	 &find_directive_struct("Limit", $conf) );
if (@dir) {
	print &ui_hr();
	print "<h3>$text{'virt_header'}</h3>\n";
	foreach $d (@dir) {
		if ($d->{'name'} eq 'Limit') {
			push(@links, "limit_index.cgi?limit=".
				     &indexof($d, @$conf)."&virt=$in{'virt'}");
			push(@titles, &text('virt_limit', $d->{'value'}));
			push(@icons, "images/limit.gif");
			}
		else {
			push(@links, "dir_index.cgi?idx=".
				     &indexof($d, @$conf)."&virt=$in{'virt'}");
			push(@titles, &text('virt_dir', $d->{'value'}));
			push(@icons, "images/dir.gif");
			}
		}
	&icons_table(\@links, \@titles, \@icons, 3);
	}
print "<p>\n";

print &ui_form_start("create_dirlimit.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_table_start($text{'index_dlheader'}, undef, 2);

print &ui_table_row($text{'index_dlmode'},
	&ui_radio_table("mode", 0,
		[ [ 0, $text{'virt_path'},
		    &ui_textbox("dir", undef, 50) ],
		  [ 1, $text{'virt_cmds'},
		    &ui_textbox("cmd", undef, 30) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});

