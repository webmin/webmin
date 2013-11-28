#!/usr/local/bin/perl
# digest_form.cgi
# Display a form for creating a new disgest list

require './majordomo-lib.pl';
%access = &get_module_acl();
$access{'create'} || &error($text{'cdigest_ecannot'});
&ui_print_header(undef, $text{'cdigest_title'}, "");

$lists = "<select name=list>\n";
foreach $l (&list_lists(&get_config())) {
	$lists .= "<option>$l</option>\n";
	}
$lists .= "</select>\n";

$old = &text('cdigest_old', "<input name=days size=3>");
$lines = &text('cdigest_lines', "<input name=lines size=5>");

print <<EOF;
<form action=create_digest.cgi method=post>
<table border width=100%>
<tr $tb> <td><b>$text{'cdigest_header'}</b></td> </tr>
<tr $cb> <td><table width=100%>

<tr> <td><b>$text{'cdigest_name'}</b></td>
     <td><input name=name size=15></td> </tr>
<tr> <td><b>$text{'cdigest_list'}</b></td> <td>$lists</td> </tr>
<tr> <td><b>$text{'cdigest_owner'}</b></td>
     <td><input name=owner size=30></td> </tr>
<tr> <td><b>$text{'cdigest_password'}</b></td>
     <td><input name=password type=password size=10></td> </tr>
<tr> <td><b>$text{'cdigest_desc'}</b></td>
     <td><input name=desc size=50></td> </tr>
<tr> <td valign=top><b>$text{'cdigest_info'}</b></td>
     <td><textarea name=info rows=5 cols=60></textarea></td> </tr>
<tr> <td valign=top><b>$text{'cdigest_footer'}</b></td>
     <td><textarea name=footer rows=3 cols=60></textarea></td> </tr>
<tr> <td valign=top><b>$text{'cdigest_when'}</b></td>
     <td><input type=radio name=mode value=0 checked> $old<br>
	 <input type=radio name=mode value=1> $lines</td> </tr>

</table></td></tr></table>
<input type=submit value="$text{'create'}"></form>
EOF
&ui_print_footer("", $text{'index_return'});

