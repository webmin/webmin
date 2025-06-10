#!/usr/local/bin/perl
# Create, update or delete a BSD RC script

require './init-lib.pl';
&ReadParse();
$access{'bootup'} || &error($text{'edit_ecannot'});
&foreign_require("proc", "proc-lib.pl");

@rcs = &list_rc_scripts();
if (!$in{'new'}) {
	($rc) = grep { $_->{'name'} eq $in{'name'} } @rcs;
	$rc || &error($text{'edit_egone'});
	}

if ($in{'delete'}) {
	# Delete the action script
	&delete_rc_script($in{'name'});
	&webmin_log("delete", "action", $in{'name'});
	&redirect("");
	}
elsif ($in{'start'} || $in{'stop'} || $in{'status'}) {
	# Run now
	$mode = $in{'start'} ? "start" :
		$in{'stop'} ? "stop" : "status";
	&ui_print_header(undef, $text{'ss_'.$mode}, "");
	print &text('ss_doing'.$mode, "<tt>$in{'name'}</tt>"),"<br>\n";
	$cmd = "$rc->{'file'} $mode";
	print "<pre>";
	&foreign_call("proc", "safe_process_exec_logged", $cmd, 0, 0, STDOUT, undef, 1);
	print "</pre>\n";
	&webmin_log($mode, 'action', $in{'name'});
	&ui_print_footer("edit_rc.cgi?name=".&urlize($in{'name'}),
			 $text{'edit_return'});
	}
else {
	# Validate inputs
	if ($in{'new'}) {
		$in{'name'} =~ /^[A-z0-9\_\-\.]+$/ ||
			&error($text{'save_ename'});
		($clash) = grep { $_->{'name'} eq $in{'name'} } @rcs;
		$clash && &error($text{'save_eclash'});
		$in{'start_cmd'} =~ /\S/ || &error($text{'save_estartcmd'});

		@dirs = split(/\s+/, $config{'rc_dir'});
		$file = $dirs[$#dir]."/".$in{'name'};
		$data =  "#!/bin/sh\n";
		$data .= "#\n";
		$data .= "# PROVIDE: $in{'name'}\n";
		$data .= "# REQUIRE: LOGIN\n";
		$data .= "\n";
		$data .= ". /etc/rc.subr\n";
		$data .= "\n";
		$data .= "name=$in{'name'}\n";
		$data .= "rcvar=`set_rcvar`\n";
		$data .= "start_cmd=\"$in{'start_cmd'}\"\n";
		if ($in{'stop_cmd'}) {
			$data .= "stop_cmd=\"$in{'stop_cmd'}\"\n";
			}
		if ($in{'status_cmd'}) {
			$data .= "status_cmd=\"$in{'status_cmd'}\"\n";
			}
		$data .= "\n";
		$data .= "load_rc_config \${name}\n";
		$data .= "run_rc_command \"\$1\"\n";
		}
	else {
		$data = $in{'script'};
		$data =~ s/\r//g;
		$data =~ /\S/ || &error($text{'save_escript'});
		$file = $rc->{'file'};
		}

	# Write out the file
	&open_lock_tempfile(SCRIPT, ">$file");
	&print_tempfile(SCRIPT, $data);
	&close_tempfile(SCRIPT);
	&set_ownership_permissions(undef, undef, 0755, $file);

	if ($rc->{'enabled'} != 2) {
		# Enable or disable
		&lock_rc_files();
		if ($in{'enabled'}) {
			&enable_rc_script($in{'name'});
			}
		else {
			&disable_rc_script($in{'name'});
			}
		&unlock_rc_files();
		}

	&webmin_log($in{'new'} ? "create" : "modify", "action", $in{'name'});
	&redirect("");
	}

