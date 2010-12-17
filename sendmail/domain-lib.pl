# domain-lib.pl
# Functions for the domains table

# domains_dbm(&config)
# Returns the filename and type of the domains database, or undef if none
sub domains_dbm
{
foreach $f (&find_type("K", $_[0])) {
        if ($f->{'value'} =~ /^domaintable\s+(\S+)[^\/]+(\S+)$/) {
		return ($2, $1);
                }
	}
return undef;
}

# domains_file(&config)
# Returns the filename of the text domains file, or undef if none
sub domains_file
{
return &find_textfile($config{'domains_file'}, &domains_dbm($_[0]));
}

# list_domains(textfile)
sub list_domains
{
if (!scalar(@list_domains_cache)) {
	@list_domains_cache = ( );
	local $lnum = 0;
	local $cmt;
	open(DOM, $_[0]);
	while(<DOM>) {
		s/\r|\n//g;     # remove newlines
		if (/^\s*#+\s*(.*)/) {
			# A comment line
			$cmt = &is_table_comment($_);
			}
		elsif (/^(\S+)\s+(.*)/) {
			# A domain mapping
			local(%dom);
			$dom{'from'} = $1;
			$dom{'to'} = $2;
			$dom{'line'} = $cmt ? $lnum-1 : $lnum;
			$dom{'eline'} = $lnum;
			$dom{'num'} = scalar(@list_domains_cache);
			$dom{'cmt'} = $cmt;
			push(@list_domains_cache, \%dom);
			$cmt = undef;
			}
		else {
			$cmt = undef;
			}
		$lnum++;
		}
	close(DOM);
	}
return @list_domains_cache;
}

# create_domain(&details, textfile, dbmfile, dbmtype)
# Create a new domain mapping
sub create_domain
{
&list_domains($_[1]);	# force cache init
local %dom;

# Write to the file
local $lref = &read_file_lines($_[1]);
$_[0]->{'line'} = scalar(@$lref);
push(@$lref, &make_table_comment($_[0]->{'cmt'}));
push(@$lref, "$_[0]->{'from'}\t$_[0]->{'to'}");
$_[0]->{'eline'} = scalar(@$lref)-1;
&flush_file_lines($_[1]);

# Add to DBM
if (!&rebuild_map_cmd($_[1])) {
	if ($_[3] eq "dbm") {
		dbmopen(%dom, $_[2], 0644);
		$dom{$_[0]->{'from'}} = $_[0]->{'to'};
		dbmclose(%dom);
		}
	else { &run_makemap($_[1], $_[2], $_[3]); }
	}

# Add to cache
$_[0]->{'num'} = scalar(@list_domains_cache);
$_[0]->{'file'} = $_[1];
push(@list_domains_cache, $_[0]);
}

# delete_domain(&details, textfile, dbmfile, dbmtype)
# Delete an existing domain mapping
sub delete_domain
{
local %dom;

# Delete from file
local $lref = &read_file_lines($_[1]);
local $len = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
splice(@$lref, $_[0]->{'line'}, $len);
&flush_file_lines($_[1]);

# Delete from DBM
if (!&rebuild_map_cmd($_[1])) {
	if ($_[3] eq "dbm") {
		dbmopen(%dom, $_[2], 0644);
		delete($dom{$_[0]->{'from'}});
		dbmclose(%dom);
		}
	else { &run_makemap($_[1], $_[2], $_[3]); }
	}

# Delete from cache
local $idx = &indexof($_[0], @list_domains_cache);
splice(@list_domains_cache, $idx, 1) if ($idx != -1);
&renumber_list(\@list_domains_cache, $_[0], -$len);
}

# modify_domain(&old, &details, textfile, dbmfile, dbmtype)
# Change an existing domain
sub modify_domain
{
local %dom;

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
		dbmopen(%dom, $_[3], 0644);
		delete($dom{$_[0]->{'from'}});
		$dom{$_[1]->{'from'}} = $_[1]->{'to'};
		dbmclose(%dom);
		}
	else { &run_makemap($_[2], $_[3], $_[4]); }
	}

# Update cache
local $idx = &indexof($_[0], @list_domains_cache);
$_[1]->{'line'} = $_[0]->{'line'};
$_[1]->{'eline'} = $_[1]->{'cmt'} ? $_[0]->{'line'}+1 : $_[0]->{'line'};
$list_domains_cache[$idx] = $_[1] if ($idx != -1);
&renumber_list(\@list_domains_cache, $_[0], scalar(@newlines)-$oldlen);
}

# domain_form([&details])
sub domain_form
{
local $g = $_[0];

print &ui_form_start("save_domain.cgi", "post");
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

print &ui_table_row($text{'dform_from'},
		    &ui_textbox("from", $g->{'from'}, 30));

print &ui_table_row($text{'dform_to'},
		    &ui_textbox("to", $g->{'to'}, 30));

print &ui_table_end();
print &ui_form_end($_[0] ? [ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]
		         : [ [ "create", $text{'create'} ] ]);
}

1;

