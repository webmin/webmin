#!/usr/local/bin/perl
# edit_class.cgi
# Edit options for a class in some section

require './cfengine-lib.pl';
use Config;
&ReadParse();
$conf = $in{'cfd'} ? &get_cfd_config() : &get_config();
$sec = $conf->[$in{'idx'}] if ($in{'idx'} ne '');
if ($in{'new'}) {
	&ui_print_header(undef, $sec ? $text{'edit_create2'} : $text{'edit_create1'}, "",
		"edit");
	$cls = { 'name' => 'any' };
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "", "edit");
	$cls = $sec->{'cls'}->[$in{'cidx'}];
	}

print "<form action=save_class.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=cidx value='$in{'cidx'}'>\n";
print "<input type=hidden name=type value='$in{'type'}'>\n";
print "<input type=hidden name=cfd value='$in{'cfd'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$type = $in{'type'} ? $in{'type'} : $sec->{'name'};
$t = $text{"section_".$type."_".$in{'cfd'}};
$t = $text{"section_".$type} if (!$t);
print "<tr> <td><b>$text{'edit_section'}</b></td> <td colspan=3>\n";
print $t ? "$t ($type)" : $type,"</td> </tr>\n";

print "<td><b>$text{'edit_class'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=class_def value=1 %s> %s\n",
	$cls->{'name'} eq 'any' ? 'checked' : '', $text{'edit_all'};
printf "<input type=radio name=class_def value=0 %s>\n",
	$cls->{'name'} eq 'any' ? '' : 'checked';
printf "<input name=class size=50 value='%s'></td> </tr>\n",
	$cls->{'name'} eq 'any' ? '' : $cls->{'name'};

$type = undef if ($in{'manual'});
if ($text{"type_".$type."_".$in{'cfd'}}) {
	print "<tr> <td colspan=4>",$text{"type_".$type."_".$in{'cfd'}},
	      "</td> </tr>\n";
	}
elsif ($text{"type_".$type}) {
	print "<tr> <td colspan=4>",$text{"type_".$type},"</td> </tr>\n";
	}
if ($type eq 'links') {
	# Show links that would be created
	local @links = &parse_links($cls);
	print "<tr> <td valign=top><b>$text{'edit_links'}</b></td>\n";
	print "<td colspan=3><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_linkfrom'}</b></td> ",
	      "<td><b>$text{'edit_linktype'}</b></td> ",
	      "<td><b>$text{'edit_linkover'}</b></td> ",
	      "<td><b>$text{'edit_linkto'}</b></td> </tr>\n";
	$i = 0;
	foreach $l (@links, { }) {
		print "<tr $cb>\n";
		printf "<td><input name=from_$i size=30 value='%s'></td>\n",
			$l->{'_linkfrom'};
		printf "<td><input type=checkbox name=type_$i value=1 %s> %s</td>\n", $l->{'_linktype'} =~ /^\+/ ? "checked" : "", $text{'yes'};
		printf "<td><input type=checkbox name=over_$i value=1 %s> %s</td>\n", $l->{'_linktype'} =~ /!$/ ? "checked" : "", $text{'yes'};
		printf "<td><input name=to_$i size=30 value='%s'></td>\n",
			$l->{'_linkto'};
		print "</tr>\n";
		$i++;
		}
	print "</table></td> </tr>\n";
	}
elsif ($type eq 'directories') {
	# Show directories that would be created
	local @dirs = &parse_directories($cls);
	print "<tr> <td colspan=4><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_dir'}</b></td> ",
	      "<td><b>$text{'edit_dirmode'}</b></td> ",
	      "<td><b>$text{'edit_dirowner'}</b></td> ",
	      "<td><b>$text{'edit_dirgroup'}</b></td> </tr>\n";
	$i = 0;
	foreach $d (@dirs, { }) {
		print "<tr $cb>\n";
		printf "<td><input name=dir_$i size=40 value='%s'></td>\n",
			$d->{'_dir'};
		printf "<td><input name=mode_$i size=4 value='%s'></td>\n",
			&sname("mode", $d);
		printf "<td><input name=owner_$i size=13 value='%s'></td>\n",
			&sname("owner", $d);
		printf "<td><input name=group_$i size=13 value='%s'></td>\n",
			&sname("group", $d);
		print "</tr>\n";
		$i++;
		}
	print "</table></td> </tr>\n";
	}
elsif ($type eq "control" && !$in{'cfd'}) {
	# Show actionsequence definition
	local ($as) = &find("actionsequence", $cls->{'defs'});
	print "<tr> <td valign=top><b>$text{'edit_actionseq'}</b></td>\n";
	print "<td colspan=3><table cellpadding=0 cellspacing=0>\n";
	print "<tr> <td valign=top><textarea name=seq rows=10 cols=30>";
	foreach $v (@{$as->{'valuequoted'}}) {
		print &html_escape($v),"\n";
		}
	print "</textarea></td>\n";
	print "<td><select name=add size=10>\n";
	foreach $s ($in{'cfd'} ? @known_cfd_sections : @known_sections) {
		next if ($s eq "control");
		local $t = $text{"section_".$s."_".$in{'cfd'}};
		$t = $text{"section_".$s} if (!$t);
		printf "<option value=$s>$t ($s)</option>\n";
		}
	print "</select><br>\n";
	print "<input type=button value='$text{'edit_actionadd'}' onClick='document.forms[0].seq.value += document.forms[0].add.options[document.forms[0].add.selectedIndex].value+\"\\n\"'>\n";
	print "</td></tr></table> </td> </tr>\n";

	# Show other global definitions
	print "<tr> <td><b>$text{'edit_controldef'}</b></td> ",
	      "<td colspan=3><b>$text{'edit_controlvalue'}</b></td> </tr>\n";
	$i = 0;
	foreach $d (@{$cls->{'defs'}}, { }) {
		next if ($d->{'name'} eq 'actionsequence');
		print "<tr>\n";
		printf "<td><input name=def_$i size=15 value='%s'></td>\n",
			$d->{'name'};
		printf "<td colspan=3><input name=value_$i size=50 value='%s'></td>\n", join(" ", @{$d->{'valuequoted'}});
		print "</tr>\n";
		$i++;
		}
	}
elsif ($type eq "control" && $in{'cfd'}) {
	# Show cfd-specific control options
	local $run = &find_value("cfrunCommand", $cls->{'defs'});
	print "<tr> <td><b>$text{'edit_controlrun'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=run_def value=1 %s> %s\n",
		$run ? "" : "checked", $text{'edit_none'};
	printf "<input type=radio name=run_def value=0 %s>\n",
		$run ? "checked" : "";
	printf "<input name=run size=50 value='%s'></td> </tr>\n", $run;

	local $elapsed = &find_value("IfElapsed", $cls->{'defs'});
	print "<tr> <td><b>$text{'edit_controlelapsed'}</b></td> <td>\n";
	printf "<input type=radio name=elapsed_def value=1 %s> %s\n",
		defined($elapsed) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=elapsed_def value=0 %s>\n",
		defined($elapsed) ? "checked" : "";
	printf "<input name=elapsed size=5 value='%s'></td>\n", $elapsed;

	local $max = &find_value("MaxConnections", $cls->{'defs'});
	print "<td><b>$text{'edit_controlmax'}</b></td> <td>\n";
	printf "<input type=radio name=max_def value=1 %s> %s\n",
		defined($max) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=max_def value=0 %s>\n",
		defined($max) ? "checked" : "";
	printf "<input name=max size=5 value='%s'></td> </tr>\n", $max;

	print "<tr> <td colspan=4><hr></td> </tr>\n";

	local $auto = &find_value("AutoExecCommand", $cls->{'defs'});
	print "<tr> <td><b>$text{'edit_controlauto'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=auto_def value=1 %s> %s\n",
		$auto ? "" : "checked", $text{'edit_none'};
	printf "<input type=radio name=auto_def value=0 %s>\n",
		$auto ? "checked" : "";
	printf "<input name=auto size=50 value='%s'></td></tr>\n", $auto;

	local $interval = &find_value("AutoExecInterval", $cls->{'defs'});
	print "<tr> <td><b>$text{'edit_controlinterval'}</b></td> <td>\n";
	printf "<input type=radio name=interval_def value=1 %s> %s\n",
		defined($interval) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=interval_def value=0 %s>\n",
		defined($interval) ? "checked" : "";
	printf "<input name=interval size=5 value='%s'></td> </tr>\n",$interval;

	print "<tr> <td colspan=4><hr></td> </tr>\n";

	local $dom = &find_value("domain", $cls->{'defs'});
	print "<tr> <td><b>$text{'edit_controldom'}</b></td> <td>\n";
	printf "<input type=radio name=dom_def value=1 %s> %s\n",
		$dom ? "" : "checked", $text{'edit_none'};
	printf "<input type=radio name=dom_def value=0 %s>\n",
		$dom ? "checked" : "";
	printf "<input name=dom size=15 value='%s'></td>\n", $dom;

	local $log = &find_value("LogAllConnections", $cls->{'defs'});
	print "<td><b>$text{'edit_controllog'}</b></td>\n";
	printf "<td><input type=radio name=log value=1 %s> %s\n",
		lc($log) eq "true" ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=log value=0 %s> %s\n",
		lc($log) eq "false" ? "checked" : "", $text{'no'};
	printf "<input type=radio name=log value=-1 %s> %s</td> </tr>\n",
		$log ? "" : "checked", $text{'default'};

	local @allow = &find_value("AllowConnectionsFrom", $cls->{'defs'});
	print "<tr> <td><b>$text{'edit_controlallow'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=allow_def value=1 %s> %s ",
		@allow ? "" : "checked", $text{'edit_controlall'};
	printf "<input type=radio name=allow_def value=0 %s>\n",
		@allow ? "checked" : "";
	printf "<input name=allow size=40 value='%s'></td> </tr>\n",
		join(" ", @allow);

	local @deny = &find_value("DenyConnectionsFrom", $cls->{'defs'});
	print "<tr> <td><b>$text{'edit_controldeny'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=deny_def value=1 %s> %s ",
		@deny ? "" : "checked", $text{'edit_controlnone'};
	printf "<input type=radio name=deny_def value=0 %s>\n",
		@deny ? "checked" : "";
	printf "<input name=deny size=40 value='%s'></td> </tr>\n",
		join(" ", @deny);

	local @skip = &find_value("SkipVerify", $cls->{'defs'});
	print "<tr> <td><b>$text{'edit_controlskip'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=skip_def value=1 %s> %s ",
		@skip ? "" : "checked", $text{'edit_controlnone'};
	printf "<input type=radio name=skip_def value=0 %s>\n",
		@skip ? "checked" : "";
	printf "<input name=skip size=40 value='%s'></td> </tr>\n",
		join(" ", @skip);
	}
elsif ($type eq "grant" || $type eq "admit" || $type eq "deny") {
	# Allow editing of allowed or denied directories
	local (@grants, $grant);
	foreach $v (@{$cls->{'values'}}) {
		if ($v =~ /\//) {
			push(@grants, $grant = { 'dir' => $v });
			}
		else {
			push(@{$grant->{'hosts'}}, $v);
			}
		}

	print "<tr> <td valign=top><b>",$text{'edit_'.$type},"</b></td>\n";
	print "<td colspan=3><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_grantdir'}</b></td> ",
	      "<td><b>$text{'edit_granthosts'}</b></td> </tr>\n";
	$i = 0;
	foreach $g (@grants, { }) {
		print "<tr $cb>\n";
		printf "<td><input name=dir_$i size=20 value='%s'></td>\n",
			$g->{'dir'};
		printf "<td><input name=hosts_$i size=40 value='%s'></td>\n",
			join(" ", @{$g->{'hosts'}});
		print "</tr>\n";
		$i++;
		}
	print "</table></td></tr>\n";
	}
elsif ($type eq "groups" || $type eq "classes") {
	# Allow editing of group definitions
	print "<tr> <td valign=top><b>$text{'edit_groups'}</b></td>\n";
	print "<td colspan=3><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_groupname'}</b></td> ",
	      "<td><b>$text{'edit_groupmems'}</b></td> </tr>\n";
	$i = 0;
	foreach $g (@{$cls->{'defs'}}, { }) {
		print "<tr $cb>\n";
		printf "<td><input name=name_$i size=15 value='%s'></td>\n",
			$g->{'name'};
		printf "<td><input name=mems_$i size=45 value='%s'></td>\n",
			join(" ", @{$g->{'valuequoted'}});
		print "</tr>\n";
		$i++;
		}
	print "</table></td></tr>\n";
	}
elsif ($type eq "files") {
	# Allow editing of file permission settings
	local @files = &parse_directories($cls);
	local $i = 0;
	foreach $f (@files, $in{'newfiles'} || $in{'new'} ? ( { } ) : ( ) ) {
		print "<tr> <td colspan=4><hr></td> </tr>\n";

		print "<tr> <td><b>$text{'edit_filesdir'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=dir_def_$i value=1 %s> %s\n",
			$f->{'_dir'} ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=dir_def_$i value=0 %s>\n",
			$f->{'_dir'} ? "checked" : "";
		printf "<input name=dir_$i size=50 value='%s'></td> </tr>\n",
			$f->{'_dir'};

		local $owner = &sname("owner", $f);
		print "<tr> <td><b>$text{'edit_filesowner'}</b></td> <td>\n";
		printf "<input type=radio name=owner_def_$i value=1 %s> %s\n",
			$owner ? "" : "checked", $text{'edit_nochange'};
		printf "<input type=radio name=owner_def_$i value=0 %s>\n",
			$owner ? "checked" : "";
		printf "<input name=owner_$i size=13 value='%s'></td>\n",
			$owner;

		local $group = &sname("group", $f);
		print "<td><b>$text{'edit_filesgroup'}</b></td> <td>\n";
		printf "<input type=radio name=group_def_$i value=1 %s> %s\n",
			$group ? "" : "checked", $text{'edit_nochange'};
		printf "<input type=radio name=group_def_$i value=0 %s>\n",
			$group ? "checked" : "";
		printf "<input name=group_$i size=13 value='%s'></td> </tr>\n",
			$group;

		local $mode = &sname("mode", $f);
		print "<tr> <td><b>$text{'edit_filesmode'}</b></td> <td>\n";
		printf "<input type=radio name=mode_def_$i value=1 %s> %s\n",
			$mode ? "" : "checked", $text{'edit_nochange'};
		printf "<input type=radio name=mode_def_$i value=0 %s>\n",
			$mode ? "checked" : "";
		printf "<input name=mode_$i size=15 value='%s'></td>\n",
			$mode;

		local $rec = &sname("recurse", $f);
		print "<td><b>$text{'edit_filesrec'}</b></td> <td>\n";
		printf "<input type=radio name=rec_def_$i value=1 %s> %s\n",
			$rec ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=rec_def_$i value=2 %s> %s\n",
			$rec eq 'inf' ? "checked" : "",
			$text{'edit_filesinf'};
		printf "<input type=radio name=rec_def_$i value=0 %s>\n",
			$rec && $rec ne 'inf' ? "checked" : "";
		printf "<input name=rec_$i size=6 value='%s'></td> </tr>\n",
			$rec eq 'inf' ? '' : $rec;

		local $include = &sname("include", $f);
		print "<tr> <td><b>$text{'edit_filesinclude'}</b></td> <td>\n";
		printf "<input type=radio name=include_def_$i value=1 %s> %s\n",
			$include ? "" : "checked", $text{'edit_filesall'};
		printf "<input type=radio name=include_def_$i value=0 %s>\n",
			$include ? "checked" : "";
		printf "<input name=include_$i size=15 value='%s'></td>\n",
			$include;

		local $exclude = &sname("exclude", $f);
		print "<td><b>$text{'edit_filesexclude'}</b></td> <td>\n";
		printf "<input type=radio name=exclude_def_$i value=1 %s> %s\n",
			$exclude ? "" : "checked", $text{'edit_filesnone'};
		printf "<input type=radio name=exclude_def_$i value=0 %s>\n",
			$exclude ? "checked" : "";
		printf "<input name=exclude_$i size=13 value='%s'></td></tr>\n",
			$exclude;

		local $acl = &sname("acl", $f);
		print "<tr> <td><b>$text{'edit_filesacl'}</b></td> <td>\n";
		printf "<input type=radio name=acl_def_$i value=1 %s> %s\n",
			$acl ? "" : "checked", $text{'edit_nochange'};
		printf "<input type=radio name=acl_def_$i value=0 %s>\n",
			$acl ? "checked" : "";
		printf "<input name=acl_$i size=15 value='%s'></td>\n",
			$acl;

		local $action = &sname("action", $f);
		local @acts = ( "fixall", "fixdirs", "fixplain", "warnall", "warndirs", "warnplain", "touch", "linkchildren", "create", "compress", "alert" );
		print "<td><b>$text{'edit_filesact'}</b></td>\n";
		print "<td><select name=act_$i>\n";
		printf "<option value='' %s>%s</option>\n",
			$action ? "" : "selected", $text{'default'};
		foreach $a (@acts) {
			printf "<option value=%s %s>%s</option>\n",
				$a, $action eq $a ? "selected" : "",
				$text{"edit_files_$a"};
			}
		print "<option selected>$action</option>\n"
			if ($action && &indexof($action, @acts) < 0);
		print "</select></td> </tr>\n";
		
		$i++;
		}
	if (!$in{'newfiles'} && !$in{'new'}) {
		print "<tr> <td colspan=4 align=right><hr><a href='edit_class.cgi?$in&newfiles=1'>$text{'edit_filesnew'}</a></td>\n";
		}
	}
elsif ($type eq "copy") {
	# Allow editing of file copy options
	local @copies = &parse_directories($cls);
	local $i = 0;
	foreach $f (@copies, $in{'newcopy'} || $in{'new'} ? ( { } ) : ( ) ) {
		print "<tr> <td colspan=4><hr></td> </tr>\n";

		print "<tr> <td><b>$text{'edit_copydir'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=dir_def_$i value=1 %s> %s\n",
			$f->{'_dir'} ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=dir_def_$i value=0 %s>\n",
			$f->{'_dir'} ? "checked" : "";
		printf "<input name=dir_$i size=50 value='%s'></td> </tr>\n",
			$f->{'_dir'};

		print "<tr> <td><b>$text{'edit_copydest'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input name=dest_$i size=50 value='%s'></td> </tr>\n",
			&sname("dest", $f);

		local $server = &sname("server", $f);
		print "<tr> <td><b>$text{'edit_copyserver'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=server_def_$i value=1 %s> %s\n",
			$server ? "" : "checked", $text{'edit_local'};
		printf "<input type=radio name=server_def_$i value=0 %s>\n",
			$server ? "checked" : "";
		printf "<input name=server_$i size=40 value='%s'></td> </tr>\n",
			$server;

		local $owner = &sname("owner", $f);
		print "<tr> <td><b>$text{'edit_filesowner'}</b></td> <td>\n";
		printf "<input type=radio name=owner_def_$i value=1 %s> %s\n",
			$owner ? "" : "checked", $text{'edit_nochange'};
		printf "<input type=radio name=owner_def_$i value=0 %s>\n",
			$owner ? "checked" : "";
		printf "<input name=owner_$i size=13 value='%s'></td>\n",
			$owner;

		local $group = &sname("group", $f);
		print "<td><b>$text{'edit_filesgroup'}</b></td> <td>\n";
		printf "<input type=radio name=group_def_$i value=1 %s> %s\n",
			$group ? "" : "checked", $text{'edit_nochange'};
		printf "<input type=radio name=group_def_$i value=0 %s>\n",
			$group ? "checked" : "";
		printf "<input name=group_$i size=13 value='%s'></td> </tr>\n",
			$group;

		local $mode = &sname("mode", $f);
		print "<tr> <td><b>$text{'edit_filesmode'}</b></td> <td>\n";
		printf "<input type=radio name=mode_def_$i value=1 %s> %s\n",
			$mode ? "" : "checked", $text{'edit_nochange'};
		printf "<input type=radio name=mode_def_$i value=0 %s>\n",
			$mode ? "checked" : "";
		printf "<input name=mode_$i size=15 value='%s'></td>\n",
			$mode;

		local $rec = &sname("recurse", $f);
		print "<td><b>$text{'edit_filesrec'}</b></td> <td>\n";
		printf "<input type=radio name=rec_def_$i value=1 %s> %s\n",
			$rec ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=rec_def_$i value=2 %s> %s\n",
			$rec eq 'inf' ? "checked" : "",
			$text{'edit_filesinf'};
		printf "<input type=radio name=rec_def_$i value=0 %s>\n",
			$rec && $rec ne 'inf' ? "checked" : "";
		printf "<input name=rec_$i size=6 value='%s'></td> </tr>\n",
			$rec eq 'inf' ? '' : $rec;

		local $size = &sname("size", $f);
		local $smode = $size =~ /^>/ ? 3 : $size =~ /^</ ? 2 :
			       $size ne '' ? 1 : 0;
		print "<tr> <td><b>$text{'edit_copysize'}</b></td>\n";
		print "<td colspan=3>\n";
		printf "<input type=radio name=size_mode_$i value=0 %s> %s\n",
			$smode == 0 ? "checked" : "", $text{'edit_none'};

		printf "<input type=radio name=size_mode_$i value=2 %s> %s\n",
			$smode == 2 ? "checked" : "", $text{'edit_copysize2'};
		printf "<input name=size2_$i size=8 value='%s'>\n",
			$smode == 2 ? substr($size, 1) : "";

		printf "<input type=radio name=size_mode_$i value=1 %s> %s\n",
			$smode == 1 ? "checked" : "", $text{'edit_copysize1'};
		printf "<input name=size1_$i size=8 value='%s'>\n",
			$smode == 1 ? $size : "";

		printf "<input type=radio name=size_mode_$i value=3 %s> %s\n",
			$smode == 3 ? "checked" : "", $text{'edit_copysize3'};
		printf "<input name=size3_$i size=8 value='%s'>\n",
			$smode == 3 ? substr($size, 1) : "";

		local $backup = &sname("backup", $f);
		print "<tr> <td><b>$text{'edit_copybackup'}</b></td> <td>\n";
		printf "<input type=radio name=backup_$i value=1 %s> %s\n",
			$backup eq "false" ? "" : "checked", $text{'yes'};
		printf "<input type=radio name=backup_$i value=0 %s> %s</td>\n",
			$backup eq "false" ? "checked" : "", $text{'no'};

		local $force = &sname("force", $f);
		print "<td><b>$text{'edit_copyforce'}</b></td> <td>\n";
		printf "<input type=radio name=force_$i value=1 %s> %s\n",
			$force eq "true" ? "checked" : "", $text{'yes'};
		printf"<input type=radio name=force_$i value=0 %s> %s</td>\n",
			$force eq "true" ? "" : "checked", $text{'no'};
		print "</tr>\n";

		local $purge = &sname("purge", $f);
		print "<tr> <td><b>$text{'edit_copypurge'}</b></td> <td>\n";
		printf "<input type=radio name=purge_$i value=1 %s> %s\n",
			$purge eq "true" ? "checked" : "", $text{'yes'};
		printf"<input type=radio name=purge_$i value=0 %s> %s</td>\n",
			$purge eq "true" ? "" : "checked", $text{'no'};

		local $action = &sname("action", $f);
		local @acts = ( "fix", "silent", "warn" );
		print "<td><b>$text{'edit_copyact'}</b></td>\n";
		print "<td><select name=act_$i>\n";
		printf "<option value='' %s>%s</option>\n",
			$action ? "" : "selected", $text{'default'};
		foreach $a (@acts) {
			printf "<option value=%s %s>%s</option>\n",
				$a, $action eq $a ? "selected" : "",
				$text{"edit_copy_$a"};
			}
		print "<option selected>$action</option>\n"
			if ($action && &indexof($action, @acts) < 0);
		print "</select></td> </tr>\n";

		$i++;
		}
	if (!$in{'newcopy'} && !$in{'new'}) {
		print "<tr> <td colspan=4 align=right><hr><a href='edit_class.cgi?$in&newcopy=1'>$text{'edit_copynew'}</a></td>\n";
		}
	}
elsif ($type eq "disable") {
	# Editing files to disable or delete
	local @dis = &parse_directories($cls);
	local $i = 0;
	foreach $f (@dis, $in{'newdis'} || $in{'new'} ? ( { } ) : ( ) ) {
		print "<tr> <td colspan=4><hr></td> </tr>\n";

		print "<tr> <td><b>$text{'edit_disfile'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=dir_def_$i value=1 %s> %s\n",
			$f->{'_dir'} ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=dir_def_$i value=0 %s>\n",
			$f->{'_dir'} ? "checked" : "";
		printf "<input name=dir_$i size=50 value='%s'></td> </tr>\n",
			$f->{'_dir'};

		local $rot = &sname("rotate", $f);
		print "<tr> <td><b>$text{'edit_disrot'}</b></td>\n";
		print "<td colspan=3>\n";
		printf "<input type=radio name=rot_mode_$i value=0 %s> %s\n",
			$rot eq '' ? "checked" : "", $text{'edit_disrot0'};
		printf "<input type=radio name=rot_mode_$i value=1 %s> %s\n",
			$rot eq 'empty' || $rot eq 'truncate' ? "checked" : "",
			$text{'edit_disrot1'};
		printf "<input type=radio name=rot_mode_$i value=2 %s>\n",
			$rot =~ /\d/ ? "checked" : "";
		print &text('edit_disrot2', sprintf("<input name=rot_$i size=6 value='%s'>", $rot =~ /\d/ ? $rot : undef)),"</td> </tr>\n";

		local $type = &sname("type", $f);
		local @types = ( "plain", "file", "link" );
		print "<tr> <td><b>$text{'edit_distype'}</b></td>\n";
		print "<td><select name=type_$i>\n";
		printf "<option value='' %s>%s</option>\n",
			$type ? "" : "selected", $text{'edit_dis_all'};
		foreach $t (@types) {
			printf "<option value=%s %s>%s</option>\n",
				$t, $type eq $t ? "selected" : "",
				$text{"edit_dis_$t"};
			}
		print "<option selected>$type</option>\n"
			if ($type && &indexof($type, @types) < 0);
		print "</select></td>\n";

		local $size = &sname("size", $f);
		local $smode = $size =~ /^>/ ? 3 : $size =~ /^</ ? 2 :
			       $size ne '' ? 1 : 0;
		print "<tr> <td><b>$text{'edit_dissize'}</b></td>\n";
		print "<td colspan=3>\n";
		printf "<input type=radio name=size_mode_$i value=0 %s> %s\n",
			$smode == 0 ? "checked" : "", $text{'edit_none'};

		printf "<input type=radio name=size_mode_$i value=2 %s> %s\n",
			$smode == 2 ? "checked" : "", $text{'edit_copysize2'};
		printf "<input name=size2_$i size=8 value='%s'>\n",
			$smode == 2 ? substr($size, 1) : "";

		printf "<input type=radio name=size_mode_$i value=1 %s> %s\n",
			$smode == 1 ? "checked" : "", $text{'edit_copysize1'};
		printf "<input name=size1_$i size=8 value='%s'>\n",
			$smode == 1 ? $size : "";

		printf "<input type=radio name=size_mode_$i value=3 %s> %s\n",
			$smode == 3 ? "checked" : "", $text{'edit_copysize3'};
		printf "<input name=size3_$i size=8 value='%s'>\n",
			$smode == 3 ? substr($size, 1) : "";

		$i++;
		}
	if (!$in{'newdis'} && !$in{'new'}) {
		print "<tr> <td colspan=4 align=right><hr><a href='edit_class.cgi?$in&newdis=1'>$text{'edit_disnew'}</a></td>\n";
		}
	}
elsif ($type eq "editfiles") {
	# Allow editing of file-editor script
	local $i = 0;
	foreach $e (@{$cls->{'lists'}},
		    $in{'newedit'} || $in{'new'} ? ( { } ) : ( ) ) {
		print "<tr> <td colspan=4><hr></td> </tr>\n";

		local $ef = $e->{'values'}->[0];
		print "<tr> <td><b>$text{'edit_editfile'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=edit_def_$i value=1 %s> %s\n",
			$ef ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=edit_def_$i value=0 %s>\n",
			$ef ? "checked" : "";
		printf "<input name=edit_$i size=50 value='%s'></td> </tr>\n",
			$ef;

		print "<tr> <td valign=top><b>$text{'edit_editscript'}</b>",
		      "</td> <td colspan=3>\n";
		print "<textarea name=script_$i rows=7 cols=70>";
		shift(@{$e->{'values'}});
		shift(@{$e->{'valuelines'}});
		shift(@{$e->{'valuequotes'}});
		foreach $l (&value_lines($e->{'values'}, $e->{'valuelines'},
					 $e->{'valuequotes'})) {
			print &html_escape($l),"\n";
			}
		print "</textarea></td> </tr>\n";

		$i++;
		}
	if (!$in{'newedit'} && !$in{'new'}) {
		print "<tr> <td colspan=4 align=right><hr><a href='edit_class.cgi?$in&newedit=1'>$text{'edit_editnew'}</a></td>\n";
		}
	}
elsif ($type eq "ignore") {
	# Display list of ignored files
	print "<tr> <td valign=top><b>$text{'edit_ignore'}</b></td>\n";
	print "<td colspan=3><textarea name=ignore rows=8 cols=50>";
	foreach $v (@{$cls->{'valuequoted'}}) {
		print &html_escape($v),"\n";
		}
	print "</textarea></td> </tr>\n";
	}
elsif ($type eq "processes") {
	# Show processes to kill
	local @procs = &parse_processes($cls);
	local $i = 0;
	foreach $p (@procs, $in{'newproc'} || $in{'new'} ? ( { } ) : ( ) ) {
		if ($p->{'_options'}) {
			# Don't edit SetOptionString lines
			$i++;
			next;
			}
		print "<tr> <td colspan=4><hr></td> </tr>\n";

		print "<tr> <td><b>$text{'edit_proc'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=proc_def_$i value=1 %s> %s\n",
			$p->{'_match'} ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=proc_def_$i value=0 %s>\n",
			$p->{'_match'} ? "checked" : "";
		printf "<input name=proc_$i size=50 value='%s'></td> </tr>\n",
			$p->{'_match'};

		local $sig = &sname("signal", $p);
		print "<tr> <td><b>$text{'edit_procsig'}</b></td>\n";
		print "<td><select name=sig_$i>\n";
		printf "<option value='' %s>%s</option>\n",
			$sig ? "" : "selected", $text{'edit_none'};
		foreach $s (split(/\s+/, $Config{sig_name})) {
			printf "<option value=%s %s>$s</option>\n",
				lc($s), lc($s) eq $sig ? "selected" : "", $s;
			}
		print "</select></td>\n";

		local $act = &sname("action", $p);
		print "<td><b>$text{'edit_procact'}</b></td>\n";
		print "<td><select name=act_$i>\n";
		printf "<option value='' %s>%s</option>\n",
			!$act || $act eq 'signal' || $act eq 'do' ?
				"selected" : "", $text{"edit_proc_signal"};
		printf "<option value=bymatch %s>%s</option>\n",
			$act eq "bymatch" ? "selected" : "",
			$text{"edit_proc_bymatch"};
		printf "<option value=warn %s>%s</option>\n",
			$act eq "warn" ? "selected" : "",
			$text{"edit_proc_warn"};
		print "</select></td> </tr>\n";

		local $mat = &sname("matches", $p);
		local $smode = $mat =~ /^>/ ? 3 : $mat =~ /^</ ? 2 :
			       $mat ne '' ? 1 : 0;
		print "<tr> <td><b>$text{'edit_procmat'}</b></td>\n";
		print "<td colspan=3>\n";
		printf "<input type=radio name=mat_mode_$i value=0 %s> %s\n",
			$smode == 0 ? "checked" : "", $text{'edit_procmat0'};

		printf "<input type=radio name=mat_mode_$i value=2 %s> %s\n",
			$smode == 2 ? "checked" : "", $text{'edit_procmat2'};
		printf "<input name=mat2_$i size=8 value='%s'>\n",
			$smode == 2 ? substr($mat, 1) : "";

		printf "<input type=radio name=mat_mode_$i value=1 %s> %s\n",
			$smode == 1 ? "checked" : "", $text{'edit_procmat1'};
		printf "<input name=mat1_$i size=8 value='%s'>\n",
			$smode == 1 ? $mat : "";

		printf "<input type=radio name=mat_mode_$i value=3 %s> %s\n",
			$smode == 3 ? "checked" : "", $text{'edit_procmat3'};
		printf "<input name=mat3_$i size=8 value='%s'>\n",
			$smode == 3 ? substr($mat, 1) : "";

		print "<tr> <td><b>$text{'edit_procrestart'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=restart_def_$i value=1 %s> %s\n",
			$p->{'_restart'} ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=restart_def_$i value=0 %s>\n",
			$p->{'_restart'} ? "checked" : "";
		printf "<input name=restart_$i size=50 value='%s'></td></tr>\n",
			$p->{'_restart'};

		local $owner = &sname("owner", $p);
		print "<tr> <td><b>$text{'edit_procowner'}</b></td> <td>\n";
		printf "<input type=radio name=owner_def_$i value=1 %s> %s\n",
			$owner ? "" : "checked", "<tt>root</tt>";
		printf "<input type=radio name=owner_def_$i value=0 %s>\n",
			$owner ? "checked" : "";
		printf "<input name=owner_$i size=13 value='%s'></td>\n",
			$owner;

		local $group = &sname("group", $p);
		print "<td><b>$text{'edit_procgroup'}</b></td> <td>\n";
		printf "<input type=radio name=group_def_$i value=1 %s> %s\n",
			$group ? "" : "checked", "<tt>root</tt>";
		printf "<input type=radio name=group_def_$i value=0 %s>\n",
			$group ? "checked" : "";
		printf "<input name=group_$i size=13 value='%s'></td> </tr>\n",
			$group;

		$i++;
		}
	if (!$in{'newproc'} && !$in{'new'}) {
		print "<tr> <td colspan=4 align=right><hr><a href='edit_class.cgi?$in&newproc=1'>$text{'edit_procnew'}</a></td>\n";
		}
	}
elsif ($type eq "shellcommands") {
	# Edit list of executed shell commands
	local @cmds = &parse_directories($cls);
	print "<tr> <td colspan=4><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_cmd'}</b></td> ",
	      "<td><b>$text{'edit_cmdowner'}</b></td> ",
	      "<td><b>$text{'edit_cmdgroup'}</b></td> ",
	      "<td><b>$text{'edit_cmdtimeout'}</b></td> </tr>\n";
	$i = 0;
	foreach $c (@cmds, { }) {
		print "<tr $cb>\n";
		printf "<td><input name=cmd_$i size=40 value='%s'></td>\n",
			$c->{'_dir'};
		printf "<td><input name=owner_$i size=13 value='%s'></td>\n",
			&sname("owner", $c);
		printf "<td><input name=group_$i size=13 value='%s'></td>\n",
			&sname("group", $c);
		printf"<td><input name=timeout_$i size=6 value='%s'> %s</td>\n",
			&sname("timeout", $c), "secs";
		print "</tr>\n";
		$i++;
		}
	print "</table></td> </tr>\n";
	}
elsif ($type eq "tidy") {
	# Allow editing of directories to tidy up
	local @dirs = &parse_directories($cls);
	local $i = 0;
	foreach $d (@dirs, $in{'newtidy'} || $in{'new'} ? ( { } ) : ( ) ) {
		print "<tr> <td colspan=4><hr></td> </tr>\n";

		print "<tr> <td><b>$text{'edit_tidydir'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=dir_def_$i value=1 %s> %s\n",
			$d->{'_dir'} ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=dir_def_$i value=0 %s>\n",
			$d->{'_dir'} ? "checked" : "";
		printf "<input name=dir_$i size=50 value='%s'></td> </tr>\n",
			$d->{'_dir'};

		local $pat = &sname("pattern", $d);
		print "<tr> <td><b>$text{'edit_tidypat'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=pat_def_$i value=1 %s> %s\n",
			$pat ? "" : "checked", $text{'edit_filesall'};
		printf "<input type=radio name=pat_def_$i value=0 %s>\n",
			$pat ? "checked" : "";
		printf "<input name=pat_$i size=50 value='%s'></td> </tr>\n",
			$pat;

		local $size = &sname("size", $d);
		print "<tr> <td><b>$text{'edit_tidysize'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=smode_$i value=0 %s> %s\n",
			$size eq '' ? "checked" : "", $text{'edit_tidysize0'};
		printf "<input type=radio name=smode_$i value=1 %s> %s\n",
			$size eq 'empty' ? "checked" : "",
			$text{'edit_tidysize1'};
		printf "<input type=radio name=smode_$i value=2 %s> %s\n",
			$size eq 'empty' || $size eq '' ? "" : "checked",
			$text{'edit_tidysize2'};
		printf "<input name=size_$i size=6 value='%s'></td> </tr>\n",
			$size eq 'empty' ? "" : $size;

		local $age = &sname("age", $d);
		local $type = &sname("type", $d);
		print "<tr> <td><b>$text{'edit_tidyage'}</b></td>\n";
		print "<td colspan=3>";
		printf "<input type=radio name=age_def_$i value=1 %s> %s\n",
			$age eq '' ? "checked" : "", $text{'edit_tidyage1'};
		printf "<input type=radio name=age_def_$i value=0 %s>\n",
			$age eq '' ? "" : "checked";
		local $asel = "<select name=type_$i>";
		$asel .= sprintf "<option value='' %s>%s</option>\n",
				$type eq 'atime' || !$type ? "selected" : "",
				$text{'edit_tidyatime'};
		$asel .= sprintf "<option value=mtime %s>%s</option>\n",
		    $type eq 'mtime' ? "selected" : "", $text{'edit_tidymtime'};
		$asel .= sprintf "<option value=ctime %s>%s</option>\n",
		    $type eq 'ctime' ? "selected" : "", $text{'edit_tidyctime'};
		$asel .= "</select>\n";
		local $afield = "<input name=age_$i size=5 value='$age'>\n";
		print &text('edit_tidyage0', $asel, $afield),"</td> </tr>\n";

		local $rec = &sname("recurse", $d);
		print "<td><b>$text{'edit_filesrec'}</b></td> <td>\n";
		printf "<input type=radio name=rec_def_$i value=1 %s> %s\n",
			$rec ? "" : "checked", $text{'edit_none'};
		printf "<input type=radio name=rec_def_$i value=2 %s> %s\n",
			$rec eq 'inf' ? "checked" : "",
			$text{'edit_filesinf'};
		printf "<input type=radio name=rec_def_$i value=0 %s>\n",
			$rec && $rec ne 'inf' ? "checked" : "";
		printf "<input name=rec_$i size=6 value='%s'></td> </tr>\n",
			$rec eq 'inf' ? '' : $rec;

		$i++;
		}
	if (!$in{'newtidy'} && !$in{'new'}) {
		print "<tr> <td colspan=4 align=right><hr><a href='edit_class.cgi?$in&newtidy=1'>$text{'edit_tidynew'}</a></td>\n";
		}
	}
elsif ($type eq "miscmounts") {
	# Display filesystems to mount
	local @mnts = &parse_miscmounts($cls);
	print "<tr> <td colspan=4><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_miscsrc'}</b></td> ",
	      "<td><b>$text{'edit_miscdest'}</b></td> ",
	      "<td><b>$text{'edit_miscmode'}</b></td> </tr>\n";
	local $i = 0;
	foreach $m (@mnts, { }) {
		print "<tr $cb>\n";
		printf "<td><input name=src_$i size=30 value='%s'></td>\n",
			$m->{'_src'};
		printf "<td><input name=dest_$i size=30 value='%s'></td>\n",
			$m->{'_dest'};
		printf "<td><input name=mode_$i size=10 value='%s'></td>\n",
			&sname("mode", $m);
		print "</tr>\n";
		$i++;
		}
	print "</table></td></tr>\n";
	}
elsif ($type eq "resolve") {
	# Display nameserver options
	local (@ns, @other);
	for($i=0; $i<@{$cls->{'values'}}; $i++) {
		if ($cls->{'valuequotes'}->[$i]) {
			push(@other, $cls->{'values'}->[$i]);
			}
		else {
			push(@ns, $cls->{'values'}->[$i]);
			}
		}
	print "<tr> <td valign=top><b>$text{'edit_resns'}</b></td>\n";
	print "<td><textarea name=ns rows=4 cols=20>",
		join("\n", @ns),"</textarea></td>\n";

	print "<td valign=top><b>$text{'edit_resother'}</b></td>\n";
	print "<td><textarea name=other rows=4 cols=20>",
		join("\n", @other),"</textarea></td> </tr>\n";
	}
elsif ($type eq "defaultroute") {
	# Display the default route
	printf "<tr> <td><b>$text{'edit_route'}</b></td>\n";
	printf "<td><input name=route size=25 value='%s'></td> </tr>\n",
		$cls->{'values'}->[0];
	}
elsif ($type eq "required" || $type eq "disks") {
	# Display filesystems to check
	local @reqs = &parse_directories($cls);
	print "<tr> <td colspan=4><table border>\n";
	print "<tr $tb> <td><b>$text{'edit_reqfs'}</b></td> ",
	      "<td><b>$text{'edit_reqfree'}</b></td> </tr>\n";
	local $i = 0;
	foreach $r (@reqs, { }) {
		print "<tr $cb>\n";
		printf "<td><input name=fs_$i size=40 value='%s'></td> <td>\n",
			$r->{'_dir'};
		local $free = &sname("freespace", $r);
		printf "<input type=radio name=free_def_$i value=1 %s> %s\n",
			$free eq '' ? "checked" : "", $text{'edit_none'};
		printf "<input type=radio name=free_def_$i value=0 %s>\n",
			$free eq '' ? "" : "checked";
		printf "<input name=free_$i size=10 value='%s'></td>\n", $free;
		print "</tr>\n";
		print "</tr>\n";
		$i++;
		}
	print "</table></td></tr>\n";
	}
else {
	# Allow editing of class manually
	if (!$in{'new'}) {
		$lref = &read_file_lines($cls->{'file'});
		local $st = $cls->{'line'};
		local $en = $cls->{'eline'};
		if ($lref->[$st] =~ /^\s*(\S+)::\s*$/ && $1 eq $cls->{'name'}) {
			$st++;
			}
		print "<tr> <td colspan=4><b>",&text('edit_manualtext2',
				$st, $en, "<tt>$cls->{'file'}</tt>"),"</b>\n";
		print "<br><textarea name=manual rows=15 cols=70>\n";
		for($i=$st; $i<=$en; $i++) {
			print &html_escape($lref->[$i]),"\n";
			}
		print "</textarea></td> </tr>\n";
		}
	else {
		print "<tr> <td colspan=4><b>$text{'edit_manualtext'}</b>\n";
		print "<br><textarea name=manual rows=15 cols=70>\n";
		print "</textarea></td> </tr>\n";
		}
	}

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=middle><input type=submit name=manualmode ",
	      "value='$text{'edit_manual'}'></td>\n" if (!$in{'manual'});
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table>\n";
print "</form>\n";

if ($in{'cfd'}) {
	&ui_print_footer("edit_cfd.cgi", $text{'cfd_return'},
		"", $text{'index_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

# sname(name, &hash)
sub sname
{
local $i;
for($i=length($_[0]); $i>0; $i--) {
	local $s = substr($_[0], 0, $i);
	return $_[1]->{$s} if (defined($_[1]->{$s}));
	}
return undef;
}

