#!/usr/local/bin/perl
# Show an HTML editor window

require './file-lib.pl';
do '../ui-lib.pl';
$disallowed_buttons{'edit'} && &error($text{'ebutton'});
&ReadParse();
&popup_header($in{'file'} ? $text{'html_title'} : $text{'html_title2'},
	      undef, "onload='initEditor()'");

# Output HTMLarea init code
print <<EOF;
<script type="text/javascript">
  _editor_url = "$gconfig{'webprefix'}/$module_name/xinha/";
  _editor_lang = "en";
</script>
<script type="text/javascript" src="xinha/htmlarea.js"></script>

<script type="text/javascript">
var editor = null;
function initEditor() {
  editor = new HTMLArea("body");
  editor.generate();
  return false;
}
</script>
EOF

# Read the file
&switch_acl_uid_and_chroot();
$data = &read_file_contents($in{'file'});

# Output text area
print &ui_form_start("save_html.cgi", "form-data");
if ($in{'file'}) {
	# Editing existing file
	print &ui_hidden("file", $in{'file'}),"\n";
	$pc = 95;
	}
else {
	# Creating new, so prompt for path
	print $text{'edit_filename'}," ",
	      &ui_textbox("file", $in{'dir'}, 70),"<br>\n";
	$pc = 90;
	}
print "<textarea rows=20 cols=80 style='width:100%;height:$pc%' name=body id=body>";
print &html_escape($data);
print "</textarea>\n";
print &ui_submit($text{'html_save'});
print &ui_form_end();

&popup_footer();


