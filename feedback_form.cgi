#!/usr/local/bin/perl
# feedback_form.cgi
# Display a form so that the user can send in a webmin bug report

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
if (&get_product_name() eq 'usermin') {
	&switch_to_remote_user();
	}
&ReadParse();
&error_setup($text{'feedback_err'});
%access = &get_module_acl();
$access{'feedback'} || &error($text{'feedback_ecannot'});
&ui_print_header(undef, $text{'feedback_title'}, "", undef, 0, 1);

%minfo = &get_module_info($in{'module'}) if ($in{'module'});
$fb = $gconfig{'feedback_to'} ||
      $minfo{'feedback'} ||
      $webmin_feedback_address;
print &text('feedback_desc', "<tt>$fb</tt>"),"<p>\n";
print "<b>$text{'feedback_desc2'}</b><p>\n" if (!$gconfig{'feedback_to'});

print "<form action=feedback.cgi method=post enctype=multipart/form-data>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'feedback_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'feedback_name'}</b></td>\n";
print "<td><input name=name size=25 value='$gconfig{'feedback_name'}'></td>\n";

print "<td><b>$text{'feedback_email'}</b></td>\n";
print "<td><input name=email size=25 value='$gconfig{'feedback_email'}'></td> </tr>\n";

print "<tr> <td><b>$text{'feedback_module'}</b></td>\n";
print "<td><select name=module>\n";
printf "<option value='' %s>%s</option>\n",
	$in{'module'} ? "" : "selected", $text{'feedback_all'};
@modules = ( );
foreach $minfo (&get_all_module_infos()) {
	if (&check_os_support($minfo) &&
	    ($minfo->{'longdesc'} || $minfo->{'feedback'})) {
		push(@modules, $minfo);
		}
	}
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} } @modules) {
	printf "<option %s value=%s>%s</option>\n",
		$in{'module'} eq $m->{'dir'} ? "selected" : "",
		$m->{'dir'}, $m->{'desc'};
	}
print "</select></td>\n";

print "<td><b>$text{'feedback_mailserver'}</b></td>\n";
printf "<td><input type=radio name=mailserver_def value=1 %s> %s\n",
	$gconfig{'feedback_mailserver'} ? "" : "checked",
	$text{'feedback_mailserver_def'};
printf "<input type=radio name=mailserver_def value=0 %s>\n",
	$gconfig{'feedback_mailserver'} ? "checked" : "";
printf "<input name=mailserver size=15 value='%s'></td> </tr>\n",
	$gconfig{'feedback_mailserver'};

if (!$gconfig{'nofeedbackcc'}) {
	print "<tr> <td valign=top><b>$text{'feedback_to'}</b></td>\n";
	print "<td colspan=3><textarea name=to rows=4 cols=50>",
		$fb,"</textarea></td> </tr>\n";
	}

print "<tr> <td valign=top><b>$text{'feedback_text'}</b></td>\n";
print "<td colspan=3><textarea name=text rows=6 cols=70 wrap=on>",
      "</textarea></td> </tr>\n";

print "<tr> <td colspan=2 nowrap><b>$text{'feedback_os'}</b>&nbsp;&nbsp;\n";
printf "<input type=radio name=os value=1> $text{'yes'}\n";
printf "<input type=radio name=os value=0 checked> $text{'no'}</td>\n";
print "<td colspan=2>($text{'feedback_osdesc'})</td> </tr>\n";

if (!$gconfig{'nofeedbackconfig'}) {
	print "<tr> <td colspan=2 nowrap><b>$text{'feedback_config'}</b>&nbsp;&nbsp;\n";
	printf "<input type=radio name=config value=1> $text{'yes'}\n";
	printf "<input type=radio name=config value=0 checked> $text{'no'}</td>\n";
	print "<td colspan=2>($text{'feedback_configdesc'})</td> </tr>\n";
	}

print "<tr> <td><b>$text{'feedback_attach'}</b></td>\n";
print "<td><input type=file name=attach0></td>",
      "<td colspan=2><input type=file name=attach1></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'feedback_send'}'></form>\n";

&ui_print_footer("/", $text{'index'});

