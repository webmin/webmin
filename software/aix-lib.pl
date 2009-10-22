# aix-lib.pl
# Functions for aix package management

sub list_package_system_commands
{
return ("lslpp", "geninstall", "installp");
}

# list_packages([package]*)
# Fills the array %packages with a list of all packages
sub list_packages
{
	local($_, $list, $i, $file, %fileset);
	$i = 0;
	$list = join(' ', @_);
	%packages = ( );
	&open_execute_command(LSLPP, "lslpp -L -c $list 2>&1 | grep -v '#'", 1, 1);
	while($file = <LSLPP>) {
                %fileset = &fileset_info($file); 
		if ($fileset{"type"} eq "R") {
                        $packages{$i,'name'} = join("-", $fileset{"package_name"}, $fileset{"level"});
	                $packages{$i,'class'} = $fileset{"package_name"};
	                $packages{$i,'desc'} = $fileset{"description"};
                }
 		else {
	                $packages{$i,'name'} = $fileset{"fileset"};
	                $packages{$i,'class'} = $fileset{"class"};
	                $packages{$i,'desc'} = $fileset{"description"};
	 	}
		$i++;
	}
	close(LSLPP);
	return $i;
}

# package_info(package)
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
	local(@rv, @tmp, $d, $out, $archout, %fileset);

	local $qm = quotemeta($_[0]);
	$out = &backquote_command("lslpp -L -c $qm 2>&1 | grep -v '#'", 1);
	%fileset = &fileset_info($out);
	if ($out =~ /^lslpp:/) {
		&open_execute_command(RPM, "rpm -q $qm --queryformat \"%{NAME}-%{VERSION}\\n%{GROUP}\\n%{ARCH}\\n%{VERSION}\\n%{VENDOR}\\n%{INSTALLTIME}\\n\" 2>/dev/null", 1, 1);
		@tmp = <RPM>;
		chop(@tmp);
		if (!@tmp) { return (); }
		close(RPM);
		&open_execute_command(RPM, "rpm -q $qm --queryformat \"%{DESCRIPTION}\"", 1, 1);
		while(<RPM>) { $d .= $_; }
		close(RPM);
		return ($tmp[0], $tmp[1], $d, $tmp[2], $tmp[3], $tmp[4], &make_date($tmp[5]));
     	}
	else {
		$archout = `uname -s`; 
		push(@rv, $_[0]);
		push(@rv, $fileset{"class"});
		push(@rv, $fileset{"description"});
		push(@rv, $archout);   
		push(@rv, $fileset{"level"});
		push(@rv, $text{'aix_unknown'});
		push(@rv, $text{'aix_unknown'});
		return @rv;
     	}
}

# is_package(file)
# Tests if some file is a valid package file
sub is_package
{
	local($out, $name, $filetype);
	local $qm = quotemeta($_[0]);
	$out = &backquote_command("file $qm 2>&1", 1);
	($name, $filetype) = split(/:/, $out);
	if ($filetype =~ /backup\/restore format file/i) { 
	 	$fileset{"filetype"} = "AIX";
		return 1;	
  	}
        elsif ($filetype =~ /RPM v3 bin PowerPC/i) {
		$fileset{"filetype"} = "RPM";
		return 1;
        }
        else {  return 0; }
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package description
sub file_packages
{
        local($_, $line, $i, $j, $file, $out, $continue, @token, $firstline);
	local(@rv, @output, $description, @vrmf, @field, $k, $l, $stub);
	local $qm = quotemeta($_[0]);
	local $real = &translate_filename($_[0]);
        if (&is_package($_[0])) {
                @token = split(/\//, $_[0]);
                $i = @token;
                $file = $token[$i - 1];
		if ($fileset{"filetype"} eq "RPM") {
			$fileset{"fileset_name"} = "R:$file";
			if (-d $real) {
		       		local @rv;
			        &open_execute_file(RPM, "cd $qm ; rpm -q -p *.rpm --queryformat \"%{NAME}-%{VERSION} %{SUMMARY}\\n\" 2>&1", 1, 1);
			        while(<RPM>) {
			                chop;
		        	        push(@rv, $_) if (!/does not appear|query of.*failed/);
		                }
			        close(RPM);
			        return @rv;
		        }
			else {
			        local($out);
		        	$out = &backquote_command("rpm -q -p $qm --queryformat \"%{NAME}-%{VERSION} %{SUMMARY}\" 2>&1", 1);
			        return ($out);
		        }
		}
		elsif ($fileset{"filetype"} eq "AIX") {
			&open_tempfile(FILE, $_[0]);
			$line = <FILE>;
			$continue = 1;
        	       	while ($continue) {
				if ($line =~ /^\}/) { $continue = 0; }
	                	elsif (($line =~ /lpp_name/) && ($line =~ / \{/)) { 
					$firstline = $line; 
        	       	        	$line = <FILE>;
               			    	$out = $out . $line;
	       	        	}
	                        elsif ($line =~ /^\]/) {
        	       	               	$line = <FILE>;
					if ($line =~ /^\}/) { $continue = 0; }
					else { $out = $out . $line; }
		               	}	
				$line = <FILE>; 
       			}
			close(FILE);
			@field = split(/\s/, $firstline);
			$j = @field;
			for ($i = 0; $i < $j; $i++) {
				if ($field[$i] =~ /\{/) {
					$fileset{"fileset_name"} = $field[$i - 1] =~ /\>|\s+/ ? $file : 
                       	                	                   $field[$i - 1];
				}
			}
			@output = split(/\n/, $out);
		        $j = @output;
			for ($i = 0; $i < $j; $i++) {
				if ($output[$i] !~ /\{|\}|\*/) {
					@field = split(/\s/, $output[$i]);
                                        $out = undef;
                                        $out = "$fileset{fileset_name}  ";
					$description = undef;
					@vrmf = split(/\./, $field[1]);
					$vrmf[0] =~ s/^0+//;
					$vrmf[1] =~ s/^0+//; if ($vrmf[1] == "") { $vrmf[1] = "0"; }
					$vrmf[2] =~ s/^0+//; if ($vrmf[2] == "") { $vrmf[2] = "0"; } 
					$vrmf[3] =~ s/^0+//; if ($vrmf[3] == "") { $vrmf[3] = "0"; }
					if ($vrmf[0] != "") {
						$k = @field;
						for ($l = 6; $l <= $k; $l++) {
							$description = $description . " " . $field[$l];
						}
						$out = $out . "$field[0], $vrmf[0].$vrmf[1].$vrmf[2].$vrmf[3], $description";
					}	
				}
                                push(@rv, $out);
			}
			return @rv;
		}
	}
	else {  return undef; }
}

# install_options(file, package)
# Outputs HTML for choosing install options
sub install_options
{
        local(@token, $command, $i, $j, $file, $directory);
        @token = split(/\//, $_[0]);
        $i = @token;
        for ( $j = 1; $j < $i - 1; $j++) {
                $directory = join("/", $directory, $token[$j]);
        }

	$file = $token[$i-1];

	print "<script language=\"JavaScript\">\n";
	print "   function changeRadio(formName, radiobutton, disable) {\n";
        print "      for( var i=0; i<formName.elements.length; i++) {\n";
        print "         if (formName.elements[i].name == radiobutton) {\n";
        print "            formName.elements[i].checked = disable;\n";
        print "         }\n";
        print "      }\n";
        print "   }\n";
	print "</script>\n";

        print "<tr>\n";
        print "<td>", &hlink("<b>$text{'aix_device'}</b>", "aix_device"), "</td>\n";
        print "<td>$directory</td>\n";
        print "</tr>\n";

        print "<tr>\n";
        print "<td>", &hlink("<b>$text{'aix_software'}</b>", "aix_software"), "</td>\n";
        print "<td>$file</td>\n";
        print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_preview'}</b>", "aix_preview"), "</td>\n";
	print "<td><input type=radio name=preview value=1> $text{'yes'}\n";
	print "<input type=radio name=preview value=0 checked> $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_commit'}</b>", "aix_commit"), "</td>\n";
	print "<td><input type=radio name=commit value=1 checked> $text{'yes'}\n"; 
	print "<input type=radio name=commit value=0 \n";
	print "     onClick=\"changeRadio(this.form, 'save', true)\"> $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_save'}</b>", "aix_save"), "</td>\n";
	print "<td><input type=radio name=save value=1> $text{'yes'}\n";
	print "<input type=radio name=save value=0 checked> $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_auto'}</b>", "aix_auto"), "</td>\n";
	print "<td><input type=radio name=auto value=1 \n";
	print "     onClick=\"changeRadio(this.form, 'overwrite', false)\" checked> $text{'yes'}\n";
	print "<input type=radio name=auto value=0> $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_extend'}</b>", "aix_extend"), "</td>\n";
	print "<td><input type=radio name=extend value=1 checked> $text{'yes'}\n";
	print "<input type=radio name=extend value=0> $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_overwrite'}</b>", "aix_overwrite"), "</td>\n";
	print "<td><input type=radio name=overwrite value=1 \n";
	print "     onClick=\"changeRadio(this.form, 'auto', false)\"> $text{'yes'}\n";
	print "<input type=radio name=overwrite value=0 checked > $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_verify'}</b>", "aix_verify"), "</td>\n";
	print "<td><input type=radio name=verify value=1> $text{'yes'}\n";
	print "<input type=radio name=verify value=0 checked> $text{'no'}</td>\n";
	print "</tr>\n";

#        print "<tr>\n";
#        print "<td>", &hlink("<b>$text{'aix_include'}</b>", "aix_include"), "</td>\n";
#        print "<td><input type=radio name=include value=1> $text{'yes'}\n";
#        print "<input type=radio name=include value=0 checked> $text{'no'}</td>\n";
#        print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_detail'}</b>", "aix_detail"), "</td>\n";
	print "<td><input type=radio name=detail value=1> $text{'yes'}\n";
	print "<input type=radio name=detail value=0 checked> $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_process'}</b>", "aix_process"), "</td>\n";
	print "<td><input type=radio name=process value=1 checked> $text{'yes'}\n";
	print "<input type=radio name=process value=0> $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_accept'}</b>", "aix_accept"), "</td>\n";
	print "<td><input type=radio name=accept value=1> $text{'yes'}\n";
	print "<input type=radio name=accept value=0 checked> $text{'no'}</td>\n";
	print "</tr>\n";

	print "<tr>\n";
	print "<td>", &hlink("<b>$text{'aix_license'}</b>", "aix_license"), "</td>\n";
	print "<td><input type=radio name=license value=1> $text{'yes'}\n";
	print "<input type=radio name=license value=0 checked> $text{'no'}</td>\n";
	print "</tr>\n";

        print "<tr>\n";
        print "<td>", &hlink("<b>$text{'aix_clean'}</b>", "aix_clean"), "</td>\n";
        print "<td><input type=radio name=clean value=1 \n";
	print "     onClick=\"changeRadio(this.form, 'preview', false),\n";
	print "		      changeRadio(this.form, 'commit', false),\n";
	print "               changeRadio(this.form, 'save', false),\n";
	print "               changeRadio(this.form, 'auto', false),\n";
	print "               changeRadio(this.form, 'extend', false),\n";
	print "               changeRadio(this.form, 'overwrite', false),\n";
	print "               changeRadio(this.form, 'verify', false),\n";
#	print "               changeRadio(this.form, 'include', false),\n";
	print "               changeRadio(this.form, 'detail', false),\n";
	print "               changeRadio(this.form, 'process', false),\n";
	print "               changeRadio(this.form, 'accept', false),\n";
	print "               changeRadio(this.form, 'license', false)\"> $text{'yes'}\n";
        print "<input type=radio name=clean value=0\n";
	print "     onClick=\"reset()\" checked> $text{'no'}</td>\n";
        print "</tr>\n";
}

# install_package(file, package)
# Installs the package in the given file, with options from %in
sub install_package
{
	local(@token, $command, $directory, $out);
	@token = split(/\//, $_[0]);
	$i = @token;
	for ( $j = 1; $j < $i - 1; $j++) {
		$directory = join("/", $directory, $token[$j]);
	}

	local $args = ($in{"preview"}   ? "p"  : "")   .
        	      ($in{"commit"}    ? "c"  : "")   .
 	              ($in{"save"}      ? ""   : "N")  .
		      ($in{"auto"}      ? "g"  : "")   .
		      ($in{"extend"}    ? "X"  : "")   .
        	      ($in{"overwrite"} ? "F"  : "")   .
	              ($in{"verify"}    ? "v"  : "")   .
#        	      ($in{"include"}   ? "G"  : "")   .
	              ($in{"detail"}    ? "V2" : "")   .
	              ($in{"process"}   ? ""   : "S")  .
	              ($in{"accept"}    ? "Y"  : "")   .
	              ($in{"license"}   ? "E"  : "");

	$command = "geninstall -I \"-a$args\" -d '$directory' '$fileset{fileset_name}' 2>&1";
	if ($in{"clean"}) {
		$args = "-C";
		$command = "installp $args 2>&1";
	}

	local $out = &backquote_logged($command);
        	if (($?) || ($in{"preview"}) || ($in{"clean"})) { 
        		return "<pre>$command<br>$out</pre>";
        }
	return undef;
}

# check_files(package)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are path type user group mode size error link
sub check_files
{
	local($_, $list, $i, $_, @w, %errs, %myfile, $epath, $path, $fileset, $file);
	local $qm = quotemeta($_[0]);
	$i = 0;
	$list = join(' ', @_);
	&open_execute_command(LSLPP, "lslpp -f -c $qm 2>&1 | grep -v '#'", 1, 1);
	$out = <LSLPP>;
	if ($out =~ /lslpp:/) { 
		&open_execute_command(RPM, "rpm -V $qm", 1, 1);
		while(<RPM>) {
       			/^(.{8}) (.) (.*)$/;
	        	if ($1 eq "missing ") { $errs{$3} = "Missing"; }
        		else {
                		$epath = $3;
	                	@w = grep { $_ ne "." } split(//, $1);
        	        	$errs{$epath} =
                	        	join("\n", map { "Failed $etype{$_} check" } @w);
	             	}
        	}
		close(RPM);
		&open_execute_command(RPM, "rpm -q $qm -l --dump", 1, 1);
		while(<RPM>) {
        		chop;
                	if ($_ =~ /(contains no files)/) { return $i; }
	        	@w = split(/ /);
       			$files{$i,'path'} = $w[0];
        		if ($w[10] ne "X") { $files{$i,'link'} = $w[10]; }
        		$files{$i,'type'} = $w[10] ne "X" ? 3 :
					    (-d &translate_filename($w[0]))? 1 :
	                	            $w[7]         ? 5 : 0;
	        	$files{$i,'user'} = $w[5];
        		$files{$i,'group'} = $w[6];
        		$files{$i,'size'} = $w[1];
	       		$files{$i,'error'} = $w[7]        ? "" : $errs{$w[0]};
        		$i++;
       		}
		close(RPM);
	}
	else {
		while($fileinfo = <LSLPP>) {
			chop($fileinfo);
			#Path:Fileset:File
			($path, $fileset, $file) = split(/:/, $fileinfo);
			%myfile = &file_info($file);
                	$files{$i,'path'}  = $myfile{"path"};
	                $files{$i,'type'}  = $myfile{"type"}; 
	                $files{$i,'user'}  = $myfile{"uid"}; 
        	        $files{$i,'group'} = $myfile{"gid"};
                	$files{$i,'mode'}  = $myfile{"mode"}; 
	                $files{$i,'size'}  = $myfile{"size"}; 
			$files{$i,'link'}  = $myfile{"link"};
	                $files{$i,'error'} = $myfile{"err"};
	                $i++;
	        }
	}
	close(LSLPP);
	return $i;
}

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
# Usable values in %file are  path type user group mode size packages
sub installed_file
{
	local(%myfile);
	local $qm = quotemeta($_[0]);
	$out = &backquote_command("lslpp -wc $qm 2>&1 | grep -v '#'", 1);
	if ($?) {
		local($pkg, @w, $_);
		undef(%file);
		$pkg = &backquote_command("rpm -q -f $qm --queryformat \"%{NAME}-%{VERSION}\\n\" 2>&1", 1);

		if ($pkg =~ /not owned/ || $?) { return 0; }
		@pkgs = split(/\n/, $pkg);
		&open_execute_command(RPM, "rpm -q $pkgs[0] -l --dump", 1);
		while(<RPM>) {
		        chop;
	        	@w = split(/ /);
	        	if ($w[0] eq $_[0]) {
	                	$file{'packages'} = join(' ', @pkgs);
        	        	$file{'path'} = $w[0];
                		if ($w[10] ne "X") { $files{$i,'link'} = $w[10]; }
             			$file{'type'} = $w[10] ne "X" ? 3 :
					(-d &translate_filename($w[0])) ? 1 :
                                		$w[7]         ? 5 : 0;
                		$file{'user'} = $w[5];
                		$file{'group'}= $w[6];
                		$file{'mode'} = substr($w[4], -4);
                		$file{'size'} = $w[1];
                		last;
                	}
        	}
		close(RPM);
	}
	else {
		%myfile = &file_info($_[0]);
		$file{'path'}     = $myfile{"path"};
		$file{'type'}     = $myfile{"type"};
		$file{'user'}     = $myfile{"uid"};
		$file{'group'}    = $myfile{"gid"};
		$file{'mode'}     = $myfile{"mode"};
		$file{'size'}     = $myfile{"size"};
		$file{'link'}     = $myfile{"link"};
		$file{'packages'} = $myfile{"package"};
	}
	return 1;
}

# delete_package(package)
# Totally remove some package
sub delete_package
{
        local(%fileset, $file, $out, $rv);
	local $temp = &transname();
	local $qm = quotemeta($_[0]);

	$file = &backquote_command("lslpp -L -c $qm 2>&1 | grep -v '#'", 1);
	%fileset = &fileset_info($file);

	$rv = &system_logged("geninstall -u $_[0] >$temp 2>&1");
	local $out = &backquote_command("cat $temp");
	&unlink_file($temp);
	
	if ($rv) { return "<pre>$out</pre>"; }
	return undef; 
}

sub fileset_info
{
	local($_, $out, %fileset, $package_name, $fileset, $level, $state, $ptf_id, 
	      $fix_state, $type, $description, $destination_dir, $uninstaller, 
	      $msg_cat, $msg_set, $msg_num, $parent, $class);
	%fileset = ();
	($package_name, $fileset, $level, $state, $ptf_id, $fix_state,
	 $type, $description, $destination_dir, $uninstaller, $msg_cat,
	 $msg_set, $msg_num, $parent) = split(/:/, $_[0]);
	($class, $stub)             = split(/\./, $package_name);
	$fileset{"class"}           = $class;
	$fileset{"package_name"}    = $package_name;
	$fileset{"fileset"}         = $fileset;
	$fileset{"level"}           = $level;
	$fileset{"state"}           = $state;
	$fileset{"ptf_id"}          = $ptf_id;
	$fileset{"fix_state"}       = $fix_state;
	$fileset{"type"}            = $type;
	$fileset{"description"}     = $description;
	$fileset{"destination_dir"} = $destination_dir;
	$fileset{"uninstaller"}     = $uninstaller;
	$fileset{"msg_cat"}         = $msg_cat;
        $fileset{"msg_set"}         = $msg_set;
	$fileset{"msg_num"}         = $msg_num;
	$fileset{"parent"}          = $parent;
	return(%fileset);
}

sub file_info
{
	local($_, %file, @out, $filename, $fileset, $type,  
	      $dev, $ino, $mode, $nlink, $uid, $gid, @args, $rdev,
	      $size, $atime, $mtime, $ctime, $blksize, $blocks);
  	%file = ();	
	local $real;
	
        if ($_[0] =~ /->/) {
		($filename, $symlink) = split(/->/, $_[0]);
		$real = &translate_filename($filename);
		chop($filename);
                ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
                 $atime, $mtime, $ctime, $blksize, $blocks) = lstat($real);
	}
	else {
		$filename = $_[0];
		$real = &translate_filename($filename);
                ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
                 $atime, $mtime, $ctime, $blksize, $blocks) = stat($real);
	}
	
	local $qm = quotemeta($filename);
	@out = &backquote_command("lslpp -wc $qm 2>&1", 1);
	($stub, $fileset, $type) = split(/:/, $out[1]);

        $file{"path"}    = $filename;	
	$file{"dev"}     = sprintf "%d,%d", $dev/256, $dev%256;
	$file{"ino"}     = $ino;
	$file{"mode"}    = sprintf "%o", $mode & 07777;
	$file{"nlink"}   = $nlink;
	$file{"uid"}     = getpwuid($uid);
	$file{"gid"}     = getgrgid($gid);
	$file{"rdev"}    = readlink($rdev);
	$file{"size"}    = $size        ? $size : 0;
	$file{"atime"}   = scalar(localtime($atime));
	$file{"mtime"}   = scalar(localtime($mtime));
	$file{"ctime"}   = scalar(localtime($ctime));
	$file{"blksize"} = $blksize;
	$file{"blocks"}  = $blocks;
	$file{"link"}    = readlink($real);
	$file{"package"} = $fileset;
	$file{"err"}     = -e $real  ? 0 : "Error";
	$file{"type"}    = -l $real ? 3 :
                           -d $real ? 1 :
			   0;
	return(%file);
}

sub package_system
{
	return $text{'aix_manager'}; 
}

sub package_help
{
        return "installp lslpp";
}

1;

