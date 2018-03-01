# spam-amavis-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
use Fcntl;
&init_config();

# get_amavis_config()
# Parse and return the amavisd config file
sub get_amavis_config
{
local(@rv, $line);
open(CONF, $config{'amavisdconf'});
while(<CONF>) {
	s/\r|\n//g;
	if (/^\s*\$(\S+)\s*=\s*"(.*)";/ ||
	    /^\s*\$(\S+)\s*=\s*'(.*)';/) {
		# static config option
		push(@rv, { 'name' => $1,
			    'value' => &perl_unescape($2),
			    'line' => $line,
			    'eline' => $line });
#print "<pre>$line: $1 = $2</pre>";
		}
	elsif (/^\s*\$(\S+)\s*=\s*(.*);/) {
		# computed config option
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'computed' => 1,
			    'line' => $line,
			    'eline' => $line });
#print "<pre>$line: $1 = $2</pre>";
		}
	$line++;
	}
close(CONF);
return \@rv;
}


# save_amavis_directive(&config, name, value, multiline)
# Update some directive in the global config file
sub save_amavis_directive
{
local $old = &findamavis_find($_[1], $_[0]);
return if (!$old);
local $lref = &read_file_lines($config{'majordomo_cf'});
local $olen = $old->{'eline'} - $old->{'line'} + 1;
local $pos = $old->{'line'};
local $v = $_[2];
$v =~ s/\n$//;

	$v =~ s/\@/\\@/g;
	splice(@$lref, $pos, $olen, "\$$_[1] = \"$v\";");
}

# amavis_find(name, &array)
sub amavis_find
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

# amavis_find_value(name, &array)
sub amavis_find_value
{
local(@v);
@v = &findamavis_find($_[0], $_[1]);
@v = grep { !$_->{'computed'} } @v;
if (!@v) { return undef; }
elsif (wantarray) { return map { $_->{'value'} } @v; }
else { return $v[0]->{'value'}; }
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

# amavis_choice_input(name, text, &config, [opt, display]+)
sub amavis_choice_input
{
local $v = &find_value($_[0], $_[2]);
local $rv = "<td><b>$_[1]</b></td> <td nowrap>";
for($i=3; $i<@_; $i+=2) {
	local $ch = $v eq $_[$i] ? "checked" : "";
	$rv .= "<input name=\"$_[0]\" type=\"radio\" value=\"$_[$i]\" $ch> ".$_[$i+1];
	}
$rv .= "</td>\n";
return $rv;
}

# amavis_save_choice(&config, file, name)
sub amavis_save_choice
{
&save_list_directive($_[0], $_[1], $_[2], $in{$_[2]});
}

# amavis_opt_input(name, text, &config, default, size, [units])
sub amavis_opt_input
{
local $v = &find_value($_[0], $_[2]);
local $rv = "<td><b>$_[1]</b></td> <td nowrap ".
	    ($_[4] > 30 ? "colspan=\"3\"" : "").">";
$rv .= sprintf "<input type=\"radio\" name=\"$_[0]_def\" value=\"1\" %s> $_[3]\n",
		$v eq "" ? "checked" : "";
$rv .= sprintf "<input type=\"radio\" name=\"$_[0]_def\" value=\"0\" %s>\n",
		$v eq "" ? "" : "checked";
local $passwd = $_[0] =~ /passwd/ ? "type=\"password\"" : "";
$rv .= "<input $passwd name=\"$_[0]\" size=\"$_[4]\" value=\"$v\"> $_[5]</td>\n";
return $rv;
}

# amavis_save_opt(&config, file, name, [&func])
sub amavis_save_opt
{
if ($in{"$_[2]_def"}) { &save_list_directive($_[0], $_[1], $_[2], ""); }
elsif ($_[3] && ($err = &{$_[3]}($in{$_[2]}))) { &error($err); }
else { &save_list_directive($_[0], $_[1], $_[2], $in{$_[2]}); }
}

# amavis_select_input(name, text, &config, [opt, display]+)
sub amavis_select_input
{
local $v = &find_value($_[0], $_[2]);
local $rv = "<td><b>$_[1]</b></td> <td nowrap><select name=$_[0]>";
for($i=3; $i<@_; $i+=2) {
	local $ch = $v eq $_[$i] ? "selected" : "";
	$rv .= "<option value='$_[$i]' $ch>".$_[$i+1]."</option>";
	}
$rv .= "</select></td>\n";
return $rv;
}

# save_select(&config, file, name)
sub amavis_save_select
{
&save_list_directive($_[0], $_[1], $_[2], $in{$_[2]});
}

# multi_input(name, text, &config)
sub amavis_multi_input
{
local $v = &find_value($_[0], $_[2]);
local $l = 1 + $v =~ tr/\n|\r//;
$l=4  if ($l <= 4);
$l=15 if ($l >= 14);
local $rv = "<td valign=\"top\"><b>$_[1]</b></td> <td colspan=\"3\">".
	    "<textarea rows=\"$l\" cols=\"80\" name=\"$_[0]\">\n$v</textarea></td>\n";
return $rv;
}

# save_multi_global(&config, name)
sub save_amavis_multi_global
{
$in{$_[1]} =~ s/\r//g;
&save_amavis_directive($_[0], $_[1], $in{$_[1]}, 1);
}



# amavis_help()
# returns majordomo help link
sub amavis_help
{
local $rv= &help_search_link("amavisd", "man", "doc", "google");
return $rv;
}

1;

