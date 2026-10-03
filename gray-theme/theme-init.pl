# Functions that read the theme settings. The core loads this file while it
# sets up every page, as the oofunctions file named in the theme config,
# and theme.pl loads it too. Reading the settings that early matters on
# pages that then switch to a Unix user, such as File Manager for a domain
# owner: that user cannot read the root-only settings files.

# theme_post_init_config()
# Called by the core at the end of init_config, while the page still runs
# as root. Reads the theme settings, which the page then keeps.
sub theme_post_init_config
{
&theme_settings();
}

# theme_settings()
# Returns the theme settings as a hash ref: the user's own, or the global
# ones when those apply to everyone or the user has none. They are stored
# with the system information page settings and read once per page.
sub theme_settings
{
return $main::gray_theme_settings if ($main::gray_theme_settings);
my $file = "$config_directory/$current_theme/sections";
my %sects;
&read_file($file, \%sects);
if (!$sects{'global'}) {
	# The user's own file replaces the global settings
	my %usects;
	%sects = %usects if (&read_file("$file.$remote_user", \%usects));
	}
$main::gray_theme_settings = \%sects;
return $main::gray_theme_settings;
}

1;
