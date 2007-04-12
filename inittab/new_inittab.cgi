#!/usr/local/bin/perl

require "./inittab-lib.pl";

&ReadParse();

&ui_print_header(undef,  &text( 'new_inittab_title', $in{ 'id' } ), "", "index", 1, 1, undef );

print(
"<form action=save_inittab.cgi><p>",
"<table border width=\"100%\">",
    "<tr ", $tb, ">",
        "<td><b>", $text{ 'edit_inittab_details' }, "</b></td>",
    "</tr><tr ", $cb, ">",
	"<td>",
	    "<table width=\"100%\">",
    		"<tr>",
        	    "<td><b>", &hlink( $text{ 'inittab_id' }, "id" ), "</b></td>",
        	    "<td>", &p_entry( "id", "", 4 ), "</td>",
    		"</tr><tr>",
		    "<td><b>",&hlink($text{ 'inittab_runlevels' }, "runlevels"),
		    "</b></td>",
		    "<td><input type=checkbox name=0 value=1>0 <input type=checkbox name=1 value=1>1 <input type=checkbox name=2 value=1>2 <input type=checkbox name=3 value=1>3 <input type=checkbox name=4 value=1>4 <input type=checkbox name=5 value=1>5 <input type=checkbox name=6 value=1>6 <input type=checkbox name=a value=1>A <input type=checkbox name=b value=1>B <input type=checkbox name=c value=1>C</td>",
		"</tr><tr>",
    		    "<td><b>",&hlink($text{'inittab_action'}, "action"),
		    "</b></td>",
    		    "<td>", &p_select_wdl( "action", "", ( "respawn", $text{ 'inittab_respawn' }, "wait", $text{ 'inittab_wait' }, "once", $text{ 'inittab_once' }, "wait", $text{ 'inittab_wait' }, "ondemand", $text{ 'inittab_ondemand' }, "initdefault", $text{ 'inittab_initdefault' }, "sysinit", $text{ 'inittab_sysinit' }, "powerwait", $text{ 'inittab_powerwait' }, "powerfail", $text{ 'inittab_powerfail' }, "powerokwait", $text{ 'inittab_powerokwait' }, "powerfailnow", $text{ 'inittab_powerfailnow' }, "ctraltdel", $text{ 'inittab_ctrlaltdel' }, "kbdrequest", $text{ 'inittab_kbdrequest' } ) ), "</td>",
		"</tr><tr>",
    		    "<td><b>",&hlink($text{'inittab_process'}, "process"),
		    "</b></td>",
    		    "<td>", &p_entry( "process", "" ), "</td>",
		"</tr>",
	    "</table>",
	"</td>",
    "</tr>",
"</table>",
"<table width=\"100%\">",
    "<tr>",
	"<td align=left>", &p_button( "button", $text{ 'create' } ), "</td>",
    "</tr>",
"</table></form>" );

&ui_print_footer( "/inittab/index.cgi", $text{ 'inittab_return' } );
