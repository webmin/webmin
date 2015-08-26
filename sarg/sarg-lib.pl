# Functions for reading and writing sarg.conf

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

$cron_cmd = "$module_config_directory/generate.pl";
%needs_quotes = map { $_, 1 } ("title", "logo_text", "user_invalid_char",
			       "privacy_string", "include_users",
			       "exclude_string", "datafile_delimiter");

# get_config()
# Parses the sarg config file into directives
sub get_config
{
if (!scalar(@get_config_cache)) {
	local $lnum = 0;
	open(CONF, $config{'sarg_conf'});
	while(<CONF>) {
		s/\r|\n//g;
		if (/^\s*(#*)\s*(\S+)\s+"([^"]*)"/ ||
		    /^\s*(#*)\s*(\S+)\s+'([^"]*)'/ ||
		    /^\s*(#*)\s*(\S+)\s+(.*\S)/) {
			push(@get_config_cache,
				  { 'name' => $2,
				    'value' => $3,
				    'enabled' => !$1,
				    'line' => $lnum });
			}
		$lnum++;
		}
	close(CONF);
	}
return \@get_config_cache;
}

# find(name, &config, [and-disabled])
sub find
{
local @rv;
local $c;
foreach $c (@{$_[1]}) {
	if (lc($c->{'name'}) eq lc($_[0])) {
		if ($c->{'enabled'} && $_[2] == 0 ||
		    !$c->{'enabled'} && $_[2] == 2 ||
				       $_[2] == 1) {
			push(@rv, $c);
			}
		}
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @rv = map { $_->{'value'} } &find(@_);
return wantarray ? @rv : $rv[0];
}

# save_directive(&config, name, &values)
# Update the config file with some new values for an option
sub save_directive
{
local ($conf, $name, $values) = @_;
local $lref = &read_file_lines($config{'sarg_conf'});
local @old = &find($name, $conf);
local @new = @$values;
local $i;
local $changed;
for($i=0; $i<@old || $i<@new; $i++) {
	local $newline;
	if ($i<@new) {
		if ($needs_quotes{$name}) {
			$newline = $name." \"".$new[$i]."\"";
			}
		else {
			$newline = $name." ".$new[$i];
			}
		}

	if ($i<@old && $i<@new) {
		# Updating some directive
		$lref->[$old[$i]->{'line'}] = $newline;
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
		# Adding some directive (perhaps after comment)
		local $nd = { 'name' => $name,
			      'value' => $new[$i] };
		local $cmt = &find($name, $conf, 1);
		if ($cmt && !$cmt->{'enabled'}) {
			# Add after comment line
			$nd->{'line'} = $cmt->{'line'} + 1;
			$nd->{'index'} = $cmt->{'index'} + 1;
			&renumber($conf, 'line', $nd->{'line'}-1, 1);
			&renumber($conf, 'index', $nd->{'index'}-1, 1);
			splice(@$lref, $nd->{'line'}, 0, $newline);
			splice(@$conf, $nd->{'index'}, 0, $nd);
			}
		else {
			# Add to end
			$nd->{'line'} = scalar(@$lref);
			$nd->{'index'} = scalar(@$conf);
			push(@$lref, $newline);
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
return &ui_table_row($text{$config_prefix.$name},
		     &ui_textbox($name, $val, $size)." ".$prefix,
		     $cols, \@ui_tds);
}

# save_textbox(config, name, [function])
sub save_textbox
{
local ($conf, $name, $func) = @_;
local @vals = $split ? split(/\s+/, $in{$name}) : ( $in{$name} );
local $v;
foreach $v (@vals) {
	&error_check($name, $func, $v);
	}
&save_directive($conf, $name, \@vals);
}

# error_check(name, func, value)
sub error_check
{
local ($name, $func, $val) = @_;
return if (!$func);
local $err = &$func($val);
&error($text{$config_prefix.$name}." : ".$err) if ($err);
}

# config_opt_textbox(&config, name, size, cols, [default])
# Returns HTML for a table row for some optional text field
sub config_opt_textbox
{
local ($conf, $name, $size, $cols, $default) = @_;
$cols ||= 1;
local $val = &find_value($name, $conf);
local $defstr = &find($name, $conf, 2);
local $def = $defstr && $defstr->{'value'} ? " ($defstr->{'value'})" : undef;
return &ui_table_row($text{$config_prefix.($name eq "title" ? "title2" :$name)},
		     &ui_radio($name."_def", $val ? 0 : 1,
			       [ [ 1, $default || $text{'default'}.$def ],
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

# config_yesno(&config, name, [yes], [no], [&others])
# Returns HTML for a table row for yes/no checkboxes
sub config_yesno
{
local ($conf, $name, $yes, $no, $others, $width) = @_;
local $val = &find_value($name, $conf);
local $default = &find($name, $conf, 2);
#local $defstr = $default ? " ($default->{'value'})" : "";
return &ui_table_row($text{$config_prefix.$name},
		     &ui_radio($name, $val,
			       [ [ "yes", $yes || $text{'yes'} ],
				 [ "no", $no || $text{'no'} ],
				 @$others,
				 [ "", $text{'default'}.$defstr ] ]),
		     $width, \@ui_tds);
}

# save_yesno(&config, name)
sub save_yesno
{
local ($conf, $name) = @_;
if (!$in{$name}) {
	&save_directive($conf, $name, [ ]);
	}
else {
	&save_directive($conf, $name, [ $in{$name} ]);
	}
}

# config_radio(&config, name, [&options], [width])
# Returns HTML for a table row for a bunch of checkboxes
sub config_radio
{
local ($conf, $name, $others, $width) = @_;
local $val = &find_value($name, $conf);
local $default = &find($name, $conf, 2);
#local $defstr = $default ? " ($default->{'value'})" : "";
return &ui_table_row($text{$config_prefix.$name},
		     &ui_radio($name, $val,
			       [ @$others,
				 [ "", $text{'default'}.$defstr ] ]),
		     $width, \@ui_tds);
}

sub save_radio
{
&save_yesno(@_);	# same logic works
}

# config_sortfield(&config, name, &opts, [&sort-opts])
# Returns HTML for a table row for selecting a sort mode
sub config_sortfield
{
local ($conf, $name, $opts, $sort) = @_;
local $val = &find_value($name, $conf);
local $default = &find($name, $conf, 2);
#local $defstr = $default ? " ($default->{'value'})" : "";
local @vals = split(/\s+/, $val);
$sort ||= [ [ "reverse", $text{'report_reverse'} ],
	    [ "forward", $text{'report_forward'} ] ];
return &ui_table_row($text{$config_prefix.$name},
	&ui_oneradio($name."_def", 1, $text{'default'}.$defstr, !$val)."\n".
	&ui_oneradio($name."_def", 0, $text{'report_field'}, $val)."\n".
	&ui_select($name."_field", $vals[0],
		   [ map { [ $_, $text{'report_by_'.lc($_)} ] } @$opts ])."\n".
	&ui_select($name."_order", $vals[1], $sort), 3);
}

sub save_sortfield
{
local ($conf, $name) = @_;
if ($in{$name."_def"}) {
	&save_directive($conf, $name, [ ]);
	}
else {
	&save_directive($conf, $name, [ $in{$name."_field"}." ".
					$in{$name."_order"} ]);
	}
}

# config_language(&config, name, width, file)
sub config_language
{
local ($conf, $name, $width, $file) = @_;
local $val = &find_value($name, $conf);
local $default = &find($name, $conf, 2);
local $defstr = $default ? " ($default->{'value'})" : "";
local $found;
local @langs = ( [ "", $text{'default'}.$defstr ] );
open(LANGS, $file);
while(<LANGS>) {
	chop;
	if (/^(\S+)\t+(\S.*)/) {
		push(@langs, [ $1, "$1 - $2" ]);
		}
	elsif (/^(\S+)/) {
		push(@langs, [ $1 ]);
		}
	$found++ if ($val eq $_);
	}
close(LANGS);
push(@langs, [ $val ]) if (!$found && $val);
return &ui_table_row($text{$config_prefix.$name},
		     &ui_select($name, $val, \@langs), $width);
}

# save_language(&config, name)
sub save_language
{
&save_yesno(@_);	# same logic works
}

# config_select(&config, name, &options, default, width)
sub config_select
{
local ($conf, $name, $others, $default, $width) = @_;
local $val = &find_value($name, $conf);
local @vals = split(/\s+/, $val);
return &ui_table_row($text{$config_prefix.$name},
		     &ui_radio($name."_def", $val ? 0 : 1,
			       [ [ 1, $default || $text{'default'} ],
				 [ 0, $text{'report_below'} ] ])."<br>".
		     &ui_select($name, \@vals, $others, "5 ", 1),
		     $width, \@ui_tds);

}

sub save_select
{
local ($conf, $name) = @_;
$in{$name} =~ s/\0/ /g;
$in{$name."_def"} || $in{$name} || &error($text{'report_eselect'});
&save_opt_textbox(@_);	# same logic works
}

# config_colons(&config, name, separator, default, width)
sub config_colons
{
local ($conf, $name, $sep, $default, $width) = @_;
local $val = &find_value($name, $conf);
return &ui_table_row($text{$config_prefix.$name},
		     &ui_radio($name."_def", $val ? 0 : 1,
			       [ [ 1, $default || $text{'default'} ],
				 [ 0, $text{'report_below2'} ] ])."<br>".
		     &ui_textarea($name, join("\n", split($sep, $val)),
				  3, 30),
		     $width, \@ui_tds);
}

# save_colons(&config, name, separator)
sub save_colons
{
local ($conf, $name, $sep) = @_;
$in{$name} =~ s/\r//g;
$in{$name} =~ s/\s+$//;
$in{$name} =~ s/^\s+//;
$in{$name} =~ s/\n/$sep/g;
$in{$name."_def"} || $in{$name} || &error($text{'report_eenter'});
&save_opt_textbox($conf, $name);	# same logic works
}

# config_range(&config, name, start, end, width)
sub config_range
{
local ($conf, $name, $start, $end, $width) = @_;
local $val = &find_value($name, $conf);
local (%sel, $v, $vn);
foreach $v (split(/,/, $val)) {
	if ($v =~ /^(\d+)\-(\d+)$/) {
		foreach $vn ($1 .. $2) { $sel{$vn}++; }
		}
	else { $sel{$v}++; }
	}
local $table = "<table>\n";
local $i;
for($i=$start; $i<=$end; $i++) {
	$table .= "<tr>\n" if ($i%12 == 0);
	$table .= "<td>".&ui_checkbox($name, $i,
		$text{$config_prefix.$name.$i} || $i, $sel{$i})."</td>\n";
	$table .= "</tr>\n" if ($i%12 == 11);
	}
$table .= "</tr>\n" if ($i%12 != 0);
$table .= "</table>\n";
return &ui_table_row($text{$config_prefix.$name},
		     &ui_radio($name."_def", $val ? 0 : 1,
			       [ [ 1, $text{'default'} ],
				 [ 0, $text{'report_below'} ] ]).
		     "<br>".$table, $width);
}

# save_range(&config, name)
sub save_range
{
local ($conf, $name) = @_;
if ($in{$name."_def"}) {
	&save_directive($conf, $name, [ ]);
	}
else {
	local @vals = split(/\0/, $in{$name});
	&save_directive($conf, $name, [ join(",", @vals) ]);
	}
}

# generate_report(handle, escape, clear-output, from, to)
# Immediately generate a report
sub generate_report
{
local ($h, $esc, $clear, $from, $to) = @_;
local $conf = &get_config();
local $odir = &find_value("output_dir", $conf);
$odir ||= &find_value("output_dir", $conf, 1);

if ($clear) {
	# Delete all old files
	unlink("$odir/index.html");
	opendir(DIR, $odir);
	while($f = readdir(DIR)) {
		if (-r "$odir/$f/usuarios") {
			&system_logged("rm -rf ".quotemeta("$odir/$f"));
			}
		}
	closedir(DIR);
	}

# Work out date range
local $rangearg;
if ($from || $to) {
	if ($from < $to) {
		($from, $to) = ($to, $from);
		}
	local $now = time();
	local @fromtm = localtime($now - $from*24*60*60);
	local @totm = localtime($now - $to*24*60*60);
	$rangearg = sprintf "-d %2.2d/%2.2d/%4.4d-%2.2d/%2.2d/%4.4d",
			$fromtm[3], $fromtm[4]+1, $fromtm[5]+1900,
			$totm[3], $totm[4]+1, $totm[5]+1900;
	}

local $sfile = &find_value("access_log", $conf);
local @all = &all_log_files($sfile);
local $cmd = "$config{'sarg'} -f $config{'sarg_conf'} -l @all $rangearg";
print $h $cmd,"\n";
open(OUT, "$cmd 2>&1 |");
while(<OUT>) {
	print $h $esc ? &html_escape($_) : $_;
}	
close(OUT);
return 0 if ($?);
&additional_log("exec", undef, $cmd);
return 1;
}

# all_log_files(file)
sub all_log_files
{
$_[0] =~ /^(.*)\/([^\/]+)$/;
local $dir = $1;
local $base = $2;
local ($f, @rv);
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^\Q$base\E/ && -f "$dir/$f") {
		push(@rv, "$dir/$f");
		}
	}
closedir(DIR);
return @rv;
}

sub gen_clear_input
{
return &ui_radio("clear", int($config{'clear'}),
		      [ [ 1, $text{'yes'} ],
			[ 0, $text{'no'} ] ]);
}

sub gen_range_input
{
local ($rfrom, $rto) = split(/\s+/, $config{'range'});
local $range = &text('sched_rsel',
	       &ui_textbox("rfrom", $rfrom, 3),
	       &ui_textbox("rto", $rto, 3));
return &ui_radio("range_def", $config{'range'} ? 0 : 1,
		      [ [ 1, $text{'sched_rall'} ],
			[ 0, $range ] ]);
}

sub lock_sarg_files
{
&lock_file($config{'sarg_conf'});
}

sub unlock_sarg_files
{
&unlock_file($config{'sarg_conf'});
}

sub get_sarg_version
{
local $out = &backquote_command("$config{'sarg'} -v 2>&1 </dev/null");
if ($out =~ /sarg-([0-9\.]+)\s/ || $out =~ /Version:\s*([0-9\.]+)/i) {
	return $1;
	}
return undef;
}

1;

