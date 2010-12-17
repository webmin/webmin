# generics-lib.pl
# Functions for the generics table

# generics_dbm(&config)
# Returns the filename and type of the generics database, or undef if none
sub generics_dbm
{
foreach $f (&find_type("K", $_[0])) {
        if ($f->{'value'} =~ /^generics\s+(\S+)[^\/]+(\S+)$/) {
		return ($2, $1);
                }
	}
return undef;
}

# generics_file(&config)
# Returns the filename of the text generics file, or undef if none
sub generics_file
{
return &find_textfile($config{'generics_file'}, &generics_dbm($_[0]));
}

# list_generics(textfile)
sub list_generics
{
if (!scalar(@list_generics_cache)) {
	@list_generics_cache = ( );
	local $lnum = 0;
	local $cmt;
	open(GEN, $_[0]);
	while(<GEN>) {
		s/\r|\n//g;     # remove newlines
		if (/^\s*#+\s*(.*)/) {
			# A comment line
			$cmt = &is_table_comment($_);
			}
		elsif (/^(\S+)\s+(.*)/) {
			local(%gen);
			$gen{'from'} = $1;
			$gen{'to'} = $2;
			$gen{'line'} = $cmt ? $lnum-1 : $lnum;
			$gen{'eline'} = $lnum;
			$gen{'file'} = $_[0];
			$gen{'num'} = scalar(@list_generics_cache);
			$gen{'cmt'} = $cmt;
			push(@list_generics_cache, \%gen);
			$cmt = undef;
			}
		else {
			$cmt = undef;
			}
		$lnum++;
		}
	close(GEN);
	}
return @list_generics_cache;
}

# create_generic(&details, textfile, dbmfile, dbmtype)
# Create a new generic mapping
sub create_generic
{
&list_generics($_[1]);	# force cache init
local(%virt);

# Write to the file
local $lref = &read_file_lines($_[1]);
$_[0]->{'line'} = scalar(@$lref);
push(@$lref, &make_table_comment($_[0]->{'cmt'}));
push(@$lref, "$_[0]->{'from'}\t$_[0]->{'to'}");
$_[0]->{'eline'} = scalar(@$lref)-1;
&flush_file_lines($_[1]);

# Add to DBM
if (!&rebuild_map_cmd($_[1])) {
	if (!&rebuild_map_cmd($_[1])) {
		if ($_[3] eq "dbm") {
			dbmopen(%virt, $_[2], 0644);
			$virt{$_[0]->{'from'}} = $_[0]->{'to'};
			dbmclose(%virt);
			}
		else { &run_makemap($_[1], $_[2], $_[3]); }
		}
	}

# Add to cache
$_[0]->{'num'} = scalar(@list_generics_cache);
$_[0]->{'file'} = $_[1];
push(@list_generics_cache, $_[0]);
}

# delete_generic(&details, textfile, dbmfile, dbmtype)
# Delete an existing generic mapping
sub delete_generic
{
local(%virt);

# Delete from file
local $lref = &read_file_lines($_[1]);
local $len = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
splice(@$lref, $_[0]->{'line'}, $len);
&flush_file_lines($_[1]);

# Delete from DBM
if (!&rebuild_map_cmd($_[1])) {
	if ($_[3] eq "dbm") {
		dbmopen(%virt, $_[2], 0644);
		delete($virt{$_[0]->{'from'}});
		dbmclose(%virt);
		}
	else { &run_makemap($_[1], $_[2], $_[3]); }
	}

# Delete from cache
local $idx = &indexof($_[0], @list_generics_cache);
splice(@list_generics_cache, $idx, 1) if ($idx != -1);
&renumber_list(\@list_generics_cache, $_[0], -$len);
}

# modify_generic(&old, &details, textfile, dbmfile, dbmtype)
# Change an existing generic
sub modify_generic
{
local(%virt);

# Update in file
local $lref = &read_file_lines($_[2]);
local $oldlen = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
local @newlines;
push(@newlines, &make_table_comment($_[1]->{'cmt'}));
push(@newlines, "$_[1]->{'from'}\t$_[1]->{'to'}");
splice(@$lref, $_[0]->{'line'}, $oldlen, @newlines);
&flush_file_lines($_[2]);

# Update DBM
if (!&rebuild_map_cmd($_[2])) {
	if ($_[4] eq "dbm") {
		dbmopen(%virt, $_[3], 0644);
		delete($virt{$_[0]->{'from'}});
		$virt{$_[1]->{'from'}} = $_[1]->{'to'};
		dbmclose(%virt);
		}
	else { &run_makemap($_[2], $_[3], $_[4]); }
	}

# Update cache
local $idx = &indexof($_[0], @list_generics_cache);
$_[1]->{'line'} = $_[0]->{'line'};
$_[1]->{'eline'} = $_[1]->{'cmt'} ? $_[0]->{'line'}+1 : $_[0]->{'line'};
$list_generics_cache[$idx] = $_[1] if ($idx != -1);
&renumber_list(\@list_generics_cache, $_[0], scalar(@newlines)-$oldlen);
}

sub generic_form([&details])
{
local $g = $_[0];

print &ui_form_start("save_generic.cgi", "post");
if ($g) {
	print &ui_hidden("num", $g->{'num'}),"\n";
	}
else {
	print &ui_hidden("new", 1),"\n";
	}
print &ui_table_start($g ? $text{'gform_edit'} : $text{'gform_create'},
		      undef, 2);

print &ui_table_row($text{'vform_cmt'},
		    &ui_textbox("cmt", $g->{'cmt'}, 50));

print &ui_table_row($text{'gform_from'},
		    &ui_textbox("from", $g->{'from'}, 30));

print &ui_table_row($text{'gform_to'},
		    &ui_textbox("to", $g->{'to'}, 30));

print &ui_table_end();
print &ui_form_end($_[0] ? [ [ "save", $text{'save'} ],
		    	     [ "delete", $text{'delete'} ] ]
		         : [ [ "create", $text{'create'} ] ]);
}

sub can_edit_generic
{
local ($g) = @_;
return $access{'omode'} == 1 ||
       $access{'omode'} == 2 && ($g->{'from'} =~ /$access{'oaddrs'}/ ||
				 $g->{'to'} =~ /$access{'oaddrs'}/);
}

1;

