# access-lib.pl
# Functions for the access_db table

# access_dbm(&config)
# Returns the filename and type of the access database, or undef if none
sub access_dbm
{
foreach $f (&find_type("K", $_[0])) {
        if ($f->{'value'} =~ /^access\s+(\S+)[^\/]+(\S+)$/) {
		return ($2, $1);
                }
	}
return undef;
}

# access_file(&config)
# Returns the filename of the text access file, or undef if none
sub access_file
{
return &find_textfile($config{'access_file'}, &access_dbm($_[0]));
}

# list_access(textfile)
sub list_access
{
if (!scalar(@list_access_cache)) {
	@list_access_cache = ( );
	local $lnum = 0;
	open(ACC, $_[0]);
	while(<ACC>) {
		s/\r|\n//g;     # remove newlines
		if (/^\s*#+\s*(.*)/) {
			# A comment line
			$cmt = &is_table_comment($_);
			}
		elsif (/^(\S+)\s+(.*)/) {
			local(%acc);
			$acc{'from'} = $1;
			$acc{'action'} = $2;
			$acc{'line'} = $cmt ? $lnum-1 : $lnum;
			$acc{'eline'} = $lnum;
			$acc{'num'} = scalar(@list_access_cache);
			if ($acc{'from'} =~ /^(Connect|From|To):(.*)/i) {
				$acc{'tag'} = $1;
				$acc{'from'} = $2;
				}
			$acc{'cmt'} = $cmt;
			push(@list_access_cache, \%acc);
			$cmt = undef;
			}
		else {
			$cmt = undef;
			}
		$lnum++;
		}
	close(ACC);
	}
return @list_access_cache;
}

# create_access(&details, textfile, dbmfile, dbmtype)
# Create a new access database entry
sub create_access
{
&list_access($_[1]);	 # force cache init
local(%acc);

# Write to the file
local $lref = &read_file_lines($_[1]);
$_[0]->{'line'} = scalar(@$lref);
push(@$lref, &make_table_comment($_[0]->{'cmt'}));
local $from = $_[0]->{'tag'} ? "$_[0]->{'tag'}:$_[0]->{'from'}"
			     : $_[0]->{'from'};
push(@$lref, "$from\t$_[0]->{'action'}");
$_[0]->{'eline'} = scalar(@$lref)-1;
&flush_file_lines($_[1]);

# Add to DBM
if (!&rebuild_map_cmd($_[1])) {
	if ($_[3] eq "dbm") {
		dbmopen(%acc, $_[2], 0644);
		$acc{$from} = $_[0]->{'action'};
		dbmclose(%acc);
		}
	else { &run_makemap($_[1], $_[2], $_[3]); }
	}

# Add to cache
$_[0]->{'num'} = scalar(@list_access_cache);
$_[0]->{'file'} = $_[1];
push(@list_access_cache, $_[0]);
}

# delete_access(&details, textfile, dbmfile, dbmtype)
# Delete an existing access entry
sub delete_access
{
local(%acc);

# Delete form file
local $lref = &read_file_lines($_[1]);
local $len = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
splice(@$lref, $_[0]->{'line'}, $len);
&flush_file_lines($_[1]);

# Delete from DBM
local $oldfrom = $_[0]->{'tag'} ? "$_[0]->{'tag'}:$_[0]->{'from'}"
			        : $_[0]->{'from'};
if (!&rebuild_map_cmd($_[1])) {
	if ($_[3] eq "dbm") {
		dbmopen(%acc, $_[2], 0644);
		delete($acc{$oldfrom});
		dbmclose(%acc);
		}
	else { &run_makemap($_[1], $_[2], $_[3]); }
	}

# Delete from cache
local $idx = &indexof($_[0], @list_access_cache);
splice(@list_access_cache, $idx, 1) if ($idx != -1);
&renumber_list(\@list_access_cache, $_[0], -$len);
}

# modify_access(&old, &details, textfile, dbmfile, dbmtype)
# Change an existing access entry
sub modify_access
{
local %acc;
local $oldfrom = $_[0]->{'tag'} ? "$_[0]->{'tag'}:$_[0]->{'from'}"
			     : $_[0]->{'from'};
local $from = $_[1]->{'tag'} ? "$_[1]->{'tag'}:$_[1]->{'from'}"
			     : $_[1]->{'from'};

# Update in file
local $lref = &read_file_lines($_[2]);
local $oldlen = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
local @newlines;
push(@newlines, &make_table_comment($_[1]->{'cmt'}));
push(@newlines, "$from\t$_[1]->{'action'}");
splice(@$lref, $_[0]->{'line'}, $oldlen, @newlines);
&flush_file_lines($_[2]);

# Update DBM
if (!&rebuild_map_cmd($_[2])) {
	if ($_[4] eq "dbm") {
		dbmopen(%virt, $_[3], 0644);
		delete($virt{$oldfrom});
		$virt{$from} = $_[1]->{'action'};
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

# access_form([&details])
sub access_form
{
local ($v) = @_;
local ($mode, $addr);

print &ui_form_start("save_access.cgi", "post");
if ($v) {
	print &ui_hidden("num", $v->{'num'}),"\n";
	}
else {
	print &ui_hidden("new", 1),"\n";
	}
print &ui_table_start($v ? $text{'sform_edit'} : $text{'sform_create'},
		      undef, 2);

# Comment
print &ui_table_row($text{'vform_cmt'},
		    &ui_textbox("cmt", $v->{'cmt'}, 50));

# Mail source
local $src = $v->{'from'} =~ /^\S+\@\S+$/ ? 0 :
	     $v->{'from'} =~ /^[0-9\.]+$/ ? 1 :
	     $v->{'from'} =~ /^\S+\@$/ ? 2 :
	     $v->{'from'} =~ /^[A-z0-9\-\.]+$/ ? 3 : 0;
print &ui_table_row($text{'sform_source'},
    &ui_select("from_type", $src,
	       [ map { [ $_, $text{"sform_type$_"} ] } (0 .. 3) ])."\n".
    &ui_textbox("from", $v->{'from'}, 25));

# Match against tag
local $ver = &get_sendmail_version();
if ($v->{'tag'} || $ver >= 8.10) {
	print &ui_table_row($text{'sform_tag'},
	    &ui_select("tag", $v->{'tag'},
		       [ [ "", $text{'sform_tag_'} ],
		         [ "From", $text{'sform_tag_from'} ],
		         [ "To", $text{'sform_tag_to'} ],
		         [ "Connect", $text{'sform_tag_connect'} ],
		         [ "Spam", $text{'sform_tag_spam'} ] ]));
	}

# Action
local $atable = "<table>\n";
$atable .= "<tr>";
$atable .= "<td>".&ui_oneradio("action", "OK", $text{'sform_ok'},
		       $v->{'action'} eq "OK" || !$v->{'action'})."</td>\n";
$atable .= "<td>".&ui_oneradio("action", "RELAY", $text{'sform_relay'},
			       $v->{'action'} eq "RELAY")."</td>\n";
$atable .= "</tr>";
$atable .= "<tr>";
$atable .= "<td>".&ui_oneradio("action", "REJECT", $text{'sform_reject'},
			       $v->{'action'} eq "REJECT")."</td>\n";
$atable .= "<td>".&ui_oneradio("action", "DISCARD", $text{'sform_discard'},
			       $v->{'action'} eq "DISCARD")."</td>\n";
$atable .= "</tr>";
$atable .= "<tr>";
local ($err, $msg) = $v->{'action'} =~ /(\d+)\s*(.*)$/ ? ($1, $2) : ( );
$atable .= "<td colspan=2>".&ui_oneradio("action", 0,  $text{'sform_err'},
					 $err)."\n";
$atable .= &ui_textbox("err", $err, 4)." ".$text{'sform_msg'}."\n";
$atable .= &ui_textbox("msg", $msg, 20)."</td>\n";
$atable .= "</tr>";
$atable .= "</table>\n";
print &ui_table_row($text{'sform_action'}, $atable);

print &ui_table_end();
print &ui_form_end($_[0] ? [ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]
		         : [ [ "create", $text{'create'} ] ]);
}

sub can_edit_access
{
local ($g) = @_;
return $access{'smode'} == 1 ||
       $access{'smode'} == 2 && $g->{'from'} =~ /$access{'saddrs'}/;
}

1;

