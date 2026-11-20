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

# module_config_editor(module)
# Check access before loading module code. Return the module information,
# directory and config.info file used by both the editor and the save handler.
sub module_config_editor
{
my ($m) = @_;
&get_product_name() eq 'webmin' || &error($text{'config_ecannot'});
defined($m) && $m =~ /\A[A-Za-z0-9_-]+\z/ || &error($text{'config_emodule'});
my %info = &get_module_info($m);
%info || &error($text{'config_emodule'});
&foreign_available($m) || $info{'noacl'} || &error($text{'config_eaccess'});
my %access = &get_module_acl(undef, $m);
$access{'noconfig'} && &error($text{'config_ecannot'});

# Modules can supply hooks in their library or a custom configuration editor.
my $dir = &module_root_directory($m);
my $lib = ($info{'cloneof'} || $m)."-lib.pl";
&foreign_require($m) if ($info{'library'} || -r "$dir/$lib");
&foreign_require($m, "config_info.pl") if (-r "$dir/config_info.pl");

# The last theme with a configuration definition takes precedence.
my $file = "$dir/config.info";
foreach my $root (@theme_root_directories) {
	$file = "$root/$m/config.info" if (-r "$root/$m/config.info");
	}
return ( \%info, $dir, $file );
}

# module_config_return(module, &input, [footer-label])
# Preserve the caller's return parameters and the theme's navigation target.
sub module_config_return
{
my ($m, $in, $label) = @_;
my $url = &link_config_cparams($m, $in);
&load_theme_library();
return &theme_config_return_link($m, $url, $label)
	if (defined(&theme_config_return_link));
return ( $url, $label );
}

# read_config_fields(info-file, [module], [group-sections])
# Resolve field order, translations and module hooks once for the whole form.
sub read_config_fields
{
my ($file, $module, $group_sections) = @_;
my (%info, @order);
&read_file($file, \%info, \@order);
my %english = %info;

# Overlay the user's language files in preference order.
my $auto = &load_language_auto();
my $neutral = $gconfig{"langneutral_$remote_user"};
foreach my $lang (@lang_order_list) {
	&read_file("$file.$lang", \%info, \@order);
	&read_file("$file.$lang.auto", \%info, \@order) if ($auto);
	&read_file("$file.$lang.neutral", \%info, \@order) if ($neutral);
	}
if ($module && &foreign_defined($module, 'config_pre_load')) {
	# Let the module hide or relabel fields in both definitions.
	&foreign_call($module, "config_pre_load", \%info, \@order);
	&foreign_call($module, "config_pre_load", \%english);
	}

# Drop repeated keys and fields the module removed.
@order = grep { exists($info{$_}) } &unique(@order);

# Translations may supply only the label. Both display and save need
# the field type and any omitted parameters from the original definition.
foreach my $key (@order) {
	next if ($info{$key} eq $english{$key});
	my @field = split(/,/, $info{$key});
	my @base = split(/,/, $english{$key});
	if (@base > @field) {
		$info{$key} = join(',', @field, @base[@field .. $#base]);
		}
	}
my @sections;
if ($group_sections) {
	# List the section headings for paginated forms.
	foreach my $key (@order) {
		my ($label, $type) = split(/,/, $info{$key});
		push(@sections, [ $key, $label ]) if ($type == 11);
		}
	if (@sections > 1 && $sections[0]->[0] ne $order[0]) {
		# Include fields before the first heading on the first page.
		my $idx = &indexof($sections[0]->[0], @order);
		unshift(@order, splice(@order, $idx, 1));
		}
	}
return { 'info' => \%info, 'order' => \@order, 'sections' => \@sections };
}

# generate_config(&config, info-file-or-fields, [module], [&can-config],
#                 [checkbox-name], [only-section])
# Render the fields allowed for this form.
sub generate_config
{
my ($configref, $file, $module, $canconfig, $cbox, $section) = @_;
my %config = %$configref;
my $fields = ref($file) ? $file : &read_config_fields($file, $module);
my %info = %{$fields->{'info'}};
my @info_order = @{$fields->{'order'}};
if (defined($section) && $section ne '') {
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
	if ($p[1] == 14) {
		$module || &error($text{'config_ewebmin'});
		&foreign_require($module, "config_info.pl");
		my @newp = &foreign_call($module, $p[2], @p);
		$newp[0] ||= $p[0];
		@p = @newp;
		}
	if ($p[1] == 11) {
		# Title row
		print &ui_table_row(undef, &ui_tag('b', $p[0]), 2, [ undef, $tb ]);
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
		my $br = $len > 50 ? &ui_br() : "";
		for($i=2; $i<@p; $i++) {
			$p[$i] =~ /^(\S*)\-(.*)$/;
			push(@opts, [ $1, $2.$br ]);
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
		my $br = $len > 50 ? &ui_br() : "";
		for(my $i=2; $i<@p; $i++) {
			($p[$i] =~ /^(\S*)\-(.*)$/) || next;
			push(@opts, [ $1, $2.$br ]);
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
	$label = &ui_tag('a', $label, { 'name' => $c });
	print &ui_table_row($label, $field, 1, [ "width=30% nowrap" ]);
	}
}

# parse_config(&config, info-file-or-fields, [module], [&canconfig], [section])
# Update the specified configuration from %in and return the fields written.
sub parse_config
{
my ($config, $file, $module, $canconfig, $section) = @_;

# The shared editor supplies the same filtered definitions it uses to render.
# Other callers pass a filename and may need the module's hooks loaded here.
if (!ref($file) && $module && &foreign_exists($module)) {
	&foreign_require($module);
	}
my $fields = ref($file) ? $file : &read_config_fields($file, $module);
my %info = %{$fields->{'info'}};
my @info_order = @{$fields->{'order'}};
if (defined($section) && $section ne '') {
	@info_order = &config_in_section($section, \@info_order, \%info);
	}

# Actually parse the inputs
my @saved;
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
		# Keeping a password also keeps any existing personal override.
		next if ($in{"${c}_nochange"});
		$config->{$c} = $in{$c};
		}
	elsif ($p[1] == 15) {
		# Parse custom HTML field
		$_[2] || &error($text{'config_ewebmin'});
		&foreign_require($_[2], "config_info.pl");
		$config->{$c} = &foreign_call($_[2], "parse_".$p[2],
					    $config->{$c}, @p);
		}
	else {
		# Headings and unrecognized field types have no value to save.
		next;
		}
	push(@saved, $c);
	}
return \@saved;
}

# parse_custom_config(&config, info-file, module, [section])
# Run the module's save callback and return the settings it wrote or deleted.
sub parse_custom_config
{
my ($config, $file, $module, $section) = @_;
if (length($section)) {
	# Reject a stale section before calling the module.
	my $fields = &read_config_fields($file, $module, 1);
	&config_in_section($section, $fields->{'order'}, $fields->{'info'});
	}

# A callback can write an existing value or delete a personal-only setting.
# Neither operation shows up in a comparison of the old and new config.
require Tie::Hash;
my %written;
tie(my %changes, 'Webmin::ConfigChanges', $config, \%written);
&foreign_call($module, 'config_save', \%changes);
return [ keys %written ];
}

# config_in_section(section, &order, &config-info)
# Return the config names in one section. Stop with an error if the section
# heading does not exist.
sub config_in_section
{
my ($section, $info_order, $info) = @_;
# An unknown section must not select an empty or partial set of fields.
my (undef, $type) = split(/,/, $info->{$section});
defined($type) && $type == 11 || &error($text{'config_esection'});
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

# save_module_preferences(module, &config, [&saved-fields])
# Save allowed preferences, preserving other sections on a partial save.
sub save_module_preferences
{
my ($module, $curr_config, $saved) = @_;
my $module_dir = &module_root_directory($module);
my $module_prefs_conf = "$module_dir/prefs.info";
if (-r $module_prefs_conf) {
	my %module_prefs_conf_allowed;
	&read_file($module_prefs_conf, \%module_prefs_conf_allowed);
	mkdir("$config_directory/$module", 0700);
	my $user_prefs_file = "$config_directory/$module/prefs.$remote_user";
	&lock_file($user_prefs_file);
	if ($saved) {
		# Other sections may contain personal overrides.
		my %prefs;
		&read_file($user_prefs_file, \%prefs);
		foreach my $key (@$saved) {
			if (exists($curr_config->{$key})) {
				$prefs{$key} = $curr_config->{$key};
				}
			else {
				delete($prefs{$key});
				}
			}
		$curr_config = \%prefs;
		}
	if ($module_prefs_conf_allowed{'allowed'} eq "*") {
		&write_file($user_prefs_file, \%$curr_config);
		}
	else {
		my %newconfigtmp;
		foreach my $key (split(/,/, $module_prefs_conf_allowed{'allowed'})) {
			$newconfigtmp{$key} = $curr_config->{$key}
				if (exists($curr_config->{$key}));
			}
		&write_file($user_prefs_file, \%newconfigtmp);
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

# Private to parse_custom_config. Tie::ExtraHash handles reads and iteration.
{
package Webmin::ConfigChanges;
our @ISA = qw(Tie::ExtraHash);

# TIEHASH(class, &config, &written)
# Tie::ExtraHash uses the first hash for storage.
sub TIEHASH
{
my ($class, $config, $written) = @_;
return bless([ $config, $written ], $class);
}

# STORE(self, key, value)
sub STORE
{
my ($self, $key, $value) = @_;
$self->[1]->{$key} = 1;
return $self->SUPER::STORE($key, $value);
}

# DELETE(self, key)
sub DELETE
{
my ($self, $key) = @_;
$self->[1]->{$key} = 1;
return $self->SUPER::DELETE($key);
}

# CLEAR(self) calls DELETE for each key when a callback replaces the hash.
sub CLEAR { Tie::Hash::CLEAR(@_) }
}

1;

