#!/usr/local/bin/perl

do "../web-lib.pl";
&init_config();
do '../ui-lib.pl';

# parse_inittab()
# Returns a list of entries from the /etc/inittab file
sub parse_inittab
{
local @rv;
local $lnum = 0;
open(INITTAB, $config{'inittab_file'});
while(<INITTAB>) {
	s/\r|\n//g;
	#s/#.*$//g;
	s/\/\/.*$//g;
	if ($gconfig{'os_type'} eq 'aix') {
		# A leading : indicates a comment on AIX
		s/^:.*$//g;
		}
	next if (/^\s*#\s*\$Header/i);	# CVS header
	local $sline = $lnum;
	# Join \ lines
	while(/\\$/) {
		local $nl = <INITTAB>;
		s/\\$//;
		$nl =~ s/^\s+//;
		$_ .= $nl;
		$lnum++;
		}
	if (/^(#*)\s*\$Id/ || /^(#*)\s*\/etc/ || /^(#*)\s*<id>/) {
		# Skip this line
		}
	elsif (/^(#*)\s*([^:]+):([^:]*):([^:]+):([^:]*)/) {
		push(@rv, { 'id' => $2,
			    'action' => $4,
			    'process' => $5,
			    'comment' => $1 ne '',
			    'levels' => [ split(//, $3) ],
			    'line' => $sline,
			    'eline' => $lnum,
			    'index' => scalar(@rv) });
		}
	$lnum++;
	}
close(INITTAB);
return @rv;
} 

# create_inittab(&inittab)
# Adds an entry to /etc/inittab
sub create_inittab
{
&open_tempfile(INITTAB, ">>$config{'inittab_file'}");
&print_tempfile(INITTAB, $_[0]->{'comment'} ? "# " : "",
	      join(":", $_[0]->{'id'}, join("", @{$_[0]->{'levels'}}),
			$_[0]->{'action'}, $_[0]->{'process'}),"\n");
&close_tempfile(INITTAB);
}

# modify_inittab(&inittab)
# Replaces an /etc/inittab entry
sub modify_inittab
{
local $lref = &read_file_lines($config{'inittab_file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       ($_[0]->{'comment'} ? "# " : "").
       join(":", $_[0]->{'id'}, join("", @{$_[0]->{'levels'}}),
		 $_[0]->{'action'}, $_[0]->{'process'}));
&flush_file_lines();
}

# delete_inittab(&inittab)
# Delete a single /etc/inittab entry
sub delete_inittab
{
local $lref = &read_file_lines($config{'inittab_file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

sub p_link
{
    my ( $dest, $text ) = @_;
    return "<a href=\"". $dest. "\">". $text. "</a>";
}

sub p_radio
{
    my ( $name, $checked, @list ) = @_;
    local ($out, $size, $i);
    $size = @list; $i = 0;

    do
    {
	$out .= " <input type=radio name=".$name." value=".$list[$i];
	$out .= " checked" if( $checked eq $list[$i++] );
	$out .="> ".$list[$i++];
    } while( $i < $size );

    return $out;
}

sub p_entry
{
    my ( $name, $value, $size ) = @_;
    my $q = $_[1] =~ /'/ ? "\"" : "'";

    $size ? return "<input name=". $name. " size=". $size." value=$q". $value."$q>" : return "<input name=". $name. " value=$q". $value."$q>";
}

sub p_select_wdl
{
    my ( $name, $selected, @list ) = @_;
    local $size = @list, $i = 0, $out = " <select name=".$name.">";
    do
    {
	$out .= "<option name=".$name." value=".$list[$i];
	$out .= " selected" if( $selected eq $list[$i++] );
	$out .= ">".$list[$i++];
    } while( $i < $size );
    $out .= "</select>";

    return $out;
}

sub p_select
{
    my ( $name, $selected, @list ) = @_;
    local (@newlist, $item);

    foreach $item ( @list )
    {
	push( @newlist, $item, $item );
    }

    p_select_wdl( $name, $selected, @newlist );
}

sub p_button
{
    my ( $name, $value ) = @_;
    return "<input type=submit name=". $name. " value=\"". $value. "\">";
}
