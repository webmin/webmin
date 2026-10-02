#!/usr/local/bin/perl
# save.cgi
# Save an edited file

require './custom-lib.pl';
&ReadParseMime();
$edit = &get_command($in{'id'}, $in{'idx'});
&error_setup($text{'view_err'});
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
&open_lock_tempfile(FILE, ">$file", 1) ||
	&error(&text('view_efile', $file, $!));
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);

# Set file ownership and permissions without invoking a shell
if ($edit->{'user'}) {
	# Apply the configured owner and group
	&set_ownership_permissions($edit->{'user'}, $edit->{'group'},
				   undef, $file);
	}
if ($edit->{'perms'}) {
	# Apply the configured file permissions
	&set_ownership_permissions(undef, undef, oct($edit->{'perms'}), $file);
	}

# Run the after-command
if ($edit->{'after'}) {
	$out = &backquote_logged("($edit->{'after'}) 2>&1 </dev/null");
	&error(&text('view_eafter', &html_escape($out))) if ($?);
	}

&webmin_log("save", "edit", $cmd->{'id'}, $edit);
&redirect("");

