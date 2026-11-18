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
open(CONF, "<".$config{'amavisdconf'});
while(<CONF>) {
	s/\r|\n//g;
	if (/^\s*#|^\s*$/) { $line++; next; }
	if (/^\s*\$(\S+)\s*=\s*"(.*)";/ ||
	    /^\s*\$(\S+)\s*=\s*'(.*)';/) {
		# STRING config option
		push(@rv, { 'name' => $1,
			    'value' => &perl_unescape($2),
			    'line' => $line,
			    'eline' => $line });
		}
	elsif (/^\s*\$(\S+)\s*=\s*(.*);/) {
		# VALUE or computed config option
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'computed' => 1,
			    'line' => $line,
			    'eline' => $line });
		}
	# ignore multiline options for now ....
	$line++;
	}
close(CONF);
return \@rv;
}

# check_amavis_value(value, [numeric])
# Returns 1 if a value can be saved in the Perl config file. Every value must
# be a single line. Numeric values must be undef or a simple arithmetic
# expression, because they are written without quotes.
sub check_amavis_value
{
my ($v, $numeric) = @_;
return 0 if ($v =~ /[\r\n\0]/);
return 1 if (!$numeric);
my $number = qr/[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)/;
return $v eq "undef" ||
       $v =~ m{\A[ \t]*$number(?:[ \t]*(?:\*\*|[+*/-])[ \t]*$number)*[ \t]*\z};
}

# amavis_quote_value(value)
# Returns a value as a double-quoted Perl string, with characters that Perl
# would interpolate escaped
sub amavis_quote_value
{
my ($v) = @_;
$v =~ s/([\\\"\$\@])/\\$1/g;
return "\"$v\"";
}

# save_amavis_directive(&config, name, value, multiline)
# Update some directive in the global config file
sub save_amavis_directive
{
local ($c,$n,$v,$m) = @_;
local $old = &amavis_find($n, $c);
# Leave an unchanged Perl expression exactly as the administrator wrote it.
return if ($old && $old->{'value'} eq $v);
local $lref = &read_file_lines($config{'amavisdconf'});
$v =~ s/\n$//;
&check_amavis_value($v) || &error($text{'amavis_eline'});
if (!$old) {
    pop(@$lref);
    push(@$lref, "# new config added by webmin");
    if (&check_amavis_value($v, 1)) {
	push(@$lref, "\$$n = $v;");
    } else {
	push(@$lref, "\$$n = ".&amavis_quote_value($v).";");
    }
    push(@$lref, "1;");
    return;
}

local $olen = $old->{'eline'} - $old->{'line'} + 1;
local $pos = $old->{'line'};

	# Only safe numeric values are written without quotes
	if ($old->{'computed'} && $v ne "*" && &check_amavis_value($v, 1)) {
		splice(@$lref, $pos, $olen, "\$$n = $v; # modified by webmin");
	} else {
		splice(@$lref, $pos, $olen, "\$$n = ".
			&amavis_quote_value($v)."; # modified by webmin");
	}
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
@v = &amavis_find($_[0], $_[1]);
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
	local $val = &amavis_find_value($1, $_[1]);
	$str =~ s/\$([A-z0-9\_]+)/$val/;
	}
return $str;
}

1;

