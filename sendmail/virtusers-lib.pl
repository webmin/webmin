# virtusers-lib.pl
# Functions for the virtusers table

# virtusers_dbm(&config)
# Returns the filename and type of the virtusers database, or undef if none
sub virtusers_dbm
{
foreach $f (&find_type("K", $_[0])) {
        if ($f->{'value'} =~ /^virtuser\s+(\S+)[^\/]+(\S+)$/) {
		return ($2, $1);
                }
	}
return undef;
}

# virtusers_file(&config)
# Returns the filename of the text virtusers file, or undef if none
sub virtusers_file
{
return &find_textfile($config{'virtusers_file'}, &virtusers_dbm($_[0]));
}

# list_virtusers(textfile)
sub list_virtusers
{
if (!scalar(@list_virtusers_cache)) {
	@list_virtusers_cache = ( );
	local $lnum = 0;
	local $cmt;
	open(VIRT, $_[0]);
	while(<VIRT>) {
		s/\r|\n//g;     # remove newlines
		if (/^\s*#+\s*(.*)/) {
			# A comment line
			$cmt = &is_table_comment($_);
			}
		elsif (/^(\S+)\s+(.*)/) {
			# An actual virtuser line
			local(%virt);
			$virt{'from'} = $1;
			$virt{'to'} = $2;
			$virt{'line'} = $cmt ? $lnum-1 : $lnum;
			$virt{'eline'} = $lnum;
			$virt{'file'} = $_[0];
			$virt{'num'} = scalar(@list_virtusers_cache);
			$virt{'cmt'} = $cmt;
			push(@list_virtusers_cache, \%virt);
			$cmt = undef;
			}
		else {
			$cmt = undef;
			}
		$lnum++;
		}
	close(VIRT);
	}
return @list_virtusers_cache;
}

# create_virtuser(&details, textfile, dbmfile, dbmtype)
# Create a new virtuser mapping
sub create_virtuser
{
&list_virtusers($_[1]);	# force cache init
local(%virt);

# Add to file
local $lref = &read_file_lines($_[1]);
$_[0]->{'line'} = scalar(@$lref);
push(@$lref, &make_table_comment($_[0]->{'cmt'}));
push(@$lref, "$_[0]->{'from'}\t$_[0]->{'to'}");
$_[0]->{'eline'} = scalar(@$lref)-1;
&flush_file_lines($_[1]);

# Add to DBM
if (!&rebuild_map_cmd($_[1])) {
	if ($_[3] eq "dbm") {
		dbmopen(%virt, $_[2], 0644);
		$virt{$_[0]->{'from'}} = $_[0]->{'to'};
		dbmclose(%virt);
		}
	else { &run_makemap($_[1], $_[2], $_[3]); }
	}

# Add to cache
$_[0]->{'num'} = scalar(@list_virtusers_cache);
$_[0]->{'file'} = $_[1];
push(@list_virtusers_cache, $_[0]);
}

# delete_virtuser(&details, textfile, dbmfile, dbmtype)
# Delete an existing virtuser mapping
sub delete_virtuser
{
local %virt;

# Delete  from file
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
local $idx = &indexof($_[0], @list_virtusers_cache);
splice(@list_virtusers_cache, $idx, 1) if ($idx != -1);
&renumber_list(\@list_virtusers_cache, $_[0], -$len);
}

# modify_virtuser(&old, &details, textfile, dbmfile, dbmtype)
# Change an existing virtuser
sub modify_virtuser
{
local %virt;

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
local $idx = &indexof($_[0], @list_virtusers_cache);
$_[1]->{'line'} = $_[0]->{'line'};
$_[1]->{'eline'} = $_[1]->{'cmt'} ? $_[0]->{'line'}+1 : $_[0]->{'line'};
$list_virtusers_cache[$idx] = $_[1] if ($idx != -1);
&renumber_list(\@list_virtusers_cache, $_[0], scalar(@newlines)-$oldlen);
}

# virtuser_form([&details])
sub virtuser_form
{
local ($v) = @_;
local ($mode, $addr);

print &ui_form_start("save_virtuser.cgi", "post");
if ($v) {
	print &ui_hidden("num", $v->{'num'});
	}
else {
	print &ui_hidden("new", 1);
	}
print &ui_table_start($v ? $text{'vform_edit'} : $text{'vform_create'},
		      undef, 2);

# Description
print &ui_table_row($text{'vform_cmt'},
	&ui_textbox("cmt", $v ? $v->{'cmt'} : undef, 50));

# Source address
$addr = !$v || $v->{'from'} =~ /^(\S+)\@(\S+)$/;
if ($access{'vcatchall'}) {
	# Can be address or whole domain
	print &ui_table_row($text{'vform_for'},
		&ui_radio_table("from_type", $addr ? 0 : 1,
		  [ [ 0, $text{'vform_address'},
			 &ui_textbox("from_addr",
			     $addr ? $v->{'from'} : "", 20) ],
		    [ 1, $text{'vform_domain'},
			 &ui_textbox("from_dom",
			     $addr ? "" : substr($v->{'from'}, 1), 20) ] ]));
	}
else {
	# Just address
	print &ui_table_row($text{'vform_for'},
		&ui_textbox("from_addr", $addr ? $v->{'from'} : "", 40));
	}
		
# Virtuser destination
$mode = !$v ? 2 :
	$v->{'to'} =~ /^error:(\S+)\s*(.*)$/ ? 0 :
	$v->{'to'} =~ /^\%1\@(\S+)$/ ? 1 :
	$v->{'to'} =~ /^(.*)$/ ? 2 : 2;
local ($one, $two) = ($1, $2);
local @opts;
if ($access{'vedit_2'}) {
	# Some address
	push(@opts, [ 2, $text{'vform_address'},
		      &ui_textbox("to_addr", $mode == 2 ? $one : "", 20) ]);
	}
if ($access{'vedit_1'}) {
	# Another domain
	push(@opts, [ 1, $text{'vform_domain'},
		      &ui_textbox("to_dom", $mode == 1 ? $one : "", 15) ]);
	}
if ($access{'vedit_0'}) {
	# Return an error
	push(@opts, [ 0, $text{'vform_error'},
		      &ui_select("to_code", $one,
			[ map { [ $_, $text{'vform_err_'.$_} ] }
			      ( "nouser", "nohost", "unavailable",
				"tempfail", "protocol" ) ])." ".
		      &ui_textbox("to_error", $mode == 0 ? $two : "", 15)
		      ]);
	}
print &ui_table_row($text{'vform_to'},
	&ui_radio_table("to_type", $mode, \@opts));

print &ui_table_end();
print &ui_form_end($_[0] ? [ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]
		         : [ [ "create", $text{'create'} ] ]);
}

# virt_type(string)
# Return the type and destination of some virtuser target
sub virt_type
{
local @rv;
if ($_[0] =~ /^error:(.*)$/) {
	@rv = (0, $1);
	}
elsif ($_[0] =~ /^\%1\@(\S+)$/) {
	@rv = (1, $1);
	}
else {
	@rv = (2, $_[0]);
	}
return wantarray ? @rv : $rv[0];
}

sub can_edit_virtuser
{
local ($v) = @_;
if ($v->{'from'} =~ /^\@/ && !$access{'vcatchall'}) {
	return 0;
	}
return $access{'vmode'} == 1 ||
       $access{'vmode'} == 2 && $v->{'from'} =~ /$access{'vaddrs'}/ ||
       $access{'vmode'} == 3 && $v->{'from'} =~ /^$remote_user\@/;
}

1;

