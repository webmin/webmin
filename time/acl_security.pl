
require 'time-lib.pl';

sub acl_security_form
{
    print(
	"<tr>",
	    "<td><b>", $text{ 'acl_sys' }, "</b></td>",
	    "<td><input type=radio name=sysdate value=0 ", $_[0] -> { 'sysdate' } == 0 ? "checked" : "", ">", $text{ 'acl_yes' }, " <input type=radio name=sysdate value=1 ", $_[0] -> { 'sysdate' } == 1 ? "checked" : "", ">", $text{ 'acl_no' },
	"</tr><tr>",
	    "<td><b>", $text{ 'acl_hw' }, "</b></td>",
	    "<td><input type=radio name=hwdate value=0 ", $_[0] -> { 'hwdate' } == 0 ? "checked" : "", ">", $text{ 'acl_yes' }, " <input type=radio name=hwdate value=1 ", $_[0] -> { 'hwdate' } == 1 ? "checked" : "", ">", $text{ 'acl_no' },
	"</tr><tr>",
	    "<td><b>", $text{ 'acl_timezone' }, "</b></td>",
	    "<td><input type=radio name=timezone value=1 ", $_[0] -> { 'timezone' } == 1 ? "checked" : "", ">", $text{ 'acl_yes' }, " <input type=radio name=timezone value=0 ", $_[0] -> { 'timezone' } == 0 ? "checked" : "", ">", $text{ 'acl_no' },
	"</tr><tr>",
	    "<td><b>", $text{ 'acl_ntp' }, "</b></td>",
	    "<td><input type=radio name=ntp value=1 ", $_[0] -> { 'ntp' } == 1 ? "checked" : "", ">", $text{ 'acl_yes' }, " <input type=radio name=ntp value=0 ", $_[0] -> { 'ntp' } == 0 ? "checked" : "", ">", $text{ 'acl_no' },
	"</tr>\n");
}

sub acl_security_save
{
    $_[0] -> { 'sysdate' } = $in{ 'sysdate' };
    $_[0] -> { 'hwdate' } = $in{ 'hwdate' };
    $_[0] -> { 'timezone' } = $in{ 'timezone' };
    $_[0] -> { 'ntp' } = $in{ 'ntp' };
}
