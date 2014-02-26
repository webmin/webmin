#!/usr/local/bin/perl
# create_form.cgi
# Display a form for creating a new mailing list

require './majordomo-lib.pl';
%access = &get_module_acl();
$access{'create'} || &error($text{'create_ecannot'});
&ui_print_header(undef, $text{'create_title'}, "");

print <<EOF;
<form action=create_list.cgi method=post>
<table border width=100%>
<tr $tb> <td><b>$text{'create_header'}</b></td> </tr>
<tr $cb> <td><table width=100%>

<tr> <td><b>$text{'create_name'}</b></td>
     <td><input name=name size=15></td> </tr>
<tr> <td><b>$text{'create_owner'}</b></td>
     <td><input name=owner size=30></td> </tr>
<tr> <td><b>$text{'create_password'}</b></td>
     <td><input name=password type=password size=10></td> </tr>
<tr> <td><b>$text{'create_desc'}</b></td>
     <td><input name=desc size=50></td> </tr>
<tr> <td valign=top><b>$text{'create_info'}</b></td>
     <td><textarea name=info rows=5 cols=60></textarea></td> </tr>
<tr> <td valign=top><b>$text{'create_footer'}</b></td>
     <td><textarea name=footer rows=3 cols=60></textarea></td> </tr>

<tr> <td><b>$text{'create_moderate'}</b></td>
     <td><input type=radio name=moderate value=yes> $text{'yes'}
         <input type=radio name=moderate value=no checked> $text{'no'}
     </td> </tr>
<tr> <td><b>$text{'create_moderator'}</b></td>
     <td><input type=radio name=moderator_def value=1 checked>
	 $text{'create_same'}
         <input type=radio name=moderator_def value=0>
         <input name=moderator size=20></td> </tr>

<tr> <td><b>$text{'create_archive'}</b></td>
     <td><select name=archive>
	 <option value='' selected>$text{'no'}</option>
	 <option value=Y>$text{'create_archiveyear'}</option>
	 <option value=M>$text{'create_archivemonth'}</option>
	 <option value=D>$text{'create_archiveday'}</option>
	 </select></td> </tr>

</table></td></tr></table>
<input type=submit value="$text{'create'}"></form>
EOF
&ui_print_footer("", $text{'index_return'});

