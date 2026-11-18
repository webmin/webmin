#!/usr/local/bin/perl
# save.cgi
# Save an edited file

require './custom-lib.pl';
&ReadParseMime();
$edit = &get_command($in{'id'}, $in{'idx'});
&error_setup($text{'view_err'});
$edit->{'edit'} && &can_run_command($edit) || &error($text{'edit_ecannot'});

($file, $homeuser) = &editor_file($edit);

# Set environment variables for parameters
($env, $export, $str, $displayfile) = &set_parameter_envs($edit, $file);
if ($edit->{'envs'} || @{$edit->{'args'}}) {
	# Expand variables without invoking a shell
	$file = &resolve_editor_file($file);
	}

# Run the before-command
if ($edit->{'before'}) {
	$out = &backquote_logged("($edit->{'before'}) 2>&1 </dev/null");
	&error(&text('view_ebefore', &html_escape($out))) if ($?);
	}

# Save the file
$in{'data'} =~ s/\r//g;
if (defined($homeuser)) {
	# Write the file in the user's home directory with his permissions
	&eval_as_unix_user($homeuser, \&save_editor_file);
	}
else {
	&save_editor_file();
	}

# Run the after-command
if ($edit->{'after'}) {
	$out = &backquote_logged("($edit->{'after'}) 2>&1 </dev/null");
	&error(&text('view_eafter', &html_escape($out))) if ($?);
	}

&webmin_log("save", "edit", $cmd->{'id'}, $edit);
&redirect("");

# save_editor_file()
# Writes the edited data, then applies the configured owner and permissions
# without invoking a shell
sub save_editor_file
{
&open_lock_tempfile(FILE, ">$file", 1) ||
	&error(&text('view_efile', &html_escape($file), &html_escape("$!")));
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);
&unlock_file($file);
if ($edit->{'user'}) {
	# Apply the configured owner and group
	&set_ownership_permissions($edit->{'user'}, $edit->{'group'},
				   undef, $file);
	}
if ($edit->{'perms'}) {
	# Apply the configured file permissions
	&set_ownership_permissions(undef, undef, oct($edit->{'perms'}), $file);
	}
}
