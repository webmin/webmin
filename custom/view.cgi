#!/usr/local/bin/perl
# view.cgi
# Display a file for editing

require './custom-lib.pl';
&ReadParse();
$edit = &get_command($in{'id'}, $in{'idx'});
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
$displayfile = &html_escape($displayfile);

if ($edit->{'envs'} || @{$edit->{'args'}}) {
	# Do environment variable substitution
	chop($file = `echo "$file"`);
	}

# Run any before-edit command
if ($edit->{'beforeedit'}) {
	$out = &backquote_logged("($edit->{'beforeedit'}) 2>&1 </dev/null");
	&error(&text('view_ebeforeedit', &html_escape($out))) if ($?);
	}

# Show the editor form
&ui_print_header(undef, $text{'view_title'}, "");

$w = $config{'width'} || 80;
$h = $config{'height'} || 20;
print &ui_form_start("save.cgi", "form-data");
print &ui_table_start(&text('view_header', "<tt>$displayfile</tt>"), undef, 2);
foreach my $i (keys %in) {
	print &ui_hidden($i, $in{$i}),"\n";
	}
$data = &read_file_contents($file);
print &ui_table_row(undef, &ui_textarea("data", $data, $h, $w, $config{'wrap'}),
		    2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

