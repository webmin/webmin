# bsdexports-lib.pl
# Functions for managing the FreeBSD exports file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# check_exports()
# Returns an error message if the NFS exports package is missing
sub check_exports
{
if ($gconfig{'os_type'} eq 'freebsd') {
	# Check for commands on FreeBSD
	foreach my $c ("mountd", "nfsd") {
		&has_command($c) || return &text('check_ecmd', $c);
		}
	return undef;
	}
else {
	# Don't know
	return undef;
	}
}

# list_exports()
# Returns the current exports list
sub list_exports
{
local(@rv, $lnum, $_);
open(EXP, $config{'exports_file'});
$lnum = -1; $index = 0;
while(<EXP>) {
	$lnum++;
	s/\r|\n//g;	# remove newlines
	s/#.*$//g;	# remove comments
	next if (!/\S/);
	s/\\ /<sp>/g;	# hack to support splitting on space
	local @w = split(/[\s=]+/, $_);
	local %exp;
	for($i=0; $i<@w; $i++) {
		$w[$i] =~ s/<sp>/ /g;
		if ($w[$i] =~ /^\//) { push(@{$exp{'dirs'}}, $w[$i]); }
		elsif ($w[$i] eq "-maproot") { $exp{'maproot'} = $w[++$i]; }
		elsif ($w[$i] eq "-r") { $exp{'maproot'} = $w[++$i]; }
		elsif ($w[$i] eq "-mapall") { $exp{'mapall'} = $w[++$i]; }
		elsif ($w[$i] eq "-kerb") { $exp{'kerb'}++; }
		elsif ($w[$i] eq "-ro") { $exp{'ro'}++; }
		elsif ($w[$i] eq "-alldirs") { $exp{'alldirs'}++; }
		elsif ($w[$i] eq "-network") { $exp{'network'} = $w[++$i]; }
		elsif ($w[$i] eq "-mask") { $exp{'mask'} = $w[++$i]; }
		elsif ($w[$i] eq "-public") { $exp{'public'}++; }
		elsif ($w[$i] eq "-webnfs") { $exp{'webnfs'}++; }
		elsif ($w[$i] eq "-index") { $exp{'index'} = $w[++$i]; }
		else { push(@{$exp{'hosts'}}, $w[$i]); }
		}
	$exp{'line'} = $lnum;
	$exp{'index'} = $index++;
	push(@rv, \%exp);
	}
close(EXP);
return @rv;
}

# create_export(&export)
sub create_export
{
&open_tempfile(EXP, ">> $config{'exports_file'}");
&print_tempfile(EXP, &export_line($_[0]));
&close_tempfile(EXP);
}

# modify_export(&old, &new)
sub modify_export
{
&replace_file_line($config{'exports_file'}, $_[0]->{'line'},
		   &export_line($_[1]));
}

# delete_export(&export)
sub delete_export
{
&replace_file_line($config{'exports_file'}, $_[0]->{'line'});
}

# export_line(&export)
sub export_line
{
local %exp = %{$_[0]};
foreach my $d (@{$exp{'dirs'}}) {
	$d =~ s/ /\\ /g;
	}
local $rv = join(' ', @{$exp{'dirs'}});
if ($exp{'alldirs'}) { $rv .= " -alldirs"; }
if ($exp{'ro'}) { $rv .= " -ro"; }
if ($exp{'kerb'}) { $rv .= " -kerb"; }
if ($exp{'maproot'}) { $rv .= " -maproot $exp{'maproot'}"; }
if ($exp{'mapall'}) { $rv .= " -mapall $exp{'mapall'}"; }
if ($exp{'mask'}) { $rv .= " -network $exp{'network'} -mask $exp{'mask'}"; }
if ($exp{'public'}) { $rv .= " -public"; }
if ($exp{'webnfs'}) { $rv .= " -webnfs"; }
if ($exp{'index'}) { $rv .= " -index $exp{'index'}"; }
else { $rv .= " ".join(" ", @{$exp{'hosts'}}); }
$rv .= "\n";
return $rv;
}

# restart_mountd()
# Attempt to apply the NFS configuration, returning undef on success or an
# error message on failure
sub restart_mountd
{
local $out = &backquote_logged("($config{'restart_command'}) </dev/null 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

