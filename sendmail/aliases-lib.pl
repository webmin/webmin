# aliases-lib.pl
# Alias file functions

# aliases_file(&config)
# Returns the alias filenames
sub aliases_file
{
if ($config{'alias_file'}) { return [ $config{'alias_file'} ]; }
else {
	local(@afiles, $o);
	foreach $o (&find_type("O", $_[0])) {
		if ($o->{'value'} =~ /^\s*AliasFile=(.*)$/) {
			push(@afiles, split(/,/, $1));
			}
		}
	map { s/dbm:// } @afiles;
	return \@afiles;
	}
}

# list_aliases(files)
# Returns an array of data structures, each containing information about
# one sendmail alias
sub list_aliases
{
local $jfiles = join(",", @{$_[0]});
local $c = $list_aliases_cache{$jfiles};
if (!defined($c)) {
	$c = $list_aliases_cache{$jfiles} = [ ];
	local $file;
	local @skip = split(/\s+/, $config{'alias_skip'});
	foreach $file (@{$_[0]}) {
		local $lalias;
		local $lnum = 0;
		local $cmt;
		&open_readfile(AFILE, $file);
		while(<AFILE>) {
			s/\r|\n//g;	# remove newlines
			if (/^\s*#+\s*(.*)/ && &is_table_comment($_, 1)) {
				# A comment line
				$cmt = &is_table_comment($_, 1);
				}
			elsif (/^(#*)\s*([^:$ \t]+)\s*:\s*(.*)$/) {
				local(%alias, @values, $v);
				$alias{'line'} = $cmt ? $lnum-1 : $lnum;
				$alias{'eline'} = $lnum;
				$alias{'file'} = $file;
				$alias{'files'} = $_[0];
				$alias{'enabled'} = $1 ? 0 : 1;
				$alias{'name'} = $2;
				$alias{'cmt'} = $cmt;
				$v = $3;
				$alias{'value'} = $v;
				while($v =~ /^\s*,?\s*()"([^"]+)"(.*)$/ ||
				      $v =~ /^\s*,?\s*(\|)"([^"]+)"(.*)$/ ||
				      $v =~ /^\s*,?\s*()([^,\s]+)(.*)$/) {
					push(@values, $1.$2); $v = $3;
					}
				$alias{'values'} = \@values;
				$alias{'num'} = scalar(@$c);
				if (&indexof($alias{'name'}, @skip) < 0) {
					push(@$c, \%alias);
					$lalias = \%alias;
					}
				$cmt = undef;
				}
			elsif (/^(#*)\s+(\S.*)$/ && $lalias &&
			       ($1 && !$lalias->{'enabled'} ||
				!$1 && $lalias->{'enabled'})) {
				# continuation of last alias
				$lalias->{'eline'} = $lnum;
				local $v = $2;
				$lalias->{'value'} .= $v;
				while($v =~ /^\s*,?\s*()"([^"]+)"(.*)$/ ||
				      $v =~ /^\s*,?\s*(\|)"([^"]+)"(.*)$/ ||
				      $v =~ /^\s*,?\s*()([^,\s]+)(.*)$/) {
					push(@{$lalias->{'values'}}, $1.$2); $v = $3;
					}
				$cmt = undef;
				}
			else {
				# Some other line
				$lalias = undef;
				$cmt = undef;
				}
			$lnum++;
			}
		close(AFILE);
		}
	}
return @$c;
}

# alias_form([alias], [no-comment])
# Display a form for editing or creating an alias. Each alias can map to
# 1 or more programs, files, lists or users
sub alias_form
{
local ($a, $nocmt, $afile) = @_;
local (@values, $v, $type, $val, @typenames);
if ($a) { @values = @{$a->{'values'}}; }
@typenames = map { $text{"aform_type$_"} } (0 .. 6);
$typenames[0] = "&lt;$typenames[0]&gt;";

# Start of form and table
print &ui_form_start("save_alias.cgi", "post");
if ($a) {
	print &ui_hidden("num", $a->{'num'}),"\n";
	}
else {
	print &ui_hidden("new", 1),"\n";
	}
print &ui_table_start($a ? $text{'aform_edit'}
			 : $text{'aform_create'}, undef, 2);

# Description
if (!$nocmt) {
	print &ui_table_row(&hlink($text{'aform_cmt'},"alias_cmt"),
		&ui_textbox("cmt", $a ? $a->{'cmt'} : undef, 50));
	}


# Alias name
print &ui_table_row(&hlink($text{'aform_name'},"alias_name"),
		    &ui_textbox("name", $a ? $a->{'name'} : "", 20));

# Enabled flag
print &ui_table_row(&hlink($text{'aform_enabled'}, "alias_enabled"),
		    &ui_yesno_radio("enabled", !$a || $a->{'enabled'} ? 1 : 0));

# Alias file, if more than one possible
if ($afile && @$afile > 1) {
	print &ui_table_row(&hlink($text{'aform_file'}, "alias_file"),
		&ui_select("afile", undef, $afile));
	}

# Destinations
local @typeopts;
for($j=0; $j<@typenames; $j++) {
	if (!$j || $access{"aedit_$j"}) {
		push(@typeopts, [ $j, $typenames[$j] ]);
		}
	}
for($i=0; $i<=@values; $i++) {
	($type, $val) = $values[$i] ? &alias_type($values[$i]) : (0, "");

	local $typesel = &ui_select("type_$i", $type, \@typeopts);
	local $valtxt = &ui_textbox("val_$i", $val, 30);
	local $edlnk;
	if ($type == 2 && $a) {
		$edlnk = &ui_link("edit_afile.cgi?file=$val&num=$a->{'num'}",$text{'aform_afile'});
		}
	elsif ($type == 5 && $a) {
		$edlnk = &ui_link("edit_rfile.cgi?file=$val&num=$a->{'num'}",$text{'aform_afile'});
		}
	elsif ($type == 6 && $a) {
		$edlnk = &ui_link("edit_ffile.cgi?file=$val&num=$a->{'num'}",$text{'aform_afile'});
		}
	print &ui_table_row(&hlink($text{'aform_val'},"alias_to"),
			      $typesel."\n".$valtxt."\n".$edlnk);
	}

# Table and form end
print &ui_table_end();
if ($a) {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
}

# create_alias(&details, &files, [norebuild])
# Create a new alias
sub create_alias
{
&list_aliases($_[1]);	# force cache init

# Update the config file
local(%aliases);
$_[0]->{'file'} ||= $_[1]->[0];
local $lref = &read_file_lines($_[0]->{'file'});
$_[0]->{'line'} = scalar(@$lref);
push(@$lref, &make_table_comment($_[0]->{'cmt'}, 1));
local $str = ($_[0]->{'enabled'} ? "" : "# ") . $_[0]->{'name'} . ": " .
	     join(',', map { /\s/ ? "\"$_\"" : $_ } @{$_[0]->{'values'}});
push(@$lref, $str);
$_[0]->{'eline'} = scalar(@$lref)-1;
&flush_file_lines($_[0]->{'file'});
if (!$_[2]) {
	if (!&rebuild_map_cmd($_[0]->{'file'})) {
		&system_logged("newaliases >/dev/null 2>&1");
		}
	}

# Add to the cache
local $jfiles = join(",", @{$_[1]});
local $c = $list_aliases_cache{$jfiles};
$_[0]->{'num'} = scalar(@$c);
push(@$c, $_[0]);
}

# delete_alias(&details, [norebuild])
# Deletes one mail alias
sub delete_alias
{
# Remove from the file
local $lref = &read_file_lines($_[0]->{'file'});
local $len = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
splice(@$lref, $_[0]->{'line'}, $len);
&flush_file_lines($_[0]->{'file'});
if (!$_[1]) {
	if (!&rebuild_map_cmd($_[0]->{'file'})) {
		&system_logged("newaliases >/dev/null 2>&1");
		}
	}

# Remove from the cache
local $jfiles = join(",", @{$_[0]->{'files'}});
local $c = $list_aliases_cache{$jfiles};
local $idx = &indexof($_[0], @$c);
splice(@$c, $idx, 1) if ($idx != -1);
&renumber_list($c, $_[0], -$len);
}

# modify_alias(&old, &details, [norebuild])
# Update some existing alias
sub modify_alias
{
# Add to the file
local @newlines;
push(@newlines, &make_table_comment($_[1]->{'cmt'}, 1));
local $str = ($_[1]->{'enabled'} ? "" : "# ") . $_[1]->{'name'} . ": " .
	     join(',', map { /\s/ ? "\"$_\"" : $_ } @{$_[1]->{'values'}});
push(@newlines, $str);
local $lref = &read_file_lines($_[0]->{'file'});
local $len = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
splice(@$lref, $_[0]->{'line'}, $len, @newlines);
&flush_file_lines($_[0]->{'file'});
if (!$_[2]) {
	if (!&rebuild_map_cmd($_[0]->{'file'})) {
		&system_logged("newaliases >/dev/null 2>&1");
		}
	}

local $jfiles = join(",", @{$_[0]->{'files'}});
local $c = $list_aliases_cache{$jfiles};
local $idx = &indexof($_[0], @$c);
$_[1]->{'file'} = $_[0]->{'file'};
$_[1]->{'line'} = $_[0]->{'line'};
$_[1]->{'eline'} = $_[1]->{'line'}+scalar(@newlines)-1;
$c->[$idx] = $_[1] if ($idx != -1);
&renumber_list($c, $_[0], scalar(@newlines) - $len);
}

# alias_type(string)
# Return the type and destination of some alias string
sub alias_type
{
local @rv;
if ($_[0] =~ /^\|$module_config_directory\/autoreply.pl\s+(\S+)/) {
	@rv = (5, $1);
	}
elsif ($_[0] =~ /^\|$module_config_directory\/filter.pl\s+(\S+)/) {
	@rv = (6, $1);
	}
elsif ($_[0] =~ /^\|(.*)$/) {
	@rv = (4, $1);
	}
elsif ($_[0] =~ /^(\/.*)$/) {
	@rv = (3, $1);
	}
elsif ($_[0] =~ /^:include:"(.*)"$/ || $_[0] =~ /^:include:(.*)$/) {
	@rv = (2, $1);
	}
else {
	@rv = (1, $_[0]);
	}
return wantarray ? @rv : $rv[0];
}

# lock_alias_files(&files)
sub lock_alias_files
{
foreach $f (@{$_[0]}) {
	&lock_file($f);
	}
}

# unlock_alias_files(&files)
sub unlock_alias_files
{
foreach $f (@{$_[0]}) {
	&unlock_file($f);
	}
}

# can_edit_alias(&alias)
sub can_edit_alias
{
local ($a) = @_;
foreach my $v (@{$a->{'values'}}) {
	$access{"aedit_".&alias_type($v)} || return 0;
	}
if ($access{'amode'} == 2) {
	$a->{'name'} =~ /$access{'aliases'}/ || return 0;
	}
elsif ($access{'amode'} == 3) {
	$a->{'name'} eq $remote_user || return 0;
	}
return 1;
}

1;

