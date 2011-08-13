#!/usr/local/bin/perl
# save_file.cgi
# Save, create or delete a file editor

require './custom-lib.pl';
&ReadParse();

$access{'edit'} || &error($text{'file_ecannot'});
if ($in{'delete'}) {
	$edit = &get_command($in{'id'}, $in{'idx'});
	&delete_command($edit);
	&webmin_log("delete", "edit", $edit->{'id'}, $edit);
	&redirect("");
	}
elsif ($in{'clone'}) {
	&redirect("edit_file.cgi?id=$in{'id'}&idx=$in{'idx'}&clone=1&new=1");
	}
else {
	&error_setup($text{'file_err'});
	if (!$in{'new'}) {
		$edit = &get_command($in{'id'}, $in{'idx'});
		}
	else {
		$edit = { 'id' => time() };
		}

	# parse and validate inputs
	$in{'edit'} =~ /\S/ || &error($text{'file_eedit'});
	$edit->{'edit'} = $in{'edit'};
	$in{'desc'} =~ /\S/ || &error($text{'file_edesc'});
	$edit->{'desc'} = $in{'desc'};
	$in{'html'} =~ s/\r//g;
	$in{'html'} =~ s/\n*/\n/;
	$cmd->{'html'} = $in{'html'};
	if ($in{'owner_def'}) {
		$edit->{'user'} = $edit->{'group'} = undef;
		}
	else {
		(@u = getpwnam($in{'user'})) || &error($text{'file_euser'});
		(@g = getgrnam($in{'group'})) || &error($text{'file_egroup'});
		$edit->{'user'} = $in{'user'};
		$edit->{'group'} = $in{'group'};
		}
	if ($in{'perms_def'}) {
		$edit->{'perms'} = undef;
		}
	else {
		$in{'perms'} =~ /^[0-7]{3}$/ || &error($text{'file_eperms'});
		$edit->{'perms'} = $in{'perms'};
		}
	$edit->{'beforeedit'} = $in{'beforeedit'};
	$edit->{'before'} = $in{'before'};
	$edit->{'after'} = $in{'after'};
	$edit->{'order'} = $in{'order_def'} ? 0 : int($in{'order'});
	$edit->{'usermin'} = $in{'usermin'};
	$edit->{'envs'} = $in{'envs'};
	&parse_params_inputs($edit);
	&save_command($edit);
	&webmin_log($in{'new'} ? "create" : "modify", "edit",
		    $cmd->{'id'}, $cmd);

	if ($in{'new'} && $access{'cmds'} ne '*') {
		$access{'cmds'} .= " ".$edit->{'id'};
		&save_module_acl(\%access);
		}
	&redirect("");
	}

