#!/usr/local/bin/perl
# create_form.cgi
# Display a form for creating a new mailing list

require './majordomo-lib.pl';
%access = &get_module_acl();
$access{'create'} || &error($text{'create_ecannot'});
&ui_print_header(undef, $text{'create_title'}, "");
local $cspan=' colspan="3"',$bcss=' style="display: box; float: left; padding: 10px;"';

print <<EOF;
<form action=create_list.cgi method=post>
<table border width=\"100%\">
<tr $tb> <td><b>$text{'create_header'}</b></td> </tr>
<tr $cb> <td><table width=\"100%\">
<tr> <td><b>$text{'create_name'} *</b></td>
     <td $cspan><input name=\"name\" size=\"20\"></td> </tr>
EOF

print "<tr>". &opt_input("reply_to", $text{'mesg_reply'},
                 $conf, $text{'mesg_none'}, 20);
print &opt_input("subject_prefix", $text{'mesg_subject'},
                 $conf, $text{'default'}, 20) ."</tr>\n";

print <<EOF;
<tr> <td><b>$text{'create_owner'} *</b></td>
     <td width=\"30%\"><input name=\"owner\" size=\"30\"></td>
     <td><b>$text{'create_password'} *</b></td>
     <td><input name=\"password\" type=\"password\" size=\"30\"></td> </tr>
<tr> <td><b>$text{'create_desc'}</b></td>
     <td $cspan><input name=\"desc\" size=\"60\"></td> </tr>
<tr> <td valign=top><b>$text{'create_info'}</b></td>
     <td $cspan><textarea name=\"info\" rows=\"5\" cols=\"50\"></textarea></td> </tr>
<tr> <td valign=top><b>$text{'create_footer'}</b></td>
     <td $cspan><textarea name=\"footer\" rows=\"3\" cols=\"60\"></textarea></td> </tr>

<tr> <td><b>$text{'create_moderate'}</b></td>
     <td><input type=\"radio\" name=\"moderate\" value=\"yes\"> $text{'yes'}
         <input type=\"radio\" name=\"moderate\" value=\"no\" checked> $text{'no'}
     </td> </tr>
<tr> <td><b>$text{'create_moderator'}</b></td>
     <td $cspan nowrap=""><input type=\"radio\" name=\"moderator_def\" value=\"1\" checked>
	 $text{'create_same'}
         <input type=\"radio\" name=\"moderator_def\" value=\"0\">
         <input name=\"moderator\" size=\"20\"></td> </tr>

<tr> <td><b>$text{'create_archive'}</b></td>
     <td $cspan><select name=\"archive\">
	 <option value=\"\"$text{'no'}</option>
	 <option value=\"Y\" selected>$text{'create_archiveyear'}</option>
	 <option value=\"M\">$text{'create_archivemonth'}</option>
	 <option value=\"D\">$text{'create_archiveday'}</option>
	 </select></td> </tr>

</table></td></tr></table>
EOF
print "<div $bcss>".&ui_submit($text{'create'})."</form>&nbsp&nbsp;* $text{'create_minimum'}</div>";

&ui_print_footer("", $text{'index_return'});

