# Common functions for editing the Frox config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
@ui_tds = ( undef, "nowrap" );

# get_config()
# Returns an array reference containing the contents of the Frox config file
sub get_config
{
    if (!scalar(@get_config_cache)) {
	    local $lnum = 0;
	    open(CONF, $config{'frox_conf'});
	    while(<CONF>) {
		s/\r|\n//g;
		s/^\s*#.$//g;
		if (/^\s*(\S+)\s*(.*)/) {
		    push(@get_config_cache,
			      { 'name' => $1,
				'value' => $2,
				'words' => [ split(/\s+/, $2) ],
				'line' => $lnum,
				'index' => scalar(@get_config_cache) });
		}
		$lnum++;
	    }
	    close(CONF);
    }
    return \@get_config_cache;
}

# find(name, &config)
sub find
{
    local @rv;
    foreach $c (@{$_[1]}) {
	if (lc($c->{'name'}) eq lc($_[0])) {
	    push(@rv, $c);
	}
    }
    return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
    local @rv = &find($_[0], $_[1]);
    if (wantarray) {
	return map { $_->{'value'} } @rv;
	}
    else {
	return $rv[0]->{'value'};
	}
}

# save_directive(&config, name, &values)
# Update the config file with some new values for an option
sub save_directive
{
local ($conf, $name, $values) = @_;
local $lref = &read_file_lines($config{'frox_conf'});
local @old = &find($name, $conf);
local @new = @$values;
local $i;
local $changed;
for($i=0; $i<@old || $i<@new; $i++) {
	if ($i<@old && $i<@new) {
		# Updating some directive
		$lref->[$old[$i]->{'line'}] = $name." ".$new[$i];
		$old[$i]->{'value'} = $new[$i];
		$changed = $old[$i];
		}
	elsif ($i<@old) {
		# Removing some directive (need to renumber)
		splice(@$lref, $old[$i]->{'line'}, 1);
		splice(@$conf, $old[$i]->{'index'}, 1);
		&renumber($conf, 'line', $old[$i]->{'line'}, -1);
		&renumber($conf, 'index', $old[$i]->{'index'}, -1);
		}
	elsif ($i<@new) {
		# Adding some directive (perhaps after same)
		local $nd = { 'name' => $name,
			      'value' => $new[$i] };
		local ($j, $cmtline);
		for($j=0; $j<@$lref; $j++) {
			if ($lref->[$j] =~ /^\s*#+\s*(\S+)/ && $1 eq $name) {
				$cmtline = $j;
				}
			}
		if ($changed) {
			# Adding after same
			$nd->{'line'} = $changed->{'line'}+1;
			$nd->{'index'} = $changed->{'index'}+1;
			&renumber($conf, 'line', $changed->{'line'}, 1);
			&renumber($conf, 'index', $changed->{'index'}, 1);
			splice(@$lref, $changed->{'line'}+1, 0,
			       $name." ".$new[$i]);
			splice(@$conf, $changed->{'index'}+1, 0, $nd);
			$changed = $nd;
			}
		elsif (defined($cmtline)) {
			# Adding after comment of same directive
			local ($aftercmt) = grep { $_->{'line'} > $cmtline } @$conf;
			$nd->{'line'} = $cmtline;
			$nd->{'index'} = $aftercmt ? $aftercmt->{'index'} : 0;
			&renumber($conf, 'line', $nd->{'line'}-1, 1);
			&renumber($conf, 'index', $nd->{'index'}-1, 1);
			splice(@$lref, $cmtline+1, 0,
			       $name." ".$new[$i]);
			splice(@$conf, $nd->{'index'}, 0, $nd);
			$changed = $nd;
			}
		else {
			# Adding at end
			$nd->{'line'} = scalar(@$lref);
			$nd->{'index'} = scalar(@$conf);
			push(@$lref, $name." ".$new[$i]);
			push(@$conf, $nd);
			}
		}
	}
}

# renumber(&conf, field, pos, offset)
sub renumber
{
local ($conf, $field, $pos, $offset) = @_;
local $c;
foreach $c (@$conf) {
	if ($c->{$field} > $pos) {
		$c->{$field} += $offset;
		}
	}
}

# config_textbox(&config, name, size, cols, [prefix])
# Returns HTML for a table row for some text field
sub config_textbox
{
local ($conf, $name, $size, $cols, $prefix) = @_;
$cols ||= 1;
local $val = join(" ", &find_value($name, $conf));
$val =~ s/\s*'(.*)'\s*$/$1/;
return &ui_table_row($text{'edit_'.$name},
		     &ui_textbox($name, $val, $size)." ".$prefix,
		     $cols, \@ui_tds);
}

# save_textbox(config, name, [function], [split])
sub save_textbox
{
local ($conf, $name, $func, $split) = @_;
local @vals = $split ? split(/\s+/, $in{$name}) : ( $in{$name} );
local $v;
foreach $v (@vals) {
	&error_check($name, $func, $v);
	$v = "'$v'" if ($v =~ /\s/);
	}
&save_directive($conf, $name, \@vals);
}

# config_opt_textbox(&config, name, size, cols, [default])
# Returns HTML for a table row for some optional text field
sub config_opt_textbox
{
local ($conf, $name, $size, $cols, $default) = @_;
$cols ||= 1;
local $val = join(" ", &find_value($name, $conf));
$val =~ s/\s*'(.*)'\s*$/$1/;
return &ui_table_row($text{'edit_'.$name},
		     &ui_radio($name."_def", $val ? 0 : 1,
			       [ [ 1, $default || $text{'default'} ],
				 [ 0, " " ] ])." ".
		     &ui_textbox($name, $val, $size), $cols, \@ui_tds);
}

# save_opt_textbox(config, name, [function], [split])
sub save_opt_textbox
{
local ($conf, $name, $func, $split) = @_;
if ($in{$name."_def"}) {
	&save_directive($conf, $name, [ ]);
	}
else {
	&save_textbox(@_);
	}
}

# config_yesno(&config, name, [yes], [no], [default])
# Returns HTML for a table row for yes/no checkboxes
sub config_yesno
{
local ($conf, $name, $yes, $no, $default) = @_;
local $val = &find_value($name, $conf);
$val ||= $default;
return &ui_table_row($text{'edit_'.$name},
		     &ui_radio($name, $val =~ /yes|on|true/i ? 1 : 0,
			       [ [ 1, $yes || $text{'yes'} ],
				 [ 0, $no || $text{'no'} ] ]), 1, \@ui_tds).
       &ui_hidden($name."_default", $default);
}

# save_yesno(&config, name, default)
sub save_yesno
{
local ($conf, $name, $default) = @_;
local $val = &find_value($name, $conf);
$val ||= $in{$name."_default"};
local $curr = $val =~ /yes|on|true/i ? 1 : 0;
if ($curr ne $in{$name}) {
	&save_directive($conf, $name, [ $in{$name} ? "yes" : "no" ]);
	}
}

# config_exists(&config, name, [yes], [no])
# Returns HTML for a table row for yes/no checkboxes, based on the existance
# of some config item
sub config_exists
{
local ($conf, $name, $yes, $no) = @_;
local $exists = &find($name, $conf);
return &ui_table_row($text{'edit_'.$name},
		     &ui_radio($name, $exists ? 1 : 0,
			       [ [ 1, $yes || $text{'yes'} ],
				 [ 0, $no || $text{'no'} ] ]), 1, \@ui_tds);
}

# save_exists(&config, name)
sub save_exists
{
local ($conf, $name) = @_;
&save_directive($conf, $name, $in{$name} ? [ "" ] : [ ]);
}

# config_user(&config, name)
# Returns HTML for a table row for a username field
sub config_user
{
local ($conf, $name) = @_;
local $val = &find_value($name, $conf);
return &ui_table_row($text{'edit_'.$name},
		     &ui_user_textbox($name, $val, $size), 1, \@ui_tds);
}

# save_user(&config, name)
# Saves a username field
sub save_user
{
local ($conf, $name) = @_;
defined(getpwnam($in{$name})) ||
	&error($text{'edit_'.$name}." : ".$text{'edit_euser'});
&save_directive($conf, $name, [ $in{$name} ]);
}

# config_group(&config, name)
# Returns HTML for a table row for a groupname field
sub config_group
{
local ($conf, $name) = @_;
local $val = &find_value($name, $conf);
return &ui_table_row($text{'edit_'.$name},
		     &ui_group_textbox($name, $val, $size), 1, \@ui_tds);
}

# save_group(&config, name)
# Saves a group name field
sub save_group
{
local ($conf, $name) = @_;
defined(getgrnam($in{$name})) ||
	&error($text{'edit_'.$name}." : ".$text{'edit_egroup'});
&save_directive($conf, $name, [ $in{$name} ]);
}

# config_opt_range(&config, name, cols, default)
# Returns HTML for a row containing a two-part range input field
sub config_opt_range
{
local ($conf, $name, $cols, $default) = @_;
$cols ||= 1;
local $val = &find_value($name, $conf);
local ($v1, $v2) = split(/\-/, $val);
return &ui_table_row($text{'edit_'.$name},
		     &ui_radio($name."_def", $val ? 0 : 1,
			       [ [ 1, $default || $text{'default'} ],
				 [ 0, " " ] ])." ".
		     $text{'edit_from'}." ".
		     &ui_textbox($name."_from", $v1, 6)." ".
		     $text{'edit_to'}." ".
		     &ui_textbox($name."_to", $v2, 6), $cols, \@ui_tds);
}

# save_opt_range(config, name)
sub save_opt_range
{
local ($conf, $name, $func, $split) = @_;
if ($in{$name."_def"}) {
	&save_directive($conf, $name, [ ]);
	}
else {
	local $v1 = $in{$name."_from"};
	local $v2 = $in{$name."_to"};
	$v1 =~ /^\d+$/ && $v1 > 0 && $v2 < 65535 ||
		&error($text{'edit_'.$name}." : ".$text{'edit_efrom'});
	$v2 =~ /^\d+$/ && $v2 > 0 && $v2 < 65536 ||
		&error($text{'edit_'.$name}." : ".$text{'edit_eto'});
	$v1 < $v2 || &error($text{'edit_'.$name}." : ".$text{'edit_erange'});
	&save_directive($conf, $name, [ $v1."-".$v2 ]);
	}
}

# error_check(name, func, value)
sub error_check
{
local ($name, $func, $val) = @_;
return if (!$func);
local $err = &$func($val);
&error($text{'edit_'.$name}." : ".$err) if ($err);
}

# is_frox_running()
# Returns the PID if Frox is running, 0 if not
sub is_frox_running
{
local $conf = &get_config();
local $pidfile = &find_value("PidFile", $conf);
if ($pidfile) {
	open(PID, $pidfile) || return 0;
	chop($pid = <PID>);
	close(PID);
	return $pid && kill(0, $pid) ? $pid : 0;
	}
else {
	local ($pid) = &find_byname("frox");
	return $pid;
	}
}

# restart_frox()
# Apply the current frox configuration, or return an error message
sub restart_frox
{
if ($config{'apply_cmd'}) {
	$out = &backquote_logged("($config{'apply_cmd'}) 2>&1 </dev/null");
	if ($?) {
		return "<pre>$out</pre>";
		}
	}
else {
	$pid = &is_frox_running();
	$pid || return $text{'stop_egone'};
	&kill_logged('HUP', $pid) || return $text{'stop_egone'};
	}
return undef;
}

1;

