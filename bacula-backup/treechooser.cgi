#!/usr/local/bin/perl
# treechooser.cgi
# Outputs HTML for a java file-chooser tree

require './bacula-backup-lib.pl';
&PrintHeader();
&ReadParse();

$shortest = "/";
if ($main::session_id) {
	$session = "<param name=session value=\"sid=$main::session_id\">";
	}

$in{'job'} =~ s/^(.*)_(\d+)$/$2/g;
print <<EOF;
<html><head><title>$text{'tree_title'}</title><body>

<script>
function clear_files()
{
top.ifield.value = "";
}

function add_file(file)
{
top.ifield.value = top.ifield.value + file + "\\n";
}

function finished()
{
window.close();
}
</script>

<applet code=TreeChooser name=TreeChooser width=100% height=100% MAYSCRIPT>
<param name=volume value="$in{'volume'}">
<param name=root value="$shortest">
<param name=job value="$in{'job'}">
$session
</applet>
</body></html>
EOF

