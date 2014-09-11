#!/usr/local/bin/perl
# Show an HTML editor window

$trust_unknown_referers = 1;
require './file-lib.pl';
do '../ui-lib.pl';
$disallowed_buttons{'edit'} && &error($text{'ebutton'});
&ReadParse();

# Work out editing mode
if ($in{'text'} || $in{'file'} && !&is_html_file($in{'file'})) {
	$text_mode = 1;
	}

if ($in{'file'} ne '' && !&can_access($in{'file'})) {
	# ACL rules prevent access to file
	&error(&text('view_eaccess', &html_escape($in{'file'})));
	}

&popup_header($in{'file'} ? $text{'html_title'} : $text{'html_title2'},
	      undef, $text_mode ? undef : "onload='xinha_init()'");

# Output HTMLarea init code
print <<EOF;
<script type="text/javascript">
  _editor_url = "$gconfig{'webprefix'}/$module_name/xinha/";
  _editor_lang = "en";
</script>
<script type="text/javascript" src="xinha/XinhaCore.js"></script>

<script type="text/javascript">
xinha_init = function()
{
xinha_editors = [ "body" ];
xinha_plugins = [ ];
xinha_config = new Xinha.Config();
xinha_editors = Xinha.makeEditors(xinha_editors, xinha_config, xinha_plugins);
Xinha.startEditors(xinha_editors);
}
</script>
EOF

# Read the file
&switch_acl_uid_and_chroot();
$data = &read_file_contents($in{'file'});

# Output text area
print &ui_form_start("save_html.cgi", "form-data");
print &ui_hidden("text", $text_mode);
if ($in{'file'}) {
	# Editing existing file
	print &ui_hidden("file", $in{'file'});
	$pc = 95;
	}
else {
	# Creating new, so prompt for path
	print $text{'edit_filename'}," ",
	      &ui_textbox("file", $in{'dir'}, 70),"<br>\n";
	$pc = 90;
	}
if ($text_mode) {
	# Show plain textarea
	print "<textarea rows=20 cols=80 style='width:100%;height:$pc%' name=body>";
	print &html_escape($data);
	print "</textarea>\n";
	print &ui_submit($text{'html_save'});
	}
else {
	# Show HTML editor
	print "<textarea rows=20 cols=80 style='width:100%;height:$pc%' name=body id=body>";
	print &html_escape($data);
	print "</textarea>\n";
	print "<table width=100%><tr>\n";
	print "<td>",&ui_submit($text{'html_save'}),"</td>\n";
	print "<td align=right><a href='edit_html.cgi?file=".
	     &urlize($in{'file'})."&text=1'>$text{'edit_textmode'}</a></td>\n";
	print "</tr> </table>\n";
	}
print &ui_form_end();

&popup_footer();

sub is_html_file
{
local ($file) = @_;
local @exts = split(/\s+/, $userconfig{'htmlexts'} || $config{'htmlexts'});
@exts = ( ".htm", ".html", ".shtml" ) if (!@exts);
foreach my $e (@exts) {
	return 1 if ($file =~ /\Q$e\E$/i);
	}
return 0;
}
