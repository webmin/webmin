#!/usr/local/bin/perl
# index.cgi
# Display main menu of cfengine options

require './cfengine-lib.pl';

# Check if cfengine command exists
if (!&has_command($config{'cfengine'})) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print &text('index_ecommand', "<tt>$config{'cfengine'}</tt>",
		     "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Make sure it is actually cfengine, and get the version
$ver = &get_cfengine_version(\$out);
if (!$ver) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print &text('index_eversion', "<tt>$config{'cfengine'} -v</tt>",
		     "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, undef,
	&help_search_link("cfengine", "man", "doc", "google"), undef, undef,
	&text('index_version', $ver));

# Only versions 1.x are supported yet
if ($ver !~ /^1\./) {
	print &text('index_eversion2', "<tt>$config{'cfengine'}</tt>",
		     "<tt>$ver</tt>", "<tt>1.x</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if config file exists
if (!-r $cfengine_conf || -d $config{'cfengine_conf'}) {
	print &text('index_econfig', "<tt>$cfengine_conf</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Display table of sections
$conf = &get_config();
@secs = grep { $_->{'type'} eq 'section' } @$conf;
&show_classes_table(\@secs, 0);

# Display option icons
print &ui_hr();
print &ui_subheading($text{'index_options'});
@links = ( "run_form.cgi", "list_hosts.cgi", "edit_cfd.cgi", "edit_push.cgi" );
@titles = ( $text{'run_title'}, $text{'hosts_title'}, $text{'cfd_title'},
	    $text{'push_title'} );
@icons = ( "images/run.gif", "images/hosts.gif", "images/cfd.gif",
	   "images/push.gif" );
&icons_table(\@links, \@titles, \@icons);

&ui_print_footer("/", $text{'index'});

