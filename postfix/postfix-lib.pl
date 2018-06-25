# postfix-lib.pl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron

$POSTFIX_MODULE_VERSION = 5;

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
$access{'postfinger'} = 0 if (&is_readonly_mode());
do 'aliases-lib.pl';

$config{'perpage'} ||= 20;      # a value of 0 can cause problems

# Get the saved version number
$version_file = "$module_config_directory/version";
if (&open_readfile(VERSION, $version_file)) {
	chop($postfix_version = <VERSION>);
	close(VERSION);
	my @vst = stat($version_file);
	my @cst = stat(&has_command($config{'postfix_config_command'}));
	if (@cst && $cst[9] > $vst[9]) {
		# Postfix was probably upgraded
		$postfix_version = undef;
		}
	}

if (!$postfix_version) {
	# Not there .. work it out
	if (&has_command($config{'postfix_config_command'}) &&
	    &backquote_command("$config{'postfix_config_command'} -d mail_version 2>&1", 1) =~ /mail_version\s*=\s*(.*)/) {
		# Got the version
		$postfix_version = $1;
		}

	# And save for other callers
	&open_tempfile(VERSION, ">$version_file", 0, 1);
	&print_tempfile(VERSION, "$postfix_version\n");
	&close_tempfile(VERSION);
	}

if (&compare_version_numbers($postfix_version, 2) >= 0) {
	$virtual_maps = "virtual_alias_maps";
	$ldap_timeout = "ldap_timeout";
	}
else {
	$virtual_maps = "virtual_maps";
	$ldap_timeout = "ldap_lookup_timeout";
	}


sub guess_config_dir
{
    my $answ = $config{'postfix_config_file'};
    $answ =~ /(.*)\/[^\/]*/;
    return $1;
}

$config_dir = guess_config_dir();


## DOC: compared to other webmin modules, here we don't need to parse
##      the config file, because a config command is provided by
##      postfix to read and write the config parameters


# postfix_module_version()
# returns the version of the postfix module
sub postfix_module_version
{
    return $POSTFIX_MODULE_VERSION;
}

# is_postfix_running()
# returns 1 if running, 0 if stopped, calls error() if problem
sub is_postfix_running
{
    my $queuedir = get_current_value("queue_directory");
    my $processid = get_current_value("process_id_directory");

    my $pid_file = $queuedir."/".$processid."/master.pid";
    my $pid = &check_pid_file($pid_file);
    return $pid ? 1 : 0;
}


sub is_existing_parameter
{
    my $out = &backquote_command("$config{'postfix_config_command'} -c $config_dir $_[0] 2>&1", 1);
    return !($out =~ /unknown parameter/);
}


# get_current_value(parameter_name)
# returns a scalar corresponding to the value of the parameter
## modified to allow main_parameter:subparameter 
sub get_current_value
{
# First try to get the value from main.cf directly
my ($name,$key)=split /:/,$_[0];
my $lref = &read_file_lines($config{'postfix_config_file'});
my $out;
my ($begin_flag, $end_flag);
foreach my $l (@$lref) {
	# changes made to this loop by Dan Hartman of Rae Internet /
	# Message Partners for multi-line parsing 2007-06-04
	if ($begin_flag == 1 && $l =~ /\S/ && $l =~ /^(\s+[^#].+)/) {
		# non-comment continuation line, and replace tabs with spaces
		$out .= $1;
		$out =~ s/^\s+/ /;
		}
 	if ($l =~ /^\s*([a-z0-9\_]+)\s*=\s*(.*)|^\s*([a-z0-9\_]+)\s*=\s*$/ &&
 	    $1 . $3 eq $name) {
		# Found the one we're looking for, set a flag
		$out = $2;
		$begin_flag = 1;
		}
 	if ($l =~ /^\s*([a-z0-9\_]+)\s*=\s*(.*)|^\s*([a-z0-9\_]+)\s*=\s*$/ &&
 	    $1 . $3 ne $name && $begin_flag == 1) {
		# after the beginning, another configuration variable
		# found!  Stop!
		$end_flag = 1;
		last;
		}
	}
if (!defined($out)) {
	# Fall back to asking Postfix
	# -h tells postconf not to output the name of the parameter
	$out = &backquote_command("$config{'postfix_config_command'} -c $config_dir -h ".
				  quotemeta($name)." 2>/dev/null", 1);
	if ($?) {
		&error(&text('query_get_efailed', $name, $out));
		}
	elsif ($out =~ /warning:.*unknown\s+parameter/) {
		return undef;
		}
	chop($out);
	}
else {
	# Trim trailing whitespace
	$out =~ s/\s+$//;
	}
if ($key) {
	# If the value asked for was like foo:bar, extract from the value
	# the parts after bar
	my @res = ( );
        while($out =~ /^(.*?)\Q$key\E\s+(\S+)(.*)$/) {
		my $v = $2;
		$out = $3;
		$v =~ s/,$//;
		push(@res, $v);
		}
	return join(" ", @res);
	}
return $out;
}

# if_default_value(parameter_name)
# returns if the value is the default value
sub if_default_value
{
    my $out = &backquote_command("$config{'postfix_config_command'} -c $config_dir -n $_[0] 2>&1", 1);
    if ($?) { &error(&text('query_get_efailed', $_[0], $out)); }
    return ($out eq "");
}

# get_default_value(parameter_name)
# returns the default value of the parameter
sub get_default_value
{
    my $out = &backquote_command("$config{'postfix_config_command'} -c $config_dir -dh $_[0] 2>&1", 1);  # -h tells postconf not to output the name of the parameter
    if ($?) { &error(&text('query_get_efailed', $_[0], $out)); }
    chop($out);
    return $out;
}


# set_current_value(parameter_name, parameter_value, [always-set])
# Update some value in the Postfix configuration file
sub set_current_value
{
    my $value = $_[1];
    if ($value eq "__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__" ||
	$value eq &get_default_value($_[0]) && !$_[2])
    {
	# there is a special case in which there is no static default value ;
	# postfix will handle it correctly if I remove the line in `main.cf'
	my $all_lines = &read_file_lines($config{'postfix_config_file'});
	my $line_of_parameter = -1;
	my $end_line_of_parameter = -1;
	my $i = 0;

	foreach (@{$all_lines})
	{
	    if (/^\s*$_[0]\s*=/) {
		$line_of_parameter = $i;
		$end_line_of_parameter = $i;
	    } elsif ($line_of_parameter >= 0 &&
		     /^\t+\S/) {
		# Multi-line continuation
		$end_line_of_parameter = $i;
	    }
	    $i++;
	}

	if ($line_of_parameter != -1) {
	    splice(@{$all_lines}, $line_of_parameter,
		   $end_line_of_parameter - $line_of_parameter + 1);
	    &flush_file_lines($config{'postfix_config_file'});
	} else {
	    &unflush_file_lines($config{'postfix_config_file'});
	}
    }
    else
    {
        local ($out, $ex);
	$ex = &execute_command(
		"$config{'postfix_config_command'} -c $config_dir ".
		"-e $_[0]=".quotemeta($value), undef, \$out, \$out);
	$ex && &error(&text('query_set_efailed', $_[0], $_[1], $out).
		      "<br> $config{'postfix_config_command'} -c $config_dir ".
		     "-e $_[0]=\"$value\" 2>&1");
        &unflush_file_lines($config{'postfix_config_file'}); # Invalidate cache
    }
}

# check_postfix()
#
sub check_postfix
{
	my $cmd = "$config{'postfix_control_command'} -c $config_dir check";
	my $out = &backquote_command("$cmd 2>&1 </dev/null", 1);
	my $ex = $?;
	if ($ex && &foreign_check("proc")) {
		# Get a better error message
		&foreign_require("proc", "proc-lib.pl");
		$out = &proc::pty_backquote("$cmd 2>&1 </dev/null");
		}
	return $ex ? ($out || "$cmd failed") : undef;
}

# reload_postfix()
#
sub reload_postfix
{
    if (is_postfix_running())
    {
	if (check_postfix()) {
		return $text{'check_error'};
		}
	my $cmd;
	if (!$config{'reload_cmd'}) {
		$cmd = "$config{'postfix_control_command'} -c $config_dir ".
		       "reload";
		}
	else {
		$cmd = $config{'reload_cmd'};
		}
	my $ex = &system_logged("$cmd >/dev/null 2>&1");
	return $ex ? ($out || "$cmd failed") : undef;
    }
    return undef;
}

# stop_postfix()
# Attempts to stop postfix, returning undef on success or an error message
sub stop_postfix
{
local $out;
if ($config{'stop_cmd'}) {
	$out = &backquote_logged("$config{'stop_cmd'} 2>&1");
	}
else {
	$out = &backquote_logged("$config{'postfix_control_command'} -c $config_dir stop 2>&1");
	}
return $? ? "<tt>$out</tt>" : undef;
}

# start_postfix()
# Attempts to start postfix, returning undef on success or an error message
sub start_postfix
{
local $out;
if ($config{'start_cmd'}) {
	$out = &backquote_logged("$config{'start_cmd'} 2>&1");
	}
else {
	$out = &backquote_logged("$config{'postfix_control_command'} -c $config_dir start 2>&1");
	}
return $? ? "<tt>$out</tt>" : undef;
}

# option_radios_freefield(name_of_option, length_of_free_field, [name_of_radiobutton, text_of_radiobutton]+)
# builds an option with variable number of radiobuttons and a free field
# WARNING: *FIRST* RADIO BUTTON *MUST* BE THE DEFAULT VALUE OF POSTFIX
sub option_radios_freefield
{
    my ($name, $length) = ($_[0], $_[1]);

    my $v = &get_current_value($name);
    my $key = 'opts_'.$name;

    my $check_free_field = 1;
    
    my $help = -r &help_file($module_name, "opt_".$name) ?
		&hlink($text{$key}, "opt_".$name) : $text{$key};
    my $rv;

    # first radio button (must be default value!!)
    $rv .= &ui_oneradio($name."_def", "__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__",
		       $_[2], &if_default_value($name));

    $check_free_field = 0 if &if_default_value($name);
    shift;
    
    # other radio buttons
    while (defined($_[2]))
    {
	$rv .= &ui_oneradio($name."_def", $_[2], $_[3], $v eq $_[2]);
	if ($v eq $_[2]) { $check_free_field = 0; }
	shift;
	shift;
    }

    # the free field
    $rv .= &ui_oneradio($name."_def", "__USE_FREE_FIELD__", undef,
		       $check_free_field == 1);
    $rv .= &ui_textbox($name, $check_free_field == 1 ? $v : undef, $length);
    print &ui_table_row($help, $rv, $length > 20 ? 3 : 1);
}

# option_mapfield(name_of_option, length_of_free_field)
# Prints a field for selecting a map, or none
sub option_mapfield
{
    my ($name, $length) = ($_[0], $_[1]);

    my $v = &get_current_value($name);
    my $key = 'opts_'.$name;

    my $check_free_field = 1;
    
    my $help = -r &help_file($module_name, "opt_".$name) ?
		&hlink($text{$key}, "opt_".$name) : $text{$key};
    my $rv;
    $rv .= &ui_oneradio($name."_def", "__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__",
		        $text{'opts_nomap'}, &if_default_value($name));
    $rv .= "<br>\n";

    $check_free_field = 0 if &if_default_value($name);
    shift;
    
    # the free field
    $rv .= &ui_oneradio($name."_def", "__USE_FREE_FIELD__",
		        $text{'opts_setmap'}, $check_free_field == 1);
    $rv .= &ui_textbox($name, $check_free_field == 1 ? $v : undef, $length);
    $rv .= &map_chooser_button($name, $name);
    print &ui_table_row($help, $rv, $length > 20 ? 3 : 1);
}



# option_freefield(name_of_option, length_of_free_field)
# builds an option with free field
sub option_freefield
{
    my ($name, $length) = ($_[0], $_[1]);

    my $v = &get_current_value($name);
    my $key = 'opts_'.$name;
    
    print &ui_table_row(&hlink($text{$key}, "opt_".$name),
	&ui_textbox($name."_def", $v, $length),
	$length > 20 ? 3 : 1);
}


# option_yesno(name_of_option, [help])
# if help is provided, displays help link
sub option_yesno
{
    my $name = $_[0];
    my $v = &get_current_value($name);
    my $key = 'opts_'.$name;

    print &ui_table_row(defined($_[1]) ? &hlink($text{$key}, "opt_".$name)
		       		       : $text{$key},
			&ui_radio($name."_def", lc($v),
				  [ [ "yes", $text{'yes'} ],
				    [ "no", $text{'no'} ] ]));
}

# option_select(name_of_option, &options, [help])
# Shows a drop-down menu of options
sub option_select
{
    my $name = $_[0];
    my $v = &get_current_value($name);
    my $key = 'opts_'.$name;

    print &ui_table_row(defined($_[2]) ? &hlink($text{$key}, "opt_".$name)
				       : $text{$key},
    			&ui_select($name."_def", lc($v), $_[1]));
}



############################################################################
# aliases support    [too lazy to create a aliases-lib.pl :-)]

# get_aliases_files($alias_maps) : @aliases_files
# parses its argument to extract the filenames of the aliases files
# supports multiple alias-files
sub get_aliases_files
{
    return map { $_->[1] }
	       grep { &file_map_type($_->[0]) } &get_maps_types_files($_[0]);
}

# init_new_alias() : $number
# gives a new number of alias
sub init_new_alias
{
    $aliases = &get_aliases();

    my $max_number = 0;

    foreach $trans (@{$aliases})
    {
	if ($trans->{'number'} > $max_number) { $max_number = $trans->{'number'}; }
    }
    
    return $max_number+1;
}

# list_postfix_aliases()
# Returns a list of all aliases. These typically come from a file, but may also
# be taken from a MySQL or LDAP backend
sub list_postfix_aliases
{
local @rv;
foreach my $f (&get_maps_types_files(&get_current_value("alias_maps"))) {
	if (&file_map_type($f->[0])) {
		# We can read this file directly
		local $sofar = scalar(@rv);
		foreach my $a (&list_aliases([ $f->[1] ])) {
			$a->{'num'} += $sofar;
			push(@rv, $a);
			}
		}
	else {
		# Treat as a map
		push(@maps, "$f->[0]:$f->[1]");
		}
	}
if (@maps) {
	# Convert values from MySQL and LDAP maps into alias structures
	local $maps = &get_maps("alias_maps", undef, join(",", @maps));
	foreach my $m (@$maps) {
		local $v = $m->{'value'};
		local @values;
		while($v =~ /^\s*,?\s*()"([^"]+)"(.*)$/ ||
		      $v =~ /^\s*,?\s*(\|)"([^"]+)"(.*)$/ ||
		      $v =~ /^\s*,?\s*()([^,\s]+)(.*)$/) {
			push(@values, $1.$2);
			$v = $3;
			}
		if ($m->{'name'} =~ /^#(.*)$/) {
			$m->{'enabled'} = 0;
			$m->{'name'} = $1;
			}
		else {
			$m->{'enabled'} = 1;
			}
		$m->{'values'} = \@values;
		$m->{'num'} = scalar(@rv);
		push(@rv, $m);
		}
	}
return @rv;
}

# create_postfix_alias(&alias)
# Adds a new alias, either to the local file or another backend
sub create_postfix_alias
{
local ($alias) = @_;
local @afiles = &get_maps_types_files(&get_current_value("alias_maps"));
local $last_type = $afiles[$#afiles]->[0];
local $last_file = $afiles[$#afiles]->[1];
if (&file_map_type($last_type)) {
	# Just adding to a file
	&create_alias($alias, [ $last_file ], 1);
	}
else {
	# Add to appropriate backend map
	if (!$alias->{'enabled'}) {
		$alias->{'name'} = '#'.$alias->{'name'};
		}
	$alias->{'value'} = join(',', map { /\s/ ? "\"$_\"" : $_ }
					  @{$alias->{'values'}});
	&create_mapping("alias_maps", $alias, undef, "$last_type:$last_file");
	}
}

# delete_postfix_alias(&alias)
# Delete an alias, either from the files or from a MySQL or LDAP map
sub delete_postfix_alias
{
local ($alias) = @_;
if ($alias->{'map_type'}) {
	# This was from a map
	&delete_mapping("alias_maps", $alias);
	}
else {
	# Regular alias
	&delete_alias($alias, 1);
	}
}

# modify_postfix_alias(&oldalias, &alias)
# Update an alias, either in a file or in a map
sub modify_postfix_alias
{
local ($oldalias, $alias) = @_;
if ($oldalias->{'map_type'}) {
	# In the map
	if (!$alias->{'enabled'}) {
		$alias->{'name'} = '#'.$alias->{'name'};
		}
	$alias->{'value'} = join(',', map { /\s/ ? "\"$_\"" : $_ }
					  @{$alias->{'values'}});
	&modify_mapping("alias_maps", $oldalias, $alias);
	}
else {
	# Regular alias in a file
	&modify_alias($oldalias, $alias);
	}
}

# renumber_list(&list, &position-object, lines-offset)
sub renumber_list
{
return if (!$_[2]);
local $e;
foreach $e (@{$_[0]}) {
	next if (defined($e->{'alias_file'}) &&
	         $e->{'alias_file'} ne $_[1]->{'alias_file'});
	next if (defined($e->{'map_file'}) &&
	         $e->{'map_file'} ne $_[1]->{'map_file'});
	$e->{'line'} += $_[2] if ($e->{'line'} > $_[1]->{'line'});
	$e->{'eline'} += $_[2] if (defined($e->{'eline'}) &&
				   $e->{'eline'} > $_[1]->{'eline'});
	}
}

# save_options(%options, [&always-save])
#
sub save_options
{
    if (check_postfix()) { &error("$text{'check_error'}"); }

    my %options = %{$_[0]};

    foreach $key (keys %options)
    {
	if ($key =~ /_def$/)
	{
	    (my $param = $key) =~ s/_def$//;
	    my $value = $options{$key} eq "__USE_FREE_FIELD__" ?
			$options{$param} : $options{$key};
	    $value =~ s/\0/, /g;
            if ($value =~ /(\S+):(\/\S+)/ && $access{'dir'} ne '/') {
		foreach my $f (&get_maps_files("$1:$2")) {
		   if (!&is_under_directory($access{'dir'}, $f)) {
			&error(&text('opts_edir', $access{'dir'}));
		   }
		}
            }
	    &set_current_value($param, $value,
			       &indexof($param, @{$_[1]}) >= 0);
	}
    }
}


# regenerate_aliases
#
sub regenerate_aliases
{
    local $out;
    $access{'aliases'} || error($text{'regenerate_ecannot'});
    if (get_current_value("alias_maps") eq "")
    {
	$out = &backquote_logged("$config{'postfix_newaliases_command'} 2>&1");
	if ($?) { &error(&text('regenerate_alias_efailed', $out)); }
    }
    else
    {
	local $map;
	foreach $map (get_maps_types_files(get_real_value("alias_maps")))
	{
	    if (&file_map_type($map->[0])) {
		    my $cmd = $config{'postfix_aliases_table_command'};
		    if ($cmd =~ /newaliases/) {
			$cmd .= " -oA$map->[1]";
		    } else {
			$cmd .= " $map->[1]";
		    }
		    $out = &backquote_logged("$cmd 2>&1");
		    if ($?) { &error(&text('regenerate_table_efailed', $map->[1], $out)); }
	    }
	}
    }
}


# regenerate_relocated_table()
sub regenerate_relocated_table
{
    &regenerate_any_table("relocated_maps");
}


# regenerate_virtual_table()
sub regenerate_virtual_table
{
    &regenerate_any_table($virtual_maps);
}

# regenerate_bcc_table()
sub regenerate_bcc_table
{
    &regenerate_any_table("sender_bcc_maps");
}

sub regenerate_relay_recipient_table
{ 
    &regenerate_any_table("relay_recipient_maps");
}

sub regenerate_sender_restrictions_table
{
    &regenerate_any_table("smtpd_sender_restrictions");
}

# regenerate_recipient_bcc_table()
sub regenerate_recipient_bcc_table
{
    &regenerate_any_table("recipient_bcc_maps");
}

# regenerate_header_table()
sub regenerate_header_table
{
    &regenerate_any_table("header_checks");
}

# regenerate_body_table()
sub regenerate_body_table
{
    &regenerate_any_table("body_checks");
}

# regenerate_canonical_table
#
sub regenerate_canonical_table
{
    &regenerate_any_table("canonical_maps");
    &regenerate_any_table("recipient_canonical_maps");
    &regenerate_any_table("sender_canonical_maps");
}


# regenerate_transport_table
#
sub regenerate_transport_table
{
    &regenerate_any_table("transport_maps");
}

# regenerate_dependent_table
#
sub regenerate_dependent_table
{
    &regenerate_any_table("sender_dependent_default_transport_maps");
}


# regenerate_any_table($parameter_where_to_find_the_table_names,
#		       [ &force-files ], [ after-tag ])
#
sub regenerate_any_table
{
    my ($name, $force, $after) = @_;
    my @files;
    if ($force) {
	@files = map { [ "hash", $_ ] } @$force;
    } elsif (&get_current_value($name) ne "") {
	my $value = &get_real_value($name);
	if ($after) {
		$value =~ s/^.*\Q$after\E\s+(\S+).*$/$1/ || return;
		}
	@files = &get_maps_types_files($value);
    }
    foreach my $map (@files)
    {
        next unless $map;
	if (&file_map_type($map->[0]) &&
	    $map->[0] ne 'regexp' && $map->[0] ne 'pcre') {
		local $out = &backquote_logged("$config{'postfix_lookup_table_command'} -c $config_dir $map->[0]:$map->[1] 2>&1");
		if ($?) { &error(&text('regenerate_table_efailed', $map->[1], $out)); }
	}
    }
}



############################################################################
# maps [canonical, virtual, transport] support

# get_maps_files($maps_param) : @maps_files
# parses its argument to extract the filenames of the mapping files
# supports multiple maps-files
sub get_maps_files
{
    $_[0] =~ /:(\/[^,\s]*)(.*)/ || return ( );
    (my $returnvalue, my $recurse) = ( $1, $2 );

    return ( $returnvalue,
	     ($recurse =~ /:\/[^,\s]*/) ?
	         &get_maps_files($recurse)
	     :
	         ()
           )
}

 
# get_maps($maps_name, [&force-files], [force-map]) : \@maps
# Construct the mappings database taken from the map files given from the
# parameters.
sub get_maps
{
    if (!defined($maps_cache{$_[0]}))
    {
	my @maps_files = $_[1] ? (map { [ "hash", $_ ] } @{$_[1]}) :
			 $_[2] ? &get_maps_types_files($_[2]) :
			         &get_maps_types_files(&get_real_value($_[0]));
	my $number = 0;
	$maps_cache{$_[0]} = [ ];
	foreach my $maps_type_file (@maps_files)
	{
	    my ($maps_type, $maps_file) = @$maps_type_file;

	    if (&file_map_type($maps_type)) {
		    # Read a file on disk
		    &open_readfile(MAPS, $maps_file);
		    my $i = 0;
		    my $cmt;
		    while (<MAPS>)
		    {
			s/\r|\n//g;	# remove newlines
			if (/^\s*#+\s*(.*)/) {
			    # A comment line
			    $cmt = &is_table_comment($_);
			    }
			elsif (/^\s*(\/[^\/]*\/[a-z]*)\s+([^#]*)/ ||
			       /^\s*([^\s]+)\s+([^#]*)/) {
			    # An actual map
			    $number++;
			    my %map;
			    $map{'name'} = $1;
			    $map{'value'} = $2;
			    $map{'line'} = $cmt ? $i-1 : $i;
			    $map{'eline'} = $i;
			    $map{'map_file'} = $maps_file;
			    $map{'map_type'} = $maps_type;
			    $map{'file'} = $maps_file;
			    $map{'number'} = $number;
			    $map{'cmt'} = $cmt;
			    push(@{$maps_cache{$_[0]}}, \%map);
			    $cmt = undef;
			    }
			else {
			    $cmt = undef;
			    }
			$i++;
		    }
		    close(MAPS);

	     } elsif ($maps_type eq "mysql") {
		    # Get from a MySQL database
		    local $conf = &mysql_value_to_conf($maps_file);
		    local $dbh = &connect_mysql_db($conf);
		    ref($dbh) || &error($dbh);
		    local $cmd = $dbh->prepare(
				       "select ".$conf->{'where_field'}.
				       ",".$conf->{'select_field'}.
				       " from ".$conf->{'table'}.
				       " where 1 = 1 ".
				       $conf->{'additional_conditions'});
		    if (!$cmd || !$cmd->execute()) {
			&error(&text('mysql_elist',
			     "<tt>".&html_escape($dbh->errstr)."</tt>"));
			}
		    while(my ($k, $v) = $cmd->fetchrow()) {
			$number++;
			my %map;
			$map{'name'} = $k;
			$map{'value'} = $v;
			$map{'key'} = $k;
			$map{'map_file'} = $maps_file;
			$map{'map_type'} = $maps_type;
			$map{'number'} = $number;
			push(@{$maps_cache{$_[0]}}, \%map);
		    }
		    $cmd->finish();
		    $dbh->disconnect();

	     } elsif ($maps_type eq "ldap") {
		    # Get from an LDAP database
	     	    local $conf = &ldap_value_to_conf($maps_file);
		    local $ldap = &connect_ldap_db($conf);
		    ref($ldap) || &error($ldap);
		    local ($name_attr, $filter) = &get_ldap_key($conf);
		    local $scope = $conf->{'scope'} || 'sub';
		    local $rv = $ldap->search(base => $conf->{'search_base'},
					      scope => $scope,
					      filter => $filter);
		    if (!$rv || $rv->code) {
			# Search failed!
			&error(&text('ldap_equery',
				     "<tt>$conf->{'search_base'}</tt>",
				     "<tt>".&html_escape($rv->error)."</tt>"));
		    }
		    foreach my $o ($rv->all_entries) {
			$number++;
			my %map;
			$map{'name'} = $o->get_value($name_attr);
			$map{'value'} = $o->get_value(
				$conf->{'result_attribute'} || "maildrop");
			$map{'dn'} = $o->dn();
			$map{'map_file'} = $maps_file;
			$map{'map_type'} = $maps_type;
			$map{'number'} = $number;
			push(@{$maps_cache{$_[0]}}, \%map);
		    }
	     }
	}
    }
    return $maps_cache{$_[0]};
}


# generate_map_edit(name, desc, [wide], [nametitle], [valuetitle])
# Prints a table showing map contents, with links to edit and add
sub generate_map_edit
{
    # Check if map is set
    if (&get_current_value($_[0]) eq "")
    {
	print "<b>$text{'no_map2'}</b><p>\n";
        return;
    }

    # Make sure the user is allowed to edit them
    foreach my $f (&get_maps_types_files(&get_current_value($_[0]))) {
      if (&file_map_type($f->[0])) {
	  &is_under_directory($access{'dir'}, $f->[1]) ||
		&error(&text('mapping_ecannot', $access{'dir'}));
      }
    }

    # Make sure we *can* edit them
    foreach my $f (&get_maps_types_files(&get_current_value($_[0]))) {
       my $err = &can_access_map(@$f);
       if ($err) {
	  print "<b>",&text('map_cannot', $err),"</b><p>\n";
	  return;
       }
    }

    my $mappings = &get_maps($_[0]);
    my $nt = $_[3] || $text{'mapping_name'};
    my $vt = $_[4] || $text{'mapping_value'};

    local @links = ( &ui_link("edit_mapping.cgi?map_name=$_[0]",
			      $text{'new_mapping'}),);
    if ($access{'manual'} && &can_map_manual($_[0])) {
	push(@links, &ui_link("edit_manual.cgi?map_name=$_[0]",
			      $text{'new_manual'}));
	}

    if ($#{$mappings} ne -1)
    {
        # Map description
	print $_[1],"<p>\n";

	# Sort the map
	if ($config{'sort_mode'} == 1) {
		if ($_[0] eq $virtual_maps) {
			@{$mappings} = sort sort_by_domain @{$mappings};
			}
		else {
			@{$mappings} = sort { $a->{'name'} cmp $b->{'name'} }
					    @{$mappings};
			}
		}

	# Split into two columns, if needed
	my @parts;
	my $split_index = int(($#{$mappings})/2);
	if ($config{'columns'} == 2) {
		@parts = ( [ @{$mappings}[0 .. $split_index] ],
			   [ @{$mappings}[$split_index+1 .. $#{$mappings} ] ] );
		}
	else {
		@parts = ( $mappings );
		}
	
	# Start of the overall form
	print &ui_form_start("delete_mappings.cgi", "post");
	print &ui_hidden("map_name", $_[0]),"\n";
	unshift(@links, &select_all_link("d", 1),
			&select_invert_link("d", 1));
	print &ui_links_row(\@links);

	my @grid;
	foreach my $p (@parts) {
		# Build one table
		my @table;
		foreach my $map (@$p) {
			push(@table, [
			    { 'type' => 'checkbox', 'name' => 'd',
			      'value' => $map->{'name'} },
			    "<a href=\"edit_mapping.cgi?num=$map->{'number'}&".
			     "map_name=$_[0]\">".&html_escape($map->{'name'}).
			     "</a>",
			    &html_escape($map->{'value'}),
			    $config{'show_cmts'} ?
			     ( &html_escape($map->{'cmt'}) ) : ( ),
			    ]);
			}

		# Add a table to the grid
		push(@grid, &ui_columns_table(
			[ "", $nt, $vt,
                          $config{'show_cmts'} ? ( $text{'mapping_cmt'} ) : ( ),
			],
			100,
			\@table));
		}
	if (@grid == 1) {
		print $grid[0];
		}
	else {
		print &ui_grid_table(\@grid, 2, 100,
			[ "width=50%", "width=50%" ]);
		}
	
 	# Main form end
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'mapping_delete'} ] ]);
    }
    else {
        # None, so just show edit link
        print "<b>$text{'mapping_none'}</b><p>\n";
        print &ui_links_row(\@links);
    }
}


# create_mapping(map, &mapping, [&force-files], [force-map])
sub create_mapping
{
&get_maps($_[0], $_[2], $_[3]);	# force cache init
my @maps_files = $_[2] ? (map { [ "hash", $_ ] } @{$_[2]}) :
		 $_[3] ? &get_maps_types_files($_[3]) :
		         &get_maps_types_files(&get_real_value($_[0]));

# If multiple maps, find a good one to add to .. avoid regexp if we can
my $last_map;
if (@maps_files == 1) {
	$last_map = $maps_files[0];
	}
else {
	for(my $i=$#maps_files; $i>=0; $i--) {
		if ($maps_files[$i]->[0] ne 'regexp' &&
	 	    $maps_files[$i]->[0] ne 'pcre') {
			$last_map = $maps_files[$i];
			last;
			}
		}
	$last_map ||= $maps_files[$#maps_files];	# Fall back to last one
	}
my ($maps_type, $maps_file) = @$last_map;

if (&file_map_type($maps_type)) {
	# Adding to a regular file
	local $lref = &read_file_lines($maps_file);
	$_[1]->{'line'} = scalar(@$lref);
	push(@$lref, &make_table_comment($_[1]->{'cmt'}));
	push(@$lref, "$_[1]->{'name'}\t$_[1]->{'value'}");
	$_[1]->{'eline'} = scalar(@$lref)-1;
	&flush_file_lines($maps_file);
	}
elsif ($maps_type eq "mysql") {
	# Adding to a MySQL table
	local $conf = &mysql_value_to_conf($maps_file);
	local $dbh = &connect_mysql_db($conf);
	ref($dbh) || &error($dbh);
	local $cmd = $dbh->prepare("insert into ".$conf->{'table'}." ".
				   "(".$conf->{'where_field'}.",".
					$conf->{'select_field'}.") values (".
				   "?, ?)");
	if (!$cmd || !$cmd->execute($_[1]->{'name'}, $_[1]->{'value'})) {
		&error(&text('mysql_eadd',
			     "<tt>".&html_escape($dbh->errstr)."</tt>"));
		}
	$cmd->finish();
	$dbh->disconnect();
	$_[1]->{'key'} = $_[1]->{'name'};
	}
elsif ($maps_type eq "ldap") {
	# Adding to an LDAP database
	local $conf = &ldap_value_to_conf($maps_file);
	local $ldap = &connect_ldap_db($conf);
	ref($ldap) || &error($ldap);
	local @classes = split(/\s+/, $config{'ldap_class'} ||
				      "inetLocalMailRecipient");
	local @attrs = ( "objectClass", \@classes );
	local $name_attr = &get_ldap_key($conf);
	push(@attrs, $name_attr, $_[1]->{'name'});
	push(@attrs, $conf->{'result_attribute'} || "maildrop",
		     $_[1]->{'value'});
	push(@attrs, &split_props($config{'ldap_attrs'}));
	local $dn = &make_map_ldap_dn($_[1], $conf);
	if ($dn =~ /^([^=]+)=([^, ]+)/ && !&in_props(\@attrs, $1)) {
		push(@attrs, $1, $2);
		}

	# Make sure the parent DN exists - for example, when adding a domain
	&ensure_ldap_parent($ldap, $dn);

	# Actually add
	local $rv = $ldap->add($dn, attr => \@attrs);
	if ($rv->code) {
		&error(&text('ldap_eadd', "<tt>$dn</tt>",
			     "<tt>".&html_escape($rv->error)."</tt>"));
		}
	$_[1]->{'dn'} = $dn;
	}

# Update the in-memory cache
$_[1]->{'map_type'} = $maps_type;
$_[1]->{'map_file'} = $maps_file;
$_[1]->{'file'} = $maps_file;
$_[1]->{'number'} = scalar(@{$maps_cache{$_[0]}});
push(@{$maps_cache{$_[0]}}, $_[1]);
}


# delete_mapping(map, &mapping)
sub delete_mapping
{
if (&file_map_type($_[1]->{'map_type'}) || !$_[1]->{'map_type'}) {
	# Deleting from a file
	local $lref = &read_file_lines($_[1]->{'map_file'});
	local $dl = $lref->[$_[1]->{'eline'}];
	local $len = $_[1]->{'eline'} - $_[1]->{'line'} + 1;
	if (($dl =~ /^\s*(\/[^\/]*\/[a-z]*)\s+([^#]*)/ ||
	     $dl =~ /^\s*([^\s]+)\s+([^#]*)/) &&
	    $1 eq $_[1]->{'name'}) {
		# Found a valid line to remove
		splice(@$lref, $_[1]->{'line'}, $len);
		}
	else {
		print STDERR "Not deleting line $_[1]->{'line'} ",
			     "from $_[1]->{'file'} for key ",
			     "$_[1]->{'name'} which actually contains $dl\n";
		}
	&flush_file_lines($_[1]->{'map_file'});
	&renumber_list($maps_cache{$_[0]}, $_[1], -$len);
	local $idx = &indexof($_[1], @{$maps_cache{$_[0]}});
	if ($idx >= 0) {
		# Take out of cache
		splice(@{$maps_cache{$_[0]}}, $idx, 1);
		}
	}
elsif ($_[1]->{'map_type'} eq 'mysql') {
	# Deleting from MySQL
	local $conf = &mysql_value_to_conf($_[1]->{'map_file'});
	local $dbh = &connect_mysql_db($conf);
	ref($dbh) || &error($dbh);
	local $cmd = $dbh->prepare("delete from ".$conf->{'table'}.
				   " where ".$conf->{'where_field'}." = ?".
				   " ".$conf->{'additional_conditions'});
	if (!$cmd || !$cmd->execute($_[1]->{'key'})) {
		&error(&text('mysql_edelete',
			     "<tt>".&html_escape($dbh->errstr)."</tt>"));
		}
	$cmd->finish();
	$dbh->disconnect();
	}
elsif ($_[1]->{'map_type'} eq 'ldap') {
	# Deleting from LDAP
	local $conf = &ldap_value_to_conf($_[1]->{'map_file'});
	local $ldap = &connect_ldap_db($conf);
	ref($ldap) || &error($ldap);
	local $rv = $ldap->delete($_[1]->{'dn'});
	if ($rv->code) {
		&error(&text('ldap_edelete', "<tt>$_[1]->{'dn'}</tt>",
			     "<tt>".&html_escape($rv->error)."</tt>"));
		}
	}

# Delete from in-memory cache
local $idx = &indexof($_[1], @{$maps_cache{$_[0]}});
splice(@{$maps_cache{$_[0]}}, $idx, 1) if ($idx != -1);
}


# modify_mapping(map, &oldmapping, &newmapping)
sub modify_mapping
{
if (&file_map_type($_[1]->{'map_type'}) || !$_[1]->{'map_type'}) {
	# Modifying in a file
	local $lref = &read_file_lines($_[1]->{'map_file'});
	local $oldlen = $_[1]->{'eline'} - $_[1]->{'line'} + 1;
	local @newlines;
	push(@newlines, &make_table_comment($_[2]->{'cmt'}));
	push(@newlines, "$_[2]->{'name'}\t$_[2]->{'value'}");
	splice(@$lref, $_[1]->{'line'}, $oldlen, @newlines);
	&flush_file_lines($_[1]->{'map_file'});
	&renumber_list($maps_cache{$_[0]}, $_[1], scalar(@newlines)-$oldlen);
	local $idx = &indexof($_[1], @{$maps_cache{$_[0]}});
	if ($idx >= 0) {
		# Update in cache
		$_[2]->{'map_file'} = $_[1]->{'map_file'};
		$_[2]->{'map_type'} = $_[1]->{'map_type'};
		$_[2]->{'line'} = $_[1]->{'line'};
		$_[2]->{'eline'} = $_[1]->{'eline'};
		$maps_cache{$_[0]}->[$idx] = $_[2];
		}
	}
elsif ($_[1]->{'map_type'} eq 'mysql') {
	# Updating in MySQL
	local $conf = &mysql_value_to_conf($_[1]->{'map_file'});
	local $dbh = &connect_mysql_db($conf);
	ref($dbh) || &error($dbh);
	local $cmd = $dbh->prepare("update ".$conf->{'table'}.
				   " set ".$conf->{'where_field'}." = ?,".
				   " ".$conf->{'select_field'}." = ?".
				   " where ".$conf->{'where_field'}." = ?".
				   " ".$conf->{'additional_conditions'});
	if (!$cmd || !$cmd->execute($_[2]->{'name'}, $_[2]->{'value'},
				    $_[1]->{'key'})) {
		&error(&text('mysql_eupdate',
			     "<tt>".&html_escape($dbh->errstr)."</tt>"));
		}
	$cmd->finish();
	$dbh->disconnect();
	}
elsif ($_[1]->{'map_type'} eq 'ldap') {
	# Updating in LDAP
	local $conf = &ldap_value_to_conf($_[1]->{'map_file'});
	local $ldap = &connect_ldap_db($conf);
	ref($ldap) || &error($ldap);

	# Work out attribute changes
	local %replace;
	local $name_attr = &get_ldap_key($conf);
	$replace{$name_attr} = [ $_[2]->{'name'} ];
	$replace{$conf->{'result_attribute'} || "maildrop"} =
		[ $_[2]->{'value'} ];

	# Work out new DN, if needed
	local $newdn = &make_map_ldap_dn($_[2], $conf);
	if ($_[1]->{'name'} ne $_[2]->{'name'} &&
	    $_[1]->{'dn'} ne $newdn) {
		# Changed .. update the object in LDAP
		&ensure_ldap_parent($ldap, $newdn);
		local ($newprefix, $newrest) = split(/,/, $newdn, 2);
		local $rv = $ldap->moddn($_[1]->{'dn'},
					 newrdn => $newprefix,
					 newsuperior => $newrest);
		if ($rv->code) {
			&error(&text('ldap_erename',
				     "<tt>$_[1]->{'dn'}</tt>",
				     "<tt>$newdn</tt>",
				     "<tt>".&html_escape($rv->error)."</tt>"));
			}
		$_[2]->{'dn'} = $newdn;
		if ($newdn =~ /^([^=]+)=([^, ]+)/) {
			$replace{$1} = [ $2 ];
			}
		}
	else {
		$_[2]->{'dn'} = $_[1]->{'dn'};
		}

	# Modify attributes
	local $rv = $ldap->modify($_[2]->{'dn'}, replace => \%replace);
	if ($rv->code) {
		&error(&text('ldap_emodify',
			     "<tt>$_[2]->{'dn'}</tt>",
			     "<tt>".&html_escape($rv->error)."</tt>"));
		}
	}

# Update in-memory cache
local $idx = &indexof($_[1], @{$maps_cache{$_[0]}});
$_[2]->{'map_file'} = $_[1]->{'map_file'};
$_[2]->{'map_type'} = $_[1]->{'map_type'};
$_[2]->{'file'} = $_[1]->{'file'};
$_[2]->{'line'} = $_[1]->{'line'};
$_[2]->{'eline'} = $_[2]->{'cmt'} ? $_[1]->{'line'}+1 : $_[1]->{'line'};
$maps_cache{$_[0]}->[$idx] = $_[2] if ($idx != -1);
}

# make_map_ldap_dn(&map, &conf)
# Work out an LDAP DN for a map
sub make_map_ldap_dn
{
local ($map, $conf) = @_;
local $dn;
local $scope = $conf->{'scope'} || 'sub';
$scope = 'base' if (!$config{'ldap_doms'});	# Never create sub-domains
local $id = $config{'ldap_id'} || 'cn';
if ($map->{'name'} =~ /^(\S+)\@(\S+)$/ && $scope ne 'base') {
	# Within a domain
	$dn = "$id=$1,cn=$2,$conf->{'search_base'}";
	}
elsif ($map->{'name'} =~ /^\@(\S+)$/ && $scope ne 'base') {
	# Domain catchall
	$dn = "$id=default,cn=$1,$conf->{'search_base'}";
	}
else {
	# Some other string
	$dn = "$id=$map->{'name'},$conf->{'search_base'}";
	}
return $dn;
}

# get_ldap_key(&config)
# Returns the attribute name for the LDAP key. May call &error
sub get_ldap_key
{
local ($conf) = @_;
local ($filter, $name_attr) = @_;
if ($conf->{'query_filter'}) {
	$filter = $conf->{'query_filter'};
	$conf->{'query_filter'} =~ /([a-z0-9]+)=\%[su]/i ||
		&error("Could not get attribute from ".
		       $conf->{'query_filter'});
	$name_attr = $1;
	$filter = "($filter)" if ($filter !~ /^\(/);
	$filter =~ s/\%s/\*/g;
	}
else {
	$filter = "(mailacceptinggeneralid=*)";
	$name_attr = "mailacceptinggeneralid";
	}
return wantarray ? ( $name_attr, $filter ) : $name_attr;
}

# ensure_ldap_parent(&ldap, dn)
# Create the parent of some DN if needed
sub ensure_ldap_parent
{
local ($ldap, $dn) = @_;
local $pdn = $dn;
$pdn =~ s/^([^,]+),//;
local $rv = $ldap->search(base => $pdn, scope => 'base',
			  filter => "(objectClass=top)",
			  sizelimit => 1);
if (!$rv || $rv->code || !$rv->all_entries) {
	# Does not .. so add it
	local @pclasses = ( "top" );
	local @pattrs = ( "objectClass", \@pclasses );
	local $rv = $ldap->add($pdn, attr => \@pattrs);
	}
}

# init_new_mapping($maps_parameter) : $number
# gives a new number of mapping
sub init_new_mapping
{
my $maps = &get_maps($_[0]);
my $max_number = 0;
foreach $trans (@{$maps}) {
	if ($trans->{'number'} > $max_number) {
		$max_number = $trans->{'number'};
		}
	}
return $max_number+1;
}

# postfix_mail_file(user|user-details-list)
sub postfix_mail_file
{
local @s = &postfix_mail_system();
if ($s[0] == 0) {
	return "$s[1]/$_[0]";
	}
elsif (@_ > 1) {
	return "$_[7]/$s[1]";
	}
else {
	local @u = getpwnam($_[0]);
	return "$u[7]/$s[1]";
	}
}

# postfix_mail_system()
# Returns 0 and the spool dir for sendmail style,
#         1 and the mbox filename for ~/Mailbox style
#         2 and the maildir name for ~/Maildir style
sub postfix_mail_system
{
if (!scalar(@mail_system_cache)) {
	local $home_mailbox = &get_current_value("home_mailbox");
	if ($home_mailbox) {
		@mail_system_cache = $home_mailbox =~ /^(.*)\/$/ ?
			(2, $1) : (1, $home_mailbox);
		}
	else {
		local $mail_spool_directory =
			&get_current_value("mail_spool_directory");
		@mail_system_cache = (0, $mail_spool_directory);
		}
	}
return wantarray ? @mail_system_cache : $mail_system_cache[0];
}

# list_queue([error-on-failure])
# Returns a list of strutures, each containing details of one queued message
sub list_queue
{
local ($throw) = @_;
local @qfiles;
local $out = &backquote_command("$config{'mailq_cmd'} 2>&1 </dev/null");
&error("$config{'mailq_cmd'} failed : ".&html_escape($out)) if ($? && $throw);
foreach my $l (split(/\r?\n/, $out)) {
	next if ($l =~ /^(\S+)\s+is\s+empty/i ||
		 $l =~ /^\s+Total\s+requests:/i);
	if ($l =~ /^([^\s\*\!]+)[\*\!]?\s*(\d+)\s+(\S+\s+\S+\s+\d+\s+\d+:\d+:\d+)\s+(.*)/) {
		local $q = { 'id' => $1, 'size' => $2,
                             'date' => $3, 'from' => $4 };
		if (defined(&parse_mail_date)) {
			local $t = &parse_mail_date($q->{'date'});
			if ($t) {
				$q->{'date'} = &make_date($t, 0, 'yyyy/mm/dd');
				$q->{'time'} = $t;
				}
			}
		push(@qfiles, $q);
		}
	elsif ($l =~ /\((.*)\)/ && @qfiles) {
		$qfiles[$#qfiles]->{'status'} = $1;
		}
	elsif ($l =~ /^\s+(\S+)/ && @qfiles) {
		$qfiles[$#qfiles]->{'to'} .= "$1 ";
		}
	}
return @qfiles;
}

# parse_queue_file(id)
# Parses a postfix mail queue file into a standard mail structure
sub parse_queue_file
{
local @qfiles = ( &recurse_files("$config{'mailq_dir'}/active"),
		  &recurse_files("$config{'mailq_dir'}/incoming"),
		  &recurse_files("$config{'mailq_dir'}/deferred"),
		  &recurse_files("$config{'mailq_dir'}/corrupt"),
		  &recurse_files("$config{'mailq_dir'}/hold"),
		  &recurse_files("$config{'mailq_dir'}/maildrop"),
		);
local $f = $_[0];
local ($file) = grep { $_ =~ /\/$f$/ } @qfiles;
return undef if (!$file);
local $mode = 0;
local ($mail, @headers);
&open_execute_command(QUEUE, "$config{'postcat_cmd'} ".quotemeta($file), 1, 1);
while(<QUEUE>) {
	if (/^\*\*\*\s+MESSAGE\s+CONTENTS/ && !$mode) {	   # Start of headers
		$mode = 1;
		}
	elsif (/^\*\*\*\s+HEADER\s+EXTRACTED/ && $mode) {  # End of email
		last;
		}
	elsif ($mode == 1 && /^\s*$/) {			   # End of headers
		$mode = 2;
		}
	elsif ($mode == 1 && /^(\S+):\s*(.*)/) {	   # Found a header
		push(@headers, [ $1, $2 ]);
		}
	elsif ($mode == 1 && /^(\s+.*)/) {		   # Header continuation
		$headers[$#headers]->[1] .= $1 unless($#headers < 0);
		}
	elsif ($mode == 2) {				   # Part of body
		$mail->{'size'} += length($_);
		$mail->{'body'} .= $_;
		}
	}
close(QUEUE);
$mail->{'headers'} = \@headers;
foreach $h (@headers) {
	$mail->{'header'}->{lc($h->[0])} = $h->[1];
	}
return $mail;
}

# recurse_files(dir)
sub recurse_files
{
opendir(DIR, &translate_filename($_[0])) || return ( $_[0] );
local @dir = readdir(DIR);
closedir(DIR);
local ($f, @rv);
foreach $f (@dir) {
	push(@rv, &recurse_files("$_[0]/$f")) if ($f !~ /^\./);
	}
return @rv;
}

sub sort_by_domain
{
local ($a1, $a2, $b1, $b2);
if ($a->{'name'} =~ /^(.*)\@(.*)$/ && (($a1, $a2) = ($1, $2)) &&
    $b->{'name'} =~ /^(.*)\@(.*)$/ && (($b1, $b2) = ($1, $2))) {
	return $a2 cmp $b2 ? $a2 cmp $b2 : $a1 cmp $b1;
	}
else {
	return $a->{'name'} cmp $b->{'name'};
	}
}

# before_save()
# Copy the postfix config file to a backup file, for reversion if
# a post-save check fails
sub before_save
{
if ($config{'check_config'} && !defined($save_file)) {
	$save_file = &transname();
	&execute_command("cp $config{'postfix_config_file'} $save_file");
	}
}

sub after_save
{
if (defined($save_file)) {
	local $err = &check_postfix();
	if ($err) {
		&execute_command("mv $save_file $config{'postfix_config_file'}");
		&error(&text('after_err', "<pre>$err</pre>"));
		}
	else {
		unlink($save_file);
		$save_file = undef;
		}
	}
}

# get_real_value(parameter_name)
# Returns the value of a parameter, with $ substitions done
sub get_real_value
{
my ($name) = @_;
my $v = &get_current_value($name);
if ($postfix_version >= 2.1 && $v =~ /\$/) {
	# Try to use the built-in command to expand the param
	my $out = &backquote_command("$config{'postfix_config_command'} -c $config_dir -x -h ".
				     quotemeta($name)." 2>/dev/null", 1);
	if (!$? && $out !~ /warning:.*unknown\s+parameter/) {
		chop($out);
		return $out;
		}
	}
$v =~ s/\$(\{([^\}]+)\}|([A-Za-z0-9\.\-\_]+))/get_real_value($2 || $3)/ge;
return $v;
}

# ensure_map(name)
# Create some map text file, if needed
sub ensure_map
{
foreach my $mf (&get_maps_files(&get_real_value($_[0]))) {
	if ($mf =~ /^\// && !-e $mf) {
		&open_lock_tempfile(TOUCH, ">$mf", 1) ||
			&error(&text("efilewrite", $mf, $!));
		&close_tempfile(TOUCH);
		&set_ownership_permissions(undef, undef, 0755, $mf);
		}
	}
}

# Functions for editing the header_checks map nicely
sub edit_name_header_checks
{
return &ui_table_row($text{'header_name'},
		     &ui_textbox("name", $_[0]->{'name'}, 60));
}

sub parse_name_header_checks
{
$_[1]->{'name'} =~ /^\/.*\S.*\/[a-z]*$/ || &error($text{'header_ename'});
return $_[1]->{'name'};
}

sub edit_value_header_checks
{
local ($act, $dest) = split(/\s+/, $_[0]->{'value'}, 2);
return &ui_table_row($text{'header_value'},
              &ui_select("action", $act,
			 [ map { [ $_, $text{'header_'.lc($_)} ] }
			       @header_checks_actions ], 0, 0, $act)."\n".
	      &ui_textbox("value", $dest, 40));
}

sub parse_value_header_checks
{
local $rv = $_[1]->{'action'};
if ($_[1]->{'value'}) {
	$rv .= " ".$_[1]->{'value'};
	}
return $rv;
}

# Functions for editing the body_checks map (same as header_checks)
sub edit_name_body_checks
{
return &edit_name_header_checks(@_);
}

sub parse_name_body_checks
{
return &parse_name_header_checks(@_);
}

sub edit_value_body_checks
{
return &edit_value_header_checks(@_);
}

sub parse_value_body_checks
{
return &parse_value_header_checks(@_);
}

## added function for sender_access_maps
## added function for client_access_maps
sub edit_name_check_sender_access
{
return "<td><b>$text{'access_addresses'}</b></td>\n".
       "<td>".&ui_textbox("name", $_[0]->{'name'},40)."</td>\n";
}

sub edit_value_check_sender_access
{
local ($act, $dest) = split(/\s+/, $_[0]->{'value'}, 2);
return "<td><b>$text{'header_value'}</b></td>\n".
       "<td>".&ui_select("action", $act,
			 [ map { [ $_, $text{'header_'.lc($_)} ] }
			       @check_sender_actions ], 0, 0, $act)."\n".
	      &ui_textbox("value", $dest, 40)."</td>\n";
}

sub parse_value_check_sender_access
{
return &parse_value_header_checks(@_);
}

@header_checks_actions = ( "REJECT", "HOLD", "REDIRECT", "DUNNO", "IGNORE",
			   "DISCARD", "FILTER",
			   "PREPEND", "REPLACE", "WARN" );

@check_sender_actions = ( "OK", "REJECT", "DISCARD", "FILTER", "PREPEND", 
        "REDIRECT", "WARN", "DUNNO" );			   

# get_master_config()
# Returns an array reference of entries from the Postfix master.cf file
sub get_master_config
{
if (!scalar(@master_config_cache)) {
	@master_config_cache = ( );
	local $lnum = 0;
	local $prog;
	open(MASTER, $config{'postfix_master'});
	while(<MASTER>) {
		s/\r|\n//g;
		if (/^(#?)\s*(\S+)\s+(inet|unix|fifo)\s+(y|n|\-)\s+(y|n|\-)\s+(y|n|\-)\s+(\S+)\s+(\S+)\s+(.*)$/) {
			# A program line
			$prog = { 'enabled' => !$1,
				  'name' => $2,
				  'type' => $3,
				  'private' => $4,
				  'unpriv' => $5,
				  'chroot' => $6,
				  'wakeup' => $7,
				  'maxprocs' => $8,
				  'command' => $9,
				  'line' => $lnum,
				  'eline' => $lnum,
				 };
			push(@master_config_cache, $prog);
			}
		elsif (/^(#?)\s+(.*)$/ && $prog &&
		       $prog->{'eline'} == $lnum-1 &&
		       $prog->{'enabled'} == !$1) {
			# Continuation line
			$prog->{'command'} .= " ".$2;
			$prog->{'eline'} = $lnum;
			}
		$lnum++;
		}
	close(MASTER);
	}
return \@master_config_cache;
}

# create_master(&master)
# Adds a new Postfix server process
sub create_master
{
local ($master) = @_;
local $conf = &get_master_config();
local $lref = &read_file_lines($config{'postfix_master'});
push(@$lref, &master_line($master));
&flush_file_lines($config{'postfix_master'});
$master->{'line'} = scalar(@$lref)-1;
$master->{'eline'} = scalar(@$lref)-1;
push(@$conf, $master);
}

# delete_master(&master)
# Removes one Postfix server process
sub delete_master
{
local ($master) = @_;
local $conf = &get_master_config();
local $lref = &read_file_lines($config{'postfix_master'});
local $lines = $master->{'eline'} - $master->{'line'} + 1;
splice(@$lref, $master->{'line'}, $lines);
&flush_file_lines($config{'postfix_master'});
@$conf = grep { $_ ne $master } @$conf;
foreach my $c (@$conf) {
	if ($c->{'line'} > $master->{'eline'}) {
		$c->{'line'} -= $lines;
		$c->{'eline'} -= $lines;
		}
	}
}

# modify_master(&master)
# Updates one Postfix server process
sub modify_master
{
local ($master) = @_;
local $conf = &get_master_config();
local $lref = &read_file_lines($config{'postfix_master'});
local $lines = $master->{'eline'} - $master->{'line'} + 1;
splice(@$lref, $master->{'line'}, $lines,
       &master_line($master));
&flush_file_lines($config{'postfix_master'});
foreach my $c (@$conf) {
	if ($c->{'line'} > $master->{'eline'}) {
		$c->{'line'} -= $lines-1;
		$c->{'eline'} -= $lines-1;
		}
	}
}

# master_line(&master)
sub master_line
{
local ($prog) = @_;
return ($prog->{'enabled'} ? "" : "#").
       join("\t", $prog->{'name'}, $prog->{'type'}, $prog->{'private'},
		  $prog->{'unpriv'}, $prog->{'chroot'}, $prog->{'wakeup'},
		  $prog->{'maxprocs'}, $prog->{'command'});
}

sub redirect_to_map_list
{
local ($map_name) = @_;
if ($map_name =~ /sender_dependent_default_transport_maps/) {
	redirect("dependent.cgi");
	}
elsif ($map_name =~ /transport/) { &redirect("transport.cgi"); }
elsif ($map_name =~ /canonical/) { &redirect("canonical.cgi"); }
elsif ($map_name =~ /virtual/) { &redirect("virtual.cgi"); }
elsif ($map_name =~ /relocated/) { &redirect("relocated.cgi"); }
elsif ($map_name =~ /header/) { &redirect("header.cgi"); }
elsif ($map_name =~ /body/) { &redirect("body.cgi"); }
elsif ($map_name =~ /sender_bcc/) { &redirect("bcc.cgi?mode=sender"); }
elsif ($map_name =~ /recipient_bcc/) { &redirect("bcc.cgi?mode=recipient"); }
elsif ($map_name =~ /^smtpd_client_restrictions:/) { &redirect("client.cgi"); }
elsif ($map_name =~ /relay_recipient_maps|smtpd_sender_restrictions/) { &redirect("smtpd.cgi"); }
else { &redirect(""); }
}

sub regenerate_map_table
{
local ($map_name) = @_;
if ($map_name =~ /canonical/) { &regenerate_canonical_table(); }
if ($map_name =~ /relocated/) { &regenerate_relocated_table(); }
if ($map_name =~ /virtual/) { &regenerate_virtual_table(); }
if ($map_name =~ /transport/) { &regenerate_transport_table(); }
if ($map_name =~ /sender_access/) { &regenerate_any_table($map_name); }
if ($map_name =~ /sender_bcc/) { &regenerate_bcc_table(); }
if ($map_name =~ /recipient_bcc/) { &regenerate_recipient_bcc_table(); }
if ($map_name =~ /smtpd_client_restrictions:(\S+)/) {
	&regenerate_any_table("smtpd_client_restrictions",
			      undef, $1);
	}
if ($map_name =~ /relay_recipient_maps/) {
	&regenerate_relay_recipient_table();
	}
if ($map_name =~ /sender_dependent_default_transport_maps/) {
	&regenerate_dependent_table();
	}
if ($map_name =~ /smtpd_sender_restrictions/) {
	&regenerate_sender_restrictions_table();
	}
}

# mailq_table(&qfiles)
# Print a table of queued mail messages
sub mailq_table
{
local ($qfiles) = @_;

# Build table data
my @table;
foreach my $q (@$qfiles) {
	local @cols;
	push(@cols, { 'type' => 'checkbox', 'name' => 'file',
		      'value' => $q->{'id'} });
	push(@cols, &ui_link("view_mailq.cgi?id=$q->{'id'}",$q->{'id'}));
	local $size = &nice_size($q->{'size'});
	push(@cols, "<font size=1>$q->{'date'}</font>");
	push(@cols, "<font size=1>".&html_escape($q->{'from'})."</font>");
	push(@cols, "<font size=1>".&html_escape($q->{'to'})."</font>");
	push(@cols, "<font size=1>$size</font>");
	push(@cols, "<font size=1>".&html_escape($q->{'status'})."</font>");
	push(@table, \@cols);
	}

# Show the table and form
print &ui_form_columns_table("delete_queues.cgi",
	[ [ undef, $text{'mailq_delete'} ],
	  &compare_version_numbers($postfix_version, 1.1) >= 0 ?
		( [ 'move', $text{'mailq_move'} ] ) : ( ),
	  &compare_version_numbers($postfix_version, 2) >= 0 ?
		( [ 'hold', $text{'mailq_hold'} ],
		  [ 'unhold', $text{'mailq_unhold'} ] ) : ( ),
	],
	1,
	undef,
	undef,
	[ "", $text{'mailq_id'}, $text{'mailq_date'}, $text{'mailq_from'},
          $text{'mailq_to'}, $text{'mailq_size'}, $text{'mailq_status'} ],
	100,
	\@table);
}

# is_table_comment(line, [force-prefix])
# Returns the comment text if a line contains a comment, like # foo
sub is_table_comment
{
local ($line, $force) = @_;
if ($config{'prefix_cmts'} || $force) {
	return $line =~ /^\s*#+\s*Webmin:\s*(.*)/ ? $1 : undef;
	}
else {
	return $line =~ /^\s*#+\s*(.*)/ ? $1 : undef;
	}
}

# make_table_comment(comment, [force-tag])
# Returns an array of lines for a comment in a map file, like # foo
sub make_table_comment
{
local ($cmt, $force) = @_;
if (!$cmt) {
	return ( );
	}
elsif ($config{'prefix_cmts'} || $force) {
	return ( "# Webmin: $cmt" );
	}
else {
	return ( "# $cmt" );
	}
}

# lock_postfix_files()
# Lock all Postfix config files
sub lock_postfix_files
{
&lock_file($config{'postfix_config_file'});
&lock_file($config{'postfix_master'});
}

# unlock_postfix_files()
# Un-lock all Postfix config files
sub unlock_postfix_files
{
&unlock_file($config{'postfix_config_file'});
&unlock_file($config{'postfix_master'});
}

# map_chooser_button(field, mapname)
# Returns HTML for a button for popping up a map file chooser
sub map_chooser_button
{
local ($name, $mapname) = @_;
return &popup_window_button("map_chooser.cgi?mapname=$mapname", 1024, 600, 1,
			    [ [ "ifield", $name, "map" ] ]);
}

# get_maps_types_files(value)
# Converts a parameter like hash:/foo/bar,hash:/tmp/xxx to a list of types
# and file paths.
sub get_maps_types_files
{
my ($v) = @_;
my @rv;
foreach my $w (split(/[, \t]+/, $v)) {
	if ($w =~ /^([^:]+):(\/.*)$/) {
		push(@rv, [ $1, $2 ]);
		}
	}
return @rv;
}

# list_mysql_sources()
# Returns a list of global MySQL source names in main.cf
sub list_mysql_sources
{
local @rv;
my $lref = &read_file_lines($config{'postfix_config_file'});
foreach my $l (@$lref) {
	if ($l =~ /^\s*(\S+)_dbname\s*=/) {
		push(@rv, $1);
		}
	}
return @rv;
}

# get_backend_config(file)
# Returns a hash ref from names to values in some backend (ie. mysql or ldap)
# config file.
sub get_backend_config
{
local ($file) = @_;
local %rv;
local $lref = &read_file_lines($file, 1);
foreach my $l (@$lref) {
	if ($l =~ /^\s*([a-z0-9\_]+)\s*=\s*(.*)/i) {
		$rv{$1} = $2;
		}
	}
return \%rv;
}

# save_backend_config(file, name, [value])
# Updates one setting in a backend config file
sub save_backend_config
{
local ($file, $name, $value) = @_;
local $lref = &read_file_lines($file);
local $found = 0;
for(my $i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^\s*([a-z0-9\_]+)\s*=\s*(.*)/i &&
	    $1 eq $name) {
		# Found the line to fix
		if (defined($value)) {
			$lref->[$i] = "$name = $value";
			}
		else {
			splice(@$lref, $i, 1);
			}
		$found = 1;
		last;
		}
	}
if (!$found && defined($value)) {
	push(@$lref, "$name = $value");
	}
}

# can_access_map(type, value)
# Checks if some map (such as a database) can be accessed
sub can_access_map
{
local ($type, $value) = @_;
if (&file_map_type($type)) {
	return undef;	# Always can
	}
elsif ($type eq "mysql") {
	# Parse config, connect to DB
	local $conf;
	if ($value =~ /^[\/\.]/) {
		# Config file
		local $cfile = $value;
		if ($cfile !~ /^\//) {
			$cfile = &guess_config_dir()."/".$cfile;
			}
		-r $cfile || return &text('mysql_ecfile', "<tt>$cfile</tt>");
		$conf = &get_backend_config($cfile);
		}
	else {
		# Backend name
		$conf = &mysql_value_to_conf($value);
		$conf->{'dbname'} || return &text('mysql_esource', $value);
		}

	if (!$conf->{"query"}) {
		# Do we have the field and table info?
		foreach my $need ('table', 'select_field', 'where_field') {
			$conf->{$need} || return &text('mysql_eneed', $need);
			}
		}
	# Try a connect, and a query
	local $dbh = &connect_mysql_db($conf);
	if (!ref($dbh)) {
		return $dbh;
		}
	local $cmd = $dbh->prepare("select ".$conf->{'select_field'}." ".
				   "from ".$conf->{'table'}." ".
				   "where ".$conf->{'where_field'}." = ".
					    $conf->{'where_field'}." ".
				   "limit 1");
	if (!$cmd || !$cmd->execute()) {
		return &text('mysql_equery',
			     "<tt>".$conf->{'table'}."</tt>",
			     "<tt>".&html_escape($dbh->errstr)."</tt>");
		}
	$cmd->finish();
	$dbh->disconnect();
	return undef;
	}
elsif ($type eq "ldap") {
	# Parse config, connect to LDAP server
	local $conf = &ldap_value_to_conf($value);
	$conf->{'search_base'} || return &text('ldap_esource', $value);

	# Try a connect and a search
	local $ldap = &connect_ldap_db($conf);
	if (!ref($ldap)) {
		return $ldap;
		}
	local @classes = split(/\s+/, $config{'ldap_class'} ||
				      "inetLocalMailRecipient");
	local $rv = $ldap->search(base => $conf->{'search_base'},
				  filter => "(objectClass=$classes[0])",
				  sizelimit => 1);
	if (!$rv || $rv->code && !$rv->all_entries) {
		return &text('ldap_ebase', "<tt>$conf->{'search_base'}</tt>",
			     $rv ? $rv->error : "Unknown search error");
		}

	return undef;
	}
else {
	return &text('map_unknown', "<tt>$type</tt>");
	}
}

# connect_mysql_db(&config)
# Attempts to connect to the Postfix MySQL database. Returns
# a driver handle on success, or an error message string on failure.
sub connect_mysql_db
{
local ($conf) = @_;
local $driver = "mysql";
local $drh;
eval <<EOF;
use DBI;
\$drh = DBI->install_driver(\$driver);
EOF
if ($@) {
	return &text('mysql_edriver', "<tt>DBD::$driver</tt>");
        }
local @hosts = split(/\s+/, $config{'mysql_hosts'} || $conf->{'hosts'});
@hosts = ( undef ) if (!@hosts);	# Localhost only
local $dbh;
foreach my $host (@hosts) {
	local $dbistr = "database=$conf->{'dbname'}";
	if ($host =~ /^unix:(.*)$/) {
		# Socket file
		$dbistr .= ";mysql_socket=$1";
		}
	elsif ($host) {
		# Remote host
		$dbistr .= ";host=$host";
		}
	$dbh = $drh->connect($dbistr,
			     $config{'mysql_user'} || $conf->{'user'},
			     $config{'mysql_pass'} || $conf->{'password'},
			     { });
	last if ($dbh);
	}
$dbh || return &text('mysql_elogin',
		     "<tt>$conf->{'dbname'}</tt>", $drh->errstr)."\n";
return $dbh;
}

# connect_ldap_db(&config)
# Attempts to connect to an LDAP server with Postfix maps. Returns
# a driver handle on success, or an error message string on failure.
sub connect_ldap_db
{
local ($conf) = @_;
if (defined($connect_ldap_db_cache)) {
	return $connect_ldap_db_cache;
	}
eval "use Net::LDAP";
if ($@) {
	return &text('ldap_eldapmod', "<tt>Net::LDAP</tt>");
	}
local @servers = split(/\s+/, $config{'ldap_host'} ||
			      $conf->{'server_host'} || "localhost");
local ($ldap, $lasterr);
foreach my $server (@servers) {
	local ($host, $port, $tls);
	if ($server =~ /^(\S+):(\d+)$/) {
		# Host and port
		($host, $port) = ($1, $2);
		$tls = $conf->{'start_tls'} eq 'yes';
		}
	elsif ($server =~ /^(ldap|ldaps):\/\/(\S+)(:(\d+))?/) {
		# LDAP URL
		$host = $2;
		$port = $4 || $conf->{'server_port'} || 389;
		$tls = $1 eq "ldaps";
		}
	else {
		# Host only
		$host = $server;
		$port = $conf->{'server_port'} || 389;
		$tls = $conf->{'start_tls'} eq 'yes';
		}
	$ldap = Net::LDAP->new($server, port => $port);
	if (!$ldap) {
		$lasterr = &text('ldap_eldap', "<tt>$server</tt>", $port);
		next;
		}
	if ($tls) {
		$ldap->start_tls;
		}
	if ($conf->{'bind'} eq 'yes' || $config{'ldap_user'}) {
		local $mesg = $ldap->bind(
			dn => $config{'ldap_user'} || $conf->{'bind_dn'},
			password => $config{'ldap_pass'} || $conf->{'bind_pw'});
		if (!$mesg || $mesg->code) {
			$lasterr = &text('ldap_eldaplogin',
				     "<tt>$server</tt>",
				     "<tt>".($config{'ldap_user'} ||
					     $conf->{'bind_dn'})."</tt>",
				     $mesg ? $mesg->error : "Unknown error");
			$ldap = undef;
			next;
			}
		}
	last if ($ldap);
	}
if ($ldap) {
	# Connected OK
	$connect_ldap_db_cache = $ldap;
	return $ldap;
	}
else {
	return $lasterr;
	}
}

# mysql_value_to_conf(value)
# Converts a MySQL config file or source name to a config hash ref
sub mysql_value_to_conf
{
local ($value) = @_;
local $conf;
if ($value =~ /^[\/\.]/) {
	# Config file
	local $cfile = $value;
	if ($cfile !~ /^\//) {
		$cfile = &guess_config_dir()."/".$cfile;
		}
	-r $cfile || &error(&text('mysql_ecfile', "<tt>$cfile</tt>"));
	$conf = &get_backend_config($cfile);
		
	if ($conf->{'query'} =~ /^select\s+(\S+)\s+from\s+(\S+)\s+where\s+(\S+)\s*=\s*'\%s'/i && !$conf->{'table'}) {
		# Try to extract table and fields from the query
		$conf->{'select_field'} = $1;
		$conf->{'table'} = $2;
		$conf->{'where_field'} = $3;
		}
	}
else {
	# Backend name
	$conf = { };
	foreach my $k ("hosts", "dbname", "user", "password", "query",
		       "table", "where_field", "select_field",
		       "additional_conditions") {
		local $v = &get_real_value($value."_".$k);
		$conf->{$k} = $v;
		}
	if ($conf->{'query'} =~ /^select\s+(\S+)\s+from\s+(\S+)\s+where\s+(\S+)\s*=\s*'\%s'/i && !$conf->{'table'}) {
		# Try to extract table and fields from the query
		$conf->{'select_field'} = $1;
		$conf->{'table'} = $2;
		$conf->{'where_field'} = $3;
		}
	}
return $conf;
}

# ldap_value_to_conf(value)
# Converts an LDAP config file name to a config hash ref
sub ldap_value_to_conf
{
local ($value) = @_;
local $conf;
local $cfile = $value;
if ($cfile !~ /^\//) {
	$cfile = &guess_config_dir()."/".$cfile;
	}
-r $cfile && !-d $cfile || &error(&text('ldap_ecfile', "<tt>$cfile</tt>"));
return &get_backend_config($cfile);
}

# can_map_comments(name)
# Returns 1 if some map can have comments. Not allowed for MySQL and LDAP.
sub can_map_comments
{
local ($name) = @_;
foreach my $tv (&get_maps_types_files(&get_real_value($name))) {
	return 0 if (!&file_map_type($tv->[0]));
	}
return 1;
}

# can_map_manual(name)
# Returns 1 if osme map has a file that can be manually edited
sub can_map_manual
{
local ($name) = @_;
foreach my $tv (&get_maps_types_files(&get_real_value($name))) {
	return 0 if (!&file_map_type($tv->[0]));
	}
return 1;
}

# supports_map_type(type)
# Returns 1 if a map of some type is supported by Postfix
sub supports_map_type
{
local ($type) = @_;
return 1 if ($type eq 'hash');	# Assume always supported
if (!scalar(@supports_map_type_cache)) {
	@supports_map_type = ( );
	open(POSTCONF, "$config{'postfix_config_command'} -m |");
	while(<POSTCONF>) {
		s/\r|\n//g;
		push(@supports_map_type_cache, $_);
		}
	close(POSTCONF);
	}
return &indexoflc($type, @supports_map_type_cache) >= 0;
}

# split_props(text)
# Converts multiple lines of text into LDAP attributes
sub split_props
{
local ($text) = @_;
local %pmap;
foreach $p (split(/\t+/, $text)) {
        if ($p =~ /^(\S+):\s*(.*)/) {
                push(@{$pmap{$1}}, $2);
                }
        }
local @rv;
local $k;
foreach $k (keys %pmap) {
        local $v = $pmap{$k};
        if (@$v == 1) {
                push(@rv, $k, $v->[0]);
                }
        else {
                push(@rv, $k, $v);
                }
        }
return @rv;
}

# list_smtpd_restrictions()
# Returns a list of SMTP server restrictions known to Webmin
sub list_smtpd_restrictions
{
return ( "permit_mynetworks",
	 "permit_inet_interfaces",
	 &compare_version_numbers($postfix_version, 2.3) < 0 ?
		"reject_unknown_client" :
		"reject_unknown_reverse_client_hostname",
	 "permit_sasl_authenticated",
	 "reject_unauth_destination",
	 "check_relay_domains",
	 "permit_mx_backup" );
}

# list_client_restrictions()
# Returns a list of boolean values for use in smtpd_client_restrictions
sub list_client_restrictions
{
return ( "permit_mynetworks",
	 "permit_inet_interfaces",
	 &compare_version_numbers($postfix_version, 2.3) < 0 ?
		"reject_unknown_client" :
		"reject_unknown_reverse_client_hostname",
	 "permit_tls_all_clientcerts",
	 "permit_sasl_authenticated",
	);
}

# list_multi_client_restrictions()
# Returns a list of restrictions that have a following value
sub list_multi_client_restrictions
{
return ( "check_client_access",
	 "reject_rbl_client",
	 "reject_rhsbl_client",
       );
}

sub file_map_type
{
local ($type) = @_;
return 1 if ($type eq 'hash' || $type eq 'regexp' || $type eq 'pcre' ||
	     $type eq 'btree' || $type eq 'dbm' || $type eq 'cidr');
}

# in_props(&props, name)
# Looks up the value of a named property in a list
sub in_props
{
local ($props, $name) = @_;
for(my $i=0; $i<@$props; $i++) {
	if (lc($props->[$i]) eq lc($name)) {
		return $props->[$i+1];
		}
	}
return undef;
}

# For calling from aliases-lib only
sub rebuild_map_cmd
{
return 0;
}

# valid_postfix_command(cmd)
# Check if some command exists on the system. Strips off args.
sub valid_postfix_command
{
my ($cmd) = @_;
($cmd) = &split_quoted_string($cmd);
return &has_command($cmd);
}

# get_all_config_files()
# Returns a list of all possible postfix config files
sub get_all_config_files
{
my @rv;

# Add main config file
push(@rv, $config{'postfix_config_file'});
push(@rv, $config{'postfix_master'});

# Add known map files
push(@rv, &get_maps_files("alias_maps"));
push(@rv, &get_maps_files("alias_database"));
push(@rv, &get_maps_files("canonical_maps"));
push(@rv, &get_maps_files("recipient_canonical_maps"));
push(@rv, &get_maps_files("sender_canonical_maps"));
push(@rv, &get_maps_files($virtual_maps));
push(@rv, &get_maps_files("transport_maps"));
push(@rv, &get_maps_files("relocated_maps"));
push(@rv, &get_maps_files("relay_recipient_maps"));
push(@rv, &get_maps_files("smtpd_sender_restrictions"));

# Add other files in /etc/postfix
local $cdir = &guess_config_dir();
opendir(DIR, $cdir);
foreach $f (readdir(DIR)) {
	next if ($f eq "." || $f eq ".." || $f =~ /\.(db|dir|pag)$/i);
	push(@rv, "$cdir/$f");
	}
closedir(DIR);

return &unique(@rv);
}

1;

