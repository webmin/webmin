#!/usr/local/bin/perl
# save_class.cgi
# Create, update or delete a class in a section

require './cfengine-lib.pl';
&ReadParse();
$conf = $in{'cfd'} ? &get_cfd_config() : &get_config();
$sec = $conf->[$in{'idx'}] if ($in{'idx'} ne '');
$cls = $sec->{'cls'}->[$in{'cidx'}] if ($in{'cidx'} ne '');

if ($in{'manualmode'}) {
	# Redirect back to the edit form, but in manual mode
	&redirect("edit_class.cgi?cfd=$in{'cfd'}&idx=$in{'idx'}&cidx=$in{'cidx'}&new=$in{'new'}&manual=1");
	}
elsif ($in{'delete'}) {
	# Just delete the class, and maybe the section too
	&lock_file($sec->{'file'});
	if (@{$sec->{'cls'}} == 1) {
		&save_directive($conf, $sec, undef);
		}
	else {
		&save_directive($sec->{'cls'}, $cls, undef);
		}
	&flush_file_lines();
	&unlock_file($sec->{'file'});
	&webmin_log("delete", @{$sec->{'cls'}} == 1 ? "section" : "class",
		    $sec->{'name'});
	&redirect($in{'cfd'} ? "edit_cfd.cgi" : "");
	}
else {
	# Validate and save inputs
	$type = $in{'idx'} eq '' ? $in{'type'} : $sec->{'name'};
	if (!$sec) {
		$sec = { 'name' => $type,
			 'type' => 'section',
			 'cls' => [ $cls = { 'type' => 'class' } ] };
		}
	elsif (!$cls) {
		$cls = { 'type' => 'class' };
		}
	&error_setup($text{'save_err'});
	$in{'class_def'} || $in{'class'} =~ /^\S+$/ ||
		&error($text{'save_eclass'});
	$cls->{'name'} = $in{'class_def'} ? 'any' : $in{'class'};
	$cls->{'implied'} = 0 if (!$in{'class_def'});

	if (defined($in{'manual'})) {
		# Just save manually edited text
		$in{'manual'} =~ s/\r//g;
		$cls->{'text'} = $in{'manual'};
		}
	elsif ($type eq 'links') {
		# Save link creation lines
		local @olinks = &parse_links($cls);
		local @links;
		for($i=0; defined($in{"from_$i"}); $i++) {
			next if (!$in{"from_$i"} && !$in{"to_$i"});
			local $link = $olinks[$i];
			$in{"from_$i"} =~ /^\S+$/ ||
				&error(&text('save_elinkfrom', $i+1));
			$link->{'_linkfrom'} = $in{"from_$i"};
			$in{"to_$i"} =~ /^\S+$/ ||
				&error(&text('save_elinkto', $i+1));
			$link->{'_linkto'} = $in{"to_$i"};
			$link->{'_linktype'} = $in{"type_$i"} ? "+>" : "->";
			$link->{'_linktype'} .= "!" if ($in{"over_$i"});
			push(@links, $link);
			}
		&unparse_links($cls, @links);
		}
	elsif ($type eq 'directories') {
		# Save directory creation lines
		local @odirs = &parse_directories($cls);
		local @dirs;
		for($i=0; defined($in{"dir_$i"}); $i++) {
			next if (!$in{"dir_$i"});
			local $dir = $odirs[$i];
			$in{"dir_$i"} =~ /^\S+$/ ||
				&error(&text('save_edir', $i+1));
			$dir->{'_dir'} = $in{"dir_$i"};

			&sdelete($dir, 'mode');
			if ($in{"mode_$i"} ne "") {
				$in{"mode_$i"} =~ /^[0-9]{3,4}$/ ||
					&error(&text('save_edirmode', $i+1));
				$dir->{'mode'} = $in{"mode_$i"};
				}

			&sdelete($dir, 'owner');
			if ($in{"owner_$i"} ne "") {
				$in{"owner_$i"} =~ /^\S+$/ ||
					&error(&text('save_edirowner', $i+1));
				$dir->{'owner'} = $in{"owner_$i"};
				}

			&sdelete($dir, 'group');
			if ($in{"group_$i"} ne "") {
				$in{"group_$i"} =~ /^\S+$/ ||
					&error(&text('save_edirgroup', $i+1));
				$dir->{'group'} = $in{"group_$i"};
				}

			push(@dirs, $dir);
			}
		&unparse_directories($cls, @dirs);
		}
	elsif ($type eq "control" && !$in{'cfd'}) {
		# Save actionsequence and other global definitions
		local ($sp, $qu) = &split_str($in{'seq'});
		push(@defs, { 'name' => 'actionsequence',
			      'values' => $sp,
			      'valuequotes' => $qu } );
		for($i=0; defined($in{"def_$i"}); $i++) {
			next if (!$in{"def_$i"});
			$in{"def_$i"} =~ /^\S+$/ ||
				&error(&text('save_econtroldef', $i+1));
			local ($sp, $qu) = &split_str($in{"value_$i"});
			push(@defs, { 'name' => $in{"def_$i"},
				      'values' => $sp,
				      'valuequotes' => $qu } );
			}
		$cls->{'defs'} = \@defs;
		}
	elsif ($type eq "control" && $in{'cfd'}) {
		# Save cfd-specific control options
		$in{'run_def'} ||
		    ($in{'run'} =~ /^(\S+)/ && &has_command("$1")) ||
			&error(&text('save_econtrolrun', "$1"));
		&save_define($cls->{'defs'}, "cfrunCommand",
			     $in{'run_def'} ? undef : [ $in{'run'} ]);

		$in{'elapsed_def'} || $in{'elapsed'} =~ /^\d+$/ ||
			&error($text{'save_econtrolelapsed'});
		&save_define($cls->{'defs'}, "IfElapsed",
			     $in{'elapsed_def'} ? undef : [ $in{'elapsed'} ]);

		$in{'max_def'} || $in{'max'} =~ /^\d+$/ ||
			&error($text{'save_econtrolmax'});
		&save_define($cls->{'defs'}, "MaxConnections",
			     $in{'max_def'} ? undef : [ $in{'max'} ]);

		$in{'auto_def'} ||
		    ($in{'auto'} =~ /^(\S+)/ && &has_command("$1")) ||
			&error(&text('save_econtrolauto', "$1"));
		&save_define($cls->{'defs'}, "AutoExecCommand",
			     $in{'auto_def'} ? undef : [ $in{'auto'} ]);

		$in{'interval_def'} || $in{'interval'} =~ /^\d+$/ ||
			&error($text{'save_econtrolinterval'});
		&save_define($cls->{'defs'}, "AutoExecInterval",
		     $in{'interval_def'} ? undef : [ $in{'interval'} ]);

		$in{'dom_def'} || $in{'dom'} =~ /^[A-Za-z0-9\.\-]+$/ ||
			&error($text{'save_econtroldomain'});
		&save_define($cls->{'defs'}, "domain",
		     $in{'dom_def'} ? undef : [ $in{'dom'} ]);

		&save_define($cls->{'defs'}, "LogAllConnections",
				$in{'log'} == 1 ? [ "true" ] :
				$in{'log'} == 0 ? [ "false" ] : undef);

		$in{'allow_def'} || $in{'allow'} =~ /\S/ ||
			&error($text{'save_econtrolallow'});
		&save_define($cls->{'defs'}, "AllowConnectionsFrom",
			     $in{'allow_def'} ? undef :
			     [ split(/\s+/, $in{'allow'}) ] );

		$in{'deny_def'} || $in{'deny'} =~ /\S/ ||
			&error($text{'save_econtroldeny'});
		&save_define($cls->{'defs'}, "DenyConnectionsFrom",
			     $in{'deny_def'} ? undef :
			     [ split(/\s+/, $in{'deny'}) ] );

		$in{'skip_def'} || $in{'skip'} =~ /\S/ ||
			&error($text{'save_econtrolskip'});
		&save_define($cls->{'defs'}, "SkipVerify",
			     $in{'skip_def'} ? undef :
			     [ split(/\s+/, $in{'skip'}) ] );
		}
	elsif ($type eq "admit" || $type eq "grant" || $type eq "deny") {
		# Save allowed or denied directories
		local $vl = 0;
		for($i=0; defined($in{"dir_$i"}); $i++) {
			next if (!$in{"dir_$i"});
			$in{"dir_$i"} =~ /^\S+$/ ||
				&error(&text('save_egrantdir', $i+1));
			push(@values, $in{"dir_$i"});
			push(@valuelines, $vl++);
			local @hosts = split(/\s+/, $in{"hosts_$i"});
			@hosts ||
			    &error(&text('save_egranthosts', $in{"dir_$i"}));
			foreach $h (@hosts) {
				&to_ipaddress($h) ||
				    $h =~ /\*/ || $h =~ /=/ ||
					&error(&text('save_egranthost', $h));
				push(@values, $h);
				push(@valuelines, $vl++);
				}
			$vl++;
			}

		$cls->{'values'} = \@values;
		$cls->{'valuelines'} = \@valuelines;
		}
	elsif ($type eq "groups" || $type eq "classes") {
		# Save group definitions
		for($i=0,$j=0; defined($in{"name_$i"}); $i++) {
			next if (!$in{"name_$i"});
			$in{"name_$i"} =~ /^\S+$/ ||
				&error(&text('save_egroupname', $i+1));
			local ($st, $qu) = &split_str($in{"mems_$i"});
			push(@defs, { 'name' => $in{"name_$i"},
				      'values' => $st,
				      'valuequotes' => $qu } );
			$j++;
			}
		$cls->{'defs'} = \@defs;
		}
	elsif ($type eq "files") {
		# Save all the files lines
		local @ofiles = &parse_directories($cls);
		local @files;
		for($i=0; defined($d = $in{"dir_$i"}); $i++) {
			next if ($in{"dir_def_$i"});
			local $file = $ofiles[$i];
			$file->{'_dir'} = $d;
			$d =~ /\S/ || &error(&text('save_efilesdir', $i+1));

			&sdelete($file, 'owner');
			if (!$in{"owner_def_$i"}) {
				$in{"owner_$i"} =~ /^\S+$/ ||
					&error(&text('save_efilesowner', $d));
				$file->{'owner'} = $in{"owner_$i"};
				}

			&sdelete($file, 'group');
			if (!$in{"group_def_$i"}) {
				$in{"group_$i"} =~ /^\S+$/ ||
					&error(&text('save_efilesgroup', $d));
				$file->{'group'} = $in{"group_$i"};
				}

			&sdelete($file, 'mode');
			if (!$in{"mode_def_$i"}) {
				$in{"mode_$i"} =~ /^\S+$/ ||
					&error(&text('save_efilesmode', $d));
				$file->{'mode'} = $in{"mode_$i"};
				}

			&sdelete($file, 'recurse');
			if ($in{"rec_def_$i"} == 2) {
				$file->{'recurse'} = 'inf';
				}
			elsif ($in{"rec_def_$i"} == 0) {
				$in{"rec_$i"} =~ /^\d+$/ ||
					&error(&text('save_efilesrec', $d));
				$file->{'recurse'} = $in{"rec_$i"};
				}

			&sdelete($file, 'include');
			if (!$in{"include_def_$i"}) {
				$in{"include_$i"} =~ /^\S+$/ ||
				    &error(&text('save_efilesinclude', $d));
				$file->{'include'} = $in{"include_$i"};
				}

			&sdelete($file, 'exclude');
			if (!$in{"exclude_def_$i"}) {
				$in{"exclude_$i"} =~ /^\S+$/ ||
				    &error(&text('save_efilesexclude', $d));
				$file->{'exclude'} = $in{"exclude_$i"};
				}

			&sdelete($file, 'acl');
			if (!$in{"acl_def_$i"}) {
				$in{"acl_$i"} =~ /^\S+$/ ||
					&error(&text('save_efileacl', $d));
				$file->{'acl'} = $in{"acl_$i"};
				}

			&sdelete($file, 'action');
			if ($in{"act_$i"}) {
				$file->{'action'} = $in{"act_$i"};
				}
			push(@files, $file);
			}
		&unparse_directories($cls, @files);
		}
	elsif ($type eq "copy") {
		# Save copy lines
		local @ocopies = &parse_directories($cls);
		local @copies;
		for($i=0; defined($d = $in{"dir_$i"}); $i++) {
			next if ($in{"dir_def_$i"});
			local $copy = $ocopies[$i];
			$copy->{'_dir'} = $d;
			$d =~ /\S/ || &error(&text('save_ecopydir', $i+1));

			&sdelete($copy, "dest");
			$in{"dest_$i"} =~ /\S/ ||
				&error(&text('save_ecopydest', $d));
			$copy->{'dest'} = $in{"dest_$i"};

			&sdelete($copy, "server");
			if (!$in{"server_def_$i"}) {
				&to_ipaddress($in{"server_$i"}) ||
					&error(&text('save_ecopyserver', $d));
				$copy->{'server'} = $in{"server_$i"};
				}

			&sdelete($copy, 'owner');
			if (!$in{"owner_def_$i"}) {
				$in{"owner_$i"} =~ /^\S+$/ ||
					&error(&text('save_ecopyowner', $d));
				$copy->{'owner'} = $in{"owner_$i"};
				}

			&sdelete($copy, 'group');
			if (!$in{"group_def_$i"}) {
				$in{"group_$i"} =~ /^\S+$/ ||
					&error(&text('save_ecopygroup', $d));
				$copy->{'group'} = $in{"group_$i"};
				}

			&sdelete($copy, 'mode');
			if (!$in{"mode_def_$i"}) {
				$in{"mode_$i"} =~ /^\S+$/ ||
					&error(&text('save_ecopymode', $d));
				$copy->{'mode'} = $in{"mode_$i"};
				}

			&sdelete($copy, 'recurse');
			if ($in{"rec_def_$i"} == 2) {
				$copy->{'recurse'} = 'inf';
				}
			elsif ($in{"rec_def_$i"} == 0) {
				$in{"rec_$i"} =~ /^\d+$/ ||
					&error(&text('save_ecopyrec', $d));
				$copy->{'recurse'} = $in{"rec_$i"};
				}

			&sdelete($copy, "size");
			if ($in{"size_mode_$i"} == 1) {
				$in{"size1_$i"} ne '' ||
					&error(&text('save_ecopysize', $d));
				$copy->{'size'} = $in{"size1_$i"};
				}
			elsif ($in{"size_mode_$i"} == 2) {
				$in{"size2_$i"} ne '' ||
					&error(&text('save_ecopysize', $d));
				$copy->{'size'} = "<".$in{"size2_$i"};
				}
			elsif ($in{"size_mode_$i"} == 3) {
				$in{"size3_$i"} ne '' ||
					&error(&text('save_ecopysize', $d));
				$copy->{'size'} = ">".$in{"size3_$i"};
				}

			&sdelete($copy, "backup");
			$copy->{'backup'} = 'false' if (!$in{"backup_$i"});

			&sdelete($copy, "force");
			$copy->{'force'} = 'true' if ($in{"force_$i"});

			&sdelete($copy, "purge");
			$copy->{'purge'} = 'true' if ($in{"purge_$i"});

			&sdelete($copy, "action");
			if ($in{"act_$i"}) {
				$copy->{'action'} = $in{"act_$i"};
				}

			push(@copies, $copy);
			}
		&unparse_directories($cls, @copies);
		}
	elsif ($type eq "disable") {
		# Save disable lines
		local @odis = &parse_directories($cls);
		local @dis;
		for($i=0; defined($d = $in{"dir_$i"}); $i++) {
			next if ($in{"dir_def_$i"});
			local $dis = $odis[$i];
			$dis->{'_dir'} = $d;
			$d =~ /\S/ || &error(&text('save_edisfile', $i+1));

			&sdelete($dis, "rotate");
			if ($in{"rot_mode_$i"} == 1) {
				$dis->{'rotate'} = 'empty';
				}
			elsif ($in{"rot_mode_$i"} == 2) {
				$in{"rot_$i"} =~ /^\d+$/ ||
					&error(&text('save_edisrot', $d));
				$dis->{'rotate'} = $in{"rot_$i"};
				}

			&sdelete($dis, "type");
			if ($in{"type_$i"}) {
				$dis->{'type'} = $in{"type_$i"};
				}

			&sdelete($dis, "size");
			if ($in{"size_mode_$i"} == 1) {
				$in{"size1_$i"} ne '' ||
					&error(&text('save_edissize', $d));
				$dis->{'size'} = $in{"size1_$i"};
				}
			elsif ($in{"size_mode_$i"} == 2) {
				$in{"size2_$i"} ne '' ||
					&error(&text('save_edissize', $d));
				$dis->{'size'} = "<".$in{"size2_$i"};
				}
			elsif ($in{"size_mode_$i"} == 3) {
				$in{"size3_$i"} ne '' ||
					&error(&text('save_edissize', $d));
				$dis->{'size'} = ">".$in{"size3_$i"};
				}

			push(@dis, $dis);
			}
		&unparse_directories($cls, @dis);
		}
	elsif ($type eq "editfiles") {
		# Save file-editing scripts
		for($i=0; defined($d = $in{"edit_$i"}); $i++) {
			local (@values, @valuelines);
			next if ($in{"edit_def_$i"});
			$d =~ /\S/ || &error(&text('save_eeditfile', $i+1));
			push(@values, $d);
			push(@valuelines, 0);
			push(@valuequotes, undef);

			$in{"script_$i"} =~ s/\r//g;
			local @lines = split(/\n/, $in{"script_$i"});
			for($j=0; $j<@lines; $j++) {
				local ($st, $qu) = &split_str($lines[$j]);
				push(@values, @$st);
				push(@valuequotes, @$qu);
				push(@valuelines, map { $j+1 } @$st);
				}
			@values > 1 || &error(&text('save_eeditscript', $d));

			push(@lists, { 'values' => \@values,
				       'valuelines' => \@valuelines,
				       'valuequotes' => \@valuequotes } );
			}
		$cls->{'lists'} = \@lists;
		}
	elsif ($type eq "ignore") {
		# Save list of ignored files
		local ($st, $qu) = &split_str($in{"ignore"});
		for($i=0; $i<@$st; $i++) {
			push(@values, $st->[$i]);
			push(@valuelines, $i);
			push(@valuequotes, $qu->[$i]);
			}
		$cls->{'values'} = \@values;
		$cls->{'valuelines'} = \@valuelines;
		$cls->{'valuequotes'} = \@valuequotes;
		}
	elsif ($type eq "processes") {
		# Save managed processes list
		local $ostr;
		local @oprocs = &parse_processes($cls);
		local @procs;
		for($i=0; defined($p = $in{"proc_$i"}) || $i<@oprocs; $i++) {
			next if ($in{"proc_def_$i"});
			local $proc = $oprocs[$i];
			if ($proc->{'_options'}) {
				push(@procs, $proc);
				next;
				}
			$proc->{'_match'} = $p;
			$p =~ /\S/ || &error(&text('save_eproc', $i+1));

			&sdelete($proc, "signal");
			if ($in{"sig_$i"}) {
				$proc->{'signal'} = $in{"sig_$i"};
				}

			&sdelete($proc, "action");
			if ($in{"act_$i"}) {
				$proc->{'action'} = $in{"act_$i"};
				}

			&sdelete($proc, "matches");
			if ($in{"mat_mode_$i"} == 1) {
				$in{"mat1_$i"} ne '' ||
					&error(&text('save_eprocmat', $d));
				$proc->{'matches'} = $in{"mat1_$i"};
				}
			elsif ($in{"mat_mode_$i"} == 2) {
				$in{"mat2_$i"} ne '' ||
					&error(&text('save_eprocmat', $d));
				$proc->{'matches'} = "<".$in{"mat2_$i"};
				}
			elsif ($in{"mat_mode_$i"} == 3) {
				$in{"mat3_$i"} ne '' ||
					&error(&text('save_eprocmat', $d));
				$proc->{'matches'} = ">".$in{"mat3_$i"};
				}

			delete($proc->{'_restart'});
			if (!$in{"restart_def_$i"}) {
				$in{"restart_$i"} =~ /\S/ ||
					&error(&text('save_eprocrestart', $p));
				$proc->{'_restart'} = $in{"restart_$i"};
				}

			&sdelete($proc, 'owner');
			if (!$in{"owner_def_$i"}) {
				$in{"owner_$i"} =~ /^\S+$/ ||
					&error(&text('save_eprocowner', $d));
				$proc->{'owner'} = $in{"owner_$i"};
				}

			&sdelete($proc, 'group');
			if (!$in{"group_def_$i"}) {
				$in{"group_$i"} =~ /^\S+$/ ||
					&error(&text('save_eprocgroup', $d));
				$proc->{'group'} = $in{"group_$i"};
				}

			push(@procs, $proc);
			}
		&unparse_processes($cls, @procs);
		}
	elsif ($type eq "shellcommands") {
		# Save commands to execute
		local @ocmds = &parse_directories($cls);
		local @cmds;
		for($i=0; defined($in{"cmd_$i"}); $i++) {
			next if (!$in{"cmd_$i"});
			local $cmd = $ocmd[$i];
			$in{"cmd_$i"} =~ /\S/ ||
				&error(&text('save_ecmd', $i+1));
			$cmd->{'_dir'} = $in{"cmd_$i"};

			&sdelete($cmd, 'owner');
			if ($in{"owner_$i"} ne "") {
				$in{"owner_$i"} =~ /^\S+$/ ||
					&error(&text('save_ecmdowner', $i+1));
				$cmd->{'owner'} = $in{"owner_$i"};
				}

			&sdelete($cmd, 'group');
			if ($in{"group_$i"} ne "") {
				$in{"group_$i"} =~ /^\S+$/ ||
					&error(&text('save_ecmdgroup', $i+1));
				$cmd->{'group'} = $in{"group_$i"};
				}

			&sdelete($cmd, "timeout");
			if ($in{"timeout_$i"} ne '') {
				$in{"timeout_$i"} =~ /^\d+$/ ||
					&error(&text('save_ecmdtimeout', $i+1));
				$cmd->{'timeout'} = $in{"timeout_$i"};
				}

			push(@cmds, $cmd);
			}
		&unparse_shellcommands($cls, @cmds);
		}
	elsif ($type eq "tidy") {
		# Save tidied directories
		local @otidy = &parse_directories($cls);
		local @tidy;
		for($i=0; defined($d = $in{"dir_$i"}); $i++) {
			next if ($in{"dir_def_$i"});
			local $tidy = $otidy[$i];
			$d =~ /^\S+$/ || &error(&text('save_etidy', $i+1));
			$tidy->{'_dir'} = $d;

			&sdelete($tidy, "pattern");
			if (!$in{"pat_def_$i"}) {
				$in{"pat_$i"} =~ /^\S+$/ ||
					&error(&text('save_etidypat', $d));
				$tidy->{'pattern'} = $in{"pat_$i"};
				}

			&sdelete($tidy, "size");
			if ($in{"smode_$i"} == 1) {
				$tidy->{'size'} = 'empty';
				}
			elsif ($in{"smode_$i"} == 2) {
				$in{"size_$i"} =~ /^\S+$/ ||
					&error(&text('save_etidysize', $d));
				$tidy->{'size'} = $in{"size_$i"};
				}

			&sdelete($tidy, "age");
			&sdelete($tidy, "type");
			if ($in{"type_$i"}) {
				$tidy->{'type'} = $in{"type_$i"};
				}
			if (!$in{"age_def_$i"}) {
				$in{"age_$i"} =~ /^\d+$/ ||
					&error(&text('save_etidyage', $d));
				$tidy->{'age'} = $in{"age_$i"};
				}

			&sdelete($tidy, 'recurse');
			if ($in{"rec_def_$i"} == 2) {
				$tidy->{'recurse'} = 'inf';
				}
			elsif ($in{"rec_def_$i"} == 0) {
				$in{"rec_$i"} =~ /^\d+$/ ||
					&error(&text('save_etidyrec', $d));
				$tidy->{'recurse'} = $in{"rec_$i"};
				}

			push(@tidy, $tidy);
			}
		&unparse_directories($cls, @tidy);
		}
	elsif ($type eq "miscmounts") {
		# Save mounted NFS filesystems
		local @omnts = &parse_miscmounts($cls);
		local @mnts;
		for($i=0; defined($d = $in{"src_$i"}); $i++) {
			next if (!$d);
			local $mnt = $omnts[$i];

			$d =~ /^\S+$/ ||
				&error(&text('save_emiscsrc', $i+1));
			$mnt->{'_src'} = $d;

			$in{"dest_$i"} =~ /^\S+$/ ||
				&error(&text('save_emiscdest', $d));
			$mnt->{'_dest'} = $in{"dest_$i"};

			&sdelete($mnt, "mode");
			$in{"mode_$i"} =~ /^\S*$/ ||
				&error(&text('save_emiscmode', $d));
			$mnt->{'mode'} = $in{"mode_$i"} if ($in{"mode_$i"});

			push(@mnts, $mnt);
			}
		&unparse_miscmounts($cls, @mnts);
		}
	elsif ($type eq "resolve") {
		# Save nameserver options
		$in{'ns'} =~ s/\r//g;
		local @ns = split(/\n/, $in{'ns'});
		$in{'other'} =~ s/\r//g;
		local @other = split(/\n/, $in{'other'});

		local $vl = 0;
		foreach $n (@ns) {
			push(@values, $n);
			push(@valuelines, $vl++);
			push(@valuequotes, "");
			}
		foreach $n (@other) {
			push(@values, $n);
			push(@valuelines, $vl++);
			push(@valuequotes, '"');
			}

		$cls->{'values'} = \@values;
		$cls->{'valuelines'} = \@valuelines;
		$cls->{'valuequotes'} = \@valuequotes;
		}
	elsif ($type eq "defaultroute") {
		# Save default router options
		$in{'route'} =~ /^\S+$/ || &error($text{'save_eroute'});
		$cls->{'values'} = [ $in{'route'} ];
		$cls->{'valuelines'} = 0;
		$cls->{'valuequotes'} = [ ];
		}
	elsif ($type eq "required" || $type eq "disks") {
		# Save filesystems to check
		local @oreqs = &parse_directories($cls);
		local @reqs;
		for($i=0; defined($d = $in{"fs_$i"}); $i++) {
			next if (!$d);
			local $req = $oreqs[$i];
			$d =~ /^\S+$/ || &error(&text('save_ereq', $i+1));
			$req->{'_dir'} = $d;

			&sdelete($req, "freespace");
			if (!$in{"free_def_$i"}) {
				$in{"free_$i"} =~ /^\S+$/ ||
					&error(&text('save_ereqfree', $d));
				$req->{'freespace'} = $in{"free_$i"};
				}

			push(@reqs, $req);
			}
		&unparse_directories($cls, @reqs);
		}

	# Write to the config file
	if ($in{'cidx'} ne '') {
		# Updating an existing class
		&lock_file($sec->{'file'});
		&save_directive($conf, $cls, $cls);
		&flush_file_lines();
		&unlock_file($sec->{'file'});
		&webmin_log("modify", "class", $sec->{'name'});
		}
	elsif ($in{'idx'} ne '') {
		# Adding a class to an existing section
		&lock_file($sec->{'file'});
		&save_directive($sec->{'cls'}, undef, $cls);
		&flush_file_lines();
		&unlock_file($sec->{'file'});
		&webmin_log("create", "class", $sec->{'name'});
		}
	else {
		# Creating a new section and class
		&lock_file($conf->[0]->{'file'});
		&save_directive($conf, undef, $sec);
		&flush_file_lines();
		&unlock_file($conf->[0]->{'file'});
		&webmin_log("create", "section", $sec->{'name'});
		}

	&redirect($in{'cfd'} ? "edit_cfd.cgi" : "");
	}

# save_define(&config, name, &values|undef)
sub save_define
{
local ($i, $old);
for($i=0; $i<@{$_[0]}; $i++) {
	if ($_[0]->[$i]->{'name'} eq $_[1]) {
		$old = $_[0]->[$i];
		last;
		}
	}
if ($old && $_[2]) {
	$_[0]->[$i]->{'values'} = $_[2];
	}
elsif ($old) {
	splice(@{$_[0]}, $i, 1);
	}
elsif ($_[2]) {
	push(@{$_[0]}, { 'name' => $_[1], 'values' => $_[2] } );
	}
}

# sdelete(&conf, name)
sub sdelete
{
local $i;
for($i=length($_[1]); $i>0; $i--) {
	local $s = substr($_[1], 0, $i);
	if (defined($_[0]->{$s})) {
		delete($_[0]->{$s});
		last;
		}
	}
}

