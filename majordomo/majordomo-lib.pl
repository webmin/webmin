# majordomo-lib.pl
# Common majordomo functions

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

%MAJOR_ENV = ( 'HOME', $config{'program_dir'} );

# get_config()
# Parse and return the majordomo config file
sub get_config
{
local(@rv, $line);
open(CONF, $config{'majordomo_cf'});
while(<CONF>) {
	s/\r|\n//g;
	if (/^\s*\$(\S+)\s*=\s*"(.*)";\s*$/ ||
	    /^\s*\$(\S+)\s*=\s*'(.*)';\s*$/) {
		# static config option
		push(@rv, { 'name' => $1,
			    'value' => &perl_unescape($2),
			    'line' => $line,
			    'eline' => $line });
		}
	elsif (/^\s*\$(\S+)\s*=\s*<<\s*'(\S+)';\s*$/) {
		# multiline config option
		local $o = { 'name' => $1,
			     'line' => $2 };
		local $end = $3;
		while(<CONF>) {
			$line++;
			last if ($_ =~ /^$end[\r\n]+$/);
			$o->{'value'} .= $_;
			}
		$o->{'eline'} = $line;
		push(@rv, $o);
		}
#	elsif (/^\s*\$(\S+)\s*=\s*\$ENV\{['"]([^'"]+)['"]\};\s*$/) {
#		# from majordomo environment variable
#		push(@rv, { 'name' => $1,
#			    'value' => $MAJOR_ENV{$2},
#			    'line' => $line,
#			    'eline' => $line });
#		}
	elsif (/^\s*\$(\S+)\s*=\s*(.*);\s*$/) {
		# computed config option
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'computed' => 1,
			    'line' => $line,
			    'eline' => $line });
		}
	$line++;
	}
close(CONF);
return \@rv;
}

# save_directive(&config, name, value)
# Update some directive in the global config file
sub save_directive
{
local $old = &find($_[1], $_[0]);
return if (!$old);
local $lref = &read_file_lines($config{'majordomo_cf'});
local $olen = $old->{'eline'} - $old->{'line'} + 1;
local $v = $_[2];
$v =~ s/\n$//;
if ($v =~ /\n/) {
	splice(@$lref, $old->{'line'}, $olen,
	       ( "\$$_[1] = <<'END';", split(/\n/, $v, -1), "END" ));
	}
else {
	$v =~ s/\@/\\@/g;
	splice(@$lref, $old->{'line'}, $olen, "\$$_[1] = \"$v\";");
	}
}

# find(name, &array)
sub find
{
local($c, @rv);
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	}
return @rv ? wantarray ? @rv : $rv[0]
           : wantarray ? () : undef;
}

# find_value(name, &array)
sub find_value
{
local(@v);
@v = &find($_[0], $_[1]);
@v = grep { !$_->{'computed'} } @v;
if (!@v) { return undef; }
elsif (wantarray) { return map { $_->{'value'} } @v; }
else { return $v[0]->{'value'}; }
}

# list_lists(&config)
# Returns a list of mailing list names
sub list_lists
{
local ($l, @rv);
local $ldir = &perl_var_replace(&find_value("listdir", $_[0]), $_[0]);
opendir(DIR, $ldir);
while($l = readdir(DIR)) {
	if ($l =~ /^(\S+)\.config$/ && $1 !~ /\.old$/) {
		push(@rv, $1);
		}
	}
closedir(DIR);
return @rv;
}
	
# get_list(name, &config)
# Returns the details of some list
sub get_list
{
local $ldir = &perl_var_replace(&find_value("listdir", $_[1]), $_[1]);
local %list;
return undef if (!-r "$ldir/$_[0].config");
$list{'name'} = $_[0];
$list{'members'} = "$ldir/$_[0]";
$list{'config'} = "$ldir/$_[0].config";
$list{'info'} = "$ldir/$_[0].info";
$list{'intro'} = "$ldir/$_[0].intro";
return \%list;
}

# get_list_config(file)
sub get_list_config
{
local(@rv, $line);
$lnum = 0;
open(CONF, $_[0]);
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/^\s*(\S+)\s*=\s*(.*)$/) {
		# single value
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'index' => scalar(@rv),
			    'line' => $lnum,
			    'eline' => $lnum });
		}
	elsif (/^\s*(\S+)\s*<<\s*(\S+)/) {
		# multi-line value
		local $c = { 'name' => $1,
			     'index' => scalar(@rv),
			     'line' => $lnum };
		local $end = $2;
		while(<CONF>) {
			$lnum++;
			last if (/^$end[\r\n]+$/);
			s/^--/-/;
			s/^-\n/\n/;
			$c->{'value'} .= $_;
			}
		$c->{'eline'} = $lnum;
		push(@rv, $c);
		}
	$lnum++;
	}
return \@rv;
}

# save_list_directive(&config, file, name, value, multiline)
sub save_list_directive
{
local $old = &find($_[2], $_[0]);
local $lref = &read_file_lines($_[1]);
local ($pos, $olen, $nlen);
if ($old) {
	$olen = $old->{'eline'} - $old->{'line'} + 1;
	$pos = $old->{'line'};
	}
else {
	$olen = 0;
	$pos = @$lref;
	}
if ($_[4]) {
	local $ov = $old->{'value'};
	$ov =~ s/\n$//;
	local $v = $_[3];
	$v =~ s/\n$//;
	local @lines = split(/\n/, $v, -1);
	@lines = map { s/^-/--/; s/^$/-/; $_ } @lines;
	splice(@$lref, $pos, $olen, ("$_[2]        <<   END", @lines, "END"))
		if (!$old || $v ne $ov);
	$nlen = (!$old || $v ne $ov) ? @lines + 2 : $olen;
	}
else {
	splice(@$lref, $pos, $olen, "$_[2] = $_[3]")
		if (!$old || $_[3] ne $old->{'value'});
	$nlen = 1;
	}
if ($old && $nlen != $olen) {
	foreach $c (@{$_[0]}) {
		if ($c->{'line'} > $old->{'eline'}) {
			$c->{'line'} += ($nlen - $olen);
			$c->{'eline'} += ($nlen - $olen);
			}
		}
	}
}

# get_aliases_file()
# Returns the paths to the sendmail-style aliases files
sub get_aliases_file
{
if ($config{'aliases_file'} eq 'postfix') {
	# Get from Postfix config
	&foreign_require("postfix", "postfix-lib.pl");
	local @afiles = &postfix::get_aliases_files(
				&postfix::get_current_value("alias_maps"));
	$aliases_module = "postfix";
	return \@afiles;
	}
else {
	&foreign_require("sendmail", "sendmail-lib.pl");
	&foreign_require("sendmail", "aliases-lib.pl");
	$aliases_module = "sendmail";
	if ($config{'aliases_file'} eq '') {
		# Get from Sendmail
		local $sm_conf = &sendmail::get_sendmailcf();
		return &sendmail::aliases_file($sm_conf);
		}
	else {
		# Use fixed file
		return [ $config{'aliases_file'} ];
		}
	}
}

# perl_unescape(string)
# Converts a string like "hello\@there\\foo" to "hello@there\foo"
sub perl_unescape
{
local $v = $_[0];
$v =~ s/\\(.)/$1/g;
return $v;
}

# perl_var_replace(string, &config)
# Replaces variables like $foo in a string with their value from
# the config file
sub perl_var_replace
{
local $str = $_[0];
local %donevar;
while($str =~ /\$([A-z0-9\_]+)/ && !$donevar{$1}) {
	$donevar{$1}++;
	local $val = &find_value($1, $_[1]);
	$str =~ s/\$([A-z0-9\_]+)/$val/;
	}
return $str;
}

# set_permissions(file)
# Sets the ownership and permissions on some file or directory,
# based on the ownership of the lists directory
sub set_permissions
{
local $conf = &get_config();
local $ldir = &perl_var_replace(&find_value("listdir", $conf), $conf);
local @ldir = stat($ldir);
chown($ldir[4], $ldir[5], $_[0]);
if ($config{'perms'}) {
	chmod(-d $_[0] ? 0755 : 0644, $_[0]);
	}
else {
	chmod(-d $_[0] ? 0775 : 0664, $_[0]);
	}
}

# choice_input(name, text, &config, [opt, display]+)
sub choice_input
{
local $v = &find_value($_[0], $_[2]);
local $rv = "<td><b>$_[1]</b></td> <td nowrap>";
for($i=3; $i<@_; $i+=2) {
	local $ch = $v eq $_[$i] ? "checked" : "";
	$rv .= "<input name=$_[0] type=radio value='$_[$i]' $ch> ".$_[$i+1];
	}
$rv .= "</td>\n";
return $rv;
}

# save_choice(&config, file, name)
sub save_choice
{
&save_list_directive($_[0], $_[1], $_[2], $in{$_[2]});
}

# opt_input(name, text, &config, default, size, [units])
sub opt_input
{
local $v = &find_value($_[0], $_[2]);
local $rv = "<td><b>$_[1]</b></td> <td nowrap ".
	    ($_[4] > 30 ? "colspan=3" : "").">";
$rv .= sprintf "<input type=radio name=$_[0]_def value=1 %s> $_[3]\n",
		$v eq "" ? "checked" : "";
$rv .= sprintf "<input type=radio name=$_[0]_def value=0 %s>\n",
		$v eq "" ? "" : "checked";
local $passwd = $_[0] =~ /passwd/ ? "type=password" : "";
$rv .= "<input $passwd name=$_[0] size=$_[4] value=\"$v\"> $_[5]</td>\n";
return $rv;
}

# save_opt(&config, file, name, [&func])
sub save_opt
{
if ($in{"$_[2]_def"}) { &save_list_directive($_[0], $_[1], $_[2], ""); }
elsif ($_[3] && ($err = &{$_[3]}($in{$_[2]}))) { &error($err); }
else { &save_list_directive($_[0], $_[1], $_[2], $in{$_[2]}); }
}

# select_input(name, text, &config, [opt, display]+)
sub select_input
{
local $v = &find_value($_[0], $_[2]);
local $rv = "<td><b>$_[1]</b></td> <td nowrap><select name=$_[0]>";
for($i=3; $i<@_; $i+=2) {
	local $ch = $v eq $_[$i] ? "selected" : "";
	$rv .= "<option value='$_[$i]' $ch> ".$_[$i+1];
	}
$rv .= "</select></td>\n";
return $rv;
}

# save_select(&config, file, name)
sub save_select
{
&save_list_directive($_[0], $_[1], $_[2], $in{$_[2]});
}

# multi_input(name, text, &config)
sub multi_input
{
local $v = &find_value($_[0], $_[2]);
local $rv = "<td valign=top><b>$_[1]</b></td> <td colspan=3>".
	    "<textarea rows=4 cols=80 name=$_[0]>\n$v</textarea></td>\n";
return $rv;
}

# save_multi(&config, file, name)
sub save_multi
{
$in{$_[2]} =~ s/\r//g;
&save_list_directive($_[0], $_[1], $_[2], $in{$_[2]}, 1);
}

# can_edit_list(&access, name)
sub can_edit_list
{
foreach (split(/\s+/, $_[0]->{'lists'})) {
	return 1 if ($_ eq "*" || $_ eq $_[1]);
	}
return 0;
}

# homedir_valid(&config)
sub homedir_valid
{
local $homedir = &find_value("homedir", $_[0]);
if (!-d $homedir) {
	local $homeused;
	foreach $c (@$conf) {
		$homeused++ if ($c->{'value'} =~ /\$homedir/);
		}
	if ($homeused) {
		return 0;
		}
	}
return 1;
}

1;

