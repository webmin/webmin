# sgiexports-lib.pl
# Functions for reading and editing the SGI NFS exports file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_exports()
# Parses the exports file into a list of structures, one per export
sub get_exports
{
local $lnum = 0;
local @rv;
open(EXPORTS, $config{'exports_file'});
while(<EXPORTS>) {
	s/\r|\n//g;
	s/#.*$//g;
	local $slnum = $lnum;
	while(/\\$/) {
		local $nl = <EXPORTS>;
		s/\\$//;
		$nl =~ s/^\s+//;
		$_ .= $nl;
		$lnum++;
		}
	local @w = split(/\s+/, $_);
	if (@w) {
		local $exp = { 'dir' => shift(@w),
			       'opts' => { },
			       'line' => $slnum,
			       'eline' => $lnum,
			       'index' => scalar(@rv) };
		if ($w[0] =~ /^-/) {
			# Has some options
			local $opts = shift(@w);
			$opts =~ s/^\-//;
			local $o;
			foreach $o (split(/,/, $opts)) {
				if ($o =~ /^([^=]+)=(\S*)$/) {
					$exp->{'opts'}->{$1} = $2;
					}
				else {
					$exp->{'opts'}->{$o} = "";
					}
				}
			}
		$exp->{'hosts'} = \@w;
		push(@rv, $exp);
		}
	$lnum++;
	}
close(EXPORTS);
return @rv;
}

# create_export(&export)
sub create_export
{
open(EXPORTS, ">>$config{'exports_file'}");
print EXPORTS &export_line($_[0]),"\n";
close(EXPORTS);
}

# modify_export(&export)
sub modify_export
{
local $lref = &read_file_lines($config{'exports_file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       &export_line($_[0]));
&flush_file_lines();
}

# delete_export(&export)
sub delete_export
{
local $lref = &read_file_lines($config{'exports_file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

sub export_line
{
local @w = ( $_[0]->{'dir'} );
local @o;
foreach $o (keys %{$_[0]->{'opts'}}) {
	if ($_[0]->{'opts'}->{$o} eq "") {
		push(@o, $o);
		}
	else {
		push(@o, $o."=".$_[0]->{'opts'}->{$o});
		}
	}
push(@w, "-".join(",", @o)) if (@o);
push(@w, @{$_[0]->{'hosts'}});
return join(" ", @w);
}

1;

