#!/usr/local/bin/perl
# view.cgi
# Display a file for editing

require './custom-lib.pl';
&ReadParse();
@cmds = &list_commands();
$edit = $cmds[$in{'idx'}];
$edit->{'edit'} && &can_run_command($edit) || &error($text{'edit_ecannot'});

# Work out proper filename
$file = $edit->{'edit'};
if ($file !~ /^\//) {
	# File is relative to user's home directory
	@uinfo = getpwnam($remote_user);
	$file = "$uinfo[7]/$file" if (@uinfo);
	}

# Set environment variables for parameters
($env, $export, $str, $displayfile) = &set_parameter_envs($edit, $file);

if ($edit->{'envs'} || @{$edit->{'args'}}) {
	# Do environment variable substitution
	chop($file = `echo "$file"`);
	}

# Show the editor window
&ui_print_header($displayfile, $text{'view_title'}, "");

$w = $config{'width'} || 80;
$h = $config{'height'} || 20;
$wrap = $config{'wrap'} ? "wrap=$config{'wrap'}" : "";
print "<form action=save.cgi method=post enctype=multipart/form-data>\n";
foreach my $i (keys %in) {
	print &ui_hidden($i, $in{$i}),"\n";
	}
print "<textarea rows=$h cols=$w $wrap name=data>";

open(FILE, $file);
while(<FILE>) { print &html_escape($_); }
close(FILE);
print "</textarea><br>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

