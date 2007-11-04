
sub theme_icons_table
{
local ($i, $need_tr);
local $cols = $_[3] ? $_[3] : 4;
local $per = int(100.0 / $cols);
print "<table class='main' width=100% cellpadding=5>\n";
for($i=0; $i<@{$_[0]}; $i++) {
	if ($i%$cols == 0) { print "<tr>\n"; }
	print "<td width=$per% align=center valign=top>\n";
	&generate_icon($_[2]->[$i], $_[1]->[$i], $_[0]->[$i],
		       $_[4], $_[5], $_[6], $_[7]->[$i], $_[8]->[$i]);
	print "</td>\n";
        if ($i%$cols == $cols-1) { print "</tr>\n"; }
        }
while($i++%$cols) { print "<td width=$per%></td>\n"; $need_tr++; }
print "</tr>\n" if ($need_tr);
print "</table>\n";
}

sub theme_generate_icon
{
local $w = !defined($_[4]) ? "width=48" : $_[4] ? "width=$_[4]" : "";
local $h = !defined($_[5]) ? "height=48" : $_[5] ? "height=$_[5]" : "";
if ($tconfig{'noicons'}) {
	if ($_[2]) {
		print "$_[6]<a href=\"$_[2]\" $_[3]>$_[1]</a>$_[7]\n";
		}
	else {
		print "$_[6]$_[1]$_[7]\n";
		}
	}
elsif ($_[2]) {
	print "<table><tr><td width=48 height=48>\n",
	      "<a href=\"$_[2]\" $_[3]><img src=\"$_[0]\" alt=\"\" border=0 ",
	      "$w $h></a></td></tr></table>\n";
	print "$_[6]<a href=\"$_[2]\" $_[3]>$_[1]</a>$_[7]\n";
	}
else {
	print "<table><tr><td width=48 height=48>\n",
	      "<img src=\"$_[0]\" alt=\"\" border=0 $w $h>",
	      "</td></tr></table>\n$_[6]$_[1]$_[7]\n";
	}
}

sub theme_post_save_domain
{
print "<script>\n";
print "top.left.location = top.left.location;\n";
print "</script>\n";
}

sub theme_prebody
{
if ($script_name =~ /session_login.cgi/) {
	# Generate CSS link
	print "<link rel='stylesheet' type='text/css' href='$gconfig{'webprefix'}/unauthenticated/style.css'>\n";
	}
}

sub theme_postbody
{
# If we just came from a folder editing page, refresh the folder list
if ($module_name eq "mailbox" && $ENV{'HTTP_REFERER'} =~ /(edit|save)_(folder|comp|imap|pop3|virt)\.cgi|mail_search\.cgi|delete_folders\.cgi/) {
	print "refreshing!<p>\n";
        print "<script>\n";
        print "top.frames[0].document.location = top.frames[0].document.location;\n";
        print "</script>\n";
        }
}

sub theme_prehead
{
print "<link rel='stylesheet' type='text/css' href='$gconfig{'webprefix'}/unauthenticated/style.css' />\n";
print "<script>\n";
print "var rowsel = new Array();\n";
print "</script>\n";
}

# theme_ui_columns_start(&headings, [width-percent], [noborder], [&tdtags], [heading])
# Returns HTML for a multi-column table, with the given headings
sub theme_ui_columns_start
{
local ($heads, $width, $noborder, $tdtags, $heading) = @_;
local ($href) = grep { $_ =~ /<a\s+href/i } @$heads;
local $rv;
$theme_ui_columns_row_toggle = 0;
$rv .= "<table".($noborder ? "" : " class='ui_table'").
		(defined($width) ? " width=$width%" : "").
		($href ? "" : " class='sortable'").">\n";
if ($heading) {
	$rv .= "<thead> <tr $tb><td colspan=".scalar(@$heads).
			"><b>$heading</b></td></tr> </thead> <tbody>\n";
	}
$rv .= "<thead> <tr $tb>\n";
local $i;
for($i=0; $i<@$heads; $i++) {
	$rv .= "<td ".$tdtags->[$i]."><b>".
			($heads->[$i] eq "" ? "<br>" : $heads->[$i])."</b></td>\n";
	}
$rv .= "</tr></thead> <tbody>\n";
$theme_ui_columns_count++;
return $rv;
}

# theme_ui_columns_row(&columns, &tdtags)
# Returns HTML for a row in a multi-column table
sub theme_ui_columns_row
{
$theme_ui_columns_row_toggle = $theme_ui_columns_row_toggle ? '0' : '1';
local ($cols, $tdtags) = @_;
local $rv;
$rv .= "<tr class='ui_columns row$theme_ui_columns_row_toggle' onMouseOver=\"this.className='mainhigh'\" onMouseOut=\"this.className='mainbody row$theme_ui_columns_row_toggle'\">\n";
local $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i].">".
			($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i])."</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

# theme_ui_columns_end()
# Returns HTML to end a table started by ui_columns_start
sub theme_ui_columns_end
{
return "</tbody> </table>\n";
}

# theme_select_all_link(field, form, text)
# Adds support for row highlighting to the normal select all
sub theme_select_all_link
{
local ($field, $form, $text) = @_;
$form = int($form);
$text ||= $text{'ui_selall'};
return "<a href='#' onClick='f = document.forms[$form]; ff = f.$field; ff.checked = true; r = document.getElementById(\"row_\"+ff.id); if (r) { r.className = \"mainsel\" }; for(i=0; i<f.$field.length; i++) { ff = f.${field}[i]; ff.checked = true; r = document.getElementById(\"row_\"+ff.id); if (r) { r.className = \"mainsel\" } } return false'>$text</a>";
}

# theme_select_invert_link(field, form, text)
# Adds support for row highlighting to the normal invert selection
sub theme_select_invert_link
{
local ($field, $form, $text) = @_;
$form = int($form);
$text ||= $text{'ui_selinv'};
return "<a href='#' onClick='f = document.forms[$form]; ff = f.$field; ff.checked = !f.$field.checked; r = document.getElementById(\"row_\"+ff.id); if (r) { r.className = ff.checked ? \"mainsel\" : \"mainbody\" }; for(i=0; i<f.$field.length; i++) { ff = f.${field}[i]; ff.checked = !ff.checked; r = document.getElementById(\"row_\"+ff.id); if (r) { r.className = ff.checked ? \"mainsel\" : \"mainbody row\"+((i+1)%2) } } return false'>$text</a>";
}

# theme_select_status_link(name, form, &folder, &mails, start, end, status, label)
# Adds support for row highlighting to read mail module selector
sub theme_select_status_link
{
local ($name, $formno, $folder, $mail, $start, $end, $status, $label) = @_;
$formno = int($formno);
local @sel;
for(my $i=$start; $i<=$end; $i++) {
	local $m = $mail->[$i];
	push(@sel, &get_mail_read($folder, $m) == $status ? 1 : 0);
	}
local $js = "var sel = [ ".join(",", @sel)." ]; ";
$js .= "var f = document.forms[$formno]; ";
$js .= "for(var i=0; i<sel.length; i++) { document.forms[$formno].${name}[i].checked = sel[i]; var ff = f.${name}[i]; var r = document.getElementById(\"row_\"+ff.id); if (r) { r.className = ff.checked ? \"mainsel\" : \"mainbody row\"+((i+2)%2) } }";
$js .= "return false;";
return "<a href='#' onClick='$js'>$label</a>";
}

sub theme_ui_checked_columns_row
{
$theme_ui_columns_row_toggle = $theme_ui_columns_row_toggle ? '0' : '1';
local ($cols, $tdtags, $checkname, $checkvalue, $checked) = @_;
local $rv;
local $cbid = &quote_escape(quotemeta("${checkname}_${checkvalue}"));
local $rid = &quote_escape(quotemeta("row_${checkname}_${checkvalue}"));
local $ridtr = &quote_escape("row_${checkname}_${checkvalue}");
local $mycb = $cb;
if ($checked) {
	$mycb =~ s/mainbody/mainsel/g;
	}
$mycb =~ s/class='/class='row$theme_ui_columns_row_toggle /;
$rv .= "<tr id=\"$ridtr\" $mycb onMouseOver=\"this.className = document.getElementById('$cbid').checked ? 'mainhighsel' : 'mainhigh'\" onMouseOut=\"this.className = document.getElementById('$cbid').checked ? 'mainsel' : 'mainbody row$theme_ui_columns_row_toggle'\">\n";
$rv .= "<td ".$tdtags->[0].">".
		&ui_checkbox($checkname, $checkvalue, undef, $checked, "onClick=\"document.getElementById('$rid').className = this.checked ? 'mainhighsel' : 'mainhigh';\"").
		"</td>\n";
local $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i+1].">";
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		$rv .= "<label for=\"".
				&quote_escape("${checkname}_${checkvalue}")."\">";
		}
	$rv .= ($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i]);
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		$rv .= "</label>";
		}
	$rv .= "</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

sub theme_ui_radio_columns_row
{
local ($cols, $tdtags, $checkname, $checkvalue, $checked) = @_;
local $rv;
local $cbid = &quote_escape(quotemeta("${checkname}_${checkvalue}"));
local $rid = &quote_escape(quotemeta("row_${checkname}_${checkvalue}"));
local $ridtr = &quote_escape("row_${checkname}_${checkvalue}");
local $mycb = $cb;
if ($checked) {
  $mycb =~ s/mainbody/mainsel/g;
  }

$rv .= "<tr $mycb id=\"$ridtr\" onMouseOver=\"this.className = document.getElementById('$cbid').checked ? 'mainhighsel' : 'mainhigh'\" onMouseOut=\"this.className = document.getElementById('$cbid').checked ? 'mainsel' : 'mainbody'\">\n";
$rv .= "<td ".$tdtags->[0].">".
       &ui_oneradio($checkname, $checkvalue, undef, $checked, "onClick=\"for(i=0; i<form.$checkname.length; i++) { ff = form.${checkname}[i]; r = document.getElementById('row_'+ff.id); if (r) { r.className = 'mainbody' } } document.getElementById('$rid').className = this.checked ? 'mainhighsel' : 'mainhigh';\"").
       "</td>\n";
local $i;
for($i=0; $i<@$cols; $i++) {
  $rv .= "<td ".$tdtags->[$i+1].">";
  if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
    $rv .= "<label for=\"".
      &quote_escape("${checkname}_${checkvalue}")."\">";
    }
  $rv .= ($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i]);
  if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
    $rv .= "</label>";
    }
  $rv .= "</td>\n";
  }
$rv .= "</tr>\n";
return $rv;
}

# ui_hidden_table_start(heading, [tabletags], [cols], name, status,
#     [&default-tds])
# A table with a heading and table inside, and which is collapsible
sub theme_ui_hidden_table_start
{
local ($heading, $tabletags, $cols, $name, $status, $tds) = @_;
local $rv;
if (!$main::ui_hidden_start_donejs++) {
  $rv .= &ui_hidden_javascript(); 
  }
local $divid = "hiddendiv_$name";
local $openerid = "hiddenopener_$name";
local $defimg = $status ? "open.gif" : "closed.gif";
local $defclass = $status ? 'opener_shown' : 'opener_hidden';
local $text = defined($tconfig{'cs_text'}) ? $tconfig{'cs_text'} :
        defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
$rv .= "<table border class='formsection' $tabletags>\n";
$rv .= "<tr $tb> <td><a href=\"javascript:hidden_opener('$divid', '$openerid')\" id='$openerid'><img border=0 src='$gconfig{'webprefix'}/images/$defimg'></a> <a href=\"javascript:hidden_opener('$divid', '$openerid')\"><b><font color=#$text>$heading</font></b></a></td> </tr>\n" if (defined($heading));
$rv .= "<tr $cb> <td><div class='$defclass' id='$divid'><table width=100%>\n";
$main::ui_table_cols = $cols || 4;
$main::ui_table_pos = 0;
$main::ui_table_default_tds = $tds;
return $rv;
}

# theme_ui_columns_start(&headings, [width-percent], [noborder], [&tdtags], [heading])
# Returns HTML for a multi-column table, with the given headings
sub theme_ui_columns_start
{
local ($heads, $width, $noborder, $tdtags, $heading) = @_;
local ($href) = grep { $_ =~ /<a\s+href/i } @$heads;
local $rv;
$rv .= "<table".($noborder ? "" : " border").
    (defined($width) ? " width=$width%" : "").
    ($href ? "" : " class='sortable'").">\n";
if ($heading) {
  $rv .= "<thead> <tr $tb><td colspan=".scalar(@$heads).
         "><b>$heading</b></td></tr> </thead> <tbody>\n";
  }
$rv .= "<thead> <tr $tb>\n";
local $i;
for($i=0; $i<@$heads; $i++) {
  $rv .= "<td ".$tdtags->[$i]."><b>".
         ($heads->[$i] eq "" ? "<br>" : $heads->[$i])."</b></td>\n";
  }
$rv .= "</tr></thead> <tbody>\n";
$theme_ui_columns_count++;
return $rv;
}

