# mailers-lib.pl
# Functions for editing the mailertable database

# mailers_dbm(&config)
# Returns the filename of the mailertable database and type, or undef if none
sub mailers_dbm
{
foreach $f (&find_type("K", $_[0])) {
        if ($f->{'value'} =~ /^mailertable\s+(\S+)[^\/]+(\/\S+)$/) {
		return ($2, $1);
                }
	}
return undef;
}

# mailers_file(&config)
# Returns the filename of the text mailertable file, or undef if none
sub mailers_file
{
return &find_textfile($config{'mailers_file'}, &mailers_dbm($_[0]));
}

# list_mailers(textfile)
sub list_mailers
{
if (!scalar(@list_mailers_cache)) {
	local $lnum = 0;
	@list_mailers_cache = ( );
	local $cmt;
	open(MAILER, $_[0]);
	while(<MAILER>) {
		s/\r|\n//g;     # remove newlines
		if (/^\s*#+\s*(.*)/) {
			# A comment line
			$cmt = &is_table_comment($_);
			}
		elsif (/^(\S+)\s+([^: ]+):(.*)/) {
			# An actual mailer line
			local(%virt);
			$virt{'domain'} = $1;
			$virt{'mailer'} = $2;
			$virt{'dest'} = $3;
			$virt{'line'} = $cmt ? $lnum-1 : $lnum;
			$virt{'eline'} = $lnum;
			$virt{'num'} = scalar(@list_mailers_cache);
			$virt{'cmt'} = $cmt;
			push(@list_mailers_cache, \%virt);
			$cmt = undef;
			}
		else {
			$cmt = undef;
			}
		$lnum++;
		}
	close(MAILER);
	}
return @list_mailers_cache;
}

# create_mailer(&details, textfile, dbmfile, dbmtype)
sub create_mailer
{
local(%mailer);
&list_mailers($_[1]);	# force cache init

# Write to the file
local $lref = &read_file_lines($_[1]);
$_[0]->{'line'} = scalar(@$lref);
push(@$lref, &make_table_comment($_[0]->{'cmt'}));
push(@$lref, "$_[0]->{'domain'}\t$_[0]->{'mailer'}:$_[0]->{'dest'}");
$_[0]->{'eline'} = scalar(@$lref)-1;
&flush_file_lines();

# Write to the DBM
if (!&rebuild_map_cmd($_[1])) {
	if ($_[3] eq "dbm") {
		dbmopen(%mailer, $_[2], 0644);
		$mailer{$_[0]->{'domain'}} = "$_[0]->{'mailer'}:$_[0]->{'dest'}";
		dbmclose(%mailer);
		}
	else { &run_makemap($_[1], $_[2], $_[3]); }
	}

# Update the cache
$_[0]->{'num'} = scalar(@list_mailers_cache);
$_[0]->{'file'} = $_[1];
push(@list_mailers_cache, $_[0]);
}

# modify_mailer(&old, &details, textfile, dbmfile, dbmtype)
sub modify_mailer
{
local(@mailer, %mailer);

# Update the file
local $lref = &read_file_lines($_[2]);
local $oldlen = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
local @newlines;
push(@newlines, &make_table_comment($_[1]->{'cmt'}));
push(@newlines, "$_[1]->{'domain'}\t$_[1]->{'mailer'}:$_[1]->{'dest'}");
splice(@$lref, $_[0]->{'line'}, $oldlen, @newlines);
&flush_file_lines($_[2]);

# Update the DBM
if (!&rebuild_map_cmd($_[2])) {
	if ($_[3] eq "dbm") {
		dbmopen(%mailer, $_[3], 0644);
		delete($mailer{$_[0]->{'domain'}});
		$mailer{$_[1]->{'domain'}} = "$_[1]->{'mailer'}:$_[1]->{'dest'}";
		dbmclose(%mailer);
		}
	else { &run_makemap($_[2], $_[3], $_[4]); }
	}

local $idx = &indexof($_[0], @list_mailers_cache);
$_[1]->{'line'} = $_[0]->{'line'};
$_[1]->{'eline'} = $_[1]->{'cmt'} ? $_[0]->{'line'}+1 : $_[0]->{'line'};
$list_mailers_cache[$idx] = $_[1] if ($idx != -1);
&renumber_list(\@list_mailers_cache, $_[0], scalar(@newlines)-$oldlen);
}

# delete_mailer(&old, textfile, dbmfile, dbmtype)
sub delete_mailer
{
local(@mailer, %mailer);

# Delete from the file
local $len = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
local $lref = &read_file_lines($_[1]);
splice(@$lref, $_[0]->{'line'}, $len);
&flush_file_lines($_[1]);

# Delete f rom the DBM
if (!&rebuild_map_cmd($_[1])) {
	if ($_[3] eq "dbm") {
		dbmopen(%mailer, $_[2], 0644);
		delete($mailer{$_[0]->{'domain'}});
		dbmclose(%mailer);
		}
	else { &run_makemap($_[1], $_[2], $_[3]); }
	}

# Update the cache
local $idx = &indexof($_[0], @list_mailers_cache);
splice(@list_mailers_cache, $idx, 1) if ($idx != -1);
&renumber_list(\@list_mailers_cache, $_[0], -$len);
}

# mailer_form([&details])
sub mailer_form
{
local ($m) = @_;
local ($mode, $addr, $conf, $ml, $dest, $nomx);

print &ui_form_start("save_mailer.cgi", "post");
if ($m) {
	print &ui_hidden("num", $m->{'num'});
	}
else {
	print &ui_hidden("new", 1);
	}
print &ui_table_start($m ? $text{'mform_edit'} : $text{'mform_create'},
		      undef, 2);

# Description
print &ui_table_row($text{'vform_cmt'},
		    &ui_textbox("cmt", $m ? $m->{'cmt'} : undef, 50));

# Show 'mail for' input
local $dom = $m && $m->{'domain'} =~ /^\.(\S+)$/ ? $1 : undef;
print &ui_table_row($text{'mform_for'},
    &ui_radio_table("from_type", $dom ? 1 : 0,
	[ [ 0, $text{'mform_host2'},
	       &ui_textbox("from_host", $dom || !$m ? "" : $m->{'domain'},
			   20) ],
	  [ 1, $text{'mform_domain2'},
	       &ui_textbox("from_dom", $dom, 20) ],
	  $m ? ( ) : ( [ 2, $text{'mform_domain3'},
			    &ui_textbox("from_all", undef ,20) ] ) ]));

# Show delivery input
$conf = &get_sendmailcf();
local @mailers = ( { 'value' => 'error' }, &find_type("M", $conf) );
print &ui_table_row($text{'mform_delivery'},
    &ui_select("mailer",
	       $m ? $m->{'mailer'} : "smtp",
	       [ map { $_->{'value'} =~ /^([^ ,]+)/;
		       [ $1, $text{"mform_$1"} ] } @mailers ]));

# Show send to input
$dest = $m->{'dest'};
if ($dest =~ s/\[([^\]:]+)\]/$1/g) {
	$nomx = 1;
	}
else {
	$dest = $m->{'dest'};
	}
print &ui_table_row($text{'mform_to'},
    &ui_textbox("dest", $dest, 30)."<br>".
    &ui_checkbox("nomx", 1, $text{'mform_ignore'}, $nomx));

print &ui_table_end();
print &ui_form_end($_[0] ? [ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]
		         : [ [ "create", $text{'create'} ] ]);
}

1;

