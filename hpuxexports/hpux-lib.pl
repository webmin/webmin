# hpux-lib.pl
# Functions for HPUX exports files

# list_exports()
# Return a list of all the directories currently being exported
sub list_exports
{
local (@rv, $pos, $lnum, $h, $o, $line);
return @list_exports_cache if (@list_exports_cache);
open(EXP, $config{'exports_file'});
$lnum = 0;
while($line = <EXP>) {
        local $slnum = $lnum;
        $line =~ s/\s+$//g;
        while($line =~ /\\$/) {
                # continuation character!
                $line =~ s/\\$//;
                $line .= <EXP>;
                $line =~ s/\s+$//g;
                $lnum++;
                }
        if ($line =~ /^(#*)\s*(\/\S*)\s+-(.*)$/) {
                local %exp;
                $exp{'active'} = !$1;
                $exp{'dir'} = $2;
		# 'host' includes the hole option string!
		# for describe_host needed, only
                $exp{'host'} = $3;
		parse_options($3, $exp{'options'});
                $exp{'line'} = $slnum;
                $exp{'eline'} = $lnum;
		$exp{'pos'} = $pos++;
                $exp{'index'} = scalar(@rv);
                push(@rv, \%exp);
                }
        $lnum++;
        }
close(EXP);
@list_exports_cache = @rv;
return @list_exports_cache;
}


# make_exports_line([&export]+)
sub make_exports_line
{
local ($options, $line);
$options = join_options($_[0]->{'options'});
$line = ($_[0]->{'active'} ? "" : "#").$_[0]->{'dir'};
$line .= ($options ? " -".$options : "");
return $line;
}


# describe_host(host)
# Given a host option string return a human-readable version
sub describe_host
{
local ($desc, %options);
&parse_options($_[0], \%options);
if (defined($options{"ro"}) && $options{"access"} ne "") {
	$desc = $text{'index_sel_ro'};
	}
elsif (defined($options{"ro"}) && !defined($options{"access"})) {
	$desc = $text{'index_all_ro'};
	}
elsif ($options{"rw"} ne "") {
	$desc = $text{'index_ro_rw'};
	}
elsif (!defined($options{"ro"}) && $options{"access"} ne "") {
	$desc = $text{'index_sel_rw'};
	}
elsif (!defined($options{"ro"}) && !defined($options{"rw"}) && !defined($options{"access"})) {
	$desc = $text{'index_all_rw'};
	}
if ($options{"root"} ne "") {
	$desc .= ", ";
	$desc .= $text{'index_sel_root'};
	}
return $desc;
}

# more_detail_fields()
sub more_detail_fields
{
print " <td><b>", &hlink($text{'edit_async'}, "async"), "</b></td>\n";
printf "<td nowrap><input type=radio name=async value=1 %s> %s\n",
        defined($opts{"async"}) ? "checked" : "", $text{'yes'};
printf "<input type=radio name=nfs_bg value=0 %s> %s</td> </tr>\n",
        defined($opts{"async"}) ? "" : "checked", $text{'no'};
}

# security_fields()
sub security_fields
{
print "<tr $cb>\n";
print " <td><b>", &hlink($text{'edit_user_access'}, "user_access"), "</b></td>\n";
print " <td><b>", &hlink($text{'edit_root_access'}, "root_access"), "</b></td>\n";
print " <td><b>", &hlink($text{'edit_anon_access'}, "anon"), "</b></td>\n";
print "</tr>\n";

$fn = "<font size=-1>"; $efn = "</font>";
print "<tr $cb>\n";
printf " <td><input type=radio name=user value=1 %s> $text{'edit_sel_ro'}<br>\n",
        defined($opts{"ro"}) && $opts{"access"} ne "" ? "checked" : "";
printf "<input type=radio name=user value=2 %s> $text{'edit_all_ro'}<br>\n",
        defined($opts{"ro"}) && !defined($opts{"access"}) ? "checked" : "";
printf "<input type=radio name=user value=3 %s> $text{'edit_ro_rw'}<br>\n",
        $opts{"rw"} ne "" ? "checked" : "";
printf "<input type=radio name=user value=4 %s> $text{'edit_sel_rw'}<br>\n",
        !defined($opts{"ro"}) && $opts{"access"} ne "" ? "checked" : "";
printf "<input type=radio name=user value=5 %s> $text{'edit_all_rw'}<br>\n",
        !defined($opts{"ro"}) && !defined($opts{"rw"}) && !defined($opts{"access"}) ? "checked" : "";
print " </td>\n";
printf " <td><input type=radio name=root value=1 %s> $text{'edit_none'}<br>\n",
        defined($opts{"root"}) ? "" : "checked";
print "<br>";
print "<br>";
print "<br>";
printf "<input type=radio name=root value=2 %s> $text{'edit_sel_hosts'}<br>\n",
        $opts{"root"} ne "" ? "checked" : "";
print " </td>\n";
print " <td>\n";
if ($in{'new'}) { $opts{"anon"} = getpwnam("nobody"); }
printf "<input type=radio name=anon value=1 %s> $text{'edit_anon_noaccess'}<br>\n",
	$opts{"anon"} == -1 ? "checked" : "";
if (defined($opts{"anon"}) && $opts{"anon"} != -1) {
	$anonuser = getpwuid($opts{'anon'}) ?
		getpwuid($opts{'anon'}) : $opts{'anon'};
	}
printf "<input type=radio name=anon value=2 %s>\n",
	$opts{"anon"} != -1 ? "checked" : "";
print "<input name=anonnam size=8 value=\"$anonuser\"> ",
	&user_chooser_button("anonnam", 0),"\n";   
print "<br>";
print "<br>";
print "<br>";
print "<br>";
print " </td>\n";
print "</tr>\n";

print "<tr $cb>\n";
print " <td>$fn<textarea name=ualist rows=6 cols=40 >";
        if ($opts{"rw"} ne "") {
                $list = join("\n", split(/:/, $opts{"rw"}));
                }
        if ($opts{"access"} ne "") {
                $list = join("\n", split(/:/, $opts{"access"}));
                }
        print $list;
print "</textarea>$efn</td>\n";
printf " <td>$fn<textarea name=rtlist rows=6 cols=40 >%s</textarea>$efn</td>\n",
        join("\n", split(/:/, $opts{"root"}));
print "</tr>\n";
}

# check_inputs()
sub check_inputs
{
if ($in{user} == 1 || $in{user} == 3 || $in{user} == 4) {
	&check_hosts($text{'edit_user_access'}, $in{ualist});
        @ualist = split(/\s+/, $in{ualist});
        }
if ($in{root} == 2) {
	&check_hosts($text{'edit_root_access'}, $in{rtlist});
	@rtlist = split(/\s+/, $in{rtlist});
        }

# Remove from the root list any hosts which not in the user list as well
if (($in{user} == 1 || $in{user} == 3 || $in{user} == 4) && $in{root} == 2) {
        @tmplist = @rtlist;
        foreach $rth (@tmplist) {
                if (($idx = &indexof($rth, @ualist)) == -1) {
                        splice(@rtlist, &indexof($rth, @rtlist), 1);
                        }
                }
        if (@rtlist == 0) {
                $in{root} = 1;
                }
        }
}


# set_options()
# Fill in the options associative array
sub set_options
{
delete($opts{"ro"});
delete($opts{"rw"});
delete($opts{"access"});
if ($in{user} == 1) { $opts{"ro"} = ""; $opts{"access"} = join(':', @ualist); }
elsif ($in{user} == 2) { $opts{"ro"} = ""; }
elsif ($in{user} == 3) { $opts{"rw"} = join(':', @ualist); }
elsif ($in{user} == 4) { $opts{"access"} = join(':', @ualist); }
elsif ($in{user} == 5) { ; }

if ($in{root} == 1) { delete($opts{"root"}); }
elsif ($in{root} == 2) { $opts{"root"} = join(':', @rtlist); }

if ($in{async} == 1) { $opts{"async"} = ""; }
else { delete($opts{"async"}); }

if ($in{'anon'} == 1) { $opts{"anon"} = -1; }
elsif ($in{'anonnam'} =~ /^[0-9\-]+$/)
	{ $opts{"anon"} = $in{"anonnam"}; }
elsif (getpwnam($in{"anonnam"})) 
	{ $opts{"anon"} = getpwnam($in{"anonnam"}); }
else { $opts{"anon"} = -1; }
}

1;

