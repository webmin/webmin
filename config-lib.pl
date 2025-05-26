# config-lib.pl
# Common functions for parsing config.info files
# Each module has a number of configurable parameters (stored in the config and
# config-* files in the module directory). Descriptions and possible values for
# each option are stored in the file config.info in the module directory.
# Each line of config.info looks like
# name=desc,type[,options]
#  desc - A description of the parameter
#  type - Possible types (and options) are
#	0 - Free text
#	1 - One of many (options are possibilities)
#	2 - Many of many (options are possibilities)
#	3 - Optional free text
#	4 - Like 1, but uses a pulldown menu
#	5 - User name
#	6 - Group name
#	7 - Directory
#	8 - File
#	9 - Multiline text
#	10 - Like 1, but with free text option
#	11 - Section header
#	12 - Password free text, with don't change option
#	13 - Like 2, but uses a list box
#	14 - Parameter is the name of a function in config_info.pl that
#	     returns an alternate set of config.info values.
#	15 - Parameter is the suffix for a pair of functions with show_
#	     and parse_ prepended.
#	16 - Password free text

# generate_config(&config, info-file, [module], [&can-config], [checkbox-name],
#		  [only-section])
# Prints HTML for 
sub generate_config
{
my ($configref, $file, $module, $canconfig, $cbox, $section) = @_;
my %config = %$configref;

my $auto = $gconfig{"langauto_$remote_user"};
my $neutral = $gconfig{"langneutral_$remote_user"};
if (!defined($auto)) {
my $glangauto = $gconfig{'langauto'};
if (defined($glangauto)) {
	$auto = $glangauto;
	} 
else {
	my ($clanginfo) = grep { $_->{'lang'} eq $current_lang } &list_languages();
	$auto = $clanginfo->{'auto'};
	}
}

# Read the .info file in the right language
my (%info, @info_order, %einfo, $o);
&read_file($file, \%info, \@info_order);
%einfo = %info;
foreach $o (@lang_order_list) {
	&read_file("$file.$o", \%info, \@info_order);
	&read_file("$file.$o.auto", \%info, \@info_order)
		if ($auto && -r "$file.$o.auto");
	&read_file("$file.$o.neutral", \%info, \@info_order)
		if ($neutral && -r "$file.$o.neutral");
	}

# Call any config pre-load function
if (&foreign_defined($module, 'config_pre_load')) {
	&foreign_call($module, "config_pre_load", \%info, \@info_order);
	&foreign_call($module, "config_pre_load", \%einfo);
	}

@info_order = &unique(@info_order);

if ($section) {
	# Limit to settings in one section
	@info_order = &config_in_section($section, \@info_order, \%info);
	}

# Show the parameter editors
foreach my $c (@info_order) {
	my $checkhtml;
	if ($cbox) {
		# Show checkbox to allow configuring
		$checkhtml = &ui_checkbox($cbox, $c, "",
					  !$canconfig || $canconfig->{$c});
		}
	else {
		# Skip those not allowed to be configured
		next if ($canconfig && !$canconfig->{$c});
		}
	my @p = split(/,/, $info{$c});
	my @ep = split(/,/, $einfo{$c});
	if (scalar(@ep) > scalar(@p)) {
		push(@p, @ep[scalar(@p) .. @ep-1]);
		}
	if ($p[1] == 14) {
		$module || &error($text{'config_ewebmin'});
		&foreign_require($module, "config_info.pl");
		my @newp = &foreign_call($module, $p[2], @p);
		$newp[0] ||= $p[0];
		@p = @newp;
		}
	if ($p[1] == 11) {
		# Title row
		print &ui_table_row(undef, "<b>$p[0]</b>", 2, [ undef, $tb ]);
		next;
		}
	if ($p[1] == 16 && $gconfig{'config_16_insecure'}) {
		# Don't allow mode 16
		$p[1] = 12;
		}
	my $label;
	if ($module && -r &help_file($module, "config_$c")) {
		$label = $checkhtml." ".
		         &hlink($p[0], "config_$c", $module);
		}
	else {
		$label = $checkhtml." ".$p[0];
		}
	my $field;
	if ($p[1] == 0) {
		# Text value
		$field = &ui_textbox($c, $config{$c}, $p[2] || 40, 0, $p[3]).
			 " ".$p[4];
		}
	elsif ($p[1] == 1) {
		# One of many
		my $len = 0;
		for(my $i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			$len += length($2);
			}
		my @opts;
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			push(@opts, [ $1, $2.($len > 50 ? "<br>" : "") ]);
			}
		$field = &ui_radio($c, $config{$c}, \@opts);
		}
	elsif ($p[1] == 2) {
		# Many of many
		my %sel;
		map { $sel{$_}++ } split(/,/, $config{$c});
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			$field .= &ui_checkbox($c, $1, $2, $sel{$1});
			}
		}
	elsif ($p[1] == 3) {
		# Optional value
		my $none = $p[2] || $text{'config_none'};
		$field = &ui_opt_textbox($c, $config{$c}, $p[3] || 20, $none,
					 $p[6], 0, undef, $p[4])." ".$p[5];
		}
	elsif ($p[1] == 4) {
		# One of many menu
		my @opts;
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			push(@opts, [ $1, $2 ]);
			}
		$field = &ui_select($c, $config{$c}, \@opts);
		}
	elsif ($p[1] == 5) {
		# User chooser
		if ($p[2]) {
			$field = &ui_radio($c."_def", $config{$c} ? 0 : 1,
					   [ [ 1, $p[2] ], [ 0, " " ] ]);
			}
		if ($p[3]) {
			$field .= &ui_textbox($c, $config{$c}, 30)." ".
				  &user_chooser_button($c, 1);
			}
		else {
			$field .= &unix_user_input($c, $config{$c});
			}
		}
	elsif ($p[1] == 6) {
		# Group chooser
		if ($p[2]) {
			$field = &ui_radio($c."_def", $config{$c} ? 0 : 1,
					   [ [ 1, $p[2] ], [ 0, " " ] ]);
			}
		if ($p[3]) {
			$field .= &ui_textbox($c, $config{$c}, 30)." ".
				  &group_chooser_button($c, 1);
			}
		else {
			$field .= &unix_group_input($c, $config{$c});
			}
		}
	elsif ($p[1] == 7) {
		# Directory chooser
		$field = &ui_textbox($c, $config{$c}, 40)." ".
			 &file_chooser_button($c, 1);
		}
	elsif ($p[1] == 8) {
		# File chooser
		$field = &ui_textbox($c, $config{$c}, 40)." ".
			 &file_chooser_button($c, 0);
		}
	elsif ($p[1] == 9) {
		# Text area
		my $cols = $p[2] || 40;
		my $rows = $p[3] || 5;
		my $sp = $p[4] ? eval "\"$p[4]\"" : " ";
		$field = &ui_textarea($c, join("\n", split(/$sp/, $config{$c})),
				      $rows, $cols);
		}
	elsif ($p[1] == 10) {
		# Radios with freetext option
		my $len = 20;
		for(my $i=2; $i<@p; $i++) {
			if ($p[$i] =~ /^(\S*)\-(.*)$/) {
				$len += length($2);
				}
			else {
				$len += length($p[$i]);
				}
			}
		my $fv = $config{$c};
		my @opts;
		for(my $i=2; $i<@p; $i++) {
			($p[$i] =~ /^(\S*)\-(.*)$/) || next;
			push(@opts, [ $1, $2.($len > 50 ? "<br>" : "") ]);
			$fv = undef if ($config{$c} eq $1);
			}
		push(@opts, [ "free", $p[$#p] !~ /^(\S*)\-(.*)$/ ? $p[$#p]
								 : " " ]);
		$field = &ui_radio($c, $fv ? "free" : $config{$c}, \@opts)." ".
			 &ui_textbox($c."_free", $fv, 20);
		}
	elsif ($p[1] == 12) {
		# Password field
		$field = &ui_radio($c."_nochange", 1,
				   [ [ 1, $text{'config_nochange'} ],
				     [ 0, $text{'config_setto'} ] ])." ".
			 &ui_password($c, undef, $p[2] || 40, 0, $p[3]);
		}
	elsif ($p[1] == 13) {
		# Multiple selections from menu
		my @sel = split(/,/, $config{$c});
		my @opts;
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			push(@opts, [ $1, $2 ]);
			}
		$field = &ui_select($c, \@sel, \@opts, 5, 1);
		}
	elsif ($p[1] == 15) {
		# Input generated by function
		$module || &error($text{'config_ewebmin'});
		&foreign_require($module, "config_info.pl");
		$field = &foreign_call($module, "show_".$p[2],
				       $config{$c}, @p);
		}
	elsif ($p[1] == 16) {
		# Password free text
		$field = &ui_password($c, undef, $p[2] || 40, 0, $p[3]);
		}
	$label = "<a name=$c>$label</a>";
	print &ui_table_row($label, $field, 1, [ "width=30% nowrap" ]);
	}
}

# parse_config(&config, info-file, [module], [&canconfig], [section])
# Updates the specified configuration with values from %in
sub parse_config
{
my ($config, $file, $module, $canconfig, $section) = @_;

# Read the .info file
my (%info, @info_order, $o);
&read_file($file, \%info, \@info_order);
foreach $o (@lang_order_list) {
	&read_file("$file.$o", \%info, \@info_order);
	}
@info_order = &unique(@info_order);

if ($section) {
	# Limit to settings in one section
	@info_order = &config_in_section($section, \@info_order, \%info);
	}

# If config fields are conditional (not displayed)
# make sure to preserve system default values to
# prevent changing behaviour of a module
if (&foreign_exists($module) &&
    &foreign_require($module) &&
    &foreign_defined($module, 'config_pre_load')) {
	&foreign_call($module, "config_pre_load", \%info, \@info_order);
	}

# Actually parse the inputs
foreach my $c (@info_order) {
	next if ($canconfig && !$canconfig->{$c});
	my @p = split(/,/, $info{$c});
	if ($p[1] == 14) {
		$_[2] || &error($text{'config_ewebmin'});
		&foreign_require($_[2], "config_info.pl");
		my @newp = &foreign_call($_[2], $p[2]);
		$newp[0] ||= $p[0];
		@p = @newp;
		}
	if ($p[1] == 16 && $gconfig{'config_16_insecure'}) {
		# Don't allow mode 16
		$p[1] = 12;
		}
	if ($p[1] == 0 || $p[1] == 7 || $p[1] == 8 || $p[1] == 16) {
		# Free text input
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 1 || $p[1] == 4) {
		# One of many
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 5 || $p[1] == 6) {
		# User or group
		$config->{$c} = ($p[2] && $in{$c."_def"} ? "" : $in{$c});
		}
	elsif ($p[1] == 2 || $p[1] == 13) {
		# Many of many
		$in{$c} =~ s/\0/,/g;
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 3) {
		# Optional free text
		if ($in{$c."_def"}) { $config->{$c} = ""; }
		else { $config->{$c} = $in{$c}; }
		}
	elsif ($p[1] == 9) {
		# Multilines of free text
		my $sp = $p[4] ? eval "\"$p[4]\"" : " ";
		$in{$c} =~ s/\r//g;
		$in{$c} =~ s/\n/$sp/g;
		$in{$c} =~ s/\s+$//;
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 10) {
		# One of many or free text
		if ($in{$c} eq 'free') {
			$config->{$c} = $in{$c.'_free'};
			}
		else {
			$config->{$c} = $in{$c};
			}
		}
	elsif ($p[1] == 12) {
		# Optionally changed password
		if (!$in{"${c}_nochange"}) {
			$config->{$c} = $in{$c};
			}
		}
	elsif ($p[1] == 15) {
		# Parse custom HTML field
		$_[2] || &error($text{'config_ewebmin'});
		&foreign_require($_[2], "config_info.pl");
		$config->{$c} = &foreign_call($_[2], "parse_".$p[2],
					    $config->{$c}, @p);
		}
	}
}

# config_in_section(&section, &order, &config-info)
# Returns a list of config names that are in some section
sub config_in_section
{
my ($section, $info_order, $info) = @_;
my @new_order = ( );
my $in_section = 0;
foreach my $c (@$info_order) {
	my @p = split(/,/, $info->{$c});
	if ($p[1] == 11 && $c eq $section) {
		$in_section = 1;
		}
	elsif ($p[1] == 11 && $c ne $section) {
		$in_section = 0;
		}
	elsif ($in_section) {
		push(@new_order, $c);
		}
	}
return @new_order;
}

# save_module_preferences(module, &config)
# Check which user preferences can be save for
# given module based on module's prefs.info file
sub save_module_preferences
{
my ($module, $curr_config) = @_;
my $module_dir = &module_root_directory($module);
my $module_prefs_conf = "$module_dir/prefs.info";
if (-r $module_prefs_conf) {
	my %module_prefs_conf_allowed;
	&read_file($module_prefs_conf, \%module_prefs_conf_allowed);
	mkdir("$config_directory/$module", 0700);
	my $user_prefs_file = "$config_directory/$module/prefs.$remote_user";
	&lock_file($user_prefs_file);
	if ($module_prefs_conf_allowed{'allowed'} eq "*") {
		&write_file($user_prefs_file, \%$curr_config);
		}
	else {
		my %newconfigtmp;
		foreach my $key (keys %{$curr_config}) {
			if (grep(/^$key$/, split(",", $module_prefs_conf_allowed{'allowed'}))) {
				$newconfigtmp->{$key} = $curr_config->{$key};
				}
			}
		&write_file($user_prefs_file, \%$newconfigtmp);
		}
	&unlock_file($user_prefs_file);
	}
}

# hidden_config_cparams(&in)
# Return HTML for hidden inputs for params to pass back to whatever linked
# to config.cgi
sub hidden_config_cparams
{
my ($in) = @_;
my $rv = "";
foreach my $k (keys %$in) {
	next if ($k !~ /^(_cparam_|_cscript)/);
	foreach my $v (split(/\0/, $in{$k})) {
		$rv .= &ui_hidden($k, $v)."\n";
		}
	}
return $rv;
}

# link_config_cparams(module, &in, [add-cparam])
# Returns a URL to link to after the config is saved
sub link_config_cparams
{
my ($m, $in, $keep) = @_;
my $url = "/$m/";
my @w;
if ($in->{'_cscript'}) {
	if ($keep) {
		push(@w, "_cscript=".&urlize($in->{'_cscript'}));
		}
	else {
		$url .= $in->{'_cscript'};
		}
	}
foreach my $k (keys %$in) {
	if ($k =~ /^_cparam_(.*)$/) {
		$n = $1;
		foreach my $v (split(/\0/, $in{$k})) {
			push(@w, &urlize($keep ? $k : $n)."=".&urlize($v));
			}
		}
	}
if (@w) {
	$url .= "?".join("&", @w);
	}
return $url;
}

1;

