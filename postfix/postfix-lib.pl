# postfix-lib.pl
# XXX ldap support and multiple servers (mentioned by Joe)
# XXX virtual mail boxes and read mail

#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
#
# Functions for managing the postfix module for Webmin.
#
# Written by G. Cottenceau for MandrakeSoft <gc@mandrakesoft.com>
# This is free software under GPL license.
#

$POSTFIX_MODULE_VERSION = 5;

#
#
# -------------------------------------------------------------------------


do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
%access = &get_module_acl();
$access{'postfinger'} = 0 if (&is_readonly_mode());
do 'aliases-lib.pl';

$config{'perpage'} ||= 20;      # a value of 0 can cause problems

# Get the saved version number
if (&open_readfile(VERSION, "$module_config_directory/version")) {
	chop($postfix_version = <VERSION>);
	close(VERSION);
	}
else {
	# Not there .. work it out
	if (&has_command($config{'postfix_config_command'}) &&
	    &backquote_command("$config{'postfix_config_command'} mail_version 2>&1", 1) =~ /mail_version\s*=\s*(.*)/) {
		# Got the version
		$postfix_version = $1;
		}

	# And save for other callers
	&open_tempfile(VERSION, ">$module_config_directory/version", 0, 1);
	&print_tempfile(VERSION, "$postfix_version\n");
	&close_tempfile(VERSION);
	}

if ($postfix_version >= 2) {
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
	if ($begin_flag == 1 && $l =~ /^(\t+[^#].+)/) {
		# non-comment continuation line, and replace tabs with spaces
		$out .= $1;
		$out =~ s/\t/ /;
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
	$out = &backquote_command(
	  "$config{'postfix_config_command'} -c $config_dir -h $name 2>&1", 1);
	if ($?) {
		&error(&text('query_get_efailed', $name, $out));
		}
	elsif ($out =~ /warning:.*unknown\s+parameter/) {
		return undef;
		}
	chop($out);
	}
if ($key) {
	my @res=();
	foreach (split /,/,$out)
	    { push @res, $1 if /$key\s+(.+)/; }
	if ($#res>0) {$out=join ", ",@res}
	else {$out=$res[0]}
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
#    print "--".$value."--<br>";
    if (($value eq "__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__" || $value eq &get_default_value($_[0])) && !$_[2])
    {
	# there is a special case in which there is no static default value ;
	# postfix will handle it correctly if I remove the line in `main.cf'
	my $all_lines = &read_file_lines($config{'postfix_config_file'});
	my $line_of_parameter = -1;
	my $i = 0;

	foreach (@{$all_lines})
	{
	    if (/^\s*$_[0]\s*=/)
	    {
		$line_of_parameter = $i;
	    }
	    $i++;
	}

	if ($line_of_parameter != -1) {
	    splice(@{$all_lines}, $line_of_parameter, 1);
	    &flush_file_lines($config{'postfix_config_file'});
	} else {
	    &unflush_file_lines($config{'postfix_config_file'});
	}
    }
    else
    {
	$value =~ s/\$/\\\$/g;     # prepend a \ in front of every $ to protect from shell substitution
        local ($out, $ex);
	$ex = &execute_command("$config{'postfix_config_command'} -c $config_dir -e $_[0]=\"$value\"", undef, \$out, \$out);
	$ex && &error(&text('query_set_efailed', $_[0], $_[1], $out)."<br> $config{'postfix_config_command'} -c $config_dir -e $_[0]=\"$value\" 2>&1");
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
    $access{'startstop'} || &error($text{'reload_ecannot'});
    if (is_postfix_running())
    {
	if (check_postfix()) { &error("$text{'check_error'}"); }
	my $ex;
	if ($config{'reload_cmd'}) {
		$ex = &system_logged("$config{'postfix_control_command'} -c $config_dir reload >/dev/null 2>&1");
		}
	else {
		$ex = &system_logged("$config{'reload_cmd'} >/dev/null 2>&1");
		}
	if ($ex) { &error($text{'reload_efailed'}); }
    }
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
    
    printf "<td>".&hlink("<b>$text{$key}</b>", "opt_".$name)."</td> <td %s nowrap>\n",
    $length > 20 ? "colspan=3" : "";

    # first radio button (must be default value!!)
    
    print &ui_oneradio($name."_def", "__DEFAULT_VALUE_IE_NOT_IN_CONFIG_FILE__",
		       $_[2], &if_default_value($name));

    $check_free_field = 0 if &if_default_value($name);
    shift;
    
    # other radio buttons
    while (defined($_[2]))
    {
	print &ui_oneradio($name."_def", $_[2], $_[3], $v eq $_[2]);
	if ($v eq $_[2]) { $check_free_field = 0; }
	shift;
	shift;
    }

    # the free field
    print &ui_oneradio($name."_def", "__USE_FREE_FIELD__", undef,
		       $check_free_field == 1);
    print &ui_textbox($name, $check_free_field == 1 ? $v : undef, $length);
    print "</td>\n";
}


# option_freefield(name_of_option, length_of_free_field)
# builds an option with free field
sub option_freefield
{
    my ($name, $length) = ($_[0], $_[1]);

    my $v = &get_current_value($name);
    my $key = 'opts_'.$name;
    
    printf "<td>".&hlink("<b>$text{$key}</b>", "opt_".$name)."</td> <td %s nowrap>\n",
    $length > 20 ? "colspan=3" : "";
    
    print &ui_textbox($name."_def", $v, $length),"</td>\n";
}


# option_yesno(name_of_option, [help])
# if help is provided, displays help link
sub option_yesno
{
    my $name = $_[0];
    my $v = &get_current_value($name);
    my $key = 'opts_'.$name;

    defined($_[1]) ?
	print "<td>".&hlink("<b>$text{$key}</b>", "opt_".$name)."</td> <td nowrap>\n"
    :
	print "<td><b>$text{$key}</b></td> <td nowrap>\n";
    
    print &ui_radio($name."_def", lc($v),
		    [ [ "yes", $text{'yes'} ], [ "no", $text{'no'} ] ]);
    print "</td>\n";
}

# option_select(name_of_option, &options, [help])
# Shows a drop-down menu of options
sub option_select
{
    my $name = $_[0];
    my $v = &get_current_value($name);
    my $key = 'opts_'.$name;

    defined($_[2]) ?
	print "<td>".&hlink("<b>$text{$key}</b>", "opt_".$name)."</td> <td nowrap>\n"
    :
	print "<td><b>$text{$key}</b></td> <td nowrap>\n";
    
    print &ui_select($name."_def", lc($v), $_[1]);
    print "</td>\n";
}



############################################################################
# aliases support    [too lazy to create a aliases-lib.pl :-)]

# get_aliases_files($alias_maps) : @aliases_files
# parses its argument to extract the filenames of the aliases files
# supports multiple alias-files
sub get_aliases_files
{
    $_[0] =~ /:(\/[^,\s]*)(.*)/;
    (my $returnvalue, my $recurse) = ( $1, $2 );

    # Yes, Perl is also a functional language -> I construct a list, and no problem, lists are flattened in Perl
    return ( $returnvalue,
	     ($recurse =~ /:\/[^,\s]*/) ?
	         &get_aliases_files($recurse)
	     :
	         ()
           )
}

 
# get_aliases() : \@aliases
# construct the aliases database taken from the aliases files given in the "alias_maps" parameter
sub get_aliases
{
    if (!@aliases_cache)
    {
	my @aliases_files = &get_aliases_files(&get_current_value("alias_maps"));
	my $number = 0;
	foreach $aliases_file (@aliases_files)
	{
	    &open_readfile(ALIASES, $aliases_file);
	    my $i = 0;
	    while (<ALIASES>)
	    {
		s/^#.*$//g;	# remove comments
		s/\r|\n//g;	# remove newlines
		if ((/^\s*\"([^\"]*)[^:]*:\s*([^#]*)/) ||      # names with double quotes (") are special, as seen in `man aliases(5)`
		    (/^\s*([^\s:]*)[^:]*:\s*([^#]*)/))         # other names
		{
		    $number++;
		    my %alias;
		    $alias{'name'} = $1;
		    $alias{'value'} = $2;
		    $alias{'line'} = $i;
		    $alias{'alias_file'} = $aliases_file;
		    $alias{'number'} = $number;
		    push(@aliases_cache, \%alias);
		}
		$i++;
	    }
	    close(ALIASES);
	}
    }
    return \@aliases_cache;
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

# save_options(%options)
#
sub save_options
{
    if (check_postfix()) { &error("$text{'check_error'}"); }

    my %options = %{$_[0]};

    foreach $key (keys %options)
    {
	if ($key =~ /_def/)
	{
	    (my $param = $key) =~ s/_def//;
	    my $value = $options{$key} eq "__USE_FREE_FIELD__" ?
			$options{$param} : $options{$key};
            if ($value =~ /(\S+):(\/\S+)/ && $access{'dir'} ne '/') {
		foreach my $f (&get_maps_files("$1:$2")) {
		   if (!&is_under_directory($access{'dir'}, $f)) {
			&error(&text('opts_edir', $access{'dir'}));
		   }
		}
            }
	    &set_current_value($param, $value);
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
	foreach $map (get_maps_files(get_real_value("alias_maps")))
	{
	    $out = &backquote_logged("$config{'postfix_aliases_table_command'} -c $config_dir $map 2>&1");
	    if ($?) { &error(&text('regenerate_table_efailed', $map, $out)); }
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


# regenerate_any_table($parameter_where_to_find_the_table_names,
#		       [ &force-files ])
#
sub regenerate_any_table
{
    local @files;
    if ($_[1]) {
	@files = @{$_[1]};
    } elsif (&get_current_value($_[0]) ne "") {
	@files = &get_maps_files(&get_real_value($_[0]));
    }
    foreach $map (@files)
    {
        next unless $map;
        local $out = &backquote_logged("$config{'postfix_lookup_table_command'} -c $config_dir $map 2>&1");
        if ($?) { &error(&text('regenerate_table_efailed', $map, $out)); }
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

 
# get_maps($maps_name, [&force-files]) : \@maps
# Construct the mappings database taken from the map files given from the
# parameters.
sub get_maps
{
    if (!defined($maps_cache{$_[0]}))
    {
	my @maps_files = $_[1] ? @{$_[1]} : &get_maps_files(&get_real_value($_[0]));
	my $number = 0;
	foreach $maps_file (@maps_files)
	{
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
	}
    }
    return $maps_cache{$_[0]};
}


# generate_map_edit(name, desc, [wide], [nametitle], [valuetitle])
sub generate_map_edit
{
    if (&get_current_value($_[0]) eq "")
    {
	print ("<h2>$text{'no_map2'}</h2><br>");
	print "<hr>\n";
	&footer("", $text{'index_return'});
	exit;
    }

    # Make sure the user is allowed to edit them
    foreach my $f (&get_maps_files(&get_current_value($_[0]))) {
      &is_under_directory($access{'dir'}, $f) ||
	&error(&text('mapping_ecannot', $access{'dir'}));
    }

    my $mappings = &get_maps($_[0]);
    my $nt = $_[3] || $text{'mapping_name'};
    my $vt = $_[4] || $text{'mapping_value'};

    if ($#{$mappings} ne -1)
    {
	print $_[1];
	
	print &ui_form_start("delete_mappings.cgi", "post");
	print &ui_hidden("map_name", $_[0]),"\n";
	local @links = ( &select_all_link("d", 1),
			 &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	print "<table width=100%> <tr><td width=50% valign=top>\n";
	
	local @tds = ( "width=5" );
	print &ui_columns_start(
			[ "", $nt, $vt,
			  $config{'show_cmts'} ? ( $text{'mapping_cmt'} ) : ( )
			], 100, 0, \@tds);
	my $split_index = int(($#{$mappings})/2);
	my $i = -1;
	
	if ($config{'sort_mode'} == 1) {
		if ($_[0] eq $virtual_maps) {
			@{$mappings} = sort sort_by_domain @{$mappings};
			}
		else {
			@{$mappings} = sort { $a->{'name'} cmp $b->{'name'} }
					    @{$mappings};
			}
		}
	foreach $map (@{$mappings})
	{
	    local @cols = ( "<a href=\"edit_mapping.cgi?num=$map->{'number'}&map_name=$_[0]\">$map->{'name'}</a>",
			    $map->{'value'} );
	    push(@cols, &html_escape($map->{'cmt'})) if ($config{'show_cmts'});
	    print &ui_checked_columns_row(\@cols, \@tds, "d", $map->{'name'});
	    $i++;
	    if ($i == $split_index && !$_[2] && $config{'columns'} == 2)
	    {
		# Switch to second table
		print &ui_columns_end();
		print "</td><td width=50% valign=top>\n";
		if ($i == @$mappings -1) {
			# No more to show!
			print &ui_columns_start([ ]);
			}
		else {
			print &ui_columns_start([ "", $nt, $vt ], 100, 0,\@tds);
			}
	    }
	}
	
	print &ui_columns_end();
	print "</td></tr></table>\n";
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'mapping_delete'} ] ]);
    }


    # new form
    print &ui_buttons_start();
    print &ui_buttons_row("edit_mapping.cgi", $text{'new_mapping'},
			  $text{'new_mappingmsg'},
			  &ui_hidden("map_name", $_[0]));
    if ($access{'manual'}) {
	    print &ui_buttons_row("edit_manual.cgi", $text{'new_manual'},
				  $text{'new_manualmsg'},
				  &ui_hidden("map_name", $_[0]));
	    }
    print &ui_buttons_end();

}


# create_mapping(map, &mapping, [&force-files])
sub create_mapping
{
&get_maps($_[0], $_[2]);	# force cache init
my @maps_files = $_[2] ? @{$_[2]} : &get_maps_files(&get_real_value($_[0]));
local $lref = &read_file_lines($maps_files[0]);
$_[1]->{'line'} = scalar(@$lref);
push(@$lref, &make_table_comment($_[1]->{'cmt'}));
push(@$lref, "$_[1]->{'name'}\t$_[1]->{'value'}");
$_[1]->{'eline'} = scalar(@$lref)-1;
&flush_file_lines();

$_[1]->{'map_file'} = $maps_files[0];
$_[1]->{'file'} = $maps_files[0];
$_[1]->{'number'} = scalar(@{$maps_cache{$_[0]}});
push(@{$maps_cache{$_[0]}}, $_[1]);
}


# delete_mapping(map, &mapping)
sub delete_mapping
{
local $lref = &read_file_lines($_[1]->{'map_file'});
local $len = $_[1]->{'eline'} - $_[1]->{'line'} + 1;
splice(@$lref, $_[1]->{'line'}, $len);
&flush_file_lines();

local $idx = &indexof($_[1], @{$maps_cache{$_[0]}});
splice(@{$maps_cache{$_[0]}}, $idx, 1) if ($idx != -1);
&renumber_list($maps_cache{$_[0]}, $_[1], -$len);
}


# modify_mapping(map, &oldmapping, &newmapping)
sub modify_mapping
{
local $lref = &read_file_lines($_[1]->{'map_file'});
local $oldlen = $_[1]->{'eline'} - $_[1]->{'line'} + 1;
local @newlines;
push(@newlines, &make_table_comment($_[2]->{'cmt'}));
push(@newlines, "$_[2]->{'name'}\t$_[2]->{'value'}");
splice(@$lref, $_[1]->{'line'}, $oldlen, @newlines);
&flush_file_lines();

local $idx = &indexof($_[1], @{$maps_cache{$_[0]}});
$_[2]->{'map_file'} = $_[1]->{'map_file'};
$_[2]->{'file'} = $_[1]->{'file'};
$_[2]->{'line'} = $_[1]->{'line'};
$_[2]->{'eline'} = $_[2]->{'cmt'} ? $_[1]->{'line'}+1 : $_[1]->{'line'};
$maps_cache{$_[0]}->[$idx] = $_[2] if ($idx != -1);
&renumber_list($maps_cache{$_[0]}, $_[1], scalar(@newlines)-$oldlen);
}


# init_new_mapping($maps_parameter) : $number
# gives a new number of mapping
sub init_new_mapping
{
    $maps = &get_maps($_[0]);

    my $max_number = 0;

    foreach $trans (@{$maps})
    {
	if ($trans->{'number'} > $max_number) { $max_number = $trans->{'number'}; }
    }
    
    return $max_number+1;
}

# postfix_mail_file(user)
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
if (!defined(@mail_system_cache)) {
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

# list_queue()
# Returns a list of strutures, each containing details of one queued message
sub list_queue
{
local @qfiles;
&open_execute_command(MAILQ, $config{'mailq_cmd'}, 1, 1);
while(<MAILQ>) {
	next if (/^(\S+)\s+is\s+empty/i || /^\s+Total\s+requests:/i);
	if (/^([^\s\*\!]+)[\*\!]?\s*(\d+)\s+(\S+\s+\S+\s+\d+\s+\d+:\d+:\d+)\s+(.*)/) {
		push(@qfiles, { 'id' => $1,
			        'size' => $2,
				'date' => $3,
				'from' => $4 });
		}
	elsif (/\((.*)\)/ && @qfiles) {
		$qfiles[$#qfiles]->{'status'} = $1;
		}
	elsif (/^\s+(\S+)/ && @qfiles) {
		$qfiles[$#qfiles]->{'to'} .= "$1 ";
		}
	}
close(MAILQ);
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
my $v = &get_current_value($_[0]);
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
$_[1]->{'name'} =~ /^\/\S+\/[a-z]*$/ || &error($text{'header_ename'});
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
if (!defined(@master_config_cache)) {
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
if ($map_name =~ /transport/) { &redirect("transport.cgi"); }
elsif ($map_name =~ /canonical/) { &redirect("canonical.cgi"); }
elsif ($map_name =~ /virtual/) { &redirect("virtual.cgi"); }
elsif ($map_name =~ /relocated/) { &redirect("relocated.cgi"); }
elsif ($map_name =~ /header/) { &redirect("header.cgi"); }
elsif ($map_name =~ /body/) { &redirect("body.cgi"); }
elsif ($map_name =~ /sender_access/) { &redirect("edit_access.cgi?name=smtpd_client_restrictions:check_sender_access&title=Check+sender+access+mapping+table"); }
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
}

# mailq_table(&qfiles)
# Print a table of queued mail messages
sub mailq_table
{
local ($qfiles) = @_;

# Show queued messages
print "<form action=delete_queues.cgi method=post>\n";
local @links = ( &select_all_link("file", 0),
		 &select_invert_link("file", 0) );
print &ui_links_row(\@links);

# Table header
local @tds = ( "width=5" );
print &ui_columns_start([
	"",
	$text{'mailq_id'},
	$text{'mailq_date'},
	$text{'mailq_from'},
	$text{'mailq_to'},
	$text{'mailq_size'},
	$text{'mailq_status'} ], 100, 0, \@tds);
foreach my $q (@$qfiles) {
	local @cols;
	push(@cols, "<a href='view_mailq.cgi?id=$q->{'id'}'>$q->{'id'}</a>");
	local $size = &nice_size($q->{'size'});
	push(@cols, "<font size=1>$q->{'date'}</font>");
	push(@cols, "<font size=1>".&html_escape($q->{'from'})."</font>");
	push(@cols, "<font size=1>".&html_escape($q->{'to'})."</font>");
	push(@cols, "<font size=1>$size</font>");
	push(@cols, "<font size=1>".&html_escape($q->{'status'})."</font>");
	print &ui_checked_columns_row(\@cols, \@tds, "file", $q->{'id'});
	}
print &ui_columns_end();
print &ui_links_row(\@links);
print "<input type=submit value='$text{'mailq_delete'}'>\n";
if ($postfix_version >= 1.1) {
	# Show button to re-queue
	print "&nbsp;\n";
	print &ui_submit($text{'mailq_move'}, "move");
	}
if ($postfix_version >= 2) {
	# Show button to hold and un-hold
	print "&nbsp;\n";
	print &ui_submit($text{'mailq_hold'}, "hold");
	print &ui_submit($text{'mailq_unhold'}, "unhold");
	}
print "<p>\n";
print "</form>\n";
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

1;

