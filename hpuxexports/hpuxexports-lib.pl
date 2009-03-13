# hpuxexports-lib.pl
# Common functions for managing exports files

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
use Socket;

# list_exports()
# Return a list of all the directories currently being exported
sub list_exports
{
local(@rv);
open(EXP, $config{exports_file});
while(<EXP>) {
	chop; s/#.*//g;
	if (!/\S/) { next; }
	/(\/\S*)\s*/; push(@rv, $1);
	}
close(EXP);
return @rv;
}


# get_exports(directory)
# Return an array containing the following for some directory
#  directory, options
sub get_exports
{
local(@rv);
open(EXP, $config{exports_file});
while(<EXP>) {
	chop; s/#.*//g;
	if (!/\S/) { next; }
	if (/(\/\S*)\s+-(.*)/ && $1 eq $_[0]) {
		# found matching exports with options
		$rv[0] = $1;
                $rv[1] = $2;
		}
	elsif (/(\/\S*)\s+-(.*)/ && $1 eq $_[0]) {
		# found matching exports with options
		$rv[0] = $1;
                $rv[1] = $2;
		}
	}
close(EXP);
return @rv;
}


# create_export(directory, options)
# Add a new exports to the exports file
sub create_export
{
&open_tempfile(EXP, ">> $config{exports_file}");
&print_tempfile(EXP, "$_[0] ");
if ($_[1]) { &print_tempfile(EXP, "-$_[1]\n"); };
&close_tempfile(EXP);
}


# modify_export(old_directory, directory, options)
# Modify an existing exports
sub modify_export
{
local(@exp);
open(EXP, $config{exports_file});
@exp = <EXP>;
close(EXP);
&open_tempfile(EXP, "> $config{exports_file}");
foreach (@exp) {
	chop; ($line = $_) =~ s/#.*//g;
	if ($line =~ /(\/\S+)\s*/ && $1 eq $_[0]) {
		# found exports to change..
		/\s*(\S+)/;
		&print_tempfile(EXP, "$_[1] ");
		if ($_[2]) { &print_tempfile(EXP, "-$_[2]\n"); };
		}
	else {
		# leave this line alone
		&print_tempfile(EXP, "$_\n");
		}
	}
&close_tempfile(EXP);
}


# delete_export(directory)
# Delete the export for a particular directory
sub delete_export
{
local(@exp);
open(EXP, $config{exports_file});
@exp = <EXP>;
close(EXP);
&open_tempfile(EXP, "> $config{exports_file}");
foreach (@exp) {
	chop; ($line = $_) =~ s/#.*//g;
	if ($line !~ /(\/\S+)\s*/ || $1 ne $_[0]) {
		# Leave this line alone
		&print_tempfile(EXP, "$_\n");
		}
	}
&close_tempfile(EXP);
}


# parse_options(string)
# Parse a mount options string like rw=foo,nosuid,... into the associative
# array %options. Parts with no value are given an empty string as the value
sub parse_options
{
local($opt);
undef(%options);
foreach $opt (split(/,/, $_[0])) {
	if ($opt =~ /^([^=]+)=(.*)$/) {
		$options{$1} = $2;
		}
	else {
		$options{$opt} = "";
		}
	}
}

# join_options()
# Returns a list of options from the %options array, in the form used in
# the exports file
sub join_options
{
local(@list, $k);
foreach $k (keys %options) {
	if ($options{$k} eq "") {
		push(@list, $k);
		}
	else {
		push(@list, "$k=$options{$k}");
		}
	}
return join(',', @list);
}

1;

