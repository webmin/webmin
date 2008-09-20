#!/usr/bin/perl
# userpermissions_form.cgi
# Display a the list of users and their permissions
# Author: Mattias Gaertner
#
# Abstract:
#   - Allows editing the user permissions for a directory with an 
#     .ftpaccess file.
#   - It has a select field to easily add a user to the .ftpaccess file.
#   - Shows a list of users with their permissions.
#   - Provides minimum allowed commands (at the moment hardcoded in
#     $MiniumCommands).
#     These commands will applied to any new and changed permissions.
#   - Shows names instead of the hard to remember FTP abbreviations
#     (e.g. PBSZ).
#   - Commands can be combined. For example: RNFR and RNTO are shown 
#     as only one permission.
#   - adds automatically a DenyAll All limit, so the default is to allow
#     nothing.
#   
# ToDos:
#   - multi language support 
#   - a page to config the minimum commands
#   - a page to config the tuples (combined commands)
#   - Probably some functions already exists in webmin and can be replaced

require './proftpd-lib.pl';

&ReadParse();

# read .ftpaccess file
$file = $in{'file'};
$title = &text('ftpindex_header', "<tt>$in{'file'}</tt>");
$return = "ftpaccess_index.cgi";
$rmsg = $text{'ftpindex_return'};

&ui_print_header($title, "Edit User Permissions", "",
	undef, undef, undef, undef, &restart_button());

#########################################
# Navigation parameters
foreach $h ('virt', 'idx', 'file', 'limit', 'anon', 'global') {
    if (defined($in{$h})) {
	$NavigationData.="<input type=hidden name=$h value='$in{$h}'>\n";
	push(@args, "$h=$in{$h}");
    }
}
$args = join('&', @args);


# These are the FTP Commands, that any user have
$MinimumCommands="CWD XCWD CDUP XCUP PORT PASS PASV EPRT EPSV"
  ." PWD XPWD SIZE HELP NOOP AUTH ABORT USER LIST TYPE PROT QUIT PBSZ MDTM MODE";

$Commands{"CWD"}="Change working directory";
$Commands{"XCWD"}=""; 
$Commands{"CDUP"}="";
$Commands{"XCUP"}="";
$Commands{"PORT"}="";
$Commands{"PASV"}="enter passive mode";
$Commands{"EPRT"}="";
$Commands{"EPSV"}="";
$Commands{"RNFR"}="Rename From";
$Commands{"RNTO"}="Rename To";
$Commands{"DELE"}="Delete File";
$Commands{"RMD"}="Remove Directory";
$Commands{"XRMD"}="X Remove Directory";
$Commands{"MKD"}="Create Directory";
$Commands{"XMKD"}="X Create Directory";
$Commands{"MODE"}="";
$Commands{"PWD"}="";
$Commands{"XPWD"}="";
$Commands{"SIZE"}="";
$Commands{"SITE_CHMOD"}="Change Unix File Permissions";
$Commands{"STAT"}="Return Server Status";
$Commands{"SYST"}="Prints System Info";
$Commands{"HELP"}="";
$Commands{"NOOP"}="";
$Commands{"AUTH"}="";
$Commands{"PBSZ"}="";
$Commands{"PROT"}="";
$Commands{"TYPE"}="Set Transfer Type";
$Commands{"MODE"}="Set Transfer Mode";
$Commands{"MDTM"}="List Modification Time";
$Commands{"RETR"}="Retrieve (Read)";
$Commands{"STOR"}="Store (Write)";
$Commands{"STOU"}="Store Unique";
$Commands{"APPE"}="Append";
$Commands{"REST"}="Restart Write";
$Commands{"ABOR"}="Abort";
$Commands{"USER"}="";
$Commands{"PASS"}="";
$Commands{"LIST"}="List remote files";
$Commands{"QUIT"}="";
$Commands{"TupleRMD"} = "Remove Directory";
$Commands{"TupleMKD"} = "Make Directory";
$Commands{"TupleRN"} = "Rename";
$Commands{"TuplePWD"} = "Print Working Directory";

# Not implemented by proftpd:
#$Commands{"STRU"}="Specify File Structure";

# Here you can group commands
$CommandTuples{"TupleRMD"} = "RMD XRMD";
$CommandTuples{"TupleMKD"} = "MKD XMKD";
$CommandTuples{"TupleRN"} = "RNFR RNTO";
$CommandTuples{"TuplePWD"} = "PWD XPWD";

# Create CommandToTuple array
foreach $TupleName(sort keys %CommandTuples){
    foreach $Command(split (" ",$CommandTuples{$TupleName})){
	next unless ($Command);
	$CommandToTuple{$Command}=$TupleName;
    } 
}


#########################################
# Get user list and read old permissions
&GetUsers();
&GetFTPAccessUserPerms($file);

#########################################
# Parse Input and update .ftpaccess file

foreach $ParamName(keys %in){
    #print "Name=\"$ParamName\" Value=\"".$in{$ParamName}."\"<br>\n";
    if($ParamName eq "AddUser"){
	$Username=$in{$ParamName};
	if($Username =~ /^[a-zA-Z0-9_]+$/){
	    &AddUser($Username,$file);
	}
    }
    if($ParamName eq "DeleteUser"){
	$Username=$in{$ParamName};
	if($Username =~ /^[a-zA-Z0-9_]+$/){
	    if($in{"Confirm Delete User"} eq "on"){
		&DeleteUser($Username,$file);
		#print "New used usernames: $UsedUsernames<br>\n";
	    } else {
		print "<H2>To really delete a user, please check the confim checkbox.</H2>\n";
	    }
	}
    }
    if($ParamName eq "ChangePermissions"){
	$Username=$in{$ParamName};
	if($Username =~ /^[a-zA-Z0-9_]+$/){
	    &ChangePermissions($Username,$file);
	}
    }
}


#########################################
# select box and button for add user
print "<form action=userpermissions_form.cgi method=get>\n";
print $NavigationData;
print "<H3>Add an User to the permission table</H3>\n";
print "<select name=\"AddUser\">\n";
foreach $Username (sort split(" ",$Usernames)){
    print "<option value=\"$Username\">$Username</option>\n";
}
print "</select>\n";
print "<input type=submit value=\"Add User\"><br>\n";
print "</form>\n";

#########################################
# Print Permissions

$MaxColumns=4;
foreach $Username(sort split (" ",$UsedUsernames)){
    #print "User: $Username  Allowed=\"".$UserAllowedCommands{$Username}."\" Denied=\"".$UserDeniedCommands{$Username}."\"\n";
    print "<form action=userpermissions_form.cgi method=get>\n";
    print $NavigationData;
    print "<input type=hidden name=\"ChangePermissions\" value=\"".$Username."\">\n";
    print "<HR WIDTH=\"100%\">\n";
    print "<H2>User: $Username</H2>\n";
    print "<table border=1>\n";
    $Column=0;
    $Row=0;
    foreach $Command(sort keys %Commands){
	if($MinimumCommands =~ /$Command/i){
	    # skip minimum permissions, that all users are allowed to
	    next;
	}
	if($CommandToTuple{$Command}){
	    # skip commands that belong to a tuple
	    next;
	}
	$FTPCommands=$Command;
	if($CommandTuples{$FTPCommands}){
	    $FTPCommands = $CommandTuples{$FTPCommands};
	}


	if($Column == 0){
	    if($Row==0){
		print "  <tr>\n";
		for ($i=0; $i<$MaxColumns; $i++){
		    print "    <td>Command</td><td>Allow/Deny/Default</td>\n";
		}
		print "  </tr>\n";
	    }
	    print "  <tr>\n";
	}
	$CommandDesc=$Commands{$Command};
	if(!$CommandDesc){
	    $CommandDesc = $Command;
	}
	print "    <td>$CommandDesc</td><td>\n";
	if(&CommandContains($UserAllowedCommands{$Username},$FTPCommands)){
	    $AllowChecked=" checked";
	} else {
	    $AllowChecked="";
	}
	if(&CommandContains($UserDeniedCommands{$Username},$FTPCommands)){
	    $DenyChecked=" checked";
	} else {
	    $DenyChecked="";
	}
	if($AllowChecked || $DenyChecked){
	    $DefaultChecked = "";
	} else {
	    $DefaultChecked = " checked";
	}
	print "      <input type=\"radio\" name=\"".$Command."\" value=\"allow\"".$AllowChecked.">\n";
	print "      <input type=\"radio\" name=\"".$Command."\" value=\"deny\"".$DenyChecked.">\n";
	print "      <input type=\"radio\" name=\"".$Command."\" value=\"default\"".$DefaultChecked.">\n";
	print "    </td>";
	$Column++;
	if($Column == $MaxColumns){
	    print "  </tr>\n";
	    $Column=0;
	    $Row++;
	}
    }
    if($Column > 0){
	print "  </tr>\n";
    }
    print "</table>\n";
    print "<input type=submit value=\"Change Permissions\">\n";
    print "</form><br>\n";

    print "<form action=userpermissions_form.cgi method=get>\n";
    print $NavigationData;
    print "<input type=hidden name=\"DeleteUser\" value=\"".$Username."\">\n";
    print "<input type=submit value=\"Delete User Permissions\">\n";
    print "<input type=checkbox name=\"Confirm Delete User\">I'm sure<br>\n";
    print "</form>\n";
}


#########################################
# print textarea

print "<HR WIDTH=100%>\n";
print &text('manual_header', "<tt>$file</tt>"),"<p>\n";

print "<form action=manual_save.cgi method=post enctype=multipart/form-data>\n";
print $NavigationData;

print "<br><textarea rows=15 cols=80 name=directives>\n";
$lref = &read_file_lines($file);
if (!defined($start)) {
	$start = 0;
	$end = @$lref - 1;
	}
for($i=$start; $i<=$end; $i++) {
	print &html_escape($lref->[$i]),"\n";
	}
print "</textarea><br><input type=submit value=\"$text{'save'}\"></form>\n";

#########################################
# print footer

&ui_print_footer("$return?$args", $rmsg);

exit;

#########################################################

sub GetUsers(){
    my $UserCount=0;
    setpwent();
    while(my @uinfo = getpwent()) {
	if ($uinfo[2] > 100) {
		$UserCount++;
                $Users[$UserCount]=$uinfo[0];
		$Usernames.=" ".$uinfo[0];
	}
    }
    endpwent();
}

sub GetFTPAccessUserPerms(){
    # Fills global variables:
    # $UsedUsernames, %UserAllowedCommands, %UserDeniedCommands

    my ($FTPAccessFile) = @_;

    ##################################################
    # Read .ftpaccess file
    my $Commands = "";

    open FTPACCESS, "$FTPAccessFile" or &error("Can't open $FTPAccessFile: $!");
    while (my $line=<FTPACCESS>){
        chomp $line;
        #print $line."\n";
        if($line =~ /<Limit (.*)>/i){
            $Commands = $1;
            #print "Limit $Commands\n";
        }
        if($line =~ /<\/Limit(.*)>/i){
            $Commands = "";
            #print "End Limit $Commands\n";
        }
        if($Commands){
            #print "$line\n";
            if($line =~ /AllowUser (.+)/i){
                my $AllowedUsernames = $1;
                #print "AllowUser $AllowedUsernames\n";
                foreach $AllowedUsername (split (" ",$AllowedUsernames)){
                    next unless ($AllowedUsername);
                    $UserAllowedCommands{$AllowedUsername}.=" ".$Commands;
                    #print "AllowUser $AllowedUsername\n";
                }
            }
            if($line =~ /DenyUser (.+)/i){
                my $DeniedUsernames = $1;
                foreach $DeniedUsername (split (" ",$DeniedUsernames)){
                    next unless ($DeniedUsername);
                    $UserDeniedCommands{$DeniedUsername}.=" ".$Commands;
                }
            }
        }
    }
    close FTPACCESS;

    ##################################################
    # collect all mentioned users in table
    $UsedUsernames="";
    foreach $Username(keys %UserAllowedCommands){
        #print "Adding $Username\n";
	$UserAllowedCommands{$Username}=
	    &UnifyAndExpandCommands($UserAllowedCommands{$Username}." ".$Commands);
        if($UsedUsernames !~ /\b$Username\b/){
            $UsedUsernames.=$Username." ";
        }
    }
    foreach $Username(keys %UserDeniedCommands){
	$UserDeniedCommands{$Username}=
	    &UnifyAndExpandCommands($UserDeniedCommands{$Username}." ".$Commands);
        if($UsedUsernames !~ /\b$Username\b/){
            $UsedUsernames.=$Username." ";
        }
    }
}

sub UnifyAndExpandCommands(){
    (my $Commands) = @_;
    my $NewCommands = "";
    foreach $Command(split(" ",$Commands)){
	next unless($Command);
	if($CommandTuples{$Command}){
	    $NewCommands.=" ".$CommandTuples{$Command};
	} else {
	    $NewCommands.=" ".$Command;
	}
    }
    return &UnifyCommands($NewCommands);
}

sub UnifyCommands(){
    (my $Commands) = @_;
    my $NewCommands = "";
    foreach $Command(split(" ",$Commands)){
	next unless($Command);
	next if($NewCommands =~ /\b$Command\b/i);
	if($NewCommands){
	    $NewCommands.=" ";
	}
	$NewCommands.=$Command;
    }
    return $NewCommands;
}

sub AddUser(){
    (my $Username, $FTPAccessFile) = @_;

    if($Usernames =~ /\b$Usernames\b/){
	print "<H2>Username $Username does not exist.</H2>\n";
	return;
    }

    if ($UserAllowedCommands{$Username} || $UserDeniedCommands{$Username}){
	# user already exists
	print "<H2>Username $Username already exists.</H2>\n";
	return;
    }
    $UserAllowedCommands{$Username}=$MinimumCommands;
    $UserDeniedCommands{$Username}="";
    if($UsedUsernames !~ /\b$Username\b/){
	$UsedUsernames.=$Username." ";
    }

    &WritePermissions($FTPAccessFile);
}

sub DeleteUser(){
    (my $Username, $FTPAccessFile) = @_;

    if($UsedUsernames =~ /\b$Usernames\b/){
	print "<H2>Username $Username does not exist in table.</H2>\n";
	return;
    }

    if ((!$UserAllowedCommands{$Username}) && (!$UserDeniedCommands{$Username})){
	# user already deleted
	print "<H2>Username $Username is already not in table.</H2>\n";
	return;
    }
    $UserAllowedCommands{$Username}="";
    $UserDeniedCommands{$Username}="";
    $UsedUsernames =~ s/\b$Username\b *//;

    &WritePermissions($FTPAccessFile);
}

sub ChangePermissions(){
    (my $Username, $FTPAccessFile) = @_;

    if($UsedUsernames =~ /\b$Usernames\b/){
	print "<H2>Username $Username does not exist in table.</H2>\n";
	return;
    }

    foreach $Command(keys %Commands){
	#print "$Command value=".$in{$Command}."<br>\n";

	if($CommandToTuple{$Command}){
	    # skip commands in tuples
	    next;
	}

	my $FTPCommands=$Command;
	if($CommandTuples{$FTPCommands}){
	    $FTPCommands = $CommandTuples{$FTPCommands};
	}

	if ($in{$Command} eq "allow"){
	    $UserAllowedCommands{$Username}.=" ".$FTPCommands;
	    #print "Allow $Username $Command<br>\n";
	} else {
	    $UserAllowedCommands{$Username} =
		&RemoveCommands($UserAllowedCommands{$Username},$FTPCommands);
	}
	if ($in{$Command} eq "deny"){
	    $UserDeniedCommands{$Username}.=" ".$FTPCommands;
	    #print "Deny $Username $Command<br>\n";
	} else {
	    $UserDeniedCommands{$Username} =
		&RemoveCommands($UserDeniedCommands{$Username},$FTPCommands);
	}
    }
    $UserAllowedCommands{$Username}=
	&UnifyCommands($MinimumCommands." ".$UserAllowedCommands{$Username});
    $UserDeniedCommands{$Username}=
	&UnifyCommands($UserDeniedCommands{$Username});

    &WritePermissions($FTPAccessFile);
}

sub WritePermissions(){
    # Read .ftpaccess file, remove all user command permissions
    # and add new set of user permissions
    (my $FTPAccessFile) = @_;
    my $NewConfig = "";
    my $OldCommands = "";
    my $Username;

    # Lock .ftpaccess file
    &lock_file($FTPAccessFile);
    &lock_file($FTPAccessFile);


    # Read old .ftpaccess file
    open FTPACCESS, "$FTPAccessFile" or die "Can't read $FTPAccessFile: $!";
    $DenyAllBlockFound = 0;
    while(my $line = <FTPACCESS>){
	my $ShortLine = $line;
	chomp $ShortLine;
        #print $ShortLine."\n";
        if($ShortLine =~ /<Limit (.*)>/i){
	    # start of Limit block
            $OldCommands = $1;
            #print "Limit $OldCommands\n";
	    $LimitBlock = $line;
	    $ImportantLimitLineFound = 0;
	    $DenyAllFound = 0;
        } elsif($ShortLine =~ /<\/Limit(.*)>/i){
	    # end of Limit block
            #print "End Limit $OldCommands\n";
	    $LimitBlock .= $line;
	    if($ImportantLimitLineFound){
		$NewConfig .= $LimitBlock;
	    }
	    if(($OldCommands =~ /\bALL\b/i) && ($DenyAllFound)){
		# this was a DenyAll for All commands block
		$DenyAllBlockFound = 1;
	    }
            $OldCommands = "";
        } elsif($OldCommands){
            #print "$ShortLine\n";
            if($ShortLine =~ /AllowUser (.*)/i){
		# AllowUser line -> will be replaced, not important
            } elsif($ShortLine =~ /DenyUser (.*)/i){
		# DenyUser line -> will be replaced, not important
            } elsif($ShortLine =~ /^ +$/){
		# empty line -> not important, but keep it for readability
		$LimitBlock .= $line;
	    } else {
		# other limit directive -> important
		$LimitBlock .= $line;
		$ImportantLimitLineFound = 1;
		if($ShortLine =~ /\bDenyAll\b/i){
		    $DenyAllFound = 1;
		}
	    }
        } else {
	    # other directives -> keep
	    $NewConfig .= $line;
	}
    }
    close FTPACCESS;

    # Append new directives

    # Append DenyAll block if not already there
    if(!$DenyAllBlockFound){
	$NewConfig.="<Limit All>\n";
	$NewConfig.="  DenyAll\n";
	$NewConfig.="</Limit>\n";
    }

    # Append Limit blocks for users
    foreach $Username (sort split(" ",$Usernames)){
	my $CurAllow = $UserAllowedCommands{$Username};
	if ($CurAllow){
	    $NewConfig.="<Limit ".$CurAllow.">\n";
	    $NewConfig.="  AllowUser ".$Username."\n";
	    $NewConfig.="</Limit>\n";
	}
	my $CurDeny = $UserDeniedCommands{$Username};
	if ($CurDeny){
	    $NewConfig.="<Limit ".$CurDeny.">\n";
	    $NewConfig.="  DenyUser ".$Username."\n";
	    $NewConfig.="</Limit>\n";
	}
    }
    #print "<br>\n".$NewConfig."<br>\n";

    # Write new .ftpaccess file
    open FTPACCESS, "> $FTPAccessFile" or die "Can't append to $FTPAccessFile: $!";
    print FTPACCESS $NewConfig;
    close FTPACCESS;

    # Unlock .ftpaccess file
    &unlock_file($FTPAccessFile);

    $logtype = 'ftpaccess'; 
    $logname = $in{'file'};
    &webmin_log($logtype, "user permissions", $logname, \%in);
}

sub CommandContains(){
    (my $Commands, my $SubSet) = @_;
    foreach my $Command(split(" ",$SubSet)){
	next unless($Command);
	if($Commands =~ /\b$Command\b/i){
	    return 1;
	}
    }
    return 0;
}

sub RemoveCommands(){
    (my $Commands, my $SubSet) = @_;
    foreach my $Command(split(" ",$SubSet)){
	next unless($Command);
	$Commands =~ s/\b$Command\b *//gi;
    }
    return $Commands;
}

# end.
