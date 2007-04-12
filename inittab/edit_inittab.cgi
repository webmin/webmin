#!/usr/local/bin/perl

require "./inittab-lib.pl";

&ReadParse();

&ui_print_header(undef,  &text( 'edit_inittab_title', $in{ 'id' } ), "", "index", 1, 1, undef );

print(
    "<form action=save_inittab.cgi><p><table border width=\"100%\">",
	"<tr ", $tb, ">",
	    "<td><b>", $text{ 'edit_inittab_details' }, "</b></td>",
	"</tr><tr ", $cb, "><td><table width=\"100%\">" );

@inittab = &parse_inittab();
($init) = grep { $_->{'id'} eq $in{'id'} } @inittab;

print(
"<tr>",
    "<td><b>", &hlink( $text{ 'inittab_id' }, "id" ), "</b></td>",
    "<td>", &p_entry( "id", $init->{'id'}, $config{ 'inittab_size' } ), "<input type=hidden name=oldid value='$init->{'id'}'></td>",
"</tr>\n");
print "<tr> <td><b>",&hlink($text{ 'inittab_active' },"active"),"</b></td>\n";
printf "<td><input type=radio name=comment value=0 %s> %s\n",
	$init->{'comment'} ? "" : "checked", $text{'yes'};
printf "<input type=radio name=comment value=1 %s> %s</td> </tr>\n",
	$init->{'comment'} ? "checked" : "", $text{'no'};
print ("<tr> <td><b>", &hlink( $text{ 'inittab_runlevels' }, "runlevels" ),
    "</b></td><td>" );

foreach $checkbox ( 0..6, "a", "b", "c" ) {
	local $runlevels;

	print( "<input type=checkbox name=", $checkbox, " value=1" );
	foreach $runlevel (@{$init->{'levels'}}) {
		print( " checked" ) if( $runlevel eq $checkbox );
		}
	print( ">", $checkbox, " " );
	}
print "</td></tr>\n";

$init->{'action'} = "kbdrequest" if ($init->{'action'} eq "kbrequest");
print("<tr>",
    "<td><b>", &hlink( $text{ 'inittab_action' }, "action" ), "</b></td>",
    "<td>", &p_select_wdl( "action", $init->{'action'}, ( "respawn", $text{ 'inittab_respawn' }, "wait", $text{ 'inittab_wait' }, "once", $text{ 'inittab_once' }, "wait", $text{ 'inittab_wait' }, "ondemand", $text{ 'inittab_ondemand' }, "initdefault", $text{ 'inittab_initdefault' }, "sysinit", $text{ 'inittab_sysinit' }, "powerwait", $text{ 'inittab_powerwait' }, "powerfail", $text{ 'inittab_powerfail' }, "powerokwait", $text{ 'inittab_powerokwait' }, "powerfailnow", $text{ 'inittab_powerfailnow' }, "ctrlaltdel", $text{ 'inittab_ctrlaltdel' }, "kbdrequest", $text{ 'inittab_kbdrequest' }, "bootwait", $text{'inittab_bootwait'}, "boot", $text{'inittab_boot'}, "off", $text{'inittab_off'} ) ), "</td>",
"</tr><tr>",
    "<td><b>", &hlink( $text{ 'inittab_process' }, "process" ), "</b></td>\n",
    "<td>", &p_entry( "process", $init->{'process'}, 50 ), "</td>",
"</tr>" );

print( "</td></tr></table></table>",
	"<table width=\"100%\">",
	    "<tr>",
		"<td align=left>", &p_button( "button", $text{ 'save' } ), "</td>",
		"<td align=right>", &p_button( "button", $text{ 'edit_inittab_del' } ), "</td>",
	    "</tr>",
	"</table></form>" );

&ui_print_footer( "", $text{ 'inittab_return' } );

