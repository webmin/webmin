#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
# A form for SMTP server parameters.
# modified by Roberto Tecchio, 2005 (www.tecchio.net)
#
# << Here are all options seen in Postfix sample-smtpd.cf >>

require './postfix-lib.pl';

$access{'smtpd'} || &error($text{'smtpd_ecannot'});
&ui_print_header(undef, $text{'smtpd_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'smtpd_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_banner", 85, $default);
print "</tr>\n";


print "<tr>\n";
&option_freefield("smtpd_recipient_limit", 15);
&option_yesno("disable_vrfy_command", 'help');
print "</tr>\n";

print "<tr>\n";
&option_freefield("smtpd_timeout", 15);
&option_freefield("smtpd_error_sleep_time", 15);
print "</tr>\n";

print "<tr>\n";
&option_freefield("smtpd_soft_error_limit", 15);
&option_freefield("smtpd_hard_error_limit", 15);
print "</tr>\n";

print "<tr>\n";
&option_yesno("smtpd_helo_required", 'help');
&option_yesno("allow_untrusted_routing", 'help');
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_etrn_restrictions", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_helo_restrictions", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_sender_restrictions", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("smtpd_recipient_restrictions", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_radios_freefield("relay_domains", 65, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("access_map_reject_code", 15, $default);
&option_freefield("invalid_hostname_reject_code", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("maps_rbl_reject_code", 15, $default);
&option_freefield("reject_code", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("relay_domains_reject_code", 15, $default);
&option_freefield("unknown_address_reject_code", 15, $default);
print "</tr>\n";

print "<tr>\n";
&option_freefield("unknown_client_reject_code", 15, $default);
&option_freefield("unknown_hostname_reject_code", 15, $default);
print "</tr>\n";

## the form must be divided to avoid sending unexpected fields
print "
    <input type=hidden name=smtpd_client_restrictions_def>
    <input type=hidden name=smtpd_client_restrictions>
    </form>
    <form>
    ";

print "<tr>\n";
## &ui_opt_textarea("check_sender_access", $check_sender_access, undef, 40, $none, 1);
## modified to use the customized ui_opt_textarea
&ui_opt_textarea("smtpd_client_restrictions:check_sender_access", undef, 40, $none, 1);
print "</tr>\n";

print "<tr>\n";
## &ui_opt_textarea("maps_rbl_domains", join(', ',@rbl_domains), 3, 62, $none);
## modified to use the customized ui_opt_textarea
&ui_opt_textarea("smtpd_client_restrictions:reject_rbl_client", 3, 62, $none);
print "</tr>\n";

print "</table></td></tr></table><p>\n";

## code added for javascript-managed fields
print <<JS;

<SCRIPT>
function check_js_fields()
{
f0=document.forms[0];
f1=document.forms[1];
check_value="";    
if (f1.reject_rbl_client_def[1].checked && f1.reject_rbl_client.value != "")
    {
    aRbls=f1.reject_rbl_client.value.split(',');
    for (var i in aRbls) check_value+="reject_rbl_client "+aRbls[i].replace(/ /g,'')+", "; 
    }
if (f1.check_sender_access_def[1].checked && f1.check_sender_access.value != "") 
    {
    n=f1.check_sender_access.value.indexOf(':');
    if (n>-1) f1.check_sender_access.value=f1.check_sender_access.value.substr(n+1);
    check_value = "check_sender_access hash:" + f1.check_sender_access.value + 
        ", "+check_value;
    }        
if (check_value) 
    {
    check_value="permit_mynetworks, "+check_value+"permit";
    f0.smtpd_client_restrictions_def.value="__USE_FREE_FIELD__";
    f0.smtpd_client_restrictions.value=check_value;
    }
f0.submit();    
}   
</SCRIPT>    
JS
## end of added javascript code

## print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
## changed to allow submitting of forms[0]
print "<input type=button onClick=check_js_fields() value=\"$text{'opts_save'}\"></form>\n";
&ui_print_footer("", $text{'index_return'});
   
## a customized version of ui_opt_textbox
sub ui_opt_textarea
{
return &theme_ui_opt_textbox(@_) if (defined(&theme_ui_opt_textbox));

my ($name, $rows, $cols, $opt1, $btnedit) = @_;
my $value=&get_current_value($name);
my ($mainparm,$name)=split /:/, $name;

my $dis1 = &js_disable_inputs([ $name], [ ]);
my $dis2 = &js_disable_inputs([ ], [ $name ]);
my $key = 'opts_'.$name;

print "<td valign=top>".&hlink("<b>$text{$key}</b>", "opt_".$name)."</td>
    <td valign=top nowrap colspan=3>";
    
print "<table border=0 cellpadding=0 cellspacing=0><tr><td valign=top nowrap>"
    unless $btnedit;

print "<input type=radio name=\"".&quote_escape($name."_def")."\" ".
       "value=1 ".($value ne '' ? "" : "checked"). " onClick='$dis1'> ".$opt1."\n";
print "<input type=radio name=\"".&quote_escape($name."_def")."\" ".
       "value=0 ".($value ne '' ? "checked" : ""). " onClick='$dis2'> ".$opt2."\n";

if ($btnedit) 
    {
    print "<input name=\"".&quote_escape($name)."\" size=$cols".
       ($value eq "" ? " disabled=true" : "")." value=\"".
       &quote_escape($value)."\">\n";
    print &file_chooser_button(&quote_escape($name),0,0);
    print "<input type=button value=\"". $text{edit_map_file}. 
        "\" onClick=\"location.href='edit_access.cgi?name=", &quote_escape("$mainparm:$name"),
        "&title=", $text{$key}, "'\">" if $value;
    }
else
    {    
    print "</td><td>\n<textarea name=\"".&quote_escape($name)."\" cols=$cols rows=$rows".
       ($value eq ""? " disabled=true" : "").">".
       &quote_escape($value)."</textarea></td></tr></table>\n";
    }
print "</td>";
}
