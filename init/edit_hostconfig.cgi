#!/usr/local/bin/perl
# edit_hostconfig.cgi
#
# Edit the settings in the hostconfig file, or the
# StartupItems script or plist associated with the
# action described in the hostconfig file.
#
# Also create a new startup action with associated script and plist
# and manually modify hostconfig file.

require './init-lib.pl';
require './hostconfig-lib.pl';
use File::Basename;
$access{'bootup'} == 1 || &error($text{'edit_ecannot'});

$ty = $ARGV[0];
if ($ty == 0) {
	# Editing an existing action in /etc/hostconfig
	$action_to_edit = $ARGV[1];
	&ui_print_header(undef, $text{'edit_title'}, "");
	%startuphash = &hostconfig_gather(startscript);
	$startscript = $startuphash{"$action_to_edit"};
	if ( $startscript ne "") {
		$startupdir = dirname("$startscript");
		$plistedit = "$startupdir/$config{'plist'}";
		}
	else {
		$plistedit = "";
		}

	#create the action edit table
	$actionedit = &hostconfig_editaction("$action_to_edit", "$startscript");
	print "<form action=modifyhostconfig.cgi method=post name=hostmod>\n";
	print "<table width=\"100%\" border><tr $tb> <td><b>", &text('index_action'), "</b></td>\n";
	print "<td><b>", &text('index_setting'), "</b></td></tr>\n";
	print "<tr $cb><td valign=middle>$action_to_edit</td>\n";
	print "<td>$actionedit</td></tr></table>\n";
	print "<input type=submit value='$text{'save'}'></form>\n";
	
	
	#create the edit file forms
	if ($startscript ne "") {
		print &ui_hr();
		print &text('edit_hostconfig_startup',
			"<tt>$startscript</tt>"),"<br>\n";
		#	}
		print "<form action=save_startscript.cgi method=post>\n";
		print "<textarea name=startup rows=20 cols=80>";
		open(STARTSCRIPT, "<$startscript");
		while(<STARTSCRIPT>) { print; }
		close(STARTSCRIPT);
		print "</textarea><br>\n";
		print "<input type=hidden name=\"action\" value=\"$action_to_edit\">\n";
		print "<input type=submit value='$text{'save'}'></form>\n";
		}
	if ($plistedit ne "") {
		print &ui_hr();
		print &text('edit_hostconfig_plist',
			"<tt>$plistedit</tt>"),"<br>\n";
		#	}
		print "<form action=save_startscript.cgi method=post>\n";
		print "<textarea name=plist rows=20 cols=80>";
		open(PLIST, "<$plistedit");
		while(<PLIST>) { print; }
		close(PLIST);
		print "</textarea><br>\n";
		print "<input type=hidden name=\"action\" value=\"$action_to_edit\">\n";
#		print "$plistedit</textarea><br>\n";
		print "<input type=submit value='$text{'save'}'></form>\n";
		}
	}

if ($ty == 1) {
	&ui_print_header(undef, $text{'edit_hostconfig_new'}, "");
	print "<HR>\n";

	print "<P>\n", &text('edit_hostconfig_noquotes',
		"<tt>$text{'edit_start'}</tt>"),"\n";

	print "<P>\n", &text('edit_hostconfig_startitems',
		"<tt>$text{'edit_hostconfig_actionname'}</tt>",
		"<tt>$text{'edit_hostconfig_scriptname'}</tt>"),"\n";

	print "<P>\n", &text('edit_hostconfig_array',
		"<tt>Provides</tt>", "<tt>Requires</tt>", "<tt>Uses</tt>"),"\n";
	
	print "<P>\n $text{'edit_hostconfig_further'}\n";

	#print "<form method=post action=save_hostconfig_action.cgi enctype=multipart/form-data>\n";
	print "<form method=post action=save_hostconfig_action.cgi>\n";
	print "<table border>\n";
	print "<tr $tb><td><b>Action Details</b></td></tr>\n";
	print "<tr $cb><td><table cellpadding=3>\n";

	# create the form fields

	$textt=&hostconfig_createtext("Action Name","req");
	print "<tr>", &hostconfig_createtext("$text{'edit_hostconfig_actionname'}","req");
	print "<td><input size=20 name=action_name value=\"\"></td></tr>\n";
	
	print "<tr>", &hostconfig_createtext("$text{'edit_hostconfig_scriptname'}","req");
	print "<td><input size=20 name=script_name value=\"\"></td></tr>\n";

	print "<tr>", &hostconfig_createtext("$text{'edit_start'}","req");
	print "<td><font size=-1><textarea rows=5 cols=80 name=execute></textarea></font></td></tr>\n";

	print "<tr>", &hostconfig_createtext("$text{'index_desc'}","");
	print "<td><input size=60 name=description value=\"\"></td></tr>\n";

	print "<tr>", &hostconfig_createtext("Provides","");
	print "<td><input size=60 name=provides value=\"\"></td></tr>\n";

	print "<tr>", &hostconfig_createtext("Requires","");
	print "<td><input size=60 name=requires value=\"\"></td></tr>\n";

	print "<tr>", &hostconfig_createtext("Uses","");
	print "<td><input size=60 name=uses value=\"\"></td></tr>\n";

	print "<tr>", &hostconfig_createtext("OrderPreference","");
	print "<td><SELECT name=order><option value=First>First</option>",
			"<option value=Early>Early</option>",
			"<option value='None selected'>None</option>",
			"<option value=Late>Late</option>",
			"<option value=Last>Last</option>",
			"</select></td></tr>\n";

	print "<tr>", &hostconfig_createtext("Start Message","");
	print "<td><input size=60 name=start value=\"\"></td></tr>\n";

	print "<tr>", &hostconfig_createtext("Stop Message","");
	print "<td><input size=60 name=stop value=\"\"></td></tr>\n";

	print "<tr>", &hostconfig_createtext("Start at boot time?","");
	print "<td><input name=boot type=radio value=\"-YES-\"> Yes\n";
	print "<input name=boot type=radio value=\"-NO-\" checked> No</td></tr>\n";

	print "<tr><td><font size=-1 color=#ff0000>* required field</font></td><td> </td></tr>\n";
	print "</table>";
	print "</td></tr></table>\n";
	print "<input type=submit value=\"Create\"></form>\n";

	}

if ($ty == 2) {
	
	&ui_print_header(undef, $text{'edit_hostconfig_title'}, "");
	print &text('edit_hostconfig_hostconfig',
		"<tt>$config{'hostconfig'}</tt>"),"<br>\n";
	print "<form action=save_startscript.cgi method=post>\n";
	print "<textarea name=hostconfig rows=20 cols=80>";
	open(LOCAL, "<$config{'hostconfig'}");
	while(<LOCAL>) { print; }
	close(LOCAL);
	print "</textarea><br>\n";
	print "<input type=submit value='$text{'save'}'></form>\n";
	print &ui_hr();

	#add reboot and shutdown messages to this page as well...
	print "<table cellpadding=5 width=100%>\n";
	if ($access{'reboot'}) {
		print "<form action=reboot.cgi>\n";
		print "<tr> <td><input type=submit ",
			"value=\"$text{'index_reboot'}\"></td>\n";
		print "</form>\n";
		print "<td>$text{'index_rebootmsg'}</td> </tr>\n";
		}

	if ($access{'shutdown'}) {
		print "<form action=shutdown.cgi>\n";
		print "<tr> <td><input type=submit ",
			"value=\"$text{'index_shutdown'}\"></td>\n";
		print "</form>\n";
		print "<td>$text{'index_shutdownmsg'}</td> </tr>\n";
		}
	print "</table>\n";
	}
	
&ui_print_footer("", $text{'index_return'});
