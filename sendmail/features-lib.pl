# features-lib.pl

# list_features()
# Returns a list of entries in the sendmail.mc file, each of which may be a
# feature or some other unrecognized line
sub list_features
{
local (@rv, $lnum = 0);
open(MC, $config{'sendmail_mc'});
while(<MC>) {
	s/\r|\n//g;
	local $f;
	if (/^FEATURE\((.*)\)/i) {
		local ($name, @v) = &split_m4_params($1);
		$f = { 'type' => 1,
		       'name' => $name,
		       'values' => \@v };
		}
	elsif (/^(define|undefine)\((.*)\)/i) {
		local @v = &split_m4_params($2);
		$f = { 'type' => ($1 eq 'define' ? 2 : 3),
		       'name' => $v[0],
		       'value' => $v[1] };
		}
	elsif (/^MAILER\((.*)\)/i) {
		local ($mailer) = &split_m4_params($1);
		$f = { 'type' => 4,
		       'mailer' => $mailer };
		}
	elsif (/^OSTYPE\((.*)\)/i) {
		local ($ostype) = &split_m4_params($1);
		$f = { 'type' => 5,
		       'line' => $lnum,
		       'index' => scalar(@rv),
		       'ostype' => $ostype };
		}
	else {
		# Unrecognized line
		$f = { 'type' => 0 };
		}
	if ($f) {
		$f->{'line'} = $lnum;
		$f->{'index'} = scalar(@rv);
		$f->{'text'} = $_;
		push(@rv, $f);
		}
	$lnum++;
	}
close(MC);
return @rv;
}

# split_m4_params(string)
sub split_m4_params
{
local @p;
local $str = $_[0];
while($str =~ /^`([^']*)'\s*,?\s*(.*)$/ ||
      $str =~ /^([^\s,]+)\s*,?\s*(.*)$/) {
	push(@p, $1);
	$str = $2;
	}
return @p;
}

# list_feature_types()
sub list_feature_types
{
local (@rv, $f);
opendir(DIR, "$config{'sendmail_features'}/feature");
while($f = readdir(DIR)) {
	if ($f =~ /^(\S+)\.m4$/) {
		local $t = $text{'feat_'.lc($1)};
		push(@rv, [ $1, $t ? "$1 ($t)" : $1 ] );
		}
	}
close(DIR);
return @rv;
}

# list_define_types()
# Returns a list of known define types. Some (but not all) will have human-
# readable descriptions
sub list_define_types
{
local (@rv, $d);
open(DEFINES, "$module_root_directory/defines");
while($d = <DEFINES>) {
	$d =~ s/\r|\n//g;
	local $t = $text{'def_'.lc($d)};
	push(@rv, [ $d, $t ? "$d ($t)" : $d ]);
	}
close(DEFINES);
return @rv;
}

# list_mailer_types()
sub list_mailer_types
{
local (@rv, $f);
opendir(DIR, "$config{'sendmail_features'}/mailer");
while($f = readdir(DIR)) {
	if ($f =~ /^(\S+)\.m4$/) {
		local $t = $text{'mailer_'.lc($1)};
		push(@rv, [ $1, $t ? "$1 ($t)" : $1 ] );
		}
	}
close(DIR);
return @rv;
}

# list_ostype_types()
sub list_ostype_types
{
local (@rv, $f);
opendir(DIR, "$config{'sendmail_features'}/ostype");
while($f = readdir(DIR)) {
	if ($f =~ /^(\S+)\.m4$/) {
		local $t = $text{'ostype_'.lc($1)};
		push(@rv, [ $1, $t ? "$1 ($t)" : $1 ] );
		}
	}
close(DIR);
return @rv;
}

# create_feature(&feature)
# Adds an entry to the end of the M4 config file
sub create_feature
{
&open_tempfile(MC, ">>$config{'sendmail_mc'}");
&print_tempfile(MC, &feature_line($_[0]),"\n");
&close_tempfile(MC);
$_[0]->{'text'} = &feature_line($_[0]);
}

# delete_feature(&feature)
# Deletes one entry from the M4 config file
sub delete_feature
{
local $lref = &read_file_lines($config{'sendmail_mc'});
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
}

# modify_feature(&feature)
# Updates an entry in the M4 config file
sub modify_feature
{
local $lref = &read_file_lines($config{'sendmail_mc'});
splice(@$lref, $_[0]->{'line'}, 1, &feature_line($_[0]));
&flush_file_lines();
$_[0]->{'text'} = &feature_line($_[0]);
}

# swap_features(&feature1, &feature2)
sub swap_features
{
local $lref = &read_file_lines($config{'sendmail_mc'});
splice(@$lref, $_[0]->{'line'}, 1, $_[1]->{'text'});
splice(@$lref, $_[1]->{'line'}, 1, $_[0]->{'text'});
&flush_file_lines();
}

# feature_line(&feature)
sub feature_line
{
if ($_[0]->{'type'} == 0) {
	return $_[0]->{'text'};
	}
elsif ($_[0]->{'type'} == 1) {
	return "FEATURE(".join_m4_params($_[0]->{'name'}, @{$_[0]->{'values'}}).")";
	}
elsif ($_[0]->{'type'} == 2) {
	if ($_[0]->{'value'} eq '') {
		return "define(".join_m4_params($_[0]->{'name'}).")";
		}
	else {
		return "define(".join_m4_params($_[0]->{'name'},
						$_[0]->{'value'}).")";
		}
	}
elsif ($_[0]->{'type'} == 3) {
	return "undefine(".join_m4_params($_[0]->{'name'}).")";
	}
elsif ($_[0]->{'type'} == 4) {
	return "MAILER(".join_m4_params($_[0]->{'mailer'}).")";
	}
elsif ($_[0]->{'type'} == 5) {
	return "OSTYPE(".join_m4_params($_[0]->{'ostype'}).")";
	}
}

sub join_m4_params
{
local @rv = map { $_ =~ /^\d+$/ ? $_ : "`$_'" } @_;
return join(",", @rv);
}

1;

